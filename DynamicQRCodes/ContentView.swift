import SwiftUI

struct ContentView: View {

    // MARK: - Input State

    @State private var timestampText    = ""
    @State private var autoUpdate       = true
    @State private var urlTemplate      = "https://charging.cloud/{evseId}/{totp}"
    @State private var evseId           = "DE*GEF*E12345*678*1"
    @State private var sharedSecret     = TOTPGenerator.generateRandomSecret(length: 16)
    @State private var validityTimeText = "30"
    @State private var totpLengthText   = "12"
    @State private var alphabet         = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

    // MARK: - Output State

    @State private var resultingURL      = ""
    @State private var remainingTimeText = ""
    @State private var errorMessage:       String?

    // MARK: - Scanner State

    @State private var showScanner  = false
    @State private var scannedCode: String?
    @State private var showScanResult = false

    // MARK: - Focus

    @FocusState private var timestampFocused: Bool

    // MARK: - Timer

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let dateFormatter: DateFormatter = {
        let df        = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        df.locale     = Locale.current
        return df
    }()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {

                    // Timestamp
                    TextField("Timestamp (yyyy-MM-dd HH:mm:ss)", text: $timestampText)
                        .textFieldStyle(.roundedBorder)
                        .focused($timestampFocused)
                        .onChange(of: timestampFocused) {
                            if timestampFocused {
                                autoUpdate = false
                            }
                        }
                        .onChange(of: timestampText) { updateTOTP() }

                    // Auto Update Toggle
                    Toggle("Auto update", isOn: $autoUpdate)
                        .onChange(of: autoUpdate) {
                            if autoUpdate {
                                updateTimestamp()
                            }
                        }

                    // URL Template
                    TextField("URL Template", text: $urlTemplate)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: urlTemplate) { updateTOTP() }

                    // EVSE ID
                    TextField("EVSE ID", text: $evseId)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: evseId) { updateTOTP() }

                    // Shared Secret
                    TextField("Shared Secret", text: $sharedSecret)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: sharedSecret) { updateTOTP() }

                    // Validity Time
                    TextField("Validity Time (seconds)", text: $validityTimeText)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .onChange(of: validityTimeText) { updateTOTP() }

                    // TOTP Length
                    TextField("TOTP Length", text: $totpLengthText)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .onChange(of: totpLengthText) { updateTOTP() }

                    // Alphabet
                    TextField("Alphabet", text: $alphabet)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: alphabet) { updateTOTP() }

                    // Resulting URL (read-only output)
                    if !resultingURL.isEmpty {
                        Text(resultingURL)
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.top, 16)
                            .textSelection(.enabled)
                    }

                    // Remaining Time (read-only output)
                    if !remainingTimeText.isEmpty {
                        Text(remainingTimeText)
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }

                    // Scan QR Code Button
                    Button {
                        showScanner = true
                    } label: {
                        Label("Scan QR Code", systemImage: "camera")
                            .font(.system(size: 19))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 32)

                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("DynamicQRCodes")
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(timer) { _ in
                if autoUpdate {
                    updateTimestamp()
                }
            }
            .onAppear {
                updateTimestamp()
            }
            .sheet(isPresented: $showScanner) {
                QRScannerView(scannedCode: $scannedCode, isPresented: $showScanner)
            }
            .onChange(of: scannedCode) {
                if scannedCode != nil {
                    showScanResult = true
                }
            }
            .alert("QR Code Scanned", isPresented: $showScanResult) {
                Button("OK") {
                    scannedCode = nil
                }
            } message: {
                Text(scannedCode ?? "")
            }
        }
    }

    // MARK: - Logic

    private func updateTimestamp() {
        timestampText = dateFormatter.string(from: Date())
    }

    private func updateTOTP() {

        guard !timestampText.isEmpty else { return }

        guard let date = dateFormatter.date(from: timestampText) else {
            errorMessage      = "Invalid date format!"
            resultingURL      = ""
            remainingTimeText = ""
            return
        }

        guard let validityTime = UInt32(validityTimeText), validityTime > 0 else {
            errorMessage      = "Invalid validity time!"
            resultingURL      = ""
            remainingTimeText = ""
            return
        }

        guard let totpLength = UInt32(totpLengthText) else {
            errorMessage      = "Invalid TOTP length!"
            resultingURL      = ""
            remainingTimeText = ""
            return
        }

        do {
            let result = try TOTPGenerator.generate(
                sharedSecret: sharedSecret,
                validityTime: validityTime,
                totpLength:   totpLength,
                alphabet:     alphabet,
                timestamp:    Int64(date.timeIntervalSince1970 * 1000)
            )

            var url = urlTemplate
            url = url.replacingOccurrences(of: "{evseId}", with: evseId)
            url = url.replacingOccurrences(of: "{totp}",   with: result.current)

            resultingURL      = url
            remainingTimeText = "Remaining Time: \(result.remainingTime) secs"
            errorMessage      = nil

        } catch {
            errorMessage      = error.localizedDescription
            resultingURL      = ""
            remainingTimeText = ""
        }

    }

}

#Preview {
    ContentView()
}
