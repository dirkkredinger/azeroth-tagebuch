import SwiftUI
import Charts

/// Kampf- oder Heilstatistik eines Charakters aus dem Kampflog.
struct CombatStatsView: View {
    enum Mode { case damage, healing }

    let character: WowCharacter
    let mode: Mode
    @Environment(DataStore.self) private var store
    @State private var selectedFight: Fight.ID?

    private var accent: Color { mode == .damage ? Theme.damage : Theme.healing }
    private var unit: String { mode == .damage ? "DPS" : "HPS" }

    private func value(_ f: Fight) -> Double { mode == .damage ? f.dps : f.hps }
    private func amount(_ f: Fight) -> Int { mode == .damage ? f.damage : f.healing }

    /// Nur Kämpfe, in denen in diesem Bereich etwas passiert ist
    private var fights: [Fight] {
        store.fights(for: character.key).filter { amount($0) > 0 }
    }

    var body: some View {
        let all = fights
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let live = store.liveFight, live.char == character.key {
                    LiveFightBanner(fight: live, mode: mode)
                }
                if all.isEmpty {
                    CombatEmptyState(mode: mode, logFound: store.combatLogFound || store.isDemo)
                } else {
                    tiles(all)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        ChartBox("\(unit) je Kampf") { perFightChart(all) }
                        ChartBox("\(unit) nach Stufe") { byLevelChart(all) }
                        ChartBox("\(unit) nach Gegenstandsstufe") { byItemLevelChart(all) }
                        ChartBox(mode == .damage ? "Stärkste Fähigkeiten" : "Stärkste Heilzauber") { spellsChart(all) }
                    }
                    fightList(all)
                }
            }
            .padding(20)
        }
    }

    // MARK: Kacheln

    @ViewBuilder private func tiles(_ all: [Fight]) -> some View {
        let total = all.reduce(0) { $0 + amount($1) }
        let seconds = all.reduce(0.0) { $0 + $1.duration }
        let best = all.max { value($0) < value($1) }
        let recent = Array(all.suffix(10))
        let recentAvg = recent.reduce(0.0) { $0 + value($1) } / Double(max(recent.count, 1))
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
            StatTile(title: "Kämpfe", value: "\(all.count)", icon: "flame", tint: accent)
            StatTile(title: mode == .damage ? "Schaden gesamt" : "Heilung gesamt", value: Fmt.big(total),
                     icon: mode == .damage ? "burst" : "cross.case", tint: accent)
            StatTile(title: "Ø \(unit) gesamt", value: Fmt.big(Int(Double(total) / max(seconds, 1))), icon: "gauge.with.dots.needle.50percent", tint: accent)
            StatTile(title: "Ø \(unit) letzte 10", value: Fmt.big(Int(recentAvg)), icon: "chart.line.uptrend.xyaxis", tint: accent)
            StatTile(title: "Bester Kampf", value: best.map { Fmt.big(Int(value($0))) } ?? "–", icon: "crown", tint: Theme.gold)
            if mode == .damage {
                StatTile(title: "Erlittener Schaden", value: Fmt.big(all.reduce(0) { $0 + $1.taken }), icon: "shield.lefthalf.filled.slash", tint: Theme.taken)
                StatTile(title: "Bosskämpfe", value: "\(all.filter { $0.encounter != nil }.count)", icon: "crown.fill", tint: Theme.gold)
            } else {
                let over = all.reduce(0) { $0 + $1.overheal }
                let raw = total + over
                StatTile(title: "Überheilung", value: raw > 0 ? "\(Int(Double(over) / Double(raw) * 100)) %" : "–", icon: "drop.triangle", tint: .orange)
                StatTile(title: "Davon Schilde", value: Fmt.big(all.reduce(0) { $0 + $1.absorb }), icon: "shield", tint: Theme.shield)
            }
        }
    }

    // MARK: Diagramme

    private func perFightChart(_ all: [Fight]) -> some View {
        Chart {
            ForEach(Array(all.enumerated()), id: \.element.id) { i, f in
                PointMark(x: .value("Kampf", i + 1), y: .value(unit, value(f)))
                    .foregroundStyle(f.encounter != nil ? Theme.gold : accent)
                    .symbolSize(f.encounter != nil ? 70 : 30)
            }
            ForEach(movingAverage(all)) { p in
                LineMark(x: .value("Kampf", p.index), y: .value("Schnitt", p.value))
                    .foregroundStyle(Theme.parchment.opacity(0.8))
            }
        }
        .chartXAxisLabel("Kampf Nr. (Linie: Schnitt der letzten 5, gold: Bosse)")
        .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.big(Int(d))) } } } }
    }

    private func byLevelChart(_ all: [Fight]) -> some View {
        let groups = Dictionary(grouping: all) { character.level(at: Int($0.start)) ?? 0 }
            .filter { $0.key > 0 }
            .map { (level: $0.key, avg: $0.value.reduce(0.0) { $0 + value($1) } / Double($0.value.count), n: $0.value.count) }
            .sorted { $0.level < $1.level }
        return Group {
            if groups.isEmpty { NoData(text: "Keine Stufendaten zu den Kämpfen") } else {
                Chart(groups, id: \.level) { g in
                    BarMark(x: .value("Stufe", "\(g.level)"), y: .value(unit, g.avg))
                        .foregroundStyle(accent.gradient)
                        .annotation(position: .top) {
                            Text(Fmt.big(Int(g.avg))).font(.caption2).foregroundStyle(Theme.parchmentDim)
                        }
                }
                .chartXAxisLabel("Stufe")
                .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.big(Int(d))) } } } }
            }
        }
    }

    private func byItemLevelChart(_ all: [Fight]) -> some View {
        let points = all.compactMap { f -> (il: Double, v: Double, id: String)? in
            guard let il = f.itemLevel ?? character.itemLevel(at: Int(f.start)) else { return nil }
            return (il, value(f), f.id)
        }
        return Group {
            if points.isEmpty { NoData(text: "Keine Gegenstandsstufen zu den Kämpfen") } else {
                Chart {
                    ForEach(points, id: \.id) { p in
                        PointMark(x: .value("Gegenstandsstufe", p.il), y: .value(unit, p.v))
                            .foregroundStyle(accent.opacity(0.75))
                            .symbolSize(30)
                    }
                    ForEach(trend(points.map { ($0.il, $0.v) }), id: \.x) { p in
                        LineMark(x: .value("Gegenstandsstufe", p.x), y: .value("Trend", p.y))
                            .foregroundStyle(Theme.gold)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    }
                }
                .chartXScale(domain: .automatic(includesZero: false))
                .chartXAxisLabel("Gegenstandsstufe")
                .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.big(Int(d))) } } } }
            }
        }
    }

    private func spellsChart(_ all: [Fight]) -> some View {
        var totals: [String: Int] = [:]
        for f in all { for s in f.spells { totals[s.name, default: 0] += mode == .damage ? s.damage : s.healing } }
        let top = totals.filter { $0.value > 0 }.sorted { $0.value > $1.value }.prefix(8)
        let sum = max(totals.values.reduce(0, +), 1)
        return Group {
            if top.isEmpty { NoData() } else {
                Chart(Array(top), id: \.key) { s in
                    BarMark(x: .value("Menge", s.value), y: .value("Fähigkeit", s.key))
                        .foregroundStyle(accent.gradient)
                        .annotation(position: .trailing) {
                            Text("\(Int(Double(s.value) / Double(sum) * 100)) %").font(.caption2).foregroundStyle(Theme.parchmentDim)
                        }
                }
                .chartXAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Int.self) { Text(Fmt.big(d)) } } } }
            }
        }
    }

    // MARK: Liste

    private func fightList(_ all: [Fight]) -> some View {
        GroupBox("Letzte Kämpfe") {
            VStack(spacing: 0) {
                ForEach(Array(all.suffix(25).reversed())) { f in
                    FightRow(fight: f, mode: mode, level: character.level(at: Int(f.start)),
                             expanded: selectedFight == f.id) {
                        selectedFight = selectedFight == f.id ? nil : f.id
                    }
                    Divider().overlay(Theme.goldDim.opacity(0.3))
                }
            }
        }
    }

    // MARK: Rechenhilfen

    struct AvgPoint: Identifiable { var index: Int; var value: Double; var id: Int { index } }

    private func movingAverage(_ all: [Fight], window: Int = 5) -> [AvgPoint] {
        guard all.count >= 3 else { return [] }
        return all.indices.map { i in
            let slice = all[max(0, i - window + 1)...i]
            return AvgPoint(index: i + 1, value: slice.reduce(0.0) { $0 + value($1) } / Double(slice.count))
        }
    }

    /// Lineare Trendlinie (kleinste Quadrate)
    private func trend(_ pts: [(Double, Double)]) -> [(x: Double, y: Double)] {
        guard pts.count >= 3, let minX = pts.map(\.0).min(), let maxX = pts.map(\.0).max(), maxX > minX else { return [] }
        let n = Double(pts.count)
        let sx = pts.reduce(0) { $0 + $1.0 }, sy = pts.reduce(0) { $0 + $1.1 }
        let sxx = pts.reduce(0) { $0 + $1.0 * $1.0 }, sxy = pts.reduce(0) { $0 + $1.0 * $1.1 }
        let d = n * sxx - sx * sx
        guard d != 0 else { return [] }
        let b = (n * sxy - sx * sy) / d, a = (sy - b * sx) / n
        return [(minX, a + b * minX), (maxX, a + b * maxX)]
    }
}

