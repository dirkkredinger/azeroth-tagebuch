import Foundation
import CCascLib

/// Schmaler Swift-Wrapper um CascLib: öffnet das lokale Datenarchiv der WoW-Installation
/// (nur lesend) und liefert einzelne Dateien nach Name oder FileDataID.
final class CascStorage {
    enum Failure: LocalizedError {
        case open(String, UInt32)
        case file(String, UInt32)

        var errorDescription: String? {
            switch self {
            case .open(let p, let c): return "WoW-Datenarchiv konnte nicht geöffnet werden (\(p), Fehler \(c))"
            case .file(let n, let c): return "Datei \(n) nicht lesbar (Fehler \(c))"
            }
        }
    }

    private var handle: CascHandle?

    /// - Parameter gameFolder: Ordner, der `Data/` und `.build.info` enthält (z. B. „/Applications/World of Warcraft“).
    init(gameFolder: URL, product: String = "wow") throws {
        let params = gameFolder.path + "*" + product
        var h: CascHandle?
        let ok = params.withCString { CascOpenStorage($0, 0, &h) }
        guard ok, let h else { throw Failure.open(gameFolder.path, GetCascError()) }
        handle = h
    }

    deinit {
        if let handle { CascCloseStorage(handle) }
    }

    func read(fileDataID: UInt32) throws -> Data {
        try read(pointer: UnsafeRawPointer(bitPattern: UInt(fileDataID)), flags: CCASC_OPEN_BY_FILEID,
                 label: "FileDataID \(fileDataID)")
    }

    func read(name: String) throws -> Data {
        try name.withCString { try read(pointer: UnsafeRawPointer($0), flags: CCASC_OPEN_BY_NAME, label: name) }
    }

    private func read(pointer: UnsafeRawPointer?, flags: UInt32, label: String) throws -> Data {
        var file: CascHandle?
        guard CascOpenFile(handle, pointer, 0, flags | CCASC_OVERCOME_ENCRYPTED, &file), let file else {
            throw Failure.file(label, GetCascError())
        }
        defer { CascCloseFile(file) }
        var size64: UInt64 = 0
        guard CascGetFileSize64(file, &size64) else { throw Failure.file(label, GetCascError()) }
        let size = Int(size64)
        guard size > 0, size < 512 * 1024 * 1024 else { throw Failure.file(label, GetCascError()) }
        var data = Data(count: size)
        var read: UInt32 = 0
        let ok = data.withUnsafeMutableBytes { CascReadFile(file, $0.baseAddress, UInt32(size), &read) }
        guard ok else { throw Failure.file(label, GetCascError()) }
        return data.prefix(Int(read))
    }
}
