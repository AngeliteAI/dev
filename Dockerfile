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

# Configure sccache with Redis and proper ARG expansion
ARG REDIS_PASSWORD
RUN mkdir -p /root/.config/sccache && \
    echo '[cache]\ntype = "redis"\n\n[cache.redis]\nurl = "redis://default:'${REDIS_PASSWORD}'@abandon.angelite.systems"' > /root/.config/sccache/config.toml

# Install Rust through rustup - split into multiple commands
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Add cargo binaries to PATH
ENV PATH="/root/.cargo/bin:${PATH}"

# Configure Rust to use sccache with proper variable expansion
ARG REDIS_PASSWORD
# Set environment variables through shell to ensure proper expansion
RUN echo "export RUSTC_WRAPPER=sccache" >> /etc/profile.d/sccache.sh && \
    echo "export SCCACHE_REDIS=redis://default:${REDIS_PASSWORD}@abandon.angelite.systems" >> /etc/profile.d/sccache.sh && \
    echo "export OPENSSL_DIR=/usr" >> /etc/profile.d/sccache.sh && \
    chmod +x /etc/profile.d/sccache.sh

# Source the environment in each cargo install
ENV RUSTC_WRAPPER="sccache"
ENV OPENSSL_DIR="/usr"

# Add rust components now that PATH is set
RUN rustup component add rust-analyzer rust-src

# Install cargo tools one at a time with environment properly sourced
RUN source /etc/profile.d/sccache.sh && cargo install cargo-watch
RUN source /etc/profile.d/sccache.sh && cargo install cargo-expand  
RUN source /etc/profile.d/sccache.sh && cargo install cargo-edit
RUN source /etc/profile.d/sccache.sh && cargo install tokei

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