struct FightRow: View {
    let fight: Fight
    let mode: CombatStatsView.Mode
    let level: Int?
    let expanded: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: toggle) {
                HStack(spacing: 10) {
                    Image(systemName: fight.encounter != nil ? "crown.fill" : (fight.deaths > 0 ? "heart.slash.fill" : "flame"))
                        .foregroundStyle(fight.encounter != nil ? Theme.gold : (fight.deaths > 0 ? .red : Theme.parchmentDim))
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(fight.title).font(.body.weight(.semibold)).foregroundStyle(Theme.parchment)
                            if fight.success == true { Text("besiegt").font(.caption2.bold()).foregroundStyle(Theme.healing) }
                            if fight.success == false { Text("gescheitert").font(.caption2.bold()).foregroundStyle(.red) }
                        }
                        Text([fight.zone, level.map { "Stufe \($0)" },
                              fight.itemLevel.map { "GS \(Int($0))" },
                              "\(Int(fight.duration)) s"].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(Theme.parchmentDim)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Fmt.big(Int(mode == .damage ? fight.dps : fight.hps))) \(mode == .damage ? "DPS" : "HPS")")
                            .font(.system(.body, design: .serif).weight(.bold)).monospacedDigit()
                            .foregroundStyle(mode == .damage ? Theme.damage : Theme.healing)
                        Text(fight.date.formatted(.dateTime.day().month().hour().minute()))
                            .font(.caption).foregroundStyle(Theme.parchmentDim.opacity(0.7))
                    }
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption).foregroundStyle(Theme.goldDim)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if expanded {
                FightDetail(fight: fight, mode: mode)
                    .padding(.leading, 28).padding(.bottom, 8)
            }
        }
    }
}

