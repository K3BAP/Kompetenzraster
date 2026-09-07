import Foundation
import SwiftData

/// Ein Knoten im Kompetenzbaum: Bereich, Oberkompetenz oder Unterkompetenz.
///
/// Der Baum ist bewusst beliebig tief. Die mitgelieferten Vorlagen reichen bis zur
/// Oberkompetenz-Ebene; eigene Unterkompetenzen lassen sich jederzeit darunter ergänzen.
@Model
final class Kompetenz {
    var id: UUID = UUID()
    var titel: String = ""
    var beschreibung: String = ""
    /// Gliederungsnummer aus der Quelle, z. B. „4.2.1“.
    var code: String = ""
    /// Freitext wie „Ende Kl. 2“ – im Teilrahmenplan Mathematik als eigene Spalte geführt.
    var jahrgangsHinweis: String = ""
    var sortIndex: Int = 0

    var raster: Kompetenzraster?
    var eltern: Kompetenz?

    @Relationship(deleteRule: .cascade, inverse: \Kompetenz.eltern)
    var kinder: [Kompetenz] = []

    @Relationship(deleteRule: .cascade, inverse: \Eintrag.kompetenz)
    var eintraege: [Eintrag] = []

    init(
        id: UUID = UUID(),
        titel: String = "",
        beschreibung: String = "",
        code: String = "",
        jahrgangsHinweis: String = "",
        sortIndex: Int = 0
    ) {
        self.id = id
        self.titel = titel
        self.beschreibung = beschreibung
        self.code = code
        self.jahrgangsHinweis = jahrgangsHinweis
        self.sortIndex = sortIndex
    }

    var kinderSortiert: [Kompetenz] {
        kinder.sorted { $0.sortIndex < $1.sortIndex }
    }

    var istBlatt: Bool { kinder.isEmpty }

    /// Tiefe im Baum: 0 für einen Kompetenzbereich.
    var ebene: Int {
        var tiefe = 0
        var knoten = eltern
        while let aktuell = knoten {
            tiefe += 1
            knoten = aktuell.eltern
        }
        return tiefe
    }

    /// Der Pfad von der Wurzel bis zu diesem Knoten, für Breadcrumbs.
    var pfad: [Kompetenz] {
        var kette: [Kompetenz] = [self]
        var knoten = eltern
        while let aktuell = knoten {
            kette.insert(aktuell, at: 0)
            knoten = aktuell.eltern
        }
        return kette
    }

    /// Alle Blätter unterhalb dieses Knotens; er selbst, falls er ein Blatt ist.
    var blaetterImTeilbaum: [Kompetenz] {
        guard !kinder.isEmpty else { return [self] }
        return kinderSortiert.flatMap(\.blaetterImTeilbaum)
    }

    /// Verhindert Zyklen beim Verschieben im Editor.
    func istVorfahrVon(_ anderer: Kompetenz) -> Bool {
        var knoten = anderer.eltern
        while let aktuell = knoten {
            if aktuell.id == id { return true }
            knoten = aktuell.eltern
        }
        return false
    }
}
