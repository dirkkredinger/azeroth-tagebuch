// cargo run --release --example test -- <ausgabeordner>
fn main() {
    let out = std::path::PathBuf::from(std::env::args().nth(1).expect("Ausgabeordner"));
    std::fs::create_dir_all(&out).unwrap();
    let t = std::time::Instant::now();
    let mut w = wowbilder::WowBilder::open(std::path::Path::new("/Applications/World of Warcraft")).unwrap();
    for id in [63u32, 2395, 1] {
        let t1 = std::time::Instant::now();
        match w.map(id).unwrap() {
            Some(img) => { std::fs::write(out.join(format!("k{id}.jpg")), wowbilder::to_jpeg(&img, 900, 85).unwrap()).unwrap(); println!("Karte {id}: {}x{} in {:?}", img.width(), img.height(), t1.elapsed()); }
            None => println!("Karte {id}: keine"),
        }
    }
    let icon = w.icon(133071).unwrap();
    std::fs::write(out.join("helm.png"), wowbilder::to_png(&icon).unwrap()).unwrap();
    println!("Symbol {}x{}, gesamt {:?}", icon.width(), icon.height(), t.elapsed());
}
