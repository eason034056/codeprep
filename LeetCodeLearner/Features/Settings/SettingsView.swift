import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.pageBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.xl) {

                        // Account Section
                        SettingsSection(title: "Account") {
                            if viewModel.isAuthenticated {
                                SettingsRow {
                                    HStack(spacing: AppSpacing.md) {
                                        Image(systemName: "person.crop.circle.fill")
                                            .font(.system(size: 36))
                                            .foregroundStyle(AppColor.accentGradient)
                                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                            if let name = viewModel.currentUserName {
                                                Text(name)
                                                    .font(AppFont.headline)
                                            }
                                            if let email = viewModel.currentUserEmail {
                                                Text(email)
                                                    .font(AppFont.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Button("Sign Out", role: .destructive) {
                                            viewModel.signOut()
                                        }
                                        .font(AppFont.caption)
                                    }
                                }
                            } else {
                                SettingsRow {
                                    VStack(spacing: AppSpacing.lg) {
                                        Text("Sign in to sync your progress across devices")
                                            .font(AppFont.body)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.center)
                                            .frame(maxWidth: .infinity)

                                        Button(action: { viewModel.signInWithGoogle() }) {
                                            HStack(spacing: AppSpacing.md) {
                                                Image(systemName: "person.crop.circle.fill")
                                                    .font(.system(size: 20))
                                                Text("Continue with Google")
                                                    .font(AppFont.headline)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, AppSpacing.md)
                                            .background(AppColor.accentGradient)
                                            .foregroundStyle(.white)
                                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                                        }

                                        // 💡 Custom-styled Apple button for Settings —
                                        //    Apple HIG allows custom styling on secondary screens
                                        //    (native button only required on primary login screen).
                                        Button(action: { viewModel.signInWithApple() }) {
                                            HStack(spacing: AppSpacing.md) {
                                                Image(systemName: "apple.logo")
                                                    .font(.system(size: 20))
                                                Text("Continue with Apple")
                                                    .font(AppFont.headline)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, AppSpacing.md)
                                            .background(Color.white)
                                            .foregroundStyle(.black)
                                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                                        }

                                        if let error = viewModel.authErrorMessage {
                                            Text(error)
                                                .font(AppFont.caption)
                                                .foregroundStyle(AppColor.error)
                                        }
                                    }
                                }
                            }
                        }

                        // API Key Section
                        SettingsSection(title: "OpenRouter API Key") {
                            if viewModel.hasAPIKey {
                                SettingsRow {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppColor.success)
                                    Text("API key configured")
                                        .font(AppFont.body)
                                    Spacer()
                                    Button("Remove", role: .destructive) {
                                        viewModel.deleteAPIKey()
                                    }
                                }
                                .accessibilityLabel("API key is configured")
                                .accessibilityHint("Tap Remove to delete your API key")
                            } else {
                                SettingsRow {
                                    SecureField("Enter your OpenRouter API key", text: $viewModel.apiKey)
                                        .textContentType(.none)
                                        .autocorrectionDisabled()
                                        .font(AppFont.body)
                                }
                                
                                Divider().background(AppColor.surfaceElevated)
                                
                                SettingsRow {
                                    Button(action: {
                                        HapticManager.shared.light()
                                        viewModel.saveAPIKey()
                                    }) {
                                        Text("Save Key")
                                            .font(AppFont.headline)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .disabled(viewModel.apiKey.isEmpty)
                                    .accessibilityLabel("Save API key")
                                }
                            }

                            if let error = viewModel.errorMessage {
                                Divider().background(AppColor.surfaceElevated)
                                SettingsRow {
                                    Text(error)
                                        .font(AppFont.caption)
                                        .foregroundStyle(AppColor.error)
                                }
                            }
                        }

                        // Model Selection
                        SettingsSection(title: "AI Model") {
                            SettingsRow {
                                VStack(spacing: AppSpacing.md) {
                                    // Toggle between preset and custom
                                    HStack(spacing: 0) {
                                        ModelModeButton(title: "Preset", isSelected: !viewModel.isCustomModel) {
                                            if viewModel.isCustomModel {
                                                viewModel.switchToPreset(viewModel.availableModels[0])
                                            }
                                        }
                                        ModelModeButton(title: "Custom", isSelected: viewModel.isCustomModel) {
                                            viewModel.switchToCustom()
                                        }
                                    }
                                    .padding(AppSpacing.xs)
                                    .background(Color.black.opacity(0.25))
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))

                                    if viewModel.isCustomModel {
                                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                            HStack(spacing: AppSpacing.sm) {
                                                TextField("e.g. anthropic/claude-sonnet-4", text: $viewModel.customModelText)
                                                    .font(AppFont.body)
                                                    .autocorrectionDisabled()
                                                    .textInputAutocapitalization(.never)
                                                Button {
                                                    HapticManager.shared.medium()
                                                    viewModel.applyCustomModel()
                                                } label: {
                                                    HStack(spacing: AppSpacing.xs) {
                                                        if viewModel.showModelApplied {
                                                            Image(systemName: "checkmark")
                                                                .font(.system(size: 10, weight: .bold))
                                                        }
                                                        Text(viewModel.showModelApplied ? "Applied" : "Apply")
                                                            .font(AppFont.caption)
                                                            .fontWeight(.bold)
                                                    }
                                                    .padding(.horizontal, AppSpacing.md)
                                                    .padding(.vertical, AppSpacing.sm)
                                                    .background(viewModel.showModelApplied ? AnyShapeStyle(AppColor.success) : AnyShapeStyle(AppColor.accentGradient))
                                                    .foregroundStyle(.white)
                                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                                                    .animation(.easeInOut(duration: 0.2), value: viewModel.showModelApplied)
                                                }
                                                .disabled(viewModel.customModelText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                            }

                                            // Show currently active model
                                            HStack(spacing: AppSpacing.xs) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(AppColor.success)
                                                Text("Active: \(viewModel.selectedModel)")
                                                    .font(AppFont.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                    } else {
                                        Picker("Model", selection: $viewModel.selectedModel) {
                                            ForEach(viewModel.availableModels, id: \.self) { model in
                                                Text(model.split(separator: "/").last.map(String.init) ?? model)
                                                    .tag(model)
                                            }
                                        }
                                        .tint(AppColor.accent)
                                        .onChange(of: viewModel.selectedModel) { _, _ in
                                            viewModel.saveModel()
                                        }
                                    }
                                }
                            }
                        }

                        // Learning Path
                        SettingsSection(title: "Learning Path") {
                            SettingsRow {
                                LearningPathPicker(selection: $viewModel.selectedPath)
                                    .onChange(of: viewModel.selectedPath) { _, _ in
                                        viewModel.saveLearningPath()
                                    }
                            }
                        }

                        // Notification Times
                        SettingsSection(title: "Notification Times") {
                            NotificationTimeRow(label: "Morning", icon: "sunrise.fill", iconColor: Color(hex: "FBBF24"), components: $viewModel.notificationTime1)
                            Divider().background(Color.white.opacity(0.06)).padding(.horizontal, AppSpacing.lg)
                            NotificationTimeRow(label: "Afternoon", icon: "sun.max.fill", iconColor: Color(hex: "F97316"), components: $viewModel.notificationTime2)
                            Divider().background(Color.white.opacity(0.06)).padding(.horizontal, AppSpacing.lg)
                            NotificationTimeRow(label: "Evening", icon: "moon.fill", iconColor: Color(hex: "8B5CF6"), components: $viewModel.notificationTime3)
                        }

                        // Data Management
                        SettingsSection(title: "Data Management") {
                            SettingsRow {
                                Button(action: {
                                    HapticManager.shared.light()
                                    viewModel.exportData()
                                }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                            .foregroundStyle(AppColor.accent)
                                        Text("Export My Data")
                                            .font(AppFont.headline)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Export your data as JSON")
                            }
                            Divider().background(AppColor.surfaceElevated)
                            SettingsRow {
                                Button(action: {
                                    viewModel.showDeleteConfirmation = true
                                }) {
                                    HStack {
                                        Image(systemName: "trash")
                                            .foregroundStyle(AppColor.error)
                                        Text("Delete All Data")
                                            .font(AppFont.headline)
                                            .foregroundStyle(AppColor.error)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete all app data")
                                .accessibilityHint("Permanently removes all progress, chat history, and preferences")
                            }
                        }

                        // Legal
                        SettingsSection(title: "Legal") {
                            SettingsRow {
                                Link(destination: URL(string: "https://eason034056.github.io/codereps/privacy.html")!) {
                                    HStack {
                                        Image(systemName: "hand.raised")
                                            .foregroundStyle(AppColor.accent)
                                        Text("Privacy Policy")
                                            .font(AppFont.headline)
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .foregroundStyle(.white)
                            }
                            Divider().background(AppColor.surfaceElevated)
                            SettingsRow {
                                Link(destination: URL(string: "https://eason034056.github.io/codereps/terms.html")!) {
                                    HStack {
                                        Image(systemName: "doc.text")
                                            .foregroundStyle(AppColor.accent)
                                        Text("Terms of Service")
                                            .font(AppFont.headline)
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .foregroundStyle(.white)
                            }
                        }

                        // About
                        SettingsSection(title: "About") {
                            SettingsRow {
                                Text("Version")
                                    .font(AppFont.headline)
                                Spacer()
                                Text("1.0.0")
                                    .font(AppFont.body)
                                    .foregroundStyle(.secondary)
                            }
                            Divider().background(AppColor.surfaceElevated)
                            SettingsRow {
                                Link("Get OpenRouter API Key", destination: URL(string: "https://openrouter.ai/keys")!)
                                    .font(AppFont.headline)
                                    .foregroundStyle(AppColor.accent)
                            }
                        }
                    }
                    .padding(.vertical, AppSpacing.xl)
                    .padding(.bottom, 80) // Tab bar clearance
                }
            }
            .navigationTitle("Settings")
            .alert("API Key Saved", isPresented: $viewModel.showSaveConfirmation) {
                Button("OK") {}
            }
            .alert("Delete All Data", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Everything", role: .destructive) {
                    viewModel.deleteAllData()
                }
            } message: {
                Text("This will permanently delete all your progress, chat history, review cards, and preferences. This action cannot be undone.")
            }
            .sheet(isPresented: $viewModel.showExportSheet) {
                if let exportURL = viewModel.exportFileURL {
                    ShareSheet(activityItems: [exportURL])
                }
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Components

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title.uppercased())
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, AppSpacing.lg)

            VStack(spacing: 0) {
                content()
            }
            .background(AppColor.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
            .cardShadow()
            .padding(.horizontal, AppSpacing.lg)
        }
    }
}

struct SettingsRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack {
            content()
        }
        .padding(AppSpacing.lg)
    }
}

// MARK: - Model Mode Button

struct ModelModeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.light()
            action()
        }) {
            Text(title)
                .font(AppFont.headline)
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(
                    isSelected
                        ? AnyShapeStyle(AppColor.accentGradient)
                        : AnyShapeStyle(Color.clear)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.large - AppSpacing.xs))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notification Time Row

struct NotificationTimeRow: View {
    let label: String
    let icon: String
    let iconColor: Color
    @Binding var components: DateComponents

    var body: some View {
        SettingsRow {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
                    .frame(width: 28)

                Text(label)
                    .font(AppFont.headline)

                Spacer()

                DatePicker(
                    "",
                    selection: Binding(
                        get: { Calendar.current.date(from: components) ?? Date() },
                        set: { components = Calendar.current.dateComponents([.hour, .minute], from: $0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .tint(AppColor.accent)
            }
        }
    }
}
