//
//  BookmarksStoreTests.swift
//  nextBookmarkTests
//
//  Exercises BookmarksStore's fetch/cache/search/delete logic against a
//  scripted mock client, so these run fast and deterministically without a
//  real Nextcloud server.
//

import XCTest
@testable import nextBookmark

/// A scriptable stand-in for CallNextcloud. Every call is recorded so tests
/// can assert on how many times (and in what order) the store hit the
/// "network", and every response can be completed synchronously or deferred
/// to simulate a slow/stale response arriving late.
final class MockNextcloudClient: NextcloudBookmarksClient {
    var folderHierarchyResult: [Folder]? = []
    var allBookmarksResult: [Bookmark]? = []
    /// Per-folder-id scripted response for fetchBookmarks(forFolder:).
    var bookmarksByFolder: [Int: [Bookmark]] = [:]

    private(set) var folderHierarchyCallCount = 0
    private(set) var allBookmarksCallCount = 0
    private(set) var deletedBookmarkIds: [Int] = []
    /// Every folder id fetchBookmarks(forFolder:) was called with, in order.
    private(set) var fetchedFolderIds: [Int] = []

    /// When set, fetchBookmarks(forFolder:) does not call its completion
    /// immediately; the test must call `completeDeferredFetch()` itself.
    /// Used to simulate a slow response that resolves after the user has
    /// already navigated elsewhere.
    var deferCompletionForFolderId: Int?
    private var deferredCompletion: (() -> Void)?

    func fetchFolderHierarchy(completion: @escaping ([Folder]?) -> Void) {
        folderHierarchyCallCount += 1
        completion(folderHierarchyResult)
    }

    func fetchAllBookmarks(completion: @escaping ([Bookmark]?) -> Void) {
        allBookmarksCallCount += 1
        completion(allBookmarksResult)
    }

    func fetchBookmarks(forFolder folder: Folder, completion: @escaping ([Bookmark]?) -> Void) {
        fetchedFolderIds.append(folder.id)
        let result = bookmarksByFolder[folder.id] ?? []

        if folder.id == deferCompletionForFolderId {
            deferredCompletion = { completion(result) }
            return
        }
        completion(result)
    }

    func deleteBookmark(id: Int) {
        deletedBookmarkIds.append(id)
    }

    var createBookmarkResult: Bookmark?
    var updateBookmarkResult: Bookmark?
    private(set) var createBookmarkCallCount = 0
    private(set) var updatedBookmarkIds: [Int] = []

    func createBookmark(url: String, title: String, tags: [String], folders: [Int], completion: @escaping (Bookmark?, Error?) -> Void) {
        createBookmarkCallCount += 1
        completion(createBookmarkResult, nil)
    }

    func updateBookmark(id: Int, url: String, title: String, tags: [String], folders: [Int], completion: @escaping (Bookmark?, Error?) -> Void) {
        updatedBookmarkIds.append(id)
        completion(updateBookmarkResult, nil)
    }

    /// Resolves whatever fetch was deferred via `deferCompletionForFolderId`.
    func completeDeferredFetch() {
        deferredCompletion?()
        deferredCompletion = nil
    }
}

final class BookmarksStoreTests: XCTestCase {

    private let workFolder = Folder(id: 2, title: "Work", parent_folder_id: -1, books: [])
    private let personalFolder = Folder(id: 3, title: "Personal", parent_folder_id: -1, books: [])

    private func makeBookmark(_ id: Int, _ title: String, url: String = "https://example.com", folders: [Int] = []) -> Bookmark {
        Bookmark(id: id, title: title, url: url, tags: [], folder_ids: folders)
    }

    // MARK: - Search finds newly created bookmarks

    func testSearchFindsBookmarkAfterItIsCreatedOnTheServer() {
        let client = MockNextcloudClient()
        client.folderHierarchyResult = [workFolder, personalFolder]
        client.allBookmarksResult = [makeBookmark(1, "Apple", folders: [-1])]

        let store = BookmarksStore()
        store.performFullRefresh(client: client)

        // Not present yet.
        XCTAssertTrue(store.filteredBookmarks(searchText: "GitHub").isEmpty)

        // Simulate the bookmark having been created elsewhere (e.g. via the
        // Share Extension) and the user pulling to refresh.
        client.allBookmarksResult = [
            makeBookmark(1, "Apple", folders: [-1]),
            makeBookmark(2, "GitHub", url: "https://github.com", folders: [2])
        ]
        store.performFullRefresh(client: client)

        let results = store.filteredBookmarks(searchText: "GitHub")
        XCTAssertEqual(results.map { $0.id }, [2])
    }

