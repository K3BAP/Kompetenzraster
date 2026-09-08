import Foundation
import SwiftData

/// Gleicht ein vorhandenes Raster an die mitgelieferte Vorlage an.
///
/// Vorlagen werden beim Einfügen **kopiert**; ein Raster erfährt deshalb nichts davon, wenn die
/// Vorlage im Programm später wächst. Der Abgleich ergänzt fehlende Kompetenzen, zieht geänderte
/// Texte nach und lässt stehen, was die Lehrperson selbst hinzugefügt hat.
///
/// **Gelöscht wird nie.** An jeder Kompetenz können Bewertungen hängen, und eine Vorlage, die eine
/// Kompetenz nicht mehr führt, ist kein Grund, die Arbeit eines Schuljahres wegzuwerfen.
enum Vorlagenabgleich {
    /// Ein einzelner Punkt im Bericht – eine Zeile der Vorschau.
    struct Posten: Identifiable {
        let id = UUID()
        /// Die Ebenen darüber, z. B. „Allgemeine mathematische Kompetenzen › Darstellen“.
        let pfad: String
        let titel: String
        /// Bei geänderten Kompetenzen die betroffenen Felder, sonst leer.
        var felder: [String] = []
    }

    /// Was ein Abgleich verändern würde – vor dem Anwenden als Vorschau, danach als Rückmeldung.
    struct Bericht {
        var neue: [Posten] = []
        var geaenderte: [Posten] = []
        /// Eigene Ergänzungen, die die Vorlage nicht kennt; sie bleiben unangetastet.
        var eigene: [Posten] = []
        /// Bewertungen an Kompetenzen, die durch den Abgleich Unterkompetenzen bekommen.
        var verdeckteBewertungen = 0
        var quelleAendertSich = false

        var istLeer: Bool { neue.isEmpty && geaenderte.isEmpty && !quelleAendertSich }
    }

    /// Zeigt, was der Abgleich tun würde, ohne etwas zu ändern.
    static func bericht(fuer raster: Kompetenzraster, vorlage: VorlagenDatei) -> Bericht {
        var bericht = Bericht()
        bericht.quelleAendertSich = raster.quelle != vorlage.quellenangabe
        gleicheAb(
            vorlage: vorlage.kompetenzen, elternteil: nil, raster: raster,
            pfad: [], anwenden: false, kontext: nil, bericht: &bericht
        )
        return bericht
    }

    /// Führt den Abgleich durch und liefert denselben Bericht wie die Vorschau.
    @discardableResult
    static func wendeAn(
        _ vorlage: VorlagenDatei,
        auf raster: Kompetenzraster,
        in kontext: ModelContext
    ) -> Bericht {
        var bericht = Bericht()
        bericht.quelleAendertSich = raster.quelle != vorlage.quellenangabe
        gleicheAb(
            vorlage: vorlage.kompetenzen, elternteil: nil, raster: raster,
            pfad: [], anwenden: true, kontext: kontext, bericht: &bericht
        )
        raster.quelle = vorlage.quellenangabe
        try? kontext.save()
        return bericht
    }

    // MARK: - Baumdurchlauf

