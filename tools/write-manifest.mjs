#!/usr/bin/env node
// Prints the release manifest for a publish run (blueprint section 23): ties the published
// Roblox version to the exact commit, build hash and test evidence that passed.
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";

const env = process.env;
const place = readFileSync("build/place.rbxl");
const tests = JSON.parse(readFileSync("test-results.json", "utf8"));

const manifest = {
  source_commit: env.GITHUB_SHA,
  source_ref: env.GITHUB_REF,
  build_id: `${env.GITHUB_RUN_ID}.${env.GITHUB_RUN_ATTEMPT}`,
  build_timestamp: new Date().toISOString(),
  artifact_sha256: createHash("sha256").update(place).digest("hex"),
  tests: { total: tests.total, passed: tests.passed, failed: tests.failed },
  target: { environment: env.TARGET, universe_id: env.UNIVERSE_ID, place_id: env.PLACE_ID },
  publication_mode: "Published",
  authorised_by: env.GITHUB_TRIGGERING_ACTOR,
  published_version: Number(env.VERSION),
  build_stamp: readFileSync("build-info/BuildInfo.txt", "utf8").trim(),
  post_publish_verification: env.VERIFIED || "not run",
};

console.log(JSON.stringify(manifest, null, 2));
