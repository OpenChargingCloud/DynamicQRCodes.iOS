import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let privacyPolicyURL = URL(
        string: "https://github.com/OpenChargingCloud/DynamicQRCodes.iOS/blob/master/PRIVACY.md"
    )
    private let sourceCodeURL = URL(string: "https://github.com/OpenChargingCloud/DynamicQRCodes.iOS")
    private let supportURL = URL(string: "https://github.com/OpenChargingCloud/DynamicQRCodes.iOS/issues")

    private var version: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Version", value: version)
                }

                Section("Privacy") {
                    Text("DynamicQRCodes processes configuration values and camera images only on this device. It does not transmit, persist, or collect personal data. Camera frames are used only while the scanner is visible.")

                    if let privacyPolicyURL {
                        Link("Read privacy policy", destination: privacyPolicyURL)
                    }
                }

                Section("Project") {
                    if let sourceCodeURL {
                        Link("Source code", destination: sourceCodeURL)
                    }
                    if let supportURL {
                        Link("Support and issues", destination: supportURL)
                    }
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AboutView()
}
