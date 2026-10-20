# Unused Resource Finder

An asset audit dock, not just an orphan finder: it flags files nothing
references AND images that are needlessly huge, in the same scan.

## Two checks, one pass

**Unused.** A file counts as referenced if its `res://` path shows up as text
anywhere in your `.tscn`, `.tres`, `.gd`, `.cs`, `.cfg` or `.import` files —
and, just as importantly, if its **uid** does too. Godot scenes can
reference a resource purely by `uid://...`, with the `path=` next to it going
stale the moment something gets moved. A plain path search would call that
resource unused and risk you deleting something that's very much in use;
this plugin resolves each asset's uid first and checks for that as well.

**Oversized.** Independent of whether an image is used anywhere, the scan
flags any `.png`, `.jpg`, `.webp` or `.bmp` wider or taller than 2048px.
A 4096×4096 background that only ever gets drawn at 400×300 is one of the
most common, least visible causes of a bloated export — this surfaces it
without you having to open every texture by hand.

## What you get back

- One list, grouped visibly into `[Unused]` and `[Oversized]` rows, each
  showing file size — and, for oversized images, the actual pixel dimensions.
- Double-click any row to reveal that file in your system file manager.
- "Export Markdown" writes a single `asset_audit.md` with both sections, so
  you (or a teammate) can review and tick things off outside the editor.

Both checks are heuristics, not guarantees: the unused check can't see a path
assembled at runtime from a variable, and "oversized" is a size judgement,
not a defect. Always look before you delete or resize.

## Setup

Copy `addons/unused_resource_finder` into your project's `addons/` folder,
then switch it on under **Project > Project Settings > Plugins**. The dock
tab shows up on the left; click **Scan Project** whenever you want a fresh
pass — after an art import, before cutting a release build, or just to see
where the project stands.

## Works with

Godot 4.2 and later (tested on 4.7). Uid-based matching uses the uid Godot
already assigned your asset on import; if a particular resource has none,
it still gets the full path-based check.

## License

MIT — see `LICENSE`.
