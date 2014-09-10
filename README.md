KPCC-iPhone
===========

The KPCC iOS App for iPhone

Currently being targeted at iOS7 and up. Compiled and built with Xcode 6 for iOS8. And meet our new best friend, Swift. 


Config
==========
  In order for this app to hook up to the variety of third-party services we use, you're going to have to setup a file 'KPCC/Config.plist' - as seen in [SCPR/KPCC-iPad](https://github.com/SCPR/KPCC-iPad).

  Here's what that might look like for you:
  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
    <key>Flurry</key>
    <dict>
      <key>DebugKey</key>
      <string>*****</string>
      <key>ProductionKey</key>
      <string>*****</string>
    <dict/>
    <key>TestFlight</key>
    <dict>
      <key>iPadKey</key>
      <string>*****</string>
      <key>iPhoneKey</key>
      <string>*****</string>
    </dict>
    <key>Parse</key>
    <dict>
      <key>ClientKey</key>
      <string>*****</string>
      <key>ApplicationId</key>
      <string>*****</string>
    </dict>
  </dict>
  </plist>
  ```

Dependencies
==========
The app uses CocoaPods to manage third-party libraries within the project:
<h3>Podfile</h3>
      platform :ios, '7.0'
      pod 'AFNetworking', '~> 2.0'
      pod 'JDStatusBarNotification'
      pod 'pop', '~> 1.0'
      pod 'FXBlurView', '~> 1.6'
      link_with ['KPCC', 'KPCC-TestFlight']

We also incorporate several libraries that are included in the repository as compilable sources:
<h3>Inline compilable dependencies:</h3>

	    Flurry (v5.3.0)
	    TestFlight (v3.0.0)


Building & Running
==========
You're going to have to install [CocoaPods](http://cocoapods.org/). After doing so:

Run `pod install` from terminal in the project root, open `KPCC.xcworkspace`, and build to a device as you see fit. Ignore errors from TestFlight, Flurry, and other services that require the use of secret keys - the app should still run fine without them. You're going to have to use your own keys and set up a Config.plist to make use of these libraries.

As stated above, this app plays nice with Swift, so you're going to have to download Xcode 6 and build for simulator/devices running >= iOS7.
