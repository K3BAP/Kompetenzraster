import Foundation

/// Liest Klassenlisten, wie sie aus Tabellenprogrammen kopiert werden.
enum CSVSchuelerImport {
    struct Zeile: Equatable, Identifiable {
        let id = UUID()
        var vorname: String
        var nachname: String

        static func == (links: Zeile, rechts: Zeile) -> Bool {
            links.vorname == rechts.vorname && links.nachname == rechts.nachname
        }
    }

    /// Erkennt Semikolon, Komma und Tabulator; ohne Trennzeichen gilt das letzte Wort als Nachname.
    static func lese(_ text: String) -> [Zeile] {
        text.split(whereSeparator: \.isNewline)
            .compactMap { zeile -> Zeile? in
                let roh = String(zeile).trimmingCharacters(in: .whitespaces)
                guard !roh.isEmpty else { return nil }

                let felder: [String]
                if let trenner = [";", "\t", ","].first(where: { roh.contains($0) }) {
                    felder = roh.components(separatedBy: trenner)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                } else {
                    let woerter = roh.split(separator: " ").map(String.init)
                    guard woerter.count > 1 else { return Zeile(vorname: roh, nachname: "") }
                    felder = [woerter.dropLast().joined(separator: " "), woerter[woerter.count - 1]]
                }

                let vorname = felder.first ?? ""
                let nachname = felder.count > 1 ? felder[1] : ""
                guard !vorname.isEmpty else { return nil }
                return Zeile(vorname: vorname, nachname: nachname)
            }
            .filter { !istKopfzeile($0) }
    }

    /// Eine übernommene Kopfzeile würde als Kind namens „Vorname Nachname“ in der Klasse landen.
    private static func istKopfzeile(_ zeile: Zeile) -> Bool {
        let vorname = zeile.vorname.lowercased()
        let nachname = zeile.nachname.lowercased()
        return ["vorname", "first name", "name"].contains(vorname)
            && ["nachname", "last name", "familienname", ""].contains(nachname)
    }
}
