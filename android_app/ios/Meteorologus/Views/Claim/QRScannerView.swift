import SwiftUI
import AVFoundation

/// Mirrors `qr_scanner_screen.dart`: native camera QR scanner using AVFoundation,
/// wrapped in a full-screen SwiftUI view.
struct QRScannerView: View {
    let onDetected: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isTorchOn = false
    @State private var cameraAuthorized = false
    @State private var showDeniedAlert = false

    var body: some View {
        ZStack {
            if cameraAuthorized {
                ScannerContainer(isTorchOn: $isTorchOn, onDetected: { code in
                    dismiss()
                    onDetected(code)
                })
                .ignoresSafeArea()

                // Torch button
                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.leading, 16)
                        .padding(.top, 8)

                        Spacer()

                        Button {
                            toggleTorch()
                            isTorchOn.toggle()
                        } label: {
                            Image(systemName: isTorchOn ? "bolt.fill" : "bolt.slash")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                    }

                    Spacer()

                    Text("Align the QR code shown on node OLED")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.35))
                        .glassEffect(.regular, in: Capsule())
                        .clipShape(Capsule())
                        .padding(.bottom, 40)
                }
            } else {
                Color.black.ignoresSafeArea()
                Text("Camera access required to scan QR codes.")
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .onAppear {
            requestCameraAccess()
        }
        .alert("Camera Access Denied", isPresented: $showDeniedAlert) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("Please enable camera access in Settings to scan QR codes.")
        }
    }

    private func requestCameraAccess() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                cameraAuthorized = granted
                if !granted { showDeniedAlert = true }
            }
        }
    }

    private func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = isTorchOn ? .off : .on
        device.unlockForConfiguration()
    }
}

// MARK: - AVFoundation Scanner (UIViewControllerRepresentable)

private struct ScannerContainer: UIViewControllerRepresentable {
    @Binding var isTorchOn: Bool
    let onDetected: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onDetected = onDetected
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        // Torch is toggled from the SwiftUI toggleTorch action.
        // No additional update needed per frame.
    }
}

private class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onDetected: ((String) -> Void)?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async { self.captureSession?.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
    }

    private func setupSession() {
        let session = AVCaptureSession()
        self.captureSession = session
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.qr]
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        self.previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasScanned else { return }
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let raw = object.stringValue,
              !raw.isEmpty else { return }

        var candidate = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if candidate.contains("/") {
            if let url = URL(string: candidate), let last = url.pathComponents.last {
                candidate = last
            } else {
                candidate = candidate.split(separator: "/").last.map(String.init) ?? candidate
            }
        }

        let clean = ClaimService.normalizeMac(candidate)
        guard ClaimService.isValidMac(clean) else { return }

        hasScanned = true
        captureSession?.stopRunning()
        onDetected?(clean)
    }
}