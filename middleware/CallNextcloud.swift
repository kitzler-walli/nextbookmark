//
//  Call_Nextcloud.swift
//  nextBookmark
//
//  Created by Kai on 16.12.19.
//  Copyright © 2019 Kai. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

struct CallNextcloud
{
    let sharedUserDefaults = UserDefaults(suiteName: SharedUserDefaults.suiteName)
    let usernameFromSettings: String
    let passwordFromSettings: String
    let urlFromSettings: String
    let headers: HTTPHeaders
    
    init() {
        usernameFromSettings = CredentialsStore.loginName ?? "NO USER NAME"
        passwordFromSettings = CredentialsStore.appPassword ?? "NO PASSWORD"
        urlFromSettings = sharedUserDefaults?.string(forKey: SharedUserDefaults.Keys.url) ?? "NO URLS"
        headers = [
            .authorization(username: usernameFromSettings, password: passwordFromSettings),
            .accept("application/json")
        ]
    }
    
    func get_all_bookmarks(completion: @escaping ([Bookmark]?) -> Void) {
        var bookmarks: [Bookmark] = []
        let response = AF.request(urlFromSettings + "/index.php/apps/bookmarks/public/rest/v2/bookmark?page=-1", headers: headers).responseJSON { response in
            switch response.result {
            case .success(let value):
                let swiftyJsonVar = JSON(value)
                bookmarks.removeAll()
                for (_, mark) in swiftyJsonVar["data"] {
                    // Safe parsing of bookmark data
                    guard let bookmarkId = mark["id"].int ?? Int(mark["id"].stringValue) else {
                        print("Error: Could not parse bookmark ID from: \(mark["id"])")
                        continue
                    }
                    
                    let title = mark["title"].string ?? "TITLE"
                    let url = mark["url"].string ?? "URL" 
                    let tags = mark["tags"].arrayValue.map { $0.stringValue }
                    let folderIds = mark["folders"].arrayValue.compactMap { $0.int }
                    
                    let newBookmark = Bookmark(id: bookmarkId, title: title, url: url, tags: tags, folder_ids: folderIds)
                    bookmarks.append(newBookmark)
                }
            case .failure(let error):
                print(error)
            }
            completion(bookmarks)
        }
    }
    
    func get_all_bookmarks_for_folder(folder: Folder, completion: @escaping ([Bookmark]?) -> Void) {
        var bookmarks: [Bookmark] = []
        let urlString = urlFromSettings + "/index.php/apps/bookmarks/public/rest/v2/bookmark?page=-1&folder="+String(folder.id)
        
        print("DEBUG: Fetching bookmarks for folder \(folder.id) (\(folder.title))")
        print("DEBUG: Request URL: \(urlString)")
        
        let response = AF.request(urlString, headers: headers).responseJSON { response in
            switch response.result {
            case .success(let value):
                print("DEBUG: Successfully received response for folder \(folder.id)")
                let swiftyJsonVar = JSON(value)
                
                // Check if response has data field
                guard swiftyJsonVar["data"].exists() else {
                    print("ERROR: No 'data' field in response: \(swiftyJsonVar)")
                    completion(nil)
                    return
                }
                
                bookmarks.removeAll()
                for (_, mark) in swiftyJsonVar["data"] {
                    // Safe parsing of bookmark data
                    guard let bookmarkId = mark["id"].int ?? Int(mark["id"].stringValue) else {
                        print("Error: Could not parse bookmark ID from: \(mark["id"])")
                        continue
                    }
                    
                    let title = mark["title"].string ?? "TITLE"
                    let url = mark["url"].string ?? "URL" 
                    let tags = mark["tags"].arrayValue.map { $0.stringValue }
                    let folderIds = mark["folders"].arrayValue.compactMap { $0.int }
                    
                    let newBookmark = Bookmark(id: bookmarkId, title: title, url: url, tags: tags, folder_ids: folderIds)
                    bookmarks.append(newBookmark)
                }
                print("DEBUG: Parsed \(bookmarks.count) bookmarks for folder \(folder.id)")
                
            case .failure(let error):
                print("ERROR: Network request failed for folder \(folder.id): \(error)")
                print("ERROR: Request URL was: \(urlString)")
                completion(nil)
                return
            }
            completion(bookmarks)
        }
    }
    
