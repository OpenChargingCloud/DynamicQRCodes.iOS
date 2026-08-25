import SwiftUI

struct ContentView: View {
    @State private var form: GeneratorFormState
    @State private var generated: GeneratedDynamicQRCode?
    @State private var generationError: String?
    @State private var scanEvaluation: ScanEvaluation?
    @State private var scannedValue: String?
    @State private var scanError: String?
    @State private var scannerMessage: String?
    @State private var pendingScannerMessage: String?
    @State private var isScannerPresented = false
    @State private var isAboutPresented = false
    @State private var isSecretVisible = false
    @State private var autoUpdate = true
    @FocusState private var focusedField: InputField?

    private let timestampFormatter = TimestampFormatter()

    init() {
        _form = State(
            initialValue: GeneratorFormState(
                timestampText: "",
                urlTemplate: "https://charging.cloud/{evseId}/{totp}",
                evseID: "DE*GEF*E12345*678*1",
                sharedSecret: TOTPGenerator.generateRandomSecret(length: 16),
                validityTimeText: "30",
                totpLengthText: "12",
                alphabet: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                TimeInputSection(
                    timestampText: $form.timestampText,
                    autoUpdate: $autoUpdate,
                    focusedField: $focusedField
                )

                TokenConfigurationSection(
                    form: $form,
                    isSecretVisible: $isSecretVisible,
                    focusedField: $focusedField
                )

                GeneratedURLSection(
                    generated: generated,
                    errorMessage: generationError,
                    validityTime: UInt32(form.validityTimeText) ?? 0
                )

                ScannerSection(
                    scannedValue: scannedValue,
                    evaluation: scanEvaluation,
                    errorMessage: scanError,
                    expectedEVSEID: form.evseID,
                    scanAction: presentScanner
                )
            }
            .formStyle(.grouped)
            .navigationTitle("Dynamic QR Codes")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("About", systemImage: "info.circle") {
                        isAboutPresented = true
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .sheet(isPresented: $isScannerPresented, onDismiss: scannerDidDismiss) {
                QRScannerView(
                    onScan: handleScannedCode,
                    onFailure: handleScannerFailure,
                    onCancel: dismissScanner
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $isAboutPresented) {
                AboutView()
            }
            .alert(
                "Scanner unavailable",
                isPresented: Binding(
                    get: { scannerMessage != nil },
                    set: { if !$0 { scannerMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(scannerMessage ?? "")
            }
            .onChange(of: form, initial: true) {
                updateGeneratedURL()
            }
            .task(id: autoUpdate) {
                await runClock()
            }
        }
    }

    private func runClock() async {
        guard autoUpdate else { return }

        while !Task.isCancelled {
            updateTimestamp()
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func updateTimestamp() {
        form.timestampText = timestampFormatter.string(from: Date())
    }

    private func updateGeneratedURL() {
        do {
            let input = try validatedInput()
            generated = try input.configuration.generate(timestamp: input.timestamp)
            generationError = nil
        } catch {
            generated = nil
            generationError = error.localizedDescription
        }
    }

    private func presentScanner() {
        focusedField = nil
        isScannerPresented = true
    }

    private func dismissScanner() {
        isScannerPresented = false
    }

    private func handleScannerFailure(_ message: String) {
        pendingScannerMessage = message
        isScannerPresented = false
    }

    private func scannerDidDismiss() {
        guard let pendingScannerMessage else { return }
        scannerMessage = pendingScannerMessage
        self.pendingScannerMessage = nil
    }

    private func handleScannedCode(_ code: String) {
        isScannerPresented = false
        scannedValue = code

        do {
            let input = try validatedInput()
            scanEvaluation = try input.configuration.evaluate(
                scannedValue: code,
                timestamp: input.timestamp
            )
            scanError = nil
        } catch {
            scanEvaluation = nil
            scanError = error.localizedDescription
        }
    }

    private func validatedInput() throws -> ValidatedInput {
        guard let date = timestampFormatter.date(from: form.timestampText) else {
            throw GeneratorFormError.invalidTimestamp
        }
        guard let validityTime = UInt32(form.validityTimeText), validityTime > 0 else {
            throw GeneratorFormError.invalidValidityTime
        }
        guard let totpLength = UInt32(form.totpLengthText) else {
            throw GeneratorFormError.invalidTOTPLength
        }

        return ValidatedInput(
            configuration: DynamicQRCodeConfiguration(
                template: try URLTemplate(form.urlTemplate),
                evseID: form.evseID.trimmingCharacters(in: .whitespacesAndNewlines),
                sharedSecret: form.sharedSecret,
                validityTime: validityTime,
                totpLength: totpLength,
                alphabet: form.alphabet
            ),
            timestamp: Int64(date.timeIntervalSince1970 * 1_000)
        )
    }
}

#Preview {
    ContentView()
}
