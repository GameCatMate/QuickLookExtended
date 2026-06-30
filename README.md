# QuickLookExtended

QuickLookExtended is a macOS Quick Look preview extension for text-like files that Finder does not always preview well by default.

Press Space in Finder and preview YAML, Terraform, configs, scripts, source files, certificates, and extensionless text files without opening an editor.

## Features

- Native Quick Look preview window.
- Text selection and copy work like regular Quick Look.
- Syntax highlighting for small and medium files.
- Rendered Markdown preview for `.md` and `.markdown`.
- Fast plain-text fallback for larger files.
- Extensionless files are previewed when they look like text.
- Binary files are rejected quickly so macOS can show the normal generic preview.

## Supported Formats

Highlighted formats:

- YAML: `.yaml`, `.yml`, `kubeconfig`
- Terraform / HCL: `.tf`, `.tfvars`, `.hcl`, `.nomad`
- JSON-like: `.json`, `.jsonnet`, `.tfstate`
- XML-like: `.csproj`, `.plist`, `.runsettings`, `.targets`, `.xml`, `.xsd`
- Markdown: `.md`, `.markdown` rendered as HTML preview
- Xcode projects: `.xcodeproj` previews the inner `project.pbxproj`; `.pbxproj` also opens directly
- Source code: `.bash`, `.c`, `.cmake`, `.cpp`, `.cs`, `.css`, `.cue`, `.fish`, `.go`, `.gradle`, `.graphql`, `.groovy`, `.h`, `.hpp`, `.html`, `.java`, `.js`, `.jsx`, `.kt`, `.kts`, `.m`, `.mk`, `.mm`, `.podspec`, `.proto`, `.ps1`, `.py`, `.rb`, `.rs`, `.sh`, `.sql`, `.swift`, `.tsx`, `.zsh`
- Config files: `.cfg`, `.conf`, `.config`, `.dockerfile`, `.dockerignore`, `.editorconfig`, `.entitlements`, `.env`, `.gemrc`, `.gitattributes`, `.gitignore`, `.ini`, `.list`, `.lock`, `.log`, `.npmrc`, `.properties`, `.props`, `.rst`, `.service`, `.sln`, `.toml`, `.xcconfig`, `.yarnrc`
- Certificates and keys: `.crt`, `.csr`, `.pem`, `.pub`
- `Dockerfile`
- Files without an extension, when they look like text

Known issue:

- `.ts` is intentionally listed in the code, but macOS often treats `.ts` as MPEG transport stream video before this extension gets a chance to preview it. `.tsx` works.

## Size Limits

QuickLookExtended is optimized for quick inspection, not full-file editing.

- Files up to `QLE_MAX_HIGHLIGHTED_BYTES` get syntax highlighting. Default: `262144` bytes (`256 KB`).
- Files up to `QLE_MAX_PREVIEW_BYTES` are previewed. Default: `524288` bytes (`512 KB`).
- Files larger than `QLE_MAX_PREVIEW_BYTES` show the first configured preview bytes and append `... preview truncated ...`.
- Large files use plain text instead of highlighted RTF for speed.
- The first `QLE_BINARY_SNIFF_BYTES` bytes are checked before previewing broad `public.data` files. Default: `16384` bytes (`16 KB`).

## Build Settings

The main performance knobs are build-time settings. Override them in the `xcodebuild` command when you want a different release profile:

```bash
xcodebuild \
  -project QuickLookExtended.xcodeproj \
  -scheme QuickLookExtended \
  -configuration Release \
  -destination generic/platform=macOS \
  -derivedDataPath build/DerivedData \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  QLE_MAX_PREVIEW_BYTES=1048576 \
  QLE_MAX_HIGHLIGHTED_BYTES=262144 \
  QLE_BINARY_SNIFF_BYTES=16384 \
  build
```

Available settings:

- `QLE_MAX_PREVIEW_BYTES`: maximum bytes read from a file.
- `QLE_MAX_HIGHLIGHTED_BYTES`: maximum UTF-8 preview size that gets RTF syntax highlighting.
- `QLE_BINARY_SNIFF_BYTES`: bytes checked before accepting an unknown or extensionless file as text.

Keep `QLE_MAX_HIGHLIGHTED_BYTES` lower than `QLE_MAX_PREVIEW_BYTES`. Highlighting is the slow part because it creates an attributed string and converts it to RTF.

In Xcode, the same values live on the `QuickLookExtendedPreviewExtension` target as user-defined build settings. Change them there if you prefer building from the UI. The extension reads the resolved `QLEMaxPreviewBytes`, `QLEMaxHighlightedBytes`, and `QLEBinarySniffBytes` values from its built `Info.plist`, so changing these settings requires rebuilding the app.

## Samples

Sample files live in `Samples/`. Markdown checks are in `Samples/sample.md` and `Samples/sample.markdown`.

Open the folder in Finder, select a sample, and press Space to see how the preview looks:

```bash
open Samples
```

## Build From Source

Requirements:

- macOS 13 or newer
- Xcode 16 or newer

Build the app:

```bash
xcodebuild \
  -project QuickLookExtended.xcodeproj \
  -scheme QuickLookExtended \
  -configuration Release \
  -destination generic/platform=macOS \
  -derivedDataPath build/DerivedData \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  build
```

Install it for the current user:

```bash
mkdir -p ~/Applications
ditto build/DerivedData/Build/Products/Release/QuickLookExtended.app ~/Applications/QuickLookExtended.app
pluginkit -r build/DerivedData/Build/Products/Release/QuickLookExtended.app/Contents/PlugIns/QuickLookExtendedPreviewExtension.appex
pluginkit -a ~/Applications/QuickLookExtended.app/Contents/PlugIns/QuickLookExtendedPreviewExtension.appex
qlmanage -r
qlmanage -r cache
```

The `pluginkit -r` line unregisters the temporary build product. Without it, System Settings may show two QuickLookExtended entries: one from `build/DerivedData` and one from `~/Applications`.

## Enable Or Disable

Open:

`System Settings -> General -> Login Items & Extensions -> Extensions`

Find `QuickLookExtended` under Quick Look and enable or disable it there.

## Uninstall

```bash
pluginkit -r ~/Applications/QuickLookExtended.app/Contents/PlugIns/QuickLookExtendedPreviewExtension.appex
rm -rf ~/Applications/QuickLookExtended.app
qlmanage -r
qlmanage -r cache
```

## Release Builds

For public binary releases, build with a Developer ID Application certificate, zip the `.app`, submit it to Apple notarization, staple the result, and publish the notarized archive on GitHub Releases.

Source builds do not require notarization because users build the app locally.
