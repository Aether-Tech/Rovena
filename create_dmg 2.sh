#!/bin/bash

echo "📦 Creating Rovena.dmg installer..."

# Ensure the app is built
if [ ! -d "Rovena.app" ]; then
    echo "❌ Rovena.app not found! Run ./build_and_run.sh first"
    exit 1
fi

# Create a temporary directory for DMG contents
DMG_DIR="dmg_temp"
DMG_NAME="Rovena-Installer.dmg"

rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"

# Copy the app to the temp directory
cp -R Rovena.app "$DMG_DIR/"

# Create a symbolic link to Applications folder
ln -s /Applications "$DMG_DIR/Applications"

# Create the DMG
echo "🔨 Building DMG..."
hdiutil create -volname "Rovena Installer" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "$DMG_NAME"

# Clean up
rm -rf "$DMG_DIR"

if [ -f "$DMG_NAME" ]; then
    echo "✅ DMG created successfully: $DMG_NAME"
    echo "📊 Size: $(du -h "$DMG_NAME" | cut -f1)"
else
    echo "❌ Failed to create DMG"
    exit 1
fi

