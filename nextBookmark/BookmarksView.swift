//
//  BookmarksView.swift
//  nextBookmark
//
//  Created by Kai on 30.10.19.
//  Copyright © 2019 Kai. All rights reserved.
//

import SwiftUI
import SwiftUIRefresh

struct BookmarksView: View {
    @StateObject private var store: BookmarksStore
    @State private var searchText: String = ""
    @State private var editingBookmark: Bookmark?
    @State private var isAddingBookmark = false

    init(store: BookmarksStore = BookmarksStore()) {
        _store = StateObject(wrappedValue: store)
    }

    struct OpenFolderRow: View {
        var folder: Folder
        var body: some View {
            HStack(){
                Image(systemName: "folder")
                Text(folder.title).fontWeight(.bold)
            }
        }
    }

    struct FolderRow: View {
        var folder: Folder
        var body: some View {
            HStack(){
                Image(systemName: "folder.fill")
                Text(folder.title).fontWeight(.bold)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
    }

    struct BackFolderRow: View {
        var body: some View {
            HStack(){
                Image(systemName: "arrowshape.turn.up.left")
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
    }

    var body: some View {
        NavigationView{
            VStack{
                SearchBar(text: $searchText, placeholder: NSLocalizedString("Filter bookmarks", comment: "Placeholder for the bookmark search field"))
                OpenFolderRow(folder: store.currentRoot)

                List {
                    // Only show navigation elements when not searching
                    if searchText.isEmpty {
                        if store.currentRoot.id > -1 {
                            BackFolderRow().onTapGesture {
                                store.openParentFolder(client: CallNextcloud())
                            }
                        }

                        ForEach(store.subfolders) { folder in
                            FolderRow(folder: folder).onTapGesture {
                                store.openFolder(folder, client: CallNextcloud())
                            }
                        }
                    }

                    // Show a spinner while the currently open folder's bookmarks are still loading
                    if searchText.isEmpty && store.loadingFolderId == store.currentRoot.id {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }

                    // Show bookmarks - either search results from all bookmarks or current folder
                    ForEach(store.filteredBookmarks(searchText: searchText)) { book in
                        BookmarkRow(book: book).onTapGesture {
                            editingBookmark = book
                        }
                    }
                    .onDelete(perform: { indexSet in
                        let displayedBooks = store.filteredBookmarks(searchText: searchText)
                        for index in indexSet {
                            if index < displayedBooks.count {
                                store.delete(displayedBooks[index], client: CallNextcloud())
                            }
                        }
                    })

                }
            }
            .pullToRefresh(isShowing: Binding(
                get: { store.isRefreshing },
                set: { store.isRefreshing = $0 }
            )) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    store.performFullRefresh(client: CallNextcloud())
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isAddingBookmark = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Text("Settings")
                    }
                }
            }
            .sheet(item: $editingBookmark) { book in
                BookmarkEditView(store: store, bookmark: book, folders: store.folders, defaultFolderId: store.currentRoot.id)
            }
            .sheet(isPresented: $isAddingBookmark) {
                BookmarkEditView(store: store, bookmark: nil, folders: store.folders, defaultFolderId: store.currentRoot.id)
            }
        }.navigationViewStyle(StackNavigationViewStyle())
            .onAppear() {
                // Only do a full reload on first launch; returning from Settings shouldn't
                // re-fetch everything when nothing changed (see SettingsUpdated below).
                store.handleOnAppear(client: CallNextcloud())
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SettingsUpdated"))) { _ in
                store.performFullRefresh(client: CallNextcloud())
            }
    }
}

struct BookmarkRow: View {
    let book: Bookmark
    var body: some View {
        HStack(){
            FaviconView(bookmarkId: book.id)
            VStack (alignment: .leading) {
                Text(book.title).fontWeight(.bold)
                if tagsAvailable(for: book) {
                    Text((book.tags.joined(separator:", "))).font(.footnote).lineLimit(1)
                }
                Text(book.url).font(.footnote).lineLimit(1).foregroundColor(Color.gray)
            }
            Spacer()
            Divider()
            Button(action: {
                guard let url = URL(string: self.book.url) else { return }
                UIApplication.shared.open(url)
            }) {
                Image(systemName: "safari")
            }
            .padding(.leading)
        }
        .contentShape(Rectangle())
    }
}



private func tagsAvailable(for book: Bookmark) -> Bool {
    if (book.tags.isEmpty) {
        return false
    }
    return true
}

struct BookmarksView_Previews: PreviewProvider {
    static var previews: some View {
        let store = BookmarksStore()
        store.folders = [
            Folder(id: -20, title: "<Pull down to load your bookmarks>", parent_folder_id: -10, books: [Bookmark(id: 1, title: "Title", url: "http://localhost", tags: ["tag", "tag"], folder_ids: [-20])])
        ]
        return BookmarksView(store: store)
    }
}

struct SearchBar: UIViewRepresentable {

    @Binding var text: String
    var placeholder: String

    class Coordinator: NSObject, UISearchBarDelegate {

        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
        }

        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            text = ""
            searchBar.text = ""
            searchBar.resignFirstResponder()
            searchBar.endEditing(true)
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
            searchBar.endEditing(true)
        }
    }

    func makeCoordinator() -> SearchBar.Coordinator {
        return Coordinator(text: $text)
    }

    func makeUIView(context: UIViewRepresentableContext<SearchBar>) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        //searchBar.delegate = context.coordinator
        searchBar.delegate = context.coordinator
        searchBar.placeholder = placeholder
        searchBar.searchBarStyle = .minimal
        searchBar.autocapitalizationType = .none
        searchBar.showsCancelButton = true
        return searchBar
    }

    func updateUIView(_ uiView: UISearchBar, context: UIViewRepresentableContext<SearchBar>) {
        uiView.text = text
    }
}
