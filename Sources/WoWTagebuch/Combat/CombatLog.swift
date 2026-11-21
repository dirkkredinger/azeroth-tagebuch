import Foundation

// MARK: - Ergebnis: ein Kampf

struct FightSpell: Codable, Hashable, Identifiable {
    var name: String
    var damage: Int = 0
    var healing: Int = 0
    var overheal: Int = 0
    var hits: Int = 0
    var crits: Int = 0
    var id: String { name }
}

/// Ein Gegner, der nach eigenem Schaden gestorben ist
struct FightKill: Codable, Hashable {
    var guid: String
    var npcID: Int?
    var name: String
    var t: Double
}

/// Ein zusammenhängender Kampf eines Charakters, berechnet aus dem offiziellen Kampflog.
struct Fight: Codable, Hashable, Identifiable {
    var char: String
    var start: Double
    var end: Double
    var zone: String?
    var mapID: Int?
    var encounter: String?
    var success: Bool?
    var damage: Int = 0
    var healing: Int = 0          // wirksame Heilung inkl. Schilde
    var overheal: Int = 0
    var absorb: Int = 0           // davon Schilde
    var taken: Int = 0
    var deaths: Int = 0
    var itemLevel: Double?
    var target: String?
    var spells: [FightSpell] = []
    var kills: [FightKill]? = nil

    var id: String { "\(char)|\(Int(start * 10))" }
    var date: Date { Date(timeIntervalSince1970: start) }
    var duration: Double { max(end - start, 1) }
    var dps: Double { Double(damage) / duration }
    var hps: Double { Double(healing) / duration }
    var title: String { encounter ?? target ?? "Kampf" }
}

// MARK: - Parser

/// Liest Zeilen aus WoWCombatLog*.txt und fasst die Ereignisse des eigenen Charakters
/// (inkl. Begleiter) zu Kämpfen zusammen. Zustandsbehaftet, damit er Datei-Stücke live verarbeiten kann.
final class CombatLogParser {
    /// Erhöhen, wenn sich die Auswertung ändert – die App liest dann alle Kampflogs neu ein.
    static let version = 3

    /// Pause ohne Kampfgeschehen, nach der ein Kampf als beendet gilt (Sekunden)
    static let gap: Double = 6

    private(set) var finished: [Fight] = []
    private(set) var current: Fight?

    private var advanced = true
    private var zone: String?
    private var mapID: Int?
    private var encounter: String?
    private var myGUID: String?
    private var myKey: String?
    private var lastActivity: Double = 0
    private var spellIndex: [String: Int] = [:]
    private var targetDamage: [String: Int] = [:]
    private var lastTime: Double = 0
    /// Gegner, die zuletzt Schaden von mir bekommen haben (GUID → Zeit)
    private var recentlyHit: [String: Double] = [:]

    /// Ordnet Namen aus dem Log ("Name-Realm-EU") einem Charakter-Schlüssel ("Name-Realm") zu.
    var resolveKey: (String) -> String = CombatLogParser.defaultKey

    static func defaultKey(_ logName: String) -> String {
        let parts = logName.split(separator: "-", omittingEmptySubsequences: false)
        if parts.count >= 3 { return parts.dropLast().joined(separator: "-") }
        return logName
    }

    /// Gibt abgeschlossene Kämpfe zurück und leert die Liste.
    func takeFinished() -> [Fight] {
        defer { finished.removeAll() }
        return finished
    }

    /// Beendet einen offenen Kampf, wenn seit dem letzten Geschehen genug Zeit vergangen ist.
    func closeIfIdle(now: Double) {
        if current != nil, now - lastActivity > Self.gap { closeFight() }
    }

    func flush() { closeFight() }

    // MARK: Zeilen

