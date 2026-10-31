#!/usr/bin/env node
// Validates studio/tasks/*.json against studio/task.schema.json without external deps.
// Supports the subset of JSON Schema the task schema uses, plus cross-file checks:
// unique task ids, file name matches task_id, and every dependency exists.
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const schema = JSON.parse(readFileSync("studio/task.schema.json", "utf8"));
const dir = "studio/tasks";
const errors = [];
const tasks = new Map();
// Tasks written before scoped tasks; every other task needs `files` and `tests` (PIPE-002).
const legacy = new Set(
  readFileSync("studio/legacy-unscoped.txt", "utf8")
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith("#")),
);
const runner = readFileSync("tests/run.luau", "utf8");

function check(value, rule, path) {
  if (rule.enum && !rule.enum.includes(value)) errors.push(`${path}: must be one of ${rule.enum.join(", ")}`);
  if (rule.type === "string") {
    if (typeof value !== "string") return errors.push(`${path}: must be a string`);
    if (rule.minLength && value.length < rule.minLength) errors.push(`${path}: too short`);
    if (rule.pattern && !new RegExp(rule.pattern).test(value)) errors.push(`${path}: must match ${rule.pattern}`);
  }
  if (rule.type === "array") {
    if (!Array.isArray(value)) return errors.push(`${path}: must be an array`);
    if (rule.minItems && value.length < rule.minItems) errors.push(`${path}: needs at least ${rule.minItems} item(s)`);
    value.forEach((item, i) => check(item, rule.items, `${path}[${i}]`));
  }
}

for (const file of readdirSync(dir).filter((f) => f.endsWith(".json"))) {
  let task;
  try {
    task = JSON.parse(readFileSync(join(dir, file), "utf8"));
  } catch (e) {
    errors.push(`${file}: invalid JSON (${e.message})`);
    continue;
  }
  for (const key of schema.required) if (!(key in task)) errors.push(`${file}: missing ${key}`);
  for (const key of Object.keys(task)) {
    if (!schema.properties[key]) errors.push(`${file}: unexpected field ${key}`);
    else check(task[key], schema.properties[key], `${file}.${key}`);
  }
  if (`${task.task_id}.json` !== file) errors.push(`${file}: file name must be ${task.task_id}.json`);
  if (tasks.has(task.task_id)) errors.push(`${file}: duplicate task_id ${task.task_id}`);
  if (task.status === "accepted" && !(task.evidence?.length > 0)) errors.push(`${file}: accepted tasks need evidence`);
  if (task.verifier && task.verifier === task.owner) errors.push(`${file}: owner cannot verify its own task`);
  if (!legacy.has(task.task_id)) {
    if (!("files" in task)) errors.push(`${file}: missing files (the exact files this task may change)`);
    if (!("tests" in task)) errors.push(`${file}: missing tests (spec files that must pass; [] for docs only)`);
  } else if ("files" in task) {
    errors.push(`${file}: has files, so remove ${task.task_id} from studio/legacy-unscoped.txt`);
  }
  for (const f of task.files ?? []) if (f.split("/").includes("..")) errors.push(`${file}: files entry ${f} uses ..`);
  // Once work is in review, its specs must exist and be registered with the runner.
  if (["in_review", "accepted"].includes(task.status))
    for (const spec of task.tests ?? []) {
      if (!existsSync(join("tests", spec))) errors.push(`${file}: tests entry ${spec} does not exist in tests/`);
      else if (!runner.includes(`["${spec}"]`)) errors.push(`${file}: ${spec} is not registered in tests/run.luau`);
    }
  tasks.set(task.task_id, task);
}

for (const [id, task] of tasks)
  for (const dep of task.dependencies ?? []) if (!tasks.has(dep)) errors.push(`${id}: unknown dependency ${dep}`);
for (const id of legacy) if (!tasks.has(id)) errors.push(`studio/legacy-unscoped.txt: unknown task ${id}`);

if (errors.length) {
  console.error(errors.map((e) => `ERROR ${e}`).join("\n"));
  process.exit(1);
}
console.log(`${tasks.size} task file(s) valid`);
