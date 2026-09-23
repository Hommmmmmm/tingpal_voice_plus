Pod::Spec.new do |s|
  s.name             = 'tingpal_voice_plus'
  s.version          = '0.0.1'
  s.summary          = 'TingPal speech plugin for macOS'
  s.description      = <<-DESC
TingPal speech plugin with Xunfei speech recognizer support for macOS via WebSocket.
                       DESC
  s.homepage         = 'https://github.com/tingpal/tingpal_voice_plus'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
