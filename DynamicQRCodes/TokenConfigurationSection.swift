import SwiftUI

struct TokenConfigurationSection: View {
    @Binding var form: GeneratorFormState
    @Binding var isSecretVisible: Bool
    let focusedField: FocusState<InputField?>.Binding

    var body: some View {
        Section {
            LabeledFormField("URL Template") {
                TextField("URL Template", text: $form.urlTemplate)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused(focusedField, equals: .urlTemplate)
                    .accessibilityLabel("URL Template")
            }

            LabeledFormField("EVSE ID") {
                TextField("EVSE ID", text: $form.evseID)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused(focusedField, equals: .evseID)
                    .accessibilityLabel("EVSE ID")
            }

            secretField

            LabeledFormField("Validity Time (seconds)") {
                TextField("Validity Time (seconds)", text: $form.validityTimeText)
                    .keyboardType(.numberPad)
                    .focused(focusedField, equals: .validityTime)
                    .accessibilityLabel("Validity Time in seconds")
            }

            LabeledFormField("TOTP Length") {
                TextField("TOTP Length", text: $form.totpLengthText)
                    .keyboardType(.numberPad)
                    .focused(focusedField, equals: .totpLength)
                    .accessibilityLabel("TOTP Length")
            }

            LabeledFormField("Alphabet") {
                TextField("Alphabet", text: $form.alphabet)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .fontDesign(.monospaced)
                    .focused(focusedField, equals: .alphabet)
                    .accessibilityLabel("Alphabet")
            }
        } header: {
            Text("Configuration")
        } footer: {
            Color.clear
                .frame(height: 8)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var secretField: some View {
        LabeledFormField("Shared Secret") {
            HStack {
                Group {
                    if isSecretVisible {
                        TextField("Shared Secret", text: $form.sharedSecret)
                    } else {
                        SecureField("Shared Secret", text: $form.sharedSecret)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .fontDesign(.monospaced)
                .focused(focusedField, equals: .sharedSecret)
                .accessibilityLabel("Shared Secret")

                Button {
                    isSecretVisible.toggle()
                } label: {
                    Image(systemName: isSecretVisible ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSecretVisible ? "Hide shared secret" : "Show shared secret")
            }
        }
    }
}
