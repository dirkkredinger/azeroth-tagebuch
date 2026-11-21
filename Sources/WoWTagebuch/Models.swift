import Foundation
import SwiftUI

// MARK: - Ereignis

/// Ein Eintrag aus dem Addon. Kurze Feldnamen entsprechen der SavedVariables-Datei.
struct WowEvent: Codable, Hashable, Identifiable {
    var t: Int            // Zeitstempel (Unix)
    var e: String         // Typ
    var m: Int?           // Karten-ID
    var x: Double?
    var y: Double?
    var mo: String?       // Fortbewegung
    var q: Int?           // Quest-ID
    var n: String?        // Name (Quest/Erfolg)
    var c: String?        // Quest-Art
    var z: String?        // Zone
    var sz: String?       // Subzone
    var xp: Int?
    var g: Int?           // Kupfer
    var lv: Int?
    var inst: String?
    var it: String?
    var diff: String?
    var a: Int?           // Erfolgs-ID
    var p: Int?           // Erfolgspunkte
    var txt: String?
    var dauer: Int?
    var dg: Int?
    var il: Double?       // Gegenstandsstufe (angelegt)
    var ilg: Double?      // Gegenstandsstufe (gesamt)
    var sid: Int?         // Spezialisierungs-ID
    var spec: String?
    var rolle: String?    // TANK, HEALER, DAMAGER
    var code: String?     // Talent-Importcode
    var lo: String?       // Name der Talent-Ausstattung
    // Ausrüstungswechsel ("gegenstand")
    var slot: Int?
    var itemID: Int?
    var quality: Int?
    var ic: Int?          // Symbol (FileDataID)
    var alt: String?      // vorheriger Gegenstand
    var altil: Double?
    // Beute ("beute")
    var src: String?      // GUID der Leiche bzw. des Vorkommens
    var npc: Int?
    var art: String?      // Creature, GameObject, Vehicle
    var sn: String?       // Name der Quelle (falls bekannt)
    var items: [LootItem]?

    var id: String { dedupeKey }

    var dedupeKey: String {
        "\(t)|\(e)|\(q ?? 0)|\(a ?? 0)|\(m ?? 0)|\(x ?? -1)|\(y ?? -1)|\(txt ?? "")|\(code ?? "")|\(il ?? 0)|\(src ?? "")|\(slot ?? 0)|\(itemID ?? 0)"
    }

    var date: Date { Date(timeIntervalSince1970: TimeInterval(t)) }

    var hasPosition: Bool { m != nil && x != nil && y != nil }

    init?(lua: LuaValue) {
        guard let t = lua["t"]?.int, let e = lua["e"]?.string else { return nil }
        self.t = t
        self.e = e
        m = lua["m"]?.int
        x = lua["x"]?.double
        y = lua["y"]?.double
        mo = lua["mo"]?.string
        q = lua["q"]?.int
        n = lua["n"]?.string
        c = lua["c"]?.string
        z = lua["z"]?.string
        sz = lua["sz"]?.string
        xp = lua["xp"]?.int
        g = lua["g"]?.int
        lv = lua["lv"]?.int
        inst = lua["inst"]?.string
        it = lua["it"]?.string
        diff = lua["diff"]?.string
        a = lua["a"]?.int
        p = lua["p"]?.int
        txt = lua["txt"]?.string
        dauer = lua["dauer"]?.int
        dg = lua["dg"]?.int
        il = lua["il"]?.double
        ilg = lua["ilg"]?.double
        sid = lua["sid"]?.int
        spec = lua["spec"]?.string
        rolle = lua["rolle"]?.string
        code = lua["code"]?.string
        lo = lua["lo"]?.string
        slot = lua["slot"]?.int
        itemID = lua["id"]?.int
        ic = lua["ic"]?.int
        alt = lua["alt"]?.string
        altil = lua["altil"]?.double
        src = lua["src"]?.string
        npc = lua["npc"]?.int
        art = lua["art"]?.string
        sn = lua["sn"]?.string
        items = lua["items"]?.table?.items.compactMap(LootItem.init(lua:))
        if e == "gegenstand" {
            // dort steht q für die Qualität, nicht für eine Quest
            quality = q
            q = nil
        }
    }
}

// MARK: - Charakter

