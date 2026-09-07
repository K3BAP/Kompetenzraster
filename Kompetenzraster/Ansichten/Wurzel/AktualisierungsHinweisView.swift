import SwiftUI

/// Schmaler Streifen über dem Hauptfenster, wenn eine neue Fassung bereitliegt.
struct AktualisierungsHinweisView: View {
    var manifest: Versionsmanifest
    var spaeter: () -> Void

    @Environment(\.openURL) private var oeffne

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("Version \(manifest.version) ist verfügbar")
                    .font(.callout.weight(.medium))
                if let hinweise = manifest.hinweise, !hinweise.isEmpty {
                    Text(hinweise)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Button("Herunterladen") { oeffne(Veroeffentlichung.releaseSeite) }
                .buttonStyle(.borderedProminent)
            Button("Später", action: spaeter)
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.tint.opacity(0.12))
        .overlay(alignment: .bottom) { Divider() }
    }
}
