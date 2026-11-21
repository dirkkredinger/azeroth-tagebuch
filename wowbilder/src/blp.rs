//! Dekodiert BLP2-Texturen (Blizzards Bildformat) in RGBA. Palette, DXT1/3/5 und unkomprimiert.

use image::RgbaImage;

pub fn decode(b: &[u8]) -> Result<RgbaImage, String> {
    if b.len() <= 1172 || &b[0..4] != b"BLP2" { return Err("kein BLP2".into()); }
    let u32_ = |o: usize| u32::from_le_bytes([b[o], b[o + 1], b[o + 2], b[o + 3]]) as usize;
    let (encoding, alpha_depth, alpha_type) = (b[8], b[9], b[10]);
    let (w, h) = (u32_(12), u32_(16));
    let (offset, size) = (u32_(20), u32_(84));
    if w == 0 || h == 0 || w > 8192 || h > 8192 || offset + size > b.len() { return Err("BLP-Kopf fehlerhaft".into()); }
    let src = &b[offset..offset + size];
    let mut out = vec![0u8; w * h * 4];

    match encoding {
        1 => {
            // Palette (ab Byte 148), Alpha folgt den Indizes
            let n = w * h;
            for i in 0..n.min(src.len()) {
                let c = 148 + src[i] as usize * 4;
                out[i * 4] = b[c + 2];
                out[i * 4 + 1] = b[c + 1];
                out[i * 4 + 2] = b[c];
                out[i * 4 + 3] = match alpha_depth {
                    8 => *src.get(n + i).unwrap_or(&255),
                    4 => src.get(n + i / 2).map(|v| ((v >> ((i % 2) * 4)) & 0x0F) * 17).unwrap_or(255),
                    1 => src.get(n + i / 8).map(|v| if (v >> (i % 8)) & 1 == 1 { 255 } else { 0 }).unwrap_or(255),
                    _ => 255,
                };
            }
        }
        2 => {
            // DXT: alphaType 0 = DXT1, 1 = DXT3, 7 = DXT5
            let kind = match alpha_type { 7 => 5, 1 => 3, _ => 1 };
            let block = if kind == 1 { 8 } else { 16 };
            let (bw, bh) = ((w + 3) / 4, (h + 3) / 4);
            for by in 0..bh {
                for bx in 0..bw {
                    let o = (by * bw + bx) * block;
                    if o + block > src.len() { continue; }
                    let px = decode_block(&src[o..o + block], kind, alpha_depth > 0);
                    for (i, p) in px.iter().enumerate() {
                        let (x, y) = (bx * 4 + i % 4, by * 4 + i / 4);
                        if x < w && y < h { out[(y * w + x) * 4..(y * w + x) * 4 + 4].copy_from_slice(p); }
                    }
                }
            }
        }
        3 => {
            for i in 0..(w * h) {
                if i * 4 + 3 >= src.len() { break; }
                out[i * 4] = src[i * 4 + 2];
                out[i * 4 + 1] = src[i * 4 + 1];
                out[i * 4 + 2] = src[i * 4];
                out[i * 4 + 3] = src[i * 4 + 3];
            }
        }
        e => return Err(format!("BLP-Kodierung {e} unbekannt")),
    }
    RgbaImage::from_raw(w as u32, h as u32, out).ok_or_else(|| "BLP: Puffergröße".into())
}

fn rgb565(v: u16) -> [i32; 3] {
    let (r, g, b) = (((v >> 11) & 0x1F) as i32, ((v >> 5) & 0x3F) as i32, (v & 0x1F) as i32);
    [(r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2)]
}

fn decode_block(s: &[u8], kind: u8, dxt1_alpha: bool) -> [[u8; 4]; 16] {
    let mut alphas = [255u8; 16];
    let mut co = 0;
    if kind == 3 {
        for i in 0..16 { let byte = s[i / 2]; alphas[i] = (if i % 2 == 0 { byte & 0x0F } else { byte >> 4 }) * 17; }
        co = 8;
    } else if kind == 5 {
        let (a0, a1) = (s[0] as i32, s[1] as i32);
        let mut t = [0i32; 8];
        t[0] = a0; t[1] = a1;
        if a0 > a1 { for k in 1..=6 { t[k + 1] = ((7 - k as i32) * a0 + k as i32 * a1) / 7; } }
        else { for k in 1..=4 { t[k + 1] = ((5 - k as i32) * a0 + k as i32 * a1) / 5; } t[6] = 0; t[7] = 255; }
        let mut bits: u64 = 0;
        for k in 0..6 { bits |= (s[2 + k] as u64) << (8 * k); }
        for i in 0..16 { alphas[i] = t[((bits >> (3 * i)) & 7) as usize] as u8; }
        co = 8;
    }
    let c0 = u16::from_le_bytes([s[co], s[co + 1]]);
    let c1 = u16::from_le_bytes([s[co + 2], s[co + 3]]);
    let (a, b) = (rgb565(c0), rgb565(c1));
    let mut colors = [[0i32; 4]; 4];
    colors[0] = [a[0], a[1], a[2], 255];
    colors[1] = [b[0], b[1], b[2], 255];
    if kind != 1 || c0 > c1 {
        colors[2] = [(2 * a[0] + b[0]) / 3, (2 * a[1] + b[1]) / 3, (2 * a[2] + b[2]) / 3, 255];
        colors[3] = [(a[0] + 2 * b[0]) / 3, (a[1] + 2 * b[1]) / 3, (a[2] + 2 * b[2]) / 3, 255];
    } else {
        colors[2] = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, 255];
        colors[3] = [0, 0, 0, if dxt1_alpha { 0 } else { 255 }];
    }
    let idx = u32::from_le_bytes([s[co + 4], s[co + 5], s[co + 6], s[co + 7]]);
    let mut out = [[0u8; 4]; 16];
    for i in 0..16 {
        let c = colors[((idx >> (2 * i)) & 3) as usize];
        out[i] = [c[0] as u8, c[1] as u8, c[2] as u8, if kind == 1 { c[3] as u8 } else { alphas[i] }];
    }
    out
}
