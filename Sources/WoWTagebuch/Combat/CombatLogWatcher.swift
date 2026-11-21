import Foundation

/// Beobachtet den Ordner `_retail_/Logs` und liest neue Zeilen aus WoWCombatLog*.txt –
/// beim Start alles Ungelesene, danach live alle zwei Sekunden. Arbeitet auf einer eigenen Warteschlange.
final class CombatLogWatcher {
    struct Update {
        var fights: [Fight]
        var offsets: [String: Int]
        var live: Fight?
        var bytesRead: Int
    }

    private let queue = DispatchQueue(label: "WoWTagebuch.Kampflog", qos: .utility)
    private var parsers: [String: CombatLogParser] = [:]
    private var offsets: [String: Int]
    private var timer: DispatchSourceTimer?
    private let onUpdate: (Update) -> Void
    private var hadLive = false
    var logsFolder: URL
    var resolveKey: (String) -> String = CombatLogParser.defaultKey

    init(logsFolder: URL, offsets: [String: Int], onUpdate: @escaping (Update) -> Void) {
        self.logsFolder = logsFolder
        self.offsets = offsets
        self.onUpdate = onUpdate
    }

    func start() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 0.5, repeating: 2.0)
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
    }

    func stop() { timer?.cancel(); timer = nil }

    static func logFiles(in folder: URL) -> [URL] {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])) ?? []
        return files.filter { $0.lastPathComponent.hasPrefix("WoWCombatLog") && $0.pathExtension.lowercased() == "txt" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func poll() {
        var fights: [Fight] = []
        var read = 0
        let files = Self.logFiles(in: logsFolder)
        for url in files {
            let name = url.lastPathComponent
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            var offset = offsets[name] ?? 0
            if size < offset { offset = 0 }                       // Datei wurde neu angelegt
            guard size > offset, let handle = try? FileHandle(forReadingFrom: url) else { continue }
            defer { try? handle.close() }
            let parser = parsers[name] ?? {
                let p = CombatLogParser()
                p.resolveKey = resolveKey
                parsers[name] = p
                return p
            }()
            try? handle.seek(toOffset: UInt64(offset))
            // in Stücken lesen, damit auch große Dateien den Speicher nicht sprengen
            while offset < size {
                let chunk = (try? handle.read(upToCount: 8 * 1024 * 1024)) ?? Data()
                if chunk.isEmpty { break }
                guard let lastNewline = chunk.lastIndex(of: 0x0A) else { break }
                let complete = chunk[chunk.startIndex...lastNewline]
                let text = String(decoding: complete, as: UTF8.self)
                for line in CombatLogParser.lines(text) {
                    parser.parse(line: line)
                }
                let consumed = complete.count
                offset += consumed
                read += consumed
                if consumed < chunk.count { try? handle.seek(toOffset: UInt64(offset)) }
                fights += parser.takeFinished()
            }
            offsets[name] = offset
        }
        // Offene Kämpfe in allen Dateien schließen, wenn nichts mehr passiert
        let now = Date().timeIntervalSince1970
        var live: Fight?
        for (name, p) in parsers {
            p.closeIfIdle(now: now)
            // nur die zuletzt geschriebene Datei kann live sein
            if name == files.last?.lastPathComponent { live = p.current }
            fights += p.takeFinished()
        }
        if !fights.isEmpty || read > 0 || live != nil || hadLive {
            hadLive = live != nil
            let update = Update(fights: fights, offsets: offsets, live: live, bytesRead: read)
            DispatchQueue.main.async { self.onUpdate(update) }
        }
    }

    /// Liest eine einzelne Datei vollständig (Beispieldaten).
    static func parseAll(_ text: String) -> [Fight] {
        let p = CombatLogParser()
        for line in CombatLogParser.lines(text) { p.parse(line: line) }
        p.flush()
        return p.takeFinished()
    }
}
