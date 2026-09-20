//
//  BookmarkEditView.swift
//  nextBookmark
//
//  A single form used both to create a new bookmark and to edit an existing
//  one. Passing `bookmark: nil` creates; passing a bookmark edits it in
//  place. Used by BookmarksView for both the manual "+" add flow and
//  tapping an existing row.
//

import SwiftUI

struct BookmarkEditView: View {
    @Environment(\.dismiss) private var dismiss
    let store: BookmarksStore
    let bookmark: Bookmark?
    let folders: [Folder]
    let defaultFolderId: Int

    @State private var title: String
    @State private var url: String
    @State private var tagsText: String
    @State private var selectedFolderId: Int
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(store: BookmarksStore, bookmark: Bookmark?, folders: [Folder], defaultFolderId: Int) {
        self.store = store
        self.bookmark = bookmark
        self.folders = folders
        self.defaultFolderId = defaultFolderId
        _title = State(initialValue: bookmark?.title ?? "")
        _url = State(initialValue: bookmark?.url ?? "")
        _tagsText = State(initialValue: bookmark?.tags.joined(separator: ", ") ?? "")
        _selectedFolderId = State(initialValue: bookmark?.folder_ids.first ?? defaultFolderId)
    }

    private var isEditing: Bool { bookmark != nil }

    private var isValid: Bool {
        !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("URL", comment: "Bookmark edit form section header")) {
                    TextField("https://example.com", text: $url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
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
                    Picker(NSLocalizedString("Folder", comment: "Bookmark folder picker label"), selection: $selectedFolderId) {
                        Text("/").tag(-1)
                        ForEach(folders.filter { $0.id != -1 }) { folder in
                            Text(folder.title).tag(folder.id)
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
                    Button("Cancel") { dismiss() }
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
        let folderIds = [selectedFolderId]
        let client = CallNextcloud()

        let onComplete: (Bool) -> Void = { success in
            isSaving = false
            if success {
                dismiss()
            } else {
                errorMessage = isEditing
                    ? NSLocalizedString("Could not save changes.", comment: "Error saving an edited bookmark")
                    : NSLocalizedString("Could not create bookmark.", comment: "Error creating a new bookmark")
            }
        }

        if let bookmark = bookmark {
            store.updateBookmark(id: bookmark.id, url: url, title: title, tags: tags, folders: folderIds, client: client, completion: onComplete)
        } else {
            store.createBookmark(url: url, title: title, tags: tags, folders: folderIds, client: client, completion: onComplete)
        }
    }
}
