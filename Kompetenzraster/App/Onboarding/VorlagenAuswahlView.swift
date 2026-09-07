import SwiftUI

/// Auswahl der mitgelieferten Raster – sowohl bei der Ersteinrichtung als auch später.
struct VorlagenAuswahlView: View {
    var mehrfachauswahl: Bool = false
    var beimUebernehmen: (String) -> Void

    @Environment(\.dismiss) private var schliessen
    @State private var gewaehlt: Set<String> = []

    private let vorlagen = VorlagenLader.alleVorlagen()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Kompetenzraster übernehmen")
                .font(.title2.weight(.semibold))
            Text("Grundlage sind die Teilrahmenpläne der Grundschule in Rheinland-Pfalz, gegliedert bis zur Ebene der Oberkompetenzen.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                ForEach(Array(vorlagen.enumerated()), id: \.element.fach) { index, vorlage in
                    if index > 0 { Divider() }
                    VorlagenZeile(
                        vorlage: vorlage,
                        gewaehlt: gewaehlt.contains(vorlage.fach)
                    ) {
                        if gewaehlt.contains(vorlage.fach) {
                            gewaehlt.remove(vorlage.fach)
                        } else {
                            if !mehrfachauswahl { gewaehlt.removeAll() }
                            gewaehlt.insert(vorlage.fach)
                        }
                    }
                }
            }
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))

            HStack {
                Button("Abbrechen", role: .cancel) { schliessen() }
                Spacer()
                Button("Übernehmen") {
                    for fach in vorlagen.map(\.fach) where gewaehlt.contains(fach) {
                        beimUebernehmen(fach)
                    }
                    schliessen()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(gewaehlt.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 540)
    }
}

struct VorlagenZeile: View {
    let vorlage: VorlagenDatei
    let gewaehlt: Bool
    let umschalten: () -> Void

    var body: some View {
        Button(action: umschalten) {
            HStack(spacing: 12) {
                Image(systemName: gewaehlt ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(gewaehlt ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                VStack(alignment: .leading, spacing: 2) {
                    Text(vorlage.name)
                        .font(.headline)
                    Text("\(vorlage.kompetenzen.count) Kompetenzbereiche · \(vorlage.anzahlKompetenzen) Kompetenzen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
