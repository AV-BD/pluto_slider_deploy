#!/bin/bash

# Pluto Slider Server Infrastructure - Validation Script
# This script helps validate that the installation is ready for deployment

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "🔍 Pluto Slider Server Infrastructure Validation"
echo "=================================================="

# Check Docker
if command -v docker &> /dev/null; then
    log_success "Docker is installed"
    docker --version
else
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

# Check Docker Compose
if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    log_success "Docker Compose is available"
    docker compose version 2>/dev/null || docker-compose --version
else
    log_error "Docker Compose is not installed"
    exit 1
fi

# Check directory structure
log_info "Checking directory structure..."
required_files=(
    "docker/Dockerfile"
    "docker/entrypoint.sh"
    "config/repos.yaml"
    "docker-compose.yml"
    ".env.example"
    "README.md"
    ".gitignore"
)

missing_files=()
for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        log_success "Found: $file"
    else
        log_error "Missing: $file"
        missing_files+=("$file")
    fi
done

if [[ ${#missing_files[@]} -gt 0 ]]; then
    log_error "Missing required files. Installation incomplete."
    exit 1
fi

# Check .env file
if [[ -f ".env" ]]; then
    log_success "Found .env file"
    if grep -q "GITHUB_TOKEN=your_github" .env; then
        log_warning ".env file contains placeholder token - replace with actual token"
    else
        log_success ".env file appears configured"
    fi
else
    log_warning "No .env file found. Copy .env.example to .env and configure."
fi

# Check repos.yaml configuration
if grep -q "your-github-username" config/repos.yaml; then
    log_warning "config/repos.yaml contains example configuration - update with your repositories"
else
    log_info "config/repos.yaml appears to be configured"
fi

# Check entrypoint script permissions
if [[ -x "docker/entrypoint.sh" ]]; then
    log_success "Entrypoint script is executable"
else
    log_warning "Entrypoint script may need execute permissions"
fi

# Try building the image (optional)
echo ""
log_info "Ready to test build? (This will take several minutes)"
read -p "Build Docker image now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Building Docker image..."
    if docker compose build; then
        log_success "Docker image built successfully!"
    else
        log_error "Docker build failed"
        exit 1
    fi
fi

echo ""
echo "🎉 Validation complete!"
echo ""
echo "Next steps:"
echo "1. Configure config/repos.yaml with your repositories"
echo "2. Copy .env.example to .env and add your GitHub token"
echo "3. Run: docker compose up -d"
echo "4. Access PlutoSliderServer at http://localhost:2345"
echo ""
echo "For more details, see README.md"