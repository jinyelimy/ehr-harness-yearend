#!/usr/bin/env bash
# scripts/install-all.sh
# Bash equivalent of install-all.ps1 for macOS/Linux users.
# Configures both Claude Code and Codex CLI to use this repo's yearend harness.
#
# Usage:
#   scripts/install-all.sh                                # default ClaudeHome=~/.claude, CodexHome=~/.codex
#   scripts/install-all.sh --claude-home <path>           # override Claude home
#   scripts/install-all.sh --codex-home <path>            # override Codex home
#   scripts/install-all.sh --skip-claude                  # only configure Codex
#   scripts/install-all.sh --skip-codex                   # only configure Claude
#   scripts/install-all.sh --dry-run                      # print actions without writing
#
# Requires: bash, python3 (for idempotent JSON/TOML edits).

set -euo pipefail

MARKETPLACE_NAME="ehr-harness-yearend"
PLUGIN_NAME="ehr-yearend-harness"
PLUGIN_KEY="${PLUGIN_NAME}@${MARKETPLACE_NAME}"

CLAUDE_HOME="${HOME}/.claude"
CODEX_HOME="${HOME}/.codex"
SKIP_CLAUDE=0
SKIP_CODEX=0
DRY_RUN=0
REPO_ROOT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --claude-home) CLAUDE_HOME="$2"; shift 2 ;;
        --codex-home)  CODEX_HOME="$2";  shift 2 ;;
        --repo-root)   REPO_ROOT="$2";   shift 2 ;;
        --skip-claude) SKIP_CLAUDE=1;    shift ;;
        --skip-codex)  SKIP_CODEX=1;     shift ;;
        --dry-run)     DRY_RUN=1;        shift ;;
        *) echo "Unknown argument: $1" >&2; exit 64 ;;
    esac
done

if [[ -z "$REPO_ROOT" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required but not found in PATH" >&2
    exit 1
fi

step() { echo "[ehr-yearend] $*"; }

# Verify repo shape early — same checks as the PowerShell installer.
required_paths=(
    ".claude-plugin/marketplace.json"
    ".agents/plugins/marketplace.json"
    "plugins/${PLUGIN_NAME}/.claude-plugin/plugin.json"
    "plugins/${PLUGIN_NAME}/.codex-plugin/plugin.json"
    "plugins/${PLUGIN_NAME}/skills"
    "plugins/${PLUGIN_NAME}/hooks"
    "plugins/${PLUGIN_NAME}/references"
)
for rel in "${required_paths[@]}"; do
    if [[ ! -e "${REPO_ROOT}/${rel}" ]]; then
        echo "Missing required harness file or directory: ${rel}" >&2
        exit 1
    fi
done

step "Repo root: ${REPO_ROOT}"

PLUGIN_VERSION="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1], encoding='utf-8'))['version'])" "${REPO_ROOT}/plugins/${PLUGIN_NAME}/.claude-plugin/plugin.json")"

GIT_REMOTE=""
GIT_SHA=""
if command -v git >/dev/null 2>&1; then
    GIT_REMOTE="$(git -C "$REPO_ROOT" config --get remote.origin.url 2>/dev/null || true)"
    GIT_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || true)"
fi

NOW_UTC="$(date -u +'%Y-%m-%dT%H:%M:%S.000Z')"
NOW_UTC_TOML="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

