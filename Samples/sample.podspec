Pod::Spec.new do |s|
  s.name         = "QuickLookDemo"
  s.version      = "1.4.2"
  s.summary      = "Sample podspec for Quick Look preview."
  s.homepage     = "https://example.com/quicklook-demo"
  s.license      = { type: "MIT", file: "LICENSE" }
  s.author       = { "GameCat" => "demo@example.com" }
  s.source       = { git: "https://example.com/quicklook-demo.git", tag: s.version }
  s.platform     = :ios, "15.0"
  s.swift_version = "5.10"
  s.source_files = "Sources/**/*.swift"
end
