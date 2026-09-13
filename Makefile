APP_NAME := FLACCoverQL
BUILD_DIR := build

.PHONY: build install clean

build:
	xcodebuild -project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		-destination 'generic/platform=macOS' \
		build

install: build
	ln -sfh /Applications "$(BUILD_DIR)/Build/Products/Release/Applications"
	open "$(BUILD_DIR)/Build/Products/Release/"

clean:
	rm -rf $(BUILD_DIR)
