//
//  UserQuoteEditorSheet.swift
//  InnerWhisper
//

import SwiftUI

/// Form for adding or editing a user-owned quote (stored encrypted, synced via iCloud when available).
struct UserQuoteEditorSheet: View {

    @Environment(\.dismiss) private var dismiss

    private let existingQuote: Quote?

    @State private var text: String
    @State private var author: String
    @State private var errorMessage: String?
    @State private var errorIsSyncWarning = false
    @State private var isSaving = false
    @State private var showResetConfirmation = false
    @State private var isResetting = false

    var body: some View {
        NavigationStack {
            Form {
                UserQuoteBrowseModeSection()

                Section {
                    TextField("Quote", text: $text, axis: .vertical)
                        .lineLimit(5...12)
                    TextField("Author", text: $author)
                } footer: {
                    Text("Up to \(UserAddedQuotesStore.maxQuoteLength) characters for the quote and \(UserAddedQuotesStore.maxAuthorLength) for the author.")
                }

                Section {
                    Text("Your text is encrypted on this device before it is stored. If you use iCloud, the encrypted file can sync to your other Apple devices — handled by Apple’s systems, not by us. We never receive your quotes on our servers.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    Text("How your words are kept private")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(errorIsSyncWarning ? Color.orange : Color.red)
                            .font(.footnote)
                        if errorIsSyncWarning {
                            Button(role: .destructive) {
                                showResetConfirmation = true
                            } label: {
                                Label(
                                    isResetting ? "Resetting…" : "Reset Quote Storage",
                                    systemImage: "trash"
                                )
                            }
                            .disabled(isResetting)
                        }
                    }
                }
            }
            .navigationTitle(existingQuote == nil ? "Add Quote" : "Edit Quote")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Reset Quote Storage?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All My Quotes", role: .destructive) {
                    isResetting = true
                    Task {
                        await UserAddedQuotesStore.shared.resetStorage()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes all your saved quotes and removes the encryption key from this device. It cannot be undone.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaving)
                }
            }
        }
    }

    init(quote: Quote?) {
        existingQuote = quote
        _text = State(initialValue: quote?.text ?? "")
        _author = State(initialValue: quote?.author ?? "")
    }

    private func save() {
        guard !isSaving else { return }
        errorMessage = nil
        errorIsSyncWarning = false
        isSaving = true
        do {
            if let existing = existingQuote {
                try UserAddedQuotesStore.shared.updateQuote(id: existing.id, text: text, author: author)
            } else {
                try UserAddedQuotesStore.shared.addQuote(text: text, author: author)
            }
            dismiss()
        } catch let e as UserAddedQuoteError {
            isSaving = false
            errorMessage = e.errorDescription
            if case .iCloudKeychainPending = e {
                errorIsSyncWarning = true
            }
        } catch let e as LocalizedError {
            isSaving = false
            errorMessage = e.errorDescription ?? String(describing: e)
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("Add") {
    UserQuoteEditorSheet(quote: nil)
}

#Preview("Edit") {
    UserQuoteEditorSheet(quote: Quote(
        id: "1",
        displayNumber: 1,
        text: "Sample",
        author: "Me",
        category: "User Added",
        sourceFile: UserAddedQuotesStore.sourceFileName
    ))
}
