import SwiftUI

/// Auswertung: welche Gegner (und Vorkommen) wurden besiegt bzw. geplündert und was fiel wie oft?
struct LootStats {
    struct ItemDrop: Identifiable {
        var key: String
        var itemID: Int?
        var name: String
        var quality: Int?
        var icon: Int?
        var times = 0          // in wie vielen Beutefenstern
        var total = 0          // Gesamtmenge
        var id: String { key }
    }

    struct Source: Identifiable {
        var key: String
        var npcID: Int?
        var name: String
        var isObject: Bool
        var kills = 0
        var looted = 0
        var lastSeen: Date = .distantPast
        var zones = Set<String>()
        var items: [String: ItemDrop] = [:]
        var id: String { key }

        var sortedItems: [ItemDrop] { items.values.sorted { $0.times != $1.times ? $0.times > $1.times : ($0.quality ?? 0) > ($1.quality ?? 0) } }
        func rate(_ item: ItemDrop) -> Double { looted > 0 ? Double(item.times) / Double(looted) : 0 }
        /// Kills mindestens so viele wie geplünderte Leichen (falls kein Kampflog lief)
        var effectiveKills: Int { isObject ? 0 : max(kills, looted) }
    }

    var sources: [Source] = []

    init(characters: [WowCharacter], fights: [String: [Fight]]) {
        var byKey: [String: Source] = [:]
        var nameForGUID: [String: String] = [:]
        var nameForNPC: [Int: String] = [:]

        for ch in characters {
            for f in fights[ch.key] ?? [] {
                for k in f.kills ?? [] {
                    nameForGUID[k.guid] = k.name
                    if let id = k.npcID { nameForNPC[id] = k.name }
                    let key = k.npcID.map { "npc\($0)" } ?? "name\(k.name)"
                    var s = byKey[key] ?? Source(key: key, npcID: k.npcID, name: k.name, isObject: false)
                    s.kills += 1
                    s.lastSeen = max(s.lastSeen, Date(timeIntervalSince1970: k.t))
                    if let z = f.zone { s.zones.insert(z) }
                    byKey[key] = s
                }
            }
            for ev in ch.lootEvents {
                if let id = ev.npc, let n = ev.sn { nameForNPC[id] = n }
            }
        }
        for ch in characters {
            for ev in ch.lootEvents {
                let isObject = ev.art == "GameObject"
                let name = ev.sn ?? ev.src.flatMap { nameForGUID[$0] } ?? ev.npc.flatMap { nameForNPC[$0] }
                    ?? (ev.npc.map { isObject ? "Vorkommen #\($0)" : "Gegner #\($0)" } ?? "Unbekannte Quelle")
                let key = ev.npc.map { (isObject ? "obj" : "npc") + "\($0)" } ?? "name\(name)"
                var s = byKey[key] ?? Source(key: key, npcID: ev.npc, name: name, isObject: isObject)
                if s.name.hasPrefix("Gegner #") || s.name.hasPrefix("Vorkommen #") { s.name = name }
                s.looted += 1
                s.lastSeen = max(s.lastSeen, ev.date)
                if let z = ev.z, !z.isEmpty { s.zones.insert(z) }
                // gleiche Gegenstände in einem Beutefenster nur einmal zählen
                var seen = Set<String>()
                for it in ev.items ?? [] {
                    var drop = s.items[it.key] ?? ItemDrop(key: it.key, itemID: it.itemID, name: it.name ?? "?",
                                                         quality: it.quality, icon: it.icon)
                    if !seen.contains(it.key) { drop.times += 1; seen.insert(it.key) }
                    drop.total += it.count ?? 1
                    s.items[it.key] = drop
                }
                byKey[key] = s
            }
        }
        sources = Array(byKey.values)
    }
}

