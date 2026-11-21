import SwiftUI

/// Selbst gezeichnete Routenkarte: Reiseweg auf einer Zone, eingefärbt nach Fortbewegung,
/// mit Markierungen für abgeschlossene Quests, Tode und Notizen.
struct RouteMapView: View {
    let character: WowCharacter
    @Environment(DataStore.self) private var store
    @State private var mapID: Int?
    @State private var day: Date?
    @AppStorage("kartenAusschnitt") private var zoomToRoute = true

    private var mapIDs: [Int] {
        var counts: [Int: Int] = [:]
        for ev in character.events where ev.hasPosition { counts[ev.m!, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value }.map(\.key)
    }

    private var days: [Date] {
        let cal = Calendar.current
        let set = Set(character.events.filter { $0.m == mapID && $0.hasPosition }.map { cal.startOfDay(for: $0.date) })
        return set.sorted(by: >)
    }

    private var visibleEvents: [WowEvent] {
        let cal = Calendar.current
        return character.events.filter { ev in
            guard ev.m == mapID, ev.hasPosition else { return false }
            if let day { return cal.isDate(ev.date, inSameDayAs: day) }
            return true
        }
    }

    var body: some View {
        let events = visibleEvents
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Picker("Zone", selection: $mapID) {
                    ForEach(mapIDs, id: \.self) { id in
                        Text(store.mapName(id)).tag(Optional(id))
                    }
                }
                .frame(maxWidth: 280)
                Picker("Tag", selection: $day) {
                    Text("Alle Tage").tag(Date?.none)
                    ForEach(days, id: \.self) { d in
                        Text(d.formatted(.dateTime.weekday().day().month())).tag(Optional(d))
                    }
                }
                .frame(maxWidth: 220)
                Picker("Ausschnitt", selection: $zoomToRoute) {
                    Text("Meine Route").tag(true)
                    Text("Ganze Zone").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 220)
                Spacer()
            }
            MapLegend()

            if mapIDs.isEmpty {
                ContentUnavailableView("Noch keine Reisewege",
                                       systemImage: "map",
                                       description: Text("Sobald du mit dem Addon unterwegs warst, erscheint hier deine Route."))
            } else {
                let image = mapID.flatMap { store.mapArt.images[$0] }
                MapCanvas(events: events, title: store.mapName(mapID), image: image,
                          artState: mapID.flatMap { store.mapArt.state($0) },
                          viewport: zoomToRoute ? Self.viewport(for: events) : CGRect(x: 0, y: 0, width: 1, height: 1))
                    .aspectRatio(image.map { CGFloat($0.width) / CGFloat($0.height) } ?? 1.5, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                MapSummary(events: events)
            }
        }
        .padding(16)
        .onAppear {
            if mapID == nil { mapID = mapIDs.first }
            if let mapID { store.mapArt.request(mapID) }
        }
        .onChange(of: mapID) { _, new in
            day = nil
            if let new { store.mapArt.request(new) }
        }
    }

    /// Ausschnitt um die Route herum (in Kartenkoordinaten, gleiche Breite und Höhe → unverzerrt)
    static func viewport(for events: [WowEvent]) -> CGRect {
        let pts = events.filter(\.hasPosition)
        guard let minX = pts.map({ $0.x! }).min(), let maxX = pts.map({ $0.x! }).max(),
              let minY = pts.map({ $0.y! }).min(), let maxY = pts.map({ $0.y! }).max() else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        let side = min(1, max(maxX - minX, maxY - minY, 0.12) * 1.3)
        let cx = (minX + maxX) / 2, cy = (minY + maxY) / 2
        let x = min(max(cx - side / 2, 0), 1 - side), y = min(max(cy - side / 2, 0), 1 - side)
        return CGRect(x: x, y: y, width: side, height: side)
    }
}

struct MapLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach(WowStyle.modeOrder, id: \.self) { mode in
                HStack(spacing: 4) {
                    Capsule().fill(WowStyle.modeColor(mode)).frame(width: 14, height: 4)
                    Text(WowStyle.modeLabel(mode))
                }
            }
            HStack(spacing: 4) { Image(systemName: "checkmark.seal.fill").foregroundStyle(.yellow); Text("Quest") }
            HStack(spacing: 4) { Image(systemName: "xmark").foregroundStyle(.red); Text("Tod") }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .fixedSize()
    }
}

