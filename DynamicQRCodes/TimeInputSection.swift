import SwiftUI

struct TimeInputSection: View {
    @Binding var timestampText: String
    @Binding var autoUpdate: Bool
    let focusedField: FocusState<InputField?>.Binding

    var body: some View {
        Section {
            LabeledFormField("Timestamp") {
                TextField("Timestamp", text: $timestampText)
                    .textContentType(.none)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .fontDesign(.monospaced)
                    .focused(focusedField, equals: .timestamp)
                    .accessibilityLabel("Timestamp")
                    .onChange(of: focusedField.wrappedValue) {
                        if focusedField.wrappedValue == .timestamp {
                            autoUpdate = false
                        }
                    }
                    .accessibilityHint("Local time format: year-month-day, hour-minute-second")
            }

            Toggle("Use device time", isOn: $autoUpdate)
        }
    }
}