struct LootView: View {
    let character: WowCharacter
    @Environment(DataStore.self) private var store
    @AppStorage("beuteAlleCharaktere") private var allCharacters = false
    @State private var showObjects = false
    @State private var search = ""
    @State private var sort = Sort.kills
    @State private var expanded: String?

    enum Sort: String, CaseIterable, Identifiable { case kills = "Kills", recent = "Zuletzt", name = "Name"; var id: String { rawValue } }

    var body: some View {
        let stats = LootStats(characters: allCharacters ? store.characters : [character], fights: store.fightsByChar)
        let list = filtered(stats.sources)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                tiles(stats.sources)
                controls
                if list.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 8) {
                        ForEach(list) { src in
                            SourceRow(source: src, expanded: expanded == src.id) {
                                withAnimation(.easeInOut(duration: 0.15)) { expanded = expanded == src.id ? nil : src.id }
                            }
                        }
                    }
                }
                rareFinds(stats.sources)
            }
            .padding(20)
        }
    }

    private func filtered(_ all: [LootStats.Source]) -> [LootStats.Source] {
        all.filter { $0.isObject == showObjects }
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
                || $0.items.values.contains { $0.name.localizedCaseInsensitiveContains(search) } }
            .sorted {
                switch sort {
                case .kills: return ($0.effectiveKills, $0.looted) > ($1.effectiveKills, $1.looted)
                case .recent: return $0.lastSeen > $1.lastSeen
                case .name: return $0.name.localizedCompare($1.name) == .orderedAscending
                }
            }
    }

    private func tiles(_ all: [LootStats.Source]) -> some View {
        let mobs = all.filter { !$0.isObject }
        let corpses = all.reduce(0) { $0 + $1.looted }
        let items = all.reduce(0) { $0 + $1.items.values.reduce(0) { $0 + $1.total } }
        let rare = all.reduce(0) { $0 + $1.items.values.filter { ($0.quality ?? 0) >= 2 }.reduce(0) { $0 + $1.times } }
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
            StatTile(title: "Gegner besiegt", value: mobs.reduce(0) { $0 + $1.effectiveKills }.formatted(), icon: "flame", tint: Theme.damage)
            StatTile(title: "Verschiedene Gegner", value: "\(mobs.count)", icon: "pawprint", tint: .orange)
            StatTile(title: "Geplündert", value: corpses.formatted(), icon: "bag", tint: Theme.gold)
            StatTile(title: "Gegenstände erbeutet", value: items.formatted(), icon: "shippingbox", tint: Theme.parchment)
            StatTile(title: "Seltene Funde (grün+)", value: "\(rare)", icon: "sparkles", tint: WowStyle.qualityColor(3))
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("", selection: $showObjects) {
                Text("Gegner").tag(false)
                Text("Vorkommen & Truhen").tag(true)
            }
            .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 280)
            Picker("Sortierung", selection: $sort) {
                ForEach(Sort.allCases) { Text($0.rawValue).tag($0) }
            }
            .frame(maxWidth: 170)
            Toggle("Alle Charaktere", isOn: $allCharacters).toggleStyle(.switch)
            Spacer()
            TextField("Gegner oder Gegenstand suchen", text: $search)
                .textFieldStyle(.roundedBorder).frame(maxWidth: 260)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(showObjects ? "Noch keine Vorkommen geplündert" : "Noch keine Beute erfasst", systemImage: "bag")
                .font(Theme.heading(18)).foregroundStyle(Theme.gold)
            Text("""
            Besiegte Gegner kommen aus dem Kampflog, die Beute schreibt das Addon (ab Version 1.2) mit, sobald du ein Beutefenster öffnest – \
            auch mit automatischem Plündern. Die Droprate ist: wie oft ein Gegenstand dabei war, geteilt durch die geplünderten Leichen dieses Gegners.
            """)
            .foregroundStyle(Theme.parchmentDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wowPanel(padding: 18)
    }

    @ViewBuilder private func rareFinds(_ all: [LootStats.Source]) -> some View {
        let finds = all.flatMap { s in s.items.values.filter { ($0.quality ?? 0) >= 2 }.map { (s, $0) } }
            .sorted { ($0.1.quality ?? 0, $0.1.times) > ($1.1.quality ?? 0, $1.1.times) }
        if !finds.isEmpty {
            GroupBox("Seltene Funde") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10)], spacing: 8) {
                    ForEach(finds.prefix(30), id: \.1.key) { src, item in
                        HStack(spacing: 8) {
                            ItemIcon(icon: item.icon, quality: item.quality, size: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name).foregroundStyle(WowStyle.qualityColor(item.quality)).fontWeight(.semibold).lineLimit(1)
                                Text("von \(src.name) · \(Int(src.rate(item) * 100)) %").font(.caption).foregroundStyle(Theme.parchmentDim)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }
}

struct SourceRow: View {
    let source: LootStats.Source
    let expanded: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: toggle) {
                HStack(spacing: 12) {
                    Image(systemName: source.isObject ? "leaf" : "pawprint.fill")
                        .foregroundStyle(source.isObject ? Theme.healing : Theme.damage).frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.name).font(.system(.body, design: .serif).weight(.semibold)).foregroundStyle(Theme.parchment)
                        Text(source.zones.sorted().joined(separator: ", ")).font(.caption).foregroundStyle(Theme.parchmentDim).lineLimit(1)
                    }
                    Spacer()
                    HStack(spacing: -6) {
                        ForEach(source.sortedItems.prefix(5)) { ItemIcon(icon: $0.icon, quality: $0.quality, size: 24) }
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        if !source.isObject {
                            Text("\(source.effectiveKills)× besiegt").font(.callout.weight(.semibold)).foregroundStyle(Theme.parchment)
                        }
                        Text("\(source.looted)× geplündert").font(.caption).foregroundStyle(Theme.parchmentDim)
                    }
                    .frame(width: 110, alignment: .trailing)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption).foregroundStyle(Theme.goldDim)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                if source.items.isEmpty {
                    Text(source.looted == 0 ? "Nie geplündert – kein Beutefenster erfasst." : "Keine Gegenstände.")
                        .font(.caption).foregroundStyle(Theme.parchmentDim).padding(.leading, 32)
                } else {
                    VStack(spacing: 6) {
                        ForEach(source.sortedItems) { item in
                            DropRow(item: item, rate: source.rate(item), looted: source.looted)
                        }
                    }
                    .padding(.leading, 32)
                }
            }
        }
        .wowPanel(padding: 10)
    }
}

