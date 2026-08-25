import SwiftUI
@preconcurrency import AVFoundation
import AudioToolbox

@MainActor
struct QRScannerView: UIViewControllerRepresentable {
    let onScan: @MainActor (String) -> Void
    let onFailure: @MainActor (String) -> Void
    let onCancel: @MainActor () -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let viewController = QRScannerViewController()
        viewController.delegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, QRScannerViewControllerDelegate {
        private let parent: QRScannerView

        init(parent: QRScannerView) {
            self.parent = parent
        }

        func didScanCode(_ code: String) {
            parent.onScan(code)
        }

        func didFail(with message: String) {
            parent.onFailure(message)
        }

        func didCancel() {
            parent.onCancel()
        }
    }
}

@MainActor
private protocol QRScannerViewControllerDelegate: AnyObject {
    func didScanCode(_ code: String)
    func didFail(with message: String)
    func didCancel()
}

private enum QRScannerError: LocalizedError {
    case cameraUnavailable
    case permissionDenied
    case inputUnavailable
    case configurationFailed

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            "No camera is available on this device."
        case .permissionDenied:
            "Camera access is disabled. Allow access in Settings to scan QR codes."
        case .inputUnavailable:
            "The camera could not be opened."
        case .configurationFailed:
            "The camera could not be configured for QR-code scanning."
        }
    }
}

private final class CaptureSessionController: @unchecked Sendable {
    let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "cloud.charging.open.dynamicqrcodes.capture")

    func start() {
        queue.async { [session] in
            guard !session.isRunning else { return }
            session.startRunning()
        }
    }

    func stop() {
        queue.async { [session] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }
}

@MainActor
final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    fileprivate weak var delegate: QRScannerViewControllerDelegate?

    private let sessionController = CaptureSessionController()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasFinished = false

    override func viewDidLoad() {
        super.viewDidLoad()
        configureInterface()
        requestCameraAccess()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        updatePreviewOrientation()
    }

    override func viewWillDisappear(_ animated: Bool) {
        sessionController.stop()
        super.viewWillDisappear(animated)
    }

    private func configureInterface() {
        view.backgroundColor = .black

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        cancelButton.accessibilityHint = "Closes the QR-code scanner"
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        let promptLabel = UILabel()
        promptLabel.text = "Point the camera at a secure charging QR code"
        promptLabel.textColor = .white
        promptLabel.textAlignment = .center
        promptLabel.font = .preferredFont(forTextStyle: .body)
        promptLabel.adjustsFontForContentSizeCategory = true
        promptLabel.numberOfLines = 0
        promptLabel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        promptLabel.layer.cornerRadius = 12
        promptLabel.layer.masksToBounds = true
        promptLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(cancelButton)
        view.addSubview(promptLabel)

        NSLayoutConstraint.activate([
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            cancelButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            cancelButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            promptLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leadingAnchor),
            promptLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.trailingAnchor),
            promptLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            promptLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            promptLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 420)
        ])
    }

    private func requestCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCamera()
        case .notDetermined:
            Task { [weak self] in
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                guard let self else { return }
                if granted {
                    configureCamera()
                } else {
                    finish(with: QRScannerError.permissionDenied)
                }
            }
        case .denied, .restricted:
            finish(with: QRScannerError.permissionDenied)
        @unknown default:
            finish(with: QRScannerError.permissionDenied)
        }
    }

    private func configureCamera() {
        let session = sessionController.session

        guard let device = AVCaptureDevice.default(for: .video) else {
            finish(with: QRScannerError.cameraUnavailable)
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: device) else {
            finish(with: QRScannerError.inputUnavailable)
            return
        }

        let output = AVCaptureMetadataOutput()
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard session.canAddInput(input), session.canAddOutput(output) else {
            finish(with: QRScannerError.configurationFailed)
            return
        }

        session.addInput(input)
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
        self.previewLayer = previewLayer

        sessionController.start()
    }

    private func updatePreviewOrientation() {
        guard let connection = previewLayer?.connection else { return }

        let angle: CGFloat = switch view.window?.windowScene?.interfaceOrientation {
        case .landscapeLeft: 270
        case .landscapeRight: 90
        case .portraitUpsideDown: 180
        default: 0
        }
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }

    @objc private func cancelTapped() {
        guard !hasFinished else { return }
        hasFinished = true
        sessionController.stop()
        delegate?.didCancel()
    }

    private func finish(with error: QRScannerError) {
        guard !hasFinished else { return }
        hasFinished = true
        sessionController.stop()
        delegate?.didFail(with: error.localizedDescription)
    }

    private func finish(with code: String) {
        guard !hasFinished else { return }
        hasFinished = true
        sessionController.stop()
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        delegate?.didScanCode(code)
    }

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let readableObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = readableObject.stringValue else { return }

        Task { @MainActor [weak self] in
            self?.finish(with: value)
        }
    }
}
