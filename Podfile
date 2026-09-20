# Uncomment the next line to define a global platform for your project
platform :ios, '17.0'

target 'nextBookmark' do
  # Comment the next line if you don't want to use dynamic frameworks
  #use_frameworks!

  # Pods for nextBookmark
  pod 'Alamofire'
  pod 'SwiftyJSON'
  pod 'SwiftUIRefresh'
  pod 'NotificationBannerSwift'

  target 'nextBookmarkTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'nextBookmarkUITests' do
    # Pods for testing
  end

end

target 'ShareExtension' do
  # Comment the next line if you don't want to use dynamic frameworks
  #use_frameworks!

  # Pods for ShareExtension
  pod 'Alamofire'
  pod 'SwiftyJSON'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    end
  end
end
