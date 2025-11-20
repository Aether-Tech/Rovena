#!/bin/bash

APP_NAME="Rovena"
DMG_NAME="Rovena-Installer.dmg"
APP_PATH="${APP_NAME}.app"

# Ensure the app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ $APP_PATH not found! Please run build_and_run.sh first."
    exit 1
fi

echo "📦 Creating DMG for $APP_NAME..."

# Remove existing DMG
if [ -f "$DMG_NAME" ]; then
    rm "$DMG_NAME"
fi

# Create temporary folder for DMG content
mkdir -p dist
cp -r "$APP_PATH" dist/
ln -s /Applications dist/Applications

# Create the DMG
hdiutil create -volname "$APP_NAME" -srcfolder dist -ov -format UDZO "$DMG_NAME"

# Cleanup
rm -rf dist

echo "✅ $DMG_NAME created successfully!"

