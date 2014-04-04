KPCC-iPhone
===========

The KPCC iOS App for iPhone


Config
==========
  In order for this app to hook up to the variety of third-party services we use, you're going to have to setup a file 'KPCC/Config.plist' - as seen in SCPR/KPCC-iPad.

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
The app uses CocoaPods to integrate third-party libraries with the project. Currently, we are only using this to load AFNetworking, but that will change in the future.

We also incorporate several libraries that are included in the repository as compilable sources:
<h3>Inline compilable dependencies:</h3>

	    Flurry (v4.3.2)
	    TestFlight (v3.0.0)
	    StreamingKit (v0.2.0)


Building & Running
==========
You're going to have to install [CocoaPods](http://cocoapods.org/). After doing so:

Run `pod install` from terminal in the project root, open `KPCC.xcworkspace`, and build to a device as you see fit.