struct MapMarker {
    var point: CGPoint      // 0…1
    var event: WowEvent
}

struct MapCanvas: View {
    let events: [WowEvent]
    let title: String
    var image: CGImage?
    var artState: MapArtStore.State?
    /// Sichtbarer Ausschnitt in Kartenkoordinaten (0…1)
    var viewport = CGRect(x: 0, y: 0, width: 1, height: 1)
    @State private var hover: CGPoint?

    private var positions: [WowEvent] { events.filter { $0.e == "pos" } }
    private var markers: [MapMarker] {
        events.filter { ["quest_ab", "tod", "notiz", "level", "erfolg"].contains($0.e) }
            .map { MapMarker(point: CGPoint(x: $0.x!, y: $0.y!), event: $0) }
    }

    private func project(_ p: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: (p.x - viewport.minX) / viewport.width * size.width,
                y: (p.y - viewport.minY) / viewport.height * size.height)
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let marks = markers
            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in
                    drawBackground(ctx, size)
                    drawRoute(ctx, size)
                    drawMarkers(ctx, size, marks)
                }
                Text(title)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
                    .padding(12)

                if image == nil, let artState {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            switch artState {
                            case .loading:
                                ProgressView().controlSize(.small)
                                Text("Kartenbild wird aus deiner WoW-Installation geladen …")
                            case .unavailable(let why):
                                Image(systemName: "map")
                                Text("Kein Kartenbild: \(why)")
                            case .ready:
                                EmptyView()
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(Theme.ink)
                        .padding(8)
                        .background(Theme.parchment.opacity(0.9), in: Capsule())
                        .padding(12)
                    }
                    .frame(maxWidth: .infinity)
                }

                if let hover, let near = nearest(to: hover, in: size, marks: marks) {
                    let p = project(near.point, size)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(near.event.title()).font(.caption.bold())
                        Text(near.event.date.formatted(.dateTime.day().month().hour().minute()))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .fixedSize()
                    .offset(x: min(p.x + 12, size.width - 220), y: max(p.y - 44, 0))
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let loc): hover = loc
                case .ended: hover = nil
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.borderGradient, lineWidth: 2))
        .shadow(color: .black.opacity(0.6), radius: 8, y: 3)
    }

    private func nearest(to loc: CGPoint, in size: CGSize, marks: [MapMarker]) -> MapMarker? {
        var best: (MapMarker, CGFloat)?
        for m in marks {
            let p = project(m.point, size)
            let d = ((p.x - loc.x) * (p.x - loc.x) + (p.y - loc.y) * (p.y - loc.y)).squareRoot()
            if d < 14, d < (best?.1 ?? .infinity) { best = (m, d) }
        }
        return best?.0
    }

    private func drawBackground(_ ctx: GraphicsContext, _ size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        if let image {
            ctx.fill(Path(rect), with: .color(.black))
            let full = CGRect(x: -viewport.minX / viewport.width * size.width,
                              y: -viewport.minY / viewport.height * size.height,
                              width: size.width / viewport.width, height: size.height / viewport.height)
            ctx.draw(Image(decorative: image, scale: 1), in: full)
            // leicht abdunkeln, damit die Route besser hervortritt
            ctx.fill(Path(rect), with: .color(.black.opacity(0.12)))
            return
        }
        ctx.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [Color(red: 0.96, green: 0.91, blue: 0.79), Color(red: 0.9, green: 0.83, blue: 0.68)]),
            startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
        var grid = Path()
        for k in 1..<10 {
            let x = size.width * CGFloat(k) / 10
            let y = size.height * CGFloat(k) / 10
            grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height))
            grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
        }
        ctx.stroke(grid, with: .color(Color(red: 0.55, green: 0.4, blue: 0.2).opacity(0.12)), lineWidth: 1)
    }

    private func drawRoute(_ ctx: GraphicsContext, _ size: CGSize) {
        let pos = positions
        guard pos.count > 1 else { return }
        func pt(_ e: WowEvent) -> CGPoint { project(CGPoint(x: e.x!, y: e.y!), size) }

        var paths: [String: Path] = [:]
        var all = Path()
        for k in 1..<pos.count {
            let a = pos[k - 1], b = pos[k]
            guard b.t - a.t <= 90 else { continue }   // Lücke = neue Sitzung oder Teleport
            let mode = a.mo ?? "zu_fuss"
            var p = paths[mode] ?? Path()
            p.move(to: pt(a)); p.addLine(to: pt(b))
            paths[mode] = p
            all.move(to: pt(a)); all.addLine(to: pt(b))
        }
        // dunkle Kontur unter der Route
        ctx.stroke(all, with: .color(.black.opacity(0.55)), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        for mode in WowStyle.modeOrder + paths.keys.filter({ !WowStyle.modeOrder.contains($0) }) {
            guard let p = paths[mode] else { continue }
            let dash: [CGFloat] = mode == "taxi" ? [6, 4] : []
            ctx.stroke(p, with: .color(WowStyle.modeColor(mode)),
                       style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round, dash: dash))
        }
        // Start- und Endpunkt
        let start = pt(pos.first!), end = pt(pos.last!)
        ctx.fill(Path(ellipseIn: CGRect(x: start.x - 6, y: start.y - 6, width: 12, height: 12)), with: .color(.green))
        ctx.stroke(Path(ellipseIn: CGRect(x: start.x - 6, y: start.y - 6, width: 12, height: 12)), with: .color(.black.opacity(0.7)), lineWidth: 1.5)
        ctx.fill(Path(ellipseIn: CGRect(x: end.x - 7, y: end.y - 7, width: 14, height: 14)), with: .color(.white))
        ctx.stroke(Path(ellipseIn: CGRect(x: end.x - 7, y: end.y - 7, width: 14, height: 14)), with: .color(.black.opacity(0.8)), lineWidth: 2)
    }

    private func drawMarkers(_ ctx: GraphicsContext, _ size: CGSize, _ marks: [MapMarker]) {
        // Tode zuletzt zeichnen, damit sie nicht unter Quest-, Stufen- oder Notizpunkten verschwinden
        let ordered = marks.filter { $0.event.e != "tod" } + marks.filter { $0.event.e == "tod" }
        for m in ordered {
            let p = project(m.point, size)
            switch m.event.e {
            case "tod":
                var x = Path()
                x.move(to: CGPoint(x: p.x - 6, y: p.y - 6)); x.addLine(to: CGPoint(x: p.x + 6, y: p.y + 6))
                x.move(to: CGPoint(x: p.x + 6, y: p.y - 6)); x.addLine(to: CGPoint(x: p.x - 6, y: p.y + 6))
                ctx.stroke(x, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
                ctx.stroke(x, with: .color(.red), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            default:
                let color: Color = m.event.e == "quest_ab" ? .yellow
                    : m.event.e == "notiz" ? .purple
                    : m.event.e == "level" ? .green : .orange
                let r: CGFloat = m.event.e == "quest_ab" ? 5.5 : 6.5
                let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(color))
                ctx.stroke(Path(ellipseIn: rect), with: .color(.black.opacity(0.75)), lineWidth: 1.5)
            }
        }
    }
}

struct MapSummary: View {
    let events: [WowEvent]

    var body: some View {
        let quests = events.filter { $0.e == "quest_ab" }.count
        let deaths = events.filter { $0.e == "tod" }.count
        let samples = events.filter { $0.e == "pos" }
        let minutes = samples.count > 1 ? max(0, (samples.last!.t - samples.first!.t) / 60) : 0
        HStack(spacing: 20) {
            Label("\(quests) Quests abgeschlossen", systemImage: "checkmark.seal.fill")
            Label("\(deaths) Tode", systemImage: "heart.slash.fill")
            Label("\(samples.count) Wegpunkte", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            if minutes > 0 { Label("Zeitraum \(Fmt.duration(minutes * 60))", systemImage: "clock") }
            Spacer()
            Text("Fahre mit der Maus über eine Markierung für Details")
                .foregroundStyle(.tertiary)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}
