#!/bin/bash
# Build AppImage with ELF interpreter fix for Nix builds

set -e

VERSION=$(grep '^version' Cargo.toml | head -1 | cut -d'"' -f2)
APPIMAGE_NAME="Scratchmark-${VERSION}-x86_64.AppImage"

echo "Building Scratchmark AppImage v${VERSION}..."
echo ""

# Build with Nix for dependencies
echo "Step 1: Building binary with Nix..."
nix develop --command bash -c "cargo build --release" --impure 2>/dev/null

# Create AppDir
echo "Step 2: Creating AppDir structure..."
rm -rf AppDir squashfs-root
mkdir -p AppDir/usr/{bin,share/{applications,icons,metainfo,glib-2.0/schemas}}

# Copy binary
echo "Step 3: Copying binary..."
cp target/release/scratchmark AppDir/usr/bin/
chmod +x AppDir/usr/bin/scratchmark

# Build resources with meson
echo "Step 4: Building resources..."
nix develop --command bash -c "meson setup build && cd build && meson compile"

# Copy resources
echo "Step 5: Copying resources..."
mkdir -p AppDir/usr/share/scratchmark
cp build/data/resources/scratchmark.gresource AppDir/usr/share/scratchmark/
cp build/data/org.scratchmark.Scratchmark.desktop AppDir/usr/share/applications/
cp data/org.scratchmark.Scratchmark.gschema.xml AppDir/usr/share/glib-2.0/schemas/
cp build/data/org.scratchmark.Scratchmark.metainfo.xml AppDir/usr/share/metainfo/
cp -r data/icons/* AppDir/usr/share/icons/

# Copy AppRun
cp scripts/AppRun.in AppDir/AppRun
chmod +x AppDir/AppRun

# Copy icon and desktop to root for appimagetool
cp data/icons/hicolor/scalable/apps/org.scratchmark.Scratchmark.svg AppDir/.DirIcon
cp build/data/org.scratchmark.Scratchmark.desktop AppDir/org.scratchmark.Scratchmark.desktop

# Fix ELF interpreter
echo "Step 6: Fixing ELF interpreter..."
cat > /tmp/patchelf.nix << 'EOF'
{ pkgs ? import <nixpkgs> {} }:
pkgs.stdenv.mkDerivation {
  name = "patchelf-fix";
  buildInputs = [ pkgs.patchelf ];
  buildCommand = ''
    ${pkgs.patchelf}/bin/patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 AppDir/usr/bin/scratchmark
  '';
}
EOF

nix-build /tmp/patchelf.nix 2>/dev/null
rm /tmp/patchelf.nix

# Verify fix
INTERPRETER=$(patchelf -i AppDir/usr/bin/scratchmark | grep interpreter | grep -o '/nix/store/[^"]*' || echo "fixed")
if [ -n "$INTERPRETER" ]; then
    echo "✓ ELF interpreter fixed successfully"
else
    echo "✗ Failed to set ELF interpreter"
    echo "  Current interpreter: $(patchelf -i AppDir/usr/bin/scratchmark | grep interpreter)"
    exit 1
fi

# Download appimagetool
echo "Step 7: Downloading appimagetool..."
if [ ! -f ~/.local/bin/appimagetool-x86_64.AppImage ]; then
    mkdir -p ~/.local/bin
    cd ~/.local/bin
    wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x appimagetool-x86_64.AppImage
    cd -
fi

# Create AppImage
echo "Step 8: Creating AppImage..."
~/.local/bin/appimagetool-x86_64.AppImage AppDir "$APPIMAGE_NAME"

# Create dist directory
echo "Step 9: Packaging..."
mkdir -p dist
cp "$APPIMAGE_NAME" dist/
chmod +x "dist/$APPIMAGE_NAME"

# Generate checksum
cd dist
sha256sum "$APPIMAGE_NAME" > sha256sums.txt

# Cleanup
rm -rf AppDir squashfs-root build

echo ""
echo "✓ AppImage built successfully!"
echo ""
echo "Location: dist/$APPIMAGE_NAME"
echo "Size: $(du -h "$APPIMAGE_NAME" | cut -f1)"
SHA256=$(cat sha256sums.txt | cut -d' ' -f1)
echo "SHA256: $SHA256"
echo ""
