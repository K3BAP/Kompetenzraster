import SwiftData
import SwiftUI

/// Zeigt, was ein Abgleich mit der mitgelieferten Vorlage ändern würde, und führt ihn aus.
struct VorlagenAbgleichView: View {
    @Bindable var raster: Kompetenzraster
    let vorlage: VorlagenDatei

    @Environment(\.modelContext) private var kontext
    @Environment(\.dismiss) private var schliessen

    @State private var vorschau: Vorlagenabgleich.Bericht?
    @State private var erledigt: Vorlagenabgleich.Bericht?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(erledigt == nil ? "Mit der Vorlage abgleichen" : "Abgleich abgeschlossen")
                .font(.title2.weight(.semibold))

            if let erledigt {
                rueckmeldung(erledigt)
            } else if let vorschau {
                if vorschau.istLeer {
                    hinweiszeile(
                        "checkmark.circle", .green,
                        "„\(raster.name)“ entspricht bereits der mitgelieferten Vorlage „\(vorlage.name)“."
                    )
                    if !vorschau.eigene.isEmpty {
                        Text("\(anzahl(vorschau.eigene.count, "eigene Kompetenz bleibt", "eigene Kompetenzen bleiben")) unberührt.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    einleitung
                    liste(vorschau)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }

            HStack {
                if erledigt == nil, vorschau?.istLeer == false {
                    Button("Abbrechen", role: .cancel) { schliessen() }
                    Spacer()
                    Button("Übernehmen") {
                        erledigt = Vorlagenabgleich.wendeAn(vorlage, auf: raster, in: kontext)
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Spacer()
                    Button("Fertig") { schliessen() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 560)
        .onAppear { vorschau = Vorlagenabgleich.bericht(fuer: raster, vorlage: vorlage) }
    }

    private var einleitung: some View {
        Text("Fehlende Kompetenzen werden ergänzt und Texte der Vorlage nachgezogen. Bewertungen bleiben erhalten; gelöscht wird nichts.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func liste(_ bericht: Vorlagenabgleich.Bericht) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                abschnitt("Neue Kompetenzen", symbol: "plus.circle", farbe: .green, posten: bericht.neue)
                abschnitt("Texte werden nachgezogen", symbol: "pencil.circle", farbe: .orange,
                          posten: bericht.geaenderte)
                abschnitt("Eigene Ergänzungen bleiben", symbol: "hand.raised", farbe: .secondary,
                          posten: bericht.eigene)
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: 300)

        if bericht.verdeckteBewertungen > 0 {
            hinweiszeile("exclamationmark.triangle", .orange, warnung(bericht))
        }
    }

    @ViewBuilder
    private func abschnitt(
        _ titel: String,
        symbol: String,
        farbe: Color,
        posten: [Vorlagenabgleich.Posten]
    ) -> some View {
        if !posten.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Label("\(titel) (\(posten.count))", systemImage: symbol)
                    .font(.headline)
                    .foregroundStyle(farbe)
                ForEach(posten.prefix(12)) { eintrag in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(eintrag.titel)
                            .font(.callout)
                            .lineLimit(2)
                        if !eintrag.pfad.isEmpty || !eintrag.felder.isEmpty {
                            Text(untertitel(eintrag))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if posten.count > 12 {
                    Text("… und \(posten.count - 12) weitere")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func untertitel(_ posten: Vorlagenabgleich.Posten) -> String {
        let felder = posten.felder.isEmpty ? "" : posten.felder.joined(separator: ", ")
        return [posten.pfad, felder].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func rueckmeldung(_ bericht: Vorlagenabgleich.Bericht) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            hinweiszeile("checkmark.circle", .green, zusammenfassung(bericht))
            if bericht.verdeckteBewertungen > 0 {
                Text(warnung(bericht))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Das Raster hat jetzt \(raster.kompetenzen.count) Kompetenzen, davon \(raster.blattKompetenzen.count) bewertbare.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func zusammenfassung(_ bericht: Vorlagenabgleich.Bericht) -> String {
        var teile: [String] = []
        if !bericht.neue.isEmpty {
            teile.append(anzahl(bericht.neue.count, "Kompetenz", "Kompetenzen") + " ergänzt")
        }
        if !bericht.geaenderte.isEmpty {
            teile.append(anzahl(bericht.geaenderte.count, "Text", "Texte") + " nachgezogen")
        }
        return teile.isEmpty ? "Es gab nichts anzugleichen." : teile.joined(separator: ", ") + "."
    }

    /// Bewertete Kompetenzen, die Unterkompetenzen bekommen, rutschen aus der Auswertung.
    private func warnung(_ bericht: Vorlagenabgleich.Bericht) -> String {
        let einzeln = bericht.verdeckteBewertungen == 1
        let betroffen = einzeln
            ? "Eine Bewertung hängt an einer Kompetenz"
            : "\(bericht.verdeckteBewertungen) Bewertungen hängen an Kompetenzen"
        let bleibt = einzeln ? "Sie bleibt gespeichert, zählt" : "Sie bleiben gespeichert, zählen"
        return "\(betroffen), die Unterkompetenzen bekommen. \(bleibt) aber nicht mehr in die "
            + "Auswertung – bewertet wird immer die unterste Ebene."
    }

    private func anzahl(_ wert: Int, _ einzahl: String, _ mehrzahl: String) -> String {
        "\(wert) \(wert == 1 ? einzahl : mehrzahl)"
    }

    private func hinweiszeile(_ symbol: String, _ farbe: Color, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(farbe)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
