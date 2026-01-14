#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Config
REPO_URL="https://github.com/qtnx/oh-my-opencode.git"
DEFAULT_BRANCH="dev"
INSTALL_DIR="${OMO_INSTALL_DIR:-$HOME/.local/share/oh-my-opencode}"
PLUGIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/plugin"
OPENCODE_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json"
PLUGIN_NAME="oh-my-opencode.js"

print_banner() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════╗"
    echo "║       Oh-My-OpenCode Local Installer      ║"
    echo "╚═══════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_dependencies() {
    log_info "Checking dependencies..."

    if ! command -v git &> /dev/null; then
        log_error "git is not installed"
        exit 1
    fi

    if ! command -v bun &> /dev/null; then
        log_error "bun is not installed. Install it with: curl -fsSL https://bun.sh/install | bash"
        exit 1
    fi

    log_success "All dependencies are installed"
}

clone_repo() {
    if [ -d "$INSTALL_DIR" ]; then
        log_info "Repository already exists at $INSTALL_DIR"
        return 0
    fi

    log_info "Cloning repository to $INSTALL_DIR..."
    git clone --branch "$DEFAULT_BRANCH" "$REPO_URL" "$INSTALL_DIR"
    log_success "Repository cloned"
}

pull_latest() {
    log_info "Pulling latest changes..."
    cd "$INSTALL_DIR"

    # Stash any local changes
    if [ -n "$(git status --porcelain)" ]; then
        log_warn "Local changes detected, stashing..."
        git stash
    fi

    git fetch origin
    git checkout "$DEFAULT_BRANCH"
    git pull origin "$DEFAULT_BRANCH"

    log_success "Updated to latest version"
}

build_plugin() {
    log_info "Building plugin..."
    cd "$INSTALL_DIR"

    bun install
    bun run build

    log_success "Build completed"
}

link_plugin() {
    log_info "Linking plugin to OpenCode..."

    mkdir -p "$PLUGIN_DIR"

    # Remove existing symlink or file
    if [ -L "$PLUGIN_DIR/$PLUGIN_NAME" ] || [ -f "$PLUGIN_DIR/$PLUGIN_NAME" ]; then
        rm "$PLUGIN_DIR/$PLUGIN_NAME"
    fi

    ln -sf "$INSTALL_DIR/dist/index.js" "$PLUGIN_DIR/$PLUGIN_NAME"

    log_success "Plugin linked: $PLUGIN_DIR/$PLUGIN_NAME -> $INSTALL_DIR/dist/index.js"
}

unlink_plugin() {
    log_info "Unlinking plugin from OpenCode..."

    if [ -L "$PLUGIN_DIR/$PLUGIN_NAME" ]; then
        rm "$PLUGIN_DIR/$PLUGIN_NAME"
        log_success "Plugin unlinked"
    else
        log_warn "Plugin symlink not found"
    fi
}

