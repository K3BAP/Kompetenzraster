import SwiftData
import SwiftUI

/// Schüler:innen × Kompetenzen. Mit gewähltem „Stift“ genügt ein Klick je Bewertung.
struct RasterMatrixView: View {
    @Bindable var klasse: Klasse
    @Bindable var raster: Kompetenzraster
    @Environment(\.modelContext) private var kontext

    @State private var stiftID: UUID?
    @State private var notizZiel: NotizZiel?

    private var stufen: [Bewertungsstufe] { raster.skala?.stufenSortiert ?? [] }
    private var stift: Bewertungsstufe? { stufen.first { $0.id == stiftID } }
    private var kinder: [SchuelerIn] { klasse.schuelerSortiert }

    private let titelBreite: CGFloat = 320
    private let spaltenBreite: CGFloat = 42

    var body: some View {
        VStack(spacing: 0) {
            stiftleiste
            Divider()
            if kinder.isEmpty {
                LeerhinweisView(
                    titel: "Diese Klasse hat noch keine Kinder",
                    symbol: "person.badge.plus",
                    beschreibung: "Lege sie unter „Schüler:innen“ an, dann erscheint hier das Raster."
                )
            } else if raster.blattKompetenzen.isEmpty {
                LeerhinweisView(titel: "Dieses Raster enthält noch keine Kompetenzen", symbol: "square.grid.3x3")
            } else {
                gitter
            }
        }
        .onAppear { if stiftID == nil { stiftID = stufen.last?.id } }
        .sheet(item: $notizZiel) { ziel in
            NotizBearbeitenView(kompetenz: ziel.kompetenz, schueler: ziel.schueler)
        }
    }

    // MARK: - Stiftleiste

