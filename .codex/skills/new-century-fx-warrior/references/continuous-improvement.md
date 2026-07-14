# Continuous Improvement

Use this reference when the user reports that prior work caused a bug, parse error, workflow miss, or repeated avoidable mistake.

## Goal

Turn each meaningful failure into a repo-specific process improvement.

## Mandatory response pattern

1. Identify the actual failure mode, not just the surface error.
2. State whether it was a code bug, scene-editing process bug, validation miss, or workflow miss.
3. Add or tighten one project rule so the same class of failure is less likely.
4. Update `AI更新日志.md` with the corrective work if no immediate Git commit already captures it.
5. Prefer a small commit once the repo is back in a stable state.

## What must be fed back into the skill

Add or refine a rule when the failure involves:
- Godot parser errors caused by editing method
- recurring node-path coupling issues
- repeated typed-GDScript parser mistakes
- missing validation steps before reporting done
- Git/logging workflow drift
- any user correction that reveals a durable repo preference

## Good updates

- Convert a vague preference into a hard rule.
- Convert a one-off failure into a detectable warning sign.
- Add a recovery rule when a failure class is expensive.
- Keep the rule specific to the repo and the actual mistake.

## Avoid

- Logging blame without changing process
- Adding generic fluff that does not alter future behavior
- Expanding the skill with unrelated material after a failure

## Current known lessons for this repo

- `财经报.tscn`-class scenes are high risk and should default to script-first, scene-last handling.
- User-reported scene parse failures require immediate recovery mode, not continued feature edits.
- Tool or terminal mojibake around Chinese Godot resources is a stop signal, not a cosmetic issue.
- Stable project progress here benefits from frequent log updates and smaller Git checkpoints.
