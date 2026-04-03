import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0
    @State private var selectedPath: LearningPath = .grind75
    @State private var apiKeyInput = ""
    @State private var apiKeySaved = false
    @State private var apiKeyError: String?

    private let totalPages = 4

    var body: some View {
        ZStack {
            AppColor.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    learningPathPage.tag(1)
                    apiKeyPage.tag(2)
                    readyPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Page indicator and navigation
                VStack(spacing: AppSpacing.lg) {
                    pageIndicator

                    if currentPage < totalPages - 1 {
                        Button {
                            withAnimation {
                                currentPage += 1
                            }
                        } label: {
                            Text("Continue")
                                .font(AppFont.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.lg)
                                .background(AppColor.accentGradient)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                        }
                        .padding(.horizontal, AppSpacing.xxl)
                    }
                }
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(0..<totalPages, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? AppColor.accent : Color.white.opacity(0.3))
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: currentPage)
            }
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xxl) {
                Spacer().frame(height: AppSpacing.xxxl)

                // App icon area
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 60))
                    .foregroundStyle(AppColor.accentGradient)
                    .padding(.bottom, AppSpacing.sm)

                // Title
                Text("CodeReps")
                    .font(AppFont.largeTitle)
                    .foregroundStyle(AppColor.accentGradient)

                Text("Master coding interviews with\nAI-powered tutoring")
                    .font(AppFont.title3)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                Spacer().frame(height: AppSpacing.lg)

                // Feature bullets
                VStack(spacing: AppSpacing.xl) {
                    featureRow(
                        icon: "brain.head.profile",
                        text: "Spaced repetition to never forget"
                    )
                    featureRow(
                        icon: "bubble.left.and.bubble.right",
                        text: "AI mentor guides your thinking"
                    )
                    featureRow(
                        icon: "chart.line.uptrend.xyaxis",
                        text: "Track your progress daily"
                    )
                }
                .padding(.horizontal, AppSpacing.xxl)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.lg)
        }
        .scrollIndicators(.hidden)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: AppSpacing.lg) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppColor.accent)
                .frame(width: 40, alignment: .center)

            Text(text)
                .font(AppFont.body)
                .foregroundStyle(.white.opacity(0.9))

            Spacer()
        }
    }

    // MARK: - Page 2: Learning Path

    private var learningPathPage: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xxl) {
                Spacer().frame(height: AppSpacing.xxxl)

                Image(systemName: "map")
                    .font(.system(size: 50))
                    .foregroundStyle(AppColor.accentGradient)

                Text("Choose Your Path")
                    .font(AppFont.largeTitle)
                    .foregroundStyle(.white)

                Text("Select a curated problem set to guide\nyour interview preparation")
                    .font(AppFont.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                Spacer().frame(height: AppSpacing.md)

                VStack(spacing: AppSpacing.lg) {
                    pathCard(
                        path: .grind75,
                        title: "Grind 75",
                        description: "75 essential problems curated by a Google engineer. Great for a focused prep.",
                        icon: "flame"
                    )

                    pathCard(
                        path: .neetcode150,
                        title: "NeetCode 150",
                        description: "150 problems covering all key patterns. Comprehensive and thorough.",
                        icon: "square.grid.3x3"
                    )
                }
                .padding(.horizontal, AppSpacing.xxl)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.lg)
        }
        .scrollIndicators(.hidden)
    }

    private func pathCard(path: LearningPath, title: String, description: String, icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPath = path
                UserDefaults.standard.set(path.rawValue, forKey: "learningPath")
            }
        } label: {
            HStack(spacing: AppSpacing.lg) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(selectedPath == path ? .white : AppColor.accent)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.small)
                            .fill(selectedPath == path ? AppColor.accentGradient : LinearGradient(colors: [AppColor.cardBackground], startPoint: .top, endPoint: .bottom))
                    )

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppFont.headline)
                        .foregroundStyle(.white)

                    Text(description)
                        .font(AppFont.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: selectedPath == path ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selectedPath == path ? AppColor.accent : .white.opacity(0.3))
            }
            .padding(AppSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(AppColor.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(selectedPath == path ? AppColor.accent : AppColor.cardBorder, lineWidth: selectedPath == path ? 2 : 1)
                    )
            )
            .cardShadow()
        }
    }

    // MARK: - Page 3: API Key Setup

    private var apiKeyPage: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xxl) {
                Spacer().frame(height: AppSpacing.xxxl)

                Image(systemName: "key.horizontal")
                    .font(.system(size: 50))
                    .foregroundStyle(AppColor.accentGradient)

                Text("Connect to AI")
                    .font(AppFont.largeTitle)
                    .foregroundStyle(.white)

                Text("This app uses OpenRouter to power your\nAI coding tutor. Add your API key to\nenable AI-guided learning.")
                    .font(AppFont.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                Spacer().frame(height: AppSpacing.md)

                VStack(spacing: AppSpacing.lg) {
                    SecureField("Enter your API key", text: $apiKeyInput)
                        .font(AppFont.body)
                        .padding(AppSpacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .fill(AppColor.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.medium)
                                        .stroke(AppColor.cardBorder, lineWidth: 1)
                                )
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if let error = apiKeyError {
                        Text(error)
                            .font(AppFont.caption)
                            .foregroundStyle(AppColor.error)
                    }

                    if apiKeySaved {
                        Label("API key saved securely", systemImage: "checkmark.shield.fill")
                            .font(AppFont.body)
                            .foregroundStyle(AppColor.success)
                    }

                    Button {
                        saveAPIKey()
                    } label: {
                        Text("Save Key")
                            .font(AppFont.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .fill(apiKeyInput.isEmpty ? AnyShapeStyle(Color.white.opacity(0.1)) : AnyShapeStyle(AppColor.accentGradient))
                            )
                    }
                    .disabled(apiKeyInput.isEmpty)

                    Link(destination: URL(string: "https://openrouter.ai/keys")!) {
                        Label("Get an API key at OpenRouter", systemImage: "arrow.up.right.square")
                            .font(AppFont.caption)
                            .foregroundStyle(AppColor.accent)
                    }
                }
                .padding(.horizontal, AppSpacing.xxl)

                Spacer().frame(height: AppSpacing.lg)

                Button {
                    withAnimation {
                        currentPage += 1
                    }
                } label: {
                    Text("Skip for now")
                        .font(AppFont.body)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.lg)
        }
        .scrollIndicators(.hidden)
    }

    private func saveAPIKey() {
        do {
            try APIKeyManager.shared.store(apiKey: apiKeyInput)
            apiKeySaved = true
            apiKeyError = nil
        } catch {
            apiKeyError = "Failed to save key. Please try again."
            apiKeySaved = false
        }
    }

    // MARK: - Page 4: Ready

    private var readyPage: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xxl) {
                Spacer().frame(height: AppSpacing.xxxl)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(AppColor.accentGradient)

                Text("You're all set!")
                    .font(AppFont.largeTitle)
                    .foregroundStyle(.white)

                Text("You're ready to start your coding\ninterview prep journey. Consistent\npractice is the key to success.")
                    .font(AppFont.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                Spacer().frame(height: AppSpacing.xl)

                Button {
                    onComplete()
                } label: {
                    Text("Get Started")
                        .font(AppFont.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.lg)
                        .background(AppColor.accentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                }
                .padding(.horizontal, AppSpacing.xxl)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.lg)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    OnboardingView {
        print("Onboarding complete")
    }
    .preferredColorScheme(.dark)
}
