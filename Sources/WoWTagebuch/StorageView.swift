import SwiftUI

/// Reiter „Lager“: Taschen, Charakterbank, Kriegsmeutenbank und Gildenbank
struct StorageView: View {
    let character: WowCharacter
    @Environment(DataStore.self) private var store
    @State private var kind = Kind.bags
    @State private var search = ""
    @AppStorage("lagerAlsListe") private var asList = false

    enum Kind: String, CaseIterable, Identifiable {
        case bags = "Taschen", bank = "Bank", warband = "Kriegsmeute", guild = "Gildenbank"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .bags: return "bag"
            case .bank: return "building.columns"
            case .warband: return "person.3.sequence"
            case .guild: return "flag"
            }
        }
    }

    private var storage: Storage? {
        switch kind {
        case .bags: return character.bags
        case .bank: return character.bank
        case .warband: return store.warbands[character.account ?? ""] ?? store.warbands.values.max { $0.t < $1.t }
        case .guild: return character.guild.flatMap { store.guilds[$0] }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Picker("", selection: $kind) {
                        ForEach(Kind.allCases) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 460)
                    Picker("", selection: $asList) {
                        Image(systemName: "square.grid.3x3").tag(false)
                        Image(systemName: "list.bullet").tag(true)
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 80)
                    Spacer()
                    TextField("Gegenstand suchen", text: $search)
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 240)
                }

                if let storage {
                    summary(storage)
                    ForEach(Array(storage.tabs.enumerated()), id: \.offset) { _, tab in
                        let items = tab.items.filter { search.isEmpty || ($0.name ?? "").localizedCaseInsensitiveContains(search) }
                        if !items.isEmpty || search.isEmpty {
                            GroupBox {
                                if items.isEmpty {
                                    Text("leer").foregroundStyle(Theme.parchmentDim)
                                } else if asList {
                                    StorageList(items: items)
                                } else {
                                    StorageGrid(items: items)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    if tab.icon != nil { ItemIcon(icon: tab.icon, quality: 1, size: 22) }
                                    Text(tab.name)
                                    Text("\(items.count) Plätze belegt").font(.caption).foregroundStyle(Theme.parchmentDim)
                                }
                            }
                        }
                    }
                } else {
                    emptyState
                }
            }
            .padding(20)
        }
    }

    private func summary(_ s: Storage) -> some View {
        HStack(spacing: 18) {
            Label("Stand: \(s.date.formatted(.dateTime.day().month().year().hour().minute()))", systemImage: "clock")
            Label("\(s.itemCount.formatted()) Gegenstände", systemImage: "shippingbox")
            if let g = s.gold, g > 0 { Label(Fmt.gold(g), systemImage: "dollarsign.circle").foregroundStyle(.yellow) }
            if kind == .guild, let by = s.seenBy { Label("zuletzt gesehen von \(by.split(separator: "-").first.map(String.init) ?? by)", systemImage: "eye") }
            if kind == .warband { Label("gemeinsam für alle Charaktere des Accounts", systemImage: "person.3") }
            Spacer()
        }
        .font(.callout)
        .foregroundStyle(Theme.parchment)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Noch kein Inhalt erfasst", systemImage: kind.icon).font(Theme.heading(18)).foregroundStyle(Theme.gold)
            Text(hint).foregroundStyle(Theme.parchmentDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wowPanel(padding: 18)
    }

    private var hint: String {
        switch kind {
        case .bags: return "Die Taschen speichert das Addon (ab Version 1.3) beim Ausloggen und beim Schließen der Bank."
        case .bank: return "Öffne im Spiel einmal deine Bank – das Addon (ab Version 1.3) merkt sich dann den Inhalt."
        case .warband: return "Öffne im Spiel einmal die Bank mit dem Kriegsmeuten-Reiter. Der Inhalt gilt für alle Charaktere des Accounts."
        case .guild: return character.guild == nil
            ? "Dieser Charakter ist (laut Addon) in keiner Gilde."
            : "Öffne im Spiel einmal die Gildenbank – erfasst werden alle Fächer, die du sehen darfst."
        }
    }
}

struct StorageGrid: View {
    let items: [Storage.Item]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 46, maximum: 46), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                ItemIcon(icon: item.icon, quality: item.quality, size: 44)
                    .overlay(alignment: .bottomTrailing) {
                        if item.count > 1 {
                            Text(item.count >= 1000 ? "\(item.count / 1000)k" : "\(item.count)")
                                .font(.system(size: 11, weight: .heavy)).monospacedDigit()
                                .foregroundStyle(.white)
                                .shadow(color: .black, radius: 1).shadow(color: .black, radius: 1)
                                .padding(3)
                        }
                    }
                    .help([item.name ?? "?", item.count > 1 ? "\(item.count)×" : nil,
                           item.itemLevel.map { "GS \(Int($0))" }].compactMap { $0 }.joined(separator: " · "))
            }
        }
    }
}

struct StorageList: View {
    let items: [Storage.Item]
    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(items.sorted { ($0.quality ?? 0, $0.count) > ($1.quality ?? 0, $1.count) }.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 10) {
                    ItemIcon(icon: item.icon, quality: item.quality, size: 26)
                    Text(item.name ?? "?").foregroundStyle(WowStyle.qualityColor(item.quality)).lineLimit(1)
                    if let il = item.itemLevel { Text("GS \(Int(il))").font(.caption).foregroundStyle(Theme.gold) }
                    Spacer()
                    Text("\(item.count)×").monospacedDigit().foregroundStyle(Theme.parchment)
                }
            }
        }
    }
}