    func parse(line: Substring) {
        guard let sep = line.range(of: "  ") else { return }
        guard let time = Self.parseTime(line[line.startIndex..<sep.lowerBound]) else { return }
        let body = line[sep.upperBound...]
        let eventEnd = body.firstIndex(of: ",") ?? body.endIndex
        let event = body[body.startIndex..<eventEnd]
        lastTime = time

        if current != nil, time - lastActivity > Self.gap { closeFight() }

        switch event {
        case "COMBAT_LOG_VERSION":
            let f = Self.fields(body)
            if let i = f.firstIndex(of: "ADVANCED_LOG_ENABLED"), i + 1 < f.count { advanced = f[i + 1] == "1" }
        case "ZONE_CHANGE":
            let f = Self.fields(body)
            if f.count > 2 { zone = f[2] }
        case "MAP_CHANGE":
            let f = Self.fields(body)
            if f.count > 1, let m = Int(f[1]) { mapID = m }
        case "ENCOUNTER_START":
            let f = Self.fields(body)
            closeFight()
            encounter = f.count > 2 ? f[2] : nil
        case "ENCOUNTER_END":
            let f = Self.fields(body)
            if current != nil {
                current?.encounter = encounter
                current?.success = f.count > 5 ? f[5] == "1" : nil
                lastActivity = time
                closeFight()
            }
            encounter = nil
        case "SWING_DAMAGE", "RANGE_DAMAGE", "SPELL_DAMAGE", "SPELL_PERIODIC_DAMAGE", "SPELL_BUILDING_DAMAGE",
             "DAMAGE_SHIELD", "DAMAGE_SPLIT", "ENVIRONMENTAL_DAMAGE":
            handleDamage(String(event), Self.fields(body), time)
        case "SPELL_HEAL", "SPELL_PERIODIC_HEAL":
            handleHeal(Self.fields(body), time)
        case "SPELL_ABSORBED":
            handleAbsorb(Self.fields(body), time)
        case "UNIT_DIED", "UNIT_DESTROYED":
            let f = Self.fields(body)
            guard f.count > 7 else { break }
            if Self.isMyPlayer(f[7]), current != nil { current?.deaths += 1 }
            if let hit = recentlyHit.removeValue(forKey: f[5]), time - hit < 120 {
                let kill = FightKill(guid: f[5], npcID: Self.npcID(f[5]), name: f[6], t: time)
                if current != nil {
                    current!.kills = (current!.kills ?? []) + [kill]
                } else if var last = finished.popLast(), time - last.end < 30 {
                    last.kills = (last.kills ?? []) + [kill]
                    finished.append(last)
                } else if let last = finished.popLast() {
                    finished.append(last)
                }
            }
        default:
            break
        }
    }

    // MARK: Ereignisse

    private func prefixLength(_ event: String) -> Int {
        if event.hasPrefix("SWING_") { return 0 }
        if event.hasPrefix("ENVIRONMENTAL_") { return 1 }
        return 3
    }

    private func handleDamage(_ event: String, _ f: [String], _ time: Double) {
        guard f.count > 9 else { return }
        let pre = prefixLength(event)
        let s = suffixStart(f, at: 9 + pre)
        guard f.count > s, let amount = Int(f[s]) else { return }
        let srcFlags = Self.flags(f[3]), dstFlags = Self.flags(f[7])

        if Self.isMine(srcFlags) && !Self.isMine(dstFlags) {
            noteMe(f, srcFlags)
            begin(time)
            current?.damage += amount
            let name = pre == 3 ? f[10] : (event.hasPrefix("SWING") ? "Nahkampf" : "Umgebung")
            addSpell(name: name, damage: amount, crit: critical(f, s, heal: false))
            targetDamage[f[6], default: 0] += amount
            if f[5].hasPrefix("Creature-") || f[5].hasPrefix("Vehicle-") {
                recentlyHit[f[5]] = time
                if recentlyHit.count > 2000 { recentlyHit = recentlyHit.filter { time - $0.value < 120 } }
            }
            if advanced, f[9 + pre] == f[1], Self.isMyPlayer(f[3]) {
                readAdvanced(f, at: 9 + pre, suffix: s)
            }
        } else if Self.isMyPlayer(f[7]) && !Self.isMine(srcFlags) {
            noteMeAsTarget(f)
            begin(time)
            current?.taken += amount
        }
    }

