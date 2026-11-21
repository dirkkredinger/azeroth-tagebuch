import Foundation

/// Ein Wert aus einer WoW-SavedVariables-Datei.
enum LuaValue {
    case string(String)
    case number(Double)
    case bool(Bool)
    case table(LuaTable)
    case null

    var string: String? {
        switch self {
        case .string(let s): return s
        case .number(let d):
            if d == d.rounded(), abs(d) < 1e15 { return String(Int(d)) }
            return String(d)
        case .bool(let b): return b ? "true" : "false"
        default: return nil
        }
    }

    var double: Double? {
        switch self {
        case .number(let d): return d
        case .string(let s): return Double(s)
        default: return nil
        }
    }

    var int: Int? {
        guard let d = double, d.isFinite else { return nil }
        return Int(d)
    }

    var table: LuaTable? {
        if case .table(let t) = self { return t }
        return nil
    }

    subscript(key: String) -> LuaValue? { table?.dict[key] }
}

struct LuaTable {
    /// Einträge ohne Schlüssel (Lua-Array-Teil)
    var array: [LuaValue] = []
    /// Einträge mit Schlüssel; Zahlenschlüssel werden als Text gespeichert ("1", "2", ...)
    var dict: [String: LuaValue] = [:]

    /// Alle Array-Einträge in Reihenfolge, auch wenn sie mit [1] = ... geschrieben wurden.
    var items: [LuaValue] {
        let numeric = dict.compactMap { key, value -> (Int, LuaValue)? in
            guard let n = Int(key) else { return nil }
            return (n, value)
        }
        if numeric.isEmpty { return array }
        return array + numeric.sorted { $0.0 < $1.0 }.map { $0.1 }
    }
}

struct LuaParseError: LocalizedError {
    let message: String
    let offset: Int
    var errorDescription: String? { "Lesefehler bei Byte \(offset): \(message)" }
}

/// Liest das Lua-Format, das WoW für SavedVariables schreibt (Zuweisungen mit Tabellen).
struct LuaParser {
    private let b: [UInt8]
    private var i = 0

    private init(_ data: [UInt8]) { b = data }

    static func parseAssignments(_ data: Data) throws -> [String: LuaValue] {
        var p = LuaParser([UInt8](data))
        return try p.assignments()
    }

    private mutating func assignments() throws -> [String: LuaValue] {
        var result: [String: LuaValue] = [:]
        skip()
        // UTF-8-BOM überspringen
        if b.count >= 3, b[0] == 0xEF, b[1] == 0xBB, b[2] == 0xBF { i = 3; skip() }
        while i < b.count {
            let name = try identifier()
            try expect(UInt8(ascii: "="))
            result[name] = try value()
            skip()
            if i < b.count, b[i] == UInt8(ascii: ";") { i += 1; skip() }
        }
        return result
    }