    func testSearchMatchesOnUrlAsWellAsTitle() {
        let client = MockNextcloudClient()
        client.folderHierarchyResult = []
        client.allBookmarksResult = [makeBookmark(1, "My Cloud", url: "https://nextcloud.com")]

        let store = BookmarksStore()
        store.performFullRefresh(client: client)

        XCTAssertEqual(store.filteredBookmarks(searchText: "nextcloud").map { $0.id }, [1])
        XCTAssertEqual(store.filteredBookmarks(searchText: "MY CLOUD").map { $0.id }, [1]) // case-insensitive
    }

    func testSearchIsIndependentOfWhichFolderIsCurrentlyOpenOrCached() {
        // A bookmark that lives in a folder the user has never opened
        // should still be found by search, since search reads allBookmarks,
        // not the per-folder cache.
        let client = MockNextcloudClient()
        client.folderHierarchyResult = [workFolder, personalFolder]
        client.allBookmarksResult = [makeBookmark(5, "Nextcloud", folders: [3])]
        client.bookmarksByFolder[-1] = []

        let store = BookmarksStore()
        store.performFullRefresh(client: client)

        XCTAssertTrue(store.bookmarksCache[3] == nil, "Personal folder was never opened, so it shouldn't be cached")
        XCTAssertEqual(store.filteredBookmarks(searchText: "Nextcloud").map { $0.id }, [5])
    }

    // MARK: - Delete then search again for the deleted item

    func testDeletedBookmarkNoLongerFoundInSearchAfterNavigatingToAnotherFolder() {
        let client = MockNextcloudClient()
        client.folderHierarchyResult = [workFolder, personalFolder]
        let github = makeBookmark(10, "GitHub", url: "https://github.com", folders: [2])
        client.allBookmarksResult = [github]
        client.bookmarksByFolder[2] = [github]
        client.bookmarksByFolder[3] = []

        let store = BookmarksStore()
        store.performFullRefresh(client: client)

        // Open Work, confirm GitHub is there, delete it.
        store.openFolder(workFolder, client: client)
        XCTAssertEqual(store.currentRoot.books.map { $0.id }, [10])
        store.delete(github, client: client)
        XCTAssertEqual(client.deletedBookmarkIds, [10])
        XCTAssertTrue(store.currentRoot.books.isEmpty)

        // Navigate away to a different folder...
        store.openFolder(personalFolder, client: client)
        XCTAssertEqual(store.currentRoot.id, personalFolder.id)

        // ...then search again for the deleted item: it must not turn up.
        XCTAssertTrue(store.filteredBookmarks(searchText: "GitHub").isEmpty,
                      "A deleted bookmark must not still be found by search")
    }

    func testDeletingWhileSearchingAlsoRemovesFromCurrentFolderAndItsCache() {
        let client = MockNextcloudClient()
        client.folderHierarchyResult = [workFolder]
        let github = makeBookmark(10, "GitHub", folders: [2])
        client.allBookmarksResult = [github]
        client.bookmarksByFolder[2] = [github]

        let store = BookmarksStore()
        store.performFullRefresh(client: client)
        store.openFolder(workFolder, client: client)
        XCTAssertEqual(store.bookmarksCache[2]?.map { $0.id }, [10])

        // Delete as if the user swiped it away while a search was active.
        store.delete(github, client: client)

        XCTAssertTrue(store.allBookmarks.isEmpty)
        XCTAssertTrue(store.currentRoot.books.isEmpty)
        XCTAssertEqual(store.bookmarksCache[2]?.count, 0, "Cache for the folder it was deleted from must be updated too")
    }

    func testDeletingABookmarkNotInTheCurrentFolderLeavesCurrentFolderUntouched() {
        // Simulates deleting a search result that belongs to a folder other
        // than the one currently open.
        let client = MockNextcloudClient()
        client.folderHierarchyResult = [workFolder, personalFolder]
        let github = makeBookmark(10, "GitHub", folders: [2])
        let nextcloud = makeBookmark(11, "Nextcloud", folders: [3])
        client.allBookmarksResult = [github, nextcloud]
        client.bookmarksByFolder[2] = [github]

        let store = BookmarksStore()
        store.performFullRefresh(client: client)
        store.openFolder(workFolder, client: client)

        store.delete(nextcloud, client: client)

        XCTAssertEqual(client.deletedBookmarkIds, [11])
        XCTAssertEqual(store.allBookmarks.map { $0.id }, [10])
        XCTAssertEqual(store.currentRoot.books.map { $0.id }, [10], "Deleting an unrelated bookmark shouldn't touch the open folder")
    }

    // MARK: - Per-folder cache

