#!/usr/bin/env node
// node tools/check-place.mjs <project.json> <place.rbxl> [--sha <commit>]
// Pre-upload gate (SPIRE-002): the built file must contain every node of the project tree, the
// scripts from each mapped folder and, with --sha, a build stamp for that commit. Catches an
// upload of the wrong or empty file before it reaches Roblox.
import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { expectations } from "./place-check/expectations.mjs";

const [project, place, flag, sha] = process.argv.slice(2);
if (!project || !place || (flag && flag !== "--sha")) {
  console.error("usage: node tools/check-place.mjs <project.json> <place.rbxl> [--sha <commit>]");
  process.exit(2);
}
const specFile = join(mkdtempSync(join(tmpdir(), "place-check-")), "expect.json");
writeFileSync(specFile, JSON.stringify(expectations(project)));
try {
  execFileSync("lune", ["run", "tools/place-check/check", place, specFile, sha ?? ""], { stdio: "inherit" });
  console.log(`${place}: matches ${project}${sha ? ` and stamp ${sha.slice(0, 7)}` : ""}`);
} catch {
  console.error(`::error title=Place check::${place} does not match ${project} (see problems above)`);
  process.exit(1);
}
