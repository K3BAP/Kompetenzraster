import Foundation

/// Der zusammengefasste Stand eines Teilbaums für eine Schülerin oder einen Schüler.
struct Auswertungsergebnis: Sendable {
    /// Mittelwert der Stufenwerte aller bewerteten Blattkompetenzen; `nil`, wenn nichts bewertet ist.
    var mittelwert: Double?
    var bewertet: Int
    var gesamt: Int

    var istLeer: Bool { mittelwert == nil }
    var anteilBewertet: Double { gesamt > 0 ? Double(bewertet) / Double(gesamt) : 0 }
}

enum Auswertung {
    /// Fasst alle Blattkompetenzen unterhalb von `kompetenz` für eine Schüler:in zusammen.
    ///
    /// Nur bewertete Blätter gehen in den Mittelwert ein – unbewertete Kompetenzen sollen den
    /// Stand nicht künstlich nach unten ziehen, sondern in der Blume als blasser Umriss erscheinen.
    static func ergebnis(fuer kompetenz: Kompetenz, schueler: SchuelerIn) -> Auswertungsergebnis {
        let blaetter = kompetenz.blaetterImTeilbaum
        let werte = blaetter.compactMap { blatt in
            eintrag(fuer: blatt, schueler: schueler)?.stufe?.wert
        }
        return Auswertungsergebnis(
            mittelwert: werte.isEmpty ? nil : Double(werte.reduce(0, +)) / Double(werte.count),
            bewertet: werte.count,
            gesamt: blaetter.count
        )
    }

    /// Das Ergebnis über ein ganzes Raster.
    static func ergebnis(fuer raster: Kompetenzraster, schueler: SchuelerIn) -> Auswertungsergebnis {
        let blaetter = raster.blattKompetenzen
        let werte = blaetter.compactMap { eintrag(fuer: $0, schueler: schueler)?.stufe?.wert }
        return Auswertungsergebnis(
            mittelwert: werte.isEmpty ? nil : Double(werte.reduce(0, +)) / Double(werte.count),
            bewertet: werte.count,
            gesamt: blaetter.count
        )
    }

    /// Der Eintrag einer Schüler:in zu genau einer Kompetenz, falls vorhanden.
    static func eintrag(fuer kompetenz: Kompetenz, schueler: SchuelerIn) -> Eintrag? {
        kompetenz.eintraege.first { $0.schueler?.id == schueler.id }
    }
}
