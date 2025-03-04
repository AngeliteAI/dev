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

# Install sccache from pre-built binary
RUN curl -L https://github.com/mozilla/sccache/releases/download/v0.10.0/sccache-v0.10.0-x86_64-unknown-linux-musl.tar.gz -o sccache.tar.gz && \
    mkdir -p sccache-extract && \
    tar -xzf sccache.tar.gz -C sccache-extract --strip-components=1 && \
    cp sccache-extract/sccache /usr/local/bin/ && \
    chmod +x /usr/local/bin/sccache && \
    rm -rf sccache.tar.gz sccache-extract

# Install Rust through rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Add cargo binaries to PATH
ENV PATH="/root/.cargo/bin:${PATH}"

# Configure sccache with Redis
RUN mkdir -p /root/.config/sccache

# Create a dedicated script for setting up sccache with the proper Redis password
RUN echo '#!/bin/bash' > /setup-sccache.sh && \
    echo 'echo -e "[cache]\ntype = \"redis\"\n\n[cache.redis]\nurl = \"redis://default:'${REDIS_PASSWORD}'@abandon.angelite.systems\"" > /root/.config/sccache/config.toml' >> /setup-sccache.sh && \
    echo 'export RUSTC_WRAPPER=sccache' >> /setup-sccache.sh && \
    echo 'export SCCACHE_REDIS="redis://default:'${REDIS_PASSWORD}'@abandon.angelite.systems"' >> /setup-sccache.sh && \
    echo 'export OPENSSL_DIR=/usr' >> /setup-sccache.sh && \
    chmod +x /setup-sccache.sh && \
    /setup-sccache.sh

# Add rust components
RUN export RUSTC_WRAPPER=sccache && \
    export SCCACHE_REDIS="redis://default:${REDIS_PASSWORD}@abandon.angelite.systems" && \
    export OPENSSL_DIR=/usr && \
    rustup component add rust-analyzer rust-src

# Install cargo tools with environment variables explicitly set in each RUN command
RUN export RUSTC_WRAPPER=sccache && \
    export SCCACHE_REDIS="redis://default:${REDIS_PASSWORD}@abandon.angelite.systems" && \
    export OPENSSL_DIR=/usr && \
    cargo install cargo-watch

RUN export RUSTC_WRAPPER=sccache && \
    export SCCACHE_REDIS="redis://default:${REDIS_PASSWORD}@abandon.angelite.systems" && \
    export OPENSSL_DIR=/usr && \
    cargo install cargo-expand

RUN export RUSTC_WRAPPER=sccache && \
    export SCCACHE_REDIS="redis://default:${REDIS_PASSWORD}@abandon.angelite.systems" && \
    export OPENSSL_DIR=/usr && \
    cargo install cargo-edit

RUN export RUSTC_WRAPPER=sccache && \
    export SCCACHE_REDIS="redis://default:${REDIS_PASSWORD}@abandon.angelite.systems" && \
    export OPENSSL_DIR=/usr && \
    cargo install tokei

# Get Neovim configuration from the GitHub repository
RUN mkdir -p /root/.config/nvim && \
    git clone https://github.com/solmidnight/.config.git /tmp/.config && \
    cp /tmp/.config/nvim/init.lua /root/.config/nvim/ && \
    rm -rf /tmp/.config

RUN git config --global user.name "solmidnight" && \
    git config --global user.email "sol@angelite.ai"

# Pull angelite repository
RUN git clone https://solmidnight:${GIT_TOKEN}@github.com/angeliteai/angelite /tmp/angelite && \
    cp -r /tmp/angelite /workspace

# Set environment variables for Zig path
ENV PATH="/opt/zig:${PATH}"

# Set working directory
WORKDIR /workspace

CMD ["bash"]