    func delete(bookId: Int) {
        AF.request(urlFromSettings + "/index.php/apps/bookmarks/public/rest/v2/bookmark/" + String(bookId), method: .delete, headers: headers).responseJSON { response in
            switch response.result {
            case .success(let value):
                print (value)
            case .failure(let error):
                print(error)
            }
        }
    }
    
    
    func getAllFolders() -> [Folder] {
        var fff = [Folder(id: -1, title: "/", parent_folder_id: -1, books: [])]
        requestFolderHierarchy() { olders in
            guard let olders = olders else {
                return
            }
            fff =  self.makeFolders(json: olders)
        }
        return fff
    }
    
    func requestFolderHierarchy(completionHandler: @escaping (JSON?) -> Void) {
        var swiftyJsonVar = JSON("")
        let response = AF.request(urlFromSettings + "/index.php/apps/bookmarks/public/rest/v2/folder", headers: headers).responseJSON { response in
            switch response.result {
            case .success(let value):
                swiftyJsonVar = JSON(value)["data"]
                print(swiftyJsonVar["data"])
            case .failure(let error):
                print(error)
            }
            completionHandler(swiftyJsonVar)
        }
        debugPrint(response)
    }
    
    func makeFolders(json: JSON) -> [Folder] {
        debugPrint("iTERATE")
        debugPrint(json)
        var folders = [Folder]()
        for (_, folderJSON) in json {
            if (folderJSON["id"].exists()){
                let newFolder = Folder(id: Int(folderJSON["id"].intValue) , title: folderJSON["title"].stringValue , parent_folder_id: Int(folderJSON["parent_folder"].intValue), books: [])
                folders.append(newFolder)
                if !(folderJSON["children"].isEmpty) {
                    for (_, child) in folderJSON["children"] {
                        let subfolder = makeFolders(json: [child])
                        if (subfolder.count > 0) {
                            folders = folders + subfolder}
                    }
                }}
        }
        return folders
    }
    
    func postURL(url: String, completionHandler: @escaping (JSON?, Error?) -> Void) {
        let parameters: [String: String] = [
            "url": url
        ]
        AF.request(urlFromSettings + "/index.php/apps/bookmarks/public/rest/v2/bookmark", method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
            switch response.result {
            case .success(let value):
                let swiftyJsonVar = JSON(value)["data"]
                completionHandler(swiftyJsonVar, nil)
            case .failure(let error):
                completionHandler(nil, error)
            }
        }
    }

    /// Creates a new bookmark with the given fields (used by the manual "add
    /// bookmark" flow; the Share Extension uses the simpler `postURL` above).
    func createBookmark(url: String, title: String, tags: [String], folders: [Int], completion: @escaping (Bookmark?, Error?) -> Void) {
        let parameters: [String: Any] = ["url": url, "title": title, "tags": tags, "folders": folders]
        AF.request(urlFromSettings + "/index.php/apps/bookmarks/public/rest/v2/bookmark", method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
            switch response.result {
            case .success(let value):
                completion(Self.parseBookmark(JSON(value)["item"]), nil)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }

    /// Updates an existing bookmark's fields.
    func updateBookmark(id: Int, url: String, title: String, tags: [String], folders: [Int], completion: @escaping (Bookmark?, Error?) -> Void) {
        let parameters: [String: Any] = ["url": url, "title": title, "tags": tags, "folders": folders]
        AF.request(urlFromSettings + "/index.php/apps/bookmarks/public/rest/v2/bookmark/\(id)", method: .put, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
            switch response.result {
            case .success(let value):
                completion(Self.parseBookmark(JSON(value)["item"]), nil)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }

    /// Fetches the favicon image data Nextcloud Bookmarks has cached for a
    /// bookmark, if any. Returns nil (not an error) if none has been fetched
    /// server-side yet — the server crawls favicons asynchronously.
    func fetchFavicon(bookmarkId: Int, completion: @escaping (Data?) -> Void) {
        AF.request(urlFromSettings + "/index.php/apps/bookmarks/public/rest/v2/bookmark/\(bookmarkId)/favicon", headers: headers)
            .validate(statusCode: 200..<300)
            .responseData { response in
                completion(response.data)
            }
    }

    private static func parseBookmark(_ mark: JSON) -> Bookmark? {
        guard let bookmarkId = mark["id"].int ?? Int(mark["id"].stringValue) else { return nil }
        let title = mark["title"].string ?? ""
        let url = mark["url"].string ?? ""
        let tags = mark["tags"].arrayValue.map { $0.stringValue }
        let folderIds = mark["folders"].arrayValue.compactMap { $0.int }
        return Bookmark(id: bookmarkId, title: title, url: url, tags: tags, folder_ids: folderIds)
    }
}
