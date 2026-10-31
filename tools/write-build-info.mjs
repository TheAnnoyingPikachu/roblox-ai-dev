#!/usr/bin/env node
// Writes build-info/BuildInfo.txt, the build stamp every place carries as ReplicatedStorage.BuildInfo
// (SPIRE-002). CI and publish.yml run this before `rojo build`; the committed file says "dev".
// Format is parsed by src/kit/BuildStamp.luau and tools/place-check/checker.luau.
import { execSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

export function stampText({ sha, time, ref, run }) {
  if (!/^[0-9a-f]{40}$/i.test(sha ?? "")) throw new Error(`write-build-info: not a full commit sha: ${sha}`);
  for (const [k, v] of Object.entries({ time, ref, run }))
    if (/[;\r\n]/.test(v ?? "")) throw new Error(`write-build-info: ${k} must not contain ; or newlines`);
  return `sha=${sha.toLowerCase()};time=${time};ref=${ref ?? ""};run=${run ?? ""}\n`;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const env = process.env;
  const sha = env.GITHUB_SHA || execSync("git rev-parse HEAD").toString().trim();
  const text = stampText({
    sha,
    time: new Date().toISOString().replace(/\.\d+Z$/, "Z"),
    ref: env.GITHUB_REF || "local",
    run: env.GITHUB_RUN_ID ? `${env.GITHUB_RUN_ID}.${env.GITHUB_RUN_ATTEMPT ?? 1}` : "local",
  });
  writeFileSync("build-info/BuildInfo.txt", text);
  process.stdout.write(`build-info/BuildInfo.txt: ${text}`);
}
