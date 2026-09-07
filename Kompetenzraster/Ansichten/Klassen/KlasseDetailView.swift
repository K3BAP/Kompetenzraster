import SwiftData
import SwiftUI

struct KlasseDetailView: View {
    @Bindable var klasse: Klasse
    @Environment(\.modelContext) private var kontext

    private enum Bereich: String, CaseIterable, Identifiable {
        case schueler = "Schüler:innen"
        case erfassung = "Erfassung"
        case blume = "Kompetenzblume"
        var id: String { rawValue }
    }

    @State private var bereich: Bereich = .schueler
    @State private var bearbeiten = false
    @State private var gewaehltesRasterID: UUID?

    private var zugeordneteRaster: [Kompetenzraster] {
        klasse.raster.sorted { $0.name < $1.name }
    }

    private var gewaehltesRaster: Kompetenzraster? {
        zugeordneteRaster.first { $0.id == gewaehltesRasterID } ?? zugeordneteRaster.first
    }

    var body: some View {
        VStack(spacing: 0) {
            kopfzeile
            Divider()
            inhalt
        }
        .sheet(isPresented: $bearbeiten) {
            KlasseBearbeitenView(klasse: klasse)
        }
        .onAppear {
            if gewaehltesRasterID == nil { gewaehltesRasterID = zugeordneteRaster.first?.id }
        }
    }

    private var kopfzeile: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(klasse.name)
                    .font(.largeTitle.weight(.semibold))
                Text("\(klasse.jahrgangsstufe). Jahrgangsstufe · \(klasse.schuljahr)")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Bearbeiten") { bearbeiten = true }
            }

            HStack {
                Picker("", selection: $bereich) {
                    ForEach(Bereich.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                if bereich != .schueler, zugeordneteRaster.count > 1 {
                    Picker("Raster", selection: Binding(
                        get: { gewaehltesRaster?.id },
                        set: { gewaehltesRasterID = $0 }
                    )) {
                        ForEach(zugeordneteRaster) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .fixedSize()
                }
                Spacer()
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private var inhalt: some View {
        switch bereich {
        case .schueler:
            SchuelerListeView(klasse: klasse)
        case .erfassung:
            if let raster = gewaehltesRaster {
                RasterMatrixView(klasse: klasse, raster: raster)
            } else {
                rasterFehltHinweis
            }
        case .blume:
            if let raster = gewaehltesRaster {
                BlumeBereichView(klasse: klasse, raster: raster)
            } else {
                rasterFehltHinweis
            }
        }
    }

    private var rasterFehltHinweis: some View {
        LeerhinweisView(
            titel: "Dieser Klasse ist noch kein Kompetenzraster zugeordnet",
            symbol: "square.grid.3x3",
            beschreibung: "Ordne unter „Schüler:innen“ ein Raster zu, dann kannst du hier Lernfortschritte festhalten."
        )
    }
}
