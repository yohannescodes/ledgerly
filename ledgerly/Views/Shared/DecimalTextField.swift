import SwiftUI

struct DecimalTextField: View {
    let title: String
    @Binding var value: Decimal
    @State private var text: String

    init(title: String, value: Binding<Decimal>) {
        self.title = title
        _value = value
        _text = State(initialValue: DecimalTextField.format(value.wrappedValue))
    }

    var body: some View {
        TextField(title, text: $text)
            .keyboardType(.decimalPad)
            .onChange(of: text) { newValue in
                if newValue.isEmpty {
                    value = .zero
                } else if let decimal = Decimal(string: newValue, locale: Locale.current) {
                    value = decimal
                }
            }
            .onChange(of: value) { updated in
                let formatted = DecimalTextField.format(updated)
                if formatted != text {
                    text = formatted
                }
            }
    }

    private static func format(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        formatter.minimumFractionDigits = 0
        return formatter.string(from: value as NSNumber) ?? ""
    }
}
