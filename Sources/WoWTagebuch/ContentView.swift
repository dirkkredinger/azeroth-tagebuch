import SwiftUI


struct ContentView: View {
    @Environment(DataStore.self) private var store
    /// nil = Account-Übersicht „Alle Charaktere“
    @State private var selection: String?
    @State private var search = ""

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                SidebarTitle()
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
                // Als Button statt als Listenzeile: zuverlässig anklickbar, auch wenn sie schon gewählt ist
                Button {
                    selection = nil
                    search = ""
                } label: {
                    AllCharactersRow(count: store.characters.count)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(selection == nil && search.isEmpty ? Theme.goldDim.opacity(0.35) : .clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
                Rectangle().fill(Theme.goldDim.opacity(0.35)).frame(height: 1).padding(.horizontal, 12)

                List(selection: $selection) {
                    Section("Charaktere") {
                        ForEach(store.characters) { ch in
                            CharacterRow(character: ch)
                                .tag(Optional(ch.key))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .background(Theme.sidebar)
            .navigationSplitViewColumnWidth(min: 230, ideal: 260)
            .safeAreaInset(edge: .bottom) { StatusBar() }
            .onChange(of: selection) { _, new in if new != nil { search = "" } }
        } detail: {
            Group {
                if store.characters.isEmpty {
                    EmptyStateView()
                } else if !search.trimmingCharacters(in: .whitespaces).isEmpty {
                    GlobalSearchView(query: search, selection: $selection)
                } else if let key = selection, let ch = store.characters.first(where: { $0.key == key }) {
                    CharacterDetailView(character: ch, showOverview: { selection = nil })
                        .id(ch.key)
                } else {
                    AllCharactersView(selection: $selection)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WowBackground())
        }
        .searchable(text: $search, placement: .toolbar, prompt: "Quests, Beute, Gegner suchen")
        .wowTheme()
        .toolbar {
            ToolbarItemGroup {
                Button { selection = nil; search = "" } label: {
                    Label("Alle Charaktere", systemImage: "person.3")
                }
                .help("Zur Übersicht aller Charaktere (⌘0)")
                .keyboardShortcut("0")
                Button { store.reload() } label: {
                    Label("Neu einlesen", systemImage: "arrow.clockwise")
                }
                .help("SavedVariables neu einlesen (⌘R)")
                Button { store.chooseFolder() } label: {
                    Label("WoW-Ordner", systemImage: "folder")
                }
                .help("WoW-Ordner wählen")
            }
        }
    }
}

struct SidebarTitle: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "book.closed.fill").foregroundStyle(Theme.gold)
            Text("Azeroth-Tagebuch").font(Theme.heading(16)).foregroundStyle(Theme.gold)
            Spacer()
        }
        .textCase(nil)
        .padding(.vertical, 6)
    }
}

struct AllCharactersRow: View {
    let count: Int
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.panelHighlight)
                Circle().strokeBorder(Theme.gold.opacity(0.8), lineWidth: 1.5)
                Image(systemName: "person.3.fill").font(.system(size: 11)).foregroundStyle(Theme.gold)
            }
            .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("Alle Charaktere").font(.system(.body, design: .serif).weight(.semibold)).foregroundStyle(Theme.parchment)
                Text("\(count) Charakter\(count == 1 ? "" : "e") im Überblick").font(.caption).foregroundStyle(Theme.parchmentDim)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }
}

struct CharacterRow: View {
    let character: WowCharacter

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(character.classColor.gradient)
                Circle().strokeBorder(Theme.gold.opacity(0.8), lineWidth: 1.5)
                Text(String(character.name.prefix(1)))
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(.black.opacity(0.75))
            }
            .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(character.name).font(.system(.body, design: .serif).weight(.semibold)).foregroundStyle(character.classColor)
                Text(character.subtitle).font(.caption).foregroundStyle(Theme.parchmentDim)
                Text(character.realm).font(.caption2).foregroundStyle(Theme.parchmentDim.opacity(0.6))
            }
        }
        .padding(.vertical, 2)
    }
}

struct StatusBar: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: store.isDemo ? "sparkles" : "dot.radiowaves.left.and.right")
                .foregroundStyle(store.isDemo ? .orange : .green)
            VStack(alignment: .leading, spacing: 0) {
                Text(store.status).lineLimit(2)
                if let date = store.lastUpdate, !store.isDemo {
                    Text("Geprüft \(date.formatted(date: .omitted, time: .shortened))")
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(Theme.parchmentDim)
        .padding(10)
        .background(Theme.sidebar)
        .overlay(alignment: .top) { Rectangle().fill(Theme.goldDim.opacity(0.4)).frame(height: 1) }
    }
}

