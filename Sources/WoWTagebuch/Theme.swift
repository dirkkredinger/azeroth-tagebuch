import SwiftUI

/// Eigenes Fantasy-Design im Stil alter Abenteuerbücher: dunkles Leder, Gold und Pergament.
/// Alles ist selbst gezeichnet – es werden keine Blizzard-Grafiken oder -Schriften verwendet.
enum Theme {
    static let gold = Color(red: 0.98, green: 0.80, blue: 0.36)
    static let goldDeep = Color(red: 0.78, green: 0.58, blue: 0.22)
    static let goldDim = Color(red: 0.62, green: 0.48, blue: 0.24)
    static let parchment = Color(red: 0.94, green: 0.88, blue: 0.74)
    static let parchmentDim = Color(red: 0.75, green: 0.69, blue: 0.57)
    static let ink = Color(red: 0.24, green: 0.15, blue: 0.07)
    static let leatherTop = Color(red: 0.13, green: 0.09, blue: 0.06)
    static let leatherBottom = Color(red: 0.06, green: 0.04, blue: 0.03)
    static let panel = Color(red: 0.17, green: 0.12, blue: 0.08)
    static let panelHighlight = Color(red: 0.24, green: 0.17, blue: 0.10)
    static let sidebar = Color(red: 0.09, green: 0.06, blue: 0.04)

    static let damage = Color(red: 0.93, green: 0.36, blue: 0.24)
    static let healing = Color(red: 0.36, green: 0.86, blue: 0.45)
    static let taken = Color(red: 0.62, green: 0.42, blue: 0.86)
    static let shield = Color(red: 0.55, green: 0.80, blue: 0.98)

    static func title(_ size: CGFloat = 22) -> Font { .system(size: size, weight: .bold, design: .serif) }
    static func heading(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .semibold, design: .serif) }

    static let borderGradient = LinearGradient(
        colors: [gold.opacity(0.85), goldDim.opacity(0.35), goldDeep.opacity(0.75)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// Hintergrund wie dunkles Leder mit leichter Vignette.
struct WowBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.leatherTop, Theme.leatherBottom], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Theme.goldDeep.opacity(0.10), .clear], center: .topLeading, startRadius: 0, endRadius: 700)
            Canvas { ctx, size in
                // feine Maserung
                var rng = SeededRandom(seed: 42)
                for _ in 0..<Int(size.width * size.height / 900) {
                    let x = rng.next() * size.width, y = rng.next() * size.height
                    let r = rng.next() * 1.2 + 0.3
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                             with: .color(.white.opacity(0.018 + rng.next() * 0.02)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) % 10_000) / 10_000
    }
}

/// Rahmen mit Goldkante für Kacheln und Kästen.
struct WowPanel: ViewModifier {
    var padding: CGFloat = 12
    var highlight = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [highlight ? Theme.panelHighlight : Theme.panel, Theme.panel.opacity(0.85)],
                                         startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.borderGradient, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6).strokeBorder(Color.black.opacity(0.45), lineWidth: 1).padding(2)
            )
    }
}

extension View {
    func wowPanel(padding: CGFloat = 12, highlight: Bool = false) -> some View {
        modifier(WowPanel(padding: padding, highlight: highlight))
    }

    /// Grundlook für die ganze App
    func wowTheme() -> some View {
        self
            .preferredColorScheme(.dark)
            .tint(Theme.gold)
            .groupBoxStyle(WowGroupBoxStyle())
    }
}

struct WowGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            configuration.label
                .font(Theme.heading())
                .foregroundStyle(Theme.gold)
            configuration.content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wowPanel()
    }
}

/// Überschrift mit Zierlinie
struct OrnamentHeader: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Text(text).font(Theme.title(26)).foregroundStyle(Theme.gold)
                .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
            Ornament()
        }
    }
}

struct Ornament: View {
    var body: some View {
        HStack(spacing: 4) {
            Rectangle().fill(LinearGradient(colors: [Theme.gold.opacity(0.7), Theme.goldDim.opacity(0.0)],
                                             startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
        }
        .overlay(alignment: .leading) {
            Image(systemName: "diamond.fill").font(.system(size: 7)).foregroundStyle(Theme.gold)
        }
    }
}

/// Reiterleiste im Fantasy-Stil
struct WowTabBar<Tab: Hashable & Identifiable>: View {
    let tabs: [Tab]
    @Binding var selection: Tab
    let label: (Tab) -> String
    let icon: (Tab) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(tabs) { tab in
                    let active = tab == selection
                    Button { selection = tab } label: {
                        HStack(spacing: 6) {
                            Image(systemName: icon(tab)).font(.system(size: 11))
                            Text(label(tab)).font(.system(size: 13, weight: active ? .bold : .medium, design: .serif))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .foregroundStyle(active ? Theme.ink : Theme.parchmentDim)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(active
                                      ? AnyShapeStyle(LinearGradient(colors: [Theme.gold, Theme.goldDeep], startPoint: .top, endPoint: .bottom))
                                      : AnyShapeStyle(Theme.panel.opacity(0.8)))
                        )
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.goldDim.opacity(active ? 0.9 : 0.4), lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
