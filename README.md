# Pluto Slider Server Infrastructure

A **public, declarative infrastructure repository** that deploys a PlutoSliderServer as a Dockerized service. The service pulls Pluto notebooks from private GitHub repositories using a locally supplied token, indexes them deterministically, and serves them via PlutoSliderServer.

## 🎯 Problem Statement

Build a public infrastructure repository that allows an operator to deploy a PlutoSliderServer on any Linux VM with Docker by cloning the repo, providing a GitHub access token locally, and running `docker compose up`, after which the server automatically fetches Pluto notebooks from configured GitHub repositories and serves them via PlutoSliderServer.

## 🚫 Explicit Non-Goals

This project **does NOT**:

- Manage notebook source code
- Manage per-repo Julia environments  
- Provide authentication to end users
- Expose services publicly on the internet
- Handle CI/CD for notebook repos

## 🏗️ System Architecture

### Components

1. **Docker Image**: Contains Julia + Pluto + PlutoSliderServer + git (stateless)
2. **Runtime Volume**: Stores cloned repositories and generated notebook index 
3. **Startup Script**: Syncs Git repositories, builds notebook index, launches PlutoSliderServer
4. **Configuration Files**: `repos.yaml` (declarative repo list) and `.env` (runtime secrets)

### Directory Structure

```
pluto-slider-infra/
├── docker/
│   ├── Dockerfile              # Multi-stage build with Julia ecosystem
│   └── entrypoint.sh           # Startup orchestration script
├── config/
│   └── repos.yaml              # Repository configuration
├── docker-compose.yml          # Service orchestration
├── .env.example               # Environment template
└── README.md                  # This file
```

### Notebook Repository Contract

Every notebook repository **must** follow this structure:

```
<repo-root>/
└── notebooks/
    ├── *.jl   # Valid Pluto notebooks only
```

Only files matching `<repo>/notebooks/*.jl` will be discovered and served.

## 🚀 Quick Start (Operator Workflow)

### Prerequisites

- Linux VM with Docker and Docker Compose installed
- GitHub Personal Access Token with repo access
- Network access to GitHub

### Deployment Steps

```bash
# 1. Clone this infrastructure repository
git clone https://github.com/AV-BD/pluto_slider_deploy.git
cd pluto_slider_deploy

# 2. Configure your repositories
# Edit config/repos.yaml to list your notebook repositories

# 3. Set up authentication
cp .env.example .env
# Edit .env and add your GitHub token:
# GITHUB_TOKEN=your_personal_access_token_here

# 4. Deploy the service
docker compose up -d

# 5. Access your notebooks
# PlutoSliderServer will be available at: http://VM-IP:2345
```

That's it! The system will:
- Build the Docker image with Julia and dependencies
- Clone/sync all configured repositories  
- Index Pluto notebooks from `notebooks/` directories
- Start PlutoSliderServer serving the indexed notebooks

## ⚙️ Configuration

### Repository Configuration (`config/repos.yaml`)

```yaml
repositories:
  - owner: your-github-username
    repo: my-pluto-notebooks
  - owner: your-organization  
    repo: data-analysis-notebooks
```

### Environment Variables (`.env`)

```bash
# Required: GitHub Personal Access Token
GITHUB_TOKEN=your_personal_access_token_here

# Optional overrides (defaults shown)
SERVER_PORT=2345
SERVER_HOST=0.0.0.0
```

### GitHub Token Permissions

Your token needs:
- **`repo`** scope for private repositories
- **`public_repo`** scope for public repositories only

