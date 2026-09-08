import Charts
import SwiftData
import SwiftUI

/// Was über ein Halbjahr zusammengekommen ist: Mittelwerte, Quote und der Verlauf je Kind.
struct MitarbeitVerlaufView: View {
    @Bindable var klasse: Klasse
    let fach: String

    @State private var halbjahr: Halbjahr = .ganzesJahr
    @State private var schuelerID: UUID?

    private var stunden: [Mitarbeitsstunde] {
        Mitarbeitsauswertung.stunden(
            in: klasse, fach: fach,
            zeitraum: halbjahr.zeitraum(imSchuljahr: klasse.schuljahr)
        )
    }

    private var kinder: [SchuelerIn] { klasse.schuelerSortiert }
    private var gewaehltesKind: SchuelerIn? { kinder.first { $0.id == schuelerID } }

    private let randAussen: CGFloat = 20
    private let achsenBreite: CGFloat = 132

    var body: some View {
        VStack(spacing: 0) {
            kopf
            Divider()
            if stunden.isEmpty {
                LeerhinweisView(
                    titel: "In diesem Zeitraum wurde noch nichts festgehalten",
                    symbol: "chart.xyaxis.line",
                    beschreibung: "Trage unter „Stunde erfassen“ ein, wie die Kinder mitgearbeitet haben."
                )
            } else {
                spaltenkopf
                Divider()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(kinder) { kind in
                            zeile(fuer: kind)
                            Divider().padding(.leading, randAussen)
                        }
                    }
                }
                if let kind = gewaehltesKind {
                    Divider()
                    diagramm(fuer: kind)
                }
            }
        }
    }

    private var kopf: some View {
        HStack(spacing: 12) {
            Picker("", selection: $halbjahr) {
                ForEach(Halbjahr.allCases) { Text($0.titel).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            Text(klasse.schuljahr)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(stunden.count) \(stunden.count == 1 ? "Stunde" : "Stunden") in \(fach)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, randAussen)
        .padding(.vertical, 10)
    }

    private var spaltenkopf: some View {
        HStack(spacing: 0) {
            Text("Kind")
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Mitarbeitsachse.allCases) { achse in
                Text(achse.titel)
                    .frame(width: achsenBreite, alignment: .leading)
                    .help(achse.erklaerung)
            }
            Text("erfasst")
                .frame(width: 92, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, randAussen)
        .padding(.vertical, 8)
    }

    private func zeile(fuer kind: SchuelerIn) -> some View {
        let ergebnis = Mitarbeitsauswertung.ergebnis(fuer: kind, stunden: stunden)
        let gewaehlt = kind.id == schuelerID
        return Button {
            schuelerID = gewaehlt ? nil : kind.id
        } label: {
            HStack(spacing: 0) {
                Text(kind.vollerName.isEmpty ? kind.kuerzel : kind.vollerName)
                    .font(.callout)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(Mitarbeitsachse.allCases) { achse in
                    achsenzelle(ergebnis: ergebnis, achse: achse)
                        .frame(width: achsenBreite, alignment: .leading)
                }

                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(ergebnis.erfassteStunden)/\(ergebnis.stundenGesamt - ergebnis.fehlzeiten)")
                        .font(.caption.monospacedDigit())
                    if ergebnis.fehlzeiten > 0 {
                        Text("\(ergebnis.fehlzeiten)× gefehlt")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .trailing)
            }
            .padding(.horizontal, randAussen)
            .padding(.vertical, 7)
            .background(gewaehlt ? Color.accentColor.opacity(0.12) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func achsenzelle(ergebnis: Mitarbeitsergebnis, achse: Mitarbeitsachse) -> some View {
        if let mittel = ergebnis.mittelwert(achse) {
            let stufe = Mitarbeitsstufe.fuer(mittelwert: mittel)
            HStack(spacing: 6) {
                Fortschrittsbalken(anteil: mittel / 3, farbe: stufe.farbe)
                    .frame(width: 46)
                Text(String(format: "%.1f", mittel + 1))
                    .font(.caption.monospacedDigit())
                trendzeichen(ergebnis.trend(achse))
            }
            .help("\(achse.titel): \(achse.name(fuer: stufe))")
        } else {
            Text("–")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    /// Zweite Hälfte des Zeitraums gegen die erste – nur deutliche Unterschiede werden gezeigt.
    @ViewBuilder
    private func trendzeichen(_ trend: Double?) -> some View {
        if let trend, abs(trend) >= 0.25 {
            Image(systemName: trend > 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(trend > 0 ? Color.green : Color.orange)
                .help(trend > 0 ? "Steigend im Zeitraum" : "Fallend im Zeitraum")
        }
    }

    private func diagramm(fuer kind: SchuelerIn) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Verlauf – \(kind.vollerName)")
                    .font(.headline)
                Spacer()
                Button("Schließen") { schuelerID = nil }
                    .buttonStyle(.link)
            }
            Chart {
                ForEach(Mitarbeitsachse.allCases) { achse in
                    ForEach(Mitarbeitsauswertung.verlauf(fuer: kind, achse: achse, stunden: stunden)) { punkt in
                        LineMark(
                            x: .value("Datum", punkt.datum),
                            y: .value("Stufe", punkt.wert + 1),
                            series: .value("Achse", achse.titel)
                        )
                        .foregroundStyle(by: .value("Achse", achse.titel))
                        .interpolationMethod(.monotone)

                        PointMark(
                            x: .value("Datum", punkt.datum),
                            y: .value("Stufe", punkt.wert + 1)
                        )
                        .foregroundStyle(by: .value("Achse", achse.titel))
                    }
                }
            }
            .chartYScale(domain: 0.6 ... 4.4)
            .chartYAxis {
                AxisMarks(values: [1, 2, 3, 4]) { wert in
                    AxisGridLine()
                    AxisValueLabel {
                        if let stufe = wert.as(Int.self) { Text("\(stufe)") }
                    }
                }
            }
            .chartLegend(position: .bottom)
            .frame(height: 180)
        }
        .padding(.horizontal, randAussen)
        .padding(.vertical, 12)
    }
}
