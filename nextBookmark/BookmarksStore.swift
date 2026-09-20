//
//  BookmarksStore.swift
//  nextBookmark
//
//  Holds the folder/bookmark state for BookmarksView and the logic to
//  fetch, cache and search it. Pulled out of the view so it can be
//  unit tested against a mock network client instead of a real server.
//

import Foundation
import SwiftyJSON

/// Everything BookmarksStore needs from the network layer. CallNextcloud
/// conforms to this via the extension at the bottom of this file, and tests
/// supply a mock instead.
protocol NextcloudBookmarksClient {
    func fetchFolderHierarchy(completion: @escaping ([Folder]?) -> Void)
    func fetchAllBookmarks(completion: @escaping ([Bookmark]?) -> Void)
    func fetchBookmarks(forFolder folder: Folder, completion: @escaping ([Bookmark]?) -> Void)
    func deleteBookmark(id: Int)
}

extension CallNextcloud: NextcloudBookmarksClient {
    func fetchFolderHierarchy(completion: @escaping ([Folder]?) -> Void) {
        requestFolderHierarchy { json in
            guard let json = json else {
                completion(nil)
                return
            }
            completion(self.makeFolders(json: json))
        }
    }

    func fetchAllBookmarks(completion: @escaping ([Bookmark]?) -> Void) {
        get_all_bookmarks(completion: completion)
    }

    func fetchBookmarks(forFolder folder: Folder, completion: @escaping ([Bookmark]?) -> Void) {
        get_all_bookmarks_for_folder(folder: folder, completion: completion)
    }

    func deleteBookmark(id: Int) {
        delete(bookId: id)
    }
}

final class BookmarksStore: ObservableObject {
    static let rootFolder = Folder(id: -1, title: "/", parent_folder_id: -1, books: [])

    @Published var folders: [Folder] = [.init(id: -20, title: "<Pull down to load your bookmarks>", parent_folder_id: -10, books: [])]
    @Published var currentRoot: Folder = BookmarksStore.rootFolder
    @Published var allBookmarks: [Bookmark] = []
    @Published var bookmarksCache: [Int: [Bookmark]] = [:]
    @Published var loadingFolderId: Int? = nil
    @Published var isRefreshing = false

    private(set) var hasLoadedInitially = false

    /// Subfolders of the currently open folder, in the order the folder tree returned them.
    var subfolders: [Folder] {
        folders.filter { $0.parent_folder_id == currentRoot.id && $0.id != currentRoot.id }
    }

    /// Called from the view's `.onAppear`. Only performs the full network
    /// reload the very first time the view appears; returning from Settings
    /// (which also triggers `.onAppear`) should not re-fetch everything.
    func handleOnAppear(client: NextcloudBookmarksClient) {
        guard !hasLoadedInitially else { return }
        hasLoadedInitially = true
        performFullRefresh(client: client)
    }

    /// Folder tree + full bookmark list + current folder's bookmarks, in that
    /// order. Used for the initial load, pull-to-refresh, and after settings
    /// change. Invalidates the per-folder cache, since any of those are an
    /// explicit "get me the truth from the server" moment.
    func performFullRefresh(client: NextcloudBookmarksClient, completion: (() -> Void)? = nil) {
        startUpCheck()
        isRefreshing = true
        bookmarksCache = [:]

        client.fetchFolderHierarchy { [weak self] fetchedFolders in
            guard let self = self else { return }
            guard var fetchedFolders = fetchedFolders else {
                self.currentRoot.books = []
                self.allBookmarks = []
                self.isRefreshing = false
                completion?()
                return
            }

            fetchedFolders.append(BookmarksStore.rootFolder)
            self.folders = fetchedFolders

            if self.currentRoot.id != -1 {
                self.currentRoot = BookmarksStore.rootFolder
            }

            client.fetchAllBookmarks { [weak self] allBooks in
                guard let self = self else { return }
                self.allBookmarks = allBooks ?? []

                let targetFolderId = self.currentRoot.id
                client.fetchBookmarks(forFolder: self.currentRoot) { [weak self] bookmarks in
                    guard let self = self else { return }
                    // Only apply if the user hasn't since navigated to a different folder
                    if self.currentRoot.id == targetFolderId {
                        let books = bookmarks ?? []
                        self.currentRoot.books = books
                        self.bookmarksCache[targetFolderId] = books
                    }
                    self.isRefreshing = false
                    completion?()
                }
            }
        }
    }

    /// Opens the given folder: instantly, from cache, if we've already
    /// fetched it this session; otherwise fetches it and caches the result.
    /// Guards against a slow/stale response landing after the user has since
    /// navigated to yet another folder.
    func openFolder(_ folder: Folder, client: NextcloudBookmarksClient) {
        let targetFolderId = folder.id

        if let cached = bookmarksCache[targetFolderId] {
            currentRoot = folder
            currentRoot.books = cached
            loadingFolderId = nil
            return
        }

        currentRoot = folder
        loadingFolderId = targetFolderId
        client.fetchBookmarks(forFolder: folder) { [weak self] bookmarks in
            guard let self = self else { return }
            if self.loadingFolderId == targetFolderId {
                self.loadingFolderId = nil
            }
            // Ignore this response if the user has since navigated elsewhere
            guard self.currentRoot.id == targetFolderId else { return }
            let books = bookmarks ?? []
            self.currentRoot.books = books
            self.bookmarksCache[targetFolderId] = books
        }
    }

    /// Opens the parent of the currently open folder (the "back" row).
    func openParentFolder(client: NextcloudBookmarksClient) {
        let targetFolder = folders.first(where: { $0.id == currentRoot.parent_folder_id }) ?? BookmarksStore.rootFolder
        openFolder(targetFolder, client: client)
    }

    /// Bookmarks to display for the given search text: the current folder's
    /// contents when not searching, or a title/URL match across every
    /// bookmark on the server when searching. Search always covers the full
    /// set regardless of which folders have actually been opened/cached.
    func filteredBookmarks(searchText: String) -> [Bookmark] {
        guard !searchText.isEmpty else { return currentRoot.books }
        let needle = searchText.lowercased()
        return allBookmarks.filter {
            $0.title.lowercased().contains(needle) || $0.url.lowercased().contains(needle)
        }
    }

    /// Deletes a bookmark on the server and keeps all in-memory state
    /// (current folder, global search index, and the folder cache) in sync
    /// so a deleted bookmark can't still turn up in a later search or a
    /// cached folder.
    func delete(_ bookmark: Bookmark, client: NextcloudBookmarksClient) {
        client.deleteBookmark(id: bookmark.id)

        if let allIndex = allBookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            allBookmarks.remove(at: allIndex)
        }
        if let currentIndex = currentRoot.books.firstIndex(where: { $0.id == bookmark.id }) {
            currentRoot.books.remove(at: currentIndex)
            bookmarksCache[currentRoot.id] = currentRoot.books
        }
    }

    private func startUpCheck() {
        let validConnection = sharedUserDefaults?.bool(forKey: SharedUserDefaults.Keys.valid) ?? false
        if !validConnection {
            print("WARNING: Missing Nextcloud credentials. Please enter valid credentials in Settings.")
        }
    }
}