    private func handleHeal(_ f: [String], _ time: Double) {
        guard f.count > 12, Self.isMine(Self.flags(f[3])) else { return }
        let s = suffixStart(f, at: 12)
        guard f.count > s + 1, let amount = Int(f[s]) else { return }
        let rest = f.count - s
        let over = Int(rest >= 5 ? f[s + 2] : f[s + 1]) ?? 0
        let effective = max(amount - over, 0)
        noteMe(f, Self.flags(f[3]))
        // Reine Überheilung außerhalb eines Kampfes ist kein Kampfbeginn
        if current == nil && effective == 0 { return }
        begin(time)
        current?.healing += effective
        current?.overheal += over
        addSpell(name: f[10], healing: effective, overheal: over, crit: critical(f, s, heal: true))
        if advanced, f[12] == f[1], Self.isMyPlayer(f[3]) { readAdvanced(f, at: 12, suffix: s) }
    }

    private func handleAbsorb(_ f: [String], _ time: Double) {
        // SPELL_ABSORBED, Angreifer(4), Ziel(4), [Zauber des Angreifers(3)], Schildwirker(4), Schildzauber(3), Menge, …
        guard f.count > 16 else { return }
        let a = Self.looksLikeGUID(f[9]) ? 9 : 12
        guard f.count > a + 7, Self.isMine(Self.flags(f[a + 2])), let amount = Int(f[a + 7]) else { return }
        noteMe(f, 0)
        guard current != nil || amount > 0 else { return }
        begin(time)
        current?.healing += amount
        current?.absorb += amount
        addSpell(name: f[a + 5], healing: amount, crit: false)
    }

    private func critical(_ f: [String], _ s: Int, heal: Bool) -> Bool {
        // Krit-Feld: bei Heilung das letzte, bei Schaden das 8. bzw. 7. Feld nach der Menge
        if heal { return f.last == "1" }
        let rest = f.count - s
        let idx = rest >= 11 ? s + 7 : s + 6
        return idx < f.count && f[idx] == "1"
    }

    /// Index des ersten Feldes nach dem erweiterten Datenblock (Menge bei Schaden/Heilung).
    /// Der Block endet mit Position X, Position Y, Karten-ID, Blickrichtung, Stufe. Seine Länge
    /// hat sich zwischen Spielversionen geändert (17 → 19 Felder), daher wird das Ende gesucht.
    private func suffixStart(_ f: [String], at a: Int) -> Int {
        guard advanced else { return a }
        var i = a + 10
        while i + 4 < f.count {
            if f[i].contains("."), f[i + 1].contains("."), Int(f[i + 2]) != nil, f[i + 3].contains("."),
               Double(f[i]) != nil, Double(f[i + 1]) != nil, Double(f[i + 3]) != nil {
                return i + 5
            }
            i += 1
        }
        return a + 17
    }

    private func readAdvanced(_ f: [String], at a: Int, suffix s: Int) {
        guard s >= 5, s <= f.count else { return }
        if let m = Int(f[s - 3]), m > 0 { mapID = m; current?.mapID = m }
        if let il = Double(f[s - 1]), il > 0 { current?.itemLevel = il }
    }

    private func noteMe(_ f: [String], _ srcFlags: UInt32) {
        if Self.isMyPlayer(f[3]), f[1].hasPrefix("Player-") {
            if myGUID != f[1] {
                myGUID = f[1]
                myKey = resolveKey(f[2])
            }
        }
    }

    private func noteMeAsTarget(_ f: [String]) {
        if f[5].hasPrefix("Player-"), myGUID != f[5] {
            myGUID = f[5]
            myKey = resolveKey(f[6])
        }
    }

    private func begin(_ time: Double) {
        if current == nil {
            current = Fight(char: myKey ?? "?", start: time, end: time, zone: zone, mapID: mapID, encounter: encounter)
            spellIndex = [:]
            targetDamage = [:]
        }
        if current?.char == "?", let myKey { current?.char = myKey }
        current?.end = time
        lastActivity = time
    }

