import SwiftData
import SwiftUI

extension Skalenverwaltung {
    /// Entfernt eine Stufe und hängt ihre Einträge an die nächstgelegene verbleibende Stufe um.
    /// Ohne das Umhängen würden bestehende Bewertungen ihre Stufe verlieren.
    static func entferne(_ stufe: Bewertungsstufe, in kontext: ModelContext) {
        guard let skala = stufe.skala, skala.stufen.count > 1 else { return }
        let verbleibende = skala.stufenSortiert.filter { $0.id != stufe.id }
        if let ersatz = verbleibende.min(by: { abs($0.wert - stufe.wert) < abs($1.wert - stufe.wert) }) {
            for eintrag in stufe.eintraege { eintrag.stufe = ersatz }
        }
        kontext.delete(stufe)
        // Werte lückenlos halten, damit Mittelwerte vergleichbar bleiben.
        for (index, verbliebene) in verbleibende.enumerated() { verbliebene.wert = index }
        try? kontext.save()
    }

    static func fuegeStufeHinzu(zu skala: Bewertungsskala, in kontext: ModelContext) {
        let neue = Bewertungsstufe(
            name: "Neue Stufe",
            wert: skala.stufen.count,
            farbeHex: "#4C8BF5",
            symbol: .pflanze(stufe: PflanzenStufe.fuer(position: skala.stufen.count, von: skala.stufen.count + 1).rawValue)
        )
        kontext.insert(neue)
        neue.skala = skala
        try? kontext.save()
    }
}

struct SkalenEinstellungenView: View {
    @Environment(\.modelContext) private var kontext
    @Query(sort: \Bewertungsskala.erstelltAm) private var skalen: [Bewertungsskala]
    @State private var auswahlID: UUID?

    private var auswahl: Bewertungsskala? {
        skalen.first { $0.id == auswahlID } ?? skalen.first
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                List(selection: $auswahlID) {
                    ForEach(skalen) { skala in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(skala.name)
                            HStack(spacing: 4) {
                                ForEach(skala.stufenSortiert) { stufe in
                                    BewertungsSymbol(quelle: stufe.symbol, farbe: stufe.farbe, groesse: 14)
                                }
                            }
                        }
                        .tag(skala.id)
                    }
                }
                Divider()
                HStack {
                    Button { neueSkala() } label: { Image(systemName: "plus") }
                    Button(role: .destructive) { loescheSkala() } label: { Image(systemName: "minus") }
                        .disabled(skalen.count < 2 || auswahl == nil)
                    Spacer()
                }
                .padding(8)
            }
            .frame(minWidth: 190, maxWidth: 240)

            if let auswahl {
                SkalaDetailView(skala: auswahl)
                    .frame(minWidth: 330)
            } else {
                LeerhinweisView(titel: "Keine Skala gewählt", symbol: "leaf")
                    .frame(minWidth: 330)
            }
        }
    }

    private func neueSkala() {
        let skala = Bewertungsskala.standard()
        skala.name = "Neue Skala"
        kontext.insert(skala)
        for stufe in skala.stufen { kontext.insert(stufe) }
        try? kontext.save()
        auswahlID = skala.id
    }

    private func loescheSkala() {
        guard let auswahl, skalen.count > 1 else { return }
        // Raster, die diese Skala nutzen, auf die erste verbleibende umstellen.
        let ersatz = skalen.first { $0.id != auswahl.id }
        for raster in auswahl.raster { raster.skala = ersatz }
        auswahlID = ersatz?.id
        kontext.delete(auswahl)
        try? kontext.save()
    }
}

private struct SkalaDetailView: View {
    @Bindable var skala: Bewertungsskala
    @Environment(\.modelContext) private var kontext

