PROJECT := Kompetenzraster
SCHEME := Kompetenzraster
CONFIG := Debug
BUILD_DIR := build
DIST_DIR := dist
APP := $(BUILD_DIR)/Build/Products/$(CONFIG)/$(PROJECT).app
RELEASE_APP := $(BUILD_DIR)/Build/Products/Release/$(PROJECT).app

# Die Version steht in project.yml; die Build-Nummer kommt in der Werkbank
# aus der Nummer des Arbeitslaufs und wächst dadurch verlässlich.
VERSION := $(shell sed -nE 's/.*MARKETING_VERSION: "(.*)".*/\1/p' project.yml | head -1)
BUILD_NUMBER ?= 1

.PHONY: all generate build run test icon release install clean

all: build

generate:
	xcodegen generate

build: generate
	xcodebuild -project $(PROJECT).xcodeproj -scheme $(SCHEME) -configuration $(CONFIG) -derivedDataPath $(BUILD_DIR) build

run: build
	open $(APP)

test: generate
	xcodebuild -project $(PROJECT).xcodeproj -scheme $(SCHEME) -configuration $(CONFIG) -derivedDataPath $(BUILD_DIR) test

icon:
	./scripts/make_icon.sh

release: generate
	xcodebuild -project $(PROJECT).xcodeproj -scheme $(SCHEME) -configuration Release \
		-derivedDataPath $(BUILD_DIR) CURRENT_PROJECT_VERSION=$(BUILD_NUMBER) build
	@mkdir -p $(DIST_DIR)
	@rm -rf "$(DIST_DIR)/$(PROJECT).app" "$(DIST_DIR)/$(PROJECT).zip" "$(DIST_DIR)/latest.json"
	cp -R "$(RELEASE_APP)" "$(DIST_DIR)/$(PROJECT).app"
	cd $(DIST_DIR) && ditto -c -k --sequesterRsrc --keepParent "$(PROJECT).app" "$(PROJECT).zip"
	./scripts/make_manifest.sh "$(VERSION)" "$(BUILD_NUMBER)" "$(DIST_DIR)/latest.json"
	@echo "release: $(DIST_DIR)/$(PROJECT).zip (Version $(VERSION), Build $(BUILD_NUMBER))"

install: release
	@rm -rf "/Applications/$(PROJECT).app"
	cp -R "$(RELEASE_APP)" "/Applications/$(PROJECT).app"
	@echo "install: /Applications/$(PROJECT).app"

clean:
	rm -rf $(BUILD_DIR) $(DIST_DIR)