Generate at: [https://github.com/settings/tokens](https://github.com/settings/tokens)

## 📖 How It Works

### Startup Sequence

1. **Environment Validation**: Checks for GitHub token and config file
2. **Repository Sync**: Clones missing repos, pulls updates for existing ones
3. **Notebook Discovery**: Finds all `*.jl` files in `notebooks/` subdirectories
4. **Index Generation**: Creates flat structure `<repo>__<notebook>.jl`
5. **Server Launch**: Starts PlutoSliderServer serving the index directory

### Notebook Indexing

Repositories are indexed using this pattern:

```
Input:  owner/repo-name/notebooks/analysis.jl
Output: owner__repo-name__analysis.jl
```

This creates a flat namespace where all notebooks are accessible through the PlutoSliderServer interface.

### Persistence

- **Repository data**: Persists in Docker volume across restarts
- **Configuration**: Mounted from host file system
- **Secrets**: Injected at runtime, never stored

## 🔧 Management

### View Logs

```bash
docker compose logs -f pluto-slider-server
```

### Restart Service

```bash
docker compose restart pluto-slider-server
```

### Update Repositories

```bash
# Restart triggers fresh sync
docker compose restart pluto-slider-server
```

### Add New Repository

```bash
# 1. Edit config/repos.yaml
# 2. Restart service
docker compose restart pluto-slider-server
```

### Clean Deployment

```bash
# Remove everything and redeploy
docker compose down -v
docker compose up -d
```

## 🔒 Security

- **Public Repository**: No secrets committed to version control
- **Runtime Injection**: Secrets provided via environment variables  
- **Read-Only Access**: GitHub token only needs read permissions
- **Container Isolation**: Runs with non-root user and security restrictions
- **Minimal Privileges**: Only required capabilities enabled

## 🚨 Troubleshooting

### Service Won't Start

```bash
# Check logs for detailed error messages
docker compose logs pluto-slider-server

# Common issues:
# - Invalid GitHub token
# - Missing repos.yaml file  
# - Network connectivity to GitHub
# - Insufficient token permissions
```

### No Notebooks Visible

```bash
# Verify repository structure
docker compose exec pluto-slider-server ls -la /app/data/repos/

# Check indexing output
docker compose logs pluto-slider-server | grep -i index

# Ensure notebooks/ directory exists and contains *.jl files
# Verify files have Pluto headers: ### A Pluto.jl notebook ###
```

### Access Issues

```bash
# Verify service is running
docker compose ps

# Check port binding
curl http://localhost:2345

# Verify firewall allows port 2345
```

## 📊 Monitoring

### Health Check

The service includes a health check endpoint:

```bash
curl http://VM-IP:2345/health
```

### Resource Usage

```bash
# View resource consumption
docker stats pluto-slider-server
```

### Storage Usage

```bash
# Check volume usage
docker system df -v
```

## 🔄 Disaster Recovery

### Complete VM Loss

```bash
# On new VM:
git clone https://github.com/AV-BD/pluto_slider_deploy.git
cd pluto_slider_deploy
cp .env.example .env
# Add your GitHub token to .env
docker compose up -d
```

The system will automatically:
1. Rebuild the Docker image
2. Re-clone all repositories
3. Regenerate the notebook index
4. Start serving notebooks

**Recovery time**: ~5-10 minutes depending on repository sizes.

### Partial Data Loss

```bash
# Clear and rebuild data volume
docker compose down -v
docker compose up -d
```

## 🧪 Development

### Local Testing

```bash
# Build image locally
docker compose build

# Run with debug output
docker compose up

# Access container for debugging  
docker compose exec pluto-slider-server bash
```

### Adding Features

1. Modify [docker/Dockerfile](docker/Dockerfile) for image changes
2. Modify [docker/entrypoint.sh](docker/entrypoint.sh) for runtime logic
3. Test with `docker compose build && docker compose up`

## 📋 System Requirements

### Host Requirements

- **OS**: Linux with Docker support
- **Docker**: Version 20.10+ with Compose V2
- **Memory**: 2GB+ available for container
- **Storage**: 10GB+ for repositories and Julia packages
- **Network**: HTTPS access to github.com

### Repository Requirements

- Git repository accessible with provided token
- `notebooks/` directory containing `*.jl` files
- Valid Pluto notebook format (contains `### A Pluto.jl notebook ###`)

## 🤝 Contributing

1. Fork this repository
2. Create a feature branch
3. Test changes with sample notebook repositories
4. Submit a pull request

## 📄 License

This infrastructure code is provided as-is for deploying PlutoSliderServer instances.

---

## ✅ Acceptance Criteria

This project is **complete** when:

- ✅ A fresh VM can run PlutoSliderServer by following the operator workflow
- ✅ Notebooks from private repos appear automatically  
- ✅ Repo updates are reflected after restart
- ✅ No secrets exist in the public repo
- ✅ No Julia exists on the host

**System Status**: Ready for production deployment 🚀