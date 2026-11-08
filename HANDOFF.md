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
- iOS: CI job `ios` builds the unsigned IPA (artifact `NightShift-1.4.0-iOS-unsigned-ipa`) for sideloading (Signulous). Bundle ID com.coleslaw510.nightshift, iOS 16+. Build number 6.
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

### v1.4.0 (in progress)
- [x] Finite 32-round pistol reserve with automatic magazine reload.
- [x] Restored normal starting shelf stock; every catalog product has a visible back-room supply crate.
- [x] Darker stockroom and slower clown complaint pressure.
- [x] Fall recovery and storefront crash detection fixes.
- [x] ENet host/join lobby foundation with synchronized remote player avatars for PC/Mac/iOS.
- [x] Pre-fill the co-op address with the deployed VM server (`132.145.159.218`), while keeping it editable.
- [ ] Shared server-authoritative interactions, lobby readiness, voice chat, and deployed Night Shift VM service.

### v1.4.0 (in progress)
- [x] Expanded, darker back-room footprint with long rack rows for a sprawling restock area.
- [x] Monster prototype patrols the back rooms and can chase/attack the player. Shotgun hits remove it.
- [x] Shotgun can be picked up from the checkout counter as well as the back locker.
- [x] Shotgun targets customers and breaks their low-poly body into pieces.
- [x] iOS pause overlay keeps its pause button available so the menu can be closed.
- [x] Freezer aisle has an interact surface and open/close feedback.
- [x] Drivable parked cars with WASD steering; driving into the store reports crash damage.
- [x] Criminal shoppers can steal frozen/aisle goods and flee; the shotgun can stop them.
- [x] Freezer stock is finite, visible in the prompt, and replenished by opening then closing the freezer.

### v1.4.0
- [x] Low was dark because it kept about 10 omni lights (the center aisle, freezer, stockroom spots, and pumps) and turned the rest off, with ambient at 0.24 and no bloom. Side aisles had almost no light.
- [x] Every preset now shares the same base: warmer ambient, one directional fill, and an emissive sales-floor ceiling. Accent omnis, MSAA, and shadows are the only things higher presets add. A saved Brightness slider scales that base.
- [x] `tests/luminance_test.gd` renders the sales floor, stockroom, and lot at Low and High and checks average luminance.
- Version is 1.4.0. iOS build number is 6.

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
- Customers are kinematic (waypoints plus steering). They sidestep the player and each other, and each reserves their own cart so a crowd doesn't circle one basket. A failsafe unsticks a state that stops making progress. Movement is substepped so a long frame doesn't fling them.
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
- Keep the repo **private**. Ask Cole before publishing anything or spending money. The repository is temporarily public for this handoff; restore private visibility when convenient.
- Test locally with the headless smoke test before pushing; CI greps for `SCRIPT ERROR`.
- Mac builds are unsigned/not notarized — friends use right-click > Open or `xattr`.


## Official new direction: v1.5 — The Night Shift Works

This is now the official project plan. The project has many isolated features but does not yet have a reliable, understandable gameplay loop. The next goal is to make one complete, replayable shift work from start to finish, then build the horror and multiplayer systems around that loop.

### Core game fantasy

The crew must keep a failing supermarket operational until 6 AM while customer problems, stock shortages, messes, theft, vehicle incidents, and a clown gradually make the store unsafe. At all times the player should understand: what needs attention now, where to solve it, what happens if it is ignored, and what new danger that created.

The attached design idea is a direction, not a rigid specification: the crew restocks an endless 24-hour supermarket, pushes carts as a team, handles pallet orders against the clock, and creates noise that attracts something. The fixed store should become fun and reliable before procedural or endlessly looping backrooms are attempted.

### Core shift loop

Before the shift, give the crew a short checklist: restock three priority products, empty the trash, bring a required supply box from the backroom, inspect the freezer, and understand the available jobs of register, stocking, cleanup, and security.

