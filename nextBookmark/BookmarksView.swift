//
//  BookmarksView.swift
//  nextBookmark
//
//  Created by Kai on 30.10.19.
//  Copyright © 2019 Kai. All rights reserved.
//

import SwiftUI
import SwiftyJSON
import SwiftUIRefresh

struct BookmarksView: View {
    //@State private var currentFolder = -1
    @State private var isShowing = false
    @State private var searchText : String = ""
    private let defaultFolder: Folder = .init(id: -20, title: "<Pull down to load your bookmarks>",  parent_folder_id: -10, books: [])
    @State var folders: [Folder] = [.init(id: -20, title: "<Pull down to load your bookmarks>",  parent_folder_id: -10, books: [])]
    
    @State var currentRoot : Folder = Folder(id: -1, title: "/", parent_folder_id: -1, books: [])
    @State var allBookmarks: [Bookmark] = []  // Store all bookmarks for global search
    
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
            }
        }
    }
    
    struct BackFolderRow: View {
        var body: some View {
            HStack(){
                Image(systemName: "arrowshape.turn.up.left")
            }
        }
    }
    
    var body: some View {
        NavigationView{
            VStack{
                SearchBar(text: $searchText, placeholder: "Filter bookmarks")
                OpenFolderRow(folder: self.currentRoot)
                
                List {
                    // Only show navigation elements when not searching
                    if self.searchText.isEmpty {
                        if self.currentRoot.id > -1 {
                            BackFolderRow().onTapGesture {
                                if let parentFolder = self.folders.first(where: {$0.id == self.currentRoot.parent_folder_id}) {
                                    self.currentRoot = parentFolder
                                    
                                    CallNextcloud().get_all_bookmarks_for_folder(folder: self.currentRoot) { bookmarks in
                                        DispatchQueue.main.async {
                                            if let bookmarks = bookmarks {
                                                self.currentRoot.books = bookmarks
                                            }
                                        }
                                    }
                                } else {
                                    // Fallback to root folder if parent not found
                                    let rootFolder = Folder(id: -1, title: "/", parent_folder_id: -1, books: [])
                                    self.currentRoot = rootFolder
                                    
                                    CallNextcloud().get_all_bookmarks_for_folder(folder: rootFolder) { bookmarks in
                                        DispatchQueue.main.async {
                                            if let bookmarks = bookmarks {
                                                self.currentRoot.books = bookmarks
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        
                        ForEach(self.folders.filter {
                            $0.parent_folder_id == self.currentRoot.id && $0.id != self.currentRoot.id
                        }) { folder in
                            FolderRow(folder: folder).onTapGesture {
                                print("DEBUG: Tapping on folder: \(folder.id) - \(folder.title)")
                                self.currentRoot = folder
                                CallNextcloud().get_all_bookmarks_for_folder(folder: self.currentRoot) { bookmarks in
                                    DispatchQueue.main.async {
                                        if let bookmarks = bookmarks {
                                            print("DEBUG: Successfully loaded \(bookmarks.count) bookmarks for folder \(folder.id)")
                                            self.currentRoot.books = bookmarks
                                        } else {
                                            print("ERROR: Failed to load bookmarks for folder \(folder.id)")
                                            // Keep existing bookmarks or clear them
                                            self.currentRoot.books = []
                                        }
                                    }
                                }
                            }}
                    }
                    
                    // Show bookmarks - either search results from all bookmarks or current folder
                    ForEach(self.searchText.isEmpty ? currentRoot.books : allBookmarks.filter {
                        $0.title.lowercased().contains(self.searchText.lowercased()) || $0.url.lowercased().contains(self.searchText.lowercased())
                    }) { book in
                        BookmarkRow(book: book)
                    }
                    .onDelete(perform: { indexSet in
                        if self.searchText.isEmpty {
                            // Deleting from current folder view
                            for index in indexSet {
                                if index < self.currentRoot.books.count {
                                    let bookToDelete = self.currentRoot.books[index]
                                    CallNextcloud().delete(bookId: bookToDelete.id)
                                    self.currentRoot.books.remove(at: index)
                                    // Also remove from allBookmarks
                                    if let allIndex = self.allBookmarks.firstIndex(where: { $0.id == bookToDelete.id }) {
                                        self.allBookmarks.remove(at: allIndex)
                                    }
                                }
                            }
                        } else {
                            // Deleting from search results
                            let filteredBooks = allBookmarks.filter {
                                $0.title.lowercased().contains(self.searchText.lowercased()) || $0.url.lowercased().contains(self.searchText.lowercased())
                            }
                            for index in indexSet {
                                if index < filteredBooks.count {
                                    let bookToDelete = filteredBooks[index]
                                    CallNextcloud().delete(bookId: bookToDelete.id)
                                    // Remove from allBookmarks
                                    if let allIndex = self.allBookmarks.firstIndex(where: { $0.id == bookToDelete.id }) {
                                        self.allBookmarks.remove(at: allIndex)
                                    }
                                    // Remove from currentRoot if it's there
                                    if let currentIndex = self.currentRoot.books.firstIndex(where: { $0.id == bookToDelete.id }) {
                                        self.currentRoot.books.remove(at: currentIndex)
                                    }
                                }
                            }
                        }
                    })
                    
                }
            }
            .pullToRefresh(isShowing: $isShowing) {
                print("DEBUG: Pull to refresh triggered")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.performFullRefresh()
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Text("Settings")
                    }
                }
            }
        }.navigationViewStyle(StackNavigationViewStyle())
            .onAppear() {
                self.performFullRefresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SettingsUpdated"))) { _ in
                print("DEBUG: Settings updated, performing full refresh")
                self.performFullRefresh()
            }
    }
    
    func startUpCheck() {
        let validConnection = sharedUserDefaults?.bool(forKey: SharedUserDefaults.Keys.valid) ?? false
        if !validConnection {
            print("WARNING: Missing Nextcloud credentials. Please enter valid credentials in Settings.")
        }
    }
    
    
    func performFullRefresh() {
        print("DEBUG: Starting full refresh...")
        self.startUpCheck()
        
        // Reset to loading state - this will show the spinner
        self.isShowing = true
        
        // First, reload the folder hierarchy
        CallNextcloud().requestFolderHierarchy() { jason in
            DispatchQueue.main.async {
                if let jason = jason {
                    print("DEBUG: Successfully reloaded folder hierarchy")
                    self.folders = CallNextcloud().makeFolders(json: jason)
                    self.folders.append(Folder(id: -1, title: "/", parent_folder_id: -1, books: []))
                    
                    // Reset to root folder if we're not already there
                    if self.currentRoot.id != -1 {
                        self.currentRoot = Folder(id: -1, title: "/", parent_folder_id: -1, books: [])
                    }
                    
                    print("DEBUG: Reloaded \(self.folders.count) folders")
                    
                    // Load all bookmarks for global search
                    CallNextcloud().get_all_bookmarks() { allBooks in
                        DispatchQueue.main.async {
                            if let allBooks = allBooks {
                                print("DEBUG: Loaded \(allBooks.count) total bookmarks for search")
                                self.allBookmarks = allBooks
                            } else {
                                print("ERROR: Failed to load all bookmarks")
                                self.allBookmarks = []
                            }
                            
                            // Then reload bookmarks for current folder
                            CallNextcloud().get_all_bookmarks_for_folder(folder: self.currentRoot) { bookmarks in
                                DispatchQueue.main.async {
                                    if let bookmarks = bookmarks {
                                        print("DEBUG: Reloaded \(bookmarks.count) bookmarks for current folder")
                                        self.currentRoot.books = bookmarks
                                    } else {
                                        print("ERROR: Failed to reload bookmarks")
                                        self.currentRoot.books = []
                                    }
                                    // Hide spinner only after everything is complete
                                    print("DEBUG: Full refresh completed, hiding spinner")
                                    self.isShowing = false
                                }
                            }
                        }
                    }
                } else {
                    print("ERROR: Failed to reload folder hierarchy")
                    self.currentRoot.books = []
                    self.allBookmarks = []
                    // Hide spinner on error
                    print("DEBUG: Full refresh failed, hiding spinner")
                    self.isShowing = false
                }
            }
        }
    }
}

struct BookmarkRow: View {
    let book: Bookmark
    var body: some View {
        HStack(){
            VStack (alignment: .leading) {
                Text(book.title).fontWeight(.bold)
                if tagsAvailable(for: book) {
                    Text((book.tags.joined(separator:", "))).font(.footnote).lineLimit(1)
                }
                Text(book.url).font(.footnote).lineLimit(1).foregroundColor(Color.gray)
            }.onTapGesture {
                debugPrint("TODO EDIT BOOKMARK")
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
        BookmarksView(folders : [
            Folder.init(id: -20, title: "<Pull down to load your bookmarks>",  parent_folder_id: -10, books: [Bookmark.init(id: 1, title: "Title", url: "http://localhost", tags: ["tag", "tag"], folder_ids: [-20])])
        ])
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