struct EmptyStateView: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        ContentUnavailableView {
            Label("Noch keine Tagebuch-Daten", systemImage: "book.closed")
        } description: {
            Text("Spiel mit aktiviertem Addon „Azeroth-Tagebuch“ und logg dich aus oder tippe /reload. Die App liest die Daten dann automatisch ein.\n\nGesucht wird in: \(store.wowFolder.path)/WTF/Account/…/SavedVariables")
        } actions: {
            Button("Beispieldaten anzeigen") { store.loadDemo() }
                .buttonStyle(.borderedProminent)
            Button("WoW-Ordner wählen …") { store.chooseFolder() }
        }
    }
}

// MARK: - Charakter-Detail

enum DetailTab: String, CaseIterable, Identifiable {
    case overview = "Übersicht"
    case quests = "Quests"
    case map = "Karte"
    case timeline = "Zeitleiste"
    case stats = "Statistik"
    case combat = "Kampf"
    case healing = "Heilung"
    case gear = "Ausrüstung"
    case loot = "Beute"
    case storage = "Lager"
    case classInfo = "Klasse"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "house"
        case .quests: return "exclamationmark.bubble"
        case .map: return "map"
        case .timeline: return "scroll"
        case .stats: return "chart.bar"
        case .combat: return "flame"
        case .healing: return "cross.case"
        case .gear: return "tshirt"
        case .loot: return "bag"
        case .storage: return "archivebox"
        case .classInfo: return "person.crop.square"
        }
    }
}

struct CharacterDetailView: View {
    let character: WowCharacter
    var showOverview: () -> Void = {}
    @State private var tab: DetailTab = .overview

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: showOverview) {
                    Label("Alle Charaktere", systemImage: "chevron.left")
                        .font(.system(.caption, design: .serif).weight(.semibold))
                        .foregroundStyle(Theme.gold)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 10)
            CharacterHeader(character: character)
            WowTabBar(tabs: DetailTab.allCases, selection: $tab, label: { $0.rawValue }, icon: { $0.icon })
                .padding(.bottom, 10)
            Rectangle().fill(Theme.goldDim.opacity(0.45)).frame(height: 1)
            Group {
                switch tab {
                case .overview: OverviewView(character: character)
                case .quests: QuestsView(character: character)
                case .map: RouteMapView(character: character)
                case .timeline: JournalTimelineView(character: character)
                case .stats: StatsView(character: character)
                case .combat: CombatStatsView(character: character, mode: .damage)
                case .healing: CombatStatsView(character: character, mode: .healing)
                case .gear: GearView(character: character)
                case .loot: LootView(character: character)
                case .storage: StorageView(character: character)
                case .classInfo: ClassView(character: character)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(character.name)
    }
}

struct CharacterHeader: View {
    let character: WowCharacter
    @Environment(DataStore.self) private var store

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(character.classColor.gradient)
                RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.borderGradient, lineWidth: 2)
                Text(String(character.name.prefix(1))).font(Theme.title(28)).foregroundStyle(.black.opacity(0.7))
            }
            .frame(width: 56, height: 56)
            .shadow(color: character.classColor.opacity(0.4), radius: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text(character.name).font(Theme.title(26)).foregroundStyle(Theme.gold)
                    .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
                Text([character.subtitle, character.spec, character.realm].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .foregroundStyle(Theme.parchmentDim)
            }
            Spacer()
            if let live = store.liveFight, live.char == character.key {
                Label("Im Kampf · \(Fmt.big(Int(live.dps))) DPS", systemImage: "flame.fill")
                    .font(.caption.bold()).foregroundStyle(.red)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.red.opacity(0.15), in: Capsule())
            }
            if let il = character.itemLevel {
                Label("GS \(Int(il))", systemImage: "shield.checkered")
                    .font(.caption.bold()).foregroundStyle(Theme.parchment)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Theme.goldDim.opacity(0.25), in: Capsule())
            }
            if let faction = character.faction {
                Text(faction == "Horde" ? "Horde" : faction == "Alliance" ? "Allianz" : faction)
                    .font(.caption.bold())
                    .foregroundStyle(Theme.parchment)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background((faction == "Horde" ? Color.red : Color.blue).opacity(0.3), in: Capsule())
            }
        }
        .padding(20)
    }
}
