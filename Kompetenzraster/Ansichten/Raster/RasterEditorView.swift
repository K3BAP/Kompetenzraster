import SwiftData
import SwiftUI

extension Kompetenz {
    /// `nil` bei Blättern, damit der Baum dort kein Aufklapp-Dreieck zeigt.
    var kinderFuerBaum: [Kompetenz]? { kinder.isEmpty ? nil : kinderSortiert }
}

struct RasterEditorView: View {
    @Bindable var raster: Kompetenzraster
    @Environment(\.modelContext) private var kontext
    @Query(sort: \Bewertungsskala.erstelltAm) private var skalen: [Bewertungsskala]

    @State private var auswahlID: UUID?
    @State private var quelleZeigen = false

    private var auswahl: Kompetenz? {
        raster.kompetenzen.first { $0.id == auswahlID }
    }

    var body: some View {
        VStack(spacing: 0) {
            kopfzeile
            Divider()
            HSplitView {
                baum.frame(minWidth: 300)
                detail.frame(minWidth: 240, maxWidth: 420)
            }
        }
    }

    // MARK: - Kopf

    private var kopfzeile: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Name des Rasters", text: $raster.name)
                    .textFieldStyle(.plain)
                    .font(.largeTitle.weight(.semibold))
                Spacer()
                if !raster.quelle.isEmpty {
                    Button {
                        quelleZeigen = true
                    } label: {
                        Label("Quelle", systemImage: "info.circle")
                    }
                    .popover(isPresented: $quelleZeigen, arrowEdge: .bottom) {
                        Text(raster.quelle)
                            .font(.callout)
                            .padding(16)
                            .frame(width: 420)
                            .textSelection(.enabled)
                    }
                }
            }

            HStack(spacing: 14) {
                TextField("Fach", text: $raster.fach, prompt: Text("Fach"))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)

                Picker("Skala", selection: Binding(
                    get: { raster.skala?.id },
                    set: { neue in raster.skala = skalen.first { $0.id == neue } }
                )) {
                    ForEach(skalen) { skala in
                        Text("\(skala.name) (\(skala.stufen.count) Stufen)").tag(Optional(skala.id))
                    }
                }
                .fixedSize()

                if let skala = raster.skala {
                    HStack(spacing: 6) {
                        ForEach(skala.stufenSortiert) { stufe in
                            BewertungsSymbol(quelle: stufe.symbol, farbe: stufe.farbe, groesse: 18)
                                .help(stufe.name)
                        }
                    }
                }
                Spacer(minLength: 8)
                Text("\(raster.blattKompetenzen.count) bewertbare Kompetenzen")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .layoutPriority(-1)
            }
        }
        .padding(20)
        .onChange(of: raster.name) { try? kontext.save() }
        .onChange(of: raster.fach) { try? kontext.save() }
    }

    // MARK: - Baum

    private var baum: some View {
        VStack(spacing: 0) {
            if raster.wurzeln.isEmpty {
                LeerhinweisView(
                    titel: "Noch keine Kompetenzen",
                    symbol: "list.bullet.indent",
                    beschreibung: "Lege unten einen Kompetenzbereich an und ergänze darunter die Kompetenzen."
                )
            } else {
                List(selection: $auswahlID) {
                    OutlineGroup(raster.wurzeln, id: \.id, children: \.kinderFuerBaum) { knoten in
                        KompetenzZeileView(kompetenz: knoten)
                            .tag(knoten.id)
                    }
                }
                .listStyle(.sidebar)
            }

            Divider()
            HStack(spacing: 8) {
                Button {
                    fuegeHinzu(unter: nil)
                } label: {
                    Label("Bereich", systemImage: "plus")
                }
                Button {
                    if let auswahl { fuegeHinzu(unter: auswahl) }
                } label: {
                    Label("Unterkompetenz", systemImage: "plus.rectangle.on.rectangle")
                }
                .disabled(auswahl == nil)

                Spacer()

                Button { verschiebe(-1) } label: { Image(systemName: "arrow.up") }
                    .disabled(auswahl == nil)
                Button { verschiebe(1) } label: { Image(systemName: "arrow.down") }
                    .disabled(auswahl == nil)
                Button(role: .destructive) { loescheAuswahl() } label: { Image(systemName: "trash") }
                    .disabled(auswahl == nil)
            }
            .padding(10)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let auswahl {
            KompetenzDetailView(kompetenz: auswahl)
        } else {
            LeerhinweisView(titel: "Keine Kompetenz gewählt", symbol: "cursorarrow.rays")
                .background(.quaternary.opacity(0.25))
        }
    }

    // MARK: - Aktionen

    private func fuegeHinzu(unter elternteil: Kompetenz?) {
        let geschwister = elternteil?.kinder ?? raster.wurzeln
        let neue = Kompetenz(
            titel: elternteil == nil ? "Neuer Kompetenzbereich" : "Neue Kompetenz",
            sortIndex: geschwister.count
        )
        kontext.insert(neue)
        neue.raster = raster
        neue.eltern = elternteil
        try? kontext.save()
        auswahlID = neue.id
    }

    private func loescheAuswahl() {
        guard let auswahl else { return }
        auswahlID = nil
        kontext.delete(auswahl)   // Kinder und Einträge hängen per Löschregel daran
        try? kontext.save()
    }

    /// Tauscht die Kompetenz mit ihrer Nachbarin auf derselben Ebene.
    private func verschiebe(_ richtung: Int) {
        guard let auswahl else { return }
        let geschwister = auswahl.eltern?.kinderSortiert ?? raster.wurzeln
        guard let position = geschwister.firstIndex(where: { $0.id == auswahl.id }) else { return }
        let ziel = position + richtung
        guard geschwister.indices.contains(ziel) else { return }

        // Nach dem Tausch die Indizes neu vergeben, damit sie lückenlos bleiben.
        var neueReihenfolge = geschwister
        neueReihenfolge.swapAt(position, ziel)
        for (index, knoten) in neueReihenfolge.enumerated() { knoten.sortIndex = index }
        try? kontext.save()
    }
}