struct DropRow: View {
    let item: LootStats.ItemDrop
    let rate: Double
    let looted: Int

    var body: some View {
        HStack(spacing: 10) {
            ItemIcon(icon: item.icon, quality: item.quality, size: 28)
            Group {
                if let id = item.itemID, let url = URL(string: "https://www.wowhead.com/de/item=\(id)") {
                    Link(destination: url) { Text(item.name).underline(false) }
                } else {
                    Text(item.name)
                }
            }
            .foregroundStyle(WowStyle.qualityColor(item.quality))
            .frame(width: 230, alignment: .leading)
            .lineLimit(1)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.35))
                    RoundedRectangle(cornerRadius: 3).fill(WowStyle.qualityColor(item.quality).opacity(0.75))
                        .frame(width: max(2, geo.size.width * rate))
                }
            }
            .frame(height: 10)
            Text("\(Int((rate * 100).rounded())) %").font(.callout.weight(.bold)).monospacedDigit()
                .foregroundStyle(Theme.gold).frame(width: 50, alignment: .trailing)
            Text("\(item.times) von \(looted)" + (item.total > item.times ? " · \(item.total) Stück" : ""))
                .font(.caption).foregroundStyle(Theme.parchmentDim).frame(width: 130, alignment: .trailing)
        }
    }
}
