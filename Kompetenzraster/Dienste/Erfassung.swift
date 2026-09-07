import Foundation
import SwiftData

/// Legt Bewertungen an und ändert sie.
enum Erfassung {
    /// Setzt die Stufe für ein Paar aus Kompetenz und Schüler:in.
    ///
    /// Es gibt genau einen Eintrag je Paar; `stufe == nil` entfernt ihn wieder.
    static func setze(
        _ stufe: Bewertungsstufe?,
        fuer kompetenz: Kompetenz,
        schueler: SchuelerIn,
        in kontext: ModelContext
    ) {
        let vorhandener = Auswertung.eintrag(fuer: kompetenz, schueler: schueler)

        guard let stufe else {
            if let vorhandener { kontext.delete(vorhandener) }
            try? kontext.save()
            return
        }

        if let vorhandener {
            vorhandener.stufe = stufe
            vorhandener.geaendertAm = Date()
        } else {
            let neuer = Eintrag()
            kontext.insert(neuer)
            neuer.kompetenz = kompetenz
            neuer.schueler = schueler
            neuer.stufe = stufe
        }
        try? kontext.save()
    }

    static func setzeNotiz(
        _ notiz: String,
        fuer kompetenz: Kompetenz,
        schueler: SchuelerIn,
        in kontext: ModelContext
    ) {
        guard let eintrag = Auswertung.eintrag(fuer: kompetenz, schueler: schueler) else { return }
        eintrag.notiz = notiz
        eintrag.geaendertAm = Date()
        try? kontext.save()
    }
}
