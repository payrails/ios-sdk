#
#  Be sure to run `pod spec lint Payrails.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://guides.cocoapods.org/syntax/podspec.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |spec|

  spec.name         = "Payrails"
  spec.version      = "1.0.0"
  spec.swift_version = "5.0"
  spec.summary      = "Payrails Checkout SDK for iOS - Seamless Payment Integration"
  spec.description  = "Payrails Checkout ensures seamless payment integration within iOS applications, providing developers with the means to create versatile payment solutions."

  spec.homepage     = "https://github.com/payrails/ios-sdk.git"

  spec.license      = "MIT Licence"
  spec.author       = { "Payrails" => "contact@payrails.com" }

  spec.platform     = :ios
  spec.platform     = :ios, "14.0"

  spec.source       = { :git => "https://github.com/payrails/ios-sdk.git", :tag => "#{spec.version}" }
  
  spec.subspec 'Checkout' do |checkout|
  	checkout.source_files  = "Payrails/Classes/Public/**/*.{swift}"
  	checkout.resources  = "Payrails/Classes/Public/Assets/*.xcassets"
  	checkout.dependency 'PayPalCheckout'
  end
end
