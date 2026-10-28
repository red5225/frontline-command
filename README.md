# FRONTLINE COMMAND: ATLAS

**A Godot 4 country-scale operational strategy prototype.**

Frontline Command is a real-time, pauseable map strategy game set in an original fictional country inspired by rugged mountain-and-desert geography. You command field groups across 34 regions, issue movement orders, manage readiness and supply, and compete with an AI faction for territory.

## Playable systems

- Procedurally drawn country map with 34 named regions, province-like borders, capitals, route lines, terrain shading, and ownership colors.
- Selectable field groups and click-to-move orders through a generated region network.
- Pause, 1× / 2× / 4× simulation speed, a running clock, and a live operations log.
- Abstract control contests, occupation progress, readiness, supply, group strength, and region income.
- Opposing AI that issues its own movement orders and competes for unclaimed territory.
- Region intelligence panel, selected-group panel, territory counts, and supply overlay.
- Original SVG emblem and a procedural map renderer—no paid asset packs or external runtime downloads.

## Run locally

1. Install Godot 4.4 or newer.
2. Clone or download this repository.
3. Open project.godot in Godot Project Manager.
4. Press F6 to run the main scene, or press F5 to run the project.

## Controls

- Left click a group marker: select that field group.
- Left click a region: inspect region information.
- Select a field group, press ISSUE MOVEMENT ORDER, then click a destination region.
- Right click a region while a group is selected: quick movement order.
- Use HOLD POSITION to cancel a group's route.
- Use PAUSE / RESUME and the speed button to control simulation time.

Groups follow a route across adjacent regions. When opposing groups occupy the same region, a simplified control contest resolves using abstract strength, readiness, and supply values. No real-world unit doctrine, weapon specifications, or tactical procedures are modelled.

## Project structure

- scenes/main.tscn — project entry scene.
- scripts/main.gd — HUD, input handling, clock, and top-level game flow.
- scripts/map_view.gd — procedural map geometry, region hit testing, and map drawing.
- scripts/world_state.gd — region ownership, group movement, AI, supplies, and abstract contests.
- data/regions.json — the 34 fictional regions and their initial scenario data.
- assets/brand/ — original SVG emblem.
- tools/validate_data.py — lightweight data integrity checks.
- .github/workflows/build.yml — headless validation and downloadable source-project package.

## Map and scenario note

The map is an original illustrative game map, not a navigation product or an authoritative map of any real country. Region shapes are generated procedurally from the region centers and a hand-authored silhouette. Region names, factions, starting positions, and simulation values are fictional.

## Builds

Every push to main and every manual workflow run validates the project and uploads a ZIP of the Godot source project as a GitHub Actions artifact. The ZIP is a Godot project, not a standalone installer; open it in Godot to play or export it for your platform.

## License

The game code is MIT-licensed. See LICENSE. The included original SVG emblem is also provided under the MIT License.
