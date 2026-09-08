import SwiftData
import SwiftUI

/// Erfassung für ein einzelnes Kind: je Kompetenz eine Zeile, je Stufe eine Spalte.
///
/// Ein Klick setzt die Stufe, ein Klick auf die bereits gesetzte nimmt sie wieder zurück.
/// Die nicht gewählten Felder zeigen ihr Stufensymbol blass – die Zeile liest sich dadurch
/// als Wachstumsreihe, und die gewählte Stufe hebt sich davon ab.
struct SchuelerErfassungView: View {
    @Bindable var klasse: Klasse
    @Bindable var raster: Kompetenzraster
    @Environment(\.modelContext) private var kontext

    @State private var schuelerID: UUID?
    @State private var notizZiel: NotizZiel?

    private var kinder: [SchuelerIn] { klasse.schuelerSortiert }
    private var stufen: [Bewertungsstufe] { raster.skala?.stufenSortiert ?? [] }
    private var kind: SchuelerIn? {
        kinder.first { $0.id == schuelerID } ?? kinder.first
    }

    private let spaltenBreite: CGFloat = 74
    private let randAussen: CGFloat = 20
    private let notizBreite: CGFloat = 30

    var body: some View {
        Group {
            if kinder.isEmpty {
                LeerhinweisView(
                    titel: "Diese Klasse hat noch keine Kinder",
                    symbol: "person.badge.plus",
                    beschreibung: "Lege sie unter „Schüler:innen“ an, dann erscheint hier das Raster."
                )
            } else if raster.blattKompetenzen.isEmpty {
                LeerhinweisView(titel: "Dieses Raster enthält noch keine Kompetenzen", symbol: "square.grid.3x3")
            } else {
                HSplitView {
                    kinderliste
                        .frame(minWidth: 190, idealWidth: 220, maxWidth: 300)
                    if let kind {
                        bogen(fuer: kind)
                            .frame(minWidth: 520)
                    }
                }
            }
        }
        .onAppear { if schuelerID == nil { schuelerID = kinder.first?.id } }
        .sheet(item: $notizZiel) { ziel in
            NotizBearbeitenView(kompetenz: ziel.kompetenz, schueler: ziel.schueler)
        }
    }

    // MARK: - Kinderliste

