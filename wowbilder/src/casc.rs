//! Schmale Rust-Hülle um CascLib: öffnet das lokale Datenarchiv der WoW-Installation (nur lesend).

use std::ffi::{c_void, CString};
use std::os::raw::{c_char, c_uint};
use std::path::Path;

extern "C" {
    fn CascOpenStorage(params: *const c_char, locale_mask: c_uint, storage: *mut *mut c_void) -> bool;
    fn CascCloseStorage(storage: *mut c_void) -> bool;
    fn CascOpenFile(storage: *mut c_void, name: *const c_void, locale: c_uint, flags: c_uint, file: *mut *mut c_void) -> bool;
    fn CascGetFileSize64(file: *mut c_void, size: *mut u64) -> bool;
    fn CascReadFile(file: *mut c_void, buf: *mut c_void, to_read: c_uint, read: *mut c_uint) -> bool;
    fn CascCloseFile(file: *mut c_void) -> bool;
    fn GetCascError() -> c_uint;
}

const OPEN_BY_FILEID: c_uint = 3;
const OVERCOME_ENCRYPTED: c_uint = 0x20;

#[derive(Debug)]
pub struct CascError(pub String);
impl std::fmt::Display for CascError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result { f.write_str(&self.0) }
}
impl std::error::Error for CascError {}

pub struct Storage {
    handle: *mut c_void,
}

// CascLib-Handles dürfen zwischen Threads wandern, aber nicht gleichzeitig benutzt werden.
unsafe impl Send for Storage {}

impl Storage {
    /// `game_folder`: Ordner mit `Data/` und `.build.info` (z. B. „/Applications/World of Warcraft“)
    pub fn open(game_folder: &Path) -> Result<Storage, CascError> {
        let params = format!("{}*wow", game_folder.display());
        let c = CString::new(params).map_err(|e| CascError(e.to_string()))?;
        let mut h: *mut c_void = std::ptr::null_mut();
        let ok = unsafe { CascOpenStorage(c.as_ptr(), 0, &mut h) };
        if !ok || h.is_null() {
            return Err(CascError(format!(
                "WoW-Datenarchiv konnte nicht geöffnet werden ({}, Fehler {})",
                game_folder.display(),
                unsafe { GetCascError() }
            )));
        }
        Ok(Storage { handle: h })
    }

    /// Liest eine Datei über ihre FileDataID
    pub fn read(&self, file_data_id: u32) -> Result<Vec<u8>, CascError> {
        let mut file: *mut c_void = std::ptr::null_mut();
        let ok = unsafe {
            CascOpenFile(self.handle, file_data_id as usize as *const c_void, 0, OPEN_BY_FILEID | OVERCOME_ENCRYPTED, &mut file)
        };
        if !ok || file.is_null() {
            return Err(CascError(format!("Datei {file_data_id} nicht lesbar (Fehler {})", unsafe { GetCascError() })));
        }
        let result = (|| {
            let mut size: u64 = 0;
            if !unsafe { CascGetFileSize64(file, &mut size) } || size == 0 || size > 512 * 1024 * 1024 {
                return Err(CascError(format!("Datei {file_data_id}: Größe unbekannt")));
            }
            let mut buf = vec![0u8; size as usize];
            let mut read: c_uint = 0;
            if !unsafe { CascReadFile(file, buf.as_mut_ptr() as *mut c_void, size as c_uint, &mut read) } {
                return Err(CascError(format!("Datei {file_data_id}: Lesefehler {}", unsafe { GetCascError() })));
            }
            buf.truncate(read as usize);
            Ok(buf)
        })();
        unsafe { CascCloseFile(file) };
        result
    }
}

impl Drop for Storage {
    fn drop(&mut self) {
        unsafe { CascCloseStorage(self.handle) };
    }
}
