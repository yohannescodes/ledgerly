import SwiftUI

struct DecimalTextField: View {
    let title: String
    @Binding var value: Decimal
    @State private var text: String = ""

    var body: some View {
        TextField(title, text: Binding(
            get: {
                if text.isEmpty {
                    return value == .zero ? "" : NSDecimalNumber(decimal: value).stringValue
                }
                return text
            },
            set: { newValue in
                text = newValue
                if let decimal = Decimal(string: newValue) {
                    value = decimal
                }
            }
        ))
        .keyboardType(.decimalPad)
    }
}
