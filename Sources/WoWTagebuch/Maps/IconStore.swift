import Foundation
import SwiftUI
import Observation
import ImageIO
import UniformTypeIdentifiers

/// Gegenstandssymbole (BLP) aus der lokalen WoW-Installation, im App-Ordner zwischengespeichert.
/// Wie bei den Karten liefert die App selbst keine Blizzard-Grafik mit.
@Observable
final class IconStore {
    private(set) var images: [Int: CGImage] = [:]
    @ObservationIgnored private var requested = Set<Int>()
    @ObservationIgnored private let queue = DispatchQueue(label: "WoWTagebuch.Symbole", qos: .utility)
    @ObservationIgnored private var storage: CascStorage?
    @ObservationIgnored private var storageFailed = false
    @ObservationIgnored var gameFolder: URL {
        didSet { queue.async { self.storage = nil; self.storageFailed = false } }
    }

    static var cacheFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WoWTagebuch/Symbole/v1", isDirectory: true)
    }

    init(gameFolder: URL) { self.gameFolder = gameFolder }

    func image(_ fileDataID: Int?) -> CGImage? {
        guard let id = fileDataID, id > 0 else { return nil }
        if let img = images[id] { return img }
        request(id)
        return nil
    }

    private func request(_ id: Int) {
        guard !requested.contains(id) else { return }
        requested.insert(id)
        let folder = gameFolder
        // Anfrage kommt oft mitten im Zeichnen der Ansicht – Ergebnis daher asynchron setzen
        queue.async {
            guard let img = self.load(id, gameFolder: folder) else { return }
            DispatchQueue.main.async { self.images[id] = img }
        }
    }

    private func load(_ id: Int, gameFolder: URL) -> CGImage? {
        let file = Self.cacheFolder.appendingPathComponent("\(id).png")
        if let src = CGImageSourceCreateWithURL(file as CFURL, nil),
           let img = CGImageSourceCreateImageAtIndex(src, 0, nil) { return img }
        if storage == nil && !storageFailed {
            storage = try? CascStorage(gameFolder: gameFolder)
            storageFailed = storage == nil
        }
        guard let storage, let data = try? storage.read(fileDataID: UInt32(id)),
              let blp = try? BLPDecoder.decode(data), let img = MapArtExtractor.cgImage(blp) else { return nil }
        try? FileManager.default.createDirectory(at: Self.cacheFolder, withIntermediateDirectories: true)
        if let dest = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil) {
            CGImageDestinationAddImage(dest, img, nil)
            CGImageDestinationFinalize(dest)
        }
        return img
    }
}

/// Symbol eines Gegenstands mit Rahmen in Qualitätsfarbe
struct ItemIcon: View {
    let icon: Int?
    var quality: Int?
    var size: CGFloat = 36
    @Environment(DataStore.self) private var store

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.6))
            if let img = store.icons.image(icon) {
                Image(decorative: img, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(2)
            } else {
                Image(systemName: "shippingbox").foregroundStyle(Theme.goldDim)
            }
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(WowStyle.qualityColor(quality).opacity(0.9), lineWidth: 1.5)
        }
        .frame(width: size, height: size)
    }
}
