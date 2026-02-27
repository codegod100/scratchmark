[![CI Status Badge](https://github.com/sevonj/scratchmark/actions/workflows/ci.yml/badge.svg)](https://github.com/sevonj/scratchmark/actions/workflows/ci.yml)

<div align="center">

![app icon](data/icons/hicolor/scalable/apps/org.scratchmark.Scratchmark.svg)

# Scratchmark

https://scratchmark.org

</div>

**\*\*Scratchmark\*\*** is a pleasant Markdown editor for writing. It tries to give you everything you need and otherwise stay out of your way so you can just focus on the text. The app can be used for writing essays and making quick notes alike. Its file management is built around a folder structure that can handle large projects with lots of files. You can add any folder on your computer to the library, and move files around by dragging and dropping.

![screenshot](data/screenshots/screenshot_a_light.png)

![screenshot](data/screenshots/screenshot_b_light.png)

![screenshot](data/screenshots/screenshot_c_dark.png)

![cat](https://github.com/user/attachments/assets/aaa7b4175e2f-4a87-add9b-aa29591d6bcd)

## Get Scratchmark

### Linux

<a href='https://flathub.org/apps/org.scratchmark.Scratchmark'>
<img height='48' alt='Get it on Flathub' src='https://flathub.org/api/badge?svg&locale=en'/>
</a>

### Windows

(planned)

## Contribute

<div align="center">

<p style="font-size: 3em; font-variant-caps: small-caps;">I want <b>you</b></p>
<p style="font-size: 3em;">🫵</p>
<p style="font-size: 2em; font-variant-caps: small-caps;">to contribute</p>
<p>Enlist now!</p>

</div>

[➜ Translation](https://translate.codeberg.org/projects/scratchmark/app/)  
[➜ Project Backlog](https://github.com/users/sevonj/projects/20)  
[➜ Website Source](https://github.com/sevonj/scratchmark.org)  
[➜ Chat #scratchmark:matrix.org](https://matrix.to/#/#scratchmark:matrix.org)

If you find an issue that's important to you, give it a thumbs up.  
You're also welcome to improve the website, which is currently rather barebones.  

## Developers

Scratchmark is written in Rust and uses GTK4 and Libadwaita for UI.

### License

Scratchmark is licensed GPL-3.0-or-later. Some parts may _additionally_ be available under other licenses, such as MIT.

### Building

The project uses a standard build system (Meson + Cargo).

### Dependencies

Ubuntu

\`\`\`bash
libgtk-4-dev build-essential libglib2.0-dev libadwaita-1-dev libgtksourceview-5-dev
\`\`\`

### Flatpak

Generating a Flatpak

#### Dependencies

You need Flatpak with Flathub and following packages:

\`\`\`bash
org.gnome.Sdk//49
\`\`\`

#### Building

Build & install:

\`\`\`bash
cd build-aux
sh generate_flatpak.sh && flatpak install Scratchmark.flatpak --user -y
\`\`\`

### AppImage

Build Scratchmark AppImage using Docker:

\`\`\`bash
# Build Docker image
docker build -t scratchmark-build .

# Build AppImage in Docker
docker run --rm -v \$(pwd):/output scratchmark-build

# Get AppImage from Docker output
docker cp scratchmark-build:/output/Scratchmark-*.AppImage .

# Or use Docker Compose
# See DOCKER_BUILD.md for detailed instructions
\`\`\`

**Dependencies:**
- docker

**System Requirements (same for all Linux):**
- gtk4
- libadwaita-1
- gtksourceview-5

**Note:** The AppImage does not bundle GTK4 or libadwaita. Users need these libraries installed on their system.

On Ubuntu/Debian:
\`\`\`bash
sudo apt install libgtk-4-1 libadwaita-1-0 libgtksourceview-5-0
\`\`\`

On Fedora:
\`\`\`bash
sudo dnf install gtk4 libadwaita gtksourceview5
\`\`\`

On Arch Linux:
\`\`\`bash
sudo pacman -S gtk4 libadwaita gtksourceview5
\`\`\`

**Documentation:** See [DOCKER_BUILD.md](DOCKER_BUILD.md) for detailed Docker build instructions, including:
- Complete build process
- Environment setup
- Troubleshooting common issues
- How to extract and test AppImage

**Advantages of Docker Build:**
- **No special setup required** - Works with any Linux distribution
- **Full network access** - No sandbox restrictions during build
- **Standard ELF paths** - Binary uses `/lib64/ld-linux-x86-64.so.2` interpreter
- **Reproducible** - Same Docker image produces identical AppImages
- **Cross-platform** - Can build on any system with Docker installed

**Quick Start:**
\`\`\`bash
# 1. Build and get AppImage (all in one command)
docker build -t scratchmark-build . && \
docker run --rm -v \$(pwd):/output scratchmark-build && \
docker cp scratchmark-build:/output/Scratchmark-*.AppImage .

# 2. Test it
chmod +x Scratchmark-*.AppImage
./Scratchmark-*.AppImage
\`\`\`

**AppImage Structure:**
The Docker-built AppImage contains:
- \`\`\`scratchmark\`\` binary
- GTK4 resources (icons, UI templates)
- GSettings schema
- Desktop entry
- \`\`\`.desktop\`\` and \`\`DirIcon\`\` for AppImage
- \`\`\`AppRun\`\` wrapper script

**SHA256 Checksum:**
See [DOCKER_BUILD.md](DOCKER_BUILD.md) for the checksum of your specific build.

---

**Release Process:**
AppImages are automatically built and released to GitHub when you push a version tag:

\`\`\`bash
git tag v1.8.0
git push origin v1.8.0
\`\`\`

The AppImage will be available at:
\`\`\`
https://github.com/sevonj/scratchmark/releases/download/v1.8.0/Scratchmark-1.8.0-x86_64.AppImage
\`\`\`

---

**Alternative: Local Build (for development)**
If you prefer to build locally without Docker, see [scripts/build-appimage-standard.sh](scripts/build-appimage-standard.sh) for standard Linux build instructions.

**Note:** Both Docker and local builds produce identical AppImages with proper ELF interpreters for all Linux distributions.
