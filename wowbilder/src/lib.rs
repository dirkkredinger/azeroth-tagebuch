//! Kartenbilder und Gegenstandssymbole aus der lokalen WoW-Installation.
//!
//! Die App liefert keine Blizzard-Grafiken mit: Jedes Bild entsteht erst beim Nutzer aus dessen
//! eigener Installation und wird nur in seinem App-Ordner zwischengespeichert.

extern crate libz_sys; // stellt zlib für CascLib bereit

pub mod blp;
pub mod casc;
pub mod db2;

use image::{imageops, RgbaImage};
use std::collections::HashMap;
use std::io::Cursor;
use std::path::Path;

/// FileDataIDs der Kartentabellen (stabil über alle Spielversionen)
mod fdid {
    pub const UI_MAP_ART: u32 = 1957202;
    pub const UI_MAP_ART_STYLE_LAYER: u32 = 1957208;
    pub const UI_MAP_ART_TILE: u32 = 1957210;
    pub const UI_MAP_X_MAP_ART: u32 = 1957217;
    pub const WORLD_MAP_OVERLAY: u32 = 1134579;
    pub const WORLD_MAP_OVERLAY_TILE: u32 = 1957212;
}

#[derive(Clone, Copy)]
struct Layer { width: u32, height: u32, tile_w: u32, tile_h: u32 }
#[derive(Clone, Copy)]
struct Tile { row: u32, col: u32, fdid: u32 }
#[derive(Clone, Copy)]
struct Overlay { id: u32, width: u32, height: u32, x: i64, y: i64 }

/// Zugriff auf das CASC-Archiv mit (bei Bedarf geladenen) Kartentabellen
pub struct WowBilder {
    storage: casc::Storage,
    maps: Option<MapTables>,
}

struct MapTables {
    arts_for_map: HashMap<u32, Vec<u32>>,
    style_for_art: HashMap<u32, u32>,
    layer_for_style: HashMap<u32, Layer>,
    tiles_for_art: HashMap<u32, Vec<Tile>>,
    overlays_for_art: HashMap<u32, Vec<Overlay>>,
    tiles_for_overlay: HashMap<u32, Vec<Tile>>,
}

impl WowBilder {
    /// `game_folder`: Ordner mit `Data/` (Elternordner von `_retail_`)
    pub fn open(game_folder: &Path) -> Result<WowBilder, String> {
        Ok(WowBilder { storage: casc::Storage::open(game_folder).map_err(|e| e.to_string())?, maps: None })
    }

    /// Gegenstandssymbol (FileDataID) als RGBA-Bild
    pub fn icon(&self, fdid: u32) -> Result<RgbaImage, String> {
        blp::decode(&self.storage.read(fdid).map_err(|e| e.to_string())?)
    }

    fn tables(&mut self) -> Result<&MapTables, String> {
        if self.maps.is_none() {
            let rd = |id: u32| -> Result<Vec<db2::Row>, String> { db2::read(&self.storage.read(id).map_err(|e| e.to_string())?) };
            let mut t = MapTables {
                arts_for_map: HashMap::new(), style_for_art: HashMap::new(), layer_for_style: HashMap::new(),
                tiles_for_art: HashMap::new(), overlays_for_art: HashMap::new(), tiles_for_overlay: HashMap::new(),
            };
            // UiMapXMapArt: Felder PhaseID, UiMapArtID; Beziehung UiMapID
            let mut tmp: HashMap<u32, Vec<(u32, u32)>> = HashMap::new();
            for r in rd(fdid::UI_MAP_X_MAP_ART)? {
                if let (Some(map), true) = (r.relation, r.fields.len() >= 2) { tmp.entry(map).or_default().push((r.fields[0], r.fields[1])); }
            }
            for (map, mut v) in tmp {
                v.sort_by_key(|(phase, _)| (*phase != 0) as u8); // Phase 0 zuerst
                t.arts_for_map.insert(map, v.into_iter().map(|(_, a)| a).collect());
            }
            // UiMapArt: HighlightFileDataID, HighlightAtlasID, UiMapArtStyleID
            for r in rd(fdid::UI_MAP_ART)? { if r.fields.len() >= 3 { t.style_for_art.insert(r.id, r.fields[2]); } }
            // UiMapArtStyleLayer: LayerIndex, LayerWidth, LayerHeight, TileWidth, TileHeight, …; Beziehung Style
            for r in rd(fdid::UI_MAP_ART_STYLE_LAYER)? {
                if r.fields.len() >= 5 && r.fields[0] == 0 {
                    if let Some(style) = r.relation {
                        t.layer_for_style.insert(style, Layer { width: r.fields[1], height: r.fields[2], tile_w: r.fields[3].max(1), tile_h: r.fields[4].max(1) });
                    }
                }
            }
            // UiMapArtTile: RowIndex, ColIndex, LayerIndex, FileDataID; Beziehung UiMapArtID
            for r in rd(fdid::UI_MAP_ART_TILE)? {
                if r.fields.len() >= 4 && r.fields[2] == 0 {
                    if let Some(art) = r.relation { t.tiles_for_art.entry(art).or_default().push(Tile { row: r.fields[0], col: r.fields[1], fdid: r.fields[3] }); }
                }
            }
            // Erkundungs-Overlays (ältere Zonen haben ihr Gelände dort): ID, UiMapArtID, W, H, X, Y, Hit×4, PlayerConditionID, …
            if let Ok(rows) = rd(fdid::WORLD_MAP_OVERLAY) {
                for r in rows {
                    if r.fields.len() >= 11 && r.fields[10] == 0 {
                        t.overlays_for_art.entry(r.fields[1]).or_default().push(Overlay {
                            id: r.id, width: r.fields[2], height: r.fields[3], x: r.fields[4] as i32 as i64, y: r.fields[5] as i32 as i64,
                        });
                    }
                }
            }
            if let Ok(rows) = rd(fdid::WORLD_MAP_OVERLAY_TILE) {
                for r in rows {
                    if r.fields.len() >= 4 && r.fields[2] == 0 {
                        if let Some(ov) = r.relation { t.tiles_for_overlay.entry(ov).or_default().push(Tile { row: r.fields[0], col: r.fields[1], fdid: r.fields[3] }); }
                    }
                }
            }
            self.maps = Some(t);
        }
        Ok(self.maps.as_ref().unwrap())
    }

