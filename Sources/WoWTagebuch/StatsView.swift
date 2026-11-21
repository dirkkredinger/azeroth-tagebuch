import SwiftUI
import Charts

struct CountItem: Identifiable {
    var label: String
    var count: Int
    var id: String { label }
}

struct DayCount: Identifiable {
    var day: Date
    var count: Int
    var id: Date { day }
}

struct LevelPoint: Identifiable {
    var date: Date
    var level: Int
    var id: Date { date }
}

struct StatsView: View {
    let character: WowCharacter

    private var questsPerDay: [DayCount] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: character.turnIns) { ev in cal.startOfDay(for: ev.date) }
        return grouped.map { DayCount(day: $0.key, count: $0.value.count) }.sorted { $0.day < $1.day }
    }

    private var questsPerZone: [CountItem] {
        let grouped = Dictionary(grouping: character.turnIns) { ev in ev.z ?? "Unbekannt" }
        return grouped.map { CountItem(label: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(10)
            .map { $0 }
    }

    private var questKinds: [CountItem] {
        let grouped = Dictionary(grouping: character.turnIns) { ev in WowStyle.questKind(ev.c) }
        return grouped.map { CountItem(label: $0.key, count: $0.value.count) }.sorted { $0.count > $1.count }
    }

    private var levelCurve: [LevelPoint] {
        var points: [LevelPoint] = []
        var seen = Set<Int>()
        for ev in character.events {
            guard let lv = ev.lv, ev.e == "level" || ev.e == "login" || ev.e == "quest_ab" else { continue }
            if ev.e == "level" || points.last?.level != lv {
                if seen.contains(ev.t) { continue }
                seen.insert(ev.t)
                points.append(LevelPoint(date: ev.date, level: lv))
            }
        }
        return points
    }

    var body: some View {
        let travel = character.travelShares
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                ChartBox("Quests pro Tag") {
                    if questsPerDay.isEmpty { NoData() } else {
                        Chart(questsPerDay) { d in
                            BarMark(x: .value("Tag", d.day, unit: .day), y: .value("Quests", d.count))
                                .foregroundStyle(Color.yellow.gradient)
                        }
                        .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
                    }
                }

                ChartBox("Reisezeit nach Fortbewegung") {
                    if travel.isEmpty { NoData() } else {
                        Chart(travel) { t in
                            BarMark(x: .value("Minuten", Double(t.seconds) / 60), y: .value("Art", WowStyle.modeLabel(t.mode)))
                                .foregroundStyle(WowStyle.modeColor(t.mode))
                                .annotation(position: .trailing) {
                                    Text(Fmt.duration(t.seconds)).font(.caption).foregroundStyle(.secondary)
                                }
                        }
                        .chartXAxisLabel("Minuten")
                    }
                }

                ChartBox("Top-Zonen nach Quests") {
                    if questsPerZone.isEmpty { NoData() } else {
                        Chart(questsPerZone) { z in
                            BarMark(x: .value("Quests", z.count), y: .value("Zone", z.label))
                                .foregroundStyle(Color.teal.gradient)
                        }
                    }
                }

                ChartBox("Arten der Quests") {
                    if questKinds.isEmpty { NoData() } else {
                        Chart(questKinds) { k in
                            SectorMark(angle: .value("Anzahl", k.count), innerRadius: .ratio(0.55), angularInset: 1.5)
                                .foregroundStyle(by: .value("Art", k.label))
                                .cornerRadius(3)
                        }
                        .chartLegend(position: .trailing, alignment: .center)
                    }
                }

                ChartBox("Stufenverlauf") {
                    if levelCurve.count < 2 { NoData(text: "Noch zu wenig Stufendaten") } else {
                        Chart(levelCurve) { p in
                            LineMark(x: .value("Zeit", p.date), y: .value("Stufe", p.level))
                                .interpolationMethod(.stepEnd)
                                .foregroundStyle(character.classColor)
                            PointMark(x: .value("Zeit", p.date), y: .value("Stufe", p.level))
                                .foregroundStyle(character.classColor)
                                .symbolSize(20)
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                    }
                }

                ChartBox("Spielzeit pro Tag") {
                    let perDay = playPerDay
                    if perDay.isEmpty { NoData() } else {
                        Chart(perDay) { d in
                            BarMark(x: .value("Tag", d.day, unit: .day), y: .value("Minuten", d.count / 60))
                                .foregroundStyle(Color.blue.gradient)
                        }
                        .chartYAxisLabel("Minuten")
                        .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
                    }
                }
            }
            .padding(20)
        }
    }

    /// Spielzeit (Sekunden) pro Tag aus den Logout-Einträgen.
    private var playPerDay: [DayCount] {
        let cal = Calendar.current
        var secs: [Date: Int] = [:]
        for ev in character.events where ev.e == "logout" {
            secs[cal.startOfDay(for: ev.date), default: 0] += ev.dauer ?? 0
        }
        return secs.map { DayCount(day: $0.key, count: $0.value) }.sorted { $0.day < $1.day }
    }
}

struct ChartBox<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        GroupBox {
            content
                .frame(height: 220)
                .padding(6)
        } label: {
            Text(title).font(.headline)
        }
    }
}

struct NoData: View {
    var text = "Noch keine Daten"
    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
