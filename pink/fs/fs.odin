package pk_fs

import "core:c"
import "core:os"
import pk ".."
import "physfs"

ARCHIVE_EXTENSION :: #config(PK_FS_ARCHIVE_EXTENSION, "zip")

@(init, private)
_module_init :: proc() {
	pk._core.hooks.fs_init = init
	pk._core.hooks.fs_destroy = destroy
}

_core: Core

@(private)
Core :: struct {
	usable: bool,
}

/*
 * Initialize
 */

init :: proc(org, name: string) {
	arc_ext := ARCHIVE_EXTENSION
	if physfs.init(cstring(raw_data(os.args[0]))) == 0 {
		panic(string(physfs.getErrorByCode(physfs.getLastErrorCode())))
	}
	physfs.setSaneConfig(
		cstring(raw_data(org)),
		cstring(raw_data(org)),
		cstring(raw_data(arc_ext)),
		0,
		0,
	)
	physfs.permitSymbolicLinks(1)
}

/*
 * Read Files
 */

bytes_load_all :: proc(path: string) -> []byte {
	c_path := cstring(raw_data(path))
	if physfs.exists(c_path) == 0 {
		panic("file does not exist")
	}
	file := physfs.openRead(cstring(raw_data(path))); defer physfs.close(file)
	file_len := physfs.fileLength(file)
	result := make([]byte, file_len)
	physfs.readBytes(file, raw_data(result), physfs.uint64(file_len))
	return result
}

string_load_all :: proc(path: string) -> string {
	unimplemented()
}

/*
 * Destroy
 */

destroy :: proc() {
	physfs.deinit()
}
