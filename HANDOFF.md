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
- iOS: CI job `ios` builds the unsigned IPA (artifact `NightShift-1.2.1-iOS-unsigned-ipa`) for sideloading (Signulous). Bundle ID com.coleslaw510.nightshift, iOS 16+. Build number 5.
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
- `project.godot`: settings and the input map (WASD, Shift sprint, Space jump, E/click interact (hold to stock), Q put a stock box back, Esc pause). Version 1.1.
- `export_presets.cfg`: Windows and macOS presets.
- `scenes/menu.tscn` + `scripts/menu.gd`: main menu (Start Shift / Quit, shows the version).
- `scenes/main.tscn` + `scripts/game.gd`: game controller. Builds the world and spawns the player, registers and customers. Runs the shift clock, the auto door and back door, trash fill, task hints, the cash-drawer flow, stats and the summary. Also the interact target for crates, the trash can, the dumpster, the back door and the gun locker. Test hooks are at the bottom.
- `scripts/store_builder.gd`: all geometry and lights for the store, stockroom, outside lot, fence, dumpster, cars and gun locker. Also holds the floor shader and the material cache.
- `scripts/shelves.gd` (`ShelfSystem`): shelf frames and stock slots (6 rows x 2 faces x 4 levels x 8 slots). Products are drawn with 2 MultiMeshes (boxes + labels). `take()` for customers, `place()` for the player, low-stock queries.
- `scripts/interact.gd` (`Interact`): generic collider that forwards `interact`/`get_prompt`/`hold_interact` to a target, with a `tag`.
- `scripts/player.gd`: first-person controller, empty-hand viewmodel, carrying (stock box / trash bag / cart), hold-to-use. `scripts/dropped_item.gd` is a box or bag left on the floor. `scripts/cart.gd` is a shopping cart. `scripts/vehicle.gd` is a lot car (park or fuel).
- `scripts/customer.gd`: low-poly person with hoodies/tees, hair styles, a simple face and a red basket. Runs the waypoint AI, waits for the player and other customers, gets annoyed when items are out of stock, and picks cash or card.
- `scripts/register.gd`: checkout lane with the queue, belt items, scanning, and payment (card tap, or cash with change counted in the HUD drawer). Money is in cents.
- `scripts/belt_item.gd`: scannable product on the belt.
- `scripts/hud.gd`: concept-style HUD, task hints, pause (with settings sliders), cash-drawer panel and the summary.
- `scripts/products.gd`: product catalog (shelf items vs freezer items).
- `scripts/sfx.gd`: all sounds synthesized in code (beep, cha-ching, chime, hum loop and more).
- `scripts/settings.gd`: mouse sensitivity and volume, saved to `user://settings.cfg`.
- `tests/smoke_test.gd`: headless test that also self-tests change math, stocking, the trash loop and the locker. `tests/screenshot.gd` renders the doc shots.
- `docs/concept/`: approved concept art. `docs/screenshot_*.png`: in-game renders.

## World layout (meters, +Z = front/entrance) — v1.2
- Store interior x -20..20, z -16 (back wall, `ZB`) .. 23 (glass storefront). Ceiling at 3.8.
- Shelf rows at x = -16, -12.6, -9.2, -5.8, -2.2, 2.2, 5.8, 9.2, 12.6, 16, spanning z -11..6. Wide center aisle at x = 0 looks at the freezer.
- Customer aisles: `StoreBuilder.AISLE_X`. Cross corridors at `FRONT_Z` 8.2 and `BACK_Z` -13.2.
- Freezer: glass-door case on the back wall, about 12 m wide.
- One checkout: counter at x 4.7, z ~14.5. The queue is at x 3.15 and folds sideways if it gets long (`QUEUE_HEAD_Z` / `QUEUE_MIN_Z`). Cashier stands on the +X side of the counter.
- Front automatic sliding door at x = 0 (z = 23). Glass storefront plus a left-wall window band.
- Stockroom: full width x -20..20, z -16..-34 (18 m deep). Lit only down the middle (two spotlights). Dark corners have empty racks. The employee entrance is a strip curtain in the left aisle (`STOCK_DOOR_X` -14.3), clear of the freezer. Gun locker is on the west wall. Back-office desk is just inside, toward the center. Swinging back door at x = 14, z = -34.
- Outside: lot fenced at x -42..42, z -48..48, with a driveway gap in the front fence (x -5..5). Parking rows at z 32 and 39.5. Cart corral at (-8, 28). Fuel bay at (32, 31), dark except the pump lights. Dumpster in the back lot.
- Trash can at (8.6, 19.2).

