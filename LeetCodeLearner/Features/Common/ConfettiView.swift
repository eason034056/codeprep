import SwiftUI

struct ConfettiView: View {
    @Binding var isActive: Bool
    @State private var particles: [ConfettiParticle] = []

    private let colors: [Color] = [
        AppColor.accent, AppColor.success, AppColor.xpGold,
        AppColor.streakFlame, AppColor.difficultyMedium, .purple
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    let elapsed = now - particle.startTime
                    guard elapsed < particle.lifetime else { continue }

                    let progress = elapsed / particle.lifetime
                    let x = particle.startX + particle.driftX * elapsed
                    let y = particle.startY + particle.speed * elapsed + 0.5 * 400 * elapsed * elapsed
                    let opacity = 1.0 - progress
                    let rotation = Angle.degrees(particle.rotation + particle.rotationSpeed * elapsed)

                    guard x >= -20, x <= size.width + 20, y <= size.height + 20 else { continue }

                    context.opacity = opacity
                    context.translateBy(x: x, y: y)
                    context.rotate(by: rotation)

                    let rect = CGRect(x: -particle.width / 2, y: -particle.height / 2, width: particle.width, height: particle.height)
                    context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(particle.color))

                    context.rotate(by: -rotation)
                    context.translateBy(x: -x, y: -y)
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, active in
            if active { spawnParticles() }
        }
        .onAppear {
            if isActive { spawnParticles() }
        }
    }

    private func spawnParticles() {
        let now = Date.now.timeIntervalSinceReferenceDate
        particles = (0..<45).map { _ in
            ConfettiParticle(
                startX: Double.random(in: -20...UIScreen.main.bounds.width + 20),
                startY: Double.random(in: -60 ... -10),
                speed: Double.random(in: 80...160),
                driftX: Double.random(in: -40...40),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -200...200),
                width: Double.random(in: 6...12),
                height: Double.random(in: 4...8),
                color: colors.randomElement()!,
                lifetime: Double.random(in: 1.8...2.5),
                startTime: now + Double.random(in: 0...0.3)
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            isActive = false
            particles = []
        }
    }
}

private struct ConfettiParticle {
    let startX: Double
    let startY: Double
    let speed: Double
    let driftX: Double
    let rotation: Double
    let rotationSpeed: Double
    let width: Double
    let height: Double
    let color: Color
    let lifetime: Double
    let startTime: TimeInterval
}
