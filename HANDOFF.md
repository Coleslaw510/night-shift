# Night Shift — Handoff

Read this first. Any AI (Grok Bot, Manus, others) or human picking this up: update the
**Status** and **Progress** sections (and PROGRESS.md) at the end of every session.

## Vision
A goofy, slightly scary **co-op** first-person game for a few friends on PC (Windows + Mac).
The crew works the night shift at **one small 24-hour supermarket** (one normal-sized store,
NOT endless/procedural — players should stay near each other). You check out customers,
stock shelves, mess around with fun stuff (cart jousting, intercom, etc.), and later a
**funny-scary monster** wanders the store after hours — it's drawn to loud talkers.
**Proximity voice chat is a must-have** (and is part of the gameplay with the monster).
Look: dim late-night store, flickering fluorescents, dark windows, chunky colorful product
boxes, glowing freezer; stylized low-poly human customers. See `docs/concept/`.

## Tech stack
- Godot **4.4.1** stable, GDScript, **GL Compatibility** renderer (runs on older Macs/PCs).
- No external assets: everything is built in code from primitive meshes + materials.
- CI: GitHub Actions, `barichello/godot-ci:4.4.1` container → headless smoke test →
  Windows x86_64 `.exe` (embedded pck) + macOS universal `.app` (zip, ad-hoc signed,
  not notarized). Artifacts: `NightShift-Windows`, `NightShift-Mac`.

## Build / run
- Open the folder in Godot 4.4.1 and press F5. Main scene: `scenes/menu.tscn`.
- Smoke test: `godot --headless --import && godot --headless --script res://tests/smoke_test.gd`
  (fails CI on any `SCRIPT ERROR` line or non-zero exit).
- Screenshots: `xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --script res://tests/screenshot.gd`
  (writes to `user://` and prints the path).
- Export locally (needs export templates 4.4.1):
  `godot --headless --export-release "Windows Desktop" build/windows/NightShift.exe`
  `godot --headless --export-release "macOS" build/mac/NightShift-Mac.zip`
- CI runs on every push to `main`. Put `[skip ci]` in commit messages for WIP pushes.

## Folder map
- `project.godot` — settings, input map (WASD, Shift sprint, E/click interact, Space jump).
- `export_presets.cfg` — Windows + macOS presets.
- `scenes/menu.tscn` + `scripts/menu.gd` — main menu (Start Shift / Quit).
- `scenes/main.tscn` + `scripts/game.gd` — game controller: builds store, spawns player
  and customers, shift clock, earnings, pause + end-of-shift summary.
- `scripts/store_builder.gd` — builds the store geometry, lights, shelves, freezer, checkouts.
- `scripts/player.gd` — first-person controller + interact raycast.
- `scripts/customer.gd` — low-poly person, waypoint AI (enter → shop → queue → pay → leave).
- `scripts/register.gd` — checkout lane: queue, belt items, scanning, total, payment.
- `scripts/hud.gd` — HUD (NIGHT SHIFT + clock, $ earnings, crosshair, prompts, pause, summary).
- `scripts/products.gd` — product catalog (names, prices, colors).
- `tests/` — smoke test + screenshot script.
- `docs/concept/` — approved concept art (store.jpg, customer.jpg). Has `.gdignore`.

## Store layout (meters, origin at store center, +Z = front/entrance)
- Store 24 x 30 (x -12..12, z -15..15), ceiling 4.
- Shelf rows along Z at x = -8, -4, 0, 4, 8 spanning z -9..1. Aisle centers x = -10,-6,-2,2,6,10.
- Cross corridors: back z = -11 (freezer along back wall z ≈ -14), front z = 3.
- Checkout lanes: customer lane x = -6 and -2, counter at lane-1, cashier at lane-1.9,
  counters z 5..9. Entrance/exit doors at x = 7, z = 15.
- Customers path only along corridors (waypoints), so no navmesh is needed.

## Status
<!-- STATUS-START -->
- [x] (a) Repo + project skeleton + HANDOFF + CI
- [x] (b) Store layout + lighting + HUD
- [x] (c) Player movement
- [ ] (d) Customers
- [ ] (e) Register / checkout + earnings
- [ ] (f) Shift clock + summary + menu
<!-- STATUS-END -->

## Roadmap (after baseline)
1. **Multiplayer**: Godot high-level multiplayer (ENet/WebSocket), host + clients, synced
   players, customers (server-authoritative), registers, earnings. Join by **room code** via
   a small relay/room-code server on Cole's Oracle VM (free route, NO Steam).
2. **Proximity voice chat** (must-have): AudioEffectCapture → Opus-ish/PCM over the network,
   AudioStreamPlayer3D per player with distance falloff. Loudness feeds the monster later.
3. **Stocking shelves**: back-room pallets, carry boxes, shelves deplete as customers shop.
4. **Monster**: funny-scary thing that roams after a certain hour, hears loud voices.
5. **Fun extras**: cart pushing/jousting, PA intercom, mop/spills, weird customers, events.

## Notes for any AI picking this up
- Cole has limited usage: small focused steps, commit + push after each, `[skip ci]` on WIP.
- Keep everything original (no assets ripped from other games). Primitive meshes are fine.
- Keep the repo **private**. Ask Cole before publishing anything or spending money.
- Test locally with the headless smoke test before pushing; CI greps for `SCRIPT ERROR`.
- Mac builds are unsigned/not notarized — friends use right-click > Open or `xattr`.
