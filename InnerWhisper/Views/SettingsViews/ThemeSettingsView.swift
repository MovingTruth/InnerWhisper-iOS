//
//  ThemeSettingsView.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import SwiftUI

/// Lets the user independently pick a background, decorative icon, and notification sound.
///
/// Each selection is stored separately in `AppStorage` and applied live to the quote screen.
/// Adding a new background or icon only requires adding a case to `AppBackground` or `AppIcon`
/// in `QuoteTheme.swift` — it will appear here automatically.
struct ThemeSettingsView: View {
    @AppStorage("InnerWhisper.SelectedBackground") private var selectedBackground: AppBackground = .space
    @AppStorage("InnerWhisper.SelectedIcon") private var selectedIcon: AppIcon = .yinYang
    @AppStorage("InnerWhisper.SelectedSound") private var selectedSound: AppSound = .default
    @State private var showingSoundSettings = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var usesAccessibilityLayout: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        Form {
            backgroundSection
            iconSection
            soundSection
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSoundSettings) {
            SoundSettingsView()
        }
    }

    // MARK: - Background section

    private var backgroundSection: some View {
        Section {
            if usesAccessibilityLayout {
                VStack(spacing: 12) {
                    ForEach(AppBackground.allCases) { backgroundCard(for: $0, usesAccessibilityLayout: true) }
                }
                .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(AppBackground.allCases) { backgroundCard(for: $0, usesAccessibilityLayout: false) }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
                .listRowInsets(EdgeInsets())
            }
        } header: {
            Text("Background")
        } footer: {
            Text("The background shown behind every quote.")
        }
    }

    // MARK: - Icon section

    private var iconSection: some View {
        Section {
            LazyVGrid(
                columns: usesAccessibilityLayout
                    ? [GridItem(.flexible())]
                    : [GridItem(.adaptive(minimum: 90))],
                spacing: 16
            ) {
                ForEach(AppIcon.allCases) { appIcon in
                    IconPreviewCard(
                        appIcon: appIcon,
                        isSelected: selectedIcon == appIcon,
                        usesAccessibilityLayout: usesAccessibilityLayout
                    ) {
                        selectedIcon = appIcon
                        HapticFeedback.selection()
                    }
                }
            }
            .padding(.vertical, 8)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        } header: {
            Text("Icon")
        } footer: {
            Text("Decorative icon displayed above each quote. Tap and drag it to interact.")
        }
    }

    private func backgroundCard(
        for background: AppBackground,
        usesAccessibilityLayout: Bool
    ) -> some View {
        BackgroundPreviewCard(
            background: background,
            isSelected: selectedBackground == background,
            usesAccessibilityLayout: usesAccessibilityLayout
        ) {
            selectedBackground = background
            HapticFeedback.selection()
        }
    }

    // MARK: - Sound section

    private var soundSection: some View {
        Section {
            Button {
                showingSoundSettings = true
            } label: {
                if usesAccessibilityLayout {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Notification Sound", systemImage: "speaker.wave.2")
                            .foregroundStyle(.primary)
                        Text(selectedSound.displayName)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack {
                        Label("Notification Sound", systemImage: "speaker.wave.2")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(selectedSound.displayName)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .imageScale(.small)
                    }
                }
            }
            .accessibleButton(
                label: String(localized: "Notification Sound"),
                hint: String(localized: "Choose the sound that plays with each quote notification")
            )
        } header: {
            Text("Sound")
        } footer: {
            Text("Choose the sound that plays with each quote notification.")
        }
    }
}

// MARK: - Background preview card

private struct BackgroundPreviewCard: View {
    let background: AppBackground
    let isSelected: Bool
    let usesAccessibilityLayout: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Group {
                if usesAccessibilityLayout {
                    HStack(spacing: 16) {
                        backgroundSwatch(width: 64, height: 88)
                        Text(background.displayName)
                            .font(.body)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                } else {
                    VStack(spacing: 6) {
                        backgroundSwatch(width: 80, height: 120)
                        Text(background.displayName)
                            .font(.caption)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(width: 88)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "\(background.displayName) background\(isSelected ? String(localized: ", selected") : "")"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func backgroundSwatch(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            ThemeBackgroundView(background: background.background)
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? Color.accentColor : Color(.separator),
                            lineWidth: isSelected ? 3 : 1
                        )
                )

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white, Color.accentColor)
                    .padding(4)
            }
        }
    }
}

// MARK: - Icon preview card

private struct IconPreviewCard: View {
    let appIcon: AppIcon
    let isSelected: Bool
    let usesAccessibilityLayout: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Group {
                if usesAccessibilityLayout {
                    HStack(spacing: 16) {
                        iconSwatch
                        Text(appIcon.displayName)
                            .font(.body)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                } else {
                    VStack(spacing: 8) {
                        iconSwatch
                        Text(appIcon.displayName)
                            .font(.caption)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 84)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "\(appIcon.displayName) icon\(isSelected ? String(localized: ", selected") : "")"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var iconSwatch: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.systemGray6))
                .frame(width: 80, height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )

            ThemeIconView(icon: appIcon.icon, size: 48)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ThemeSettingsView()
    }
}

#Preview("Smallest iPhone — AX5") {
    NavigationStack {
        ThemeSettingsView()
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}