struct WowCharacter: Codable, Identifiable, Hashable {
    var key: String
    var name: String
    var realm: String
    var classToken: String? = nil
    var className: String? = nil
    var race: String? = nil
    var faction: String? = nil
    var level: Int? = nil
    var spec: String? = nil
    var money: Int? = nil
    var account: String? = nil
    var specID: Int? = nil
    var role: String? = nil
    var specDesc: String? = nil
    var primaryStat: Int? = nil
    var talentCode: String? = nil
    var itemLevel: Double? = nil
    /// Angelegte Ausrüstung je Platz (1 = Kopf … 19 = Wappenrock)
    var gear: [Int: GearItem]? = nil
    var bags: Storage? = nil
    var bank: Storage? = nil
    var guild: String? = nil
    var events: [WowEvent] = []

    var id: String { key }
}

/// Ein Gegenstand aus einem Beutefenster
struct LootItem: Codable, Hashable {
    var itemID: Int?
    var name: String?
    var quality: Int?
    var icon: Int?
    var count: Int?
    var currency: Int?
    var gold: Bool?

    init?(lua: LuaValue) {
        guard lua.table != nil else { return nil }
        itemID = lua["id"]?.int
        name = lua["n"]?.string
        quality = lua["q"]?.int
        icon = lua["ic"]?.int
        count = lua["c"]?.int
        currency = lua["cur"]?.int
        gold = lua["gold"].map { $0.string == "true" }
    }

    /// Schlüssel zum Zusammenfassen gleicher Gegenstände
    var key: String {
        if let itemID { return "i\(itemID)" }
        if let currency { return "c\(currency)" }
        if gold == true { return "gold" }
        return "n\(name ?? "?")"
    }
}

/// Ein angelegter Gegenstand
struct GearItem: Codable, Hashable {
    var itemID: Int?
    var name: String?
    var link: String?
    var quality: Int?
    var itemLevel: Double?
    var icon: Int?
    var stats: [String: Int] = [:]

    init?(lua: LuaValue) {
        guard lua.table != nil else { return nil }
        itemID = lua["id"]?.int
        name = lua["n"]?.string
        link = lua["link"]?.string
        quality = lua["q"]?.int
        itemLevel = lua["il"]?.double
        icon = lua["ic"]?.int
        for (k, v) in lua["st"]?.table?.dict ?? [:] { if let i = v.int { stats[k] = i } }
    }
}

/// Inhalt eines Lagers (Taschen, Bank, Kriegsmeutenbank, Gildenbank) zu einem Zeitpunkt
struct Storage: Codable, Hashable {
    struct Item: Codable, Hashable {
        var itemID: Int?
        var name: String?
        var quality: Int?
        var icon: Int?
        var count: Int
        var itemLevel: Double?
    }
    struct Tab: Codable, Hashable {
        var name: String
        var icon: Int?
        var items: [Item]
    }

    var t: Int
    var tabs: [Tab]
    var gold: Int?
    /// Charakter, der den Stand zuletzt gesehen hat (Gildenbank)
    var seenBy: String?

    var date: Date { Date(timeIntervalSince1970: TimeInterval(t)) }
    var itemCount: Int { tabs.reduce(0) { $0 + $1.items.reduce(0) { $0 + $1.count } } }

    init?(lua: LuaValue?) {
        guard let lua, let t = lua["t"]?.int else { return nil }
        self.t = t
        gold = lua["g"]?.int
        seenBy = lua["by"]?.string
        tabs = (lua["tabs"]?.table?.items ?? []).enumerated().map { i, tab in
            Tab(name: tab["name"]?.string ?? "Fach \(i + 1)", icon: tab["ic"]?.int,
                items: (tab["items"]?.table?.items ?? []).map {
                    Item(itemID: $0["id"]?.int, name: $0["n"]?.string, quality: $0["q"]?.int,
                         icon: $0["ic"]?.int, count: $0["c"]?.int ?? 1, itemLevel: $0["il"]?.double)
                })
        }
    }
}

struct MapInfo: Codable, Hashable {
    var name: String
    var parent: Int?
    var type: Int?
}

