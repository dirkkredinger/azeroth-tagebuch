//! Schreibt die Beispieldaten als JSON (für die Browser-Vorschau der Oberfläche):
//! cargo run --example demo_json > ../app/static/demo.json
fn main() {
    let mut a = tagebuch_kern::demo_archive();
    // Positionsproben bleiben drin: die Browser-Vorschau trennt sie selbst ab
    println!("{}", serde_json::to_string(&a).unwrap());
}
