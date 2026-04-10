source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!
platform :osx, '13.0'

target 'Wired Client' do
    pod 'Sparkle', '~> 2.0'
    pod 'SBJson4', '~> 4.0.0'
    pod 'NSDate+TimeAgo'
    pod 'OpenSSL-Universal', '~> 3.3'
end

target 'WiredNetworking' do
    project 'vendor/WiredFrameworks/WiredFrameworks.xcodeproj'
    workspace 'vendor/WiredFrameworks/WiredFrameworks.xcworkspace'
    pod 'OpenSSL-Universal', '~> 3.3'
end

target 'libwired-osx' do
    project 'vendor/WiredFrameworks/WiredFrameworks.xcodeproj'
    workspace 'vendor/WiredFrameworks/WiredFrameworks.xcworkspace'
    pod 'OpenSSL-Universal', '~> 3.3'
end
