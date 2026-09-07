import SwiftData
import SwiftUI

struct SchuelerListeView: View {
    @Bindable var klasse: Klasse
    @Environment(\.modelContext) private var kontext
    @Query(sort: \Kompetenzraster.name) private var alleRaster: [Kompetenzraster]

    @State private var csvImport = false
    @State private var auswahl = Set<UUID>()

    var body: some View {
        HSplitView {
            schuelerliste
                .frame(minWidth: 320)
            rasterZuordnung
                .frame(minWidth: 220, maxWidth: 340)
        }
        .sheet(isPresented: $csvImport) {
            SchuelerCSVImportView(klasse: klasse)
        }
    }

    private var schuelerliste: some View {
        VStack(spacing: 0) {
            if klasse.schueler.isEmpty {
                LeerhinweisView(
                    titel: "Noch keine Kinder in dieser Klasse",
                    symbol: "person.badge.plus",
                    beschreibung: "Füge sie einzeln hinzu oder füge eine Liste aus einer Tabelle ein."
                )
            } else {
                List(selection: $auswahl) {
                    ForEach(klasse.schuelerSortiert) { person in
                        SchuelerZeileView(person: person)
                            .tag(person.id)
                    }
                }
                .listStyle(.inset)
            }

            Divider()
            HStack(spacing: 8) {
                Button {
                    hinzufuegen()
                } label: {
                    Label("Kind hinzufügen", systemImage: "plus")
                }
                Button {
                    csvImport = true
                } label: {
                    Label("Liste einfügen", systemImage: "doc.on.clipboard")
                }
                Spacer()
                Button(role: .destructive) {
                    entferneAuswahl()
                } label: {
                    Label("Entfernen", systemImage: "minus")
                }
                .disabled(auswahl.isEmpty)
            }
            .padding(10)
        }
    }

    private var rasterZuordnung: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Kompetenzraster dieser Klasse")
                .font(.headline)
                .padding([.horizontal, .top], 14)
                .padding(.bottom, 6)

            if alleRaster.isEmpty {
                Text("Es gibt noch keine Raster. Lege links eines an oder übernimm eine Vorlage.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
            } else {
                List {
                    ForEach(alleRaster) { raster in
                        Toggle(isOn: bindungFuer(raster)) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(raster.name)
                                Text("\(raster.blattKompetenzen.count) bewertbare Kompetenzen")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
            Spacer(minLength: 0)
        }
        .background(.quaternary.opacity(0.25))
    }

    private func bindungFuer(_ raster: Kompetenzraster) -> Binding<Bool> {
        Binding(
            get: { klasse.raster.contains { $0.id == raster.id } },
            set: { aktiv in
                if aktiv {
                    if !klasse.raster.contains(where: { $0.id == raster.id }) {
                        klasse.raster.append(raster)
                    }
                } else {
                    klasse.raster.removeAll { $0.id == raster.id }
                }
                try? kontext.save()
            }
        )
    }

    private func hinzufuegen() {
        let person = SchuelerIn(vorname: "Neues", nachname: "Kind", sortIndex: klasse.schueler.count)
        kontext.insert(person)
        person.klasse = klasse
        try? kontext.save()
    }

    private func entferneAuswahl() {
        for person in klasse.schueler where auswahl.contains(person.id) {
            kontext.delete(person)
        }
        auswahl.removeAll()
        try? kontext.save()
    }
}

/// Eine Zeile der Klassenliste – direkt bearbeitbar.
private struct SchuelerZeileView: View {
    @Bindable var person: SchuelerIn
    @Environment(\.modelContext) private var kontext

    var body: some View {
        HStack(spacing: 10) {
            Text(person.kuerzel.isEmpty ? "–" : person.kuerzel)
                .font(.caption.weight(.semibold).monospaced())
                .frame(width: 34, height: 26)
                .background(.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))

            TextField("Vorname", text: $person.vorname)
                .textFieldStyle(.plain)
            TextField("Nachname", text: $person.nachname)
                .textFieldStyle(.plain)

            Text("\(person.eintraege.count) Einträge")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .onChange(of: person.vorname) { aktualisiereKuerzel() }
        .onChange(of: person.nachname) { aktualisiereKuerzel() }
    }

    /// Das Kürzel folgt dem Namen, solange es nicht von Hand gesetzt wurde.
    private func aktualisiereKuerzel() {
        person.kuerzel = SchuelerIn.kuerzelVorschlag(vorname: person.vorname, nachname: person.nachname)
        try? kontext.save()
    }
}

/// Übernimmt eine aus einer Tabelle kopierte Klassenliste.
struct SchuelerCSVImportView: View {
    @Bindable var klasse: Klasse
    @Environment(\.dismiss) private var schliessen
    @Environment(\.modelContext) private var kontext

    @State private var text = ""

    private var zeilen: [CSVSchuelerImport.Zeile] { CSVSchuelerImport.lese(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Klassenliste einfügen")
                .font(.title2.weight(.semibold))
            Text("Ein Kind pro Zeile, Vorname und Nachname durch Semikolon, Komma, Tabulator oder Leerzeichen getrennt.")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextEditor(text: $text)
                .font(.body.monospaced())
                .frame(height: 180)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))

            if zeilen.isEmpty {
                Text("Noch nichts erkannt.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                Text("\(zeilen.count) Kinder erkannt: \(zeilen.prefix(4).map(\.vorname).joined(separator: ", "))\(zeilen.count > 4 ? " …" : "")")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Abbrechen", role: .cancel) { schliessen() }
                Spacer()
                Button("\(zeilen.count) Kinder übernehmen") { uebernehmen() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(zeilen.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    private func uebernehmen() {
        var index = klasse.schueler.count
        for zeile in zeilen {
            let person = SchuelerIn(vorname: zeile.vorname, nachname: zeile.nachname, sortIndex: index)
            kontext.insert(person)
            person.klasse = klasse
            index += 1
        }
        try? kontext.save()
        schliessen()
    }
}
