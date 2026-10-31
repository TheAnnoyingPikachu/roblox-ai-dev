#!/usr/bin/env node
// Post-publish gate (SPIRE-002). After publish.yml uploads a place version, this runs
// tools/place-check/checker.luau against THAT version through Open Cloud Luau execution and fails
// unless the published place holds this commit's build stamp and every scripted node of the
// project. A green publish run then means the right build is live in the place file.
//
// Env: ROBLOX_API_KEY (secret), UNIVERSE_ID, PLACE_ID, VERSION (from the publish step),
//      PROJECT (the .project.json that was built), GITHUB_SHA.
// The key needs the Luau execution scope on the staging universe:
//   universe.place.luau-execution-session:write  (created by SHANNON only, CLAUDE.md rule 7)
//
// Writes build/verify-result.json. Exit codes: 0 verified, 1 mismatch or task failure,
// 3 key lacks the scope (the publish itself succeeded; the run still fails so nobody trusts it).
import { readFileSync, writeFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
import { expectations } from "./place-check/expectations.mjs";

const API = "https://apis.roblox.com/cloud/v2";

// The Luau sent to Roblox: the checker inlined, the expectations as a JSON string, the result
// returned as one JSON string (Luau execution returns the script's return values).
export function buildScript(checkerSource, spec, sha) {
  const body = checkerSource.replace(/^--!nocheck\s*/m, "");
  const json = JSON.stringify(spec);
  const shaArg = sha ? JSON.stringify(sha) : "nil";
  return [
    'local HttpService = game:GetService("HttpService")',
    `local check = (function()\n${body}\nend)()`,
    `local spec = HttpService:JSONDecode(${JSON.stringify(json)})`,
    `return HttpService:JSONEncode(check(game, spec, ${shaArg}))`,
  ].join("\n");
}

// Reads a finished task. Returns { done, ok, result?, error? }.
export function readTask(task) {
  const state = task?.state;
  if (state === "QUEUED" || state === "PROCESSING" || state === "STATE_UNSPECIFIED" || !state)
    return { done: false };
  if (state !== "COMPLETE") {
    const msg = task.error ? `${task.error.code ?? ""} ${task.error.message ?? ""}`.trim() : state;
    return { done: true, ok: false, error: `Luau execution ${state}: ${msg}` };
  }
  const raw = task.output?.results?.[0];
  let result;
  try {
    result = typeof raw === "string" ? JSON.parse(raw) : raw;
  } catch {
    return { done: true, ok: false, error: `unreadable result: ${String(raw).slice(0, 200)}` };
  }
  if (!result || typeof result.ok !== "boolean")
    return { done: true, ok: false, error: `unexpected result: ${JSON.stringify(raw).slice(0, 200)}` };
  return { done: true, ok: result.ok, result };
}

async function call(method, url, key, body) {
  const res = await fetch(url, {
    method,
    headers: { "x-api-key": key, ...(body ? { "content-type": "application/json" } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }
  return { status: res.status, json };
}

async function main() {
  const env = process.env;
  const need = ["ROBLOX_API_KEY", "UNIVERSE_ID", "PLACE_ID", "VERSION", "PROJECT", "GITHUB_SHA"];
  const missing = need.filter((k) => !env[k]);
  if (missing.length) {
    console.error(`::error title=Verify publish::missing env ${missing.join(", ")}`);
    process.exit(1);
  }
  for (const k of ["UNIVERSE_ID", "PLACE_ID", "VERSION"])
    if (!/^\d+$/.test(env[k])) {
      console.error(`::error title=Verify publish::${k} must be digits`);
      process.exit(1);
    }

  const spec = expectations(env.PROJECT);
  const script = buildScript(readFileSync("tools/place-check/checker.luau", "utf8"), spec, env.GITHUB_SHA);
  const base = `${API}/universes/${env.UNIVERSE_ID}/places/${env.PLACE_ID}/versions/${env.VERSION}`;
  const created = await call("POST", `${base}/luau-execution-session-tasks`, env.ROBLOX_API_KEY, {
    script,
    timeout: "120s",
  });
  if (created.status === 401 || created.status === 403) {
    console.error(
      `::error title=Verify publish::Open Cloud refused Luau execution (HTTP ${created.status}). ` +
        "The publish went through, but it is NOT verified. SHANNON: add the scope " +
        "universe.place.luau-execution-session:write for this universe to the environment's ROBLOX_API_KEY.",
    );
    process.exit(3);
  }
  if (created.status !== 200 || !created.json.path) {
    console.error(`::error title=Verify publish::could not start Luau execution (HTTP ${created.status})`);
    console.error(JSON.stringify(created.json).slice(0, 500));
    process.exit(1);
  }

  const deadline = Date.now() + 5 * 60 * 1000;
  let outcome = readTask(created.json);
  let lastStatus = created.status;
  while (!outcome.done && Date.now() < deadline) {
    await new Promise((r) => setTimeout(r, 3000));
    const polled = await call("GET", `${API}/${created.json.path}`, env.ROBLOX_API_KEY);
    lastStatus = polled.status;
    if (polled.status === 200) outcome = readTask(polled.json);
    else if ([401, 403, 404].includes(polled.status)) {
      console.error(
        `::error title=Verify publish::Open Cloud refused reading the Luau execution task (HTTP ${polled.status}). ` +
          "The publish went through, but it is NOT verified. SHANNON: the environment's ROBLOX_API_KEY needs " +
          "universe.place.luau-execution-session:write (it covers creating and reading tasks) for this universe.",
      );
      process.exit(polled.status === 404 ? 1 : 3);
    }
  }
  if (!outcome.done) outcome = { done: true, ok: false, error: `timed out after 5 minutes (last poll HTTP ${lastStatus})` };

  const record = {
    verified: outcome.ok,
    published_version: Number(env.VERSION),
    expected_sha: env.GITHUB_SHA,
    project: env.PROJECT,
    ...(outcome.result ?? {}),
    ...(outcome.error ? { error: outcome.error } : {}),
  };
  writeFileSync("build/verify-result.json", JSON.stringify(record, null, 2));
  console.log(JSON.stringify(record, null, 2));
  if (!outcome.ok) {
    const why = outcome.error ?? (outcome.result?.problems ?? []).join("; ");
    console.error(`::error title=Verify publish::version ${env.VERSION} does not match ${env.GITHUB_SHA.slice(0, 7)}: ${why}`);
    process.exit(1);
  }
  console.log(`Verified: version ${env.VERSION} carries build ${env.GITHUB_SHA.slice(0, 7)} and every scripted node.`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) await main();
