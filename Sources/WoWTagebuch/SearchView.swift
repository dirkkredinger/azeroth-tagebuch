import SwiftUI

/// Suche über alle Charaktere: Quests, Beute, Gegner und Notizen.
struct GlobalSearchView: View {
    let query: String
    @Binding var selection: String?
    @Environment(DataStore.self) private var store

    private struct QuestHit: Identifiable {
        var char: WowCharacter
        var event: WowEvent
        var open: Bool
        var id: String { char.key + event.id }
    }

    private struct ItemHit: Identifiable {
        var source: LootStats.Source
        var item: LootStats.ItemDrop
        var id: String { source.key + "|" + item.key }
    }

    private struct NoteHit: Identifiable {
        var char: WowCharacter
        var event: WowEvent
        var id: String { char.key + event.id }
    }

    private struct StoredHit: Identifiable {
        var place: String
        var who: String
        var color: Color
        var item: Storage.Item
        var id: String { place + who + (item.name ?? "") + "\(item.itemLevel ?? 0)" }
    }

    private func storedHits() -> [StoredHit] {
        var hits: [StoredHit] = []
        func scan(_ s: Storage?, place: String, who: String, color: Color) {
            for tab in s?.tabs ?? [] {
                for item in tab.items where matches(item.name) {
                    hits.append(StoredHit(place: s?.tabs.count ?? 0 > 1 ? "\(place) · \(tab.name)" : place, who: who, color: color, item: item))
                }
            }
        }
        for ch in store.characters {
            scan(ch.bags, place: "Taschen", who: ch.name, color: ch.classColor)
            scan(ch.bank, place: "Bank", who: ch.name, color: ch.classColor)
        }
        for (acc, w) in store.warbands { scan(w, place: "Kriegsmeutenbank", who: acc, color: Theme.gold) }
        for (g, s) in store.guilds { scan(s, place: "Gildenbank", who: g.split(separator: "-").first.map(String.init) ?? g, color: Theme.healing) }
        return hits
    }

    private func storedSection(_ hits: [StoredHit]) -> some View {
        GroupBox("Wo liegt …?") {
            VStack(spacing: 6) {
                ForEach(hits.prefix(80)) { hit in
                    HStack(spacing: 10) {
                        ItemIcon(icon: hit.item.icon, quality: hit.item.quality, size: 28)
                        Text(hit.item.name ?? "?").foregroundStyle(WowStyle.qualityColor(hit.item.quality)).fontWeight(.semibold)
                        if let il = hit.item.itemLevel { Text("GS \(Int(il))").font(.caption).foregroundStyle(Theme.gold) }
                        Spacer()
                        Text("\(hit.item.count)×").monospacedDigit().foregroundStyle(Theme.parchment)
                        Text(hit.who).font(.caption.bold()).foregroundStyle(hit.color).frame(width: 110, alignment: .trailing)
                        Text(hit.place).font(.caption).foregroundStyle(Theme.parchmentDim).frame(width: 190, alignment: .leading)
                    }
                }
            }
        }
    }

    private var q: String { query.trimmingCharacters(in: .whitespaces) }

    private func questHits() -> [QuestHit] {
        var hits: [QuestHit] = []
        for ch in store.characters {
            for ev in ch.turnIns { hits.append(QuestHit(char: ch, event: ev, open: false)) }
            for ev in ch.openQuests { hits.append(QuestHit(char: ch, event: ev, open: true)) }
        }
        return hits.filter { matches($0.event.n) || matches($0.event.z) }.sorted { $0.event.t > $1.event.t }
    }

    private func itemHits(_ loot: LootStats) -> [ItemHit] {
        var hits: [ItemHit] = []
        for src in loot.sources {
            for item in src.items.values where matches(item.name) { hits.append(ItemHit(source: src, item: item)) }
        }
        return hits.sorted { a, b in
            if (a.item.quality ?? 0) != (b.item.quality ?? 0) { return (a.item.quality ?? 0) > (b.item.quality ?? 0) }
            return a.item.times > b.item.times
        }
    }

    private func noteHits() -> [NoteHit] {
        store.characters.flatMap { ch in ch.notes.filter { matches($0.txt) }.map { NoteHit(char: ch, event: $0) } }
    }

    private func matches(_ text: String?) -> Bool {
        guard let text else { return false }
        return text.localizedCaseInsensitiveContains(q)
    }

