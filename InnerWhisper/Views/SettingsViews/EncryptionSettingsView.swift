//
//  EncryptionSettingsView.swift
//  InnerWhisper
//
//  Settings screen for viewing and toggling AES-256-GCM data encryption.
//

import SwiftUI

/// Lets the user inspect and control the app's AES-256-GCM encryption.
///
/// Surfaced via the lock-shield toolbar button in `ContentView` so that the
/// promise made on the `SecurityWelcomeView` ("manage settings in Settings")
/// is fulfilled.
struct EncryptionSettingsView: View {
    private let encryptionManager = EncryptionManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                statusSection
                controlSection
                detailsSection
            }
            .navigationTitle("Security")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        HapticFeedback.light()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        Section {
            HStack {
                Label(
                    encryptionManager.encryptionStatus.displayName,
                    systemImage: encryptionManager.encryptionStatus.icon
                )
                .foregroundStyle(encryptionManager.encryptionStatus.color)
                Spacer()
            }
        } header: {
            Text("Current Status")
        } footer: {
            Text(encryptionManager.encryptionStatusDescription)
        }
    }

    // MARK: - Control Section

    private var controlSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { encryptionManager.isEncryptionEnabled },
                set: { enabled in
                    HapticFeedback.selection()
                    if enabled {
                        _ = encryptionManager.enableEncryption()
                    } else {
                        _ = encryptionManager.disableEncryption()
                    }
                }
            )) {
                Label("Enable Encryption", systemImage: "lock.fill")
            }
            .accessibilityLabel(String(localized: "Enable AES-256-GCM encryption"))
            .accessibilityHint(String(localized: "Toggle to enable or disable data encryption"))
        } header: {
            Text("Data Protection")
        } footer: {
            Text("Disabling encryption does not delete the key. Re-enabling will restore access to any previously encrypted data.")
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        Section {
            LabeledContent("Algorithm", value: "AES-256-GCM")
            LabeledContent("Key Storage", value: "Device Keychain")
            LabeledContent("iCloud Sync", value: "Disabled")
        } header: {
            Text("Technical Details")
        } footer: {
            Text("Encryption keys are generated on your device and stored locally. iCloud Keychain sync is disabled by default to prevent nonce-reuse across devices.")
        }
    }
}

// MARK: - Preview

#Preview {
    EncryptionSettingsView()
}

#Preview("Dark Mode") {
    EncryptionSettingsView()
        .preferredColorScheme(.dark)
}
