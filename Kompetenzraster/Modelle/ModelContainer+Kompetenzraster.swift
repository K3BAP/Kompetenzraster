import Foundation
import SwiftData

/// Zentrale Beschreibung des Datenbestands.
enum Datenbestand {
    static let alleModelle: [any PersistentModel.Type] = [
        Klasse.self,
        SchuelerIn.self,
        Kompetenzraster.self,
        Kompetenz.self,
        Bewertungsskala.self,
        Bewertungsstufe.self,
        Eintrag.self,
        AppEinstellungen.self,
    ]

    static var schema: Schema { Schema(alleModelle) }

    /// Der Container der App. `imArbeitsspeicher` wird von den Tests genutzt.
    static func container(imArbeitsspeicher: Bool = false) throws -> ModelContainer {
        let konfiguration = ModelConfiguration(
            "Kompetenzraster",
            schema: schema,
            isStoredInMemoryOnly: imArbeitsspeicher
        )
        return try ModelContainer(for: schema, configurations: konfiguration)
    }
}

extension ModelContext {
    /// Liefert den Einstellungsdatensatz und legt ihn beim ersten Aufruf an.
    func einstellungen() throws -> AppEinstellungen {
        let vorhandene = try fetch(FetchDescriptor<AppEinstellungen>())
        if let erste = vorhandene.first { return erste }
        let neue = AppEinstellungen()
        insert(neue)
        try save()
        return neue
    }

    /// Löscht sämtliche Inhalte – Grundlage für „Backup ersetzend importieren“.
    func alleDatenLoeschen() throws {
        try delete(model: Eintrag.self)
        try delete(model: Kompetenz.self)
        try delete(model: Kompetenzraster.self)
        try delete(model: SchuelerIn.self)
        try delete(model: Klasse.self)
        try delete(model: Bewertungsstufe.self)
        try delete(model: Bewertungsskala.self)
        try save()
    }
}