During the shift, customers create competing problems. Shelves become empty, customers complain or leave, trash accumulates, criminals steal, cars arrive for fuel, the register queue grows, freezer stock needs attention, and noise, crashes, shooting, and neglected work increase danger. Every customer problem should either create a task, create money, or increase danger.

At 6 AM, show customers served, revenue and tips, products restocked, complaints, trash cleaned, theft stopped, store damage, clown encounters, and each teammate's contribution. Later shifts can increase customers, demand, theft, darkness, layout changes, and clown pressure.

## Step 1 — Restocking vertical slice: The Night Shift Works

This is the immediate next task and the acceptance gate for the next update. Do not expand the feature list until this flow works on desktop and iPhone controls.

1. Create one working milk pallet in the backroom.
2. Give it a large, forgiving interaction collider.
3. Make the player reliably take a visible milk box.
4. Walk the box from the backroom to the freezer.
5. Stock eight visible milk units.
6. Update a physical employee order board and the HUD.
7. Have at least one customer specifically request milk.
8. Pay or reward the player when the customer is served.
9. Increase clown pressure if the order is ignored.
10. Test the entire flow with desktop and touch controls.

A new player must be able to see the first order, find the correct supply pallet, take the correct box, find the correct shelf, stock it successfully, see the order complete, and understand the next task without documentation.

### Restocking redesign

Replace the current mixture of functional and decorative crates with clear supply pallets by category: dairy, frozen food, drinks, snacks, and household or produce. Each pallet needs a forgiving interaction zone, readable label, strong product color, visible quantity, and a marker when its product is needed.

A box should visibly represent a shipment such as `MILK BOX — 8 UNITS`. Stocking visibly removes units from the box and fills the shelf. Empty boxes can be dropped or returned. Prompts must say things like `[E] Take MILK BOX — 8 units — Needed on freezer aisle`, `[Hold E] Stock MILK — 6 / 12 — Box contains 8`, or `This shelf takes MILK. You are carrying CHIPS.`

When an order is active, show a route marker to the supply pallet and then to the destination shelf. Never make the player guess where the requested item is.

### Order board and task clarity

Add a physical employee order board in the backroom and mirror it in the HUD. Orders are finite and actionable, such as restock milk 0/8, restock frozen pizza 0/6, restock soda 0/10, empty trash, serve five customers, and check freezer temperature. Orders should respond to actual demand. Completion updates the board, HUD, sounds, money, and clown pressure.

### Customer redesign

Customers need readable states and personalities: normal shopper, impatient shopper, parent with a cart, suspicious shopper, criminal, fuel customer, and unhappy customer who can report the store. Communicate whether a customer is searching, waiting, angry, stealing, leaving, or reporting. Every customer problem must create work, money, or danger.

### Clown director

The clown is the consequence of poor store management, not a random enemy. Pressure rises from unhappy customers, incomplete orders, theft, full trash, loud crashes, and shooting inside the store. It falls for completed orders, correct service, cleaning, and quiet periods.

Do not show generic warnings such as `something is moving`. Use distant laughter, a squeaky wheel, a freezer door opening, flickering lights, balloons, missing products, or rearranged aisles. Spawn the clown where work was neglected: backroom for ignored restocking, storefront for ignored customers, rear lot for trash or cars, or freezer aisle for frozen-stock neglect.

### Store usability and atmosphere

The backroom should be dark and frightening but usable. Use dim overall illumination, brighter lights over interactable pallets, flickering fixtures, emergency lights near exits, flashlight visibility, and readable labels. Add a functional order board, supply pallets, broom station, employee lockers, emergency item station, clown hiding spaces, and clear routes to the sales floor.

The sales floor should have clear aisle signage, stronger product categories, a central problem-board view, visible queue buildup, a freezer that visibly shows stock, and intentional customer and cart activity.

### Equipment simplification

Use two conceptual inventory slots: a work item such as a stock box, trash bag, broom, or cart handle; and an emergency item such as a pistol, flashlight, and later keys or camera. The pistol is a defensive last resort, not the main activity. Shooting customers creates serious consequences such as complaint pressure, store damage, and a lower shift score.

