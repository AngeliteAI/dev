# Start with Fedora as the base image update
FROM fedora:latest

# Define ARGs for Redis credentials
ARG REDIS_PASSWORD
ARG GIT_TOKEN

# Install sccache from pre-built binary
RUN curl -L https://github.com/mozilla/sccache/releases/download/v0.10.0/sccache-v0.10.0-x86_64-unknown-linux-musl.tar.gz -o sccache.tar.gz && \
    mkdir -p sccache-extract && \
    tar -xzf sccache.tar.gz -C sccache-extract --strip-components=1 && \
    cp sccache-extract/sccache /usr/local/bin/ && \
    chmod +x /usr/local/bin/sccache && \
    rm -rf sccache.tar.gz sccache-extract

# Install Rust through rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Set up sccache and ensure ARG is properly expanded
ARG REDIS_PASSWORD

# Set environment variables for sccache
ENV PATH="/root/.cargo/bin:${PATH}" \
    RUSTC_WRAPPER="sccache" \
    OPENSSL_DIR="/usr" \
    REDIS_PASSWORD=${REDIS_PASSWORD} \
    SCCACHE_REDIS=redis://default:${REDIS_PASSWORD}@abandon.angelite.systems

# Use a shell form RUN to ensure environment is picked up from .bashrc
SHELL ["/bin/bash", "-c"]

# Add rust components now that PATH is set
RUN rustup component add rust-analyzer rust-src

# Install cargo tools with environment variables set at build time
RUN cargo install cargo-watch cargo-expand cargo-edit tokei

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