struct Archive: Codable {
    var characters: [String: WowCharacter] = [:]
    var maps: [String: MapInfo] = [:]
    /// Kämpfe aus dem Kampflog, je Charakter-Schlüssel
    var fights: [String: [Fight]] = [:]
    /// Gelesene Bytes je Kampflog-Datei
    var logOffsets: [String: Int] = [:]
    /// Version des Kampflog-Parsers, mit dem `fights` entstanden sind
    var combatParserVersion: Int?
    /// Kriegsmeutenbank je WoW-Account
    var warbands: [String: Storage] = [:]
    /// Gildenbanken ("Gilde-Realm")
    var guilds: [String: Storage] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        characters = try c.decodeIfPresent([String: WowCharacter].self, forKey: .characters) ?? [:]
        maps = try c.decodeIfPresent([String: MapInfo].self, forKey: .maps) ?? [:]
        fights = try c.decodeIfPresent([String: [Fight]].self, forKey: .fights) ?? [:]
        logOffsets = try c.decodeIfPresent([String: Int].self, forKey: .logOffsets) ?? [:]
        combatParserVersion = try c.decodeIfPresent(Int.self, forKey: .combatParserVersion)
        warbands = try c.decodeIfPresent([String: Storage].self, forKey: .warbands) ?? [:]
        guilds = try c.decodeIfPresent([String: Storage].self, forKey: .guilds) ?? [:]
    }
}

// MARK: - Auswertungen

struct TravelShare: Identifiable {
    var mode: String
    var seconds: Int
    var id: String { mode }
}

extension WowCharacter {
    var turnIns: [WowEvent] { events.filter { $0.e == "quest_ab" } }
    var positions: [WowEvent] { events.filter { $0.e == "pos" } }
    var deaths: Int { events.filter { $0.e == "tod" }.count }
    var achievements: [WowEvent] { events.filter { $0.e == "erfolg" } }
    var levelUps: Int { events.filter { $0.e == "level" }.count }
    var flights: Int { events.filter { $0.e == "taxi_start" }.count }
    var notes: [WowEvent] { events.filter { $0.e == "notiz" } }
    var playSeconds: Int { events.filter { $0.e == "logout" }.reduce(0) { $0 + ($1.dauer ?? 0) } }
    var questGold: Int { turnIns.reduce(0) { $0 + ($1.g ?? 0) } }
    var questXP: Int { turnIns.reduce(0) { $0 + ($1.xp ?? 0) } }
    var lastSeen: Date? { events.last?.date }
    var firstSeen: Date? { events.first?.date }

    var zonesVisited: [String] {
        Array(Set(events.compactMap { ev -> String? in
            guard ev.e == "zone", let z = ev.z, !z.isEmpty, ev.inst == nil else { return nil }
            return z
        })).sorted()
    }

    var instancesVisited: [String] {
        Array(Set(events.compactMap { $0.e == "zone" ? $0.inst : nil })).sorted()
    }

    /// Quests, die angenommen, aber (noch) nicht abgegeben oder abgebrochen wurden.
    var openQuests: [WowEvent] {
        var last: [Int: WowEvent] = [:]
        for ev in events where ev.e.hasPrefix("quest_") {
            if let q = ev.q { last[q] = ev }
        }
        return last.values.filter { $0.e == "quest_an" }.sorted { $0.t > $1.t }
    }

    var questNames: [Int: String] {
        var names: [Int: String] = [:]
        for ev in events { if let q = ev.q, let n = ev.n { names[q] = n } }
        return names
    }

    /// Reisezeit pro Fortbewegungsart, aus aufeinanderfolgenden Positionsproben.
    var travelShares: [TravelShare] {
        var secs: [String: Int] = [:]
        let pos = positions
        guard pos.count > 1 else { return [] }
        for k in 1..<pos.count {
            let dt = pos[k].t - pos[k - 1].t
            if dt > 0, dt <= 30 {
                secs[pos[k - 1].mo ?? "zu_fuss", default: 0] += dt
            }
        }
        return secs.map { TravelShare(mode: $0.key, seconds: $0.value) }.sorted { $0.seconds > $1.seconds }
    }

    var classColor: Color { WowStyle.classColor(classToken) }

    /// Stufe zu einem Zeitpunkt (aus Login-, Quest- und Stufen-Einträgen)
    func level(at time: Int) -> Int? {
        var lv: Int?
        for ev in events {
            if ev.t > time { break }
            if let l = ev.lv { lv = l }
        }
        return lv ?? level
    }

    /// Gegenstandsstufe zu einem Zeitpunkt (aus den Ausrüstungs-Einträgen des Addons)
    func itemLevel(at time: Int) -> Double? {
        var il: Double?
        for ev in events where ev.e == "ausr" {
            if ev.t > time { break }
            il = ev.il
        }
        return il
    }

