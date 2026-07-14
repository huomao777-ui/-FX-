# UI Architecture

Apply these rules when editing page controllers, popup controllers, drag interactions, list interactions, chart/K-line logic, and button state behavior.

## Core principles

- Do not hardcode the whole UI logic under one parent path.
- Do not assume a control must live forever under one exact parent.
- Allow scene artists/designers to move nodes in the editor without collapsing logic.
- Resolve nodes from a local feature root whenever possible.

## Node lookup order

1. Exported `NodePath`
2. Local functional root lookup
3. Old compatibility path only as a fallback

Do not let fallback logic overwrite a valid new-structure reference.

## Recommended controller split

- Page root controller: app entry/exit state, global coordination, cross-module forwarding, internal back handling
- Popup controller: only popup visibility and popup-local controls
- Drag/scroll controller: only drag, snapping, scrolling, gesture state
- List controller: only list generation, deletion, reordering, row state
- Status bar controller: only time, battery, Wi-Fi, signal display
- Data/system logic: keep in JSON, autoload systems, or gameplay systems rather than UI scripts

## Scene structure guidance

- Keep mobile shell, status bar, and APP content as separate feature areas.
- Give drag areas, popup areas, scroll areas, and action areas their own local roots.
- Prefer one lightweight APP root controller over a huge all-in-one interaction script.

## Interaction guidance

- Separate horizontal swipe state from vertical drag state.
- Use one refresh entry point per visual state cluster.
- Update whole button/card state, not only one label, unless the design explicitly calls for that.
- Keep popup code coupled only to the popup and its trigger controls.

## Typing and parsing

- Be explicit with types when reading `Dictionary`, JSON, or `Variant` values.
- Avoid inference patterns that cause Godot parser errors in typed code.

## Comments

Add comments for why the logic exists when behavior is non-obvious, especially for:
- snap behavior
- drag/gesture arbitration
- outside-click close logic
- editor-structure compatibility logic
- chart axis preservation and clearing behavior

Do not add comments that merely restate obvious assignments.
