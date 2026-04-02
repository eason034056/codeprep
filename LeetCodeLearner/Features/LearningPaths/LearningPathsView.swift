import SwiftUI

struct LearningPathsView: View {
    @ObservedObject var viewModel: LearningPathsViewModel

    var body: some View {
        ZStack {
            AppColor.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Path picker
                LearningPathPicker(selection: $viewModel.selectedPath)
                    .padding(AppSpacing.lg)

                // Overall progress header
                VStack(spacing: AppSpacing.sm) {
                    HStack {
                        Text("\(viewModel.overallSolved)/\(viewModel.overallTotal) solved")
                            .font(AppFont.headline)
                        Spacer()
                        let pct = viewModel.overallTotal > 0
                            ? Double(viewModel.overallSolved) / Double(viewModel.overallTotal)
                            : 0.0
                        Text("\(Int(pct * 100))%")
                            .font(AppFont.headline)
                            .foregroundStyle(AppColor.accent)
                    }

                    ProgressView(value: viewModel.overallTotal > 0
                        ? Double(viewModel.overallSolved) / Double(viewModel.overallTotal)
                        : 0)
                    .tint(AppColor.accent)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.md)

                // Topic list as cute cards
                if viewModel.topicProgress.isEmpty {
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 40))
                            .foregroundStyle(AppColor.accent)
                        Text("No progress yet")
                            .font(AppFont.headline)
                        Text("Start solving problems to see your progress here.")
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(Array(viewModel.topicProgress.enumerated()), id: \.element.id) { index, topic in
                                HStack {
                                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                        Text(topic.topic.rawValue)
                                            .font(AppFont.headline)
                                        Text("\(topic.solvedCount)/\(topic.totalCount) solved")
                                            .font(AppFont.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    CircularProgressView(progress: topic.progressPercent)
                                        .frame(width: 48, height: 48)
                                }
                                .padding(AppSpacing.lg)
                                .background(AppColor.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
                                .cardShadow()
                                .padding(.horizontal, AppSpacing.lg)
                                .staggeredAppearance(index: index)
                            }
                        }
                        .padding(.vertical, AppSpacing.md)
                        .padding(.bottom, 80) // Space for custom tab bar
                    }
                }
            }
        }
        .navigationTitle("Learning Paths")
            .onChange(of: viewModel.selectedPath) { _, _ in
                viewModel.loadProgress()
            }
            .onAppear { viewModel.loadProgress() }
    }
}

// MARK: - Components

struct LearningPathPicker: View {
    @Binding var selection: LearningPath

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LearningPath.allCases, id: \.self) { path in
                pathButton(for: path, title: path.rawValue)
            }
        }
        .padding(AppSpacing.xs)
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
    }

    private func pathButton(for path: LearningPath, title: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                HapticManager.shared.light()
                selection = path
            }
        } label: {
            Text(title)
                .font(AppFont.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    ZStack {
                        if selection == path {
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .fill(AppColor.accent)
                                .shadow(color: Color.black.opacity(0.4), radius: 0, x: 0, y: 3)
                        }
                    }
                )
                .foregroundStyle(selection == path ? Color.white : Color.white.opacity(0.6))
        }
        .buttonStyle(.plain)
    }
}