    var talentChanges: [WowEvent] { events.filter { $0.e == "talente" } }
    var gearChanges: [WowEvent] { events.filter { $0.e == "gegenstand" } }
    var lootEvents: [WowEvent] { events.filter { $0.e == "beute" } }
    var itemLevelChanges: [WowEvent] { events.filter { $0.e == "ausr" } }

    var subtitle: String {
        var parts: [String] = []
        if let level { parts.append("Stufe \(level)") }
        if let race { parts.append(race) }
        if let className { parts.append(className) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Darstellung

enum WowStyle {
    static func classColor(_ token: String?) -> Color {
        switch token ?? "" {
        case "WARRIOR": return Color(red: 0.78, green: 0.61, blue: 0.43)
        case "PALADIN": return Color(red: 0.96, green: 0.55, blue: 0.73)
        case "HUNTER": return Color(red: 0.67, green: 0.83, blue: 0.45)
        case "ROGUE": return Color(red: 1.0, green: 0.96, blue: 0.41)
        case "PRIEST": return Color(red: 0.9, green: 0.9, blue: 0.9)
        case "DEATHKNIGHT": return Color(red: 0.77, green: 0.12, blue: 0.23)
        case "SHAMAN": return Color(red: 0.0, green: 0.44, blue: 0.87)
        case "MAGE": return Color(red: 0.25, green: 0.78, blue: 0.92)
        case "WARLOCK": return Color(red: 0.53, green: 0.53, blue: 0.93)
        case "MONK": return Color(red: 0.0, green: 1.0, blue: 0.6)
        case "DRUID": return Color(red: 1.0, green: 0.49, blue: 0.04)
        case "DEMONHUNTER": return Color(red: 0.64, green: 0.19, blue: 0.79)
        case "EVOKER": return Color(red: 0.2, green: 0.58, blue: 0.5)
        default: return .secondary
        }
    }

    static func modeLabel(_ mode: String) -> String {
        switch mode {
        case "zu_fuss": return "Zu Fuß"
        case "reittier": return "Reittier"
        case "flug": return "Fliegen"
        case "schwimmen": return "Schwimmen"
        case "taxi": return "Flugmeister"
        default: return mode
        }
    }

    static func modeColor(_ mode: String) -> Color {
        switch mode {
        case "zu_fuss": return Color(red: 0.55, green: 0.36, blue: 0.2)
        case "reittier": return Color(red: 0.85, green: 0.45, blue: 0.1)
        case "flug": return Color(red: 0.2, green: 0.5, blue: 0.9)
        case "schwimmen": return Color(red: 0.1, green: 0.7, blue: 0.75)
        case "taxi": return Color(red: 0.6, green: 0.3, blue: 0.8)
        default: return .gray
        }
    }

    static let modeOrder = ["zu_fuss", "reittier", "flug", "schwimmen", "taxi"]

    /// Farben der Gegenstandsqualität
    static func qualityColor(_ q: Int?) -> Color {
        switch q ?? 1 {
        case 0: return Color(red: 0.62, green: 0.62, blue: 0.62)
        case 1: return Color(red: 0.95, green: 0.95, blue: 0.95)
        case 2: return Color(red: 0.12, green: 1.0, blue: 0.0)
        case 3: return Color(red: 0.0, green: 0.44, blue: 0.87)
        case 4: return Color(red: 0.64, green: 0.21, blue: 0.93)
        case 5: return Color(red: 1.0, green: 0.5, blue: 0.0)
        case 6: return Color(red: 0.9, green: 0.8, blue: 0.5)
        case 7, 8: return Color(red: 0.0, green: 0.8, blue: 1.0)
        default: return .white
        }
    }

    static func qualityName(_ q: Int?) -> String {
        switch q ?? 1 {
        case 0: return "Schlecht"
        case 1: return "Gewöhnlich"
        case 2: return "Selten"
        case 3: return "Rar"
        case 4: return "Episch"
        case 5: return "Legendär"
        case 6: return "Artefakt"
        case 7: return "Erbstück"
        default: return "–"
        }
    }

    static func questKind(_ c: String?) -> String {
        switch c ?? "Normal" {
        case "Campaign": return "Kampagne"
        case "WorldQuest": return "Weltquest"
        case "Important": return "Wichtig"
        case "Legendary": return "Legendär"
        case "Calling": return "Berufung"
        case "Meta": return "Meta"
        case "Recurring": return "Wiederholbar"
        case "Questline": return "Questreihe"
        case "BonusObjective": return "Bonusziel"
        case "Threat": return "Bedrohung"
        case "Normal": return "Normal"
        default: return c ?? "Normal"
        }
    }
}

enum Fmt {
    static func gold(_ copper: Int) -> String {
        let g = copper / 10000
        let s = (copper / 100) % 100
        let c = copper % 100
        if g > 0 { return "\(g.formatted()) G \(s) S" }
        if s > 0 { return "\(s) S \(c) K" }
        return "\(c) K"
    }

    static func duration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h) Std. \(m) Min." }
        return "\(m) Min."
    }
}

extension WowEvent {
    func title(questNames: [Int: String] = [:]) -> String {
        switch e {
        case "login": return "Eingeloggt" + (lv.map { " (Stufe \($0))" } ?? "")
        case "logout": return "Ausgeloggt nach \(Fmt.duration(dauer ?? 0))"
        case "zone":
            if let inst { return "Instanz betreten: \(inst)" + (diff.map { " (\($0))" } ?? "") }
            let sub = (sz ?? "").isEmpty ? "" : " – \(sz!)"
            return "Unterwegs in \(z ?? "?")\(sub)"
        case "quest_an": return "Quest angenommen: \(n ?? "?")"
        case "quest_ab": return "Quest abgeschlossen: \(n ?? "?")"
        case "quest_weg": return "Quest abgebrochen: \(q.flatMap { questNames[$0] } ?? "#\(q ?? 0)")"
        case "level": return "Stufe \(lv ?? 0) erreicht!"
        case "erfolg": return "Erfolg errungen: \(n ?? "?")" + (p.map { " (\($0) Punkte)" } ?? "")
        case "tod": return "Gestorben in \(z ?? "?")" + ((sz ?? "").isEmpty ? "" : " – \(sz!)")
        case "taxi_start": return "Flug mit dem Flugmeister gestartet"
        case "taxi_ende": return "Mit dem Flugmeister gelandet"
        case "notiz": return "„\(txt ?? "")“"
        case "ausr": return "Gegenstandsstufe \((il ?? 0).formatted(.number.precision(.fractionLength(1))))"
        case "talente": return "Talente: \(spec ?? "?")" + (lo.map { " – \($0)" } ?? "")
        case "gegenstand": return "Neu angelegt: \(n ?? "?")" + (il.map { " (\(Int($0)))" } ?? "")
        case "beute":
            let count = items?.count ?? 0
            return "Beute von \(sn ?? "Gegner") (\(count) \(count == 1 ? "Gegenstand" : "Gegenstände"))"
        default: return e
        }
    }

