//
//  SharedUserDefaults.swift
//  nextBookmark
//
//  Created by Kai on 07.09.19.
//  Copyright © 2019 Kai. All rights reserved.
//

import Foundation

struct SharedUserDefaults {
    static let suiteName = "group.at.kw.nextbookmark"
    
    struct Keys {
        static let username = "username"
        static let password = "password"
        static let url = "url"
        static let valid = "valid"
    }
}
