//! Schreibt die Beispieldaten als JSON (für die Browser-Vorschau der Oberfläche):
//! cargo run --example demo_json > ../app/static/demo.json
//! cargo run --example demo_json en > ../app/static/demo-en.json
fn main() {
    let lang = std::env::args().nth(1).unwrap_or_else(|| "de".into());
    let a = tagebuch_kern::demo_archive_lang(&lang);
    // Positionsproben bleiben drin: die Browser-Vorschau trennt sie selbst ab
    println!("{}", serde_json::to_string(&a).unwrap());
}
