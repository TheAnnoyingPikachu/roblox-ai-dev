#!/usr/bin/env node
// node tools/check-scope.mjs <base-ref>
// Scoped tasks (PIPE-002): a PR may only change files listed in the `files` of the task files it
// changes (plus those task files, their specs and tests/run.luau). CLAUDE.md rule 1 as a check:
// a PR that changes no task file fails. A PR whose changed tasks are all legacy (no `files`,
// studio/legacy-unscoped.txt) is reported but not blocked; with any scoped task it is enforced.
// Renames count as a delete plus an add, so both paths are checked.
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";

export function globToRegExp(glob) {
  if (glob.endsWith("/")) glob += "**";
  let re = "";
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === "*" && glob[i + 1] === "*") {
      i++;
      if (glob[i + 1] === "/") {
        re += "(?:.*/)?"; // "**/" matches zero or more whole folders
        i++;
      } else re += ".*";
    } else if (c === "*") re += "[^/]*";
    else if (c === "?") re += "[^/]";
    else re += c.replace(/[.+^${}()|[\]\\]/g, "\\$&");
  }
  return new RegExp(`^${re}$`);
}

// Returns { ok, outside, legacy, tasks } for a list of changed paths and a task loader.
export function checkScope(changed, loadTask) {
  const taskFiles = changed.filter((f) => /^studio\/tasks\/[A-Z]+-\d+\.json$/.test(f));
  const tasks = taskFiles.map((f) => ({ file: f, task: loadTask(f) })).filter((t) => t.task);
  if (tasks.length === 0) return { ok: false, reason: "no task file changed (CLAUDE.md rule 1)", outside: changed };
  const legacy = tasks.filter((t) => !Array.isArray(t.task.files)).map((t) => t.task.task_id);
  // Scope is relaxed only when every changed task is legacy; one scoped task enforces its files.
  const allLegacy = legacy.length === tasks.length;
  const allowed = [];
  for (const { file, task } of tasks) {
    allowed.push(globToRegExp(file));
    for (const f of task.files ?? []) allowed.push(globToRegExp(f));
    for (const spec of task.tests ?? []) allowed.push(globToRegExp(`tests/${spec}`));
    if ((task.tests ?? []).length) allowed.push(globToRegExp("tests/run.luau"));
  }
  const outside = changed.filter((f) => !allowed.some((re) => re.test(f)));
  return { ok: outside.length === 0 || allLegacy, allLegacy, outside, legacy, tasks: tasks.map((t) => t.task.task_id) };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const base = process.argv[2];
  if (!base) {
    console.error("usage: node tools/check-scope.mjs <base-ref>");
    process.exit(2);
  }
  const changed = execFileSync("git", ["diff", "--name-only", "--no-renames", `${base}...HEAD`]).toString().split("\n").filter(Boolean);
  const result = checkScope(changed, (f) => (existsSync(f) ? JSON.parse(readFileSync(f, "utf8")) : null));
  if (result.reason) {
    console.error(`::error title=Task scope::${result.reason}`);
    process.exit(1);
  }
  console.log(`Tasks in this PR: ${result.tasks.join(", ")}`);
  if (result.legacy.length)
    console.log(
      `::notice title=Task scope::${result.legacy.join(", ")} has no files list${result.allLegacy ? ", so scope is not enforced" : ""}. Add files and tests to it.`,
    );
  for (const f of result.outside) console.log(`${result.allLegacy ? "::warning" : "::error"} title=Task scope::${f} is outside the files of ${result.tasks.join(", ")}`);
  if (!result.ok) process.exit(1);
  console.log(result.outside.length ? "Scope not enforced (legacy task)." : `All ${changed.length} changed files are in scope.`);
}
