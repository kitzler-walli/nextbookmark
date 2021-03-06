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
import NotificationBannerSwift

struct BookmarksView: View {
    //@State private var currentFolder = -1
    @State private var isShowing = false
    @State private var searchText : String = ""
    private let defaultFolder: Folder = .init(id: -20, title: "<Pull down to load your bookmarks>",  parent_folder_id: -10, books: [])
    @State var folders: [Folder] = [.init(id: -20, title: "<Pull down to load your bookmarks>",  parent_folder_id: -10, books: [])]
    
    @State var currentRoot : Folder = Folder(id: -1, title: "/", parent_folder_id: -1, books: [])
    
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
                    if self.currentRoot.id > -1 {
                        BackFolderRow().onTapGesture {
                            
                            self.currentRoot = self.folders.first(where: {$0.id == self.currentRoot.parent_folder_id})!
                            
                            CallNextcloud().get_all_bookmarks_for_folder(folder: self.currentRoot) { bookmarks in
                                if let bookmarks = bookmarks {
                                    self.currentRoot.books = bookmarks
                                    self.isShowing = false
                                }
                            }
                        }
                    }
                    
                    
                    ForEach(self.folders.filter {
                        $0.parent_folder_id == self.currentRoot.id && $0.id != self.currentRoot.id
                    }) { folder in
                        FolderRow(folder: folder).onTapGesture {
                            self.currentRoot = folder
                            CallNextcloud().get_all_bookmarks_for_folder(folder: self.currentRoot) { bookmarks in
                                if let bookmarks = bookmarks {
                                    self.currentRoot.books = bookmarks
                                    self.isShowing = false
                                }
                            }
                        }}
                    ForEach(currentRoot.books.filter {
                        self.searchText.isEmpty ? true : $0.title.lowercased().contains(self.searchText.lowercased()) || $0.url.lowercased().contains(self.searchText.lowercased())
                    }) { book in
                        BookmarkRow(book: book)
                    }
                    .onDelete(perform: { row in
                        self.delete(folder: self.currentRoot, row: row)
                    })
                    
                }
            }
            .pullToRefresh(isShowing: $isShowing) {
                self.startUpCheck()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    CallNextcloud().get_all_bookmarks_for_folder(folder: self.currentRoot) { bookmarks in
                        if let bookmarks = bookmarks {
                            self.currentRoot.books = bookmarks
                            self.isShowing = false
                        }
                    }
                }
            }.navigationBarTitle("Bookmarks", displayMode: .inline)
                .navigationBarItems(trailing: NavigationLink(destination: SettingsView()) {
                    Text("Settings")})
        }.navigationViewStyle(StackNavigationViewStyle())
            .onAppear() {
                CallNextcloud().requestFolderHierarchy() { jason in
                    if let jason = jason {
                        self.folders =  CallNextcloud().makeFolders(json: jason)
                        self.folders.append(Folder(id: -1, title: "/", parent_folder_id: -1, books: []))
                        self.currentRoot = Folder(id: -1, title: "/", parent_folder_id: -1, books: [])
                        CallNextcloud().get_all_bookmarks_for_folder(folder: self.currentRoot) { bookmarks in
                            if let bookmarks = bookmarks {
                                self.currentRoot.books = bookmarks
                                self.isShowing = false
                            }
                            
                        }
                    }
                }
        }
    }
    
    func startUpCheck() {
        let validConnection = sharedUserDefaults?.bool(forKey: SharedUserDefaults.Keys.valid) ?? false
        if !validConnection {
            let banner = NotificationBanner(title: "Missing Credentials", subtitle: "Please enter valid Nextcloud credentials in 'Settings'", style: .warning)
            banner.show()
        }
    }
    
    
    func delete(folder: Folder, row: IndexSet) {
        for index in row {
            CallNextcloud().delete(bookId: folder.books[index].id)
            self.currentRoot.books.remove(at: index)
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