    func testOpeningTheSameFolderTwiceOnlyFetchesFromTheNetworkOnce() {
        let client = MockNextcloudClient()
        client.folderHierarchyResult = [workFolder]
        client.bookmarksByFolder[2] = [makeBookmark(1, "GitHub", folders: [2])]

        let store = BookmarksStore()
        store.openFolder(workFolder, client: client)
        store.openFolder(personalFolder, client: client) // navigate away
        store.openFolder(workFolder, client: client)      // and back

        XCTAssertEqual(client.fetchedFolderIds, [2, 3], "Second visit to Work should be served from cache, not refetched")
        XCTAssertEqual(store.currentRoot.books.map { $0.id }, [1])
    }

    func testPullToRefreshInvalidatesTheCacheSoFoldersAreRefetched() {
        let client = MockNextcloudClient()
        client.folderHierarchyResult = [workFolder]
        client.bookmarksByFolder[2] = [makeBookmark(1, "GitHub", folders: [2])]

        let store = BookmarksStore()
        store.openFolder(workFolder, client: client)
        XCTAssertEqual(client.fetchedFolderIds, [2])

        store.performFullRefresh(client: client) // pull-to-refresh / settings change
        store.openFolder(workFolder, client: client)

        XCTAssertEqual(client.fetchedFolderIds, [2, -1, 2], "After an explicit refresh, opening Work again should hit the network")
    }

    func testDeletingKeepsCacheInSyncSoAFolderReopenDoesNotResurrectTheDeletedBookmark() {
        let client = MockNextcloudClient()
        client.folderHierarchyResult = [workFolder, personalFolder]
        let github = makeBookmark(10, "GitHub", folders: [2])
        client.bookmarksByFolder[2] = [github]

        let store = BookmarksStore()
        store.openFolder(workFolder, client: client)
        store.delete(github, client: client)
        store.openFolder(personalFolder, client: client)
        store.openFolder(workFolder, client: client) // back to Work

        XCTAssertEqual(client.fetchedFolderIds, [2, 3], "Work should be served from the (now-empty) cache, not refetched")
        XCTAssertTrue(store.currentRoot.books.isEmpty, "The deleted bookmark must not reappear from a stale cache entry")
    }

    // MARK: - Stale/out-of-order network response guard

    func testSlowResponseForAnAbandonedFolderDoesNotClobberTheFolderTheUserNavigatedTo() {
        let client = MockNextcloudClient()
        client.folderHierarchyResult = [workFolder, personalFolder]
        client.deferCompletionForFolderId = workFolder.id
        client.bookmarksByFolder[2] = [makeBookmark(1, "Apple", folders: [2])]      // stale, must be ignored
        client.bookmarksByFolder[3] = [makeBookmark(2, "Nextcloud", folders: [3])]  // correct, current folder

        let store = BookmarksStore()

        // Tap Work: request goes out but does not resolve yet.
        store.openFolder(workFolder, client: client)
        XCTAssertEqual(store.loadingFolderId, workFolder.id)

        // Before it resolves, the user taps Personal, which resolves immediately.
        store.openFolder(personalFolder, client: client)
        XCTAssertEqual(store.currentRoot.id, personalFolder.id)
        XCTAssertEqual(store.currentRoot.books.map { $0.id }, [2])

        // Now the stale Work response finally arrives.
        client.completeDeferredFetch()

        // It must not have overwritten what the user is currently looking at.
        XCTAssertEqual(store.currentRoot.id, personalFolder.id)
        XCTAssertEqual(store.currentRoot.books.map { $0.id }, [2],
                       "A late response for a folder the user left must not clobber the folder they navigated to")
    }

    func testLoadingIndicatorClearsEvenForAStaleResponse() {
        let client = MockNextcloudClient()
        client.folderHierarchyResult = [workFolder, personalFolder]
        client.deferCompletionForFolderId = workFolder.id
        client.bookmarksByFolder[3] = []

        let store = BookmarksStore()
        store.openFolder(workFolder, client: client)
        store.openFolder(personalFolder, client: client)

        client.completeDeferredFetch()

        XCTAssertNil(store.loadingFolderId, "Loading flag must not get stuck on after a stale response resolves")
    }

    // MARK: - Loading indicator

    func testLoadingFolderIdIsSetWhileFetchingAndClearedAfter() {
        let client = MockNextcloudClient()
        client.folderHierarchyResult = [workFolder]
        client.deferCompletionForFolderId = workFolder.id
        client.bookmarksByFolder[2] = [makeBookmark(1, "GitHub", folders: [2])]

        let store = BookmarksStore()
        XCTAssertNil(store.loadingFolderId)

        store.openFolder(workFolder, client: client)
        XCTAssertEqual(store.loadingFolderId, workFolder.id)

        client.completeDeferredFetch()
        XCTAssertNil(store.loadingFolderId)
        XCTAssertEqual(store.currentRoot.books.map { $0.id }, [1])
    }

