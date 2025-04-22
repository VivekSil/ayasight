import AVFoundation
import UIKit

class CameraManager: NSObject, ObservableObject {
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    var onPhotoCaptured: ((Data) -> Void)?
    var onVideoSaved: ((URL) -> Void)?



    override init() {
        super.init()
        configureSession()
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        // Add input
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        // Add movie output
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        session.commitConfiguration()
        session.startRunning()
    }

    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        if previewLayer == nil {
            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer?.videoGravity = .resizeAspectFill
        }
        return previewLayer!
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func startRecording() {
        guard !movieOutput.isRecording else { return }
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("video.mov")
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
    }

    func stopRecording() {
        if movieOutput.isRecording {
            movieOutput.stopRecording()
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let _ = UIImage(data: imageData) else { return }
        print("✅ Photo captured")
        onPhotoCaptured?(imageData)
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        print("✅ Video saved to: \(outputFileURL.absoluteString)")
        DispatchQueue.main.async {
                self.onVideoSaved?(outputFileURL)
            }
    }
}
