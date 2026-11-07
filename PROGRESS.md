# Progress

## v1.2.1: **80%**
Stockroom door is open. Draw calls are down and the pause menu has graphics presets. Next: version bump and the one CI build. iOS defaults to Low (10 lights, no MSAA, 0.7 scale, 60 FPS cap).

## v1.2: **100%**
Shipped. One register, bigger store, no scanner, carts, cars, fuel, shop, saves, shotgun, and a smaller touch HUD. `tests/sim_test.gd` covers customers, cars, fuel, carts, and save migration.

## v1.1.1 (iPhone): **100%**
Touch controls, phone HUD, mobile preset, icon, iOS preset and the CI job are written and tested headless (desktop + `--touch`). CI run 42341132892 is green. Unsigned IPA is 25.0 MB (arm64, iOS 16+). The simulator launch test can't link (no MetalFX in the simulator SDK), so it isn't used, and the IPA was checked structurally instead.

## v1.1: 100%
## v0.1 baseline: 100%
