# Pluto Slider Server Infrastructure
# Stateless Docker image containing Julia + Pluto + PlutoSliderServer + git

FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    ca-certificates \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Julia 1.10.0 (updated version for PlutoSliderServer compatibility)
ENV JULIA_VERSION=1.10.0
ENV JULIA_PATH=/usr/local/julia
ENV PATH=$JULIA_PATH/bin:$PATH

RUN mkdir -p $JULIA_PATH && \
    curl -sSL "https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-${JULIA_VERSION}-linux-x86_64.tar.gz" | \
    tar -xz --strip-components=1 -C $JULIA_PATH

# Create working directories
RUN mkdir -p /app/data/repos /app/data/index

# Set working directory
WORKDIR /app

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Install Julia packages at build time for faster startup
# This creates a system-wide Julia environment with required packages
RUN julia -e 'using Pkg; Pkg.add(["Pluto", "PlutoSliderServer"]); Pkg.precompile()'

# Create non-root user for security
RUN useradd -m -u 1000 pluto && \
    chown -R pluto:pluto /app

# Switch to non-root user
USER pluto

# Expose PlutoSliderServer port
EXPOSE 2345

# Set environment variables
ENV JULIA_PROJECT=""
ENV REPOS_CONFIG_PATH="/app/config/repos.yaml"
ENV DATA_DIR="/app/data"
ENV REPOS_DIR="/app/data/repos"
ENV INDEX_DIR="/app/data/index"
ENV SERVER_HOST="0.0.0.0"
ENV SERVER_PORT="2345"

# Default entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]