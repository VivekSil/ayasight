import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var speaker = SpeechSynthesizer()
    @State private var statusMessage = "👋 Ready for gestures"
    @State private var gesturePath: [CGPoint] = []
    @State private var ayaResponse: String = ""

    var body: some View {
        ZStack {
            CameraPreviewView(cameraManager: cameraManager)
                .onAppear {
                    // 📸 Photo callback
                    cameraManager.onPhotoCaptured = { imageData in
                        uploadToAya(imageData: imageData)
                    }

                    // 🎥 Video callback
                    cameraManager.onVideoSaved = { videoURL in
                        extractAndSendFrames(from: videoURL)
                    }
                }

            // ✍️ Gesture trail
            Canvas { context, size in
                guard gesturePath.count > 1 else { return }

                var path = Path()
                path.move(to: gesturePath.first!)
                for point in gesturePath.dropFirst() {
                    path.addLine(to: point)
                }

                context.stroke(path, with: .color(.green), lineWidth: 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)

            // ✋ Gesture listeners
            GestureCaptureView(
                onCapturePhoto: {
                    cameraManager.capturePhoto()
                    speaker.speak("Photo captured")
                    statusMessage = "📸 Photo Captured"
                },
                onStartRecording: {
                    cameraManager.startRecording()
                    speaker.speak("Recording started")
                    statusMessage = "🎥 Recording Started"
                },
                onStopRecording: {
                    cameraManager.stopRecording()
                    speaker.speak("Recording stopped")
                    statusMessage = "🛑 Recording Stopped"
                },
                gesturePath: $gesturePath
            )

            VStack {
                Spacer()

                // 🧠 Aya Response
                if !ayaResponse.isEmpty {
                    Text("🧠 Aya Vision:\n\(ayaResponse)")
                        .foregroundColor(.white)
                        .font(.callout)
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }

                // 📘 Gesture Guide
                VStack(alignment: .leading, spacing: 6) {
                    Text("👆 Two-finger pull down → Capture Photo")
                    Text("↗️ Left-down to Right-up → Start Recording")
                    Text("↖️ Right-down to Left-up → Stop Recording")
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(10)

                Text(statusMessage)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    .padding(.bottom, 30)
            }
        }
    }

    // 📤 Send image to Aya Vision
    func uploadToAya(imageData: Data, completion: ((String?) -> Void)? = nil) {
        guard let url = URL(string: "https://0fd0-2600-1700-6ec-9c00-b917-b3b3-1b01-736b.ngrok-free.app/analyze-image") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        URLSession.shared.uploadTask(with: request, from: body) { data, response, error in
            if let data = data,
               let result = try? JSONSerialization.jsonObject(with: data) as? [String: String],
               let reply = result["response"] {
                DispatchQueue.main.async {
                    self.ayaResponse = reply
                    completion?(reply)
                }
            } else {
                print("❌ Aya Vision request failed: \(error?.localizedDescription ?? "Unknown error")")
                completion?(nil)
            }
        }.resume()
    }

    // 🎞️ Extract 3 frames from video and send each to Aya
    func extractAndSendFrames(from videoURL: URL) {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        let duration = CMTimeGetSeconds(asset.duration)
        let times = stride(from: 0.5, to: duration, by: max(duration / 3.0, 1.5)).prefix(3).map {
            NSValue(time: CMTime(seconds: $0, preferredTimescale: 600))
        }

        var allCaptions: [String] = []
        let group = DispatchGroup()

        for time in times {
            group.enter()
            generator.generateCGImagesAsynchronously(forTimes: [time]) { _, cgImage, _, _, _ in
                if let cgImage = cgImage {
                    let image = UIImage(cgImage: cgImage)
                    if let imageData = image.jpegData(compressionQuality: 0.8) {
                        uploadToAya(imageData: imageData) { caption in
                            if let caption = caption {
                                allCaptions.append("• \(caption)")
                            }
                            group.leave()
                        }
                    } else {
                        group.leave()
                    }
                } else {
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            self.ayaResponse = allCaptions.joined(separator: "\n")
        }
    }
}
