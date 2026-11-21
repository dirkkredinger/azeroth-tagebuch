import Foundation
import AppKit
import Observation
import ImageIO
import UniformTypeIdentifiers

/// Hält die Kartenbilder bereit. Fehlt ein Bild, wird es im Hintergrund aus der
/// WoW-Installation des Nutzers erzeugt und im App-Ordner zwischengespeichert.
@Observable
final class MapArtStore {
    enum State: Equatable { case loading, ready, unavailable(String) }

    private(set) var images: [Int: CGImage] = [:]
    private(set) var states: [Int: State] = [:]

    @ObservationIgnored private let queue = DispatchQueue(label: "WoWTagebuch.Karten", qos: .utility)
    @ObservationIgnored private var extractor: MapArtExtractor?
    @ObservationIgnored private var extractorError: String?
    @ObservationIgnored var gameFolder: URL {
        didSet { queue.async { self.extractor = nil; self.extractorError = nil } }
    }

    /// Maximale Breite der gespeicherten Bilder (die Originale haben bis zu 3840 px)
    static let maxWidth = 2560

    static var cacheFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WoWTagebuch/Karten/v2", isDirectory: true)   // Version erhöhen, wenn sich das Erzeugen ändert
    }

    init(gameFolder: URL) {
        self.gameFolder = gameFolder
    }

    func state(_ mapID: Int) -> State? { states[mapID] }

    /// Sorgt dafür, dass das Bild dieser Karte (bald) verfügbar ist.
    func request(_ mapID: Int) {
        guard states[mapID] == nil else { return }
        states[mapID] = .loading
        let file = Self.cacheFolder.appendingPathComponent("\(mapID).jpg")
        let folder = gameFolder
        queue.async {
            let result = self.load(mapID: mapID, file: file, gameFolder: folder)
            DispatchQueue.main.async {
                switch result {
                case .success(let img):
                    self.images[mapID] = img
                    self.states[mapID] = .ready
                case .failure(let err):
                    self.states[mapID] = .unavailable(err.localizedDescription)
                }
            }
        }
    }

    func requestAll(_ ids: some Sequence<Int>) {
        for id in ids { request(id) }
    }

    private struct NoArt: LocalizedError {
        var errorDescription: String? { "Für diese Karte gibt es kein Kartenbild" }
    }

    private func load(mapID: Int, file: URL, gameFolder: URL) -> Result<CGImage, Error> {
        if let src = CGImageSourceCreateWithURL(file as CFURL, nil),
           let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
            return .success(img)
        }
        do {
            if extractor == nil {
                if let extractorError { throw NSError(domain: "Karten", code: 1, userInfo: [NSLocalizedDescriptionKey: extractorError]) }
                do { extractor = try MapArtExtractor(gameFolder: gameFolder) }
                catch { extractorError = error.localizedDescription; throw error }
            }
            guard let full = try extractor!.render(mapID: mapID) else { throw NoArt() }
            let img = Self.scaled(full, maxWidth: Self.maxWidth) ?? full
            try Self.writeJPEG(img, to: file)
            return .success(img)
        } catch {
            return .failure(error)
        }
    }

    static func scaled(_ img: CGImage, maxWidth: Int) -> CGImage? {
        guard img.width > maxWidth else { return img }
        let w = maxWidth, h = Int(Double(img.height) * Double(maxWidth) / Double(img.width))
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }

    static func writeJPEG(_ img: CGImage, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(dest, img, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
    }
}
