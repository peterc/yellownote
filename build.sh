#!/bin/bash
set -e

APP="YellowNote.app"
rm -rf "$APP"

# Compile
swiftc main.swift -o YellowNote -framework Cocoa

# Create bundle structure
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

# Copy files into bundle
cp YellowNote "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
cp AppIcon.icns "$APP/Contents/Resources/"
cp ChicagoFLF.ttf "$APP/Contents/Resources/"

echo "Built $APP"