    var detail: String? {
        switch e {
        case "quest_ab":
            var parts: [String] = []
            if let z { parts.append(z) }
            if let xp, xp > 0 { parts.append("\(xp.formatted()) EP") }
            if let g, g > 0 { parts.append(Fmt.gold(g)) }
            if c != nil, c != "Normal" { parts.append(WowStyle.questKind(c)) }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        case "logout":
            if let dg, dg != 0 { return (dg > 0 ? "+" : "−") + Fmt.gold(abs(dg)) }
            return nil
        case "notiz": return z
        default: return nil
        }
    }

    var icon: String {
        switch e {
        case "login": return "arrow.right.circle"
        case "logout": return "arrow.left.circle"
        case "zone": return inst != nil ? "shield.lefthalf.filled" : "map"
        case "quest_an": return "exclamationmark.circle"
        case "quest_ab": return "checkmark.seal.fill"
        case "quest_weg": return "xmark.circle"
        case "level": return "arrow.up.circle.fill"
        case "erfolg": return "trophy.fill"
        case "tod": return "heart.slash.fill"
        case "taxi_start", "taxi_ende": return "airplane"
        case "notiz": return "note.text"
        case "ausr": return "shield.checkered"
        case "talente": return "sparkles"
        case "gegenstand": return "tshirt"
        case "beute": return "bag"
        default: return "circle"
        }
    }

    var tint: Color {
        switch e {
        case "quest_ab": return .yellow
        case "quest_an": return .orange
        case "quest_weg": return .gray
        case "level": return .green
        case "erfolg": return Color(red: 0.85, green: 0.65, blue: 0.13)
        case "tod": return .red
        case "notiz": return .purple
        case "taxi_start", "taxi_ende": return .indigo
        case "ausr": return .cyan
        case "talente": return .mint
        case "gegenstand": return WowStyle.qualityColor(quality)
        case "beute": return Theme.gold
        default: return .secondary
        }
    }
}
