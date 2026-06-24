# QuickLookExtended

Quick Look preview extension for `.yaml`, `.yml`, `.tf`, and extensionless text files.

```bash
rtk xcodebuild -project YAMLQuickLook.xcodeproj -scheme YAMLQuickLook -configuration Release -destination generic/platform=macOS -derivedDataPath build/DerivedData
rtk ditto build/DerivedData/Build/Products/Release/YAMLQuickLook.app ~/Applications/YAMLQuickLook.app
rtk pluginkit -a ~/Applications/YAMLQuickLook.app/Contents/PlugIns/YAMLPreviewExtension.appex
qlmanage -r
qlmanage -r cache
```

The current installed app path is `~/Applications/YAMLQuickLook.app`.
