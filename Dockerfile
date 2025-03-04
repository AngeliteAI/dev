# Start with Fedora as the base image update
FROM fedora:latest

# Define ARGs for Redis credentials
ARG REDIS_PASSWORD
ARG GIT_TOKEN

# Update the system and install basic development tools
RUN dnf update -y && \
    dnf install -y \
    wget \
    curl \
    git \
    gcc \
    gcc-c++ \
    make \
    cmake \
    ninja-build \
    pkg-config \
    gnupg2 \
    tar \
    xz \
    unzip \
    python3 \
    python3-pip \
    nodejs \
    npm \
    ripgrep \
    fd-find \
    neovim \
    openssl \
    openssl-devel \
    ca-certificates

# Install Zig
RUN ZIG_VERSION="0.13.0" && \
    curl -sSL "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz" -o zig.tar.xz && \
    mkdir -p /opt/zig && \
    tar -xf zig.tar.xz -C /opt/zig --strip-components=1 && \
    rm zig.tar.xz && \
    ln -s /opt/zig/zig /usr/local/bin/zig

# Install Rust through rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    . $HOME/.cargo/env && \
    rustup component add rust-analyzer rust-src

# Configure environment for sccache before installing
ENV RUSTC_WRAPPER="sccache"
ENV SCCACHE_REDIS="redis://:${REDIS_PASSWORD}@abandon.angelite.systems"
ENV OPENSSL_DIR="/usr"
ENV PATH="/root/.cargo/bin:/opt/zig:${PATH}"

# Install sccache from pre-built binary
RUN curl -L https://github.com/mozilla/sccache/releases/download/v0.10.0/sccache-v0.10.0-x86_64-unknown-linux-musl.tar.gz -o sccache.tar.gz && \
    mkdir -p sccache-extract && \
    tar -xzf sccache.tar.gz -C sccache-extract --strip-components=1 && \
    cp sccache-extract/sccache /usr/local/bin/ && \
    chmod +x /usr/local/bin/sccache && \
    rm -rf sccache.tar.gz sccache-extract

# Configure sccache with Redis
RUN mkdir -p ~/.config/sccache && \
    echo '[cache]\ntype = "redis"\n\n[cache.redis]\nendpoint = "redis://default:'${REDIS_PASSWORD}'@abandon.angelite.systems"' > ~/.config/sccache/config.toml

# Install cargo tools using sccache (now that it's properly configured)
RUN . $HOME/.cargo/env && \
    cargo install cargo-watch cargo-expand cargo-edit tokei

# Get Neovim configuration from the GitHub repository
RUN mkdir -p ~/.config/nvim && \
    git clone https://github.com/solmidnight/.config.git /tmp/.config && \
    cp /tmp/.config/nvim/init.lua ~/.config/nvim/ && \
    rm -rf /tmp/.config

RUN git config --global user.name "solmidnight" && \
    git config --global user.email "sol@angelite.ai"

# Pull angelite repository
RUN git clone https://solmidnight:${GIT_TOKEN}@github.com/angeliteai/angelite /tmp/angelite && \
    cp -r /tmp/angelite /workspace

# Set working directory
WORKDIR /workspace
CMD ["bash"]
