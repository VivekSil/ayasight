import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    var cameraManager: CameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let layer = cameraManager.getPreviewLayer()
        layer.frame = UIScreen.main.bounds
        view.layer.addSublayer(layer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
