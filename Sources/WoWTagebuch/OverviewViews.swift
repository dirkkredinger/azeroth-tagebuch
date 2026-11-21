import SwiftUI
import Charts

// MARK: - Kacheln

struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon).foregroundStyle(tint)
            }
            .font(.caption)
            .foregroundStyle(Theme.parchmentDim)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(Theme.parchment)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wowPanel(padding: 14)
    }
}

struct EventRow: View {
    let event: WowEvent
    var questNames: [Int: String] = [:]
    var showDate = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: event.icon)
                .foregroundStyle(event.tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title(questNames: questNames))
                    .italic(event.e == "notiz")
                if let detail = event.detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(showDate
                 ? event.date.formatted(.dateTime.day().month().hour().minute())
                 : event.date.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Übersicht eines Charakters

struct OverviewView: View {
    let character: WowCharacter

    private var recent: [WowEvent] {
        Array(character.events.filter { $0.e != "pos" && $0.e != "zone" }.suffix(10).reversed())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                    StatTile(title: "Quests abgeschlossen", value: "\(character.turnIns.count)", icon: "checkmark.seal.fill", tint: .yellow)
                    StatTile(title: "Offene Quests", value: "\(character.openQuests.count)", icon: "exclamationmark.circle", tint: .orange)
                    StatTile(title: "Spielzeit", value: Fmt.duration(character.playSeconds), icon: "clock", tint: .blue)
                    StatTile(title: "Stufenaufstiege", value: "\(character.levelUps)", icon: "arrow.up.circle.fill", tint: .green)
                    StatTile(title: "Gold aus Quests", value: Fmt.gold(character.questGold), icon: "dollarsign.circle", tint: .yellow)
                    StatTile(title: "EP aus Quests", value: character.questXP.formatted(), icon: "sparkles", tint: .purple)
                    StatTile(title: "Zonen besucht", value: "\(character.zonesVisited.count)", icon: "map", tint: .teal)
                    StatTile(title: "Instanzen", value: "\(character.instancesVisited.count)", icon: "shield.lefthalf.filled", tint: .indigo)
                    StatTile(title: "Flüge", value: "\(character.flights)", icon: "airplane", tint: .indigo)
                    StatTile(title: "Erfolge", value: "\(character.achievements.count)", icon: "trophy.fill", tint: .orange)
                    StatTile(title: "Tode", value: "\(character.deaths)", icon: "heart.slash.fill", tint: .red)
                    StatTile(title: "Gold aktuell", value: Fmt.gold(character.money ?? 0), icon: "banknote", tint: .yellow)
                }

                if !character.notes.isEmpty {
                    GroupBox("Deine Notizen") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(character.notes.suffix(5).reversed())) { EventRow(event: $0, showDate: true) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                    }
                }

                GroupBox("Zuletzt passiert") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(recent) { EventRow(event: $0, questNames: character.questNames, showDate: true) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Quests

struct QuestRow: Identifiable {
    var id: String
    var name: String
    var zone: String
    var kind: String
    var level: Int
    var xp: Int
    var gold: Int
    var date: Date
}

struct QuestsView: View {
    let character: WowCharacter
    @State private var search = ""
    @State private var showOpen = false
    @State private var sortOrder = [KeyPathComparator(\QuestRow.date, order: .reverse)]

    private var rows: [QuestRow] {
        let source = showOpen ? character.openQuests : character.turnIns
        let mapped = source.map {
            QuestRow(id: $0.id, name: $0.n ?? "Quest \($0.q ?? 0)", zone: $0.z ?? "–",
                     kind: WowStyle.questKind($0.c), level: $0.lv ?? 0, xp: $0.xp ?? 0,
                     gold: $0.g ?? 0, date: $0.date)
        }
        let filtered = search.isEmpty ? mapped : mapped.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.zone.localizedCaseInsensitiveContains(search)
        }
        return filtered.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $showOpen) {
                    Text("Abgeschlossen (\(character.turnIns.count))").tag(false)
                    Text("Offen (\(character.openQuests.count))").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 340)
                Spacer()
                TextField("Quest oder Zone suchen", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
            }
            .padding(12)

            Table(rows, sortOrder: $sortOrder) {
                TableColumn("Quest", value: \.name)
                TableColumn("Zone", value: \.zone)
                TableColumn("Art", value: \.kind) { row in
                    Text(row.kind).foregroundStyle(row.kind == "Normal" ? .secondary : .primary)
                }
                .width(min: 70, ideal: 90)
                TableColumn("Stufe", value: \.level) { row in
                    Text(row.level > 0 ? "\(row.level)" : "–").monospacedDigit()
                }
                .width(50)
                TableColumn("EP", value: \.xp) { row in
                    Text(row.xp > 0 ? row.xp.formatted() : "–").monospacedDigit()
                }
                .width(70)
                TableColumn("Gold", value: \.gold) { row in
                    Text(row.gold > 0 ? Fmt.gold(row.gold) : "–").monospacedDigit()
                }
                .width(80)
                TableColumn(showOpen ? "Angenommen" : "Abgegeben", value: \.date) { row in
                    Text(row.date.formatted(.dateTime.day().month().hour().minute()))
                }
                .width(min: 110, ideal: 120)
            }
            .scrollContentBackground(.hidden)
        }
    }
}

// MARK: - Zeitleiste

struct DayGroup: Identifiable {
    var day: Date
    var events: [WowEvent]
    var id: Date { day }
}

struct JournalTimelineView: View {
    let character: WowCharacter

    private var days: [DayGroup] {
        let cal = Calendar.current
        // Zonenwechsel nur zeigen, wenn sich der Ort wirklich geändert hat
        var lastPlace: String?
        let relevant = character.events.filter { ev in
            guard ev.e != "pos" else { return false }
            guard ev.e == "zone" else { return true }
            let place = [ev.z, ev.sz, ev.inst].map { $0 ?? "" }.joined(separator: "|")
            defer { lastPlace = place }
            return place != lastPlace
        }
        let grouped = Dictionary(grouping: relevant) { ev in cal.startOfDay(for: ev.date) }
        return grouped.keys.sorted(by: >).map { day in
            DayGroup(day: day, events: (grouped[day] ?? []).sorted { a, b in a.t > b.t })
        }
    }

    var body: some View {
        let names = character.questNames
        List {
            ForEach(days) { entry in
                Section {
                    ForEach(entry.events) { EventRow(event: $0, questNames: names) }
                } header: {
                    Text(entry.day.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                        .font(Theme.heading())
                        .foregroundStyle(Theme.gold)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}
