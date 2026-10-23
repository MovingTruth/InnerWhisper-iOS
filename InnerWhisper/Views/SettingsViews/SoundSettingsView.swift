//
//  SoundSettingsView.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import SwiftUI
import AudioToolbox
import AVFoundation

/// A self-contained sheet for all notification-sound settings.
///
/// Combines two previously separate controls into one place:
/// - Whether to always use the iOS system default sound or the sound chosen below.
/// - The actual `AppSound` selection (with per-row preview buttons).
///
/// Changes are committed when the user taps **Done**; notifications are
/// re-applied immediately so the new sound takes effect without requiring
/// the user to open Notification Settings separately.
struct SoundSettingsView: View {
    @AppStorage("InnerWhisper.SelectedSound") private var selectedSound: AppSound = .default
    @State private var useSystemDefault = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Always use system default", isOn: $useSystemDefault)
                        .onChange(of: useSystemDefault) { HapticFeedback.selection() }
                } header: {
                    Text("Sound Mode")
                } footer: {
                    Text(
                        useSystemDefault
                            ? "Notifications always play the iOS default sound."
                            : "Notifications play the sound you choose below."
                    )
                }

                if !useSystemDefault {
                    Section {
                        ForEach(AppSound.allCases) { sound in
                            SoundPreviewRow(
                                sound: sound,
                                isSelected: selectedSound == sound
                            ) {
                                selectedSound = sound
                                HapticFeedback.selection()
                            }
                        }
                    } header: {
                        Text("Notification Sound")
                    } footer: {
                        Text("Plays with each quote notification. Tap the speaker icon to preview.")
                    }
                }
            }
            .navigationTitle("Notification Sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                    .accessibleButton(label: String(localized: "Done"), hint: String(localized: "Save sound settings and close"))
                }
            }
            .onAppear { loadSettings() }
        }
    }

    private func loadSettings() {
        let s = NotificationSettings.load()
        useSystemDefault = s.notificationSoundIdentifier == "default"
    }

    private func saveAndDismiss() {
        var s = NotificationSettings.load()
        s.notificationSoundIdentifier = useSystemDefault ? "default" : nil
        s.save()
        Task { await NotificationManager.shared.apply(settings: s) }
        HapticFeedback.light()
        dismiss()
    }
}

// MARK: - Sound preview row

struct SoundPreviewRow: View {
    let sound: AppSound
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?

    var body: some View {
        HStack {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .imageScale(.large)
                    Text(sound.displayName)
                        .foregroundStyle(Color.primary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                previewSound()
            } label: {
                Image(systemName: isPlaying ? "speaker.wave.2.fill" : "speaker.wave.2")
                    .foregroundStyle(Color.accentColor)
                    .imageScale(.large)
                    .symbolEffect(.pulse, isActive: isPlaying)
            }
            .buttonStyle(.plain)
            .disabled(isPlaying)
            .accessibilityLabel(String(localized: "Preview \(sound.displayName) sound"))
        }
    }

    private func previewSound() {
        guard !isPlaying else { return }
        isPlaying = true

        if sound.soundIdentifier == "default" {
            AudioServicesPlaySystemSoundWithCompletion(SystemSoundID(1315)) {
                Task { @MainActor in
                    isPlaying = false
                }
            }
            // If the completion never runs, the speaker button would stay disabled forever.
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                Task { @MainActor in
                    isPlaying = false
                }
            }
        } else {
            let filename = sound.soundIdentifier
            let name = (filename as NSString).deletingPathExtension
            let ext  = (filename as NSString).pathExtension
            guard let url = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? nil : ext) else {
                isPlaying = false
                return
            }
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.play()
                let duration = max(audioPlayer?.duration ?? 2.0, 0.1)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                    isPlaying = false
                }
            } catch {
                isPlaying = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SoundSettingsView()
}
