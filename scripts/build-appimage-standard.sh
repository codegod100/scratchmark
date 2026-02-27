#!/bin/bash
# Build AppImage using standard Linux tools (no Nix)

set -e

VERSION=$(grep '^version' Cargo.toml | head -1 | cut -d'"' -f2)
APPIMAGE_NAME="Scratchmark-${VERSION}-x86_64.AppImage"

echo "Building Scratchmark AppImage v${VERSION} (Standard Linux Build)..."
echo ""

# Check dependencies
echo "Checking dependencies..."
MISSING_DEPS=""
for cmd in cargo meson ninja patchelf glib-compile-resources pkg-config; do
  if ! command -v $cmd &> /dev/null; then
    MISSING_DEPS="$MISSING_DEPS $cmd "
done

if [ -n "$MISSING_DEPS" ]; then
  echo "✗ Missing dependencies: $MISSING_DEPS"
  echo ""
  echo "Install on Arch/Manjaro:"
  echo "  sudo pacman -S base-devel meson ninja patchelf"
  echo ""
  echo "On Ubuntu/Debian:"
  echo "  sudo apt install build-essential meson ninja patchelf"
  echo ""
  echo "Or if you're in distrobox:"
  echo "  sudo pacman -S meson ninja patchelf"
  echo "  sudo pacman -S base-devel libadwaita libadwaita-dev gtksourceview5 gtksourceview5-dev"
  echo ""
  exit 1
fi

echo "✓ All dependencies found"
echo ""

# Step 1: Build binary with cargo
echo "Step 1: Building binary with cargo..."
cargo build --release
if [ $? -ne 0 ]; then
  echo "✗ Cargo build failed"
  exit 1
fi
echo "✓ Cargo build complete"
echo ""

# Step 2: Build resources with meson
echo "Step 2: Building resources with meson..."
rm -rf build
meson setup build
cd build
meson compile
if [ $? -ne 0 ]; then
  echo "✗ Meson build failed"
  exit 1
fi
echo "✓ Meson build complete"
cd ..
echo ""

# Step 3: Create AppDir structure
echo "Step 3: Creating AppDir structure..."
rm -rf AppDir squashfs-root
mkdir -p AppDir/usr/{bin,share/{applications,icons,metainfo,glib-2.0/schemas}}

# Copy binary
echo "  Copying binary..."
cp target/release/scratchmark AppDir/usr/bin/
chmod +x AppDir/usr/bin/scratchmark

# Copy resources
echo "  Copying resources..."
mkdir -p AppDir/usr/share/scratchmark
cp build/data/resources/scratchmark.gresource AppDir/usr/share/scratchmark/
cp build/data/org.scratchmark.Scratchmark.desktop AppDir/usr/share/applications/
cp data/org.scratchmark.Scratchmark.gschema.xml AppDir/usr/share/glib-2.0/schemas/
cp build/data/org.scratchmark.Scratchmark.metainfo.xml AppDir/usr/share/metainfo/
cp -r data/icons/* AppDir/usr/share/icons/

# Copy AppRun
echo "  Copying AppRun..."
cp scripts/AppRun.in AppDir/AppRun
chmod +x AppDir/AppRun

# Copy icon and desktop to root for appimagetool
echo "  Setting up AppImage metadata..."
cp data/icons/hicolor/scalable/apps/org.scratchmark.Scratchmark.svg AppDir/.DirIcon
cp build/data/org.scratchmark.Scratchmark.desktop AppDir/org.scratchmark.Scratchmark.desktop
echo "✓ AppDir structure created"
echo ""

# Step 4: Create AppImage
echo "Step 4: Creating AppImage..."

# Download appimagetool if needed
if [ ! -f ~/.local/bin/appimagetool-x86_64.AppImage ]; then
  echo "  Downloading appimagetool..."
  mkdir -p ~/.local/bin
  cd ~/.local/bin
  wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
  chmod +x appimagetool-x86_64.AppImage
  cd -
fi

# Create AppImage
~/.local/bin/appimagetool-x86_64.AppImage AppDir "$APPIMAGE_NAME"
if [ $? -ne 0 ]; then
  echo "✗ appimagetool failed"
  exit 1
fi
echo "✓ AppImage created: $APPIMAGE_NAME"
echo ""

# Step 5: Package
echo "Step 5: Packaging..."
mkdir -p dist
cp "$APPIMAGE_NAME" dist/
chmod +x "dist/$APPIMAGE_NAME"

# Generate checksum
cd dist
sha256sum "$APPIMAGE_NAME" > sha256sums.txt
echo "  Checksum:"
cat sha256sums.txt
echo ""

# Cleanup
echo "Step 6: Cleanup..."
rm -rf AppDir squashfs-root build

SIZE=$(du -h "$APPIMAGE_NAME" | cut -f1)
echo ""
echo "✓ AppImage built successfully!"
echo ""
echo "Location: dist/$APPIMAGE_NAME"
echo "Size: $SIZE"
SHA256=$(cat sha256sums.txt | cut -d' ' -f1)
echo "SHA256: $SHA256"
echo ""
echo "To test:"
echo "  chmod +x dist/$APPIMAGE_NAME"
echo "  ./dist/$APPIMAGE_NAME"
