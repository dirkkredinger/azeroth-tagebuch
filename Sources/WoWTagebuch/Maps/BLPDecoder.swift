import Foundation
import CoreGraphics

/// Dekodiert BLP2-Texturen (Blizzards Bildformat) in RGBA-Pixel. Unterstützt Palette, DXT1/3/5 und unkomprimiert.
enum BLPDecoder {
    struct Image {
        var width: Int
        var height: Int
        var rgba: [UInt8]      // width * height * 4, nicht vormultipliziert
    }

    enum Failure: LocalizedError {
        case format(String)
        var errorDescription: String? {
            if case .format(let s) = self { return "BLP-Bild nicht lesbar: \(s)" }
            return nil
        }
    }

    static func decode(_ data: Data) throws -> Image {
        let b = [UInt8](data)
        guard b.count > 1172, String(decoding: b[0..<4], as: UTF8.self) == "BLP2" else { throw Failure.format("kein BLP2") }
        func u32(_ o: Int) -> Int { Int(b[o]) | Int(b[o + 1]) << 8 | Int(b[o + 2]) << 16 | Int(b[o + 3]) << 24 }
        let encoding = b[8], alphaDepth = b[9], alphaType = b[10]
        let w = u32(12), h = u32(16)
        let offset = u32(20), size = u32(84)
        guard w > 0, h > 0, w <= 8192, h <= 8192, offset + size <= b.count else { throw Failure.format("Kopf fehlerhaft") }
        let src = Array(b[offset..<(offset + size)])
        var out = [UInt8](repeating: 0, count: w * h * 4)

        switch encoding {
        case 1: // Palette
            let pal = 148
            for i in 0..<(w * h) where i < src.count {
                let c = pal + Int(src[i]) * 4
                out[i * 4] = b[c + 2]; out[i * 4 + 1] = b[c + 1]; out[i * 4 + 2] = b[c]
                out[i * 4 + 3] = paletteAlpha(src, index: i, count: w * h, depth: alphaDepth)
            }
        case 2: // DXT
            // alphaType: 0 = DXT1, 1 = DXT3, 7 = DXT5
            let kind: Int = alphaType == 7 ? 5 : (alphaType == 1 ? 3 : 1)
            let blockSize = kind == 1 ? 8 : 16
            let bw = (w + 3) / 4, bh = (h + 3) / 4
            for by in 0..<bh {
                for bx in 0..<bw {
                    let o = (by * bw + bx) * blockSize
                    guard o + blockSize <= src.count else { continue }
                    decodeBlock(src, o, kind: kind, dxt1Alpha: alphaDepth > 0) { px, py, r, g, bb, a in
                        let x = bx * 4 + px, y = by * 4 + py
                        guard x < w, y < h else { return }
                        let d = (y * w + x) * 4
                        out[d] = r; out[d + 1] = g; out[d + 2] = bb; out[d + 3] = a
                    }
                }
            }
        case 3: // BGRA
            for i in 0..<(w * h) where i * 4 + 3 < src.count {
                out[i * 4] = src[i * 4 + 2]; out[i * 4 + 1] = src[i * 4 + 1]
                out[i * 4 + 2] = src[i * 4]; out[i * 4 + 3] = src[i * 4 + 3]
            }
        default:
            throw Failure.format("Kodierung \(encoding) unbekannt")
        }
        return Image(width: w, height: h, rgba: out)
    }

    private static func paletteAlpha(_ src: [UInt8], index i: Int, count: Int, depth: UInt8) -> UInt8 {
        switch depth {
        case 8: return count + i < src.count ? src[count + i] : 255
        case 4:
            let k = count + i / 2
            guard k < src.count else { return 255 }
            let v = (src[k] >> UInt8((i % 2) * 4)) & 0x0F
            return v * 17
        case 1:
            let k = count + i / 8
            guard k < src.count else { return 255 }
            return (src[k] >> UInt8(i % 8)) & 1 == 1 ? 255 : 0
        default: return 255
        }
    }

    private static func rgb565(_ v: UInt16) -> (Int, Int, Int) {
        let r = Int((v >> 11) & 0x1F), g = Int((v >> 5) & 0x3F), b = Int(v & 0x1F)
        return ((r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2))
    }

    private static func decodeBlock(_ s: [UInt8], _ o: Int, kind: Int, dxt1Alpha: Bool,
                                    _ put: (Int, Int, UInt8, UInt8, UInt8, UInt8) -> Void) {
        var alphas = [UInt8](repeating: 255, count: 16)
        var co = o
        if kind == 3 {
            for i in 0..<16 {
                let byte = s[o + i / 2]
                let v = i % 2 == 0 ? byte & 0x0F : byte >> 4
                alphas[i] = v * 17
            }
            co = o + 8
        } else if kind == 5 {
            let a0 = Int(s[o]), a1 = Int(s[o + 1])
            var table = [Int](repeating: 0, count: 8)
            table[0] = a0; table[1] = a1
            if a0 > a1 {
                for k in 1...6 { table[k + 1] = ((7 - k) * a0 + k * a1) / 7 }
            } else {
                for k in 1...4 { table[k + 1] = ((5 - k) * a0 + k * a1) / 5 }
                table[6] = 0; table[7] = 255
            }
            var bits: UInt64 = 0
            for k in 0..<6 { bits |= UInt64(s[o + 2 + k]) << (8 * UInt64(k)) }
            for i in 0..<16 { alphas[i] = UInt8(table[Int((bits >> (3 * UInt64(i))) & 7)]) }
            co = o + 8
        }
        let c0 = UInt16(s[co]) | UInt16(s[co + 1]) << 8
        let c1 = UInt16(s[co + 2]) | UInt16(s[co + 3]) << 8
        let (r0, g0, b0) = rgb565(c0), (r1, g1, b1) = rgb565(c1)
        var colors: [(Int, Int, Int, Int)] = [(r0, g0, b0, 255), (r1, g1, b1, 255)]
        if kind != 1 || c0 > c1 {
            colors.append(((2 * r0 + r1) / 3, (2 * g0 + g1) / 3, (2 * b0 + b1) / 3, 255))
            colors.append(((r0 + 2 * r1) / 3, (g0 + 2 * g1) / 3, (b0 + 2 * b1) / 3, 255))
        } else {
            colors.append(((r0 + r1) / 2, (g0 + g1) / 2, (b0 + b1) / 2, 255))
            colors.append((0, 0, 0, dxt1Alpha ? 0 : 255))
        }
        let idx = UInt32(s[co + 4]) | UInt32(s[co + 5]) << 8 | UInt32(s[co + 6]) << 16 | UInt32(s[co + 7]) << 24
        for i in 0..<16 {
            let c = colors[Int((idx >> (2 * UInt32(i))) & 3)]
            let a = kind == 1 ? UInt8(c.3) : alphas[i]
            put(i % 4, i / 4, UInt8(c.0), UInt8(c.1), UInt8(c.2), a)
        }
    }
}
