app_name := "Kanshi"
scheme := "Kanshi"
project := "Kanshi.xcodeproj"

# Generate Xcode project from project.yml
generate:
    xcodegen generate

# Build the app (debug)
build: generate
    xcodebuild -project {{ project }} -scheme {{ scheme }} -configuration Debug -derivedDataPath build build

# Build release
release: generate
    xcodebuild -project {{ project }} -scheme {{ scheme }} -configuration Release -derivedDataPath build build

# Format all Swift files with swift-format
fmt:
    swift-format format --in-place --recursive .

# Lint (check formatting without modifying)
lint:
    swift-format lint --recursive .

# Open project in Xcode
open: generate
    open {{ project }}

# Clean build artifacts and generated project
clean:
    xcodebuild -project {{ project }} -scheme {{ scheme }} clean
    rm -rf build/
    rm -rf {{ project }}

# Build and run (debug, launches the .app directly)
run: build
    open "build/Build/Products/Debug/{{ app_name }}.app"

# Show current marketing version from project.yml
version:
    @grep 'MARKETING_VERSION:' project.yml | sed 's/.*: "\(.*\)"/\1/'

# Bump version, update Info.plist, regenerate project, commit and tag
# Usage: just bump-version 0.1.0
bump-version version:
    sed -i.bak -e 's/MARKETING_VERSION: ".*"/MARKETING_VERSION: "{{ version }}"/' project.yml
    rm -f project.yml.bak
    plutil -replace CFBundleShortVersionString -string "{{ version }}" Kanshi/Info.plist
    xcodegen generate
    git add project.yml Kanshi/Info.plist
    git commit -m "chore: bump v{{ version }}"
    git tag "v{{ version }}"
    echo "Bumped to v{{ version }}"
