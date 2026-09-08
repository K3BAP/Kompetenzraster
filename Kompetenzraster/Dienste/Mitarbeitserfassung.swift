import Foundation
import SwiftData

/// Legt Mitarbeitsbeobachtungen an und ändert sie – das Gegenstück zu ``Erfassung``.
enum Mitarbeitserfassung {
    /// Setzt eine Achse für ein Paar aus Stunde und Schüler:in.
    ///
    /// Es gibt genau einen Eintrag je Paar. Ein Eintrag, der nichts mehr trägt, wird gelöscht:
    /// sonst zählte die Quote „in x von y Stunden erfasst“ leere Zeilen mit.
    static func setze(
        _ stufe: Mitarbeitsstufe?,
        achse: Mitarbeitsachse,
        fuer schueler: SchuelerIn,
        in stunde: Mitarbeitsstunde,
        kontext: ModelContext
    ) {
        aendere(fuer: schueler, in: stunde, kontext: kontext) { eintrag in
            eintrag[achse] = stufe
            // Wer beobachtet wird, war offensichtlich da.
            if stufe != nil { eintrag.anwesend = true }
        }
    }

    static func setzeAnwesenheit(
        _ anwesend: Bool,
        fuer schueler: SchuelerIn,
        in stunde: Mitarbeitsstunde,
        kontext: ModelContext
    ) {
        aendere(fuer: schueler, in: stunde, kontext: kontext) { eintrag in
            eintrag.anwesend = anwesend
            // Was in einer Stunde beobachtet wurde, in der das Kind fehlte, war ein Versehen.
            if !anwesend {
                for achse in Mitarbeitsachse.allCases { eintrag[achse] = nil }
            }
        }
    }

    static func setzeNotiz(
        _ notiz: String,
        fuer schueler: SchuelerIn,
        in stunde: Mitarbeitsstunde,
        kontext: ModelContext
    ) {
        aendere(fuer: schueler, in: stunde, kontext: kontext) { $0.notiz = notiz }
    }

    /// Legt eine neue Stunde an. Das Datum wird auf den Tagesbeginn gelegt, damit Stunden
    /// desselben Tages beim Sortieren und Filtern zusammenbleiben.
    @discardableResult
    static func neueStunde(
        fuer klasse: Klasse,
        fach: String,
        datum: Date = Date(),
        thema: String = "",
        in kontext: ModelContext,
        kalender: Calendar = .current
    ) -> Mitarbeitsstunde {
        let stunde = Mitarbeitsstunde(
            datum: kalender.startOfDay(for: datum), fach: fach, thema: thema
        )
        kontext.insert(stunde)
        stunde.klasse = klasse
        try? kontext.save()
        return stunde
    }

    static func loesche(_ stunde: Mitarbeitsstunde, in kontext: ModelContext) {
        kontext.delete(stunde)   // Die Einträge hängen per Löschregel daran
        try? kontext.save()
    }

    private static func aendere(
        fuer schueler: SchuelerIn,
        in stunde: Mitarbeitsstunde,
        kontext: ModelContext,
        _ arbeit: (Mitarbeitseintrag) -> Void
    ) {
        let eintrag = stunde.eintrag(fuer: schueler) ?? {
            let neuer = Mitarbeitseintrag()
            kontext.insert(neuer)
            neuer.stunde = stunde
            neuer.schueler = schueler
            return neuer
        }()

        arbeit(eintrag)
        eintrag.geaendertAm = Date()
        if eintrag.istLeer { kontext.delete(eintrag) }
        try? kontext.save()
    }
}
