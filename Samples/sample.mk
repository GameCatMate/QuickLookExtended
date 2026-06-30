APP_NAME := QuickLookExtended
BUILD_DIR := build/DerivedData

.PHONY: build install clean

build:
	xcodebuild -project QuickLookExtended.xcodeproj -scheme $(APP_NAME) -configuration Release build

install: build
	ditto $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app ~/Applications/$(APP_NAME).app

clean:
	rm -rf $(BUILD_DIR)
