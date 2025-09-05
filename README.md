# [nextBookmark](https://apps.apple.com/de/app/nextbookmark/id1500340092)

A simple iOS client for the [Bookmark](https://github.com/nextcloud/bookmarks) app in Nextcloud

## Features
  * Shows up in the 'Share' menu to easily forward bookmarks to your Nextcloud
  * Shows all your bookmarks in a list with folder navigation
  * Global search across all bookmarks
  * Pull-to-refresh to sync with your Nextcloud
  * Tap on a bookmark to open it in Safari
  * Swipe left to delete bookmarks
  * Navigate through bookmark folders

## Building the App

### Prerequisites
1. **macOS** with Xcode installed (version 14.0 or later recommended)
2. **CocoaPods** dependency manager
3. An Apple Developer account (free account is sufficient for personal use)

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/[your-username]/nextbookmark.git
   cd nextbookmark
   ```

2. **Install CocoaPods** (if not already installed)
   ```bash
   sudo gem install cocoapods
   ```

3. **Install project dependencies**
   ```bash
   pod install
   ```

4. **Open the project in Xcode**
   ```bash
   open nextBookmark.xcworkspace
   ```
   **Important:** Always use the `.xcworkspace` file, not the `.xcodeproj` file

5. **Configure signing**
   - Select the `nextBookmark` project in the navigator
   - Select the `nextBookmark` target
   - Go to "Signing & Capabilities" tab
   - Select your development team
   - Xcode will automatically manage the provisioning profile

6. **Build and run**
   - Select your target device (simulator or connected iOS device)
   - Press `Cmd+R` or click the Run button
   - The app will build and launch on your selected device

### Command Line Build

For building from the command line:

```bash
# Build for simulator
xcodebuild -workspace nextBookmark.xcworkspace \
           -scheme nextBookmark \
           -configuration Debug \
           -sdk iphonesimulator \
           build

# Build for device
xcodebuild -workspace nextBookmark.xcworkspace \
           -scheme nextBookmark \
           -configuration Release \
           -sdk iphoneos \
           build
```

### Troubleshooting

- **CocoaPods issues**: Try `pod deintegrate` followed by `pod install`
- **Build failures**: Clean the build folder with `Cmd+Shift+K` in Xcode
- **Signing issues**: Ensure you're logged into Xcode with your Apple ID (Xcode → Preferences → Accounts)

## Configuration

After installation, configure the app:
1. Launch the app
2. Go to Settings
3. Enter your Nextcloud server URL
4. Enter your username and password
5. The app will verify the connection and start syncing your bookmarks

## Acknowledgements

[Alamofire](https://github.com/Alamofire/Alamofire)
[Nextcloud](https://nextcloud.com/)
[Nextcloud Bookmarks](https://github.com/nextcloud/bookmarks)
[NotificationBanner](https://github.com/Daltron/NotificationBanner)
[SwiftUI-Refresh](https://github.com/siteline/SwiftUIRefresh)
[SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON)


## Disclaimer
This project is mostly a hobby to get familiar with Swift, SwfitUI and iOS development.

## License
GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007
