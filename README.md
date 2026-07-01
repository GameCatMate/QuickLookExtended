# QuickLookExtended

QuickLookExtended is a macOS Quick Look preview extension for text-like files that Finder does not always preview well by default.

Press Space in Finder and preview YAML, Terraform, configs, scripts, source files, certificates, and extensionless text files without opening an editor.

## Quick Start

1. Download the signed and notarized [QuickLookExtended.dmg](https://github.com/GameCatMate/QuickLookExtended/releases/latest/download/QuickLookExtended.dmg) from the latest GitHub release.
2. Open the DMG.
3. Drag `QuickLookExtended.app` to `Applications`.
4. Launch `QuickLookExtended.app`.
5. In the setup window, click `Open Quick Look Settings`.
6. Enable `QuickLookExtended` under Quick Look if it is not already enabled.
7. Select a supported file in Finder and press Space.

The published DMG is the recommended install path. However you can build from [source](#build-from-source) if you want custom preview or highlighting limits; see [Build Settings](#build-settings).

## Compatibility

The published DMG is a universal macOS build:

- Architectures: Apple Silicon (`arm64`) and Intel (`x86_64`)
- Supported macOS: macOS 13 or newer, including macOS 13, 14, 15, and current macOS 26.x releases
- Not supported: macOS 12 and older

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

QuickLookExtended defaults to behavior close to native Quick Look: it reads the whole text file for preview unless you set a preview limit at build time.

- Files up to `QLE_MAX_HIGHLIGHTED_BYTES` get syntax highlighting. Default: `262144` bytes (`256 KB`).
- `QLE_MAX_PREVIEW_BYTES` controls how many bytes are read from the file. Default: `0`, which means no preview-size limit.
- If `QLE_MAX_PREVIEW_BYTES` is greater than `0`, files larger than that value show the first configured bytes and append `... preview truncated ...`.
- Files larger than `QLE_MAX_HIGHLIGHTED_BYTES` use plain text instead of highlighted RTF for speed.
- The first `QLE_BINARY_SNIFF_BYTES` bytes are checked before previewing broad `public.data` files. Default: `16384` bytes (`16 KB`).

Examples:

- `QLE_MAX_PREVIEW_BYTES=0`: read the whole text file, closest to native Quick Look.
- `QLE_MAX_PREVIEW_BYTES=1048576`: preview only the first `1 MB`.
- `QLE_MAX_HIGHLIGHTED_BYTES=262144`: highlight files up to `256 KB`; larger files still open, but without syntax highlighting.
- `QLE_BINARY_SNIFF_BYTES=16384`: check the first `16 KB` before treating extensionless or broad `public.data` files as text.

Keep `QLE_MAX_HIGHLIGHTED_BYTES` modest. Highlighting is the slow part because it creates an attributed string and converts it to RTF. The preview limit can be unlimited while the highlight limit stays small.

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
  QLE_MAX_PREVIEW_BYTES=0 \
  QLE_MAX_HIGHLIGHTED_BYTES=262144 \
  QLE_BINARY_SNIFF_BYTES=16384 \
  build
```

Available settings:

- `QLE_MAX_PREVIEW_BYTES`: maximum bytes read from a file. Use `0` for no limit. Default: `0`.
- `QLE_MAX_HIGHLIGHTED_BYTES`: maximum UTF-8 preview size that gets RTF syntax highlighting.
- `QLE_BINARY_SNIFF_BYTES`: bytes checked before accepting an unknown or extensionless file as text.

If you set `QLE_MAX_PREVIEW_BYTES` to a positive value, keep `QLE_MAX_HIGHLIGHTED_BYTES` lower than it. If `QLE_MAX_PREVIEW_BYTES=0`, only the highlight limit controls when the extension falls back to plain text.

In Xcode, the same values live on the `QuickLookExtendedPreviewExtension` target as user-defined build settings. Change them there if you prefer building from the UI. The extension reads the resolved `QLEMaxPreviewBytes`, `QLEMaxHighlightedBytes`, and `QLEBinarySniffBytes` values from its built `Info.plist`, so changing these settings requires rebuilding the app.

## Samples

Sample files live in `Samples/`. Markdown checks are in `Samples/sample.md` and `Samples/sample.markdown`.

Open the folder in Finder, select a sample, and press Space to see how the preview looks:

```bash
open Samples
```

## Build From Source

Requirements:

- macOS 13 or newer on Apple Silicon or Intel
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
```

The `pluginkit -r` line unregisters the temporary build product. Without it, System Settings may show two QuickLookExtended entries: one from `build/DerivedData` and one from `~/Applications`.

If Finder keeps using an old cached preview, restart Finder. As a last resort, run `qlmanage -r` and `qlmanage -r cache`; they only reset Quick Look registration/cache and are not required for normal install or uninstall.

## Enable Or Disable

Open:

`System Settings -> General -> Login Items & Extensions -> Extensions`

Find `QuickLookExtended` under Quick Look and enable or disable it there.

## Uninstall

```bash
pluginkit -r ~/Applications/QuickLookExtended.app/Contents/PlugIns/QuickLookExtendedPreviewExtension.appex
rm -rf ~/Applications/QuickLookExtended.app
```

## Release Builds

For public binary releases, build with a Developer ID Application certificate, package the `.app` into a DMG, submit it to Apple notarization, staple the result, and publish the notarized DMG on GitHub Releases.

Source builds do not require notarization because users build the app locally.

## License

QuickLookExtended is released under the [MIT License](LICENSE).
