import SwiftData
import SwiftUI

/// Sicherung schreiben und wieder einspielen.
struct SicherungEinstellungenView: View {
    @Environment(\.modelContext) private var kontext
    @Query private var einstellungenListe: [AppEinstellungen]

    @State private var exportPasswort = ""
    @State private var mitPasswort = false
    @State private var dokument: SicherungsDokument?
    @State private var exportZeigen = false
    @State private var importZeigen = false
    @State private var sicherung = SicherungsImport()
    @State private var modus: BackupService.Importmodus = .zusammenfuehren
    @State private var meldung: String?
    @State private var exportFehler: String?

    var body: some View {
        Form {
            Section("Sicherung erstellen") {
                Toggle("Mit Passwort verschlüsseln", isOn: $mitPasswort)
                if mitPasswort {
                    SecureField("Passwort", text: $exportPasswort)
                    Text("Ohne dieses Passwort lässt sich die Datei nicht wiederherstellen – es gibt keine Hintertür.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Sicherung sichern …") { bereiteExportVor() }
                        .disabled(mitPasswort && exportPasswort.isEmpty)
                    Spacer()
                    if let letztes = einstellungenListe.first?.letztesBackup {
                        Text("Zuletzt: \(letztes.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Noch nie gesichert")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                if let exportFehler {
                    Text(exportFehler).font(.callout).foregroundStyle(.red)
                }
            }

            Section("Sicherung einspielen") {
                Button("Sicherungsdatei wählen …") { importZeigen = true }

                if let vorschau = sicherung.vorschau {
                    let zaehler = vorschau.zaehler
                    LabeledContent("Erstellt am",
                                   value: vorschau.exportiertAm.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Inhalt", value: inhalt(zaehler))
                    if vorschau.verschluesselt {
                        SecureField("Passwort der Sicherung", text: $sicherung.passwort)
                    }
                    Picker("Vorgehen", selection: $modus) {
                        Text("Zusammenführen").tag(BackupService.Importmodus.zusammenfuehren)
                        Text("Alles ersetzen").tag(BackupService.Importmodus.ersetzen)
                    }
                    .pickerStyle(.radioGroup)
                    Text(modus == .ersetzen
                        ? "Der aktuelle Bestand wird vollständig gelöscht und durch die Sicherung ersetzt."
                        : "Vorhandenes bleibt erhalten; gleiche Einträge werden aktualisiert.")
                    .font(.caption)
                    .foregroundStyle(modus == .ersetzen ? .orange : .secondary)

                    Button("Einspielen") { spieleEin() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!sicherung.bereit)
                }

                if let fehler = sicherung.fehler {
                    Text(fehler).font(.callout).foregroundStyle(.red)
                }
                if let meldung {
                    Label(meldung, systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.green)
                }
            }

            Section {
                Text("Eine Sicherung ist eine einzelne, lesbare JSON-Datei. Sie enthält Klassen, Kinder, Kompetenzraster, Skalen und alle Einträge.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .fileExporter(
            isPresented: $exportZeigen,
            document: dokument,
            contentType: .kompetenzSicherung,
            defaultFilename: Sicherungsname.vorschlag
        ) { ergebnis in
            if case .success = ergebnis {
                einstellungenListe.first?.letztesBackup = Date()
                try? kontext.save()
                meldung = "Sicherung geschrieben."
            }
        }
        .fileImporter(
            isPresented: $importZeigen,
            allowedContentTypes: [.kompetenzSicherung, .json]
        ) { ergebnis in
            meldung = nil
            if case .success(let url) = ergebnis { sicherung.lade(von: url) }
        }
    }

    /// Mitarbeitsstunden stehen erst in Sicherungen ab Format 2.
    private func inhalt(_ zaehler: BackupZaehler) -> String {
        var teile = [
            "\(zaehler.klassen) Klassen",
            "\(zaehler.schueler) Kinder",
            "\(zaehler.eintraege) Einträge",
        ]
        if let stunden = zaehler.mitarbeitsstunden, stunden > 0 {
            teile.append("\(stunden) Mitarbeitsstunden")
        }
        return teile.joined(separator: " · ")
    }

    private func bereiteExportVor() {
        exportFehler = nil
        do {
            let daten = try BackupService.export(
                aus: kontext,
                passwort: mitPasswort ? exportPasswort : nil
            )
            dokument = SicherungsDokument(inhalt: daten)
            exportZeigen = true
        } catch {
            exportFehler = error.localizedDescription
        }
    }

    private func spieleEin() {
        guard sicherung.fuehreAus(modus: modus, in: kontext) else { return }
        sicherung.vorschau = nil
        sicherung.rohdaten = nil
        sicherung.passwort = ""
        meldung = "Sicherung eingespielt."
    }
}
