# Git Workflow

Apply this when the user asks to commit, push, publish, or "upload to Git".

## Standard flow

1. Check `git status`
2. Confirm sensitive or generated files are not being staged unintentionally
3. Stage intentionally
4. Use the latest suitable title from `AI更新日志.md` when that file is the local convention for commit naming
5. Commit
6. Push
7. Re-check `git status`

## Never commit by accident

Watch for:
- `.env.github`
- `.godot/`
- `.godot-codex-user/`
- `*.log`
- `tmp_*`
- any credentials or tokens

## Logging convention

If Git cannot be used immediately, update `AI更新日志.md` with:
- version number
- suggested commit title
- changed scope
- main changes
- known limitations or remaining work

## Rhythm

- Prefer small commits after each stable milestone.
- Do not wait for a giant batch if the current state is already coherent.
- Avoid mixing unrelated fixes into one commit when a narrower scope is available.

## Network note

Local edits, validation, and local commits do not require pausing for GitHub connectivity.
Push/pull/API work may require the user's network or VPN setup.
