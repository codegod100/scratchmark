# Building Scratchmark AppImage

This document describes two methods for building the Scratchmark AppImage.

## Method 1: Nix Build (flake.nix)

**Status:** ✅ Working, with ELF interpreter fix

**Commands:**
```bash
# Using Nix (recommended for reproducible builds)
nix build .#appimage

# Or use helper script
bash scripts/build-appimage-fixed.sh
```

**Pros:**
- Reproducible builds
- All dependencies from Nixpkgs
- Works with Cachix for caching

**Cons:**
- Requires Nix installation
- Sandbox can block network access
- ELF interpreter needs fixing (already done in flake.nix)

---

## Method 2: Standard Linux Build (Recommended for distrobox)

**Status:** ✅ Available

**Commands:**
```bash
# Using standard Linux tools (no Nix required)
bash scripts/build-appimage-standard.sh
```

**Why use this in distrobox:**
- No Nix sandbox issues (full network access)
- Standard ELF interpreter paths (no patching needed)
- Faster builds (no Nix derivation overhead)
- Simpler debugging

**Requirements:**
- cargo
- meson
- ninja
- patchelf
- pkg-config
- glib-compile-resources
- appimagetool (auto-downloaded by script)

**Install in distrobox:**
```bash
# Install build tools
sudo pacman -S meson ninja patchelf

# Install development dependencies
sudo pacman -S base-devel libadwaita libadwaita-dev gtksourceview5 gtksourceview5-dev
```

---

## What's In the AppImage

### Both Methods Create The Same AppImage Structure:

```
scratchmark-1.8.0-x86_64.AppImage
├── usr/
│   ├── bin/
│   │   └── scratchmark (binary)
│   └── share/
│       ├── applications/
│       │   └── org.scratchmark.Scratchmark.desktop
│       ├── icons/ (scalable + symbolic)
│       ├── glib-2.0/schemas/
│       │   └── org.scratchmark.Scratchmark.gschema.xml
│       ├── metainfo/
│       │   └── org.scratchmark.Scratchmark.metainfo.xml
│       └── scratchmark/
│           └── scratchmark.gresource
├── AppRun (wrapper script)
├── .DirIcon (desktop icon)
└── org.scratchmark.Scratchmark.desktop (for appimagetool)
```

### System Requirements (Same for Both):

Users need these libraries on their system:
- `gtk4`
- `libadwaita-1`
- `gtksourceview-5`

**Ubuntu/Debian:**
```bash
sudo apt install libgtk-4-1 libadwaita-1-0 libgtksourceview-5-0
```

**Fedora:**
```bash
sudo dnf install gtk4 libadwaita gtksourceview5
```

**Arch Linux:**
```bash
sudo pacman -S gtk4 libadwaita gtksourceview5
```

---

## Verification

After building, verify the AppImage:

```bash
# Check it's an ELF executable
file dist/Scratchmark-*.AppImage

# Extract and verify
./dist/Scratchmark-*.AppImage --appimage-extract

# Test it
chmod +x dist/Scratchmark-*.AppImage
./dist/Scratchmark-*.AppImage
```

---

## Publishing

Both methods produce the same AppImage. Choose your preferred workflow:

### Option 1: Use Nix (Recommended for CI/CD)
- Works with Cachix
- Reproducible builds
- `nix build .#appimage`

### Option 2: Use Standard Build (Recommended for local/distrobox)
- No Nix required
- Full network access
- `bash scripts/build-appimage-standard.sh`

---

## Troubleshooting

### AppImage doesn't run:
- Check file permissions: `chmod +x Scratchmark-*.AppImage`
- Check system libraries are installed
- Try `--appimage-extract` to verify structure

### Build fails:
- Make sure all dependencies are installed
- Check you're in the repository root
- Clean build artifacts: `rm -rf build`

### ELF interpreter issues (Nix only):
- The Nix flake has been fixed with `patchelf --set-interpreter`
- AppImages from Nix builds should work on all Linux distributions
