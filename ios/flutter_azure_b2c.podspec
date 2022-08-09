#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_azure_b2c.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_azure_b2c'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for ios azure AD B2C.'
  s.description      = <<-DESC
  Flutter plugin for ios azure AD B2C.
                       DESC
  s.homepage         = 'https://github.com/nodriver-ai/flutter_azure_b2c'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Nodriver s.r.l.' => 'info@nodriver.ai' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'MSAL'
  s.platform = :ios, '9.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
