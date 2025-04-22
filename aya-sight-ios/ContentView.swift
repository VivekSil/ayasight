import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var speaker = SpeechSynthesizer()
    @State private var statusMessage = "👋 Ready for gestures"
    @State private var gesturePath: [CGPoint] = []
    @State private var ayaResponse: String = ""
    @State private var showAnalysis = false

    var body: some View {
        ZStack {
            CameraPreviewView(cameraManager: cameraManager)
                .onAppear {
                    cameraManager.onPhotoCaptured = { imageData in
                        uploadToAya(imageData: imageData)
                    }

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

                // 🧠 Aya Result Display (now dismissible)
                if showAnalysis {
                    VStack(spacing: 12) {
                        Text("🧠 Aya Vision")
                            .font(.headline)
                            .foregroundColor(.white)

                        ScrollView {
                            Text(ayaResponse)
                                .foregroundColor(.white)
                                .font(.callout)
                                .multilineTextAlignment(.leading)
                                .padding()
                        }
                        .frame(maxHeight: 180)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)

                        Button("Dismiss") {
                            ayaResponse = ""
                            showAnalysis = false
                            statusMessage = "👋 Ready for gestures"
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(20)
                    .padding(.horizontal)
                }

                // Gesture instructions
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

    // 📤 Upload image to Aya server
    func uploadToAya(imageData: Data, completion: ((String?) -> Void)? = nil) {
        guard let url = URL(string: "https://e2fe-2600-1700-6ec-9c00-b917-b3b3-1b01-736b.ngrok-free.app/analyze-image") else { return }

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
                    self.showAnalysis = true
                    speaker.speak(reply)
                    completion?(reply)
                }
            } else {
                print("❌ Aya Vision request failed: \(error?.localizedDescription ?? "Unknown error")")
                completion?(nil)
            }
        }.resume()
    }

    // 🎞️ Extract 3 frames from video and analyze
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
            self.showAnalysis = true
            speaker.speak(self.ayaResponse)
        }
    }
}
