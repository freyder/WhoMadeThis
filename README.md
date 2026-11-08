# Who Made This

A tiny World of Warcraft add-on for **WoW Forever** that tells you which add-on created any piece of UI on your screen. Point at a bar, button, frame or text and it shows the add-on (and file) responsible.

Handy when you've installed a pile of add-ons and want to know who's drawing what, who to configure, or which one to blame.

## Usage

- `/wmt` toggles a live tooltip that follows the mouse. It lists:
  - **Mouse is over:** what a click would hit, with its add-on and source file.
  - **Its parents:** the frames it sits inside, with their add-ons.
  - **Also drawn here:** visible frames under the cursor that don't take the mouse (bar fills, backgrounds, text), smallest first.
- `/wmt print` writes the same list to chat, so you can copy it (for example with your chat add-on's copy button).
- Both can be bound to keys: **Options > Key Bindings > AddOns > Who Made This**.

`/whomadethis` works as well as `/wmt`.

## How it works

The WoW Forever client records where each frame was created: `frame:GetSourceLocation()` returns something like `Interface/AddOns/SomeAddon/Frames.lua:120`. The folder after `AddOns` is the add-on. Frames from `Blizzard_*` folders are shown as **Blizzard**, the game's own UI.

If the client has no source for a frame, the add-on guesses from the frame's name against your loaded add-ons and marks it **(by name)**.

### Limits

- An add-on that only restyles a Blizzard frame (new textures, moved, resized) doesn't create it, so the frame still shows as Blizzard. Check the parents list, or point at the new art itself.
- Forbidden frames and secret values are skipped.

## Install

Download `WhoMadeThis-x.y.z.zip` from the [latest release](https://github.com/freyder/WhoMadeThis/releases/latest) and extract it into:

```
World of Warcraft/_forever_/Interface/AddOns/
```

The zip contains the `WhoMadeThis` folder, so you end up with `AddOns/WhoMadeThis/WhoMadeThis.toc`. Restart the game (a `/reload` doesn't pick up new add-ons).

## Compatibility

Written for WoW Forever (interface 16001). It uses only `GetMouseFoci`/`GetMouseFocus`, `EnumerateFrames` and `GetSourceLocation`, and checks for each, so it may work on other modern clients, but only Forever is tested.

## License

MIT, see [LICENSE](LICENSE).
