import SwiftUI

extension Color {
    /// Erzeugt eine Farbe aus „#RRGGBB“. Bei unlesbarer Eingabe wird Grau verwendet,
    /// damit eine beschädigte Sicherung nie zu einer unsichtbaren Oberfläche führt.
    init(hex: String) {
        let bereinigt = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).uppercased()
        guard bereinigt.count == 6, let wert = UInt32(bereinigt, radix: 16) else {
            self = .gray
            return
        }
        self.init(
            .sRGB,
            red: Double((wert >> 16) & 0xFF) / 255,
            green: Double((wert >> 8) & 0xFF) / 255,
            blue: Double(wert & 0xFF) / 255
        )
    }

    /// Die Gegenrichtung – für den Farbwähler im Skala-Editor.
    var hexWert: String {
        let farbe = NSColor(self).usingColorSpace(.sRGB) ?? .gray
        return String(
            format: "#%02X%02X%02X",
            Int((farbe.redComponent * 255).rounded()),
            Int((farbe.greenComponent * 255).rounded()),
            Int((farbe.blueComponent * 255).rounded())
        )
    }
}
