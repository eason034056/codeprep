import SwiftUI

enum AppAnimation {
    static let springDefault: Animation = .spring(response: 0.5, dampingFraction: 0.7)
    static let springBouncy: Animation = .spring(response: 0.4, dampingFraction: 0.6)
    static let springGentle: Animation = .spring(response: 0.6, dampingFraction: 0.8)
    static let fadeQuick: Animation = .easeOut(duration: 0.2)
    static let fadeMedium: Animation = .easeOut(duration: 0.35)
    static let countUp: Animation = .easeOut(duration: 0.8)
    static let progressDraw: Animation = .easeInOut(duration: 1.0)
}

// MARK: - Reduce Motion Safe Modifier

struct ReduceMotionSafe: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let reducedAnimation: Animation

    init(_ animation: Animation, reduced: Animation = .easeOut(duration: 0.15)) {
        self.animation = animation
        self.reducedAnimation = reduced
    }

    func body(content: Content) -> some View {
        content.transaction { transaction in
            transaction.animation = reduceMotion ? reducedAnimation : animation
        }
    }
}

extension View {
    func safeAnimation(_ animation: Animation = AppAnimation.springDefault) -> some View {
        modifier(ReduceMotionSafe(animation))
    }
}

// MARK: - Staggered Appearance Modifier

struct StaggeredAppearance: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    let totalCount: Int
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                let delay = reduceMotion ? 0 : Double(index) * 0.08
                withAnimation(AppAnimation.springDefault.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func staggeredAppearance(index: Int, total: Int = 10) -> some View {
        modifier(StaggeredAppearance(index: index, totalCount: total))
    }
}

// MARK: - Scale Press Button Style

struct ScalePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(AppAnimation.springBouncy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ScalePressButtonStyle {
    static var scalePress: ScalePressButtonStyle { ScalePressButtonStyle() }
}
