import SwiftData
import SwiftUI

/// Die Kompetenzblume: je Kind des aktuellen Knotens ein Blütenblatt.
/// Je größer das Blatt, desto weiter ist die Kompetenz entwickelt.
struct KompetenzblumeView: View {
    let raster: Kompetenzraster
    let schueler: SchuelerIn
    @Binding var pfad: [UUID]

    /// Die Kompetenz, in die hineingezoomt wurde – `nil` ist die Rasterebene.
    private var aktuellerKnoten: Kompetenz? {
        guard let letzte = pfad.last else { return nil }
        return raster.kompetenzen.first { $0.id == letzte }
    }

    private var kinder: [Kompetenz] {
        aktuellerKnoten?.kinderSortiert ?? raster.wurzeln
    }

    private var skala: Bewertungsskala? { raster.skala }

    var body: some View {
        VStack(spacing: 0) {
            brotkrumen
            Divider()
            if kinder.isEmpty {
                LeerhinweisView(titel: "Hier gibt es nichts mehr aufzuschlüsseln", symbol: "leaf")
            } else {
                zeichenflaeche
            }
            Divider()
            legende
        }
    }

    // MARK: - Brotkrumen

    private var brotkrumen: some View {
        HStack(spacing: 6) {
            Button {
                pfad = []
            } label: {
                Text(raster.name).fontWeight(pfad.isEmpty ? .semibold : .regular)
            }
            .buttonStyle(.link)

            ForEach(Array(pfad.enumerated()), id: \.offset) { position, id in
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Button {
                    pfad = Array(pfad.prefix(position + 1))
                } label: {
                    Text(raster.kompetenzen.first { $0.id == id }?.titel ?? "…")
                        .fontWeight(position == pfad.count - 1 ? .semibold : .regular)
                }
                .buttonStyle(.link)
            }
            Spacer()
            if !pfad.isEmpty {
                Button {
                    pfad.removeLast()
                } label: {
                    Label("Eine Ebene zurück", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
            }
        }
        .lineLimit(1)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Blume

    private var zeichenflaeche: some View {
        GeometryReader { rahmen in
            let groesse = rahmen.size
            let mitte = CGPoint(x: groesse.width / 2, y: groesse.height / 2)
            let platz = min(groesse.width, groesse.height) / 2
            let innenradius = platz * 0.16
            let maximallaenge = platz * 0.62
            let blaetter = berechneBlaetter(
                mitte: mitte, innenradius: innenradius, maximallaenge: maximallaenge
            )

            ZStack {
                Canvas { kontext, _ in
                    for blatt in blaetter { zeichne(blatt, in: &kontext) }
                    zeichneMitte(in: &kontext, bei: mitte, radius: innenradius)
                }

                // Symbole und Beschriftungen als echte Ansichten, damit dieselbe
                // Symboldarstellung wie überall sonst gilt und Text sauber umbricht.
                ForEach(blaetter, id: \.kompetenz.id) { blatt in
                    if let stufe = blatt.stufe {
                        BewertungsSymbol(quelle: stufe.symbol, farbe: stufe.farbe, groesse: 22)
                            .padding(3)
                            .background(Circle().fill(.background).shadow(radius: 1))
                            .position(blatt.geometrie.spitze)
                            .help(stufe.name)
                    }

                    Text(blatt.kompetenz.titel)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(blatt.ergebnis.istLeer ? .secondary : .primary)
                        .frame(width: beschriftungsbreite(fuer: groesse))
                        .position(beschriftungsort(
                            fuer: blatt, maximallaenge: maximallaenge, in: groesse
                        ))
                        .help(hilfetext(fuer: blatt))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { tipp in
                    // Auf denselben Pfaden treffen, auf denen auch gezeichnet wurde.
                    guard let getroffen = blaetter.first(where: { $0.geometrie.pfad.contains(tipp.location) }),
                          !getroffen.kompetenz.istBlatt
                    else { return }
                    withAnimation(.snappy) { pfad.append(getroffen.kompetenz.id) }
                }
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func beschriftungsbreite(fuer groesse: CGSize) -> CGFloat {
        min(170, max(110, groesse.width * 0.24))
    }

    /// Hält die Beschriftung innerhalb der Zeichenfläche, damit nichts abgeschnitten wird.
    private func beschriftungsort(
        fuer blatt: BlattDarstellung,
        maximallaenge: CGFloat,
        in groesse: CGSize
    ) -> CGPoint {
        let roh = blatt.geometrie.beschriftungsort(maximallaenge: maximallaenge)
        let halbeBreite = beschriftungsbreite(fuer: groesse) / 2
        return CGPoint(
            x: min(max(roh.x, halbeBreite), groesse.width - halbeBreite),
            y: min(max(roh.y, 22), groesse.height - 22)
        )
    }

    private func hilfetext(fuer blatt: BlattDarstellung) -> String {
        let stand = blatt.stufe?.name ?? "noch nicht bewertet"
        let fortschritt = "\(blatt.ergebnis.bewertet) von \(blatt.ergebnis.gesamt) bewertet"
        let hinweis = blatt.kompetenz.istBlatt ? "" : "\nKlicken, um hineinzuzoomen"
        return "\(blatt.kompetenz.titel)\n\(stand) · \(fortschritt)\(hinweis)"
    }

    private struct BlattDarstellung {
        var kompetenz: Kompetenz
        var geometrie: Bluetenblatt
        var ergebnis: Auswertungsergebnis
        var farbe: Color
        var stufe: Bewertungsstufe?
    }

    private func berechneBlaetter(
        mitte: CGPoint,
        innenradius: CGFloat,
        maximallaenge: CGFloat
    ) -> [BlattDarstellung] {
        let anzahl = kinder.count
        let hoechster = Double(skala?.hoechsterWert ?? 1)
        let scheibe = 2 * Double.pi / Double(max(anzahl, 1))

        return kinder.enumerated().map { index, kind in
            let ergebnis = Auswertung.ergebnis(fuer: kind, schueler: schueler)
            // Oben beginnen und im Uhrzeigersinn weitergehen.
            let winkel = -Double.pi / 2 + scheibe * Double(index)

            let anteil = ergebnis.mittelwert.map { hoechster > 0 ? $0 / hoechster : 0 } ?? 0
            // Auch die schwächste Stufe bekommt ein sichtbares Blatt.
            let laenge = ergebnis.istLeer
                ? innenradius + (maximallaenge - innenradius) * 0.45
                : innenradius + (maximallaenge - innenradius) * (0.28 + 0.72 * anteil)

            let stufe = ergebnis.mittelwert.flatMap { skala?.stufe(fuerMittelwert: $0) }
            return BlattDarstellung(
                kompetenz: kind,
                geometrie: Bluetenblatt(
                    mitte: mitte,
                    winkel: winkel,
                    laenge: laenge,
                    oeffnung: scheibe * 0.78,
                    innenradius: innenradius
                ),
                ergebnis: ergebnis,
                farbe: stufe?.farbe ?? .secondary,
                stufe: stufe
            )
        }
    }

    private func zeichne(_ blatt: BlattDarstellung, in kontext: inout GraphicsContext) {
        let pfad = blatt.geometrie.pfad
        if blatt.ergebnis.istLeer {
            kontext.stroke(pfad, with: .color(.secondary.opacity(0.35)),
                           style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        } else {
            kontext.fill(pfad, with: .color(blatt.farbe.opacity(0.78)))
            kontext.stroke(pfad, with: .color(blatt.farbe), lineWidth: 1.5)
        }
    }

    private func zeichneMitte(in kontext: inout GraphicsContext, bei mitte: CGPoint, radius: CGFloat) {
        let gesamt = aktuellerKnoten.map { Auswertung.ergebnis(fuer: $0, schueler: schueler) }
            ?? Auswertung.ergebnis(fuer: raster, schueler: schueler)

        kontext.fill(
            Path(ellipseIn: CGRect(x: mitte.x - radius, y: mitte.y - radius,
                                   width: radius * 2, height: radius * 2)),
            with: .color(.secondary.opacity(0.12))
        )
        let text = gesamt.istLeer ? "–" : "\(gesamt.bewertet)/\(gesamt.gesamt)"
        kontext.draw(
            kontext.resolve(Text(text).font(.caption.weight(.semibold)).foregroundColor(.secondary)),
            at: mitte
        )
    }

    // MARK: - Legende

    private var legende: some View {
        HStack(spacing: 16) {
            ForEach(skala?.stufenSortiert ?? []) { stufe in
                HStack(spacing: 5) {
                    BewertungsSymbol(quelle: stufe.symbol, farbe: stufe.farbe, groesse: 16)
                    Text(stufe.name).font(.caption)
                }
            }
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
                    .frame(width: 14, height: 10)
                Text("noch nicht bewertet").font(.caption)
            }
            Spacer()
            Text("Je größer das Blatt, desto weiter entwickelt")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}