    private func isIdentStart(_ c: UInt8) -> Bool {
        (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95
    }

    private func isIdent(_ c: UInt8) -> Bool {
        isIdentStart(c) || (c >= 48 && c <= 57)
    }

    private mutating func skip() {
        while i < b.count {
            let c = b[i]
            if c == 32 || c == 9 || c == 10 || c == 13 { i += 1; continue }
            if c == 45, i + 1 < b.count, b[i + 1] == 45 {           // "--"
                i += 2
                if i + 1 < b.count, b[i] == 91, b[i + 1] == 91 {     // "--[[ ... ]]"
                    i += 2
                    while i + 1 < b.count, !(b[i] == 93 && b[i + 1] == 93) { i += 1 }
                    i = min(i + 2, b.count)
                } else {
                    while i < b.count, b[i] != 10 { i += 1 }
                }
                continue
            }
            break
        }
    }

    private mutating func expect(_ c: UInt8) throws {
        skip()
        guard i < b.count, b[i] == c else {
            throw LuaParseError(message: "„\(Character(UnicodeScalar(c)))“ erwartet", offset: i)
        }
        i += 1
    }

    private mutating func identifier() throws -> String {
        guard i < b.count, isIdentStart(b[i]) else {
            throw LuaParseError(message: "Name erwartet", offset: i)
        }
        let start = i
        while i < b.count, isIdent(b[i]) { i += 1 }
        return String(decoding: b[start..<i], as: UTF8.self)
    }

    private mutating func value() throws -> LuaValue {
        skip()
        guard i < b.count else { throw LuaParseError(message: "Wert erwartet", offset: i) }
        let c = b[i]
        if c == UInt8(ascii: "{") { return .table(try table()) }
        if c == UInt8(ascii: "\"") || c == UInt8(ascii: "'") { return .string(try string()) }
        if c == UInt8(ascii: "-") || c == UInt8(ascii: ".") || (c >= 48 && c <= 57) {
            return .number(try number())
        }
        let start = i
        let word = try identifier()
        switch word {
        case "true": return .bool(true)
        case "false": return .bool(false)
        case "nil": return .null
        case "inf": return .number(.infinity)
        case "nan": return .number(.nan)
        default: throw LuaParseError(message: "Unbekannter Wert „\(word)“", offset: start)
        }
    }

    private mutating func number() throws -> Double {
        let start = i
        if b[i] == UInt8(ascii: "-") { i += 1 }
        while i < b.count {
            let c = b[i]
            let isDigit = c >= 48 && c <= 57
            let isExp = c == UInt8(ascii: "e") || c == UInt8(ascii: "E")
            let isSignAfterExp = (c == UInt8(ascii: "-") || c == UInt8(ascii: "+"))
                && i > start && (b[i - 1] == UInt8(ascii: "e") || b[i - 1] == UInt8(ascii: "E"))
            if isDigit || isExp || isSignAfterExp || c == UInt8(ascii: ".") { i += 1 } else { break }
        }
        let text = String(decoding: b[start..<i], as: UTF8.self)
        if text == "-", i < b.count, isIdentStart(b[i]) {   // "-inf" / "-nan"
            let word = try identifier()
            if word == "inf" { return -.infinity }
            if word == "nan" { return .nan }
        }
        guard let d = Double(text) else {
            throw LuaParseError(message: "Ungültige Zahl „\(text)“", offset: start)
        }
        return d
    }

    private mutating func string() throws -> String {
        let quote = b[i]
        i += 1
        var out: [UInt8] = []
        while i < b.count {
            let c = b[i]
            if c == quote {
                i += 1
                return String(decoding: out, as: UTF8.self)
            }
            if c == 92 {   // Backslash
                i += 1
                guard i < b.count else { break }
                let e = b[i]
                if e == UInt8(ascii: "n") { out.append(10); i += 1 }
                else if e == UInt8(ascii: "t") { out.append(9); i += 1 }
                else if e == UInt8(ascii: "r") { out.append(13); i += 1 }
                else if e >= 48 && e <= 57 {
                    var v = 0
                    var n = 0
                    while n < 3, i < b.count, b[i] >= 48, b[i] <= 57 {
                        v = v * 10 + Int(b[i] - 48)
                        i += 1
                        n += 1
                    }
                    out.append(UInt8(truncatingIfNeeded: v))
                } else { out.append(e); i += 1 }
                continue
            }
            out.append(c)
            i += 1
        }
        throw LuaParseError(message: "Text nicht abgeschlossen", offset: i)
    }

    private mutating func table() throws -> LuaTable {
        i += 1   // "{"
        var t = LuaTable()
        while true {
            skip()
            guard i < b.count else { throw LuaParseError(message: "„}“ fehlt", offset: i) }
            if b[i] == UInt8(ascii: "}") { i += 1; return t }

            if b[i] == UInt8(ascii: "[") {
                i += 1
                let key = try value()
                try expect(UInt8(ascii: "]"))
                try expect(UInt8(ascii: "="))
                let v = try value()
                if let k = key.string { t.dict[k] = v }
            } else if isIdentStart(b[i]) {
                let save = i
                let word = try identifier()
                skip()
                let isAssign = i < b.count && b[i] == UInt8(ascii: "=")
                    && !(i + 1 < b.count && b[i + 1] == UInt8(ascii: "="))
                if isAssign {
                    i += 1
                    t.dict[word] = try value()
                } else {
                    i = save
                    t.array.append(try value())
                }
            } else {
                t.array.append(try value())
            }

            skip()
            if i < b.count, b[i] == UInt8(ascii: ",") || b[i] == UInt8(ascii: ";") { i += 1 }
        }
    }
}
