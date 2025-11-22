import Foundation
import SwiftUI

enum CurrencyFormatter {
    static func string(for value: Decimal, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.string(from: value as NSNumber) ?? "--"
    }
}

extension Color {
    init?(hex: String) {
        var trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if trimmed.count == 3 {
            var expanded = ""
            for char in trimmed {
                expanded.append(char)
                expanded.append(char)
            }
            trimmed = expanded
        }
        guard trimmed.count == 6 || trimmed.count == 8 else { return nil }
        var int: UInt64 = 0
        guard Scanner(string: trimmed).scanHexInt64(&int) else { return nil }
        let a, r, g, b: UInt64
        if trimmed.count == 8 {
            a = int >> 24
            r = (int >> 16) & 0xff
            g = (int >> 8) & 0xff
            b = int & 0xff
        } else {
            a = 255
            r = (int >> 16) & 0xff
            g = (int >> 8) & 0xff
            b = int & 0xff
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
