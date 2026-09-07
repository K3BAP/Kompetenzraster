import SwiftData
import SwiftUI

@main
struct KompetenzrasterApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try Datenbestand.container()
        } catch {
            fatalError("Datenbank konnte nicht geöffnet werden: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            WurzelView()
        }
        .modelContainer(container)
        .defaultSize(width: 1320, height: 860)
        .commands {
            // Ein neues Fenster würde denselben Bestand doppelt zeigen.
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Nach Aktualisierungen suchen …") {
                    Task { await Aktualisierungspruefer.shared.pruefe(erzwungen: true) }
                }
            }
        }

        Settings {
            EinstellungenView()
                .modelContainer(container)
        }
    }
}