    /// Setzt das Kartenbild einer Zone (uiMapID) „voll erkundet“ zusammen; None, wenn es keins gibt.
    pub fn map(&mut self, map_id: u32) -> Result<Option<RgbaImage>, String> {
        let t = self.tables()?;
        let Some(arts) = t.arts_for_map.get(&map_id).cloned() else { return Ok(None) };
        let t = self.maps.as_ref().unwrap();
        for art in arts {
            let (Some(style), Some(tiles)) = (t.style_for_art.get(&art), t.tiles_for_art.get(&art)) else { continue };
            let Some(layer) = t.layer_for_style.get(style).copied() else { continue };
            if layer.width == 0 || layer.height == 0 || tiles.is_empty() { continue; }
            let mut canvas = RgbaImage::new(layer.width, layer.height);
            let mut drawn = 0;
            for tile in tiles {
                let Ok(img) = self.storage.read(tile.fdid).map_err(|e| e.to_string()).and_then(|d| blp::decode(&d)) else { continue };
                imageops::overlay(&mut canvas, &img, (tile.col * layer.tile_w) as i64, (tile.row * layer.tile_h) as i64);
                drawn += 1;
            }
            if drawn == 0 { continue; }
            for ov in t.overlays_for_art.get(&art).cloned().unwrap_or_default() {
                for tile in t.tiles_for_overlay.get(&ov.id).cloned().unwrap_or_default() {
                    let Ok(img) = self.storage.read(tile.fdid).map_err(|e| e.to_string()).and_then(|d| blp::decode(&d)) else { continue };
                    // Kacheln eines Overlays sind 256 px groß; Ränder auf die Overlay-Größe beschneiden
                    let w = img.width().min(ov.width.saturating_sub(tile.col * 256));
                    let h = img.height().min(ov.height.saturating_sub(tile.row * 256));
                    if w == 0 || h == 0 { continue; }
                    let part = imageops::crop_imm(&img, 0, 0, w, h).to_image();
                    imageops::overlay(&mut canvas, &part, ov.x + (tile.col * 256) as i64, ov.y + (tile.row * 256) as i64);
                }
            }
            return Ok(Some(canvas));
        }
        Ok(None)
    }
}

/// Verkleinert (falls breiter als `max_width`) und kodiert als JPEG
pub fn to_jpeg(img: &RgbaImage, max_width: u32, quality: u8) -> Result<Vec<u8>, String> {
    let scaled = if img.width() > max_width {
        let h = (img.height() as f64 * max_width as f64 / img.width() as f64).round() as u32;
        imageops::resize(img, max_width, h, imageops::FilterType::Triangle)
    } else {
        img.clone()
    };
    let rgb = image::DynamicImage::ImageRgba8(scaled).to_rgb8();
    let mut out = Vec::new();
    image::codecs::jpeg::JpegEncoder::new_with_quality(&mut out, quality).encode_image(&rgb).map_err(|e| e.to_string())?;
    Ok(out)
}

pub fn to_png(img: &RgbaImage) -> Result<Vec<u8>, String> {
    let mut out = Cursor::new(Vec::new());
    img.write_to(&mut out, image::ImageFormat::Png).map_err(|e| e.to_string())?;
    Ok(out.into_inner())
}

/// Ordner mit `Data/` zu einem `_retail_`-Ordner
pub fn game_folder_for(retail: &Path) -> std::path::PathBuf {
    retail.parent().map(|p| p.to_path_buf()).unwrap_or_else(|| retail.to_path_buf())
}