## Status
<!-- STATUS-START -->
### v1.2 (in progress)
- [x] Customer avoidance: they steer around each other and the player instead of freezing in contact. Queue spots are unique (the line folds instead of stacking on one point).
- [x] Failsafe: a customer who makes no progress in a state is nudged, rerouted, snapped to the register if they are first in line, or forced to leave. Patience still runs while they are blocked, so nobody waits forever.
- [x] One register and a bigger sales floor (10 shelf rows). Stockroom is full-width and 18 m deep, lit only in the middle, with dark corners. Fuel bay, cart corral and parking rows are built. Two cars sit in the lot until the driving AI lands.
- [x] No handheld scanner and no "BARCODE SCANNER" HUD. USE on a belt item or the register rings it up. USE on a matching shelf stocks; otherwise USE or Q drops the box or bag on the floor (`dropped_item.gd`). Nothing teleports home.
- [x] Shopping carts (`scripts/cart.gd`): eight start in the corral. Customers fetch one, and some abandon them in the lot. The player grabs (E or C), pushes, shoves, and can ride one up the rear ramp. Returning a player-moved cart to the corral pays $0.75.
- [x] Cars (`scripts/vehicle.gd`): shoppers drive in from the front gate, park, walk in, and drive off when they leave. About 30% of spawns are fuel customers. They stop under the pump lights. USE the car to hear a dollar amount or "fill it up", USE again to run the meter, USE to stop. Pay scales with accuracy. A pump gives up after 75s so the bay never sticks.
- [x] Shop (`data/economy.json`, `scripts/economy.gd`): back-office terminal and a pause-menu Shop button. Buys the locker key, ammo, flashlight (F), faster ring-up, double cart pay, stamina snacks (1 to eat), and vest colors. Sprint now uses a stamina bar.
- [x] Saves (`scripts/save_game.gd`): pause Save, autosave at shift end and on background/quit, version 2 with two backups. A version-1 file (`earnings` only, as from 1.1.1) migrates. Title screen is Continue / New Game.
- [x] Shotgun from the unlocked locker. G equips, R reloads, click or FIRE shoots the center of the screen. Muzzle flash and a synthesized shot. Practice cans and bottles out back and in the stockroom. The ray never hits a customer.
- [x] Touch HUD shrunk. No PUT BACK, no JUMP. RUN is a small button at the top left. Pause is top right and does not overlap it. CART, GUN, FIRE, LIGHT, and EAT show up only when they apply.
- [x] Headless sim (`tests/sim_test.gd`): several in-game minutes, customers all served, cars leave, a fuel job pays, a cart is returned, save/load and v1 migrate pass.
- Version is 1.2. iOS build number is 4. CI builds Windows, Mac, and the unsigned IPA on this branch.

### v1.2.1 (in progress)
- [x] Employee entrance is a real opening with a strip curtain on the back-left wall. The freezer no longer seals it. `tests/reach_test.gd` ray-checks the stockroom, back office, gun locker, back door, dumpster, front door, and fuel bay.
- [x] Performance: shelf price tags, the ceiling grid, fence posts, and shelf frames are batched (draw calls about 830 → about 520 on the desktop profile). Graphics presets live in the pause menu: Low / Medium / High / Ultra, a render-scale slider, an FPS cap (30 / 60 / unlimited), and an FPS counter. Low keeps about 10 lights, no MSAA, no bloom, a slightly thicker fog, and hides far shelf rows. iOS defaults to Low with a 60 FPS cap. Desktop defaults to High, with Ultra available. The choice is saved in `user://settings.cfg`.
- Version is 1.2.1. iOS build number is 5.

