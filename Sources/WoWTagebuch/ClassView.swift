import SwiftUI
import AppKit

/// Daten zu Klassen und Spezialisierungen (eigene Kurztexte, Links zu Wowhead).
/// Talent-Builds werden bewusst nicht von Wowhead übernommen, sondern nur verlinkt.
enum SpecCatalog {
    struct Spec { var classSlug: String; var slug: String; var role: String }

    static let specs: [Int: Spec] = [
        250: .init(classSlug: "death-knight", slug: "blood", role: "TANK"),
        251: .init(classSlug: "death-knight", slug: "frost", role: "DAMAGER"),
        252: .init(classSlug: "death-knight", slug: "unholy", role: "DAMAGER"),
        577: .init(classSlug: "demon-hunter", slug: "havoc", role: "DAMAGER"),
        581: .init(classSlug: "demon-hunter", slug: "vengeance", role: "TANK"),
        1480: .init(classSlug: "demon-hunter", slug: "devourer", role: "DAMAGER"),
        102: .init(classSlug: "druid", slug: "balance", role: "DAMAGER"),
        103: .init(classSlug: "druid", slug: "feral", role: "DAMAGER"),
        104: .init(classSlug: "druid", slug: "guardian", role: "TANK"),
        105: .init(classSlug: "druid", slug: "restoration", role: "HEALER"),
        1467: .init(classSlug: "evoker", slug: "devastation", role: "DAMAGER"),
        1468: .init(classSlug: "evoker", slug: "preservation", role: "HEALER"),
        1473: .init(classSlug: "evoker", slug: "augmentation", role: "DAMAGER"),
        253: .init(classSlug: "hunter", slug: "beast-mastery", role: "DAMAGER"),
        254: .init(classSlug: "hunter", slug: "marksmanship", role: "DAMAGER"),
        255: .init(classSlug: "hunter", slug: "survival", role: "DAMAGER"),
        62: .init(classSlug: "mage", slug: "arcane", role: "DAMAGER"),
        63: .init(classSlug: "mage", slug: "fire", role: "DAMAGER"),
        64: .init(classSlug: "mage", slug: "frost", role: "DAMAGER"),
        268: .init(classSlug: "monk", slug: "brewmaster", role: "TANK"),
        269: .init(classSlug: "monk", slug: "windwalker", role: "DAMAGER"),
        270: .init(classSlug: "monk", slug: "mistweaver", role: "HEALER"),
        65: .init(classSlug: "paladin", slug: "holy", role: "HEALER"),
        66: .init(classSlug: "paladin", slug: "protection", role: "TANK"),
        70: .init(classSlug: "paladin", slug: "retribution", role: "DAMAGER"),
        256: .init(classSlug: "priest", slug: "discipline", role: "HEALER"),
        257: .init(classSlug: "priest", slug: "holy", role: "HEALER"),
        258: .init(classSlug: "priest", slug: "shadow", role: "DAMAGER"),
        259: .init(classSlug: "rogue", slug: "assassination", role: "DAMAGER"),
        260: .init(classSlug: "rogue", slug: "outlaw", role: "DAMAGER"),
        261: .init(classSlug: "rogue", slug: "subtlety", role: "DAMAGER"),
        262: .init(classSlug: "shaman", slug: "elemental", role: "DAMAGER"),
        263: .init(classSlug: "shaman", slug: "enhancement", role: "DAMAGER"),
        264: .init(classSlug: "shaman", slug: "restoration", role: "HEALER"),
        265: .init(classSlug: "warlock", slug: "affliction", role: "DAMAGER"),
        266: .init(classSlug: "warlock", slug: "demonology", role: "DAMAGER"),
        267: .init(classSlug: "warlock", slug: "destruction", role: "DAMAGER"),
        71: .init(classSlug: "warrior", slug: "arms", role: "DAMAGER"),
        72: .init(classSlug: "warrior", slug: "fury", role: "DAMAGER"),
        73: .init(classSlug: "warrior", slug: "protection", role: "TANK"),
    ]

    struct ClassInfo { var slug: String; var armor: String; var resource: String; var text: String }

