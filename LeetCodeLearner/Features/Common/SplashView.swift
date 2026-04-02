import SwiftUI
import AVFoundation

extension Notification.Name {
    static let splashDidFinish = Notification.Name("splashDidFinish")
}

struct SplashView: View {
    var body: some View {
        ZStack {
            AppColor.pageBackground.ignoresSafeArea()

            SplashPlayerView()
                .ignoresSafeArea()
        }
    }
}

private struct SplashPlayerView: UIViewRepresentable {
    func makeUIView(context: Context) -> SplashUIView {
        let view = SplashUIView()
        view.setup()
        return view
    }

    func updateUIView(_ uiView: SplashUIView, context: Context) {}
}

final class SplashUIView: UIView {
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?

    func setup() {
        guard let url = Bundle.main.url(forResource: "splash", withExtension: "mp4") else {
            postFinished()
            return
        }

        let player = AVPlayer(url: url)
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        self.layer.addSublayer(layer)

        self.player = player
        self.playerLayer = layer

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(videoDidEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )

        player.play()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    @objc private func videoDidEnd() {
        postFinished()
    }

    private func postFinished() {
        NotificationCenter.default.post(name: .splashDidFinish, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
