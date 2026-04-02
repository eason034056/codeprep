import SwiftUI

struct AnimatedMeshBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            staticBackground
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let cx1 = size.width * (0.3 + 0.2 * sin(time * 0.3))
                    let cy1 = size.height * (0.3 + 0.15 * cos(time * 0.25))
                    let cx2 = size.width * (0.7 + 0.15 * cos(time * 0.35))
                    let cy2 = size.height * (0.7 + 0.2 * sin(time * 0.2))

                    let r1 = size.width * 0.6
                    let r2 = size.width * 0.5

                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: cx1 - r1 / 2, y: cy1 - r1 / 2,
                            width: r1, height: r1
                        )),
                        with: .color(Color(hex: "8B5CF6").opacity(0.06))
                    )

                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: cx2 - r2 / 2, y: cy2 - r2 / 2,
                            width: r2, height: r2
                        )),
                        with: .color(Color(hex: "6D28D9").opacity(0.05))
                    )
                }
            }
        }
    }

    private var staticBackground: some View {
        Canvas { context, size in
            let r1 = size.width * 0.6
            let r2 = size.width * 0.5
            context.fill(
                Path(ellipseIn: CGRect(
                    x: size.width * 0.3 - r1 / 2, y: size.height * 0.3 - r1 / 2,
                    width: r1, height: r1
                )),
                with: .color(Color(hex: "8B5CF6").opacity(0.06))
            )
            context.fill(
                Path(ellipseIn: CGRect(
                    x: size.width * 0.7 - r2 / 2, y: size.height * 0.7 - r2 / 2,
                    width: r2, height: r2
                )),
                with: .color(Color(hex: "6D28D9").opacity(0.05))
            )
        }
    }
}
