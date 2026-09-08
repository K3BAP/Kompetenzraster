import SwiftData
import SwiftUI

enum Navigationsziel: Hashable {
    case klasse(UUID)
    case raster(UUID)
}

struct HauptfensterView: View {
    @Environment(\.modelContext) private var kontext
    @Query(sort: [SortDescriptor(\Klasse.jahrgangsstufe), SortDescriptor(\Klasse.name)])
    private var klassen: [Klasse]
    @Query(sort: [SortDescriptor(\Kompetenzraster.sortIndex), SortDescriptor(\Kompetenzraster.name)])
    private var raster: [Kompetenzraster]

    @State private var auswahl: Navigationsziel?
    @State private var neueKlasse: Klasse?
    @State private var vorlagenAuswahl = false

    @State private var pruefer = Aktualisierungspruefer.shared
    @State private var installation = Selbstaktualisierung.shared

    /// Der Streifen bleibt stehen, solange eine Aktualisierung läuft oder schiefging.
    private var zeigtStreifen: Bool {
        switch installation.phase {
        case .fehler, .neustartNoetig: return true
        default: return pruefer.zeigtStreifen || installation.laeuft
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if zeigtStreifen {
                AktualisierungsHinweisView(pruefer: pruefer, installation: installation)
            }
            fenster
        }
        .animation(.snappy, value: zeigtStreifen)
    }

    private var fenster: some View {
        NavigationSplitView {
            List(selection: $auswahl) {
                Section("Klassen") {
                    ForEach(klassen) { klasse in
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(klasse.name)
                                Text("\(klasse.schueler.count) Kinder · \(klasse.schuljahr)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "person.3")
                        }
                        .tag(Navigationsziel.klasse(klasse.id))
                        .contextMenu {
                            Button("Klasse löschen", role: .destructive) { loesche(klasse) }
                        }
                    }
                    Button {
                        klasseAnlegen()
                    } label: {
                        Label("Klasse hinzufügen", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                Section("Kompetenzraster") {
                    ForEach(raster) { einzelnes in
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(einzelnes.name)
                                Text("\(einzelnes.kompetenzen.count) Kompetenzen")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: einzelnes.istVorlage ? "square.grid.3x3.fill" : "square.grid.3x3")
                        }
                        .tag(Navigationsziel.raster(einzelnes.id))
                        .contextMenu {
                            Button("Duplizieren") { dupliziere(einzelnes) }
                            Button("Raster löschen", role: .destructive) { loesche(einzelnes) }
                        }
                    }
                    Menu {
                        Button("Leeres Raster …") { rasterAnlegen() }
                        Button("Aus Vorlage …") { vorlagenAuswahl = true }
                    } label: {
                        Label("Raster hinzufügen", systemImage: "plus")
                    }
                    .menuStyle(.borderlessButton)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            switch auswahl {
            case .klasse(let id):
                if let klasse = klassen.first(where: { $0.id == id }) {
                    KlasseDetailView(klasse: klasse)
                } else {
                    LeerhinweisView(titel: "Klasse nicht gefunden", symbol: "person.3")
                }
            case .raster(let id):
                if let gewaehltes = raster.first(where: { $0.id == id }) {
                    RasterEditorView(raster: gewaehltes)
                } else {
                    LeerhinweisView(titel: "Raster nicht gefunden", symbol: "square.grid.3x3")
                }
            case nil:
                LeerhinweisView(
                    titel: "Wähle links eine Klasse oder ein Kompetenzraster",
                    symbol: "sidebar.left"
                )
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .sheet(item: $neueKlasse) { klasse in
            KlasseBearbeitenView(klasse: klasse) { auswahl = .klasse(klasse.id) }
        }
        .sheet(isPresented: $vorlagenAuswahl) {
            VorlagenAuswahlView { fach in
                if let neues = fuegeVorlageEin(fach: fach) { auswahl = .raster(neues.id) }
            }
        }
    }

    // MARK: - Aktionen

    private func klasseAnlegen() {
        let klasse = Klasse(name: "", jahrgangsstufe: 1, sortIndex: klassen.count)
        kontext.insert(klasse)
        neueKlasse = klasse
    }

    private func rasterAnlegen() {
        let neues = Kompetenzraster(name: "Neues Raster", sortIndex: raster.count)
        neues.skala = Skalenverwaltung.standardSkala(in: kontext)
        kontext.insert(neues)
        try? kontext.save()
        auswahl = .raster(neues.id)
    }

    private func fuegeVorlageEin(fach: String) -> Kompetenzraster? {
        guard let vorlage = try? VorlagenLader.datei(fach: fach) else { return nil }
        let neues = VorlagenLader.einfuegen(
            vorlage, in: kontext, skala: Skalenverwaltung.standardSkala(in: kontext)
        )
        neues.sortIndex = raster.count
        try? kontext.save()
        return neues
    }

    private func dupliziere(_ vorlage: Kompetenzraster) {
        let kopie = Kompetenzraster(
            name: "\(vorlage.name) (Kopie)",
            fach: vorlage.fach,
            quelle: vorlage.quelle,
            sortIndex: raster.count
        )
        kopie.skala = vorlage.skala
        kontext.insert(kopie)

        // Erst alle Knoten anlegen, dann die Eltern-Kind-Kette nachziehen.
        var abbildung: [UUID: Kompetenz] = [:]
        for alt in vorlage.kompetenzen {
            let neu = Kompetenz(
                titel: alt.titel, beschreibung: alt.beschreibung, code: alt.code,
                jahrgangsHinweis: alt.jahrgangsHinweis, sortIndex: alt.sortIndex
            )
            kontext.insert(neu)
            neu.raster = kopie
            abbildung[alt.id] = neu
        }
        for alt in vorlage.kompetenzen {
            if let elternID = alt.eltern?.id {
                abbildung[alt.id]?.eltern = abbildung[elternID]
            }
        }
        try? kontext.save()
        auswahl = .raster(kopie.id)
    }

    private func loesche(_ klasse: Klasse) {
        if auswahl == .klasse(klasse.id) { auswahl = nil }
        kontext.delete(klasse)
        try? kontext.save()
    }

    private func loesche(_ einzelnes: Kompetenzraster) {
        if auswahl == .raster(einzelnes.id) { auswahl = nil }
        kontext.delete(einzelnes)
        try? kontext.save()
    }
}

/// Einheitlicher Platzhalter für leere Bereiche.
struct LeerhinweisView: View {
    var titel: String
    var symbol: String
    var beschreibung: String?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(titel)
                .font(.title3)
                .foregroundStyle(.secondary)
            if let beschreibung {
                Text(beschreibung)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Sorgt dafür, dass es immer genau eine Standardskala gibt.
enum Skalenverwaltung {
    static func standardSkala(in kontext: ModelContext) -> Bewertungsskala {
        if let vorhandene = try? kontext.fetch(FetchDescriptor<Bewertungsskala>()).first {
            return vorhandene
        }
        let skala = Bewertungsskala.standard()
        kontext.insert(skala)
        for stufe in skala.stufen { kontext.insert(stufe) }
        return skala
    }
}
