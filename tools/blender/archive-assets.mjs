// Archives Roblox assets a game no longer uses (a replaced model, its decal and its image), with the
// Open Cloud Assets API. Archived assets leave the creator's inventory and stop loading in
// experiences; POST /assets/v1/assets/{id}:restore brings one back.
// Roblox archives decals this way; it refuses models and images ("not an archivable asset type",
// seen 2026-11-15), which then count as failed.
//
//   ROBLOX_API_KEY=... node tools/blender/archive-assets.mjs <id,id,...> [--apply]
//
// Without --apply it only prints what each id is (a dry run): look at the names before archiving.
// It refuses every id that any game's uploaded.json still lists: those are in use.
// Run by .github/workflows/upload-assets.yml (environment `assets`). Never run with a key on a
// developer machine: credentials live only in the GitHub environment (CLAUDE.md rule 6).

import assert from "node:assert";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const API = "https://apis.roblox.com";
const GAMES = ["night", "spire", "garden", "stations"];

// The ids of `ids` that an uploaded.json (name -> { model, decal, texture }) still lists.
export function inUse(ids, uploaded) {
	const used = new Set(Object.values(uploaded).flatMap((entry) => Object.values(entry ?? {})));
	return ids.filter((id) => used.has(id));
}
assert.deepEqual(inUse([1, 2, 3], { a: { model: 2, decal: null, texture: 9 }, b: { model: 3 } }), [2, 3]);

const args = process.argv.slice(2);
const apply = args.includes("--apply");
const ids = args
	.filter((a) => !a.startsWith("--"))
	.flatMap((a) => a.split(","))
	.map((s) => s.trim())
	.filter(Boolean)
	.map(Number);
if (ids.length === 0 || ids.some((id) => !Number.isSafeInteger(id) || id <= 0)) {
	console.error("usage: node tools/blender/archive-assets.mjs <id,id,...> [--apply]");
	process.exit(1);
}
const key = process.env.ROBLOX_API_KEY;
if (!key) {
	console.error("ROBLOX_API_KEY must be set");
	process.exit(1);
}

let refused = [];
for (const game of GAMES) {
	const file = path.join(ROOT, `tools/blender/${game}/uploaded.json`);
	if (!fs.existsSync(file)) continue;
	const hit = inUse(ids, JSON.parse(fs.readFileSync(file, "utf8")));
	if (hit.length) console.error(`in use by ${game}: ${hit.join(", ")}`);
	refused = refused.concat(hit);
}
if (refused.length) {
	console.error("refusing to archive anything: take the ids in use out of the list");
	process.exit(1);
}

async function call(url, method = "GET") {
	const res = await fetch(url, { method, headers: { "x-api-key": key } });
	const text = await res.text();
	let body = {};
	try {
		body = JSON.parse(text);
	} catch {
		// not JSON: keep the text for the message
	}
	return { ok: res.ok, status: res.status, body, text: text.slice(0, 200) };
}

const failed = [];
for (const id of ids) {
	const seen = await call(`${API}/assets/v1/assets/${id}`);
	if (!seen.ok) {
		// a decal's image is not always readable here: with --apply the archive call is still tried
		console.log(`${id}: could not be read (${seen.status} ${seen.text})`);
		if (!apply) continue;
	} else {
		console.log(`${id}: ${seen.body.assetType} "${seen.body.displayName}" state ${seen.body.state ?? "?"}`);
	}
	if (!apply) continue;
	const done = await call(`${API}/assets/v1/assets/${id}:archive`, "POST");
	if (done.ok) {
		console.log(`${id}: archived`);
	} else {
		console.error(`${id}: NOT archived (${done.status} ${done.text})`);
		failed.push(id);
	}
	await new Promise((r) => setTimeout(r, 700)); // the API allows 100 a minute
}
console.log(apply ? `\narchived ${ids.length - failed.length} of ${ids.length}` : `\ndry run: nothing was archived (${ids.length} ids)`);
if (failed.length) {
	console.error(`failed: ${failed.join(", ")}`);
	process.exit(1);
}
