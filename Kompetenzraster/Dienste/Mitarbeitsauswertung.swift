import Foundation

/// Der Zeitraum, über den Mitarbeit ausgewertet wird.
///
/// Zeugnisse und Elterngespräche hängen am Halbjahr, deshalb ist das die Grundeinheit.
/// Ein Schuljahr beginnt im August; das erste Halbjahr endet mit dem Januar.
enum Halbjahr: String, CaseIterable, Identifiable, Sendable {
    case erstes
    case zweites
    case ganzesJahr

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .erstes: "1. Halbjahr"
        case .zweites: "2. Halbjahr"
        case .ganzesJahr: "Ganzes Schuljahr"
        }
    }

    /// Halboffener Zeitraum: der letzte Tag gehört noch dazu, der erste des nächsten nicht mehr.
    func zeitraum(imSchuljahr bezeichnung: String, kalender: Calendar = .current) -> Range<Date>? {
        guard let start = Schuljahr.startjahr(aus: bezeichnung) else { return nil }
        switch self {
        case .erstes: return tag(start, 8, kalender) ..< tag(start + 1, 2, kalender)
        case .zweites: return tag(start + 1, 2, kalender) ..< tag(start + 1, 8, kalender)
        case .ganzesJahr: return tag(start, 8, kalender) ..< tag(start + 1, 8, kalender)
        }
    }

    private func tag(_ jahr: Int, _ monat: Int, _ kalender: Calendar) -> Date {
        kalender.date(from: DateComponents(year: jahr, month: monat, day: 1)) ?? .distantPast
    }
}

/// Eine einzelne Beobachtung im Zeitverlauf – ein Punkt im Diagramm.
struct Verlaufspunkt: Identifiable, Sendable {
    /// Die Stunde, aus der die Beobachtung stammt; je Achse eindeutig.
    let id: UUID
    let datum: Date
    let wert: Int
}

/// Der Stand eines Kindes über einen Zeitraum.
struct Mitarbeitsergebnis: Sendable {
    /// Mittelwert je Achse; eine Achse fehlt, wenn sie nie beobachtet wurde.
    var mittelwerte: [Mitarbeitsachse: Double] = [:]
    /// Wie sich die Achse innerhalb des Zeitraums verändert hat: zweite Hälfte minus erste.
    var trends: [Mitarbeitsachse: Double] = [:]
    /// Stunden, in denen zu diesem Kind etwas beobachtet wurde.
    var erfassteStunden = 0
    var stundenGesamt = 0
    var fehlzeiten = 0

    func mittelwert(_ achse: Mitarbeitsachse) -> Double? { mittelwerte[achse] }
    func trend(_ achse: Mitarbeitsachse) -> Double? { trends[achse] }

    var istLeer: Bool { mittelwerte.isEmpty }

    /// Mittel über alle beobachteten Achsen – die eine Zahl für die Klassenübersicht.
    var gesamtmittel: Double? {
        let werte = Array(mittelwerte.values)
        return werte.isEmpty ? nil : werte.reduce(0, +) / Double(werte.count)
    }

    /// Anteil der Stunden mit Beobachtung, ohne die Fehlzeiten.
    var quote: Double {
        let moeglich = stundenGesamt - fehlzeiten
        return moeglich > 0 ? Double(erfassteStunden) / Double(moeglich) : 0
    }
}

/// Rechnet Beobachtungen zu Mittelwerten und Verläufen zusammen.
///
/// Wie bei ``Auswertung`` gilt: Was nicht beobachtet wurde, zieht den Stand nicht nach unten.
/// Stunden, in denen das Kind fehlte, zählen weder in den Mittelwert noch in die Quote.
enum Mitarbeitsauswertung {
    static func stunden(
        in klasse: Klasse,
        fach: String,
        zeitraum: Range<Date>?
    ) -> [Mitarbeitsstunde] {
        klasse.stunden(fach: fach).filter { zeitraum?.contains($0.datum) ?? true }
    }

    static func ergebnis(fuer schueler: SchuelerIn, stunden: [Mitarbeitsstunde]) -> Mitarbeitsergebnis {
        var ergebnis = Mitarbeitsergebnis()
        ergebnis.stundenGesamt = stunden.count

        let eintraege = stunden.compactMap { $0.eintrag(fuer: schueler) }
        ergebnis.fehlzeiten = eintraege.count { !$0.anwesend }
        ergebnis.erfassteStunden = eintraege.count { eintrag in
            eintrag.anwesend && Mitarbeitsachse.allCases.contains { eintrag[$0] != nil }
        }

        for achse in Mitarbeitsachse.allCases {
            let werte = verlauf(fuer: schueler, achse: achse, stunden: stunden).map { Double($0.wert) }
            guard !werte.isEmpty else { continue }
            ergebnis.mittelwerte[achse] = mittel(werte)
            if let trend = trend(werte) { ergebnis.trends[achse] = trend }
        }
        return ergebnis
    }

    /// Die einzelnen Beobachtungen einer Achse in zeitlicher Reihenfolge – die Punkte im Diagramm.
    static func verlauf(
        fuer schueler: SchuelerIn,
        achse: Mitarbeitsachse,
        stunden: [Mitarbeitsstunde]
    ) -> [Verlaufspunkt] {
        sortiert(stunden).compactMap { stunde in
            guard let eintrag = stunde.eintrag(fuer: schueler), eintrag.anwesend,
                  let stufe = eintrag[achse]
            else { return nil }
            return Verlaufspunkt(id: stunde.id, datum: stunde.datum, wert: stufe.rawValue)
        }
    }

    /// Älteste zuerst – Verlauf und Trend lesen sich von links nach rechts.
    static func sortiert(_ stunden: [Mitarbeitsstunde]) -> [Mitarbeitsstunde] {
        stunden.sorted { ($0.datum, $0.erstelltAm) < ($1.datum, $1.erstelltAm) }
    }

    /// Zweite Hälfte der Beobachtungen minus erste. Bei einer einzelnen Beobachtung gibt es
    /// keine Entwicklung zu zeigen, dann `nil`.
    private static func trend(_ werte: [Double]) -> Double? {
        guard werte.count >= 2 else { return nil }
        let mitte = werte.count / 2
        // Bei ungerader Anzahl bleibt die mittlere Beobachtung außen vor, statt eine Hälfte zu kippen.
        let frueh = Array(werte.prefix(mitte))
        let spaet = Array(werte.suffix(mitte))
        return mittel(spaet) - mittel(frueh)
    }

    private static func mittel(_ werte: [Double]) -> Double {
        werte.reduce(0, +) / Double(werte.count)
    }
}