    /// Ein Durchlauf für Vorschau und Anwendung, damit die Vorschau nie etwas anderes zeigt,
    /// als hinterher geschieht.
    private static func gleicheAb(
        vorlage: [VorlagenKnoten],
        elternteil: Kompetenz?,
        raster: Kompetenzraster,
        pfad: [String],
        anwenden: Bool,
        kontext: ModelContext?,
        bericht: inout Bericht
    ) {
        let vorhanden = elternteil?.kinderSortiert ?? raster.wurzeln
        let (zuordnung, uebrig) = paare(vorlage: vorlage, vorhanden: vorhanden)
        let pfadText = pfad.joined(separator: " › ")

        for (index, knoten) in vorlage.enumerated() {
            guard let kompetenz = zuordnung[index] else {
                zaehleNeu(knoten, pfad: pfadText, in: &bericht)
                if anwenden, let kontext {
                    VorlagenLader.baue(
                        knoten, elternteil: elternteil, raster: raster, sortIndex: index, in: kontext
                    )
                }
                continue
            }

            let felder = unterschiede(zwischen: kompetenz, und: knoten)
            if !felder.isEmpty {
                bericht.geaenderte.append(
                    Posten(pfad: pfadText, titel: kompetenz.titel, felder: felder)
                )
            }
            let kinder = knoten.kinder ?? []
            if kompetenz.istBlatt, !kinder.isEmpty {
                bericht.verdeckteBewertungen += kompetenz.eintraege.count
            }
            let titelVorher = kompetenz.titel
            if anwenden {
                uebernimm(knoten, in: kompetenz)
                kompetenz.sortIndex = index
            }
            gleicheAb(
                vorlage: kinder, elternteil: kompetenz, raster: raster,
                pfad: pfad + [titelVorher], anwenden: anwenden, kontext: kontext, bericht: &bericht
            )
        }

        // Eigene Kompetenzen bleiben erhalten und rutschen hinter die der Vorlage.
        for (versatz, kompetenz) in uebrig.enumerated() {
            bericht.eigene.append(Posten(pfad: pfadText, titel: kompetenz.titel))
            if anwenden { kompetenz.sortIndex = vorlage.count + versatz }
        }
    }

    /// Ordnet die Knoten der Vorlage den vorhandenen Geschwistern zu: erst über die
    /// Gliederungsnummer, dann über den Titel. Zwei Durchgänge, damit eine umbenannte Kompetenz
    /// mit gleichbleibendem Code nicht als neu gilt – sonst entstünde ein Doppel.
    private static func paare(
        vorlage: [VorlagenKnoten],
        vorhanden: [Kompetenz]
    ) -> (zuordnung: [Int: Kompetenz], uebrig: [Kompetenz]) {
        var frei = vorhanden
        var zuordnung: [Int: Kompetenz] = [:]

        for (index, knoten) in vorlage.enumerated() {
            let code = schluessel(knoten.code ?? "")
            guard !code.isEmpty,
                  let treffer = frei.firstIndex(where: { schluessel($0.code) == code })
            else { continue }
            zuordnung[index] = frei.remove(at: treffer)
        }
        for (index, knoten) in vorlage.enumerated() where zuordnung[index] == nil {
            let titel = schluessel(knoten.titel)
            guard let treffer = frei.firstIndex(where: { schluessel($0.titel) == titel })
            else { continue }
            zuordnung[index] = frei.remove(at: treffer)
        }
        return (zuordnung, frei)
    }

    /// Groß-/Kleinschreibung und Leerraum sollen keinen Unterschied machen.
    private static func schluessel(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func unterschiede(
        zwischen kompetenz: Kompetenz,
        und knoten: VorlagenKnoten
    ) -> [String] {
        var felder: [String] = []
        if kompetenz.titel != knoten.titel { felder.append("Titel") }
        if kompetenz.beschreibung != knoten.beschreibung ?? "" { felder.append("Beschreibung") }
        if kompetenz.code != knoten.code ?? "" { felder.append("Gliederungsnummer") }
        if kompetenz.jahrgangsHinweis != knoten.jahrgangsHinweis ?? "" {
            felder.append("Jahrgangshinweis")
        }
        return felder
    }

    private static func uebernimm(_ knoten: VorlagenKnoten, in kompetenz: Kompetenz) {
        kompetenz.titel = knoten.titel
        kompetenz.beschreibung = knoten.beschreibung ?? ""
        kompetenz.code = knoten.code ?? ""
        kompetenz.jahrgangsHinweis = knoten.jahrgangsHinweis ?? ""
    }

    /// Ein neuer Knoten zählt mit seinem ganzen Teilbaum, denn der wird mit angelegt.
    private static func zaehleNeu(_ knoten: VorlagenKnoten, pfad: String, in bericht: inout Bericht) {
        bericht.neue.append(Posten(pfad: pfad, titel: knoten.titel))
        let tiefererPfad = pfad.isEmpty ? knoten.titel : "\(pfad) › \(knoten.titel)"
        for kind in knoten.kinder ?? [] {
            zaehleNeu(kind, pfad: tiefererPfad, in: &bericht)
        }
    }
}