    private var kinderliste: some View {
        List(selection: $schuelerID) {
            ForEach(kinder) { person in
                let ergebnis = Auswertung.ergebnis(fuer: raster, schueler: person)
                VStack(alignment: .leading, spacing: 4) {
                    Text(person.vollerName.isEmpty ? person.kuerzel : person.vollerName)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Fortschrittsbalken(anteil: ergebnis.anteilBewertet, farbe: farbe(zu: ergebnis))
                        Text("\(ergebnis.bewertet)/\(ergebnis.gesamt)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 3)
                .tag(person.id)
            }
        }
        .listStyle(.sidebar)
    }

    private func farbe(zu ergebnis: Auswertungsergebnis) -> Color {
        guard let mittelwert = ergebnis.mittelwert,
              let stufe = raster.skala?.stufe(fuerMittelwert: mittelwert)
        else { return .secondary }
        return stufe.farbe
    }

    // MARK: - Erfassungsbogen

    private func bogen(fuer kind: SchuelerIn) -> some View {
        VStack(spacing: 0) {
            kopf(fuer: kind)
            Divider()
            spaltenkopf
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(raster.wurzeln) { bereich in
                        Section {
                            ForEach(bereich.blattgruppen) { gruppe in
                                if let titel = gruppe.titel {
                                    zwischenzeile(titel)
                                }
                                ForEach(gruppe.blaetter) { blatt in
                                    KompetenzZeile(
                                        kompetenz: blatt,
                                        schueler: kind,
                                        stufen: stufen,
                                        spaltenBreite: spaltenBreite,
                                        notizBreite: notizBreite,
                                        rand: randAussen,
                                        notizOeffnen: { notizZiel = NotizZiel(kompetenz: blatt, schueler: kind) }
                                    )
                                    Divider().padding(.leading, randAussen)
                                }
                            }
                        } header: {
                            bereichszeile(bereich, kind: kind)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    private func kopf(fuer kind: SchuelerIn) -> some View {
        let ergebnis = Auswertung.ergebnis(fuer: raster, schueler: kind)
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(kind.vollerName.isEmpty ? kind.kuerzel : kind.vollerName)
                .font(.title3.weight(.semibold))
            Text(raster.name)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(ergebnis.bewertet) von \(ergebnis.gesamt) bewertet")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, randAussen)
        .padding(.vertical, 12)
    }

    /// Die Spaltenüberschriften bleiben beim Blättern stehen.
    private var spaltenkopf: some View {
        HStack(spacing: 0) {
            Text("Kompetenz")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(stufen) { stufe in
                VStack(spacing: 3) {
                    BewertungsSymbol(quelle: stufe.symbol, farbe: stufe.farbe, groesse: 22)
                    Text(stufe.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(width: spaltenBreite)
                .help(stufe.name)
            }
            // Platzhalter für die Notizspalte; feste Höhe, sonst dehnt Color.clear die Zeile.
            Color.clear.frame(width: notizBreite, height: 1)
        }
        .padding(.horizontal, randAussen)
        .padding(.vertical, 8)
        .background(.background)
    }

    private func bereichszeile(_ bereich: Kompetenz, kind: SchuelerIn) -> some View {
        let ergebnis = Auswertung.ergebnis(fuer: bereich, schueler: kind)
        let stufe = ergebnis.mittelwert.flatMap { raster.skala?.stufe(fuerMittelwert: $0) }
        return HStack(spacing: 8) {
            Text(bereich.titel)
                .font(.callout.weight(.semibold))
            Spacer()
            Text("\(ergebnis.bewertet)/\(ergebnis.gesamt)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            StufenSymbol(stufe: stufe, groesse: 20)
                .help(ergebnis.istLeer ? "noch nicht bewertet" : "Durchschnitt: \(stufe?.name ?? "–")")
        }
        .padding(.horizontal, randAussen)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func zwischenzeile(_ titel: String) -> some View {
        Text(titel)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, randAussen)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Eine Kompetenz mit ihren Ankreuzfeldern.
private struct KompetenzZeile: View {
    let kompetenz: Kompetenz
    let schueler: SchuelerIn
    let stufen: [Bewertungsstufe]
    let spaltenBreite: CGFloat
    let notizBreite: CGFloat
    let rand: CGFloat
    let notizOeffnen: () -> Void

    @Environment(\.modelContext) private var kontext
    @State private var ueberfahren = false

    private var eintrag: Eintrag? { Auswertung.eintrag(fuer: kompetenz, schueler: schueler) }

    var body: some View {
        let gesetzt = eintrag?.stufe
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(kompetenz.titel)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                if !kompetenz.jahrgangsHinweis.isEmpty {
                    Text(kompetenz.jahrgangsHinweis)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 12)
            .help(kompetenz.beschreibung.isEmpty ? kompetenz.titel : kompetenz.beschreibung)

            ForEach(stufen) { stufe in
                Ankreuzfeld(
                    stufe: stufe,
                    gewaehlt: gesetzt?.id == stufe.id,
                    breite: spaltenBreite
                ) {
                    setze(stufe, bereitsGesetzt: gesetzt?.id == stufe.id)
                }
                .help("\(kompetenz.titel) – \(stufe.name)")
            }

            Button(action: notizOeffnen) {
                Image(systemName: hatNotiz ? "text.bubble.fill" : "text.bubble")
                    .foregroundStyle(hatNotiz ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .buttonStyle(.plain)
            .frame(width: notizBreite)
            .opacity(hatNotiz || ueberfahren ? 1 : 0)
            .disabled(eintrag == nil)
            .help(eintrag == nil ? "Erst bewerten, dann notieren" : "Notiz")
        }
        .padding(.horizontal, rand)
        .padding(.vertical, 5)
        .background(ueberfahren ? Color.primary.opacity(0.04) : .clear)
        .onHover { ueberfahren = $0 }
    }

    private var hatNotiz: Bool {
        !(eintrag?.notiz.isEmpty ?? true)
    }

    private func setze(_ stufe: Bewertungsstufe, bereitsGesetzt: Bool) {
        withAnimation(.snappy(duration: 0.18)) {
            Erfassung.setze(bereitsGesetzt ? nil : stufe, fuer: kompetenz, schueler: schueler, in: kontext)
        }
    }
}

/// Ein einzelnes Feld der Stufenspalte.
private struct Ankreuzfeld: View {
    let stufe: Bewertungsstufe
    let gewaehlt: Bool
    let breite: CGFloat
    let tippen: () -> Void

    @State private var ueberfahren = false

    var body: some View {
        Button(action: tippen) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(gewaehlt ? stufe.farbe.opacity(0.18) : (ueberfahren ? stufe.farbe.opacity(0.09) : .clear))
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(gewaehlt ? stufe.farbe : stufe.farbe.opacity(ueberfahren ? 0.45 : 0), lineWidth: 1.5)
                BewertungsSymbol(
                    quelle: stufe.symbol,
                    farbe: stufe.farbe,
                    groesse: gewaehlt ? 28 : 24,
                    gedaempft: !gewaehlt
                )
            }
            .frame(width: breite - 8, height: 34)
            .frame(width: breite)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { ueberfahren = $0 }
        .accessibilityLabel(stufe.name)
        .accessibilityAddTraits(gewaehlt ? [.isSelected] : [])
    }
}

/// Wie viel eines Rasters für ein Kind schon bewertet ist.
struct Fortschrittsbalken: View {
    var anteil: Double
    var farbe: Color

    var body: some View {
        GeometryReader { raum in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(farbe)
                    .frame(width: raum.size.width * min(max(anteil, 0), 1))
            }
        }
        .frame(height: 4)
    }
}