    private func addSpell(name: String, damage: Int = 0, healing: Int = 0, overheal: Int = 0, crit: Bool) {
        guard current != nil else { return }
        if let i = spellIndex[name] {
            current!.spells[i].damage += damage
            current!.spells[i].healing += healing
            current!.spells[i].overheal += overheal
            current!.spells[i].hits += 1
            if crit { current!.spells[i].crits += 1 }
        } else {
            spellIndex[name] = current!.spells.count
            current!.spells.append(FightSpell(name: name, damage: damage, healing: healing, overheal: overheal,
                                              hits: 1, crits: crit ? 1 : 0))
        }
    }

    private func closeFight() {
        guard var fight = current else { return }
        current = nil
        fight.target = targetDamage.max { $0.value < $1.value }?.key
        fight.spells.sort { ($0.damage + $0.healing) > ($1.damage + $1.healing) }
        // Kleinstkämpfe (ein einzelner Treffer, kurze Selbstheilung) verwerfen
        let total = fight.damage + fight.healing + fight.taken
        guard fight.char != "?", total > 0, fight.end - fight.start >= 2 || fight.encounter != nil else { return }
        finished.append(fight)
    }

    // MARK: Hilfen

    /// Zerlegt Text in Zeilen. WoW schreibt Windows-Zeilenenden (\r\n) – für Swift ist das *ein* Zeichen.
    static func lines(_ text: String) -> [Substring] {
        text.split(whereSeparator: { $0 == "\n" || $0 == "\r\n" || $0 == "\r" })
    }

    static func flags(_ s: String) -> UInt32 {
        UInt32(s.hasPrefix("0x") ? s.dropFirst(2) : Substring(s), radix: 16) ?? 0
    }

    /// Gehört zum eigenen Spieler (inkl. Begleiter, Wächter, Totems)
    static func isMine(_ flags: UInt32) -> Bool { flags & 0x1 != 0 }

    static func isMyPlayer(_ flagString: String) -> Bool {
        let f = flags(flagString)
        return f & 0x1 != 0 && f & 0x400 != 0
    }

    /// NPC-ID aus einer GUID wie "Creature-0-3771-530-28143-16879-001E814CC3" (sechstes Feld)
    static func npcID(_ guid: String) -> Int? {
        let p = guid.split(separator: "-")
        return p.count >= 6 ? Int(p[5]) : nil
    }

    static func looksLikeGUID(_ s: String) -> Bool {
        s.hasPrefix("Player-") || s.hasPrefix("Creature-") || s.hasPrefix("Pet-") || s.hasPrefix("Vehicle-")
            || s.hasPrefix("GameObject-") || s == "0000000000000000"
    }

    /// Zerlegt die Felder einer Zeile (Komma-getrennt, Texte in Anführungszeichen).
    static func fields(_ s: Substring) -> [String] {
        var out: [String] = []
        out.reserveCapacity(40)
        var cur = ""
        var inQuotes = false
        for ch in s {
            if ch == "\"" { inQuotes.toggle(); continue }
            if ch == "," && !inQuotes { out.append(cur); cur = ""; continue }
            if ch == "\r" { continue }
            cur.append(ch)
        }
        out.append(cur)
        return out
    }

    /// "11/21/2026 20:15:03.1234-1" oder "11/21 20:15:03.123" → Unix-Zeit (lokale Zeit)
    static func parseTime(_ s: Substring) -> Double? {
        let parts = s.split(separator: " ")
        guard parts.count == 2 else { return nil }
        let d = parts[0].split(separator: "/")
        guard d.count >= 2, let month = Int(d[0]), let day = Int(d[1]) else { return nil }
        let year = d.count > 2 ? Int(d[2]) : nil
        var timePart = parts[1]
        if let tz = timePart.lastIndex(where: { $0 == "-" || $0 == "+" }) { timePart = timePart[..<tz] }
        let t = timePart.split(separator: ":")
        guard t.count == 3, let h = Int(t[0]), let mi = Int(t[1]), let sec = Double(t[2]) else { return nil }
        var comps = DateComponents()
        comps.year = year ?? Calendar.current.component(.year, from: Date())
        comps.month = month; comps.day = day; comps.hour = h; comps.minute = mi
        comps.second = Int(sec)
        guard let date = Calendar.current.date(from: comps) else { return nil }
        return date.timeIntervalSince1970 + (sec - Double(Int(sec)))
    }
}
