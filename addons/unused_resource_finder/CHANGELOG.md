# Changelog

## 1.1.0 — 2026-10-11
- "Unused" check now also resolves each asset's `uid://` (via `ResourceLoader.get_resource_uid`) and checks that against the project text too, so a resource referenced only by uid is never wrongly flagged.
- New "Oversized" check: flags image files over 2048px on either side, shown with their real pixel dimensions, independent of whether the image is used.
- Results list and exported report now show both categories together; export renamed `asset_audit.md`.

## 1.0.0 — 2026-10-10
- Initial release.
- Scans the whole project for image, audio, font, theme and resource files.
- Flags any file whose `res://` path does not appear as text anywhere in your `.tscn`, `.tres`, `.gd`, `.cs`, `.cfg` or `.import` files.
- Shows file size next to each result.
- Double-click a result to reveal it in your system file manager.
- "Export Markdown" button writes an `orphaned_resources.md` checklist.