    var body: some View {
        let loot = LootStats(characters: store.characters, fights: store.fightsByChar)
        let quests = questHits()
        let items = itemHits(loot)
        let mobs = loot.sources.filter { matches($0.name) }.sorted { $0.effectiveKills > $1.effectiveKills }
        let notes = noteHits()
        let stored = storedHits()
        let nothing = quests.isEmpty && items.isEmpty && mobs.isEmpty && notes.isEmpty && stored.isEmpty

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                OrnamentHeader(text: "Suche: „\(q)“")
                Text("\(quests.count) Quests · \(items.count) Gegenstände · \(mobs.count) Gegner · \(notes.count) Notizen · \(stored.count) im Lager")
                    .foregroundStyle(Theme.parchmentDim)
                if nothing { emptyHint }
                if !stored.isEmpty { storedSection(stored) }
                if !quests.isEmpty { questSection(quests) }
                if !items.isEmpty { itemSection(items) }
                if !mobs.isEmpty { mobSection(mobs) }
                if !notes.isEmpty { noteSection(notes) }
            }
            .padding(24)
        }
    }

    private var emptyHint: some View {
        Text("Nichts gefunden. Gesucht wird in Questnamen, Zonen, Beute, Gegnern, Notizen sowie Taschen und Banken aller Charaktere.")
            .foregroundStyle(Theme.parchmentDim)
            .frame(maxWidth: .infinity, alignment: .leading)
            .wowPanel(padding: 18)
    }

    private func questSection(_ quests: [QuestHit]) -> some View {
        GroupBox("Quests") {
            VStack(spacing: 6) {
                ForEach(quests.prefix(60)) { hit in
                    Button { selection = hit.char.key } label: { questRow(hit) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func questRow(_ hit: QuestHit) -> some View {
        let sub = [hit.event.z, hit.open ? "offen" : WowStyle.questKind(hit.event.c)].compactMap { $0 }.joined(separator: " · ")
        return HStack(spacing: 10) {
            Image(systemName: hit.open ? "exclamationmark.circle" : "checkmark.seal.fill")
                .foregroundStyle(hit.open ? Color.orange : Color.yellow).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(hit.event.n ?? "?").foregroundStyle(Theme.parchment).fontWeight(.semibold)
                Text(sub).font(.caption).foregroundStyle(Theme.parchmentDim)
            }
            Spacer()
            Text(hit.char.name).font(.caption.bold()).foregroundStyle(hit.char.classColor)
            Text(hit.event.date.formatted(.dateTime.day().month().year()))
                .font(.caption).foregroundStyle(Theme.parchmentDim).frame(width: 90, alignment: .trailing)
        }
        .contentShape(Rectangle())
    }

    private func itemSection(_ items: [ItemHit]) -> some View {
        GroupBox("Beute") {
            VStack(spacing: 6) {
                ForEach(items.prefix(60)) { hit in itemRow(hit) }
            }
        }
    }

    private func itemRow(_ hit: ItemHit) -> some View {
        let zones = hit.source.zones.sorted().joined(separator: ", ")
        let rate = Int((hit.source.rate(hit.item) * 100).rounded())
        return HStack(spacing: 10) {
            ItemIcon(icon: hit.item.icon, quality: hit.item.quality, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(hit.item.name).foregroundStyle(WowStyle.qualityColor(hit.item.quality)).fontWeight(.semibold)
                Text("von \(hit.source.name)" + (zones.isEmpty ? "" : " · \(zones)"))
                    .font(.caption).foregroundStyle(Theme.parchmentDim)
            }
            Spacer()
            Text("\(rate) %").fontWeight(.bold).foregroundStyle(Theme.gold)
            Text("\(hit.item.times) von \(hit.source.looted)").font(.caption).foregroundStyle(Theme.parchmentDim)
                .frame(width: 80, alignment: .trailing)
        }
    }

    private func mobSection(_ mobs: [LootStats.Source]) -> some View {
        GroupBox("Gegner & Vorkommen") {
            VStack(spacing: 8) {
                ForEach(mobs.prefix(30)) { src in SourceRow(source: src, expanded: true) {} }
            }
        }
    }

    private func noteSection(_ notes: [NoteHit]) -> some View {
        GroupBox("Notizen") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(notes) { hit in
                    HStack(spacing: 8) {
                        Text(hit.char.name).font(.caption.bold()).foregroundStyle(hit.char.classColor).frame(width: 90, alignment: .leading)
                        EventRow(event: hit.event, showDate: true)
                    }
                }
            }
        }
    }
}
