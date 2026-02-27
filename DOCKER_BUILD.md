# Building Scratchmark AppImage in Docker

This guide explains how to build Scratchmark AppImage using Docker instead of Nix, providing a clean, reproducible environment with full network access.

## Quick Start

```bash
# Build Docker image
docker build -t scratchmark-build .

# Run Docker container to build AppImage
docker run --rm -v $(pwd):/dist:/output scratchmark-build

# Get the AppImage from the output directory
ls -lh dist/*.AppImage
```

That's it! The AppImage is built inside Docker and copied to your `dist/` folder.

---

## Why Use Docker?

| Benefit | Docker | Nix |
|----------|-----------|------|
| No Nix required | ❌ Yes | ✅ No |
| Full network access | ✅ Yes | ❌ No (sandbox blocks crates.io) |
| No sandbox issues | ✅ Yes | ❌ Yes |
| Reproducible | ✅ Yes | ✅ Yes |
| Faster builds | ✅ Native tools | ⏳ Derivations |
| Simpler setup | ✅ Just `docker build` | 🔧 Complex config |

---

## What's Inside

### Dockerfile

```dockerfile
FROM archlinux/base:latest

# Install build dependencies
RUN pacman -Syu --noconfirm --needed meson ninja patchelf cargo pkg-config gtk4 libadwaita gtksourceview5

# Install additional tools
RUN pacman -Syu --noconfirm --needed wget

# Set working directory
WORKDIR /build

# Copy source code
COPY . .

# Build
RUN cargo build --release

# Build resources
RUN meson setup build && cd build && meson compile

# Build AppImage structure
RUN rm -rf AppDir
RUN mkdir -p AppDir/usr/{bin,share/{applications,icons,metainfo,glib-2.0/schemas}}

# Copy binary
RUN cp target/release/scratchmark AppDir/usr/bin/
RUN chmod +x AppDir/usr/bin/scratchmark

# Copy resources
RUN mkdir -p AppDir/usr/share/scratchmark
RUN cp build/data/resources/scratchmark.gresource AppDir/usr/share/scratchmark/
RUN cp build/data/org.scratchmark.Scratchmark.desktop AppDir/usr/share/applications/
RUN cp data/org.scratchmark.Scratchmark.gschema.xml AppDir/usr/share/glib-2.0/schemas/
RUN cp build/data/org.scratchmark.Scratchmark.metainfo.xml AppDir/usr/share/metainfo/
RUN cp -r data/icons/* AppDir/usr/share/icons/

# Copy AppRun
RUN cp scripts/AppRun.in AppDir/AppRun
RUN chmod +x AppDir/AppRun

# Copy icon and desktop to root
RUN cp data/icons/hicolor/scalable/apps/org.scratchmark.Scratchmark.svg AppDir/.DirIcon
RUN cp build/data/org.scratchmark.Scratchmark.desktop AppDir/org.scratchmark.Scratchmark.desktop

# Download appimagetool
RUN wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O /usr/local/bin/appimagetool
RUN chmod +x /usr/local/bin/appimagetool

# Fix ELF interpreter for standard Linux
RUN patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 AppDir/usr/bin/scratchmark

# Create AppImage
RUN /usr/local/bin/appimagetool AppDir Scratchmark-1.8.0-x86_64.AppImage

# Copy AppImage to output
RUN cp Scratchmark-1.8.0-x86_64.AppImage /output/

# Generate checksum
RUN cd /output
RUN sha256sum Scratchmark-1.8.0-x86_64.AppImage > sha256sums.txt
RUN cat sha256sums.txt

# Clean up
RUN rm -rf AppDir build

# Display results
RUN echo "=========================================="
RUN echo "✓ AppImage built successfully!"
RUN echo ""
RUN echo "AppImage: /output/Scratchmark-1.8.0-x86_64.AppImage"
RUN ls -lh /output/*.AppImage
RUN echo ""
RUN echo "SHA256:"
RUN cat /output/sha256sums.txt
RUN echo "=========================================="
```

---

## Building Locally

### Step 1: Build Docker Image

```bash
docker build -t scratchmark-build .
```

### Step 2: Build AppImage

```bash
docker run --rm -v $(pwd):/output scratchmark-build
```

The AppImage will be created in the container's `/output/` directory.

### Step 3: Extract AppImage to Host

