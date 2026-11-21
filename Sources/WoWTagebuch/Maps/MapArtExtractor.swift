import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Setzt das Kartenbild einer Zone (uiMapID) aus den Kacheln der lokalen WoW-Installation zusammen.
/// Die App liefert keine Blizzard-Grafiken mit: Jedes Bild entsteht erst beim Nutzer und
/// landet nur in seinem App-Ordner (~/Library/Application Support/WoWTagebuch/Karten).
final class MapArtExtractor {
    // FileDataIDs der Datenbanktabellen (stabil über alle Spielversionen)
    private enum FDID {
        static let uiMapArt: UInt32 = 1957202
        static let uiMapArtStyleLayer: UInt32 = 1957208
        static let uiMapArtTile: UInt32 = 1957210
        static let uiMapXMapArt: UInt32 = 1957217
        static let worldMapOverlay: UInt32 = 1134579
        static let worldMapOverlayTile: UInt32 = 1957212
    }

    /// Erkundungs-Overlays: Bei älteren Zonen liegt das Gelände nicht in der Grundkarte,
    /// sondern in Overlays je Gebiet. Die App zeigt die Karte „voll erkundet“.
    struct Overlay { var id: UInt32; var width: Int; var height: Int; var x: Int; var y: Int }

    struct Layer { var width: Int; var height: Int; var tileWidth: Int; var tileHeight: Int }
    struct Tile { var row: Int; var col: Int; var fileDataID: UInt32 }

    private let storage: CascStorage
    private var artsForMap: [UInt32: [UInt32]] = [:]   // uiMapID → UiMapArtIDs (Phase 0 zuerst)
    private var styleForArt: [UInt32: UInt32] = [:]
    private var layerForStyle: [UInt32: Layer] = [:]
    private var tilesForArt: [UInt32: [Tile]] = [:]
    private var overlaysForArt: [UInt32: [Overlay]] = [:]
    private var tilesForOverlay: [UInt32: [Tile]] = [:]

    init(gameFolder: URL) throws {
        storage = try CascStorage(gameFolder: gameFolder)

        let xmap = try DB2Table(data: storage.read(fileDataID: FDID.uiMapXMapArt))
        // Felder: PhaseID, UiMapArtID; Beziehung: UiMapID
        var tmp: [UInt32: [(phase: UInt32, art: UInt32)]] = [:]
        for r in xmap.rows {
            guard let map = r.relation, r.fields.count >= 2 else { continue }
            tmp[map, default: []].append((r.fields[0], r.fields[1]))
        }
        artsForMap = tmp.mapValues { $0.sorted { ($0.phase == 0 ? 0 : 1) < ($1.phase == 0 ? 0 : 1) }.map(\.art) }

        let art = try DB2Table(data: storage.read(fileDataID: FDID.uiMapArt))
        // Felder: HighlightFileDataID, HighlightAtlasID, UiMapArtStyleID
        for r in art.rows where r.fields.count >= 3 { styleForArt[r.id] = r.fields[2] }

        let layers = try DB2Table(data: storage.read(fileDataID: FDID.uiMapArtStyleLayer))
        // Felder: LayerIndex, LayerWidth, LayerHeight, TileWidth, TileHeight, MinScale, MaxScale, AdditionalZoomSteps; Beziehung: Style
        for r in layers.rows where r.fields.count >= 5 && r.fields[0] == 0 {
            guard let style = r.relation else { continue }
            layerForStyle[style] = Layer(width: Int(r.fields[1]), height: Int(r.fields[2]),
                                         tileWidth: Int(r.fields[3]), tileHeight: Int(r.fields[4]))
        }

        let tiles = try DB2Table(data: storage.read(fileDataID: FDID.uiMapArtTile))
        // Felder: RowIndex, ColIndex, LayerIndex, FileDataID; Beziehung: UiMapArtID
        for r in tiles.rows where r.fields.count >= 4 && r.fields[2] == 0 {
            guard let artID = r.relation else { continue }
            tilesForArt[artID, default: []].append(Tile(row: Int(r.fields[0]), col: Int(r.fields[1]), fileDataID: r.fields[3]))
        }

        // Overlays sind optional – fehlen sie, gibt es eben nur die Grundkarte
        if let overlays = try? DB2Table(data: storage.read(fileDataID: FDID.worldMapOverlay)) {
            // Felder: ID, UiMapArtID, TextureWidth, TextureHeight, OffsetX, OffsetY, HitRect×4, PlayerConditionID, Flags, AreaID[4]
            for r in overlays.rows where r.fields.count >= 11 {
                guard r.fields[10] == 0 else { continue }      // nur bedingungslose Overlays
                let ov = Overlay(id: r.id, width: Int(r.fields[2]), height: Int(r.fields[3]),
                                 x: Int(Int32(bitPattern: r.fields[4])), y: Int(Int32(bitPattern: r.fields[5])))
                overlaysForArt[r.fields[1], default: []].append(ov)
            }
        }
        if let otiles = try? DB2Table(data: storage.read(fileDataID: FDID.worldMapOverlayTile)) {
            // Felder: RowIndex, ColIndex, LayerIndex, FileDataID; Beziehung: WorldMapOverlayID
            for r in otiles.rows where r.fields.count >= 4 && r.fields[2] == 0 {
                guard let ov = r.relation else { continue }
                tilesForOverlay[ov, default: []].append(Tile(row: Int(r.fields[0]), col: Int(r.fields[1]), fileDataID: r.fields[3]))
            }
        }
    }

