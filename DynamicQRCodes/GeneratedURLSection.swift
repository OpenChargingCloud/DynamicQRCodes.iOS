import SwiftUI
import UIKit

struct GeneratedURLSection: View {
    let generated: GeneratedDynamicQRCode?
    let errorMessage: String?
    let validityTime: UInt32

    @State private var copyConfirmationID = 0
    @State private var isCopyConfirmationVisible = false

    var body: some View {
        Section("Generated URL") {
            if let generated {
                QRCodeView(value: generated.url.absoluteString)

                Text(generated.url.absoluteString)
                    .font(.footnote.monospaced())
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Generated secure URL")
                    .accessibilityValue(generated.url.absoluteString)
                    .accessibilityHint("Long press to copy the URL")
                    .accessibilityAction(named: "Copy URL") {
                        copy(generated.url)
                    }
                    .onLongPressGesture(minimumDuration: 0.5) {
                        copy(generated.url)
                    }
                    .sensoryFeedback(.success, trigger: copyConfirmationID)
                    .overlay {
                        if isCopyConfirmationVisible {
                            Label("URL copied", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.regularMaterial, in: Capsule())
                                .shadow(radius: 4, y: 2)
                                .transition(.scale.combined(with: .opacity))
                                .allowsHitTesting(false)
                        }
                    }
                    .task(id: copyConfirmationID) {
                        guard copyConfirmationID > 0 else { return }

                        do {
                            try await Task.sleep(for: .seconds(1.5))
                        } catch {
                            return
                        }

                        withAnimation(.easeOut(duration: 0.2)) {
                            isCopyConfirmationVisible = false
                        }
                    }

                Gauge(
                    value: Double(generated.totp.remainingTime),
                    in: 0...Double(max(validityTime, 1))
                ) {
                    Text("Remaining validity time")
                } currentValueLabel: {
                    Text("\(generated.totp.remainingTime) s")
                }

            } else if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    private func copy(_ url: URL) {
        UIPasteboard.general.string = url.absoluteString
        copyConfirmationID += 1

        withAnimation(.spring(duration: 0.25)) {
            isCopyConfirmationVisible = true
        }

        UIAccessibility.post(notification: .announcement, argument: "URL copied")
    }
}
