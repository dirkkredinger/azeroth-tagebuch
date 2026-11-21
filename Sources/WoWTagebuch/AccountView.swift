import SwiftUI
import Charts

/// Account-Übersicht: alle Charaktere zusammen
struct AllCharactersView: View {
    @Environment(DataStore.self) private var store
    @Binding var selection: String?

    var body: some View {
        let chars = store.characters
        let fights = store.fightsByChar
        let loot = LootStats(characters: chars, fights: fights)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                OrnamentHeader(text: "Alle Charaktere")
                totals(chars, loot: loot)

                Text("Deine Helden").font(Theme.heading(17)).foregroundStyle(Theme.gold)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12)], spacing: 12) {
                    ForEach(chars) { ch in
                        Button { selection = ch.key } label: { CharacterCard(character: ch, fights: fights[ch.key] ?? []) }
                            .buttonStyle(.plain)
                    }
                }

                records(chars, fights: fights, loot: loot)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    ChartBox("Spielzeit der letzten 14 Tage") { activityChart(chars) }
                    ChartBox("Gold je Charakter") { goldChart(chars) }
                }

                GroupBox("Zuletzt bei allen Charakteren") {
                    let recent = chars.flatMap { ch in
                        ch.events.filter { !["pos", "zone", "ausr"].contains($0.e) }.suffix(20).map { (ch, $0) }
                    }
                    .sorted { $0.1.t > $1.1.t }
                    .prefix(15)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(recent), id: \.1.id) { ch, ev in
                            HStack(spacing: 8) {
                                Text(ch.name).font(.caption.bold()).foregroundStyle(ch.classColor).frame(width: 90, alignment: .leading)
                                EventRow(event: ev, questNames: ch.questNames, showDate: true)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    // MARK: Gesamtwerte

    private func totals(_ chars: [WowCharacter], loot: LootStats) -> some View {
        let play = chars.reduce(0) { $0 + $1.playSeconds }
        let gold = chars.reduce(0) { $0 + ($1.money ?? 0) }
        let kills = loot.sources.filter { !$0.isObject }.reduce(0) { $0 + $1.effectiveKills }
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
            StatTile(title: "Charaktere", value: "\(chars.count)", icon: "person.3.fill", tint: Theme.gold)
            StatTile(title: "Spielzeit gesamt", value: Fmt.duration(play), icon: "clock", tint: .blue)
            StatTile(title: "Gold gesamt", value: Fmt.gold(gold), icon: "dollarsign.circle", tint: .yellow)
            StatTile(title: "Quests gesamt", value: "\(chars.reduce(0) { $0 + $1.turnIns.count })", icon: "checkmark.seal.fill", tint: .yellow)
            StatTile(title: "Gegner besiegt", value: kills.formatted(), icon: "flame", tint: Theme.damage)
            StatTile(title: "Stufenaufstiege", value: "\(chars.reduce(0) { $0 + $1.levelUps })", icon: "arrow.up.circle.fill", tint: .green)
            StatTile(title: "Erfolge", value: "\(chars.reduce(0) { $0 + $1.achievements.count })", icon: "trophy.fill", tint: .orange)
            StatTile(title: "Tode", value: "\(chars.reduce(0) { $0 + $1.deaths })", icon: "heart.slash.fill", tint: .red)
        }
    }

    // MARK: Rekorde

    @ViewBuilder private func records(_ chars: [WowCharacter], fights: [String: [Fight]], loot: LootStats) -> some View {
        let byKey = Dictionary(uniqueKeysWithValues: chars.map { ($0.key, $0) })
        let allFights = fights.flatMap { k, v in v.map { (k, $0) } }
        let bestDPS = allFights.filter { $0.1.damage > 0 }.max { $0.1.dps < $1.1.dps }
        let bestHPS = allFights.filter { $0.1.healing > 0 }.max { $0.1.hps < $1.1.hps }
        let topMob = loot.sources.filter { !$0.isObject }.max { $0.effectiveKills < $1.effectiveKills }
        let rarest = loot.sources.flatMap { s in s.items.values.filter { ($0.quality ?? 0) >= 2 }.map { (s, $0) } }
            .max { (($0.1.quality ?? 0), -$0.0.rate($0.1)) < (($1.1.quality ?? 0), -$1.0.rate($1.1)) }
        let longest = chars.flatMap { ch in ch.events.filter { $0.e == "logout" }.map { (ch, $0) } }.max { ($0.1.dauer ?? 0) < ($1.1.dauer ?? 0) }
        let richest = chars.max { ($0.money ?? 0) < ($1.money ?? 0) }

        GroupBox("Ruhmeshalle") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10)], spacing: 10) {
                if let (k, f) = bestDPS {
                    RecordCell(icon: "flame.fill", tint: Theme.damage, title: "Höchste DPS",
                               value: "\(Fmt.big(Int(f.dps))) DPS",
                               detail: "\(byKey[k]?.name ?? k) gegen \(f.title)")
                }
                if let (k, f) = bestHPS {
                    RecordCell(icon: "cross.case.fill", tint: Theme.healing, title: "Höchste HPS",
                               value: "\(Fmt.big(Int(f.hps))) HPS", detail: "\(byKey[k]?.name ?? k) · \(f.title)")
                }
                if let topMob {
                    RecordCell(icon: "pawprint.fill", tint: .orange, title: "Liebster Gegner",
                               value: "\(topMob.effectiveKills)× \(topMob.name)", detail: topMob.zones.sorted().joined(separator: ", "))
                }
                if let (src, item) = rarest {
                    RecordCell(icon: "sparkles", tint: WowStyle.qualityColor(item.quality), title: "Bester Fund",
                               value: item.name, detail: "von \(src.name) · \(Int(src.rate(item) * 100)) % Droprate")
                }
                if let (ch, ev) = longest, let d = ev.dauer, d > 0 {
                    RecordCell(icon: "hourglass", tint: .blue, title: "Längste Sitzung",
                               value: Fmt.duration(d), detail: "\(ch.name) · \(ev.date.formatted(.dateTime.day().month().year()))")
                }
                if let richest, let m = richest.money, m > 0 {
                    RecordCell(icon: "dollarsign.circle.fill", tint: .yellow, title: "Reichster Charakter",
                               value: Fmt.gold(m), detail: richest.name)
                }
            }
        }
    }

    // MARK: Diagramme

    private struct PlayDay: Identifiable { var day: Date; var name: String; var minutes: Double; var id: String { "\(day)\(name)" } }

    @ViewBuilder private func activityChart(_ chars: [WowCharacter]) -> some View {
        let cal = Calendar.current
        let newest = chars.compactMap(\.lastSeen).max() ?? Date()
        let from = cal.date(byAdding: .day, value: -13, to: cal.startOfDay(for: newest))!
        let days = chars.flatMap { ch in
            ch.events.filter { $0.e == "logout" && $0.date >= from }.map {
                PlayDay(day: cal.startOfDay(for: $0.date), name: ch.name, minutes: Double($0.dauer ?? 0) / 60)
            }
        }
        if days.isEmpty { NoData() } else {
            Chart(days) { d in
                BarMark(x: .value("Tag", d.day, unit: .day), y: .value("Minuten", d.minutes))
                    .foregroundStyle(by: .value("Charakter", d.name))
            }
            .chartForegroundStyleScale(domain: chars.map(\.name), range: chars.map(\.classColor))
            .chartYAxisLabel("Minuten")
            .chartXAxis { AxisMarks(values: .stride(by: .day, count: 2)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
        }
    }

    @ViewBuilder private func goldChart(_ chars: [WowCharacter]) -> some View {
        let rich = chars.filter { ($0.money ?? 0) > 0 }
        if rich.isEmpty { NoData() } else {
            Chart(rich) { ch in
                BarMark(x: .value("Gold", (ch.money ?? 0) / 10000), y: .value("Charakter", ch.name))
                    .foregroundStyle(ch.classColor.gradient)
                    .annotation(position: .trailing) { Text(Fmt.gold(ch.money ?? 0)).font(.caption2).foregroundStyle(Theme.parchmentDim) }
            }
            .chartXAxisLabel("Gold")
        }
    }
}

struct CharacterCard: View {
    let character: WowCharacter
    let fights: [Fight]
    @State private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(character.classColor.gradient)
                    RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.borderGradient, lineWidth: 1.5)
                    Text(String(character.name.prefix(1))).font(Theme.title(22)).foregroundStyle(.black.opacity(0.7))
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(character.name).font(Theme.heading(17)).foregroundStyle(character.classColor)
                    Text([character.spec, character.className].compactMap { $0 }.joined(separator: " "))
                        .font(.caption).foregroundStyle(Theme.parchment)
                    Text(character.realm).font(.caption2).foregroundStyle(Theme.parchmentDim)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(character.level ?? 0)").font(Theme.title(24)).foregroundStyle(Theme.gold)
                    Text("Stufe").font(.caption2).foregroundStyle(Theme.parchmentDim)
                }
            }
            Divider().overlay(Theme.goldDim.opacity(0.4))
            HStack {
                mini("clock", Fmt.duration(character.playSeconds))
                Spacer()
                mini("checkmark.seal", "\(character.turnIns.count) Quests")
                Spacer()
                if let il = character.itemLevel { mini("shield.checkered", "GS \(Int(il))") }
                else { mini("flame", "\(fights.count) Kämpfe") }
            }
            if let seen = character.lastSeen {
                Text("zuletzt gespielt \(seen.formatted(.relative(presentation: .named)))")
                    .font(.caption2).foregroundStyle(Theme.parchmentDim.opacity(0.8))
            }
        }
        .wowPanel(padding: 14, highlight: hover)
        .scaleEffect(hover ? 1.015 : 1)
        .animation(.easeOut(duration: 0.12), value: hover)
        .onHover { hover = $0 }
        .contentShape(Rectangle())
    }

    private func mini(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon).font(.caption).foregroundStyle(Theme.parchment)
    }
}

struct RecordCell: View {
    let icon: String
    let tint: Color
    let title: String
    let value: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(tint).frame(width: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption).foregroundStyle(Theme.parchmentDim)
                Text(value).font(.system(.body, design: .serif).weight(.bold)).foregroundStyle(Theme.parchment).lineLimit(1)
                Text(detail).font(.caption2).foregroundStyle(Theme.parchmentDim).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Theme.panelHighlight.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
    }
}
