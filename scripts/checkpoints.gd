extends RefCounted

const VERSION = 1
const INN = "inn"
const SESSION = "session"

var folder: String


func _init(save_folder: String = "user://") -> void:
	folder = save_folder


func read(slot: String) -> Dictionary:
	return _read_file(folder.path_join(slot + ".save"))


func _read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 8 or int(file.get_32()) != VERSION:
		return {}
	var state: Variant = file.get_var(false)
	if state is Dictionary and state.get("pos") is Vector2i and state.get("enemies") is Dictionary:
		return state
	return {}


func write(slot: String, state: Dictionary) -> bool:
	var path := folder.path_join(slot + ".save")
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_32(VERSION)
	file.store_var(state, false)
	file.flush()
	var written := file.get_error() == OK
	file.close()
	if written and _read_file(temp) == state:
		if DirAccess.rename_absolute(temp, path) == OK:
			return true
	DirAccess.remove_absolute(temp)
	return false


func discard(slot: String) -> void:
	var path := folder.path_join(slot + ".save")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
