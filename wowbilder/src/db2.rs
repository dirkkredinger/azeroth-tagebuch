//! Minimaler Leser für WoW-Datenbanktabellen (WDC3/WDC4/WDC5).
//! Liefert je Datensatz die ID, die Werte der Spalten (`fields`) und den Fremdschlüssel (`relation`).

use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct Row {
    pub id: u32,
    pub fields: Vec<u32>,
    pub relation: Option<u32>,
}

struct FieldInfo { offset_bits: usize, size_bits: usize, additional: usize, storage: u32, v1: u32, v2: u32, v3: u32 }

pub fn read(b: &[u8]) -> Result<Vec<Row>, String> {
    let u8_ = |o: usize| *b.get(o).unwrap_or(&0) as u32;
    let u16_ = |o: usize| u8_(o) | (u8_(o + 1) << 8);
    let u32_ = |o: usize| u16_(o) | (u16_(o + 2) << 16);
    let u64_ = |o: usize| u32_(o) as u64 | ((u32_(o + 4) as u64) << 32);

    if b.len() < 204 { return Err("DB2 zu kurz".into()); }
    let mut o = match &b[0..4] {
        b"WDC5" => 4 + 4 + 128,
        b"WDC3" | b"WDC4" => 4,
        m => return Err(format!("unbekanntes DB2-Format {:?}", String::from_utf8_lossy(m))),
    };
    o += 4; // record_count (je Abschnitt erneut)
    let field_count = u32_(o) as usize; o += 4;
    let record_size = u32_(o) as usize; o += 4;
    o += 4 + 4 + 4 + 4 + 4 + 4; // string_table_size, table_hash, layout_hash, min_id, max_id, locale
    let flags = u16_(o); o += 2;
    let id_index = u16_(o) as usize; o += 2;
    let total_field_count = u32_(o) as usize; o += 4;
    o += 4 + 4; // bitpacked_data_offset, lookup_column_count
    let field_storage_info_size = u32_(o) as usize; o += 4;
    o += 4; // common_data_size (gemeinsame Werte folgen direkt auf die Palette)
    let pallet_data_size = u32_(o) as usize; o += 4;
    let section_count = u32_(o) as usize; o += 4;

    struct Section { tact_key: u64, file_offset: usize, record_count: usize, string_table_size: usize, id_list_size: usize, relationship_size: usize, offset_map_count: usize, copy_count: usize }
    let mut sections = Vec::new();
    for _ in 0..section_count {
        sections.push(Section {
            tact_key: u64_(o), file_offset: u32_(o + 8) as usize, record_count: u32_(o + 12) as usize,
            string_table_size: u32_(o + 16) as usize, id_list_size: u32_(o + 24) as usize,
            relationship_size: u32_(o + 28) as usize, offset_map_count: u32_(o + 32) as usize, copy_count: u32_(o + 36) as usize,
        });
        o += 40;
    }
    o += total_field_count * 4;
    let mut infos = Vec::new();
    for _ in 0..field_storage_info_size / 24 {
        infos.push(FieldInfo {
            offset_bits: u16_(o) as usize, size_bits: u16_(o + 2) as usize, additional: u32_(o + 4) as usize,
            storage: u32_(o + 8), v1: u32_(o + 12), v2: u32_(o + 16), v3: u32_(o + 20),
        });
        o += 24;
    }
    if infos.len() < field_count { return Err("DB2: Feldinfos fehlen".into()); }

    let mut pallet_offsets = vec![0usize; infos.len()];
    let mut p = o;
    for (i, f) in infos.iter().enumerate() {
        if f.storage == 3 || f.storage == 4 { pallet_offsets[i] = p; p += f.additional; }
    }
    o += pallet_data_size;
    let mut common: Vec<HashMap<u32, u32>> = vec![HashMap::new(); infos.len()];
    let mut c = o;
    for (i, f) in infos.iter().enumerate() {
        if f.storage == 2 {
            let mut k = c;
            while k + 8 <= c + f.additional { common[i].insert(u32_(k), u32_(k + 4)); k += 8; }
            c += f.additional;
        }
    }
    if flags & 1 != 0 { return Err("DB2 mit Offset-Map wird nicht unterstützt".into()); }

    let read_bits = |start: usize, bit_off: usize, count: usize| -> u32 {
        if count == 0 { return 0; }
        let first = start + bit_off / 8;
        let shift = bit_off % 8;
        let need = ((shift + count + 7) / 8).min(8);
        let mut v: u64 = 0;
        for k in 0..need { v |= (*b.get(first + k).unwrap_or(&0) as u64) << (8 * k); }
        v >>= shift;
        if count < 64 { v &= (1u64 << count) - 1; }
        v as u32
    };

    let mut rows = Vec::new();
    for s in &sections {
        if s.tact_key != 0 { continue; } // verschlüsselte Abschnitte (unveröffentlichte Inhalte)
        let rec_start = s.file_offset;
        let mut q = rec_start + s.record_count * record_size + s.string_table_size;
        let ids: Vec<u32> = (0..s.id_list_size / 4).map(|k| u32_(q + k * 4)).collect();
        q += s.id_list_size;
        let copies: Vec<(u32, u32)> = (0..s.copy_count).map(|k| (u32_(q + k * 8), u32_(q + k * 8 + 4))).collect();
        q += s.copy_count * 8;
        q += s.offset_map_count * 6;
        let mut relation: HashMap<usize, u32> = HashMap::new();
        if s.relationship_size > 0 {
            let n = u32_(q) as usize;
            for k in 0..n { let e = q + 12 + k * 8; relation.insert(u32_(e + 4) as usize, u32_(e)); }
        }
        let mut by_id: HashMap<u32, usize> = HashMap::new();
        for r in 0..s.record_count {
            let rs = rec_start + r * record_size;
            let mut values = Vec::with_capacity(field_count);
            for (i, f) in infos.iter().take(field_count).enumerate() {
                values.push(match f.storage {
                    0 => read_bits(rs, f.offset_bits, f.size_bits.min(32)),
                    1 | 5 => read_bits(rs, f.offset_bits, f.v2 as usize),
                    2 => f.v1,
                    3 => { let idx = read_bits(rs, f.offset_bits, f.v2 as usize) as usize; u32_(pallet_offsets[i] + idx * 4) }
                    4 => { let idx = read_bits(rs, f.offset_bits, f.v2 as usize) as usize; u32_(pallet_offsets[i] + idx * 4 * (f.v3.max(1) as usize)) }
                    _ => 0,
                });
            }
            let id = if r < ids.len() { ids[r] } else if id_index < values.len() { values[id_index] } else { r as u32 };
            for (i, f) in infos.iter().take(field_count).enumerate() {
                if f.storage == 2 { if let Some(v) = common[i].get(&id) { values[i] = *v; } }
            }
            by_id.insert(id, rows.len());
            rows.push(Row { id, fields: values, relation: relation.get(&r).copied() });
        }
        for (new_id, old_id) in copies {
            if let Some(&i) = by_id.get(&old_id) { let mut row = rows[i].clone(); row.id = new_id; rows.push(row); }
        }
    }
    Ok(rows)
}
