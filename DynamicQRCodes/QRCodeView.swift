import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let value: String

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: 240, maxHeight: 240)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement()
        .accessibilityLabel("QR code for the generated secure URL")
        .task(id: value) {
            // Avoid blocking text-field focus and input while the form changes.
            // A short debounce also prevents rendering intermediate values while typing.
            do {
                try await Task.sleep(for: .milliseconds(120))
            } catch {
                return
            }

            let renderedImage = await Task.detached(priority: .userInitiated) {
                QRCodeRenderer.image(for: value)
            }.value

            guard !Task.isCancelled else { return }
            image = renderedImage
        }
    }
}

private enum QRCodeRenderer {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    static func image(for value: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