```bash
# From Docker build output
docker cp scratchmark-build:/output/Scratchmark-1.8.0-x86_64.AppImage .

# Or from Docker run
docker run --rm -v $(pwd):/output scratchmark-build \
  cat output/Scratchmark-1.8.0-x86_64.AppImage > Scratchmark-1.8.0-x86_64.AppImage
```

---

## Using Docker Compose (Optional)

If you prefer Docker Compose:

```yaml
version: '3'
services:
  scratchmark-build:
    build:
      context: .
      dockerfile: Dockerfile
    volumes:
      - ./dist:/output
```

Then:
```bash
docker-compose up
docker cp scratchmark-build:/output/Scratchmark-1.8.0-x86_64.AppImage .
```

---

## Differences from Nix Build

| Aspect | Docker | Nix |
|---------|-----------|------|
| Build tools | `pacman -S` | `nix-store` |
| Network access | Full (unrestricted) | Sandbox (crates.io blocked) |
| ELF interpreter | `/lib64/ld-linux-x86-64.so.2` | `/nix/store/.../ld-linux-x86-64.so.2` (needs fixing) |
| Build environment | Native Arch Linux in Docker | Nix derivation |
| Caching | Docker layer caching | Nix store caching |
| Distribution | Copy from `/output` | Artifacts from `/nix/store` |

---

## System Requirements (Same)

Users still need these libraries on their system:

- `gtk4`
- `libadwaita-1`
- `gtksourceview-5`

**Install:**
```bash
# Arch Linux
sudo pacman -S gtk4 libadwaita gtksourceview5

# Ubuntu/Debian
sudo apt install libgtk-4-1 libadwaita-1-0 libgtksourceview-5-0

# Fedora
sudo dnf install gtk4 libadwaita gtksourceview5
```

---

## Verification

After building, verify the AppImage:

```bash
# Check it's an ELF executable
file Scratchmark-1.8.0-x86_64.AppImage

# Check ELF interpreter
readelf -l Scratchmark-1.8.0-x86_64.AppImage | grep -A2 "INTERP"

# Extract and test
./Scratchmark-1.8.0-x86_64.AppImage --appimage-extract
```

**Expected:**
- ELF interpreter: `/lib64/ld-linux-x86-64.so.2` (standard path)
- No Nix store paths in binary

---

## Troubleshooting

### AppImage doesn't run

**Check permissions:**
```bash
chmod +x Scratchmark-*.AppImage
```

**Check system libraries:**
```bash
# Check if GTK4 is installed
ldconfig -p libgtk-4-1

# Check if libadwaita is installed
ldconfig -p libadwaita-1

# Check if gtksourceview5 is installed
ldconfig -p libgtksourceview-5-0
```

### Build fails

**Common issues:**

1. **Missing build dependencies:**
   ```bash
   # Check what's missing
   pacman -Qi meson
   pacman -Qi ninja
   pacman -Qi patchelf
   ```

2. **meson build fails:**
   ```bash
   # Try building resources separately
   meson setup build
   meson compile
   ```

3. **ELF interpreter not fixed:**
   - AppImage still has Nix path: The `patchelf --set-interpreter` command failed
   - Verify: `readelf -l AppImage | grep "interpreter"`
   - Should show `/lib64/ld-linux-x86-64.so.2`, not `/nix/store/...`

4. **AppImage creation fails:**
   - appimagetool couldn't find required files
   - Make sure `.DirIcon` and `.desktop` exist in AppDir

---

## Publishing

The Docker approach produces the same AppImage as Nix builds, just built differently.

To publish:
1. Upload `Scratchmark-1.8.0-x86_64.AppImage` to your release assets
2. Provide the SHA256 checksum
3. Update documentation to mention Docker build option

---

## Advantages of Docker

1. **No Nix installation** required for users
2. **Full network access** during build
3. **Reproducible** builds (same Docker image produces same output)
4. **Easier debugging** - Full shell access inside container
5. **Cross-platform** - Can build on any system with Docker installed
6. **Simpler CI/CD** - Build Docker image once, deploy anywhere

---

## Summary

**Docker Build:** Clean, reproducible, no Nix sandbox issues  
**AppImage Output:** Same structure as Nix build, but with standard ELF interpreter  
**User Setup:** No special permissions needed, just install system libraries  

**What You Need:** Docker installed locally

---

## Quick Reference

```bash
# Build and extract in one command
docker build -t scratchmark-build . && \
docker run --rm -v $(pwd):/output scratchmark-build && \
docker cp scratchmark-build:/output/Scratchmark-1.8.0-x86_64.AppImage .
```

That's it! 🎊