install_claude() {
    step "Configuring Claude plugin marketplace and cache"

    local plugins_root="${CLAUDE_HOME}/plugins"
    local cache_root="${plugins_root}/cache"
    local cache_install="${cache_root}/${MARKETPLACE_NAME}/${PLUGIN_NAME}/${PLUGIN_VERSION}"
    local source_src="${REPO_ROOT}/plugins/${PLUGIN_NAME}"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        step "(dry-run) would copy ${source_src} -> ${cache_install}"
    else
        mkdir -p "$cache_root"
        rm -rf "$cache_install"
        mkdir -p "$cache_install"
        cp -R "${source_src}/." "${cache_install}/"
    fi

    # Use python to update three JSON files idempotently.
    python3 - "$CLAUDE_HOME" "$REPO_ROOT" "$MARKETPLACE_NAME" "$PLUGIN_KEY" "$PLUGIN_VERSION" "$cache_install" "$NOW_UTC" "$GIT_REMOTE" "$GIT_SHA" "$DRY_RUN" <<'PY'
import json, os, sys
from pathlib import Path

claude_home, repo_root, marketplace, plugin_key, version, cache_install, now, remote, sha, dry_run_s = sys.argv[1:11]
dry_run = dry_run_s == "1"
plugins_root = Path(claude_home) / "plugins"

if remote:
    source = {"source": "git", "url": remote}
else:
    source = {"source": "local", "path": repo_root}

def load(p, default):
    p = Path(p)
    if p.exists() and p.read_text(encoding="utf-8").strip():
        return json.loads(p.read_text(encoding="utf-8"))
    return default

def save(p, value):
    if dry_run:
        return
    p = Path(p)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

# known_marketplaces.json
known_path = plugins_root / "known_marketplaces.json"
known = load(known_path, {})
known[marketplace] = {
    "source": source,
    "installLocation": repo_root,
    "lastUpdated": now,
}
save(known_path, known)

# settings.json (user-level)
settings_path = Path(claude_home) / "settings.json"
settings = load(settings_path, {})
settings.setdefault("enabledPlugins", {})[plugin_key] = True
settings.setdefault("extraKnownMarketplaces", {})[marketplace] = {"source": source}
save(settings_path, settings)

# installed_plugins.json
installed_path = plugins_root / "installed_plugins.json"
installed = load(installed_path, {"version": 2, "plugins": {}})
installed.setdefault("version", 2)
installed.setdefault("plugins", {})
entry = {
    "scope": "user",
    "installPath": cache_install,
    "version": version,
    "installedAt": now,
    "lastUpdated": now,
}
if sha:
    entry["gitCommitSha"] = sha
installed["plugins"][plugin_key] = [entry]
save(installed_path, installed)
PY

    step "Claude ready: ${PLUGIN_KEY} (${PLUGIN_VERSION})"
}

install_codex() {
    step "Configuring Codex marketplace, plugin, and hooks feature"

    if [[ "$DRY_RUN" -eq 0 ]]; then
        mkdir -p "$CODEX_HOME"
    fi

    local config_path="${CODEX_HOME}/config.toml"

    if [[ -f "$config_path" && "$DRY_RUN" -eq 0 ]]; then
        cp "$config_path" "${config_path}.bak-ehr-yearend-$(date +%Y%m%d%H%M%S)"
    fi

    python3 - "$config_path" "$MARKETPLACE_NAME" "$PLUGIN_KEY" "$REPO_ROOT" "$NOW_UTC_TOML" "$DRY_RUN" <<'PY'
import re, sys
from pathlib import Path

config_path, marketplace, plugin_key, repo_root, now, dry_run_s = sys.argv[1:7]
dry_run = dry_run_s == "1"
p = Path(config_path)
content = p.read_text(encoding="utf-8") if p.exists() else ""

def set_feature(text, name, value):
    line = f"{name} = {'true' if value else 'false'}"
    m = re.search(r"(?ms)^\[features\]\s*\r?\n(?P<body>.*?)(?=^\[|\Z)", text)
    if not m:
        prefix = text.rstrip()
        if prefix:
            prefix += "\n\n"
        return prefix + "[features]\n" + line + "\n"
    block = m.group(0).rstrip()
    if re.search(rf"(?m)^{re.escape(name)}\s*=", block):
        new_block = re.sub(rf"(?m)^{re.escape(name)}\s*=.*$", line, block)
    else:
        new_block = block + "\n" + line
    return text[:m.start()] + new_block + "\n" + text[m.end():]

def remove_table(text, header):
    pat = rf"(?ms)^{re.escape(header)}\s*\r?\n.*?(?=^\[|\Z)"
    return re.sub(pat, "", text)

content = set_feature(content, "codex_hooks", True)
content = remove_table(content, f"[marketplaces.{marketplace}]")
content = remove_table(content, f'[plugins."{plugin_key}"]')

repo_literal = repo_root.replace("'", "''")
append = (
    f"[marketplaces.{marketplace}]\n"
    f'last_updated = "{now}"\n'
    f'source_type = "local"\n'
    f"source = '{repo_literal}'\n"
    "\n"
    f'[plugins."{plugin_key}"]\n'
    "enabled = true\n"
)

new_content = content.rstrip() + "\n\n" + append + "\n"
if not dry_run:
    p.write_text(new_content, encoding="utf-8")
PY

    step "Codex ready: ${PLUGIN_KEY} with codex_hooks = true"
}

if [[ "$SKIP_CLAUDE" -eq 0 ]]; then
    install_claude
fi

if [[ "$SKIP_CODEX" -eq 0 ]]; then
    install_codex
fi

step "Done. Restart Claude Code and Codex so both runtimes reload plugin metadata."
