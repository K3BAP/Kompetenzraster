import LocalAuthentication
import SwiftUI

/// Entsperrt die App per Touch ID oder Anmeldepasswort.
enum AppSperre {
    /// Ob dieser Mac überhaupt eine biometrische oder Passwort-Prüfung anbietet.
    static var verfuegbar: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    static func entsperren() async -> Bool {
        let kontext = LAContext()
        kontext.localizedCancelTitle = "Abbrechen"
        guard kontext.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            // Ohne Prüfmöglichkeit würde die Sperre die Lehrperson aus ihren eigenen Daten aussperren.
            return true
        }
        return (try? await kontext.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Kompetenzraster enthält Daten deiner Schüler:innen."
        )) ?? false
    }
}

struct SperrbildschirmView: View {
    @Binding var entsperrt: Bool
    @State private var laeuft = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 52))
                .foregroundStyle(.tint)
            Text("Kompetenzraster ist gesperrt")
                .font(.title2.weight(.semibold))
            Text("Diese Daten sind besonders schützenswert.")
                .foregroundStyle(.secondary)
            Button("Entsperren") {
                laeuft = true
                Task {
                    entsperrt = await AppSperre.entsperren()
                    laeuft = false
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(laeuft)
        }
        .padding(48)
        .frame(minWidth: 480, minHeight: 360)
    }
}
