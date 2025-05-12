import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var speaker = SpeechSynthesizer()
    @State private var statusMessage = "👋 Ready for gestures"
    @State private var gesturePath: [CGPoint] = []
    @State private var ayaResponse: String = ""
    @State private var showAnalysis = false

    @State private var selectedLanguage = "en"
    let supportedLanguages = ["en", "es", "hi", "fr"]

    var body: some View {
        ZStack {
            CameraPreviewView(cameraManager: cameraManager)
                .onAppear {
                    cameraManager.onPhotoCaptured = { imageData in
                        uploadToAya(imageData: imageData, language: selectedLanguage)
                    }

                    cameraManager.onVideoSaved = { videoURL in
                        extractAndSendFrames(from: videoURL, language: selectedLanguage)
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
                    speaker.speak("Photo captured", language: selectedLanguage)
                    statusMessage = "📸 Photo Captured"
                },
                onStartRecording: {
                    cameraManager.startRecording()
                    speaker.speak("Recording started", language: selectedLanguage)
                    statusMessage = "🎥 Recording Started"
                },
                onStopRecording: {
                    cameraManager.stopRecording()
                    speaker.speak("Recording stopped", language: selectedLanguage)
                    statusMessage = "🛑 Recording Stopped"
                },
                gesturePath: $gesturePath
            )

            VStack {
                Spacer()

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

                Picker("Language", selection: $selectedLanguage) {
                    ForEach(supportedLanguages, id: \.self) { code in
                        Text(languageName(for: code))
                    }
                }
                .pickerStyle(.menu)
                .foregroundColor(.white)
                .padding(.horizontal)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)

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
    func uploadToAya(imageData: Data, language: String = "en", completion: ((String?) -> Void)? = nil) {
        guard let url = URL(string: "https://bd0b-2600-1700-6ec-9c00-24fe-7335-1a6c-1147.ngrok-free.app/analyze-image") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let promptText = "Describe this image in \(languageName(for: language))."

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(promptText)\r\n".data(using: .utf8)!)
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
                    speaker.speak(reply, language: language)
                    completion?(reply)
                }
            } else {
                print("❌ Aya Vision request failed: \(error?.localizedDescription ?? "Unknown error")")
                completion?(nil)
            }
        }.resume()
    }

    // 🎞️ Extract 3 frames and analyze with language
    func extractAndSendFrames(from videoURL: URL, language: String = "en") {
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
                        uploadToAya(imageData: imageData, language: language) { caption in
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
            speaker.speak(self.ayaResponse, language: language)
        }
    }

    func languageName(for code: String) -> String {
        switch code {
            case "es": return "Spanish"
            case "hi": return "Hindi"
            case "fr": return "French"
            default: return "English"
        }
    }
}
