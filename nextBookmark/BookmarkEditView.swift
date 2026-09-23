//
//  BookmarkEditView.swift
//  nextBookmark
//
//  A single form used both to create a new bookmark and to edit an existing
//  one. Passing `bookmark: nil` creates; passing a bookmark edits it in
//  place. Used by BookmarksView for both the manual "+" add flow and
//  tapping an existing row, and by the Share Extension for shared links.
//  It is built into both targets, so it only talks to the outside world
//  through the `onSave`/`onFinish` closures (the extension has no
//  BookmarksStore).
//

import SwiftUI

/// The form's contents at the moment Save is tapped.
struct BookmarkDraft {
    let url: String
    let title: String
    let tags: [String]
    let folderIds: [Int]
}

struct BookmarkEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let bookmark: Bookmark?
    let folders: [Folder]
    let isLoadingFolders: Bool
    /// App extensions can't open URLs, so the Share Extension hides the button.
    let allowsOpeningURL: Bool
    /// Performs the create/update and reports success.
    let onSave: (BookmarkDraft, @escaping (Bool) -> Void) -> Void
    /// Called with `true` after a successful save or `false` on Cancel.
    /// When nil the view dismisses itself, which is what a sheet wants.
    let onFinish: ((Bool) -> Void)?

    @State private var title: String
    @State private var url: String
    @State private var tagsText: String
    @State private var selectedFolderId: Int
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(bookmark: Bookmark?,
         folders: [Folder],
         defaultFolderId: Int,
         initialURL: String = "",
         initialTitle: String = "",
         isLoadingFolders: Bool = false,
         allowsOpeningURL: Bool = true,
         onSave: @escaping (BookmarkDraft, @escaping (Bool) -> Void) -> Void,
         onFinish: ((Bool) -> Void)? = nil) {
        self.bookmark = bookmark
        self.folders = folders
        self.isLoadingFolders = isLoadingFolders
        self.allowsOpeningURL = allowsOpeningURL
        self.onSave = onSave
        self.onFinish = onFinish
        _title = State(initialValue: bookmark?.title ?? initialTitle)
        _url = State(initialValue: bookmark?.url ?? initialURL)
        _tagsText = State(initialValue: bookmark?.tags.joined(separator: ", ") ?? "")
        _selectedFolderId = State(initialValue: bookmark?.folder_ids.first ?? defaultFolderId)
    }

    private var isEditing: Bool { bookmark != nil }

    /// The URL field's contents as an openable web URL, or nil if it isn't one.
    private var openableURL: URL? {
        guard let parsed = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = parsed.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else { return nil }
        return parsed
    }

    private var isValid: Bool {
        !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("URL", comment: "Bookmark edit form section header")) {
                    HStack {
                        TextField("https://example.com", text: $url)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        if allowsOpeningURL {
                            Button(action: {
                                if let openableURL = openableURL { openURL(openableURL) }
                            }) {
                                Image(systemName: "safari")
                            }
                            .buttonStyle(.borderless)
                            .disabled(openableURL == nil)
                            .accessibilityLabel(Text("Open URL", comment: "Accessibility label for the button that opens the bookmark URL in the browser"))
                        }
                    }
                }
                Section(header: Text("Title", comment: "Bookmark edit form section header")) {
                    TextField(NSLocalizedString("Title", comment: "Bookmark title field placeholder"), text: $title)
                }
                Section(header: Text("Tags", comment: "Bookmark edit form section header")) {
                    TextField(NSLocalizedString("tag1, tag2", comment: "Bookmark tags field placeholder, a comma-separated example"), text: $tagsText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                Section(header: Text("Folder", comment: "Bookmark edit form section header")) {
                    if isLoadingFolders {
                        HStack {
                            Text("Folder", comment: "Bookmark folder picker label")
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        Picker(NSLocalizedString("Folder", comment: "Bookmark folder picker label"), selection: $selectedFolderId) {
                            Text("/").tag(-1)
                            ForEach(folders.filter { $0.id != -1 }) { folder in
                                Text(folder.title).tag(folder.id)
                            }
                        }
                    }
                }
                if let errorMessage = errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                }
            }
            .navigationTitle(isEditing ? Text("Edit Bookmark", comment: "Navigation title when editing an existing bookmark") : Text("Add Bookmark", comment: "Navigation title when creating a new bookmark"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { finish(saved: false) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save", action: save)
                            .disabled(!isValid)
                    }
                }
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let draft = BookmarkDraft(url: url, title: title, tags: tags, folderIds: [selectedFolderId])

        onSave(draft) { success in
            isSaving = false
            if success {
                finish(saved: true)
            } else {
                errorMessage = isEditing
                    ? NSLocalizedString("Could not save changes.", comment: "Error saving an edited bookmark")
                    : NSLocalizedString("Could not create bookmark.", comment: "Error creating a new bookmark")
            }
        }
    }

    private func finish(saved: Bool) {
        if let onFinish = onFinish {
            onFinish(saved)
        } else {
            dismiss()
        }
    }
}
