import SwiftData
import SwiftUI

/// Ersteinrichtung: Sicherung einspielen, mit Vorlagen starten oder leer beginnen.
struct WillkommenView: View {
    @Environment(\.modelContext) private var kontext

    private enum Weg { case keiner, importieren, vorlagen }

    @State private var weg: Weg = .keiner
    @State private var dateiwahl = false
    @State private var vorlagenAuswahl = false
    @State private var uebernommeneFaecher: Set<String> = []
    @State private var sicherung = SicherungsImport()

    var body: some View {
        VStack(spacing: 0) {
            kopf
            Divider()
            ScrollView {
                VStack(spacing: 14) {
                    karte(
                        symbol: "arrow.down.doc",
                        titel: "Sicherung einspielen",
                        text: "Du hast bereits mit Kompetenzraster gearbeitet? Übernimm deine Klassen, Raster und Einträge aus einer Sicherungsdatei.",
                        aktiv: weg == .importieren
                    ) {
                        weg = .importieren
                        dateiwahl = true
                    }

                    if weg == .importieren { importbereich }

                    karte(
                        symbol: "square.grid.3x3.fill",
                        titel: "Mit fertigen Kompetenzrastern starten",
                        text: "Deutsch, Mathematik und Sachunterricht nach den Teilrahmenplänen der Grundschule Rheinland-Pfalz.",
                        aktiv: weg == .vorlagen
                    ) {
                        weg = .vorlagen
                        vorlagenAuswahl = true
                    }

                    if weg == .vorlagen, !uebernommeneFaecher.isEmpty {
                        hinweisZeile(
                            symbol: "checkmark.circle.fill",
                            text: "Übernommen: \(uebernommeneFaecher.sorted().joined(separator: ", "))"
                        )
                    }

                    karte(
                        symbol: "square.dashed",
                        titel: "Leer beginnen",
                        text: "Du legst deine Kompetenzraster selbst an. Vorlagen kannst du später jederzeit ergänzen.",
                        aktiv: false
                    ) {
                        abschliessen()
                    }
                }
                .padding(20)
            }
            Divider()
            fuss
        }
        .frame(minWidth: 640, minHeight: 620)
        .fileImporter(
            isPresented: $dateiwahl,
            allowedContentTypes: [.kompetenzSicherung, .json]
        ) { ergebnis in
            if case .success(let url) = ergebnis { sicherung.lade(von: url) }
        }
        .sheet(isPresented: $vorlagenAuswahl) {
            VorlagenAuswahlView(mehrfachauswahl: true) { fach in
                uebernimm(fach: fach)
            }
        }
    }

    private var kopf: some View {
        VStack(spacing: 8) {
            PflanzenSymbol(stufe: .bluete, farbe: .accentColor)
                .frame(width: 60, height: 60)
            Text("Willkommen bei Kompetenzraster")
                .font(.largeTitle.weight(.semibold))
            Text("Lernfortschritte dokumentieren – vollständig auf diesem Mac, ohne Cloud und ohne Konto.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 26)
    }

    private var fuss: some View {
        HStack {
            Text("Alle Daten liegen ausschließlich auf diesem Gerät.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Fertig") { abschliessen() }
                .keyboardShortcut(.defaultAction)
                .disabled(weg == .importieren && sicherung.rohdaten != nil)
        }
        .padding(16)
    }

    // MARK: - Import

    @ViewBuilder
    private var importbereich: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let vorschau = sicherung.vorschau {
                let zaehler = vorschau.zaehler
                hinweisZeile(
                    symbol: "doc.text.magnifyingglass",
                    text: "\(zaehler.klassen) Klassen · \(zaehler.schueler) Kinder · \(zaehler.raster) Raster · \(zaehler.eintraege) Einträge"
                )
                if vorschau.verschluesselt {
                    SecureField("Passwort der Sicherung", text: $sicherung.passwort)
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Button("Andere Datei wählen …") { dateiwahl = true }
                    Spacer()
                    Button("Sicherung einspielen") { spieleEin() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!sicherung.bereit)
                }
            } else {
                Button("Sicherungsdatei wählen …") { dateiwahl = true }
            }

            if let fehler = sicherung.fehler {
                hinweisZeile(symbol: "exclamationmark.triangle.fill", text: fehler, warnung: true)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
    }

    private func spieleEin() {
        guard sicherung.fuehreAus(modus: .ersetzen, in: kontext) else { return }
        abschliessen()
    }

    private func uebernimm(fach: String) {
        guard let vorlage = try? VorlagenLader.datei(fach: fach) else { return }
        VorlagenLader.einfuegen(
            vorlage, in: kontext, skala: Skalenverwaltung.standardSkala(in: kontext)
        )
        try? kontext.save()
        uebernommeneFaecher.insert(fach)
    }

    private func abschliessen() {
        // Ohne Skala ließe sich später nichts bewerten.
        _ = Skalenverwaltung.standardSkala(in: kontext)
        let einstellungen = (try? kontext.einstellungen()) ?? AppEinstellungen()
        einstellungen.ersteinrichtungAbgeschlossen = true
        try? kontext.save()
    }

    // MARK: - Bausteine

    private func karte(
        symbol: String,
        titel: String,
        text: String,
        aktiv: Bool,
        aktion: @escaping () -> Void
    ) -> some View {
        Button(action: aktion) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: symbol)
                    .font(.title)
                    .foregroundStyle(.tint)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(titel).font(.headline)
                    Text(text)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(aktiv ? AnyShapeStyle(.tint.opacity(0.1)) : AnyShapeStyle(.quaternary.opacity(0.3)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(aktiv ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.clear), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func hinweisZeile(symbol: String, text: String, warnung: Bool = false) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .foregroundStyle(warnung ? AnyShapeStyle(.red) : AnyShapeStyle(.tint))
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
