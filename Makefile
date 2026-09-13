APP_NAME := FLACCoverQL
BUILD_DIR := build
INSTALL_DIR := $(HOME)/Applications

.PHONY: build install clean

build:
	xcodebuild -project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		build

install: build
	ditto "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app" "$(INSTALL_DIR)/$(APP_NAME).app"
	open "$(INSTALL_DIR)/$(APP_NAME).app"

clean:
	rm -rf $(BUILD_DIR)
