import Foundation

/// Minimaler Leser für WoW-Datenbanktabellen im Format WDC3/WDC4/WDC5.
/// Liefert pro Datensatz die ID, die Werte der Spalten im Datensatz (`fields`)
/// und – falls vorhanden – den Fremdschlüssel aus der Beziehungstabelle (`relation`).
struct DB2Table {
    struct Row {
        var id: UInt32
        var fields: [UInt32]
        var relation: UInt32?
    }

    enum Failure: LocalizedError {
        case format(String)
        var errorDescription: String? {
            if case .format(let s) = self { return "DB2-Datei nicht lesbar: \(s)" }
            return nil
        }
    }

    var rows: [Row] = []

    private struct Section {
        var tactKey: UInt64
        var fileOffset: Int
        var recordCount: Int
        var stringTableSize: Int
        var offsetRecordsEnd: Int
        var idListSize: Int
        var relationshipDataSize: Int
        var offsetMapIDCount: Int
        var copyTableCount: Int
    }

    private struct FieldInfo {
        var offsetBits: Int
        var sizeBits: Int
        var additionalDataSize: Int
        var storageType: UInt32
        var v1: UInt32, v2: UInt32, v3: UInt32
    }

    init(data: Data) throws {
        let b = [UInt8](data)
        func u8(_ o: Int) -> UInt32 { UInt32(b[o]) }
        func u16(_ o: Int) -> UInt32 { UInt32(b[o]) | UInt32(b[o + 1]) << 8 }
        func u32(_ o: Int) -> UInt32 { u16(o) | u16(o + 2) << 16 }
        func u64(_ o: Int) -> UInt64 { UInt64(u32(o)) | UInt64(u32(o + 4)) << 32 }

        guard b.count > 204 else { throw Failure.format("zu kurz") }
        let magic = String(decoding: b[0..<4], as: UTF8.self)
        var o: Int
        switch magic {
        case "WDC5": o = 4 + 4 + 128          // Version + Schema-Text
        case "WDC3", "WDC4": o = 4
        default: throw Failure.format("unbekanntes Format \(magic)")
        }
        let recordCount = Int(u32(o)); o += 4
        let fieldCount = Int(u32(o)); o += 4
        let recordSize = Int(u32(o)); o += 4
        o += 4                                  // string_table_size
        o += 4 + 4                              // table_hash, layout_hash
        o += 4 + 4 + 4                          // min_id, max_id, locale
        let flags = u16(o); o += 2
        let idIndex = Int(u16(o)); o += 2
        let totalFieldCount = Int(u32(o)); o += 4
        o += 4 + 4                              // bitpacked_data_offset, lookup_column_count
        let fieldStorageInfoSize = Int(u32(o)); o += 4
        let commonDataSize = Int(u32(o)); o += 4
        let palletDataSize = Int(u32(o)); o += 4
        let sectionCount = Int(u32(o)); o += 4
        _ = recordCount

        var sections: [Section] = []
        for _ in 0..<sectionCount {
            sections.append(Section(tactKey: u64(o), fileOffset: Int(u32(o + 8)), recordCount: Int(u32(o + 12)),
                                    stringTableSize: Int(u32(o + 16)), offsetRecordsEnd: Int(u32(o + 20)),
                                    idListSize: Int(u32(o + 24)), relationshipDataSize: Int(u32(o + 28)),
                                    offsetMapIDCount: Int(u32(o + 32)), copyTableCount: Int(u32(o + 36))))
            o += 40
        }
        o += totalFieldCount * 4                // field_structure (in field_storage_info enthalten)

        var infos: [FieldInfo] = []
        for _ in 0..<(fieldStorageInfoSize / 24) {
            infos.append(FieldInfo(offsetBits: Int(u16(o)), sizeBits: Int(u16(o + 2)),
                                   additionalDataSize: Int(u32(o + 4)), storageType: u32(o + 8),
                                   v1: u32(o + 12), v2: u32(o + 16), v3: u32(o + 20)))
            o += 24
        }
        guard infos.count >= fieldCount else { throw Failure.format("Feldinfos fehlen") }

        // Palette und gemeinsame Werte je Feld
        let palletStart = o
        var palletOffsets: [Int] = Array(repeating: 0, count: infos.count)
        var pOff = palletStart
        for (i, f) in infos.enumerated() where f.storageType == 3 || f.storageType == 4 {
            palletOffsets[i] = pOff
            pOff += f.additionalDataSize
        }
        o = palletStart + palletDataSize
        var common: [[UInt32: UInt32]] = Array(repeating: [:], count: infos.count)
        var cOff = o
        for (i, f) in infos.enumerated() where f.storageType == 2 {
            var map: [UInt32: UInt32] = [:]
            var k = cOff
            while k + 8 <= cOff + f.additionalDataSize {
                map[u32(k)] = u32(k + 4)
                k += 8
            }
            common[i] = map
            cOff += f.additionalDataSize
        }
        o += commonDataSize
        _ = o

        guard flags & 1 == 0 else { throw Failure.format("Tabellen mit Offset-Map werden nicht unterstützt") }

        func readBits(_ recordStart: Int, _ bitOffset: Int, _ bitCount: Int) -> UInt32 {
            guard bitCount > 0 else { return 0 }
            var value: UInt64 = 0
            let firstByte = recordStart + bitOffset / 8
            let shift = bitOffset % 8
            let bytesNeeded = (shift + bitCount + 7) / 8
            for k in 0..<min(bytesNeeded, 8) where firstByte + k < b.count {
                value |= UInt64(b[firstByte + k]) << (8 * UInt64(k))
            }
            value >>= UInt64(shift)
            if bitCount < 64 { value &= (UInt64(1) << UInt64(bitCount)) - 1 }
            return UInt32(truncatingIfNeeded: value)
        }

        for s in sections {
            // Verschlüsselte Abschnitte (unveröffentlichte Inhalte) überspringen
            if s.tactKey != 0 { continue }
            let recordsStart = s.fileOffset
            var p = recordsStart + s.recordCount * recordSize + s.stringTableSize
            var ids: [UInt32] = []
            for k in 0..<(s.idListSize / 4) { ids.append(u32(p + k * 4)) }
            p += s.idListSize
            var copies: [(UInt32, UInt32)] = []
            for k in 0..<s.copyTableCount { copies.append((u32(p + k * 8), u32(p + k * 8 + 4))) }
            p += s.copyTableCount * 8
            p += s.offsetMapIDCount * 6
            var relation: [Int: UInt32] = [:]
            if s.relationshipDataSize > 0 {
                let n = Int(u32(p))
                for k in 0..<n {
                    let e = p + 12 + k * 8
                    relation[Int(u32(e + 4))] = u32(e)
                }
            }

            var byID: [UInt32: Row] = [:]
            for r in 0..<s.recordCount {
                let rs = recordsStart + r * recordSize
                var values: [UInt32] = []
                for (i, f) in infos.prefix(fieldCount).enumerated() {
                    switch f.storageType {
                    case 0:  values.append(readBits(rs, f.offsetBits, min(f.sizeBits, 32)))
                    case 1, 5: values.append(readBits(rs, f.offsetBits, Int(f.v2)))
                    case 2:
                        // ID wird erst unten bekannt – vorläufig Standardwert
                        values.append(f.v1)
                    case 3:
                        let idx = Int(readBits(rs, f.offsetBits, Int(f.v2)))
                        values.append(u32(palletOffsets[i] + idx * 4))
                    case 4:
                        let idx = Int(readBits(rs, f.offsetBits, Int(f.v2)))
                        values.append(u32(palletOffsets[i] + idx * 4 * Int(max(f.v3, 1))))
                    default: values.append(0)
                    }
                }
                let id: UInt32 = r < ids.count ? ids[r] : (idIndex < values.count ? values[idIndex] : UInt32(r))
                for (i, f) in infos.prefix(fieldCount).enumerated() where f.storageType == 2 {
                    if let v = common[i][id] { values[i] = v }
                }
                let row = Row(id: id, fields: values, relation: relation[r])
                byID[id] = row
                rows.append(row)
            }
            for (newID, oldID) in copies {
                if var row = byID[oldID] { row.id = newID; rows.append(row) }
            }
        }
    }
}
