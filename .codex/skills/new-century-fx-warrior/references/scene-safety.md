# Scene Safety

Apply these rules to `.tscn`, `.tres`, and `.theme` files.

## Risk model

Treat large Godot text resources as structured assets, not normal prose files.
High-risk signals:
- many nodes in one file
- Chinese node names or exported property names
- popup-heavy UI trees
- scene files already known to have recovery copies or parse history

## Safe editing order

1. Confirm the current scene opens before editing.
2. Prefer script-only solutions first.
3. If scene text must change, prefer ASCII-only pinpoint edits.
4. Make one narrow change at a time.
5. Revalidate before doing the next risky edit.

## Allowed patterns

### Low risk

- ASCII-only replacements such as:
  - `visible = true/false`
  - `mouse_filter = ...`
  - `flat = true`
  - `text = "<"` or `text = ">"`
  - `theme_override_styles/...`
  - `custom_minimum_size = Vector2(...)`
- Adding or changing one clearly bounded property line when the surrounding block is stable

### Medium risk

- Replacing one fully bounded node block after confirming exact start/end lines
- Adding a single `script = ExtResource("...")` line to an existing node when the resource header is already stable
- Adding one new `ext_resource` entry when done without rewriting the rest of the file

## Forbidden patterns

- Whole-file read/write for `.tscn`
- `Get-Content` + `Set-Content` style rewrites on scene resources
- Copying garbled terminal text back into the file
- Editing Chinese `parent="..."` paths manually unless the exact original bytes are trusted
- Continuing feature work after the scene starts failing to parse

## Known failure signatures

### `Expected '['` on line 1

Likely causes:
- UTF-8 BOM was introduced
- file header bytes were damaged

### `Expected '=' after identifier`

Likely causes:
- broken node header
- broken quoted property name
- multiline string or quote damage on the previous line

### parse errors on unrelated nearby lines

Likely causes:
- missing quote earlier
- malformed node block header
- text line split across lines

## Recovery procedure

1. Stop editing the broken scene.
2. Keep the broken copy for comparison only.
3. Restore a known-good openable copy.
4. Reapply only the intended minimal change.
5. If the same edit remains risky, switch to user-manual attachment in the editor.

## Encoding rules

- Use UTF-8 without BOM for Godot text resources.
- Do not trust terminal-rendered Chinese output as an authoritative patch source.
- If encoding confidence is not high, do not automate the scene edit.
