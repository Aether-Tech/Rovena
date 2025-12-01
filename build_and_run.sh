#!/bin/bash

# Build & Run script for Rovena with proper code signing
echo "🔨 Building Rovena..."

# Build the project
swift build

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "📦 Setting up app bundle..."

# Create app structure
mkdir -p Rovena.app/Contents/MacOS
mkdir -p Rovena.app/Contents/Resources
mkdir -p Rovena.app/Contents/Frameworks

# Copy executable
cp .build/debug/Rovena Rovena.app/Contents/MacOS/
chmod +x Rovena.app/Contents/MacOS/Rovena

# Copy Sparkle framework
SPARKLE_FRAMEWORK=".build/arm64-apple-macosx/debug/Sparkle.framework"
if [ -d "$SPARKLE_FRAMEWORK" ]; then
    echo "📦 Copying Sparkle framework..."
    cp -R "$SPARKLE_FRAMEWORK" Rovena.app/Contents/Frameworks/
    # Remove any existing signature from the framework
    xattr -cr "Rovena.app/Contents/Frameworks/Sparkle.framework" 2>/dev/null || true
    # Sign the framework
    codesign --force --sign - "Rovena.app/Contents/Frameworks/Sparkle.framework" 2>/dev/null || true
else
    echo "⚠️  Sparkle framework not found at $SPARKLE_FRAMEWORK"
    # Try alternative location
    SPARKLE_FRAMEWORK_ALT=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
    if [ -d "$SPARKLE_FRAMEWORK_ALT" ]; then
        echo "📦 Copying Sparkle framework from alternative location..."
        cp -R "$SPARKLE_FRAMEWORK_ALT" Rovena.app/Contents/Frameworks/
        xattr -cr "Rovena.app/Contents/Frameworks/Sparkle.framework" 2>/dev/null || true
        codesign --force --sign - "Rovena.app/Contents/Frameworks/Sparkle.framework" 2>/dev/null || true
    else
        echo "❌ Sparkle framework not found in any location!"
    fi
fi

# Update rpath to find frameworks
echo "🔗 Updating rpath..."
install_name_tool -add_rpath "@executable_path/../Frameworks" Rovena.app/Contents/MacOS/Rovena 2>/dev/null || true

# Copy GoogleService-Info.plist to Resources
if [ -f "Sources/App/GoogleService-Info.plist" ]; then
    echo "📋 Copying GoogleService-Info.plist..."
    cp Sources/App/GoogleService-Info.plist Rovena.app/Contents/Resources/
fi

# Copy Config.plist to Resources
if [ -f "Sources/Config.plist" ]; then
    echo "📋 Copying Config.plist..."
    cp Sources/Config.plist Rovena.app/Contents/Resources/
fi

# Copy Terms and Conditions to Resources
if [ -f "Sources/Documents/TermsAndConditions.md" ]; then
    echo "📋 Copying TermsAndConditions.md..."
    cp Sources/Documents/TermsAndConditions.md Rovena.app/Contents/Resources/
fi

# Generate icon if Rovena1.png exists
if [ -f "Rovena1.png" ]; then
    echo "🎨 Generating icon..."
    ICONSET="Rovena.iconset"
    mkdir -p "$ICONSET"
    
    # Generate all icon sizes (suppress output)
    sips -z 16 16     "Rovena1.png" --out "$ICONSET/icon_16x16.png" > /dev/null 2>&1
    sips -z 32 32     "Rovena1.png" --out "$ICONSET/icon_16x16@2x.png" > /dev/null 2>&1
    sips -z 32 32     "Rovena1.png" --out "$ICONSET/icon_32x32.png" > /dev/null 2>&1
    sips -z 64 64     "Rovena1.png" --out "$ICONSET/icon_32x32@2x.png" > /dev/null 2>&1
    sips -z 128 128   "Rovena1.png" --out "$ICONSET/icon_128x128.png" > /dev/null 2>&1
    sips -z 256 256   "Rovena1.png" --out "$ICONSET/icon_128x128@2x.png" > /dev/null 2>&1
    sips -z 256 256   "Rovena1.png" --out "$ICONSET/icon_256x256.png" > /dev/null 2>&1
    sips -z 512 512   "Rovena1.png" --out "$ICONSET/icon_256x256@2x.png" > /dev/null 2>&1
    sips -z 512 512   "Rovena1.png" --out "$ICONSET/icon_512x512.png" > /dev/null 2>&1
    sips -z 1024 1024 "Rovena1.png" --out "$ICONSET/icon_512x512@2x.png" > /dev/null 2>&1
    
    # Create .icns
    iconutil -c icns "$ICONSET" > /dev/null 2>&1
    mv "Rovena.icns" "Rovena.app/Contents/Resources/AppIcon.icns"
    rm -rf "$ICONSET"
fi

# Create Info.plist with network permissions
cat > "Rovena.app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Rovena</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.rovena.app</string>
    <key>CFBundleName</key>
    <string>Rovena</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>NSMicrophoneUsageDescription</key>
    <string>Rovena needs access to the microphone for the audio visualizer feature.</string>
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/Aether-Tech/Rovena/main/appcast.xml</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
EOF

# Clean extended attributes before signing to avoid "detritus" errors
echo "🧹 Cleaning extended attributes..."
xattr -cr Rovena.app 2>/dev/null || true
# Also remove resource forks and Finder info
find Rovena.app -type f -exec xattr -c {} \; 2>/dev/null || true
find Rovena.app -type d -exec xattr -c {} \; 2>/dev/null || true

# Code sign with entitlements to allow Keychain access
echo "🔐 Signing app with entitlements..."
if [ -f "Rovena.entitlements" ]; then
    # Sign frameworks first
    if [ -d "Rovena.app/Contents/Frameworks/Sparkle.framework" ]; then
        codesign --force --sign - "Rovena.app/Contents/Frameworks/Sparkle.framework" 2>/dev/null || true
    fi
    # Then sign the app
    codesign --force --sign - --entitlements Rovena.entitlements --deep Rovena.app 2>&1 | grep -v "detritus" || true
    echo "✅ App signed with Keychain access"
else
    echo "⚠️  Rovena.entitlements not found - signing without entitlements"
    codesign --force --sign - --deep Rovena.app 2>&1 | grep -v "detritus" || true
fi

# Force Finder to update
touch "Rovena.app"

echo "✅ Build complete!"
echo "🚀 Launching Rovena..."

# Open the app
open Rovena.app
