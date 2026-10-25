class_name ScrapPersistence
extends RefCounted

const DIRECTORY="D:/GameDev/Projects/ScrapReborn3D/.userdata"
const SAVE=DIRECTORY+"/campaign.json"

static func write(path: String,data: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if f==null:return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data,"\t"));f.flush();f.close()
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path+".bak"):DirAccess.remove_absolute(path+".bak")
		DirAccess.rename_absolute(path,path+".bak")
	return DirAccess.rename_absolute(path+".tmp",path)

static func read(path: String=SAVE) -> Dictionary:
	if not FileAccess.file_exists(path):return {}
	var parser=JSON.new()
	var error=parser.parse(FileAccess.get_file_as_string(path))
	if error==OK and parser.data is Dictionary and int(parser.data.get("version",0)) in [1,2] and parser.data.has("player"):
		return parser.data
	var corrupt=path+".corrupt-"+str(int(Time.get_unix_time_from_system()))
	DirAccess.copy_absolute(path,corrupt)
	if FileAccess.file_exists(path+".bak"):
		var backup=JSON.parse_string(FileAccess.get_file_as_string(path+".bak"))
		if backup is Dictionary and int(backup.get("version",0)) in [1,2] and backup.has("player"):
			backup["recovered_backup"]=true;return backup
	return {}