struct FightDetail: View {
    let fight: Fight
    let mode: CombatStatsView.Mode

    var body: some View {
        let spells = fight.spells.filter { mode == .damage ? $0.damage > 0 : $0.healing > 0 }
        let total = max(spells.reduce(0) { $0 + (mode == .damage ? $1.damage : $1.healing) }, 1)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 16) {
                Label("Schaden \(Fmt.big(fight.damage))", systemImage: "burst").foregroundStyle(Theme.damage)
                Label("Heilung \(Fmt.big(fight.healing))", systemImage: "cross.case").foregroundStyle(Theme.healing)
                Label("Erlitten \(Fmt.big(fight.taken))", systemImage: "shield.lefthalf.filled.slash").foregroundStyle(Theme.taken)
                if fight.deaths > 0 { Label("\(fight.deaths)× gestorben", systemImage: "heart.slash").foregroundStyle(.red) }
            }
            .font(.caption)
            ForEach(spells) { s in
                let v = mode == .damage ? s.damage : s.healing
                HStack(spacing: 8) {
                    Text(s.name).font(.caption).frame(width: 150, alignment: .leading).lineLimit(1)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill((mode == .damage ? Theme.damage : Theme.healing).gradient)
                            .frame(width: geo.size.width * CGFloat(v) / CGFloat(total))
                    }
                    .frame(height: 8)
                    Text("\(Fmt.big(v)) · \(s.hits)× · \(s.hits > 0 ? s.crits * 100 / s.hits : 0) % krit.")
                        .font(.caption2).monospacedDigit().foregroundStyle(Theme.parchmentDim)
                        .frame(width: 170, alignment: .trailing)
                }
            }
        }
    }
}

struct LiveFightBanner: View {
    let fight: Fight
    let mode: CombatStatsView.Mode
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 14) {
            Circle().fill(Color.red).frame(width: 10, height: 10)
                .opacity(pulse ? 1 : 0.3)
                .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever()) { pulse = true } }
            Text("LIVE").font(.system(size: 13, weight: .heavy, design: .serif)).foregroundStyle(.red)
            Text(fight.title).font(Theme.heading()).foregroundStyle(Theme.parchment)
            Spacer()
            Text("\(Fmt.big(Int(fight.dps))) DPS").foregroundStyle(Theme.damage)
            Text("\(Fmt.big(Int(fight.hps))) HPS").foregroundStyle(Theme.healing)
            Text("\(Int(fight.duration)) s").foregroundStyle(Theme.parchmentDim)
        }
        .font(.system(.body, design: .serif).weight(.semibold))
        .monospacedDigit()
        .wowPanel(highlight: true)
    }
}

struct CombatEmptyState: View {
    let mode: CombatStatsView.Mode
    let logFound: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(mode == .damage ? "Noch keine Kämpfe" : "Noch keine Heilung", systemImage: "scroll")
                .font(Theme.heading(18)).foregroundStyle(Theme.gold)
            Text("""
            Die Statistik entsteht aus dem offiziellen Kampflog von WoW. Das Addon schaltet es beim Einloggen automatisch ein \
            (abschaltbar mit /tb kampflog aus). Alternativ im Spiel /combatlog eingeben.

            Die App liest die Datei „Logs/WoWCombatLog….txt“ live mit – du siehst laufende Kämpfe hier, während du spielst.
            """)
            .foregroundStyle(Theme.parchmentDim)
            if mode == .healing {
                Text("Heilung wird erfasst, sobald dein Charakter heilt oder Schilde wirkt.")
                    .font(.caption).foregroundStyle(Theme.parchmentDim.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wowPanel(padding: 18)
    }
}

extension Fmt {
    /// 1.234 · 12,3 Tsd. · 4,5 Mio.
    static func big(_ v: Int) -> String {
        let d = Double(v)
        if abs(d) >= 1_000_000 { return (d / 1_000_000).formatted(.number.precision(.fractionLength(1))) + " Mio." }
        if abs(d) >= 10_000 { return (d / 1000).formatted(.number.precision(.fractionLength(1))) + " Tsd." }
        return v.formatted()
    }
}