# Sync config files from repo to user's config directory
sync_config() {
    local CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
    local REPO_CONFIG_DIR="$INSTALL_DIR/config"
    local BACKUP_DIR="$CONFIG_DIR/.backup-$(date +%Y%m%d-%H%M%S)"

    if [ ! -d "$REPO_CONFIG_DIR" ]; then
        log_info "No config directory in repo, skipping config sync"
        return 0
    fi

    log_info "Syncing config files..."
    mkdir -p "$CONFIG_DIR"

    # Merge opencode.json (keep user's custom config, merge shared config)
    if [ -f "$REPO_CONFIG_DIR/opencode.json" ]; then
        if [ -f "$CONFIG_DIR/opencode.json" ]; then
            mkdir -p "$BACKUP_DIR"
            cp "$CONFIG_DIR/opencode.json" "$BACKUP_DIR/opencode.json"
            log_info "Backed up existing opencode.json to $BACKUP_DIR"

            # Merge configs using bun
            log_info "Merging opencode.json configs..."
            bun -e "
const fs = require('fs');

const userPath = '$CONFIG_DIR/opencode.json';
const repoPath = '$REPO_CONFIG_DIR/opencode.json';

try {
    const userConfig = JSON.parse(fs.readFileSync(userPath, 'utf-8'));
    const repoConfig = JSON.parse(fs.readFileSync(repoPath, 'utf-8'));

    // Deep merge function
    function deepMerge(target, source) {
        for (const key in source) {
            if (source[key] && typeof source[key] === 'object' && !Array.isArray(source[key])) {
                target[key] = target[key] || {};
                deepMerge(target[key], source[key]);
            } else if (Array.isArray(source[key])) {
                // For arrays, merge unique values
                target[key] = target[key] || [];
                const existing = new Set(target[key].map(x => typeof x === 'string' ? x : JSON.stringify(x)));
                for (const item of source[key]) {
                    const key = typeof item === 'string' ? item : JSON.stringify(item);
                    if (!existing.has(key)) {
                        target[key].push(item);
                    }
                }
            } else {
                // For primitives, repo config takes precedence (shared config)
                target[key] = source[key];
            }
        }
        return target;
    }

    // Start with user config, merge repo config on top
    // But for 'provider', merge deeply to keep user's custom providers
    const merged = { ...userConfig };

    // Merge plugins (keep user's, add repo's)
    if (repoConfig.plugin) {
        merged.plugin = merged.plugin || [];
        const existingPlugins = new Set(merged.plugin);
        for (const p of repoConfig.plugin) {
            if (!existingPlugins.has(p)) {
                merged.plugin.push(p);
            }
        }
    }

    // Merge MCP servers (keep user's, add repo's)
    if (repoConfig.mcp) {
        merged.mcp = merged.mcp || {};
        for (const [name, config] of Object.entries(repoConfig.mcp)) {
            if (!merged.mcp[name]) {
                merged.mcp[name] = config;
            }
        }
    }

    // Merge agents (keep user's, add repo's)
    if (repoConfig.agent) {
        merged.agent = merged.agent || {};
        for (const [name, config] of Object.entries(repoConfig.agent)) {
            if (!merged.agent[name]) {
                merged.agent[name] = config;
            }
        }
    }

    // Deep merge providers (keep user's custom, add/update repo's)
    if (repoConfig.provider) {
        merged.provider = merged.provider || {};
        for (const [providerName, providerConfig] of Object.entries(repoConfig.provider)) {
            if (!merged.provider[providerName]) {
                merged.provider[providerName] = providerConfig;
            } else {
                // Merge provider options
                if (providerConfig.options) {
                    merged.provider[providerName].options = {
                        ...merged.provider[providerName].options,
                        ...providerConfig.options
                    };
                }
                // Merge models
                if (providerConfig.models) {
                    merged.provider[providerName].models = merged.provider[providerName].models || {};
                    for (const [modelName, modelConfig] of Object.entries(providerConfig.models)) {
                        // Repo models take precedence (shared config)
                        merged.provider[providerName].models[modelName] = modelConfig;
                    }
                }
                // Keep provider name if exists
                if (providerConfig.name && !merged.provider[providerName].name) {
                    merged.provider[providerName].name = providerConfig.name;
                }
            }
        }
    }

    // Keep schema
    if (repoConfig['\$schema']) {
        merged['\$schema'] = repoConfig['\$schema'];
    }

    fs.writeFileSync(userPath, JSON.stringify(merged, null, 2) + '\\n');
    console.log('Merged opencode.json successfully');
} catch (e) {
    console.error('Failed to merge config:', e.message);
    // Fallback: just copy repo config
    fs.copyFileSync(repoPath, userPath);
    console.log('Fallback: copied repo config');
}
"
            log_success "Merged opencode.json"
        else
            cp "$REPO_CONFIG_DIR/opencode.json" "$CONFIG_DIR/opencode.json"
            log_success "Copied opencode.json (no existing config)"
        fi
    fi

    # Backup and copy AGENTS.md (always overwrite - shared agents)
    if [ -f "$REPO_CONFIG_DIR/AGENTS.md" ]; then
        if [ -f "$CONFIG_DIR/AGENTS.md" ]; then
            mkdir -p "$BACKUP_DIR"
            cp "$CONFIG_DIR/AGENTS.md" "$BACKUP_DIR/AGENTS.md"
            log_info "Backed up existing AGENTS.md to $BACKUP_DIR"
        fi
        cp "$REPO_CONFIG_DIR/AGENTS.md" "$CONFIG_DIR/AGENTS.md"
        log_success "Synced AGENTS.md"
    fi

    log_success "Config sync completed"
}

# Clean oh-my-opencode entries from opencode.json plugin array
clean_opencode_config() {
    if [ ! -f "$OPENCODE_CONFIG" ]; then
        log_info "No opencode.json found, skipping config cleanup"
        return 0
    fi

    log_info "Checking opencode.json for old plugin entries..."

    # Check if file contains oh-my-opencode in plugin array
    if ! grep -q "oh-my-opencode" "$OPENCODE_CONFIG" 2>/dev/null; then
        log_info "No oh-my-opencode entries found in config"
        return 0
    fi

    # Use node/bun to safely modify JSON
    if command -v bun &> /dev/null; then
        log_info "Removing old oh-my-opencode plugin entries from opencode.json..."

        bun -e "
const fs = require('fs');
const configPath = '$OPENCODE_CONFIG';

try {
    const content = fs.readFileSync(configPath, 'utf-8');
    const config = JSON.parse(content);

    if (config.plugin && Array.isArray(config.plugin)) {
        const originalLength = config.plugin.length;
        config.plugin = config.plugin.filter(p => {
            if (typeof p !== 'string') return true;
            // Remove entries containing oh-my-opencode
            return !p.includes('oh-my-opencode');
        });

        const removed = originalLength - config.plugin.length;
        if (removed > 0) {
            fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n');
            console.log('Removed ' + removed + ' oh-my-opencode plugin entries');
        }
    }
} catch (e) {
    console.error('Failed to clean config:', e.message);
    process.exit(1);
}
"
        log_success "Config cleaned"
    else
        log_warn "bun not available for JSON manipulation, please manually remove oh-my-opencode from opencode.json plugin array"
    fi
}

