# Progress
## v1.4.0: **in progress**
The maintenance slice restores normal starting stock, gives the pistol a 32-round reserve with automatic reload, slows clown pressure, darkens the stockroom, adds fall recovery, and makes storefront crash detection trigger before the glass collision blocks the car. The first multiplayer slice is now in the project: ENet host/join UI, a four-player room limit, headless `--server` mode, command-line `--join=ADDRESS`, synchronized remote player avatars, and a pre-filled deployed server address (`132.145.159.218`). Local smoke tests and a real local host/client connection pass. The VM is deployed separately from Minecraft/Bedwars. Next: shared server-authoritative interactions, lobby readiness, and voice/lobby polish.

## v1.3.0: **in progress**
The first playable v1.3 slice adds the larger dark back room, monster patrol/chase, customer hit reactions, checkout shotgun access, freezer interaction, and the iOS pause close fix. Cars can now be entered and driven, crashes report store damage, criminal shoppers flee with stolen goods, and freezer items are finite and refillable. Multiplayer/proximity voice and deeper store-damage persistence remain future work.

## v1.2.2: **100%**
The sales floor stays readable on Low. Brightness comes from ambient, one fill light, and a glowing ceiling, not from a pile of omni lights. A Brightness slider is saved with the other graphics settings.

## v1.2.1: **100%**
Stockroom curtain is open and covered by a reach test. Draw calls dropped from about 830 to about 520, and iOS defaults to the Low graphics preset (10 lights, no MSAA, 0.7 render scale, 60 FPS cap). Desktop defaults to High.

## v1.2: **100%**
Shipped. One register, bigger store, no scanner, carts, cars, fuel, shop, saves, shotgun, and a smaller touch HUD. `tests/sim_test.gd` covers customers, cars, fuel, carts, and save migration.

## v1.1.1 (iPhone): **100%**
Touch controls, phone HUD, mobile preset, icon, iOS preset and the CI job are written and tested headless (desktop + `--touch`). CI run 42341132892 is green. Unsigned IPA is 25.0 MB (arm64, iOS 16+). The simulator launch test can't link (no MetalFX in the simulator SDK), so it isn't used, and the IPA was checked structurally instead.

## v1.1: 100%
## v0.1 baseline: 100%
