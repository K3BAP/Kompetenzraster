import SwiftData
import SwiftUI

/// Links die Kinder der Klasse, rechts die Blume der gewählten Person.
struct BlumeBereichView: View {
    @Bindable var klasse: Klasse
    @Bindable var raster: Kompetenzraster

    @State private var schuelerID: UUID?
    @State private var drilldown: [UUID] = []

    private var kinder: [SchuelerIn] { klasse.schuelerSortiert }
    private var gewaehlt: SchuelerIn? {
        kinder.first { $0.id == schuelerID } ?? kinder.first
    }

    var body: some View {
        HSplitView {
            liste
                .frame(minWidth: 180, maxWidth: 260)
            if let gewaehlt {
                KompetenzblumeView(raster: raster, schueler: gewaehlt, pfad: $drilldown)
                    .frame(minWidth: 360)
                    .id(gewaehlt.id)
            } else {
                LeerhinweisView(
                    titel: "Diese Klasse hat noch keine Kinder",
                    symbol: "person.badge.plus"
                )
                .frame(minWidth: 360)
            }
        }
        .onChange(of: schuelerID) { drilldown = [] }
    }

    private var liste: some View {
        List(selection: $schuelerID) {
            ForEach(kinder) { kind in
                let ergebnis = Auswertung.ergebnis(fuer: raster, schueler: kind)
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(kind.vollerName)
                        Text("\(ergebnis.bewertet) von \(ergebnis.gesamt) bewertet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StufenSymbol(
                        stufe: ergebnis.mittelwert.flatMap { raster.skala?.stufe(fuerMittelwert: $0) },
                        groesse: 20
                    )
                }
                .tag(kind.id)
            }
        }
        .listStyle(.inset)
    }
}
