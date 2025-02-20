Pod::Spec.new do |spec|
  spec.name         = "PayrailsVaultSDK"
  spec.version      = "1.0.0"
  spec.swift_version = "5.0"
  spec.summary      = "PayrailsVaultSDK - Secure Card Data Collection"
  spec.description  = "PayrailsVaultSDK provides secure card data collection functionality for iOS applications."

  spec.homepage     = "https://github.com/payrails/ios-sdk.git"
  spec.license      = "MIT Licence"
  spec.author       = { "Payrails" => "contact@payrails.com" }

  spec.platform     = :ios, "14.0"
  spec.source       = { :git => "https://github.com/payrails/ios-sdk.git", :tag => "#{spec.version}" }
  
  spec.source_files = "PayrailsVaultSDK/Sources/PayrailsVaultSDK/*.{swift}", "PayrailsVaultSDK/Sources/PayrailsVaultSDK/**/*.{swift}"
  spec.framework    = "UIKit"
end