    var knownMapCount: Int { artsForMap.count }

    func hasArt(for mapID: Int) -> Bool { artsForMap[UInt32(mapID)] != nil }

    /// Rendert die Karte; nil, wenn es für diese Karte keine Kacheln gibt.
    func render(mapID: Int) throws -> CGImage? {
        guard let arts = artsForMap[UInt32(mapID)] else { return nil }
        for artID in arts {
            guard let style = styleForArt[artID], let layer = layerForStyle[style],
                  let tiles = tilesForArt[artID], !tiles.isEmpty,
                  layer.width > 0, layer.height > 0 else { continue }
            let w = layer.width, h = layer.height
            let tw = max(layer.tileWidth, 1), th = max(layer.tileHeight, 1)
            guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            var drawn = 0
            for t in tiles {
                guard let data = try? storage.read(fileDataID: t.fileDataID),
                      let img = try? BLPDecoder.decode(data),
                      let cg = Self.cgImage(img) else { continue }
                // CoreGraphics zählt y von unten
                let rect = CGRect(x: t.col * tw, y: h - t.row * th - img.height, width: img.width, height: img.height)
                ctx.draw(cg, in: rect)
                drawn += 1
            }
            guard drawn > 0 else { continue }
            for ov in overlaysForArt[artID] ?? [] {
                for t in tilesForOverlay[ov.id] ?? [] {
                    guard let data = try? storage.read(fileDataID: t.fileDataID),
                          let img = try? BLPDecoder.decode(data),
                          let cg = Self.cgImage(img) else { continue }
                    // Kacheln eines Overlays sind 256 px groß; Ränder werden auf die Overlay-Größe beschnitten
                    let px = ov.x + t.col * 256, py = ov.y + t.row * 256
                    let w = min(img.width, ov.width - t.col * 256), hh = min(img.height, ov.height - t.row * 256)
                    guard w > 0, hh > 0, let part = cg.cropping(to: CGRect(x: 0, y: 0, width: w, height: hh)) else { continue }
                    ctx.draw(part, in: CGRect(x: px, y: h - py - hh, width: w, height: hh))
                }
            }
            return ctx.makeImage()
        }
        return nil
    }

    static func cgImage(_ img: BLPDecoder.Image) -> CGImage? {
        var px = img.rgba
        // auf vormultipliziertes Alpha umrechnen
        for i in stride(from: 0, to: px.count, by: 4) where px[i + 3] < 255 {
            let a = UInt16(px[i + 3])
            px[i] = UInt8(UInt16(px[i]) * a / 255)
            px[i + 1] = UInt8(UInt16(px[i + 1]) * a / 255)
            px[i + 2] = UInt8(UInt16(px[i + 2]) * a / 255)
        }
        guard let provider = CGDataProvider(data: Data(px) as CFData) else { return nil }
        return CGImage(width: img.width, height: img.height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: img.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
    }
}
