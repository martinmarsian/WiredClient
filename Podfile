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

post_install do |installer|
    # Fix deployment target for all Pods
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '13.0'
        end
    end

    # WiredNetworking needs both BUILT_PRODUCTS_DIR (for Debug) and the static run/include
    # path (for Archive, where libwired headers may not be in BUILT_PRODUCTS_DIR yet)
    require 'xcodeproj'
    wf_path = File.join(File.dirname(__FILE__), 'vendor/WiredFrameworks/WiredFrameworks.xcodeproj')
    wf_project = Xcodeproj::Project.open(wf_path)
    wf_project.targets.select { |t| t.name == 'WiredNetworking' }.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['HEADER_SEARCH_PATHS'] = [
                '$(BUILT_PRODUCTS_DIR)',
                '$(SRCROOT)/libwired/run/include'
            ]
        end
    end
    wf_project.save

    # Main WiredClient app also needs the libwired headers for Archive builds,
    # where $(BUILT_PRODUCTS_DIR) doesn't contain them yet.
    wc_path = File.join(File.dirname(__FILE__), 'WiredClient.xcodeproj')
    wc_project = Xcodeproj::Project.open(wc_path)
    wc_project.targets.select { |t| t.name == 'Wired Client' }.each do |target|
        target.build_configurations.each do |config|
            paths = config.build_settings['HEADER_SEARCH_PATHS'] || ['$(inherited)']
            paths = [paths] if paths.is_a?(String)
            libwired_path = '$(SRCROOT)/vendor/WiredFrameworks/libwired/run/include'
            unless paths.include?(libwired_path)
                paths << libwired_path
                config.build_settings['HEADER_SEARCH_PATHS'] = paths
            end
        end
    end
    wc_project.save
end
