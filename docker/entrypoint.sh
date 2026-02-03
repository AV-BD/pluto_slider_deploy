#!/bin/bash

# Pluto Slider Server Entrypoint Script
# Handles repository synchronization, notebook indexing, and server startup

set -euo pipefail

# Color output for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate required environment variables
validate_environment() {
    log_info "Validating environment..."
    
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        log_error "GITHUB_TOKEN environment variable is required"
        exit 1
    fi
    
    if [[ ! -f "$REPOS_CONFIG_PATH" ]]; then
        log_error "Repository configuration file not found: $REPOS_CONFIG_PATH"
        exit 1
    fi
    
    log_success "Environment validation passed"
}

# Parse repositories from YAML config
parse_repos_config() {
    # Simple YAML parser for our specific format
    # Expects repos.yaml format:
    # repositories:
    #   - owner: username
    #     repo: repo-name
    #   - owner: username2  
    #     repo: repo-name2
    
    # Parse without any logging to avoid contaminating the output
    grep -A 1000 "repositories:" "$REPOS_CONFIG_PATH" | \
    grep -E "^\s*-\s*owner:|^\s*repo:" | \
    sed 's/^\s*-\s*owner:\s*//' | \
    sed 's/^\s*repo:\s*//' | \
    paste - - | \
    while IFS=$'\t' read -r owner repo; do
        # Skip empty lines and comments
        if [[ -n "$owner" && -n "$repo" && ! "$owner" =~ ^# && ! "$repo" =~ ^# ]]; then
            echo "${owner}/${repo}"
        fi
    done
}

# Configure git with authentication
configure_git() {
    log_info "Configuring git authentication..."
    
    # Configure git to use token authentication
    git config --global credential.helper store
    echo "https://${GITHUB_TOKEN}:x-oauth-basic@github.com" > ~/.git-credentials
    
    # Set basic git config
    git config --global user.name "PlutoSliderServer"
    git config --global user.email "pluto@localhost"
    
    log_success "Git authentication configured"
}

# Synchronize a single repository
sync_repository() {
    local repo_full_name="$1"
    local repo_dir="$REPOS_DIR/${repo_full_name//\//__}"
    local clone_url="https://github.com/${repo_full_name}.git"
    
    log_info "Synchronizing repository: $repo_full_name"
    
    if [[ -d "$repo_dir" ]]; then
        log_info "Repository exists, pulling latest changes..."
        cd "$repo_dir"
        
        # Reset any local changes and pull
        git reset --hard HEAD
        git clean -fd
        git pull origin main || git pull origin master || {
            log_error "Failed to pull repository: $repo_full_name"
            return 1
        }
    else
        log_info "Repository not found, cloning..."
        git clone "$clone_url" "$repo_dir" || {
            log_error "Failed to clone repository: $repo_full_name"
            return 1
        }
    fi
    
    log_success "Successfully synchronized: $repo_full_name"
}

# Synchronize all repositories
sync_repositories() {
    log_info "Starting repository synchronization..."
    log_info "Parsing repository configuration..."
    
    local repos
    repos=$(parse_repos_config)
    
    if [[ -z "$repos" ]]; then
        log_warning "No repositories configured"
        return 0
    fi
    
    log_info "Found repositories to sync:"
    echo "$repos" | while IFS= read -r repo; do
        if [[ -n "$repo" ]]; then
            log_info "  - $repo"
        fi
    done
    
    while IFS= read -r repo; do
        if [[ -n "$repo" ]]; then
            sync_repository "$repo" || {
                log_error "Repository sync failed, stopping startup"
                exit 1
            }
        fi
    done <<< "$repos"
    
    log_success "All repositories synchronized"
}

# Index notebooks from repositories
index_notebooks() {
    log_info "Starting notebook indexing..."
    
    # Clear existing index
    rm -rf "$INDEX_DIR"/*
    
    local notebook_count=0
    
    # Find all Pluto notebooks in notebooks/ subdirectories
    find "$REPOS_DIR" -path "*/notebooks/*.jl" -type f | while read -r notebook_path; do
        # Extract repo name and notebook name
        local rel_path="${notebook_path#$REPOS_DIR/}"
        local repo_name="${rel_path%%/*}"
        local notebook_name=$(basename "$notebook_path")
        
        # Create indexed filename: repo__notebook.jl
        local indexed_name="${repo_name}__${notebook_name}"
        
        # Validate it's a Pluto notebook by checking for required headers
        if grep -q "### A Pluto.jl notebook ###" "$notebook_path" 2>/dev/null; then
            # Create symlink in index directory
            ln -sf "$notebook_path" "$INDEX_DIR/$indexed_name"
            log_info "Indexed notebook: $indexed_name"
            ((notebook_count++))
        else
            log_warning "Skipping non-Pluto notebook: $rel_path"
        fi
    done
    
    log_success "Indexed $notebook_count Pluto notebooks"
}

# Start PlutoSliderServer
start_server() {
    log_info "Starting PlutoSliderServer..."
    log_info "Server will be available at http://$SERVER_HOST:$SERVER_PORT"
    log_info "Serving notebooks from: $INDEX_DIR"
    
    cd "$INDEX_DIR"
    
    # Start PlutoSliderServer with correct API parameters
    exec julia -e "
        using PlutoSliderServer
        
        # Start the server with updated API
        PlutoSliderServer.run_directory(
            \"$INDEX_DIR\";
            SliderServer_host=\"$SERVER_HOST\",
            SliderServer_port=parse(Int, \"$SERVER_PORT\"),
            show_secrets=false,
            init_with_default_pluto_frontend_environment=true
        )
    "
}

# Main execution flow
main() {
    log_info "=== Pluto Slider Server Starting ==="
    log_info "Data directory: $DATA_DIR"
    log_info "Repositories directory: $REPOS_DIR"
    log_info "Index directory: $INDEX_DIR"
    log_info "Config file: $REPOS_CONFIG_PATH"
    
    # Ensure data directories exist
    mkdir -p "$REPOS_DIR" "$INDEX_DIR"
    
    # Execute startup sequence
    validate_environment
    configure_git
    sync_repositories
    index_notebooks
    start_server
}

# Run main function
main "$@"