    var body: some View {
        Form {
            Section("Skala") {
                TextField("Name", text: $skala.name)
                LabeledContent("Verwendet in", value: "\(skala.raster.count) Rastern")
            }

            Section("Stufen") {
                ForEach(skala.stufenSortiert) { stufe in
                    StufenZeileView(stufe: stufe) {
                        Skalenverwaltung.entferne(stufe, in: kontext)
                    }
                    .disabled(false)
                }
                Button {
                    Skalenverwaltung.fuegeStufeHinzu(zu: skala, in: kontext)
                } label: {
                    Label("Stufe hinzufügen", systemImage: "plus")
                }
            }

            Section {
                Text("Die Reihenfolge von unten nach oben entspricht dem Lernfortschritt. Wird eine Stufe entfernt, rücken vorhandene Bewertungen auf die nächstgelegene Stufe.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: skala.name) { try? kontext.save() }
    }
}

private struct StufenZeileView: View {
    @Bindable var stufe: Bewertungsstufe
    var entfernen: () -> Void
    @Environment(\.modelContext) private var kontext

    var body: some View {
        HStack(spacing: 10) {
            BewertungsSymbol(quelle: stufe.symbol, farbe: stufe.farbe, groesse: 26)
                .frame(width: 30)

            TextField("Bezeichnung", text: $stufe.name)
                .textFieldStyle(.roundedBorder)
                .labelsHidden()

            ColorPicker("", selection: Binding(
                get: { stufe.farbe },
                set: { stufe.farbeHex = $0.hexWert; try? kontext.save() }
            ), supportsOpacity: false)
            .labelsHidden()
            .frame(width: 44)

            SymbolWahlMenue(stufe: stufe)

            Button(role: .destructive, action: entfernen) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled((stufe.skala?.stufen.count ?? 0) < 2)
        }
        .onChange(of: stufe.name) { try? kontext.save() }
    }
}

/// Auswahl der Symbolart und des konkreten Symbols einer Stufe.
private struct SymbolWahlMenue: View {
    @Bindable var stufe: Bewertungsstufe
    @Environment(\.modelContext) private var kontext
    @State private var eigenerWert = ""
    @State private var eingabeZeigen = false

    /// Eine kleine Auswahl, die zum Wachstumsgedanken passt.
    private let sfVorschlaege = [
        "circle", "circle.lefthalf.filled", "circle.fill", "star.fill",
        "leaf", "leaf.fill", "tree.fill", "camera.macro",
        "hare.fill", "tortoise.fill", "checkmark.circle.fill", "hand.thumbsup.fill",
    ]
    private let emojiVorschlaege = ["🌱", "🌿", "🌷", "🌳", "⭐️", "👍", "🙂", "💪"]

    var body: some View {
        Menu {
            Menu("Pflanze") {
                ForEach(PflanzenStufe.allCases, id: \.rawValue) { pflanze in
                    Button(pflanze.bezeichnung) { setze(.pflanze(stufe: pflanze.rawValue)) }
                }
            }
            Menu("SF Symbol") {
                ForEach(sfVorschlaege, id: \.self) { name in
                    Button {
                        setze(.sfSymbol(name: name))
                    } label: {
                        Label(name, systemImage: name)
                    }
                }
                Divider()
                Button("Eigenes SF Symbol …") { eingabeZeigen = true }
            }
            Menu("Emoji") {
                ForEach(emojiVorschlaege, id: \.self) { zeichen in
                    Button(zeichen) { setze(.emoji(zeichen)) }
                }
            }
            Button("Nur Farbpunkt") { setze(.punkt) }
        } label: {
            Text(stufe.symbol.artBezeichnung)
                .font(.caption)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .popover(isPresented: $eingabeZeigen) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Name eines SF Symbols")
                    .font(.headline)
                TextField("z. B. sparkles", text: $eigenerWert)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                HStack {
                    if !eigenerWert.isEmpty {
                        Image(systemName: eigenerWert)
                        Text("Vorschau").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Übernehmen") {
                        setze(.sfSymbol(name: eigenerWert))
                        eingabeZeigen = false
                    }
                    .disabled(eigenerWert.isEmpty)
                }
            }
            .padding(14)
        }
    }

    private func setze(_ quelle: SymbolQuelle) {
        stufe.symbol = quelle
        try? kontext.save()
    }
}
