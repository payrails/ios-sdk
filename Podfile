platform :ios, '14.0'

use_frameworks!

project 'Payrails.xcodeproj'

target 'Payrails' do
  pod 'PayPalCheckout'
  pod 'PayrailsCSE'
  pod 'JOSESwift'
end

target 'PayrailsTests' do
  inherit! :search_paths
end

# Force all pods to match the project deployment target
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      # Fix DT_TOOLCHAIN_DIR issue for Xcode 15+/16+ with xcframeworks
      xcconfig_path = config.base_configuration_reference&.real_path
      if xcconfig_path&.exist?
        xcconfig = xcconfig_path.read
        new_xcconfig = xcconfig.gsub('DT_TOOLCHAIN_DIR', 'TOOLCHAIN_DIR')
        xcconfig_path.open('w') { |f| f << new_xcconfig }
      end
    end
  end
end
