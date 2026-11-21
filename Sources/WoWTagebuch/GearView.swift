import SwiftUI
import Charts

enum GearSlots {
    static let names: [Int: String] = [
        1: "Kopf", 2: "Hals", 3: "Schultern", 4: "Hemd", 5: "Brust", 6: "Taille", 7: "Beine", 8: "Füße",
        9: "Handgelenke", 10: "Hände", 11: "Finger 1", 12: "Finger 2", 13: "Schmuck 1", 14: "Schmuck 2",
        15: "Rücken", 16: "Waffenhand", 17: "Schildhand", 19: "Wappenrock",
    ]
    static let left = [1, 2, 3, 15, 5, 4, 19, 9]
    static let right = [10, 6, 7, 8, 11, 12, 13, 14]
    static let weapons = [16, 17]

    static let statNames: [String: String] = [
        "str": "Stärke", "bew": "Beweglichkeit", "int": "Intellekt", "aus": "Ausdauer",
        "krit": "Krit", "tempo": "Tempo", "meist": "Meisterschaft", "viel": "Vielseitigkeit",
    ]
    static let statOrder = ["str", "bew", "int", "aus", "krit", "tempo", "meist", "viel"]
}

struct GearView: View {
    let character: WowCharacter

    var body: some View {
        let gear = character.gear ?? [:]
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if gear.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Noch keine Ausrüstung erfasst", systemImage: "tshirt").font(Theme.heading(18)).foregroundStyle(Theme.gold)
                        Text("Das Addon (ab Version 1.2) speichert deine angelegten Gegenstände beim Einloggen, bei jedem Wechsel und beim Ausloggen. Einmal /reload genügt.")
                            .foregroundStyle(Theme.parchmentDim)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .wowPanel(padding: 18)
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 8) { ForEach(GearSlots.left, id: \.self) { GearSlotCard(slot: $0, item: gear[$0]) } }
                        GearSummary(character: character, gear: gear)
                            .frame(width: 300)
                        VStack(spacing: 8) { ForEach(GearSlots.right, id: \.self) { GearSlotCard(slot: $0, item: gear[$0], trailing: true) } }
                    }
                    HStack(spacing: 16) {
                        Spacer()
                        ForEach(GearSlots.weapons, id: \.self) { GearSlotCard(slot: $0, item: gear[$0]).frame(maxWidth: 340) }
                        Spacer()
                    }
                }

                GroupBox("Gegenstandsstufe im Verlauf") {
                    let points = character.itemLevelChanges.compactMap { ev in ev.il.map { (date: ev.date, il: $0) } }
                    if points.count < 2 { NoData(text: "Noch zu wenig Einträge").frame(height: 160) } else {
                        Chart(points, id: \.date) { p in
                            LineMark(x: .value("Zeit", p.date), y: .value("GS", p.il))
                                .interpolationMethod(.stepEnd)
                                .foregroundStyle(Theme.gold)
                            PointMark(x: .value("Zeit", p.date), y: .value("GS", p.il))
                                .foregroundStyle(Theme.gold).symbolSize(25)
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 180)
                    }
                }

                GroupBox("Ausrüstungswechsel") {
                    let changes = character.gearChanges.reversed()
                    if changes.isEmpty {
                        Text("Noch keine Wechsel erfasst.").foregroundStyle(Theme.parchmentDim)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(changes.prefix(40))) { ev in GearChangeRow(event: ev) }
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

struct GearSlotCard: View {
    let slot: Int
    let item: GearItem?
    var trailing = false

    var body: some View {
        let content = HStack(spacing: 10) {
            if trailing { Spacer(minLength: 0); texts(alignment: .trailing); icon } else { icon; texts(alignment: .leading); Spacer(minLength: 0) }
        }
        Group {
            if let id = item?.itemID, let url = URL(string: "https://www.wowhead.com/de/item=\(id)") {
                Link(destination: url) { content }.buttonStyle(.plain)
                    .help("Auf Wowhead ansehen")
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity)
        .wowPanel(padding: 8)
    }

    private var icon: some View { ItemIcon(icon: item?.icon, quality: item?.quality, size: 40) }

    private func texts(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(GearSlots.names[slot] ?? "Platz \(slot)").font(.caption2).foregroundStyle(Theme.parchmentDim)
            if let item {
                Text(item.name ?? "Unbekannt").font(.system(.callout, design: .serif).weight(.semibold))
                    .foregroundStyle(WowStyle.qualityColor(item.quality)).lineLimit(1)
                HStack(spacing: 6) {
                    if let il = item.itemLevel { Text("GS \(Int(il))").foregroundStyle(Theme.gold) }
                    Text(statLine(item)).foregroundStyle(Theme.parchmentDim).lineLimit(1)
                }
                .font(.caption2)
            } else {
                Text("leer").font(.callout).foregroundStyle(Theme.parchmentDim.opacity(0.6))
            }
        }
    }

    private func statLine(_ item: GearItem) -> String {
        GearSlots.statOrder.filter { ["krit", "tempo", "meist", "viel"].contains($0) }
            .compactMap { k in item.stats[k].map { "\($0) \(GearSlots.statNames[k] ?? k)" } }
            .joined(separator: " · ")
    }
}

struct GearSummary: View {
    let character: WowCharacter
    let gear: [Int: GearItem]

    var body: some View {
        var totals: [String: Int] = [:]
        for item in gear.values { for (k, v) in item.stats { totals[k, default: 0] += v } }
        let qualities = Dictionary(grouping: gear.values) { $0.quality ?? 1 }.mapValues(\.count)
        let levels = gear.filter { $0.key != 4 && $0.key != 19 }.compactMap { $0.value.itemLevel }
        let avg = levels.isEmpty ? nil : levels.reduce(0, +) / Double(levels.count)
        return VStack(spacing: 12) {
            ZStack {
                Circle().fill(RadialGradient(colors: [character.classColor.opacity(0.5), .clear], center: .center, startRadius: 0, endRadius: 90))
                VStack(spacing: 2) {
                    Text("Gegenstandsstufe").font(.caption).foregroundStyle(Theme.parchmentDim)
                    Text((character.itemLevel ?? avg).map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "–")
                        .font(Theme.title(40)).foregroundStyle(Theme.gold)
                    Text(character.spec ?? character.className ?? "").font(.caption).foregroundStyle(Theme.parchment)
                }
            }
            .frame(height: 170)

            VStack(alignment: .leading, spacing: 5) {
                Text("Werte der Ausrüstung").font(Theme.heading(13)).foregroundStyle(Theme.gold)
                ForEach(GearSlots.statOrder, id: \.self) { k in
                    if let v = totals[k] {
                        HStack {
                            Text(GearSlots.statNames[k] ?? k).foregroundStyle(Theme.parchmentDim)
                            Spacer()
                            Text(v.formatted()).foregroundStyle(Theme.parchment).monospacedDigit()
                        }
                        .font(.callout)
                    }
                }
                if totals.isEmpty { Text("Keine Werte erfasst").font(.caption).foregroundStyle(Theme.parchmentDim) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                ForEach(qualities.keys.sorted(by: >), id: \.self) { q in
                    Text("\(qualities[q]!)× \(WowStyle.qualityName(q))")
                        .font(.caption2.bold())
                        .foregroundStyle(WowStyle.qualityColor(q))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.black.opacity(0.35), in: Capsule())
                }
            }
        }
        .wowPanel(padding: 14)
    }
}

struct GearChangeRow: View {
    let event: WowEvent
    var body: some View {
        HStack(spacing: 10) {
            ItemIcon(icon: event.ic, quality: event.quality, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(GearSlots.names[event.slot ?? 0] ?? "").font(.caption).foregroundStyle(Theme.parchmentDim)
                    Text(event.n ?? "?").foregroundStyle(WowStyle.qualityColor(event.quality)).fontWeight(.semibold)
                    if let il = event.il { Text("GS \(Int(il))").font(.caption).foregroundStyle(Theme.gold) }
                }
                if let alt = event.alt {
                    let diff = (event.il ?? 0) - (event.altil ?? 0)
                    Text("ersetzt \(alt)" + (event.altil.map { " (GS \(Int($0)))" } ?? "")
                         + (event.altil != nil && event.il != nil ? (diff >= 0 ? "  ▲ +\(Int(diff))" : "  ▼ \(Int(diff))") : ""))
                        .font(.caption).foregroundStyle(diff >= 0 ? Theme.healing.opacity(0.9) : Color.red.opacity(0.9))
                }
            }
            Spacer()
            Text(event.date.formatted(.dateTime.day().month().hour().minute()))
                .font(.caption).foregroundStyle(Theme.parchmentDim.opacity(0.7))
        }
    }
}
