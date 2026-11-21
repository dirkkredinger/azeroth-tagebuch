// Baut CascLib (MIT, Ladislav Zezula) aus den Quellen in casclib/ – auf macOS, Windows und Linux.
fn main() {
    let root = std::path::Path::new("casclib");
    let mut files = Vec::new();
    for dir in ["", "common", "hashes", "jenkins", "overwatch"] {
        let d = root.join(dir);
        for e in std::fs::read_dir(&d).unwrap() {
            let p = e.unwrap().path();
            let name = p.file_name().unwrap().to_string_lossy().into_owned();
            let ext = p.extension().map(|x| x.to_string_lossy().into_owned()).unwrap_or_default();
            // cmf-key.cpp wird von cmf.cpp eingebunden
            if (ext == "cpp" || ext == "c") && name != "cmf-key.cpp" { files.push(p); }
        }
    }
    let mut b = cc::Build::new();
    b.cpp(true).std("c++17").warnings(false).define("CASC_USE_SYSTEM_ZLIB", None)
        // keine automatische Bibliotheksverknüpfung über #pragma (nur MSVC)
        .define("CASCLIB_NO_AUTO_LINK_LIBRARY", None);
    if let Ok(inc) = std::env::var("DEP_Z_INCLUDE") { b.include(inc); }
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows") {
        b.define("_CRT_SECURE_NO_WARNINGS", None);
        // CascLib nutzt Winsock für den (hier ungenutzten) CDN-Zugriff
        println!("cargo:rustc-link-lib=ws2_32");
    }
    // .c-Dateien (lookup3.c) getrennt als C übersetzen
    let (c_files, cpp_files): (Vec<_>, Vec<_>) = files.into_iter().partition(|p| p.extension().unwrap() == "c");
    b.files(&cpp_files).compile("casclib");
    let mut c = cc::Build::new();
    c.warnings(false).files(&c_files).compile("casclib_c");
    println!("cargo:rerun-if-changed=casclib");
}
