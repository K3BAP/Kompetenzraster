import Foundation
import SwiftData

/// Eine Unterrichtsstunde, nach der die Mitarbeit festgehalten wird.
///
/// Eine Stunde gehört zu einer Klasse und einem Fach – nicht zu einem Kompetenzraster, denn
/// Mitarbeit gibt es auch in Fächern, für die kein Raster angelegt ist. Mehrere Stunden am selben
/// Tag im selben Fach sind erlaubt (Doppelstunde).
@Model
final class Mitarbeitsstunde {
    var id: UUID = UUID()
    var datum: Date = Date()
    var fach: String = ""
    /// Kurzes Stundenthema, z. B. „Schriftliche Addition“ – der Anker fürs Elterngespräch.
    var thema: String = ""
    var erstelltAm: Date = Date()

    var klasse: Klasse?

    @Relationship(deleteRule: .cascade, inverse: \Mitarbeitseintrag.stunde)
    var eintraege: [Mitarbeitseintrag] = []

    init(
        id: UUID = UUID(),
        datum: Date = Date(),
        fach: String = "",
        thema: String = "",
        erstelltAm: Date = Date()
    ) {
        self.id = id
        self.datum = datum
        self.fach = fach
        self.thema = thema
        self.erstelltAm = erstelltAm
    }

    /// Kinder, zu denen etwas festgehalten wurde – Abwesenheit zählt mit.
    var anzahlErfasst: Int { eintraege.count }

    func eintrag(fuer schueler: SchuelerIn) -> Mitarbeitseintrag? {
        eintraege.first { $0.schueler?.id == schueler.id }
    }
}
