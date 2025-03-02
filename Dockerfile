# Start with Fedora as the base image
FROM fedora:latest

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
    neovim

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
    rustup component add rust-analyzer rust-src && \
    cargo install cargo-watch cargo-expand cargo-edit

# Get Neovim configuration from the GitHub repository
RUN mkdir -p ~/.config/nvim && \
    git clone https://github.com/solmidnight/.config.git /tmp/.config && \
    cp /tmp/.config/nvim/init.lua ~/.config/nvim/ && \
    rm -rf /tmp/.config
# Pull angelite repository
RUN git clone https://solmidnight:{GITHUB_TOKEN}@github.com/angeliteai/angelite /tmp/angelite && \
    cp -r /tmp/angelite /workspace

# Set environment variables
ENV PATH="/root/.cargo/bin:${PATH}"
ENV PATH="/opt/zig:${PATH}"

# Set working directory
WORKDIR /workspace

CMD ["bash"]
