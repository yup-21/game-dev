extends RefCounted
## Atomic, checksum-protected, versioned save slots; never serialize live battle objects.
const VERSION: int=1
const SLOTS: int=3
var folder: String="user://saves"
var last_error: String=""

func _init(directory: String="user://saves") -> void:
	folder=directory

func _path(slot: int) -> String:
	return folder.path_join("slot_%02d.json" % slot)

## Godot JSON parses every number as float; normalize whole values after digest verification.
func _normalize_numbers(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary={}
		for key in value: result[key]=_normalize_numbers(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for child in value: result.append(_normalize_numbers(child))
		return result
	if value is float and is_finite(value) and absf(value)<9000000000000000.0 and floor(value)==value:
		return int(value)
	return value

func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null: return {}
	var text_data: String=file.get_as_text()
	file.close()
	var parsed: Variant=JSON.parse_string(text_data)
	if not parsed is Dictionary: return {}
	if parsed.get("version")!=VERSION or not parsed.get("data") is Dictionary or not parsed.get("digest") is String: return {}
	var data: Dictionary=parsed.data
	if JSON.stringify(data,"",true).sha256_text()!=str(parsed.digest): return {}
	return _normalize_numbers(data)

func info(slot: int) -> Dictionary:
	if slot<1 or slot>SLOTS: return {"state":"invalid"}
	var path: String=_path(slot)
	if not FileAccess.file_exists(path): return {"state":"empty"}
	var data: Dictionary=_read_file(path)
	if data.is_empty(): return {"state":"corrupt"}
	return {"state":"ready","phase":str(data.get("phase","")),"chapter":str(data.get("chapter_id","")),"encounter":str(data.get("encounter_id",""))}

func save(slot: int,session) -> bool:
	last_error=""
	if slot<1 or slot>SLOTS or session==null:
		last_error="Invalid slot or session"
		return false
	var data: Dictionary=session.export_save_data()
	if data.is_empty():
		last_error="Only safe story/rest chapters can be saved (not live combat)"
		return false
	if not session.validate_save_data(data):
		last_error="Session state failed validation"
		return false
	var root: String=ProjectSettings.globalize_path(folder)
	var err: int=DirAccess.make_dir_recursive_absolute(root)
	if err!=OK:
		last_error="Unable to create save directory"
		return false
	var target: String=ProjectSettings.globalize_path(_path(slot))
	var tmp: String=target+".tmp"
	var backup: String=target+".bak"
	var record: Dictionary={"version":VERSION,"data":data,"digest":JSON.stringify(data,"",true).sha256_text()}
	var writer=FileAccess.open(tmp,FileAccess.WRITE)
	if writer==null:
		last_error="Unable to open temporary save"
		return false
	writer.store_string(JSON.stringify(record,"  ",true)+"\n")
	writer.flush()
	var write_error: int=writer.get_error()
	writer.close()
	if write_error!=OK:
		DirAccess.remove_absolute(tmp)
		last_error="Unable to write save"
		return false
	# Retain a last-known-good file; a failed rename restores it.
	if FileAccess.file_exists(backup): DirAccess.remove_absolute(backup)
	if FileAccess.file_exists(target):
		err=DirAccess.rename_absolute(target,backup)
		if err!=OK:
			DirAccess.remove_absolute(tmp)
			last_error="Unable to rotate old save"
			return false
	err=DirAccess.rename_absolute(tmp,target)
	if err!=OK:
		if FileAccess.file_exists(backup): DirAccess.rename_absolute(backup,target)
		last_error="Unable to commit save"
		return false
	return true

func load(slot: int,session) -> bool:
	last_error=""
	if slot<1 or slot>SLOTS or session==null:
		last_error="Invalid slot or session"
		return false
	var data: Dictionary=_read_file(_path(slot))
	if data.is_empty() or not session.validate_save_data(data):
		last_error="Save is damaged or incompatible"
		return false
	return session.import_save_data(data)

func delete(slot: int) -> bool:
	if slot<1 or slot>SLOTS: return false
	var path: String=ProjectSettings.globalize_path(_path(slot))
	if not FileAccess.file_exists(path): return true
	return DirAccess.remove_absolute(path)==OK
