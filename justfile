app_name := "Kanshi"
scheme := "Kanshi"
project := "Kanshi.xcodeproj"

# Build the app (debug)
build:
    xcodebuild -project {{ project }} -scheme {{ scheme }} -configuration Debug build

# Build release
release:
    xcodebuild -project {{ project }} -scheme {{ scheme }} -configuration Release build

# Format all Swift files with swift-format
fmt:
    swift-format format --in-place --recursive .

# Lint (check formatting without modifying)
lint:
    swift-format lint --recursive .

# Open project in Xcode
open:
    open {{ project }}

# Clean build artifacts
clean:
    xcodebuild -project {{ project }} -scheme {{ scheme }} clean

# Build and run (debug, launches the .app directly)
run: build
    open "$(xcodebuild -project {{ project }} -scheme {{ scheme }} -configuration Debug \
        -showBuildSettings | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')/{{ app_name }}.app"
