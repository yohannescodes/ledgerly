import SwiftUI

struct DecimalTextField: View {
    let title: String
    @Binding var value: Decimal
    @State private var text: String
    private let locale: Locale

    init(title: String, value: Binding<Decimal>, locale: Locale = .current) {
        self.title = title
        _value = value
        self.locale = locale
        _text = State(initialValue: DecimalTextField.format(value.wrappedValue, locale: locale))
    }

    var body: some View {
        TextField(title, text: $text)
            .keyboardType(.decimalPad)
            .onChange(of: text) { newValue in
                let sanitized = sanitize(newValue)
                guard sanitized == newValue else {
                    text = sanitized
                    return
                }

                if sanitized.isEmpty {
                    value = .zero
                } else if let decimal = Decimal(string: sanitized, locale: locale) {
                    value = decimal
                }
            }
            .onChange(of: value) { updated in
                let formatted = DecimalTextField.format(updated, locale: locale)
                if formatted != text {
                    text = formatted
                }
            }
    }

    private func sanitize(_ input: String) -> String {
        guard !input.isEmpty else { return "" }
        let decimalSeparator = locale.decimalSeparator ?? "."
        let groupingSeparator = locale.groupingSeparator ?? ","

        var normalized = input.replacingOccurrences(of: groupingSeparator, with: "")
        if decimalSeparator != "." {
            normalized = normalized.replacingOccurrences(of: ".", with: decimalSeparator)
        }
        if decimalSeparator != "," {
            normalized = normalized.replacingOccurrences(of: ",", with: decimalSeparator)
        }

        var result = ""
        var hasDecimalSeparator = false
        var hasSign = false

        for (index, character) in normalized.enumerated() {
            if character.isWholeNumber {
                result.append(character)
                continue
            }

            if String(character) == decimalSeparator {
                if !hasDecimalSeparator {
                    hasDecimalSeparator = true
                    result.append(character)
                }
                continue
            }

            if character == "-", index == 0, !hasSign {
                hasSign = true
                result.append(character)
            }
        }

        return result
    }

    private static func format(_ value: Decimal, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        return formatter.string(from: value as NSNumber) ?? ""
    }
}
