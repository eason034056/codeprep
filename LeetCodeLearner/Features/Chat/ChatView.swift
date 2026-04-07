import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @StateObject private var networkMonitor = NetworkMonitor()
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(viewModel: ChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !networkMonitor.isConnected {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 14))
                    Text("No internet connection. AI chat requires network access.")
                        .font(AppFont.caption)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
                .padding(.horizontal, AppSpacing.md)
                .background(AppColor.warning)
                .accessibilityLabel("No internet connection")
            }

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .tint(AppColor.accent)
                Spacer()
            } else {
            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppSpacing.md) {
                        // Problem description as first message
                        problemDescriptionBubble

                        ForEach(viewModel.messages) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }

                        // Streaming response
                        if !viewModel.streamingText.isEmpty {
                            ChatBubbleView(
                                message: ChatMessage(
                                    sessionId: UUID(),
                                    role: .assistant,
                                    content: viewModel.streamingText
                                )
                            )
                            .id("streaming")
                        }

                        // Typing indicator
                        if viewModel.isStreaming && viewModel.streamingText.isEmpty {
                            TypingIndicatorView()
                                .id("typing")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom)
                }
                .contentMargins(.top, 0, for: .scrollContent)
                .scrollContentBackground(.hidden)
                // 💡 點擊聊天區域收鍵盤
                .onTapGesture {
                    isInputFocused = false
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation(AppAnimation.springDefault) {
                        proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.streamingText) { _, _ in
                    withAnimation {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
            }

            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.error)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.xs)
            }

            // Suggested prompts
            if !viewModel.isStreaming && !viewModel.suggestedPrompts.isEmpty {
                SuggestedPromptsView(
                    prompts: viewModel.suggestedPrompts,
                    onSelect: { viewModel.selectSuggestedPrompt($0) }
                )
            }

            if !APIKeyManager.shared.hasKey {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "key")
                        .foregroundStyle(AppColor.warning)
                    Text("Add your OpenRouter API key in Settings to use AI chat.")
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
            }

            // Input bar
            inputBar
            } // end else (not loading)
        }
        .task {
            viewModel.loadSession()
        }
        .background(AppColor.surfacePrimary)
        .navigationBarBackButtonHidden(true)
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(AppColor.surfacePrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColor.accent)
                }
                .accessibilityLabel("Go back")
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text("#\(viewModel.problem.id) \(viewModel.problem.title)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .lineLimit(1)

                    HStack(spacing: 3) {
                        DifficultyBadge(difficulty: viewModel.problem.difficulty)
                        Text("\u{00B7}")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(viewModel.problem.topic.rawValue)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Link(destination: viewModel.problem.url) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppColor.accent)
                    }
                    .accessibilityLabel("Open problem on LeetCode")

                    if viewModel.isUMPIREMode {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(AppColor.success)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: viewModel.isUMPIREMode)
            }
        }
    }

    private var problemDescriptionBubble: some View {
        let problem = viewModel.problem
        let description = problem.description ?? "View the full problem description online."
        return ChatBubbleView(
            message: ChatMessage(
                sessionId: UUID(),
                role: .assistant,
                content: description
            )
        )
        .id("problem-description")
    }

    private var inputBar: some View {
        // 💡 用 HStack + alignment: .bottom 讓送出按鈕固定在右下角，
        //    TextEditor 可自由向上展開
        HStack(alignment: .bottom, spacing: AppSpacing.sm) {
            // ⚠️ TextEditor 沒有原生 placeholder，所以用 ZStack overlay 手動實現
            ZStack(alignment: .topLeading) {
                if viewModel.inputText.isEmpty {
                    Text("Describe your approach...")
                        .font(AppFont.body)
                        .foregroundStyle(Color.gray.opacity(0.5))
                        .padding(.horizontal, 5) // 💡 對齊 TextEditor 內部文字的偏移
                        .padding(.vertical, 8)
                        .allowsHitTesting(false) // 讓點擊穿透到底下的 TextEditor
                }

                TextEditor(text: $viewModel.inputText)
                    .font(AppFont.body)
                    .focused($isInputFocused)
                    .scrollContentBackground(.hidden) // 💡 移除 TextEditor 預設灰底
                    .frame(minHeight: 36, maxHeight: 120) // 最小一行，最多約 5 行
                    .fixedSize(horizontal: false, vertical: true) // 💡 讓高度隨內容自動長高
            }

            Button {
                isInputFocused = false // 💡 送出後立即收鍵盤
                viewModel.sendMessage()
            } label: {
                Group {
                    if viewModel.isStreaming && viewModel.streamingText.isEmpty {
                        ProgressView()
                            .tint(AppColor.accent)
                            .frame(width: 32, height: 32)
                            .transition(.opacity)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(canSend ? AppColor.accent : Color.gray.opacity(0.3))
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: viewModel.isStreaming && viewModel.streamingText.isEmpty)
            }
            .disabled(!canSend)
            .accessibilityLabel("Send message")
            .accessibilityHint("Sends your message to the AI tutor")
            .buttonStyle(.scalePress)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .fill(AppColor.cardBackground)
                .shadow(color: Color(hex: "3E2C1C").opacity(0.06), radius: 4, y: 1)
        )
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColor.surfaceElevated)
    }

    private var canSend: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isStreaming
    }
}

// MARK: - Difficulty Badge

struct DifficultyBadge: View {
    let difficulty: Difficulty

    var body: some View {
        Text(difficulty.rawValue)
            .font(AppFont.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xxs)
            .background(difficulty.color.opacity(0.15))
            .foregroundStyle(difficulty.color)
            .clipShape(Capsule())
    }
}
