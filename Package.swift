// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WoWTagebuch",
    defaultLocalization: "de",
    platforms: [.macOS(.v14)],
    targets: [
        // CascLib (MIT, Ladislav Zezula): liest das lokale Datenarchiv der WoW-Installation.
        // Damit erzeugt die App die Kartenbilder beim Nutzer selbst – mitgeliefert wird keine Blizzard-Grafik.
        .target(
            name: "CCascLib",
            path: "Sources/CCascLib",
            exclude: ["LICENSE-CascLib", "VERSION.txt", "src/overwatch/cmf-key.cpp", "src/overwatch/update-from-tactlib.py"],
            sources: ["src"],
            publicHeadersPath: "include",
            cSettings: [.define("CASC_USE_SYSTEM_ZLIB"), .unsafeFlags(["-w"])],
            cxxSettings: [.define("CASC_USE_SYSTEM_ZLIB"), .unsafeFlags(["-w"])],
            linkerSettings: [.linkedLibrary("z")]
        ),
        .executableTarget(
            name: "WoWTagebuch",
            dependencies: ["CCascLib"],
            path: "Sources/WoWTagebuch",
            resources: [.copy("Resources/Beispiel.lua"), .copy("Resources/BeispielKampflog.txt")]
        )
    ],
    cxxLanguageStandard: .cxx17
)
