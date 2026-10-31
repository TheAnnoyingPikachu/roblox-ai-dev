// node --test tools/   (CI runs it after the place builds, so the end-to-end case runs there)
import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { expectations } from "./expectations.mjs";
import { buildScript, readTask } from "../verify-publish.mjs";
import { stampText } from "../write-build-info.mjs";

const SHA = "0123456789abcdef0123456789abcdef01234567";

test("expectations cover every project node, scripts per mapped folder and the stamp", () => {
  const spec = expectations("garden.project.json");
  const byPath = new Map(spec.expect.map((e) => [e.path.join("."), e]));
  assert.ok(byPath.get("ServerScriptService.Garden").scripts >= 6);
  assert.equal(byPath.get("ReplicatedStorage.BuildInfo").stamp, true);
  assert.equal(byPath.get("ServerScriptService.BuildStamp").scripts, 1);
  assert.ok(byPath.has("ReplicatedStorage.Kit"));
});

test("every project carries the stamp and the stamp scripts", () => {
  for (const p of ["default", "relay", "night", "garden"]) {
    const paths = expectations(`${p}.project.json`).expect.map((e) => e.path.join("."));
    for (const want of ["ReplicatedStorage.BuildInfo", "ReplicatedStorage.Kit", "ServerScriptService.BuildStamp", "StarterPlayer.StarterPlayerScripts.BuildStamp"])
      assert.ok(paths.includes(want), `${p}: ${want}`);
  }
});

test("stampText needs a full sha and no separators", () => {
  assert.equal(stampText({ sha: SHA.toUpperCase(), time: "t", ref: "r", run: "1" }), `sha=${SHA};time=t;ref=r;run=1\n`);
  assert.throws(() => stampText({ sha: "abc", time: "t" }));
  assert.throws(() => stampText({ sha: SHA, time: "t", ref: "a;b" }));
});

test("readTask maps Open Cloud task states", () => {
  assert.deepEqual(readTask({ state: "QUEUED" }), { done: false });
  assert.deepEqual(readTask({ state: "PROCESSING" }), { done: false });
  const failed = readTask({ state: "FAILED", error: { code: "SCRIPT_ERROR", message: "boom" } });
  assert.equal(failed.ok, false);
  assert.match(failed.error, /SCRIPT_ERROR boom/);
  const good = readTask({ state: "COMPLETE", output: { results: [JSON.stringify({ ok: true, problems: [] })] } });
  assert.equal(good.ok, true);
  const bad = readTask({ state: "COMPLETE", output: { results: [JSON.stringify({ ok: false, problems: ["missing X"] })] } });
  assert.equal(bad.ok, false);
  assert.equal(readTask({ state: "COMPLETE", output: { results: ["not json"] } }).ok, false);
});

// Runs the exact script verify-publish sends to Roblox, under Lune on the built place, with
// HttpService swapped for serde (Lune has no HttpService).
const place = "build/garden.rbxl";
test("the Luau execution script verifies a built place", { skip: !existsSync(place) && "build/garden.rbxl not built" }, () => {
  const run = (sha) => {
    const script = buildScript(readFileSync("tools/place-check/checker.luau", "utf8"), expectations("garden.project.json"), sha);
    const shimmed = script.replace(
      'local HttpService = game:GetService("HttpService")',
      'local serde = require("@lune/serde")\nlocal HttpService = { JSONDecode = function(_, s) return serde.decode("json", s) end, JSONEncode = function(_, v) return serde.encode("json", v) end }',
    );
    const file = join(mkdtempSync(join(tmpdir(), "verify-")), "run.luau");
    writeFileSync(
      file,
      `local fs = require("@lune/fs")\nlocal roblox = require("@lune/roblox")\nlocal game = roblox.deserializePlace(fs.readFile(${JSON.stringify(place)}))\nlocal out = (function(game)\n${shimmed}\nend)(game)\nprint(out)\n`,
    );
    return JSON.parse(execFileSync("lune", ["run", file]).toString());
  };
  const plain = run(null);
  assert.equal(plain.ok, true, JSON.stringify(plain.problems));
  const wrong = run("ffffffffffffffffffffffffffffffffffffffff");
  assert.equal(wrong.ok, false);
  assert.match(wrong.problems.join(" "), /build stamp/);
});

import { checkScope, globToRegExp } from "../check-scope.mjs";

test("globToRegExp handles *, ** and folder prefixes", () => {
  assert.ok(globToRegExp("src/kit/*.luau").test("src/kit/RateLimit.luau"));
  assert.ok(!globToRegExp("src/kit/*.luau").test("src/kit/sub/X.luau"));
  assert.ok(globToRegExp("src/kit/**").test("src/kit/sub/X.luau"));
  assert.ok(globToRegExp("src/kit/").test("src/kit/a/b.luau"));
  assert.ok(globToRegExp("docs/**/*.md").test("docs/a/b/c.md"));
  assert.ok(globToRegExp("docs/**/*.md").test("docs/c.md"));
  assert.ok(!globToRegExp("ci.yml").test("ciXyml"));
});

test("checkScope enforces the changed tasks' files", () => {
  const tasks = {
    "studio/tasks/X-001.json": { task_id: "X-001", files: ["src/kit/**"], tests: ["Kit.spec.luau"] },
    "studio/tasks/OLD-001.json": { task_id: "OLD-001" },
  };
  const load = (f) => tasks[f];
  assert.equal(checkScope(["src/kit/A.luau"], load).ok, false); // no task file changed
  const ok = checkScope(["studio/tasks/X-001.json", "src/kit/A.luau", "tests/Kit.spec.luau", "tests/run.luau"], load);
  assert.equal(ok.ok, true);
  const out = checkScope(["studio/tasks/X-001.json", "src/garden/Profiles.luau"], load);
  assert.equal(out.ok, false);
  assert.deepEqual(out.outside, ["src/garden/Profiles.luau"]);
  const legacy = checkScope(["studio/tasks/OLD-001.json", "anything.txt"], load);
  assert.equal(legacy.ok, true);
  assert.deepEqual(legacy.legacy, ["OLD-001"]);
});
