import SwiftData
import SwiftUI

/// Entscheidet, was das Fenster zeigt: Sperrbildschirm, Ersteinrichtung oder die App.
struct WurzelView: View {
    @Environment(\.modelContext) private var kontext
    @Query private var einstellungenListe: [AppEinstellungen]

    @State private var entsperrt = false
    @State private var sperrePruefung = true

    private var einstellungen: AppEinstellungen? { einstellungenListe.first }

    var body: some View {
        Group {
            if sperrePruefung {
                ProgressView()
                    .frame(minWidth: 480, minHeight: 320)
            } else if !entsperrt {
                SperrbildschirmView(entsperrt: $entsperrt)
            } else if einstellungen?.ersteinrichtungAbgeschlossen == true {
                HauptfensterView()
                    .task {
                        guard einstellungen?.aktualisierungenPruefen == true else { return }
                        await Aktualisierungspruefer.shared.pruefe(erzwungen: false)
                    }
            } else {
                WillkommenView()
            }
        }
        .task {
            // Der Einstellungsdatensatz muss existieren, bevor irgendetwas anderes greift.
            let gespeicherte = (try? kontext.einstellungen()) ?? AppEinstellungen()
            if gespeicherte.sperreAktiv {
                entsperrt = await AppSperre.entsperren()
            } else {
                entsperrt = true
            }
            sperrePruefung = false
        }
    }
}
