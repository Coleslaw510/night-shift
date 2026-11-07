# Progress

## v1.3.0: **in progress**
The first playable v1.3 slice adds the larger dark back room, monster patrol/chase, customer hit reactions, checkout shotgun access, freezer interaction, and the iOS pause close fix. Vehicle driving, criminal AI, and a deeper freezer inventory loop remain next.

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
