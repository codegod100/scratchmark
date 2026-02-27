FROM archlinux/base:latest

# Install build dependencies
RUN pacman -Syu --noconfirm --needed meson ninja patchelf pkg-config cargo gtk4 libadwaita gtksourceview5

# Install additional tools
RUN pacman -Syu --noconfirm --needed wget

# Set working directory
WORKDIR /build

# Copy source code
COPY . .

# Build the binary
RUN cargo build --release

# Build resources
RUN meson setup build
RUN cd build && meson compile

# Build AppImage structure
RUN mkdir -p /AppDir/usr/{bin,share/{applications,icons,metainfo,glib-2.0/schemas}}
RUN cp target/release/scratchmark /AppDir/usr/bin/
RUN chmod +x /AppDir/usr/bin/scratchmark

RUN mkdir -p /AppDir/usr/share/scratchmark
RUN cp build/data/resources/scratchmark.gresource /AppDir/usr/share/scratchmark/
RUN cp build/data/org.scratchmark.Scratchmark.desktop /AppDir/usr/share/applications/
RUN cp data/org.scratchmark.Scratchmark.gschema.xml /AppDir/usr/share/glib-2.0/schemas/
RUN cp build/data/org.scratchmark.Scratchmark.metainfo.xml /AppDir/usr/share/metainfo/
RUN cp -r data/icons/* /AppDir/usr/share/icons/

# Copy AppRun
COPY scripts/AppRun.in /AppDir/AppRun
RUN chmod +x /AppDir/AppRun

# Copy icon and desktop to root
RUN cp data/icons/hicolor/scalable/apps/org.scratchmark.Scratchmark.svg /AppDir/.DirIcon
RUN cp build/data/org.scratchmark.Scratchmark.desktop /AppDir/org.scratchmark.Scratchmark.desktop

# Download appimagetool
RUN wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O /usr/local/bin/appimagetool
RUN chmod +x /usr/local/bin/appimagetool

# Fix ELF interpreter
RUN patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 /AppDir/usr/bin/scratchmark

# Create AppImage
RUN /usr/local/bin/appimagetool /AppDir /Scratchmark-1.8.0-x86_64.AppImage

# Copy AppImage to output location
RUN cp /Scratchmark-1.8.0-x86_64.AppImage /output/

# Generate checksum
RUN cd /output && sha256sum Scratchmark-1.8.0-x86_64.AppImage > sha256sums.txt

# Verify ELF interpreter
RUN echo "Verifying ELF interpreter..."
RUN readelf -l /output/Scratchmark-1.8.0-x86_64.AppImage | grep -A2 "INTERP" | grep "0x000000000042" | head -1 | xargs -I{} grep -q "/lib64/ld-linux-x86-64.so.2"; then \
    echo "✓ ELF interpreter correct: /lib64/ld-linux-x86-64.so.2" \
  || echo "✗ ELF interpreter incorrect"

# Clean up
RUN rm -rf /AppDir /build

# Display results
RUN echo "=========================================="
RUN echo "✓ AppImage built successfully!"
RUN echo "Location: /output/Scratchmark-1.8.0-x86_64.AppImage"
RUN echo "Version: 1.8.0"
RUN ls -lh /output/*.AppImage
RUN echo ""
RUN echo "SHA256:"
RUN cat /output/sha256sums.txt
RUN echo "=========================================="
