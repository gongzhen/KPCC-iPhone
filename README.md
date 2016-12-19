KPCC-iPhone
===========

The KPCC iOS App for iPhone


Config
==========
In order for this app to hook up to the variety of third-party services we use, you're going to have to setup a file 'KPCC/Config.plist' - as seen in [SCPR/KPCC-iPad](https://github.com/SCPR/KPCC-iPad).

Here's what that might look like for you:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>OneSignal</key>
	<dict>
		<key>AppId</key>
		<string>...</string>
	</dict>
	<key>Auth0</key>
	<dict>
		<key>ClientId</key>
		<string>...</string>
		<key>Domain</key>
		<string>...</string>
	</dict>
	<key>Desk</key>
	<dict>
		<key>AuthPassword</key>
		<string>...</string>
		<key>AuthUser</key>
		<string>...</string>
	</dict>
	<key>Flurry</key>
	<dict>
		<key>key</key>
		<string>...</string>
	</dict>
	<key>StreamMachine</key>
	<dict>
		<key>standard</key>
		<string>...</string>
	</dict>
	<key>SCPR</key>
	<dict>
		<key>api</key>
		<string>...</string>
	</dict>
	<key>Parse</key>
	<dict>
		<key>ApplicationId</key>
		<string>...</string>
		<key>Server</key>
		<string>...</string>
	</dict>
	<key>AdServer</key>
	<dict>
		<key>Cookie</key>
		<string>...</string>
		<key>Preroll</key>
		<string>...</string>
	</dict>
</dict>
</plist>```
