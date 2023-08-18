#
#  Be sure to run `pod spec lint Payrails.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://guides.cocoapods.org/syntax/podspec.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |spec|

  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  These will help people to find your library, and whilst it
  #  can feel like a chore to fill in it's definitely to your advantage. The
  #  summary should be tweet-length, and the description more in depth.
  #

  spec.name         = "Payrails"
  spec.version      = "0.0.1"
  spec.swift_version = "5.0"
  spec.summary      = "A short description of Payrails."

  # This description is used to generate tags and improve search results.
  #   * Think: What does it do? Why did you write it? What is the focus?
  #   * Try to keep it short, snappy and to the point.
  #   * Write the description between the DESC delimiters below.
  #   * Finally, don't worry about the indent, CocoaPods strips it!
  spec.description  = "This is something that needs to be changed"

  spec.homepage     = "https://github.com/payrails/ios-sdk.git"

  spec.license      = "MIT Licence"
  spec.author       = { "Lukasz Lenkiewicz" => "lukasz.lenkiewicz.ext@payrails.com" }

  spec.platform     = :ios
  spec.platform     = :ios, "14.0"

  spec.source       = { :git => "git@github.com:payrails/ios-sdk.git", :tag => "#{spec.version}" }
  
  spec.source_files  = "Payrails/Classes/Public/**/*.{swift}"
  spec.resources  = "Payrails/Classes/Public/Assets/*.xcassets"
  spec.dependency 'PayPal/PayPalNativePayments'
 # spec.dependency 'PayPal/PaymentButtons'
  
  #spec.exclude_files = "Payrails/Classes/Private"
end
