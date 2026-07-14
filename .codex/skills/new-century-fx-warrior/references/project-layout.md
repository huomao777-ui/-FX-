# Project Layout

Use this layout when deciding where new files belong.

## Top-level intent

- `核心/`: global runtime abilities, autoload entry points, cross-system services
- `玩法/`: gameplay and domain systems such as player, world, time, trading, events, NPCs
- `界面/`: UI scenes, UI components, and page-specific assets/scripts
- `资源/`: reusable cross-module assets such as fonts, common materials, common sounds
- `沙盒/`: experiments, tests, temporary prototypes, validation scenes

## Placement rules

- Reusable UI component scripts go in `界面/组件/`
- Page-specific UI scenes and scripts go in `界面/场景/<页面>/`
- New app pages should keep their page-local assets with the page when practical
- New global/autoload services belong in `核心/自动加载/` or `核心/系统/`
- New gameplay systems belong under `玩法/<系统名>/`
- Temporary proof-of-concepts belong in `沙盒/` until intentionally promoted

## Godot-specific notes

- Prefer moving Godot resources inside the editor when possible so references stay healthy.
- Chinese directories are normal in this repo; treat path edits carefully.
- Do not silently migrate sandbox artifacts into production directories.

## News / FX page guidance

- Mobile-app-internal pages should usually live under `界面/场景/`
- Feature-specific controllers should stay near the page they serve
- Shared phone/status helpers should remain reusable rather than duplicated into each page
