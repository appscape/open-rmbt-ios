platform :ios, '8.0'

target 'RMBT' do
  pod 'AFNetworking', '~>1.3'
  pod 'GCNetworkReachability', '1.3.2'
  pod 'BlocksKit', podspec: './BlocksKit.podspec'
  pod 'libextobjc/EXTKeyPathCoding'
  pod 'SVWebViewController', '1.0'
  pod 'TUSafariActivity'

  if File.exist?(File.expand_path('../Vendor/CocoaAsyncSocket', __FILE__))
    pod 'CocoaAsyncSocket', :path => 'Vendor/CocoaAsyncSocket'
  else
    pod 'CocoaAsyncSocket', :git => 'https://github.com/appscape/CocoaAsyncSocket.git', 
                            :commit => '350ac5f09002ac92a333175cb87ab8b59ebd0571'
  end

  pod 'BCGenieEffect'
  pod 'GoogleMaps', '~> 2.1'
end