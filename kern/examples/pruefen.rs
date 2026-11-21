//! Liest die echte WoW-Installation ein und gibt eine Übersicht aus:
//! cargo run --example pruefen [Pfad zu _retail_]
use tagebuch_kern::*;

fn main() {
    let wow = std::env::args().nth(1).map(std::path::PathBuf::from).unwrap_or_else(guess_wow_folder);
    println!("WoW-Ordner: {}", wow.display());
    let mut a = Archive::default();
    for (acc, file) in find_saved_variables(&wow) {
        let data = std::fs::read(&file).unwrap();
        match ingest::ingest_saved_variables(&data, Some(&acc), &mut a) {
            Ok(n) => println!("{acc}: {n} Einträge"),
            Err(e) => println!("{acc}: FEHLER {e}"),
        }
    }
    let mut offsets = Default::default();
    let up = LogReader::new().poll(&wow.join("Logs"), &mut offsets, f64::MAX);
    let n = ingest::merge_fights(up.fights, &mut a);
    println!("Kampflog: {} Bytes, {n} Kämpfe", up.bytes_read);
    for (k, c) in &a.characters {
        println!("  {k}: Stufe {:?}, {} Einträge, GS {:?}, Ausrüstung {} Plätze, Taschen {}, Bank {}, Kämpfe {}",
            c.level, c.events.len(), c.item_level, c.gear.len(),
            c.bags.as_ref().map(|b| b.tabs.iter().map(|t| t.items.len()).sum::<usize>()).unwrap_or(0),
            c.bank.as_ref().map(|b| b.tabs.iter().map(|t| t.items.len()).sum::<usize>()).unwrap_or(0),
            a.fights.get(k).map(|f| f.len()).unwrap_or(0));
    }
    println!("Kriegsmeute: {:?}, Gilden: {:?}", a.warbands.keys().collect::<Vec<_>>(), a.guilds.keys().collect::<Vec<_>>());
    let beute: usize = a.characters.values().map(|c| c.events.iter().filter(|e| e.e == "beute").count()).sum();
    println!("Beute-Einträge: {beute}");
}