    static let classes: [String: ClassInfo] = [
        "DEATHKNIGHT": .init(slug: "death-knight", armor: "Platte", resource: "Runen & Runenmacht", text: "Untote Ritter, die Frost, Seuche und Blut beherrschen."),
        "DEMONHUNTER": .init(slug: "demon-hunter", armor: "Leder", resource: "Zorn / Qual", text: "Wendige Jäger, die dämonische Kräfte gegen ihre Feinde wenden."),
        "DRUID": .init(slug: "druid", armor: "Leder", resource: "Mana, Energie, Wut, Astrale Macht", text: "Gestaltwandler, die jede Rolle übernehmen können."),
        "EVOKER": .init(slug: "evoker", armor: "Kette", resource: "Mana & Essenz", text: "Drachenblütige Zauberwirker mit aufladbaren Fähigkeiten."),
        "HUNTER": .init(slug: "hunter", armor: "Kette", resource: "Fokus", text: "Fernkämpfer mit Tiergefährten und Fallen."),
        "MAGE": .init(slug: "mage", armor: "Stoff", resource: "Mana", text: "Gelehrte der Arkan-, Feuer- und Frostmagie."),
        "MONK": .init(slug: "monk", armor: "Leder", resource: "Energie, Chi, Mana", text: "Kampfkünstler, die Chi lenken."),
        "PALADIN": .init(slug: "paladin", armor: "Platte", resource: "Mana & Heilige Kraft", text: "Streiter des Lichts für Schutz, Heilung und Vergeltung."),
        "PRIEST": .init(slug: "priest", armor: "Stoff", resource: "Mana / Wahnsinn", text: "Heiler und Schattenwirker."),
        "ROGUE": .init(slug: "rogue", armor: "Leder", resource: "Energie & Combopunkte", text: "Meister der Klingen, Gifte und Heimlichkeit."),
        "SHAMAN": .init(slug: "shaman", armor: "Kette", resource: "Mana / Mahlstrom", text: "Rufen die Elemente und stellen Totems auf."),
        "WARLOCK": .init(slug: "warlock", armor: "Stoff", resource: "Mana & Seelensplitter", text: "Beschwören Dämonen und lassen Gebrechen wirken."),
        "WARRIOR": .init(slug: "warrior", armor: "Platte", resource: "Wut", text: "Waffenmeister in Rüstung, im Angriff wie in der Verteidigung."),
    ]

    static func roleName(_ role: String?) -> String {
        switch role {
        case "TANK": return "Tank"
        case "HEALER": return "Heiler"
        case "DAMAGER": return "Schaden"
        default: return "–"
        }
    }

    static func roleSlug(_ role: String?) -> String {
        switch role {
        case "TANK": return "tank"
        case "HEALER": return "healer"
        default: return "dps"
        }
    }

    static func roleIcon(_ role: String?) -> String {
        switch role {
        case "TANK": return "shield.fill"
        case "HEALER": return "cross.fill"
        default: return "bolt.fill"
        }
    }

    static func statName(_ stat: Int?) -> String? {
        switch stat {
        case 1: return "Stärke"
        case 2: return "Beweglichkeit"
        case 4: return "Intellekt"
        default: return nil
        }
    }

    struct GuideLink: Identifiable { var title: String; var icon: String; var url: URL; var id: String { title } }

    static func links(specID: Int?, role: String?, classToken: String?, talentCode: String?) -> [GuideLink] {
        let base = "https://www.wowhead.com/de"
        var out: [GuideLink] = []
        if let specID, let spec = specs[specID] {
            let r = roleSlug(role ?? spec.role)
            let g = "\(base)/guide/classes/\(spec.classSlug)/\(spec.slug)"
            func add(_ title: String, _ icon: String, _ path: String) {
                if let u = URL(string: "\(g)/\(path)") { out.append(.init(title: title, icon: icon, url: u)) }
            }
            add("Talent-Builds", "point.3.connected.trianglepath.dotted", "talent-builds-pve-\(r)")
            add("Überblick", "book.closed", "overview-pve-\(r)")
            add("Rotation & Abklingzeiten", "arrow.triangle.2.circlepath", "rotation-cooldowns-pve-\(r)")
            add("Werte-Prioritäten", "chart.bar", "stat-priority-pve-\(r)")
            add("Ausrüstung (Best in Slot)", "shield.checkered", "bis-gear")
        } else if let token = classToken, let c = classes[token], let u = URL(string: "\(base)/guide/classes/\(c.slug)") {
            out.append(.init(title: "Klassen-Guides", icon: "book.closed", url: u))
        }
        if let code = talentCode, !code.hasPrefix("DEMO"),
           let enc = code.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
           let u = URL(string: "\(base)/talent-calc/blizzard/\(enc)") {
            out.append(.init(title: "Meine Talente im Talentrechner", icon: "sparkles", url: u))
        }
        return out
    }
}

struct ClassView: View {
    let character: WowCharacter
    @State private var copied = false

