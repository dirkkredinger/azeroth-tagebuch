import Foundation
import Observation
import AppKit

/// Liest die SavedVariables des Addons, führt sie in ein dauerhaftes Archiv zusammen
/// und beobachtet die Dateien, damit die App nach jedem Ausloggen aktuell ist.
@Observable
final class DataStore {
    var characters: [WowCharacter] = []
    var maps: [Int: MapInfo] = [:]
    var status: String = ""
    var lastUpdate: Date?
    var isDemo = false
    var wowFolder: URL
    var foundFiles: [URL] = []
    /// Kämpfe aus dem Kampflog je Charakter (neueste zuletzt)
    var fightsByChar: [String: [Fight]] = [:]
    /// Gerade laufender Kampf (live aus dem Kampflog)
    var liveFight: Fight?
    var combatLogFound = false
    var warbands: [String: Storage] = [:]
    var guilds: [String: Storage] = [:]
    let mapArt: MapArtStore
    let icons: IconStore

    @ObservationIgnored private var archive = Archive()
    @ObservationIgnored private var mtimes: [String: Date] = [:]
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var watcher: CombatLogWatcher?
    @ObservationIgnored private var lastOffsetSave = Date.distantPast

    static let defaultFolder = URL(fileURLWithPath: "/Applications/World of Warcraft/_retail_")
    static let fileName = "AzerothTagebuch.lua"

    init() {
        let folder = UserDefaults.standard.string(forKey: "wowFolder").map { URL(fileURLWithPath: $0) } ?? Self.defaultFolder
        wowFolder = folder
        mapArt = MapArtStore(gameFolder: folder.deletingLastPathComponent())
        icons = IconStore(gameFolder: folder.deletingLastPathComponent())
        loadArchive()
        publish()
        reload()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        startCombatLog()
    }

    // MARK: Kampflog

    private func startCombatLog() {
        watcher?.stop()
        let logs = wowFolder.appendingPathComponent("Logs", isDirectory: true)
        let w = CombatLogWatcher(logsFolder: logs, offsets: archive.logOffsets) { [weak self] update in
            self?.apply(update)
        }
        watcher = w
        w.start()
    }

    private func apply(_ update: CombatLogWatcher.Update) {
        guard !isDemo else { return }
        combatLogFound = true
        liveFight = update.live.map { var f = $0; f.char = resolveCharKey(f.char); return f }
        archive.logOffsets = update.offsets
        let added = Self.mergeFights(update.fights, into: &archive)
        if added > 0 || Date().timeIntervalSince(lastOffsetSave) > 60 {
            saveArchive()
            lastOffsetSave = Date()
        }
        if added > 0 { fightsByChar = archive.fights }
    }

    /// Ordnet "Name-Realm" aus dem Kampflog einem bekannten Charakter zu (Realmnamen stehen dort ohne Leerzeichen).
    private func resolveCharKey(_ logKey: String) -> String {
        Self.resolveCharKey(logKey, in: archive.characters)
    }

    private static func resolveCharKey(_ logKey: String, in characters: [String: WowCharacter]) -> String {
        if characters[logKey] != nil { return logKey }
        func norm(_ s: String) -> String {
            s.lowercased().filter { $0.isLetter || $0.isNumber }
        }
        let n = norm(logKey)
        return characters.keys.first { norm($0) == n } ?? logKey
    }

    @discardableResult
    private static func mergeFights(_ fights: [Fight], into target: inout Archive) -> Int {
        var added = 0
        for var f in fights {
            f.char = resolveCharKey(f.char, in: target.characters)
            var list = target.fights[f.char] ?? []
            if list.contains(where: { $0.id == f.id }) { continue }
            list.append(f)
            list.sort { $0.start < $1.start }
            target.fights[f.char] = list
            added += 1
        }
        return added
    }

    func fights(for key: String) -> [Fight] { fightsByChar[key] ?? [] }

    // MARK: Dateien

