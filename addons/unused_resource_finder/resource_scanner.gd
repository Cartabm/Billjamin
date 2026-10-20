@tool
extends RefCounted

# Read-only project asset audit.
# Usage from an EditorScript or editor plugin:
# var audit = load("res://scene_asset_audit.gd").new()
# var result: Dictionary = audit.scan()
# print(result["report_path"])
#
# "unreferenced" means no detectable reference from any .tscn scene,
# including dependencies of scene resources, or explicit references in scripts.
# It does NOT guarantee safe deletion (dynamic loads and external references).

const ASSET_EXTENSIONS := [
	"png", "jpg", "jpeg", "webp", "svg", "bmp", "hdr", "exr",
	"ogg", "wav", "mp3", "ttf", "otf", "woff", "woff2",
	"tres", "res", "theme", "glb", "gltf", "obj", "fbx", "mesh"
]
const TEXT_EXTENSIONS := [
	"gd", "cs", "tscn", "tres", "theme", "cfg", "json", "gltf", "obj", "mtl", "shader", "gdshader"
]
const SKIP_DIRS := [".godot", ".git", "addons/unused_resource_finder"]
const REPORT_PATH := "user://scene_asset_audit.csv"

func scan(root: String = "res://") -> Dictionary:
	var files: Array[String] = []
	_walk(root, files)
	var assets: Array[String] = []
	var scene_count := 0
	var reference_text := "\n"
	var has_dynamic_loads := false

	for path in files:
		var ext := path.get_extension().to_lower()
		if ext in ASSET_EXTENSIONS:
			assets.append(path)
		if ext == "tscn":
			scene_count += 1
		if ext in TEXT_EXTENSIONS:
			var f := FileAccess.open(path, FileAccess.READ)
			if f == null:
				continue
			var contents := f.get_as_text()
			f.close()
			reference_text += contents + "\n"
			if ext in ["gd", "cs"] and (contents.contains("load(") or contents.contains("ResourceLoader.load(")):
				has_dynamic_loads = true

	var unreferenced: Array[Dictionary] = []
	var referenced: Array[Dictionary] = []
	var total_bytes := 0
	for path in assets:
		var used := reference_text.contains(path)
		if not used:
			var uid := ResourceLoader.get_resource_uid(path)
			if uid != ResourceUID.INVALID_ID:
				used = reference_text.contains(ResourceUID.id_to_text(uid))
		var item: Dictionary = {
			"path": path,
			"size": FileAccess.get_file_as_bytes(path).size()
		}
		if used:
			referenced.append(item)
		else:
			unreferenced.append(item)
			total_bytes += int(item["size"])

	unreferenced.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["size"]) > int(b["size"]))
	_write_report(unreferenced)
	print("Scene asset audit: ", scene_count, " scenes, ", assets.size(), " candidate assets, ", unreferenced.size(), " without detected references.")
	print("Potential space: %.2f MiB" % (float(total_bytes) / 1048576.0))
	print("CSV report: ", ProjectSettings.globalize_path(REPORT_PATH))
	if has_dynamic_loads:
		print("WARNING: Scripts contain runtime load calls. Unreferenced files may still be needed.")
	return {
		"unreferenced": unreferenced,
		"unused": unreferenced,
		"referenced": referenced,
		"scene_count": scene_count,
		"potential_bytes": total_bytes,
		"report_path": ProjectSettings.globalize_path(REPORT_PATH),
		"dynamic_load_warning": has_dynamic_loads
	}

func _write_report(items: Array[Dictionary]) -> void:
	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Unable to write audit report: " + REPORT_PATH)
		return
	f.store_csv_line(PackedStringArray(["path", "size_bytes", "size_mib", "status"]))
	for item in items:
		f.store_csv_line(PackedStringArray([
			str(item["path"]),
			str(item["size"]),
			"%.3f" % (float(item["size"]) / 1048576.0),
			"REVIEW - no detected static reference"
		]))
	f.close()

func _walk(path: String, results: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full_path := path.path_join(entry)
		var relative := full_path.trim_prefix("res://")
		if dir.current_is_dir():
			var skip := false
			for skipped in SKIP_DIRS:
				if relative == skipped or relative.begins_with(skipped + "/"):
					skip = true
					break
			if not skip:
				_walk(full_path, results)
		elif not entry.ends_with(".import") and not entry.ends_with(".uid"):
			results.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
