APP_NAME := FLACCoverQL
BUILD_DIR := build
STAGE_DIR := $(BUILD_DIR)/Install

.PHONY: build install clean

build:
	xcodebuild -project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		-destination 'generic/platform=macOS' \
		build

install: build
	rm -rf "$(STAGE_DIR)"
	mkdir -p "$(STAGE_DIR)"
	ditto "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app" "$(STAGE_DIR)/$(APP_NAME).app"
	ln -sfh /Applications "$(STAGE_DIR)/Applications"
	@echo ""
	@echo "$(APP_NAME).app を Applications にドラッグしてインストールしてください。"
	@echo ""
	open "$(STAGE_DIR)"

clean:
	rm -rf $(BUILD_DIR)
