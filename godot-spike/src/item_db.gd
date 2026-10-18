extends RefCounted
## Item definitions loaded from data/items.json (written by tools/export_items.py from Trilobit's content tables).
var defs: Dictionary = {}

func load_file(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var arr = JSON.parse_string(f.get_as_text())
	for d in arr:
		defs[d["id"]] = d
	return defs.size()

func has(id: String) -> bool:
	return defs.has(id)
