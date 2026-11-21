import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Nötig, weil die App als Swift-Paket ohne eigenes App-Bundle startet
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct WoWTagebuchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = DataStore()

    var body: some Scene {
        WindowGroup("Azeroth-Tagebuch") {
            ContentView()
                .environment(store)
                .frame(minWidth: 1050, minHeight: 680)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Neu einlesen") { store.reload() }
                    .keyboardShortcut("r")
                Button("Beispieldaten anzeigen") { store.loadDemo() }
            }
        }
    }
}
