import SwiftUI

/// Schmaler Streifen über dem Hauptfenster: meldet eine neue Fassung – und ebenso,
/// dass eine von Hand angestoßene Suche gelaufen ist. Ohne das Zweite sähe ein Klick
/// auf „Nach Aktualisierungen suchen“ so aus, als sei nichts passiert.
struct AktualisierungsHinweisView: View {
    let pruefer: Aktualisierungspruefer

    @Environment(\.openURL) private var oeffne

    var body: some View {
        HStack(spacing: 12) {
            zeichen
            VStack(alignment: .leading, spacing: 1) {
                Text(titel)
                    .font(.callout.weight(.medium))
                if let unterzeile {
                    Text(unterzeile)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            aktionen
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(untergrund)
        .overlay(alignment: .bottom) { Divider() }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Bestandteile je Zustand

    @ViewBuilder
    private var zeichen: some View {
        switch pruefer.stand {
        case .laeuft:
            ProgressView().controlSize(.small)
        case .aktuell:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .fehler:
            Image(systemName: "wifi.exclamationmark").foregroundStyle(.orange)
        case .neueVersion:
            Image(systemName: "arrow.down.circle.fill").foregroundStyle(.tint)
        case .ruhend:
            EmptyView()
        }
    }

    private var titel: String {
        switch pruefer.stand {
        case .laeuft: "Suche nach Aktualisierungen …"
        case .aktuell: "Kompetenzraster ist auf dem neuesten Stand"
        case .fehler: "Nach Aktualisierungen konnte nicht gesucht werden"
        case .neueVersion(let manifest): "Version \(manifest.version) ist verfügbar"
        case .ruhend: ""
        }
    }

    private var unterzeile: String? {
        switch pruefer.stand {
        case .laeuft, .ruhend:
            return nil
        case .aktuell:
            return "Installiert: \(pruefer.eigeneBeschriftung)"
        case .fehler(let text):
            return text
        case .neueVersion(let manifest):
            let hinweise = manifest.hinweise.flatMap { $0.isEmpty ? nil : $0 }
            return hinweise ?? "Installiert: \(pruefer.eigeneBeschriftung)"
        }
    }

    /// Nur was eine Handlung nahelegt, bekommt Farbe. Die Bestätigung bleibt neutral –
    /// sonst sähe sie auf grünem Grund genauso aus wie ein verfügbares Update.
    private var untergrund: Color {
        switch pruefer.stand {
        case .neueVersion: .accentColor.opacity(0.14)
        case .fehler: .orange.opacity(0.12)
        case .aktuell, .laeuft, .ruhend: .secondary.opacity(0.10)
        }
    }

    @ViewBuilder
    private var aktionen: some View {
        switch pruefer.stand {
        case .neueVersion:
            Button("Herunterladen") { oeffne(Veroeffentlichung.releaseSeite) }
                .buttonStyle(.borderedProminent)
            Button("Später") { pruefer.spaeter() }
                .buttonStyle(.borderless)

        case .fehler:
            Button("Erneut versuchen") {
                Task { await pruefer.pruefe(erzwungen: true) }
            }
            schliessen

        case .aktuell:
            schliessen

        case .laeuft, .ruhend:
            EmptyView()
        }
    }

    private var schliessen: some View {
        Button {
            pruefer.rueckmeldungSchliessen()
        } label: {
            Image(systemName: "xmark")
                .font(.caption.weight(.semibold))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help("Ausblenden")
    }
}
