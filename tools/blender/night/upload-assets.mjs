// Uploads the committed Night models (assets/night/<name>.fbx) and textures (<name>.png) with the
// Roblox Open Cloud Assets API, then writes tools/blender/night/uploaded.json.
//
//   ROBLOX_API_KEY=... ROBLOX_CREATOR_USER_ID=... node tools/blender/night/upload-assets.mjs [name ...]
//
// Run by .github/workflows/upload-assets.yml (environment `assets`). Never run with a key on a
// developer machine: credentials live only in the GitHub environment (CLAUDE.md rule 6).
// FBX uploads as assetType "Model" (a package of MeshParts, loaded in game with
// InsertService:LoadAsset); PNG uploads as "Decal". The decal's image id (what TextureID needs) is
// read from the decal's content via the Asset Delivery API when the key allows it
// (legacy-asset:manage); otherwise it stays null and the game resolves it from the decal at runtime.

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
const MANIFEST = path.join(ROOT, "tools/blender/night/manifest.json");
const OUT = path.join(ROOT, "tools/blender/night/uploaded.json");
const FILES = path.join(ROOT, "assets/night");
const API = "https://apis.roblox.com";
// Tinted by code (Color must show), so they stay untextured.
const UNTEXTURED = new Set(["slash_arc", "demon_wing"]);

const key = process.env.ROBLOX_API_KEY;
const userId = process.env.ROBLOX_CREATOR_USER_ID;
if (!key || !userId) {
	console.error("ROBLOX_API_KEY and ROBLOX_CREATOR_USER_ID must be set");
	process.exit(1);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function call(url, init = {}, tries = 5) {
	for (let attempt = 1; ; attempt++) {
		const res = await fetch(url, { ...init, headers: { "x-api-key": key, ...(init.headers ?? {}) } });
		if (res.ok) return res;
		const body = await res.text();
		// 429 and 5xx are worth retrying; anything else is a real error.
		if (attempt < tries && (res.status === 429 || res.status >= 500)) {
			await sleep(2000 * attempt);
			continue;
		}
		throw new Error(`${init.method ?? "GET"} ${url} -> ${res.status} ${body.slice(0, 300)}`);
	}
}

async function create(assetType, file, contentType, displayName, description) {
	const form = new FormData();
	form.append(
		"request",
		JSON.stringify({ assetType, displayName, description, creationContext: { creator: { userId: String(userId) } } }),
	);
	form.append("fileContent", new Blob([fs.readFileSync(file)], { type: contentType }), path.basename(file));
	const op = await (await call(`${API}/assets/v1/assets`, { method: "POST", body: form })).json();
	const opPath = op.path ?? `operations/${op.operationId}`;
	for (let i = 0; i < 60; i++) {
		const state = await (await call(`${API}/assets/v1/${opPath}`)).json();
		if (state.done) {
			if (state.error || !state.response?.assetId) throw new Error(`${displayName}: ${JSON.stringify(state.error ?? state)}`);
			return Number(state.response.assetId);
		}
		await sleep(Math.min(1000 * 2 ** Math.min(i, 3), 8000));
	}
	throw new Error(`${displayName}: operation ${opPath} not done after polling`);
}

// The decal's content is a small model whose Texture points at the image asset.
async function imageOf(decalId) {
	try {
		const { location } = await (await call(`${API}/asset-delivery-api/v1/assetId/${decalId}`)).json();
		const text = Buffer.from(await (await fetch(location)).arrayBuffer()).toString("latin1");
		const ids = [...text.matchAll(/(?:id=|rbxassetid:\/\/)(\d+)/g)].map((m) => Number(m[1])).filter((id) => id !== decalId);
		return ids[0] ?? null;
	} catch (err) {
		console.warn(`  image id for decal ${decalId} not resolved (${err.message}); the game resolves it at runtime`);
		return null;
	}
}

const manifest = JSON.parse(fs.readFileSync(MANIFEST, "utf8"));
const wanted = process.argv.slice(2).flatMap((a) => a.split(",")).map((s) => s.trim()).filter(Boolean);
for (const name of wanted) if (!manifest[name]) throw new Error(`unknown asset ${name}`);
const uploaded = fs.existsSync(OUT) ? JSON.parse(fs.readFileSync(OUT, "utf8")) : {};
const failed = [];

for (const name of Object.keys(manifest)) {
	if (wanted.length && !wanted.includes(name)) continue;
	const description = `Hundred Demon Night: ${name} (custom Blender model, tools/blender/night)`;
	try {
		console.log(`${name}: uploading model`);
		const model = await create("Model", path.join(FILES, `${name}.fbx`), "model/fbx", `HDN ${name}`, description);
		let decal = null;
		let texture = null;
		if (!UNTEXTURED.has(name)) {
			console.log(`${name}: uploading texture`);
			decal = await create("Decal", path.join(FILES, `${name}.png`), "image/png", `HDN ${name} texture`, description);
			texture = await imageOf(decal);
		}
		uploaded[name] = { model, decal, texture };
		fs.writeFileSync(OUT, JSON.stringify(uploaded, null, 2) + "\n"); // keep progress if a later asset fails
	} catch (err) {
		console.error(`${name}: FAILED ${err.message}`);
		failed.push(name);
	}
}

console.log("\nasset                     model            decal            texture");
for (const [name, u] of Object.entries(uploaded)) {
	console.log(`${name.padEnd(25)} ${String(u.model).padEnd(16)} ${String(u.decal).padEnd(16)} ${u.texture}`);
}
if (failed.length) {
	console.error(`\nFailed: ${failed.join(", ")}`);
	process.exit(1);
}