    private var stiftleiste: some View {
        HStack(spacing: 12) {
            Text("Stift")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)

            ForEach(stufen) { stufe in
                Button {
                    stiftID = stufe.id
                } label: {
                    HStack(spacing: 6) {
                        BewertungsSymbol(quelle: stufe.symbol, farbe: stufe.farbe, groesse: 20)
                        Text(stufe.name).font(.callout)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(stiftID == stufe.id ? stufe.farbe.opacity(0.2) : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(stiftID == stufe.id ? stufe.farbe : .clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }

            Button {
                stiftID = nil
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "eraser")
                    Text("Löschen").font(.callout)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(stiftID == nil ? Color.secondary.opacity(0.2) : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(stiftID == nil ? Color.secondary : .clear, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)

            Spacer()
            Text("Klick setzt den Stift · Rechtsklick für Notiz und einzelne Stufen")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Gitter

    private var gitter: some View {
        ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    Text("Kompetenz")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: titelBreite, alignment: .leading)
                    ForEach(kinder) { kind in
                        Text(kind.kuerzel)
                            .font(.caption.weight(.semibold).monospaced())
                            .frame(width: spaltenBreite)
                            .help(kind.vollerName)
                    }
                }
                .padding(.vertical, 6)

                Divider().gridCellUnsizedAxes(.horizontal)

                ForEach(raster.wurzeln) { bereich in
                    GridRow {
                        Text(bereich.titel)
                            .font(.callout.weight(.semibold))
                            .frame(width: titelBreite, alignment: .leading)
                            .padding(.vertical, 7)
                        ForEach(kinder) { kind in
                            BereichsUeberblick(bereich: bereich, schueler: kind, skala: raster.skala)
                                .frame(width: spaltenBreite)
                        }
                    }
                    .background(.quaternary.opacity(0.3))

                    ForEach(bereich.blaetterImTeilbaum) { blatt in
                        GridRow {
                            kompetenzTitel(blatt, unter: bereich)
                            ForEach(kinder) { kind in
                                zelle(kompetenz: blatt, schueler: kind)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func kompetenzTitel(_ blatt: Kompetenz, unter bereich: Kompetenz) -> some View {
        // Bei tieferen Rastern (etwa Mathematik) den Zwischenknoten mitzeigen.
        let zwischen = blatt.pfad.dropFirst().dropLast().map(\.titel).joined(separator: " · ")
        return VStack(alignment: .leading, spacing: 1) {
            if !zwischen.isEmpty {
                Text(zwischen)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Text(blatt.titel)
                .font(.callout)
                .lineLimit(2)
        }
        .frame(width: titelBreite, alignment: .leading)
        .padding(.vertical, 4)
        .padding(.leading, 12)
        .help(blatt.beschreibung.isEmpty ? blatt.titel : blatt.beschreibung)
    }

    private func zelle(kompetenz: Kompetenz, schueler: SchuelerIn) -> some View {
        let eintrag = Auswertung.eintrag(fuer: kompetenz, schueler: schueler)
        return Button {
            Erfassung.setze(stift, fuer: kompetenz, schueler: schueler, in: kontext)
        } label: {
            ZStack(alignment: .topTrailing) {
                StufenSymbol(stufe: eintrag?.stufe, groesse: 22)
                    .frame(width: spaltenBreite, height: 30)
                if let notiz = eintrag?.notiz, !notiz.isEmpty {
                    Circle()
                        .fill(.tint)
                        .frame(width: 5, height: 5)
                        .padding(.trailing, 6)
                        .padding(.top, 3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(hilfetext(eintrag: eintrag, schueler: schueler, kompetenz: kompetenz))
        .contextMenu {
            ForEach(stufen) { stufe in
                Button {
                    Erfassung.setze(stufe, fuer: kompetenz, schueler: schueler, in: kontext)
                } label: {
                    Label(stufe.name, systemImage: eintrag?.stufe?.id == stufe.id ? "checkmark" : "circle")
                }
            }
            Divider()
            Button("Notiz …") {
                if eintrag == nil, let ersteStufe = stufen.first {
                    Erfassung.setze(ersteStufe, fuer: kompetenz, schueler: schueler, in: kontext)
                }
                notizZiel = NotizZiel(kompetenz: kompetenz, schueler: schueler)
            }
            Button("Bewertung entfernen", role: .destructive) {
                Erfassung.setze(nil, fuer: kompetenz, schueler: schueler, in: kontext)
            }
            .disabled(eintrag == nil)
        }
    }

    private func hilfetext(eintrag: Eintrag?, schueler: SchuelerIn, kompetenz: Kompetenz) -> String {
        var zeilen = ["\(schueler.vollerName) – \(kompetenz.titel)"]
        zeilen.append(eintrag?.stufe?.name ?? "noch nicht bewertet")
        if let notiz = eintrag?.notiz, !notiz.isEmpty { zeilen.append(notiz) }
        return zeilen.joined(separator: "\n")
    }
}

struct NotizZiel: Identifiable {
    let kompetenz: Kompetenz
    let schueler: SchuelerIn
    var id: String { "\(kompetenz.id)-\(schueler.id)" }
}

/// Der zusammengefasste Stand eines Bereichs – die Zeile über den Einzelkompetenzen.
private struct BereichsUeberblick: View {
    let bereich: Kompetenz
    let schueler: SchuelerIn
    let skala: Bewertungsskala?

    var body: some View {
        let ergebnis = Auswertung.ergebnis(fuer: bereich, schueler: schueler)
        let stufe = ergebnis.mittelwert.flatMap { skala?.stufe(fuerMittelwert: $0) }
        StufenSymbol(stufe: stufe, groesse: 20)
            .opacity(ergebnis.istLeer ? 0.5 : 1)
            .help("\(ergebnis.bewertet) von \(ergebnis.gesamt) bewertet")
    }
}

struct NotizBearbeitenView: View {
    let kompetenz: Kompetenz
    let schueler: SchuelerIn
    @Environment(\.dismiss) private var schliessen
    @Environment(\.modelContext) private var kontext
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(kompetenz.titel)
                .font(.headline)
            Text(schueler.vollerName)
                .font(.callout)
                .foregroundStyle(.secondary)

            TextEditor(text: $text)
                .font(.body)
                .frame(height: 140)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))

            HStack {
                Button("Abbrechen", role: .cancel) { schliessen() }
                Spacer()
                Button("Sichern") {
                    Erfassung.setzeNotiz(text, fuer: kompetenz, schueler: schueler, in: kontext)
                    schliessen()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear {
            text = Auswertung.eintrag(fuer: kompetenz, schueler: schueler)?.notiz ?? ""
        }
    }
}
