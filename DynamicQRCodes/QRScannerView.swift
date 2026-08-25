import SwiftUI
import AVFoundation
import AudioToolbox

// MARK: - SwiftUI Wrapper

struct QRScannerView: UIViewControllerRepresentable {

    @Binding var scannedCode: String?
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc      = QRScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, QRScannerViewControllerDelegate {

        let parent: QRScannerView

        init(parent: QRScannerView) {
            self.parent = parent
        }

        func didScanCode(_ code: String) {
            parent.scannedCode = code
            parent.isPresented = false
        }

        func didFailWithError(_ error: String) {
            parent.isPresented = false
        }

        func didCancel() {
            parent.isPresented = false
        }

    }

}

// MARK: - Delegate Protocol

protocol QRScannerViewControllerDelegate: AnyObject {
    func didScanCode(_ code: String)
    func didFailWithError(_ error: String)
    func didCancel()
}

// MARK: - UIKit Camera Controller

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    weak var delegate: QRScannerViewControllerDelegate?

    private var captureSession: AVCaptureSession?
    private var previewLayer:   AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        setupCamera()

        // Cancel button
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(cancelButton)
        NSLayoutConstraint.activate([
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            cancelButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])

        // Scan prompt label
        let promptLabel = UILabel()
        promptLabel.text          = "Scan a QR code"
        promptLabel.textColor     = .white
        promptLabel.textAlignment = .center
        promptLabel.font          = .systemFont(ofSize: 16)
        promptLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(promptLabel)
        NSLayoutConstraint.activate([
            promptLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            promptLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func setupCamera() {

        let session = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            delegate?.didFailWithError("No camera available")
            return
        }

        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            delegate?.didFailWithError("Cannot access camera")
            return
        }

        guard session.canAddInput(videoInput) else {
            delegate?.didFailWithError("Cannot add camera input")
            return
        }
        session.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadataOutput) else {
            delegate?.didFailWithError("Cannot add metadata output")
            return
        }
        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = [.qr]

        let preview      = AVCaptureVideoPreviewLayer(session: session)
        preview.frame        = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)

        self.previewLayer   = preview
        self.captureSession = session

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    @objc private func cancelTapped() {
        captureSession?.stopRunning()
        delegate?.didCancel()
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        captureSession?.stopRunning()

        if let metadataObject  = metadataObjects.first,
           let readableObject  = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue     = readableObject.stringValue
        {
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            delegate?.didScanCode(stringValue)
        }
    }

}