    func testLoadingFolderIdStaysNilOnACacheHit() {
        let client = MockNextcloudClient()
        client.folderHierarchyResult = [workFolder, personalFolder]
        client.bookmarksByFolder[2] = [makeBookmark(1, "GitHub", folders: [2])]

        let store = BookmarksStore()
        store.openFolder(workFolder, client: client)
        store.openFolder(personalFolder, client: client)
        store.openFolder(workFolder, client: client) // cache hit

        XCTAssertNil(store.loadingFolderId, "A cache hit should never show a loading spinner")
    }

    // MARK: - onAppear behavior

    func testHandleOnAppearOnlyRefreshesOnce() {
        let client = MockNextcloudClient()
        client.folderHierarchyResult = [workFolder]

        let store = BookmarksStore()
        store.handleOnAppear(client: client)
        store.handleOnAppear(client: client) // e.g. returning from Settings
        store.handleOnAppear(client: client)

        XCTAssertEqual(client.folderHierarchyCallCount, 1, "Only the first appearance should trigger a full refresh")
    }

    func testExplicitRefreshAlwaysReloadsRegardlessOfHasLoadedInitially() {
        let client = MockNextcloudClient()
        client.folderHierarchyResult = [workFolder]

        let store = BookmarksStore()
        store.handleOnAppear(client: client)
        store.performFullRefresh(client: client) // e.g. SettingsUpdated notification

        XCTAssertEqual(client.folderHierarchyCallCount, 2)
    }

    // MARK: - Folder navigation basics

    func testOpeningAFolderShowsOnlyItsOwnBookmarksAndSubfolders() {
        let projectsFolder = Folder(id: 4, title: "Projects", parent_folder_id: 2, books: [])
        let client = MockNextcloudClient()
        client.folderHierarchyResult = [workFolder, personalFolder, projectsFolder]
        client.bookmarksByFolder[2] = [makeBookmark(1, "GitHub", folders: [2])]

        let store = BookmarksStore()
        store.performFullRefresh(client: client)
        store.openFolder(workFolder, client: client)

        XCTAssertEqual(store.subfolders.map { $0.id }, [4])
        XCTAssertEqual(store.currentRoot.books.map { $0.id }, [1])
    }

    // MARK: - Create / update

    func testCreateBookmarkRefreshesFromServerOnSuccess() {
        let client = MockNextcloudClient()
        client.folderHierarchyResult = [workFolder]
        client.allBookmarksResult = []
        client.createBookmarkResult = makeBookmark(1, "GitHub", url: "https://github.com", folders: [-1])

        let store = BookmarksStore()
        let expectation = expectation(description: "create")
        store.createBookmark(url: "https://github.com", title: "GitHub", tags: [], folders: [-1], client: client) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)

        // performFullRefresh's fetchAllBookmarks is scripted to still return
        // empty here, since the point of this test is just that a refresh
        // was triggered at all (folderHierarchyCallCount below), not that
        // the mock realistically echoes the new bookmark back.
        XCTAssertEqual(client.createBookmarkCallCount, 1)
        XCTAssertEqual(client.folderHierarchyCallCount, 1, "A successful create should trigger a full refresh")
    }

    func testCreateBookmarkDoesNotRefreshOnFailure() {
        let client = MockNextcloudClient()
        client.folderHierarchyResult = [workFolder]
        client.createBookmarkResult = nil // simulates an error response

        let store = BookmarksStore()
        let expectation = expectation(description: "create")
        store.createBookmark(url: "https://github.com", title: "GitHub", tags: [], folders: [-1], client: client) { success in
            XCTAssertFalse(success)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(client.folderHierarchyCallCount, 0, "A failed create must not trigger a refresh")
    }

    func testUpdateBookmarkRefreshesFromServerOnSuccess() {
        let client = MockNextcloudClient()
        client.folderHierarchyResult = [workFolder]
        client.updateBookmarkResult = makeBookmark(10, "GitHub (renamed)", url: "https://github.com", folders: [2])

        let store = BookmarksStore()
        let expectation = expectation(description: "update")
        store.updateBookmark(id: 10, url: "https://github.com", title: "GitHub (renamed)", tags: [], folders: [2], client: client) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(client.updatedBookmarkIds, [10])
        XCTAssertEqual(client.folderHierarchyCallCount, 1, "A successful update should trigger a full refresh")
    }

    func testOpenParentFolderReturnsToRoot() {
        let client = MockNextcloudClient()
        client.folderHierarchyResult = [workFolder]
        client.bookmarksByFolder[2] = []
        client.bookmarksByFolder[-1] = [makeBookmark(1, "Apple", folders: [-1])]

        let store = BookmarksStore()
        store.performFullRefresh(client: client)
        store.openFolder(workFolder, client: client)
        store.openParentFolder(client: client)

        XCTAssertEqual(store.currentRoot.id, -1)
        XCTAssertEqual(store.currentRoot.books.map { $0.id }, [1])
    }
}
