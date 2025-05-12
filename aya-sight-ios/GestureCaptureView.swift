import SwiftUI
import UIKit

struct GestureCaptureView: UIViewRepresentable {
    var onCapturePhoto: () -> Void
    var onStartRecording: () -> Void
    var onStopRecording: () -> Void
    @Binding var gesturePath: [CGPoint]

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isMultipleTouchEnabled = true

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        view.addGestureRecognizer(pan)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(onCapturePhoto: onCapturePhoto,
                                      onStartRecording: onStartRecording,
                                      onStopRecording: onStopRecording)
        coordinator.gesturePath = $gesturePath
        return coordinator
    }

    class Coordinator: NSObject {
        let onCapturePhoto: () -> Void
        let onStartRecording: () -> Void
        let onStopRecording: () -> Void
        var gesturePath: Binding<[CGPoint]>?

        private var touchStartPoint: CGPoint = .zero
        private var touchStartTime: TimeInterval = 0
        private var touchCountAtStart: Int = 1

        init(onCapturePhoto: @escaping () -> Void,
             onStartRecording: @escaping () -> Void,
             onStopRecording: @escaping () -> Void) {
            self.onCapturePhoto = onCapturePhoto
            self.onStartRecording = onStartRecording
            self.onStopRecording = onStopRecording
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)

            switch gesture.state {
            case .began:
                touchStartPoint = location
                touchStartTime = Date().timeIntervalSince1970
                gesturePath?.wrappedValue = [location]
                touchCountAtStart = gesture.numberOfTouches

            case .changed:
                gesturePath?.wrappedValue.append(location)

            case .ended:
                gesturePath?.wrappedValue.append(location)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.gesturePath?.wrappedValue = []
                }

                let endPoint = location
                let dx = endPoint.x - touchStartPoint.x
                let dy = touchStartPoint.y - endPoint.y // Flipped Y for angle logic

                let angle = atan2(dy, dx) * 180 / .pi
                let distance = hypot(dx, dy)

                print("🌀 Gesture Info → Angle: \(angle.rounded())°, Distance: \(Int(distance)), Touches: \(touchCountAtStart)")

                if touchCountAtStart == 2 && dy < -80 && abs(dx) < 50 {
                    print("📸 Detected: Two-finger pull down → Capture Photo")
                    onCapturePhoto()
                } else if angle > 20 && angle < 70 && distance > 100 {
                    print("🎥 Detected: Left-down to Right-up → Start Recording")
                    onStartRecording()
                } else if angle > 110 && angle < 160 && distance > 100 {
                    print("🛑 Detected: Right-down to Left-up → Stop Recording")
                    onStopRecording()
                } else {
                    print("❌ Gesture not recognized.")
                }

            default:
                break
            }
        }
    }
}
