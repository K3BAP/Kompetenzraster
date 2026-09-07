import Foundation

/// Die deutsche Notenskala 1–6.
///
/// Noten sind in dieser Version noch kein eigenes Modul; die Skala steht hier bereits fest,
/// damit spätere Notenvorschläge nicht neu verhandelt werden müssen.
enum Note: Int, CaseIterable, Identifiable, Sendable {
    case sehrGut = 1
    case gut = 2
    case befriedigend = 3
    case ausreichend = 4
    case mangelhaft = 5
    case ungenuegend = 6

    var id: Int { rawValue }

    var bezeichnung: String {
        switch self {
        case .sehrGut: "sehr gut"
        case .gut: "gut"
        case .befriedigend: "befriedigend"
        case .ausreichend: "ausreichend"
        case .mangelhaft: "mangelhaft"
        case .ungenuegend: "ungenügend"
        }
    }

    var beschriftung: String { "\(rawValue) – \(bezeichnung)" }
}