    var body: some View {
        let info = SpecCatalog.classes[character.classToken ?? ""]
        let role = character.role ?? character.specID.flatMap { SpecCatalog.specs[$0]?.role }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    // Klasse
                    VStack(alignment: .leading, spacing: 8) {
                        Text(character.className ?? "Klasse").font(Theme.title(22)).foregroundStyle(character.classColor)
                        if let info { Text(info.text).foregroundStyle(Theme.parchment) }
                        Divider().overlay(Theme.goldDim.opacity(0.4))
                        if let info {
                            InfoLine(label: "Rüstung", value: info.armor, icon: "shield.lefthalf.filled")
                            InfoLine(label: "Ressource", value: info.resource, icon: "drop.fill")
                        }
                        if let il = character.itemLevel {
                            InfoLine(label: "Gegenstandsstufe", value: il.formatted(.number.precision(.fractionLength(1))), icon: "shield.checkered")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .wowPanel(padding: 16)

                    // Spezialisierung
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(character.spec ?? "Spezialisierung").font(Theme.title(22)).foregroundStyle(Theme.gold)
                            Spacer()
                            Label(SpecCatalog.roleName(role), systemImage: SpecCatalog.roleIcon(role))
                                .font(.caption.bold())
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Theme.goldDim.opacity(0.25), in: Capsule())
                                .foregroundStyle(Theme.parchment)
                        }
                        if let d = character.specDesc, !d.isEmpty {
                            Text(d).foregroundStyle(Theme.parchment).fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("Die Beschreibung erscheint, sobald das Addon (ab Version 1.1) die Spezialisierung mitgeschrieben hat.")
                                .foregroundStyle(Theme.parchmentDim)
                        }
                        Divider().overlay(Theme.goldDim.opacity(0.4))
                        if let stat = SpecCatalog.statName(character.primaryStat) {
                            InfoLine(label: "Primärwert", value: stat, icon: "figure.strengthtraining.traditional")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .wowPanel(padding: 16)
                }

                GroupBox("Guides & Talent-Builds (Wowhead)") {
                    let links = SpecCatalog.links(specID: character.specID, role: role,
                                                  classToken: character.classToken, talentCode: character.talentCode)
                    if links.isEmpty {
                        Text("Noch keine Spezialisierung bekannt.").foregroundStyle(Theme.parchmentDim)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], spacing: 10) {
                            ForEach(links) { l in
                                Link(destination: l.url) {
                                    HStack {
                                        Image(systemName: l.icon).frame(width: 20)
                                        Text(l.title)
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square").foregroundStyle(Theme.goldDim)
                                    }
                                    .padding(10)
                                    .background(Theme.panelHighlight, in: RoundedRectangle(cornerRadius: 6))
                                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.goldDim.opacity(0.5)))
                                    .foregroundStyle(Theme.parchment)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text("Die empfohlenen Builds stammen von Wowhead und öffnen sich im Browser. Den aktuellen Build importierst du im Spiel über „Laden/Teilen → Importieren“.")
                            .font(.caption).foregroundStyle(Theme.parchmentDim)
                    }
                }

                GroupBox("Dein Talent-Build") {
                    if let code = character.talentCode {
                        HStack(alignment: .top) {
                            Text(code).font(.system(.caption, design: .monospaced)).foregroundStyle(Theme.parchment)
                                .lineLimit(3).textSelection(.enabled)
                            Spacer()
                            Button(copied ? "Kopiert" : "Code kopieren") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(code, forType: .string)
                                copied = true
                            }
                        }
                    } else {
                        Text("Noch kein Talentcode – er wird vom Addon beim nächsten Einloggen gespeichert.").foregroundStyle(Theme.parchmentDim)
                    }
                }

                GroupBox("Verlauf: Talente & Ausrüstung") {
                    let history = (character.talentChanges + character.itemLevelChanges).sorted { $0.t > $1.t }
                    if history.isEmpty {
                        Text("Noch keine Einträge.").foregroundStyle(Theme.parchmentDim)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(history.prefix(30)) { ev in
                                HStack {
                                    EventRow(event: ev, showDate: true)
                                    if ev.e == "talente", let lv = ev.lv { Text("Stufe \(lv)").font(.caption).foregroundStyle(Theme.parchmentDim) }
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

struct InfoLine: View {
    let label: String
    let value: String
    let icon: String
    var body: some View {
        HStack {
            Label(label, systemImage: icon).foregroundStyle(Theme.parchmentDim)
            Spacer()
            Text(value).foregroundStyle(Theme.parchment).fontWeight(.semibold)
        }
        .font(.callout)
    }
}