### Multiplayer direction

The current ENet layer synchronizes avatars but game state remains mostly local. After the single-player vertical slice, make the server authoritative for customer spawning and state, shelf and pallet quantities, orders, money, complaints, clown pressure, shift clock, vehicles, and criminals. Clients send intentions such as taking, stocking, serving, opening, or cleaning; the server validates and broadcasts the result.

The first meaningful multiplayer acceptance test is: two players join, see each other and the same customers, one removes a box from a pallet, the other sees the quantity change, both see the shelf refill, and both see the order complete. Voice chat, matchmaking, and advanced lobby features wait until this works.

## Planned update sequence

### v1.5 — The Night Shift Works

Must-have: fix crate pickup and backroom access; remove decorative/functional crate confusion; add large pallet interaction colliders; add clear labels and quantities; add the order board; add task markers; add a reliable stockroom-to-shelf workflow; add reliable freezer restocking; add a tutorial shift; add end-of-shift evaluation; make customers generate visible orders; and make clown pressure respond to actual failures. The acceptance gate is the complete milk order flow on desktop and iPhone without documentation.

### v1.6 — The Store Fights Back

Add more customer types, polished stealing, visible persistent store damage, clown director encounters, scripted aisle or layout changes, better sound cues, breakable lights, temporary blackouts, broom cleanup as a recurring task, and more meaningful carts and deliveries.

### v1.7 — Crew Shift

Add server-authoritative shared inventory and orders, customer state, money, complaints, clown pressure, the clock, vehicles, and criminals. Add a lobby ready screen, suggested roles of register, stock, cleanup, and security, reconnect handling, and a shift result screen showing each player's contribution.

### v1.8 — Endless Store

Only after the fixed-store loop is fun: rearrange aisles between shifts, randomize backroom layouts and delivery locations, add multiple store layouts, new clown behaviors, and semi-endless progression. Do not build endlessly looping backrooms before the fixed-store restocking loop is reliable.

### Temporarily postponed

Do not prioritize voice chat, fully drivable cars inside the store, complex shop upgrades, a large weapon system, multiple monster types, procedural endless backrooms, detailed vehicle damage, decorative prop expansion, or additional customer animations until the v1.5 acceptance gate passes.

## Continuation checklist for the next bot

Read this section first when resuming. Start by reproducing the milk restocking vertical slice. Inspect `scripts/store_builder.gd`, `scripts/game.gd`, `scripts/shelves.gd`, `scripts/player.gd`, `scripts/hud.gd`, and `scripts/interact.gd`. Preserve the smoke, reachability, luminance, and simulation tests. Update `PROGRESS.md` and this handoff after each meaningful checkpoint. Do not start multiplayer authority work or procedural backrooms until the v1.5 restocking acceptance test passes.

## Project tracker

The official planning repository is [Coleslaw510/night-shift-tracker](https://github.com/Coleslaw510/night-shift-tracker). Read its `README.md` and `ROADMAP.md`, then check the open issues before beginning work. The first issue is the milk restocking vertical slice.

## v1.5 Step 1 checkpoint — milk restocking vertical slice

Checkpoint 1 is implemented and locally passing. `Products.CATALOG[12]` is Milk and it is part of the frozen catalog. `StoreBuilder._stockroom()` now creates a dedicated, visible Milk pallet near the employee entrance with a large `supply_pallet` interaction target, plus a physical order board. `game.gd` starts a milk order at 0/8, gives the player an eight-unit milk box, advances the order one unit per freezer interaction, updates the physical board and HUD, and unlocks one deterministic non-criminal milk-requesting customer after all eight units are stocked. A completed paid milk customer receives a bonus and reduces complaint pressure. The dedicated acceptance test is `tests/restock_test.gd` and currently passes with `RESTOCK: done ok=true`.

Next work: confirm the pushed GitHub Actions run is green, then tune the task markers and clown-pressure consequence based on device playtesting. Do not start v1.6 or deeper multiplayer authority work until the milk flow is confirmed on an iPhone.
