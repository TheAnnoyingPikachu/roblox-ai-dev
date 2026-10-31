// Expected contents of a built place, derived from a Rojo project file: every keyed node of the
// tree must exist, and every node mapped with $path must hold at least as many scripts as there
// are .luau/.lua files under that path. Used before upload (check-place.mjs on the built file)
// and after publish (verify-publish.mjs, through Open Cloud Luau execution on the new version).
import { readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join } from "node:path";

export function countScripts(path) {
  const st = statSync(path);
  if (st.isFile()) return /\.luau?$/.test(path) ? 1 : 0;
  let n = 0;
  for (const name of readdirSync(path)) n += countScripts(join(path, name));
  return n;
}

export function expectations(projectFile) {
  const project = JSON.parse(readFileSync(projectFile, "utf8"));
  const root = dirname(projectFile);
  const out = [];
  const walk = (node, path) => {
    for (const [key, child] of Object.entries(node)) {
      if (key.startsWith("$") || typeof child !== "object" || child === null) continue;
      const here = [...path, key];
      const entry = { path: here };
      if (typeof child.$path === "string") {
        const scripts = countScripts(join(root, child.$path));
        if (scripts > 0) entry.scripts = scripts;
        if (/BuildInfo\.txt$/.test(child.$path)) entry.stamp = true;
      }
      out.push(entry);
      walk(child, here);
    }
  };
  walk(project.tree, []);
  return { project: project.name, expect: out };
}
