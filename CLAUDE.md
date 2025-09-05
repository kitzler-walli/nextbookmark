# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

nextBookmark is an iOS client for the Nextcloud Bookmarks app, built with Swift and SwiftUI. It's a hobby project focused on learning iOS development. The app allows users to:
- Share bookmarks from Safari via iOS Share Extension
- View all bookmarks in a list interface
- Delete bookmarks with swipe gestures
- Navigate bookmark folders

## Build and Development Commands

### Building the Project
```bash
# Build the main app
xcodebuild -scheme nextBookmark -configuration Debug build

# Build for release
xcodebuild -scheme nextBookmark -configuration Release build

# Build the Share Extension
xcodebuild -scheme ShareExtension -configuration Debug build
```

### Running Tests
```bash
# Run unit tests
xcodebuild -scheme nextBookmark -configuration Debug test -destination 'platform=iOS Simulator,name=iPhone 15'

# Run UI tests  
xcodebuild -scheme nextBookmark -configuration Debug test -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:nextBookmarkUITests
```

### CocoaPods Management
```bash
# Install dependencies
pod install

# Update dependencies
pod update

# Always open the .xcworkspace file, not .xcodeproj
open nextBookmark.xcworkspace
```

## Architecture

### Core Structure
- **nextBookmark/**: Main app target with SwiftUI views
- **ShareExtension/**: iOS Share Extension for adding bookmarks from Safari
- **model/**: Data models (Bookmark, Folder)
- **middleware/**: API communication layer (CallNextcloud)

### Key Components

#### Main App (`nextBookmark/`)
- `AppDelegate.swift`: UIKit app delegate with Core Data stack
- `SceneDelegate.swift`: Scene lifecycle management
- `BookmarksView.swift`: Main bookmark list interface
- `SettingsView.swift`: User configuration screen
- `SharedUserDefaults.swift`: Shared preferences between app and extension

#### Models (`model/`)
- `Bookmark.swift`: Bookmark data structure with id, title, url, tags, and folder_ids
- `Folder.swift`: Folder hierarchy structure

#### API Layer (`middleware/`)
- `CallNextcloud.swift`: Handles all Nextcloud Bookmarks API communication using Alamofire and SwiftyJSON

#### Share Extension (`ShareExtension/`)
- `ShareViewController.swift`: Handles incoming URLs from iOS Share menu

### Dependencies (Podfile)
- **Alamofire**: HTTP networking
- **SwiftyJSON**: JSON parsing
- **SwiftUIRefresh**: Pull-to-refresh functionality
- **NotificationBannerSwift**: In-app notifications

### Targets
- `nextBookmark`: Main iOS app (iOS 13.3+)
- `ShareExtension`: Share extension for Safari integration
- `nextBookmarkTests`: Unit tests
- `nextBookmarkUITests`: UI automation tests

## Development Notes

- Uses Core Data for local persistence
- Shared UserDefaults between main app and Share Extension via App Groups
- SwiftUI for main interface, UIKit for Share Extension
- Nextcloud Bookmarks API v2 integration
- Supports folder hierarchy navigation
- Basic authentication with Nextcloud server