    private var archiveURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("WoWTagebuch", isDirectory: true)
            .appendingPathComponent("archiv.json")
    }

    func findFiles() -> [URL] {
        let accounts = wowFolder.appendingPathComponent("WTF/Account", isDirectory: true)
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(at: accounts, includingPropertiesForKeys: nil) else { return [] }
        return dirs.compactMap { dir in
            let file = dir.appendingPathComponent("SavedVariables").appendingPathComponent(Self.fileName)
            return fm.fileExists(atPath: file.path) ? file : nil
        }.sorted { $0.path < $1.path }
    }

    private func modDate(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    private func loadArchive() {
        guard let data = try? Data(contentsOf: archiveURL) else { return }
        if let decoded = try? JSONDecoder().decode(Archive.self, from: data) { archive = decoded }
        // Neuer Parser → Kampflogs komplett neu auswerten
        if archive.combatParserVersion != CombatLogParser.version {
            archive.fights = [:]
            archive.logOffsets = [:]
            archive.combatParserVersion = CombatLogParser.version
        }
    }

    private func saveArchive() {
        do {
            try FileManager.default.createDirectory(at: archiveURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(archive)
            try data.write(to: archiveURL, options: .atomic)
        } catch {
            status = "Archiv konnte nicht gespeichert werden: \(error.localizedDescription)"
        }
    }

    // MARK: Einlesen

    func reload() {
        if isDemo { isDemo = false; archive = Archive(); loadArchive() }
        foundFiles = findFiles()
        guard !foundFiles.isEmpty else {
            status = archive.characters.isEmpty
                ? "Noch keine Tagebuch-Daten gefunden"
                : "Keine neue Datei gefunden – zeige Archiv"
            publish()
            return
        }
        var added = 0
        var errors: [String] = []
        for url in foundFiles {
            do {
                let data = try Data(contentsOf: url)
                let account = url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
                added += try Self.ingest(data: data, account: account, into: &archive)
                mtimes[url.path] = modDate(url)
            } catch {
                errors.append("\(url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent): \(error.localizedDescription)")
            }
        }
        if added > 0 { saveArchive() }
        publish()
        lastUpdate = Date()
        if !errors.isEmpty {
            status = "Fehler: " + errors.joined(separator: "; ")
        } else {
            status = added > 0 ? "\(added) neue Einträge eingelesen" : "Alles aktuell"
        }
    }

    private func checkForChanges() {
        guard !isDemo else { return }
        let files = findFiles()
        let changed = files.count != foundFiles.count || files.contains { modDate($0) != mtimes[$0.path] }
        if changed { reload() }
    }

    /// Übernimmt neue Einträge aus einer SavedVariables-Datei ins Archiv. Gibt die Anzahl neuer Einträge zurück.
    @discardableResult
    static func ingest(data: Data, account: String?, into target: inout Archive) throws -> Int {
        let vars = try LuaParser.parseAssignments(data)
        guard let db = vars["AzerothTagebuchDB"]?.table else { return 0 }

        if let maps = db.dict["maps"]?.table {
            for (key, value) in maps.dict {
                if let name = value["n"]?.string {
                    target.maps[key] = MapInfo(name: name, parent: value["p"]?.int, type: value["ty"]?.int)
                }
            }
        }

        if let w = Storage(lua: db.dict["warband"]) {
            let acc = account ?? "?"
            if w.t >= (target.warbands[acc]?.t ?? 0) { target.warbands[acc] = w }
        }
        for (name, gv) in db.dict["guilds"]?.table?.dict ?? [:] {
            if let g = Storage(lua: gv), g.t >= (target.guilds[name]?.t ?? 0) { target.guilds[name] = g }
        }

        var added = 0
        for (key, cv) in db.dict["chars"]?.table?.dict ?? [:] {
            var ch = target.characters[key]
                ?? WowCharacter(key: key, name: cv["name"]?.string ?? key, realm: cv["realm"]?.string ?? "")
            if let v = cv["name"]?.string { ch.name = v }
            if let v = cv["realm"]?.string { ch.realm = v }
            if let v = cv["class"]?.string { ch.classToken = v }
            if let v = cv["classLocal"]?.string { ch.className = v }
            if let v = cv["raceLocal"]?.string ?? cv["race"]?.string { ch.race = v }
            if let v = cv["faction"]?.string { ch.faction = v }
            if let v = cv["level"]?.int { ch.level = v }
            if let v = cv["spec"]?.string { ch.spec = v }
            if let v = cv["money"]?.int { ch.money = v }
            if let v = cv["specID"]?.int { ch.specID = v }
            if let v = cv["role"]?.string { ch.role = v }
            if let v = cv["specDesc"]?.string { ch.specDesc = v }
            if let v = cv["primaryStat"]?.int { ch.primaryStat = v }
            if let v = cv["talentCode"]?.string { ch.talentCode = v }
            if let v = cv["ilvl"]?.double { ch.itemLevel = v }
            if let v = cv["guild"]?.string { ch.guild = v }
            // Lager: nur übernehmen, wenn der Stand neuer ist
            if let b = Storage(lua: cv["bags"]), b.t >= (ch.bags?.t ?? 0) { ch.bags = b }
            if let b = Storage(lua: cv["bank"]), b.t >= (ch.bank?.t ?? 0) { ch.bank = b }
            if let g = cv["gear"]?.table {
                var gear: [Int: GearItem] = [:]
                for (k, v) in g.dict { if let slot = Int(k), let item = GearItem(lua: v) { gear[slot] = item } }
                for (i, v) in g.array.enumerated() { if let item = GearItem(lua: v), gear[i + 1] == nil { gear[i + 1] = item } }
                ch.gear = gear
            }
            if let account { ch.account = account }

            let known = Set(ch.events.map(\.dedupeKey))
            let fresh = (cv["events"]?.table?.items ?? [])
                .compactMap(WowEvent.init(lua:))
                .filter { !known.contains($0.dedupeKey) }
            if !fresh.isEmpty {
                ch.events.append(contentsOf: fresh)
                ch.events.sort { $0.t < $1.t }
                added += fresh.count
            }
            target.characters[key] = ch
        }
        return added
    }

    private func publish() {
        characters = archive.characters.values.sorted {
            if ($0.level ?? 0) != ($1.level ?? 0) { return ($0.level ?? 0) > ($1.level ?? 0) }
            return $0.name < $1.name
        }
        var m: [Int: MapInfo] = [:]
        for (k, v) in archive.maps { if let id = Int(k) { m[id] = v } }
        maps = m
        fightsByChar = archive.fights
        warbands = archive.warbands
        guilds = archive.guilds
        // Kartenbilder für alle Zonen vorbereiten, in denen ein Charakter unterwegs war
        var ids = Set<Int>()
        for ch in archive.characters.values {
            for ev in ch.events where ev.e == "pos" { if let id = ev.m { ids.insert(id) } }
        }
        mapArt.requestAll(ids)
    }

    // MARK: Beispieldaten & Ordnerwahl

    func loadDemo() {
        guard let url = Bundle.module.url(forResource: "Beispiel", withExtension: "lua"),
              let data = try? Data(contentsOf: url) else {
            status = "Beispieldaten nicht gefunden"
            return
        }
        var demo = Archive()
        do {
            try Self.ingest(data: data, account: "DEMO", into: &demo)
            if let logURL = Bundle.module.url(forResource: "BeispielKampflog", withExtension: "txt"),
               let text = try? String(contentsOf: logURL, encoding: .utf8) {
                let fights = CombatLogWatcher.parseAll(text)
                Self.mergeFights(fights, into: &demo)
            }
            archive = demo
            liveFight = nil
            isDemo = true
            publish()
            status = "Beispieldaten – echte Daten mit „Neu einlesen“"
        } catch {
            status = "Beispieldaten fehlerhaft: \(error.localizedDescription)"
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Wähle den Ordner „_retail_“ deiner WoW-Installation"
        panel.directoryURL = wowFolder
        if panel.runModal() == .OK, let url = panel.url {
            wowFolder = url.lastPathComponent == "WTF" ? url.deletingLastPathComponent() : url
            UserDefaults.standard.set(wowFolder.path, forKey: "wowFolder")
            mapArt.gameFolder = wowFolder.deletingLastPathComponent()
            icons.gameFolder = wowFolder.deletingLastPathComponent()
            reload()
            startCombatLog()
        }
    }

    func mapName(_ id: Int?) -> String {
        guard let id else { return "Unbekannt" }
        return maps[id]?.name ?? "Karte \(id)"
    }
}
