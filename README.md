# Night Shift (v1.4.0)

Work the night shift at a creepy little 24-hour supermarket. One register, a bigger
aisle, carts, a parking lot, and a fuel bay out back of the lights. (Single player for now.)

## Controls
- WASD move · Mouse look · Shift sprint (uses stamina) · Space jump
- E or left-click: use. Hold E on a shelf to stock. E drops whatever you're holding if you aren't looking at a shelf.
- Q: drop what you're holding · C: grab or drop a cart · G: equip or holster the shotgun · R: reload · F: flashlight · 1: eat a snack
- E near a parked car: drive it · WASD steers while driving · E exits
- Esc: pause (Save, Shop, and settings)

## Windows
1. Unzip `NightShift-1.4.0-Windows.zip`.
2. Double-click `NightShift.exe`. If SmartScreen warns you, click **More info → Run anyway**.

## Mac
1. Unzip `NightShift-1.4.0-Mac.zip` to get `Night Shift.app` (drag it to Applications if you like).
2. The first time, **right-click the app → Open → Open** (macOS blocks unsigned apps otherwise).
3. If macOS says the app is "damaged", open Terminal and run:
   `xattr -dr com.apple.quarantine "/path/to/Night Shift.app"`
   (tip: type `xattr -dr com.apple.quarantine ` then drag the app into the Terminal window).

## Co-op multiplayer foundation

Night Shift now includes a Godot ENet co-op foundation for PC, Mac, and iOS. Use **Host Co-op** to create a four-player room, or enter a server address and use **Join Co-op**. The current foundation synchronizes player avatars and movement; shared interactions and server-authoritative task state are the next multiplayer slice.

For a dedicated Linux host, run the Godot project with `--server` on UDP port `7777`. For automated testing, a client can use `--join=127.0.0.1`. The planned VM service will be a separate Night Shift process and will not use the existing Minecraft ports.

The co-op address field is pre-filled with the deployed server address `132.145.159.218`, so players do not need to memorize it. It remains editable for local testing or a future server change.