show_status() {
    echo ""
    echo -e "${BLUE}=== Status ===${NC}"

    if [ -d "$INSTALL_DIR" ]; then
        echo -e "Install directory: ${GREEN}$INSTALL_DIR${NC}"
        cd "$INSTALL_DIR"
        echo -e "Current branch: ${GREEN}$(git branch --show-current)${NC}"
        echo -e "Current commit: ${GREEN}$(git log -1 --format='%h %s')${NC}"

        # Check for updates
        git fetch origin --quiet 2>/dev/null || true
        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse origin/$DEFAULT_BRANCH 2>/dev/null || echo "$LOCAL")
        if [ "$LOCAL" != "$REMOTE" ]; then
            echo -e "Updates available: ${YELLOW}Yes${NC} (run script again to update)"
        else
            echo -e "Updates available: ${GREEN}No${NC}"
        fi
    else
        echo -e "Install directory: ${RED}Not installed${NC}"
    fi

    if [ -L "$PLUGIN_DIR/$PLUGIN_NAME" ]; then
        echo -e "Plugin symlink: ${GREEN}$PLUGIN_DIR/$PLUGIN_NAME${NC}"
    else
        echo -e "Plugin symlink: ${RED}Not linked${NC}"
    fi

    echo ""
}

# Auto install or update
cmd_auto() {
    print_banner
    check_dependencies

    if [ -d "$INSTALL_DIR" ]; then
        log_info "Existing installation found, updating..."
        pull_latest
    else
        log_info "No installation found, installing..."
        clone_repo
    fi

    build_plugin
    link_plugin
    sync_config
    clean_opencode_config
    show_status

    echo -e "${GREEN}Done! Restart OpenCode to apply changes.${NC}"
}

cmd_install() {
    print_banner
    check_dependencies
    clone_repo
    build_plugin
    link_plugin
    sync_config
    clean_opencode_config
    show_status

    echo -e "${GREEN}Installation complete! Restart OpenCode to apply changes.${NC}"
}

cmd_update() {
    print_banner

    if [ ! -d "$INSTALL_DIR" ]; then
        log_warn "Plugin not installed, running install instead..."
        cmd_install
        return
    fi

    pull_latest
    build_plugin
    link_plugin
    sync_config
    clean_opencode_config
    show_status

    echo -e "${GREEN}Update complete! Restart OpenCode to apply changes.${NC}"
}

cmd_uninstall() {
    print_banner

    unlink_plugin

    if [ -d "$INSTALL_DIR" ]; then
        read -p "Remove source directory ($INSTALL_DIR)? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$INSTALL_DIR"
            log_success "Source directory removed"
        fi
    fi

    log_success "Uninstall complete"
}

cmd_rebuild() {
    print_banner

    if [ ! -d "$INSTALL_DIR" ]; then
        log_error "Plugin not installed. Run script without arguments to install."
        exit 1
    fi

    build_plugin
    show_status

    echo -e "${GREEN}Rebuild complete! Restart OpenCode to apply changes.${NC}"
}

cmd_help() {
    print_banner
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  (none)     Auto install or update (recommended)"
    echo "  install    Force fresh install"
    echo "  update     Force update (pull + rebuild)"
    echo "  rebuild    Rebuild without pulling (for local changes)"
    echo "  uninstall  Remove plugin symlink and optionally source"
    echo "  status     Show current installation status"
    echo "  help       Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  OMO_INSTALL_DIR  Override install directory (default: ~/.local/share/oh-my-opencode)"
    echo ""
    echo "Examples:"
    echo "  # Install or update (one command for everything)"
    echo "  curl -fsSL https://raw.githubusercontent.com/qtnx/oh-my-opencode/refs/heads/dev/script/install-local.sh | bash"
    echo ""
}

# Main
case "${1:-}" in
    install)
        cmd_install
        ;;
    update)
        cmd_update
        ;;
    rebuild)
        cmd_rebuild
        ;;
    uninstall)
        cmd_uninstall
        ;;
    status)
        print_banner
        show_status
        ;;
    help|--help|-h)
        cmd_help
        ;;
    "")
        # Default: auto install or update
        cmd_auto
        ;;
    *)
        log_error "Unknown command: $1"
        cmd_help
        exit 1
        ;;
esac