private struct KompetenzZeileView: View {
    @Bindable var kompetenz: Kompetenz

    var body: some View {
        HStack(spacing: 8) {
            if !kompetenz.code.isEmpty {
                Text(kompetenz.code)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Text(kompetenz.titel)
                .lineLimit(1)
            if !kompetenz.jahrgangsHinweis.isEmpty {
                Text(kompetenz.jahrgangsHinweis)
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.tint.opacity(0.15), in: Capsule())
            }
            Spacer()
            if !kompetenz.istBlatt {
                Text("\(kompetenz.kinder.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct KompetenzDetailView: View {
    @Bindable var kompetenz: Kompetenz
    @Environment(\.modelContext) private var kontext

    var body: some View {
        Form {
            Section("Kompetenz") {
                TextField("Titel", text: $kompetenz.titel, axis: .vertical)
                    .lineLimit(1 ... 4)
                TextField("Beschreibung", text: $kompetenz.beschreibung, axis: .vertical)
                    .lineLimit(3 ... 10)
            }
            Section("Einordnung") {
                TextField("Gliederungsnummer", text: $kompetenz.code, prompt: Text("z. B. 4.2.1"))
                TextField("Jahrgangshinweis", text: $kompetenz.jahrgangsHinweis,
                          prompt: Text("z. B. Ende Kl. 2"))
                LabeledContent("Ebene", value: beschriftungFuerEbene)
                LabeledContent("Unterkompetenzen", value: "\(kompetenz.kinder.count)")
                LabeledContent("Einträge", value: "\(kompetenz.eintraege.count)")
            }
        }
        .formStyle(.grouped)
        .onChange(of: kompetenz.titel) { try? kontext.save() }
        .onChange(of: kompetenz.beschreibung) { try? kontext.save() }
        .onChange(of: kompetenz.code) { try? kontext.save() }
        .onChange(of: kompetenz.jahrgangsHinweis) { try? kontext.save() }
    }

    private var beschriftungFuerEbene: String {
        switch kompetenz.ebene {
        case 0: "Kompetenzbereich"
        case 1: "Oberkompetenz"
        default: "Unterkompetenz (Ebene \(kompetenz.ebene))"
        }
    }
}
