#!/bin/bash
# Automatic AppImage builder (no password prompts)
# Handles sudo automatically for dependency installation

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'

VERSION=$(grep '^version' Cargo.toml | head -1 | cut -d'"' -f2)
APPIMAGE_NAME="Scratchmark-${VERSION}-x86_64.AppImage"

echo -e "${BLUE}========================================"
echo -e "${BLUE}  Automatic AppImage Builder"
echo -e "${BLUE}  Version: ${VERSION}"
echo -e "${BLUE}========================================"
echo ""

echo -e "${YELLOW}  Checking dependencies..."

MISSING=""

for cmd in meson ninja patchelf pkg-config cargo glib-compile-resources; do
    if ! command -v $cmd &>/dev/null; then
        MISSING="$MISSING  $cmd "
    fi
done

if [ -n "$MISSING" ]; then
    echo -e "${YELLOW}  Missing: $MISSING"
    echo ""
    echo -e "${YELLOW}  Will install missing dependencies..."
    echo ""
    
    # Install all missing dependencies in one command
    sudo pacman -S --noconfirm --needed ninja-build patchelf pkg-config glib-compile-resources
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✓ Dependencies installed"
    else
        echo -e "${RED}  ✗ Dependency installation failed"
        exit 1
    fi
else
    echo -e "${GREEN}  ✓ All dependencies found"
fi

echo ""
echo -e "${BLUE}========================================"
echo -e "${BLUE}  Building Scratchmark AppImage"
echo -e "${BLUE}========================================"
echo ""

echo -e "${YELLOW}  Step 1: Build binary..."
cargo build --release

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ Binary built"
else
    echo -e "${RED}  ✗ Cargo build failed"
    exit 1
fi

echo ""
echo -e "${YELLOW}  Step 2: Build resources..."
rm -rf build
meson setup build
cd build && meson compile

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ Resources built"
else
    echo -e "${RED}  ✗ Meson build failed"
    exit 1
fi

echo ""
echo -e "${YELLOW}  Step 3: Create AppDir..."
rm -rf AppDir
mkdir -p AppDir/usr/{bin,share/{applications,icons,metainfo,glib-2.0/schemas}}

# Copy binary
echo -e "${BLUE}  Copying binary..."
cp target/release/scratchmark AppDir/usr/bin/
chmod +x AppDir/usr/bin/scratchmark

# Copy resources
echo -e "${BLUE}  Copying resources..."
mkdir -p AppDir/usr/share/scratchmark
cp build/data/resources/scratchmark.gresource AppDir/usr/share/scratchmark/
cp build/data/org.scratchmark.Scratchmark.desktop AppDir/usr/share/applications/
cp data/org.scratchmark.Scratchmark.gschema.xml AppDir/usr/share/glib-2.0/schemas/
cp build/data/org.scratchmark.Scratchmark.metainfo.xml AppDir/usr/share/metainfo/
cp -r data/icons/* AppDir/usr/share/icons/

# Copy AppRun
echo -e "${BLUE}  Copying AppRun..."
cp scripts/AppRun.in AppDir/AppRun
chmod +x AppDir/AppRun

# Copy icon and desktop to root
echo -e "${BLUE}  Copying icon and desktop..."
cp data/icons/hicolor/scalable/apps/org.scratchmark.Scratchmark.svg AppDir/.DirIcon
cp build/data/org.scratchmark.Scratchmark.desktop AppDir/org.scratchmark.Scratchmark.desktop

# Download appimagetool
echo -e "${YELLOW}  Step 4: Download appimagetool..."
if [ ! -f ~/.local/bin/appimagetool-x86_64.AppImage ]; then
    echo -e "${BLUE}  Downloading appimagetool..."
    mkdir -p ~/.local/bin
    cd ~/.local/bin
    wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x appimagetool-x86_64.AppImage
    echo -e "${GREEN}  ✓ appimagetool downloaded"
else
    echo -e "${GREEN}  ✓ appimagetool found"
fi

# Fix ELF interpreter
echo -e "${YELLOW}  Step 5: Fix ELF interpreter..."
patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 AppDir/usr/bin/scratchmark

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ ELF interpreter fixed"
else
    echo -e "${RED}  ✗ ELF interpreter fix failed"
    exit 1
fi

# Verify ELF
echo -e "${BLUE}  Verifying ELF..."
INTERP=$(readelf -l AppDir/usr/bin/scratchmark | grep -A2 "INTERP" | grep -q "/lib64/ld-linux-x86-64.so.2")

if [ "$INTERP" = "true" ]; then
    echo -e "${GREEN}  ✓ ELF interpreter verified: /lib64/ld-linux-x86-64.so.2"
else
    INTERP=$(readelf -l AppDir/usr/bin/scratchmark | grep -A2 "INTERP" | head -1)
    echo -e "${RED}  ✗ ELF interpreter: $INTERP"
fi

echo ""
echo -e "${YELLOW}  Step 6: Create AppImage..."

# Determine appimagetool command
if [ -f ~/.local/bin/appimagetool-x86_64.AppImage ]; then
    APPIMAGETOOL=~/.local/bin/appimagetool-x86_64.AppImage
else
    APPIMAGETOOL=appimagetool-x86_64.AppImage
    # Download to current dir
    wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x appimagetool-x86_64.AppImage
fi

# Create AppImage
$APPIMAGETOOL AppDir "$APPIMAGE_NAME"

if [ -f "$APPIMAGE_NAME" ]; then
    echo -e "${GREEN}  ✓ AppImage created"
    SIZE=$(du -h "$APPIMAGE_NAME" | cut -f1)
    echo -e "${BLUE}  Size: $SIZE"
else
    echo -e "${RED}  ✗ AppImage creation failed"
    exit 1
fi

echo ""
echo -e "${BLUE}========================================"
echo -e "${GREEN}  AppImage Build Complete!"
echo -e "${BLUE}========================================"
echo ""
echo -e "${BLUE}  AppImage: $APPIMAGE_NAME"
echo -e "${BLUE}  Size: $(du -h $APPIMAGE_NAME | cut -f1)"
echo ""

# Generate checksum
echo -e "${YELLOW}  Generating SHA256 checksum..."
sha256sum "$APPIMAGE_NAME" > "$APPIMAGE_NAME.sha256"

echo -e "${GREEN}  Checksum:"
cat "$APPIMAGE_NAME.sha256"
echo ""

# Cleanup
rm -rf build

echo -e "${BLUE}========================================"
echo -e "${BLUE}  Ready to publish!"
echo -e "${BLUE}========================================"
echo ""
echo -e "${GREEN}  To test:"
echo -e "  chmod +x $APPIMAGE_NAME"
echo -e "  ./$APPIMAGE_NAME"
echo ""
echo -e "${GREEN}  To publish to GitHub:"
echo -e "  gh release create v${VERSION}"
echo -e "  gh release upload v${VERSION} $APPIMAGE_NAME"
echo ""