### v1.1.1 (iPhone)
- [x] Touch controls (`scripts/touch_controls.gd`), on automatically when `OS.has_feature("mobile")` (desktop testing: `godot -- --touch`). Left joystick moves, dragging the right side looks, and there are USE (hold to stock), PUT BACK, RUN toggle, JUMP and II pause buttons. Buttons inject InputEventActions. No mouse capture on mobile, and the mouse-click binding is removed from `interact` so emulated taps don't trigger USE.
- [x] Phone HUD: landscape only (`display/window/handheld/orientation=4`), safe-area margins (`Hud.safe_rect`), UI scale 1.3, scanner status moved to the top center.
- [x] Mobile preset (`game._setup_mobile`): no MSAA, 0.8 3D scale, 60 fps cap, lighter glow. Lights and materials are unchanged so the look stays.
- [x] iOS export preset (project-only Xcode export) and CI `ios` job: macos-15, Godot 4.4.1 plus the iOS template, xcodebuild unsigned arm64 → `NightShift-1.1.1.ipa`, Info.plist checks, and a simulator launch test (non-blocking).
- [x] App icon `icon.png` (1024, rendered from the game plus a neon title; Godot generates all sizes).
- [x] CI green: run 42341132892. `NightShift-1.1.1.ipa` is 25.0 MB (arm64, bundle ID com.coleslaw510.nightshift, MinimumOSVersion 16.0, landscape only).
- Known: the simulator smoke step fails at link time (`ld: framework 'MetalFX' not found` in the iphonesimulator SDK; Godot weak-links MetalFX). It's continue-on-error. Possible fix: strip `-weak_framework MetalFX` from OTHER_LDFLAGS for sim builds. The on-device test is untested (no device here).

### v1.1 (current)
- [x] Look matched to the concept art: warm dim lighting, a dark gridded ceiling with fluorescent strips (2 flicker), a tiled floor shader, packed colorful shelves with labels and price tags, a glowing freezer and "FREEZER AISLE ->" sign, beige boxy registers with belts, cardboard clutter, the scanner-in-hand viewmodel, and the concept-style HUD. See `docs/screenshot_1.1_interior.png`.
- [x] Customers restyled: hoodies or tees, jeans, sneakers, 5 hair styles, faces. They wait for the player and other customers instead of walking through them.
- [x] Stocking: shelves start partly stocked and deplete. Grab a crate in the stockroom (E), hold E on a matching shelf spot, Q puts it back. Out-of-stock items annoy customers. HUD shows LOW STOCK.
- [x] Trash: the can fills over time and with each sale. Carry the bag out the back door (or the front door) to the dumpster for a $1.50 bonus.
- [x] Doors: the automatic front sliding door opens for the player and customers (the invisible wall is gone). The swinging back door uses E.
- [x] Glass windows: storefront and left wall, see-through both ways. The outside lot has lamps, cars and a fence.
- [x] Making change: about 70% of customers pay cash, often over the total. The register screen shows TOTAL/CASH/CHANGE. E opens the cash drawer panel ($20…1¢), then GIVE CHANGE. Correct change can earn a tip. Short change brings a complaint (-$2). Over-giving loses you the extra. Card customers just need E.
- [x] Gun locker placeholder in the stockroom (shotgun behind glass, padlock): "LOCKED - For emergencies only".
- [x] Extras: synthesized hum and SFX, settings sliders in pause (mouse sensitivity, volume), and an expanded end-of-shift summary.

### v0.1 baseline
- [x] (a)-(f) skeleton/CI, store, player, customers, checkout, clock/summary/menu
- [x] v1.1 CI green: run 42336173236 (Windows zip 33 MB, Mac zip 58 MB)
- [ ] Next: multiplayer + proximity voice (Roadmap #1-2)
<!-- STATUS-END -->

### Known issues / rough edges (1.2)
- iPhone: touch tuning and frame rate are not playtested on real hardware. Unsigned IPA must be signed by the sideloader (Signulous).
- Customers are kinematic (waypoints plus steering). They sidestep the player and each other. A failsafe unsticks a state that stops making progress.
- A mid-shift save restores money, purchases, and the clock. It does not restore live customers, carts, or cars.
- The shotgun cannot hurt customers. Practice targets are the only thing it knocks over.
- Cars follow a short waypoint path and stop if you're in front of them. They creep past after a few seconds so a blocked lane doesn't last forever.
- iPhone touch layout is sized for landscape with the safe area, and has not been playtested on a device. The IPA is unsigned. The simulator link step can still fail on MetalFX (continue-on-error).
- Freezer items never run out (only aisle shelves are stockable).
- Product labels are colored stripes, not real text. Crate labels in the stockroom are text.
- Tuning (spawn 10-22 s, max 7 customers, patience 150 s, trash fill 150 s) has not been playtested.

## TODO: gun locker (for the monster update)
- The locker is built in `StoreBuilder._stockroom()` (node at the stockroom west wall, `out.locker` Interact with tag `{"kind": "locker"}`). The interaction is in `game.gd` `on_interact`/`get_prompt_for` → "locker".
- When the monster arrives, unlock it (e.g. after the monster first appears, or with a manager key). Swap the placeholder shotgun meshes for a pickup: `player.set_carry({"kind": "shotgun"})` plus a viewmodel and a fire raycast. Decide whether it is a stun/"broom" or a real gun for the tone.

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
