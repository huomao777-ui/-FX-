---
name: new-century-fx-warrior
description: Project-specific workflow for the New Century FX Warrior Godot repository. Use for any task in this repo, especially when modifying Godot scene resources (.tscn/.tres/.theme), mobile-phone UI pages, FX/news app screens, project file placement, project-specific script architecture, or Git/update-log workflow. Enforce scene-safe editing, UI node decoupling, repo layout rules, continuous error feedback, and the local Git/logging conventions before making changes.
---

# New Century FX Warrior

Follow this skill whenever you work in this repository.

## Start Here

1. Classify the task first:
- `scene-resource`: editing `.tscn`, `.tres`, `.theme`, or attaching scripts to scene nodes
- `ui-script`: editing page controllers, popup logic, drag/scroll interactions, node lookup logic
- `repo-structure`: adding new files, modules, scenes, assets, or data
- `git-publish`: staging, committing, pushing, or updating the project log
- `error-followup`: the user reports a parse error, runtime error, regression, or process failure caused by prior work

2. For programming or implementation tasks, use a fixed communication order before coding:
- Confirm the request and restate the requirement first
- Explain the implementation approach second
- Explain the validation approach third
- State whether this round should include Git commit/push
- After the work, explicitly report whether Git commit/push actually happened successfully
- Do not force this rigid structure onto non-programming discussion tasks unless the user asks for it

3. Load the matching references before editing:
- For `scene-resource`, read [references/scene-safety.md](references/scene-safety.md)
- For `ui-script`, read [references/ui-architecture.md](references/ui-architecture.md)
- For `repo-structure`, read [references/project-layout.md](references/project-layout.md)
- For `git-publish`, read [references/git-workflow.md](references/git-workflow.md)
- For `error-followup`, read [references/continuous-improvement.md](references/continuous-improvement.md)

4. Treat Godot scene-resource work as high risk by default.
5. Favor script-only changes when they satisfy the request.
6. If a scene parse/load error appears, switch to recovery mode immediately.

## Hard Rules

- Never treat `.tscn` as an ordinary text file that is safe to rewrite wholesale.
- Never use full-file read/write patterns on Godot text resources unless the edit is ASCII-only, encoding-safe, and backed by a recoverable baseline.
- Never continue adding new scene changes after a parse error appears.
- Never copy mojibake text from terminal output back into a Godot resource.
- Never assume Chinese node names, Chinese paths, or Chinese exported property names are safe manual edit targets.
- Prefer user-manual scene attachment over risky automated scene rewrites when the functional benefit is small.
- After every user-reported failure that traces back to prior work, update the project skill or its references so the same class of mistake is less likely to recur.
- After every stable, meaningful work step, update `AI更新日志.md` unless an immediate Git commit already records the same scope and the user does not rely on the log as the active handoff surface.
- When the repo is in a stable state and the user wants changes preserved, prefer small, prompt Git commits instead of batching unrelated work.

## Decision Rules

### Scene edits

- If the request can be solved with a new `.gd` file and a manual attach step, prefer that.
- If only one or two ASCII-safe lines need changing in a `.tscn`, do the smallest possible patch.
- If the scene is untracked or lacks an obvious recovery path, be extra conservative.
- If there are already multiple syntax errors or mixed parse failures, stop editing the broken file and recover from a known-good copy first.

### UI scripts

- Resolve nodes from the nearest feature root, not from a giant absolute path.
- Keep drag, popup, list, chart, and button-state logic in separate controllers when possible.
- Use page root controllers only for cross-module coordination and internal-back routing.
- Prefer explicit typed variables and narrow responsibilities.

### Repo structure

- Put reusable UI components in `界面/组件/`.
- Put page-specific scenes and scripts under `界面/场景/<page>/`.
- Put global systems under `核心/`.
- Put gameplay/domain systems under `玩法/`.
- Put temporary experiments under `沙盒/` and avoid promoting them silently into production structure.

### Git and logging

- When the user asks to publish, follow the local Git workflow and check ignore-sensitive files first.
- Even when the user does not explicitly ask, prefer timely commits after stable milestones rather than piling up risky changes.
- If Git cannot be used immediately, update `AI更新日志.md` with a clear versioned entry describing the work and a suggested commit title.

## Recovery Mode

Enter recovery mode immediately if any of these happen:
- Godot reports a scene parse error
- A `.tscn` line 1 error suggests BOM or encoding damage
- Multiple different syntax errors appear while editing the same scene
- Terminal output for targeted Chinese scene content becomes garbled and you need to patch the same region again
- The user reports that a recent change broke scene loading, script parsing, or expected interaction behavior

In recovery mode:
1. Stop new feature edits on that surface.
2. Preserve the broken file only for comparison.
3. Recover a known-good openable baseline.
4. Reapply only the minimum intended change.
5. Record the failure pattern in the continuous-improvement reference if it is new.
6. Prefer manual editor hookup for scene-script attachment if the previous automated path proved fragile.

## Output Expectations

When reporting work on this repo:
- For programming tasks, keep the communication order stable: requirement confirmation, implementation approach, validation approach, Git plan, then actual outcome.
- For programming tasks, explicitly state whether this round required Git and whether Git commit/push succeeded.
- For non-programming tasks, keep the response lighter unless the user wants the same structure.
- State whether you changed scripts only or also touched scene resources.
- If a risky scene file was involved, mention validation status explicitly.
- If you avoided a scene edit by design, say so plainly.
- If a user-reported failure led to a new process rule, mention that the skill was updated.
