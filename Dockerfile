# Multi-stage Docker build for Scratchmark AppImage

FROM ubuntu:22.04 AS builder

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    build-essential \
    pkg-config \
    meson \
    ninja-build \
    patchelf \
    gettext \
    libglib2.0-dev \
    libgtk-4-dev \
    libadwaita-1-dev \
    libgtksourceview-5-dev \
    libpango1.0-dev \
    libcairo2-dev

# Set PKG_CONFIG_PATH to include all library directories
ENV PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
ENV RUSTUP_HOME="/root/.rustup"

WORKDIR /build

# Copy source code
COPY . .

# Build binary
RUN cargo build --release

# Build resources
RUN rm -rf build
RUN meson setup build
RUN cd build && meson compile

# Create AppDir
RUN rm -rf AppDir
RUN mkdir -p /AppDir/usr/{bin,share/{applications,icons,metainfo,glib-2.0/schemas}}

# Copy binary
RUN cp target/release/scratchmark /AppDir/usr/bin/ && \
    chmod +x /AppDir/usr/bin/scratchmark

# Copy resources
RUN mkdir -p /AppDir/usr/share/scratchmark && \
    cp build/data/resources/scratchmark.gresource /AppDir/usr/share/scratchmark/ && \
    cp build/data/org.scratchmark.Scratchmark.desktop /AppDir/usr/share/applications/ && \
    cp data/org.scratchmark.Scratchmark.gschema.xml /AppDir/usr/share/glib-2.0/schemas/ && \
    cp build/data/org.scratchmark.Scratchmark.metainfo.xml /AppDir/usr/share/metainfo/ && \
    cp -r data/icons/* /AppDir/usr/share/icons/

# Copy AppRun
RUN cp scripts/AppRun.in /AppDir/AppRun && \
    chmod +x /AppDir/AppRun

# Copy icon and desktop to root
RUN cp data/icons/hicolor/scalable/apps/org.scratchmark.Scratchmark.svg /AppDir/.DirIcon && \
    cp build/data/org.scratchmark.Scratchmark.desktop /AppDir/org.scratchmark.Scratchmark.desktop

# Download appimagetool
RUN wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O /usr/local/bin/appimagetool && \
    chmod +x /usr/local/bin/appimagetool

# Fix ELF interpreter
RUN patchelf --set-interpreter /lib64/ld-linux-x86_64.so.2 /AppDir/usr/bin/scratchmark

# Verify ELF fix
RUN readelf -l /AppDir/usr/bin/scratchmark | grep -A2 "INTERP" | grep -q "0x000000000042" && \
    echo "Verified: ELF interpreter is correct: /lib64/ld-linux-x86-64.so.2" || \
    (echo "ERROR: ELF interpreter is incorrect" && exit 1)

# Create AppImage
RUN /usr/local/bin/appimagetool /AppDir /Scratchmark-1.8.0-x86_64.AppImage

# Generate checksum
RUN sha256sum /Scratchmark-1.8.0-x86_64.AppImage > sha256sums.txt && \
    cat sha256sums.txt

# Clean up
RUN rm -rf /AppDir /build /root/.cargo

# Display results
RUN echo "==========================================" && \
    echo "AppImage built successfully!" && \
    echo "Location: /Scratchmark-1.8.0-x86_64.AppImage" && \
    echo "Version: 1.8.0" && \
    echo "" && \
    echo "SHA256:" && \
    cat sha256sums.txt && \
    echo "=========================================="

# Final stage
FROM ubuntu:22.04 AS final

# Copy from builder stage
COPY --from=builder /Scratchmark-1.8.0-x86_64.AppImage /scratchmark.AppImage
COPY --from=builder /sha256sums.txt /sha256sums.txt

# Metadata
LABEL maintainer="scratchmark"
LABEL description="Scratchmark Markdown Editor - AppImage Build"

WORKDIR /output
