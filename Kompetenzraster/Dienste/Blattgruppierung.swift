import Foundation

/// Die Blätter eines Kompetenzbereichs, zusammengefasst nach ihrem Elternknoten.
///
/// `titel` ist `nil`, wenn die Blätter direkt unter dem Bereich hängen – dann braucht der
/// Erfassungsbogen keine Zwischenüberschrift.
struct Blattgruppe: Identifiable, Equatable {
    let id: UUID
    let titel: String?
    var blaetter: [Kompetenz]

    static func == (links: Blattgruppe, rechts: Blattgruppe) -> Bool {
        links.id == rechts.id
            && links.titel == rechts.titel
            && links.blaetter.map(\.id) == rechts.blaetter.map(\.id)
    }
}

extension Kompetenz {
    /// Gliedert die Blätter dieses Bereichs für die zeilenweise Darstellung.
    ///
    /// Zweistufige Raster (Deutsch, Sachunterricht) ergeben genau eine Gruppe ohne Titel,
    /// dreistufige (Mathematik) je Oberkompetenz eine mit Zwischenüberschrift. Die Reihenfolge
    /// der Blätter bleibt die des Baums, es wird nur zusammengefasst, was aufeinanderfolgt.
    var blattgruppen: [Blattgruppe] {
        var ergebnis: [Blattgruppe] = []
        for blatt in blaetterImTeilbaum {
            let elter = blatt.eltern
            let schluessel = elter?.id ?? id
            if ergebnis.last?.id == schluessel {
                ergebnis[ergebnis.count - 1].blaetter.append(blatt)
            } else {
                let titel = (elter == nil || elter?.id == id) ? nil : elter?.titel
                ergebnis.append(Blattgruppe(id: schluessel, titel: titel, blaetter: [blatt]))
            }
        }
        return ergebnis
    }
}
