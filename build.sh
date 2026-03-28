#!/bin/bash

# STROLL Build Script
# Builds Rust core and Flutter app

set -e

echo "🚀 Building STROLL..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
check_prereq() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}❌ $1 is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ $1 found${NC}"
}

echo ""
echo "📋 Checking prerequisites..."
check_prereq rustc
check_prereq cargo
check_prereq flutter

# Build Rust core
echo ""
echo "🔧 Building Rust core..."
cd rust_core

echo "   Building for host..."
cargo build --release

echo "   Building for Android (arm64)..."
cargo ndk -t arm64-v8a build --release 2>/dev/null || echo "   ⚠️ cargo-ndk not installed, skipping Android build"

echo "   Building for iOS..."
cargo build --target aarch64-apple-ios --release 2>/dev/null || echo "   ⚠️ iOS target not configured, skipping iOS build"

cd ..

# Native bridge exports are implemented directly in rust_core/src/lib.rs.
echo ""
echo "🔗 Using native bridge exports from rust_core/src/lib.rs"

# Build Flutter app
echo ""
echo "📱 Building Flutter app..."
cd flutter_app

flutter pub get

echo ""
echo "🎯 Build options:"
echo "   1. Run on connected device (flutter run)"
echo "   2. Build APK (flutter build apk)"
echo "   3. Build iOS (flutter build ios)"
echo "   4. Build web (flutter build web)"
echo ""

read -p "Select option (1-4): " choice

case $choice in
    1)
        echo "🏃 Running on device..."
        flutter run
        ;;
    2)
        echo "📦 Building APK..."
        flutter build apk --release
        echo -e "${GREEN}✓ APK built at: build/app/outputs/flutter-apk/app-release.apk${NC}"
        ;;
    3)
        echo "🍎 Building iOS..."
        flutter build ios --release
        echo -e "${GREEN}✓ iOS build complete${NC}"
        ;;
    4)
        echo "🌐 Building web..."
        flutter build web --release
        echo -e "${GREEN}✓ Web build at: build/web/${NC}"
        ;;
    *)
        echo -e "${YELLOW}⚠️ Invalid option${NC}"
        ;;
esac

cd ..

echo ""
echo -e "${GREEN}✅ Build complete!${NC}"
