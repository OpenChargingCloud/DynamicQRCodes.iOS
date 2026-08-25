import SwiftUI

struct ScannerSection: View {
    let scannedValue: String?
    let evaluation: ScanEvaluation?
    let errorMessage: String?
    let expectedEVSEID: String
    let scanAction: () -> Void

    var body: some View {
        Section {
            Button(action: scanAction) {
                Label("Scan and Validate QR-Code", systemImage: "qrcode.viewfinder")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .contentShape(Rectangle())
            }

            if let evaluation {
                Label(
                    evaluation.message,
                    systemImage: evaluation.validation.isValid ? "checkmark.shield.fill" : "xmark.shield.fill"
                )
                .foregroundStyle(evaluation.validation.isValid ? .green : .red)

                if let evseID = evaluation.evseID {
                    LabeledContent(
                        evseID == expectedEVSEID ? "EVSE ID" : "Different EVSE ID",
                        value: evseID
                    )
                }
            } else if let errorMessage {
                Label(errorMessage, systemImage: "xmark.shield.fill")
                    .foregroundStyle(.red)
            }

            if let scannedValue {
                Text(scannedValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        } header: {
            Color.clear
                .frame(height: 8)
                .accessibilityHidden(true)
        } footer: {
            AppMetadataFooter()
        }
    }
}
