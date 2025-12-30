#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# install-gemini-config.sh
# - Installs ~/.gemini/GEMINI.md and ~/.gemini/settings.json
# - Prompts user to enter API keys interactively (no hardcoded secrets)
# - Exports keys to current session, and optionally persists them to a shell rc file
# - Creates timestamped backups if files already exist
# =============================================================================

# ---------- Helpers ----------
info()  { printf '%s\n' "[INFO]  $*"; }
warn()  { printf '%s\n' "[WARN]  $*" >&2; }
error() { printf '%s\n' "[ERROR] $*" >&2; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    error "Missing required command: $1"
    return 1
  }
}

timestamp() { date +"%Y%m%d-%H%M%S"; }

backup_if_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    local bak="${path}.bak.$(timestamp)"
    cp -a "$path" "$bak"
    info "Backed up existing file: $path -> $bak"
  fi
}

prompt_secret() {
  # Usage: prompt_secret VAR_NAME "Human prompt"
  local var_name="$1"
  local prompt="$2"
  local value=""
  while true; do
    printf "%s" "$prompt"
    # -s: silent, -r: raw
    IFS= read -r -s value
    printf "\n"
    if [[ -n "$value" ]]; then
      # Basic confirmation (without revealing the full key)
      local last4="${value: -4}"
      info "Captured value for $var_name (last 4 chars: ****${last4})"
      printf "Confirm this is correct? (y/N): "
      local yn=""
      IFS= read -r yn
      case "${yn:-N}" in
        y|Y) break ;;
        *) warn "Re-enter $var_name." ;;
      esac
    else
      warn "Empty input. Please enter a value."
    fi
  done

  # shellcheck disable=SC2163
  export "$var_name=$value"
}

append_exports_to_rc() {
  local rc="$1"
  info "Persisting exports to: $rc"
  {
    printf "\n# Added by install-gemini-config.sh on %s\n" "$(date)"
    printf "export EXA_API_KEY=%q\n" "${EXA_API_KEY}"
    printf "export CONTEXT7_API_KEY=%q\n" "${CONTEXT7_API_KEY}"
    printf "export BRAVE_API_KEY=%q\n" "${BRAVE_API_KEY}"
  } >> "$rc"
}

# ---------- Preconditions ----------
info "Starting Gemini CLI config installation..."

need_cmd mkdir
need_cmd cp
need_cmd date
need_cmd printf
need_cmd cat

# Optional checks (not hard requirements for writing config files)
if ! command -v node >/dev/null 2>&1; then
  warn "node not found. If you plan to use MCP servers via npx, install Node.js first."
fi
if ! command -v npx >/dev/null 2>&1; then
  warn "npx not found. If you plan to use MCP servers via npx, install npm/node tooling first."
fi

# ---------- Paths ----------
GEMINI_DIR="${HOME}/.gemini"
GEMINI_MD="${GEMINI_DIR}/GEMINI.md"
SETTINGS_JSON="${GEMINI_DIR}/settings.json"

mkdir -p "$GEMINI_DIR"
info "Ensured directory exists: $GEMINI_DIR"

backup_if_exists "$GEMINI_MD"
backup_if_exists "$SETTINGS_JSON"

# ---------- Prompt for API keys (user enters them during install) ----------
info "API key setup (you will enter keys now; input is hidden)."
prompt_secret "EXA_API_KEY"      "Enter EXA_API_KEY: "
prompt_secret "CONTEXT7_API_KEY" "Enter CONTEXT7_API_KEY: "
prompt_secret "BRAVE_API_KEY"    "Enter BRAVE_API_KEY: "

# Exported to current session already by prompt_secret via `export`.
info "API keys are exported for this session."

# ---------- Optionally persist exports ----------
printf "Do you want to persist these exports to a shell rc file for future sessions? (y/N): "
persist=""
IFS= read -r persist
if [[ "${persist:-N}" =~ ^[yY]$ ]]; then
  # Choose the rc file. Prefer existing; otherwise propose common defaults.
  candidates=(
    "${HOME}/.bashrc"
    "${HOME}/.zshrc"
    "${HOME}/.profile"
  )

  chosen_rc=""
  for f in "${candidates[@]}"; do
    if [[ -f "$f" ]]; then
      chosen_rc="$f"
      break
    fi
  done

  if [[ -z "$chosen_rc" ]]; then
    # Default to .bashrc if none exist
    chosen_rc="${HOME}/.bashrc"
    warn "No existing rc file found. Will create: $chosen_rc"
  fi

  info "Default rc file: $chosen_rc"
  printf "Use this rc file? %s (Y/n): " "$chosen_rc"
  yn=""
  IFS= read -r yn
  if [[ "${yn:-Y}" =~ ^[nN]$ ]]; then
    printf "Enter full path to rc file (e.g., %s/.bashrc): " "$HOME"
    IFS= read -r chosen_rc
    if [[ -z "$chosen_rc" ]]; then
      warn "Empty path provided; skipping persistence."
      chosen_rc=""
    fi
  fi

  if [[ -n "$chosen_rc" ]]; then
    append_exports_to_rc "$chosen_rc"
    info "Done. Open a new shell or run: source \"$chosen_rc\""
  fi
else
  info "Skipping persistence. Keys will remain only in the current session."
fi

# ---------- Write GEMINI.md (Gemini 3 focused) ----------
cat > "$GEMINI_MD" <<'EOF'
# GEMINI.md — Gemini 3 Only Policy

## 0) Session Startup Requirement (Gemini CLI)
This workspace must run on Gemini 3.

Before any serious work:
1) In Gemini CLI run: `/settings` → set **Preview Features = true**
2) Run: `/model` → choose **Auto (Gemini 3)** OR **Manual → gemini-3-pro-preview / gemini-3-flash-preview**

If the active model is not Gemini 3, instruct the user to switch via `/model` and proceed only after that.

> Note: `/model` / `--model` may not override sub-agent models; keep outputs verifiable and do not assume all internal steps used the same model.

---

## Purpose
You are a professional assistant for analysis, strategy, research, technical troubleshooting, and documentation.
Primary objectives:
- Correct, verifiable, and operationally useful outputs
- Deep internal reasoning with concise, auditable external explanations

---

## Non-Negotiables
1) **Truthfulness & Verifiability**
   - Separate facts vs. inference
   - If uncertain, say so and specify what to verify
   - For numbers: show checkable calculations (succinct but complete)

2) **No Raw Chain-of-Thought Disclosure**
   - You may think deeply internally
   - Do NOT reveal raw step-by-step private reasoning
   - Instead provide a **Reasoning Summary** (assumptions, basis, high-level logic, checks, risks)

3) **Actionable Outputs**
   - Every response must include concrete next actions: steps, checklist, commands, templates, or options with trade-offs

4) **Security & Privacy**
   - Never expose API keys/tokens/passwords
   - If sensitive data appears in files, summarize safely without leaking secrets
   - Access only what is necessary

5) **Minimal Clarifying Questions**
   - Default to reasonable assumptions and proceed
   - Ask only when the missing detail materially changes the answer

---

## Default Response Format (Thai, Professional)
### 1) แผนการทำงาน (สั้น)
- 3–6 ขั้นตอนที่กำลังจะทำ

### 2) Executive Summary
- สรุปคำตอบ/ข้อเสนอหลัก 3–7 บรรทัด

### 3) Critical Analysis
- ประเด็นสำคัญ, เงื่อนไข, trade-offs, ความเสี่ยง, ข้อจำกัด
- ถ้ามีหลายทางเลือก: Option A/B/C พร้อมข้อดีข้อเสีย

### 4) Reasoning Summary (No Raw CoT)
- Key assumptions
- Evidence / basis
- Logical approach (high-level)
- Checks & validations
- Risks & mitigations

### 5) Recommendations / Next Actions
- รายการสิ่งที่ทำต่อได้ทันที

---

## Model Usage Guidance (Gemini 3 Family)
- Prefer **gemini-3-pro-preview** for:
  - multi-step reasoning, architecture, deep debugging, complex planning
- Prefer **gemini-3-flash-preview** for:
  - quick transformations, summarization, simple Q&A, rapid iteration
- If the user asks for “Gemini 3 only,” do not suggest Gemini 2.5 fallback; instead propose:
  - Manual selection of a Gemini 3 model, or
  - Auto (Gemini 3) routing

---

## Tooling & MCP (if available)
- Use tools only when they improve accuracy or enable real work (e.g., filesystem ops, search)
- Cite sources when using external info
- Never leak secrets from env/files

---

## Quality Gates (Pre-Send Checklist)
- [ ] Answer matches the user request
- [ ] Facts vs inference clearly separated
- [ ] Includes Reasoning Summary (no raw CoT)
- [ ] Calculations are checkable
- [ ] Has actionable next steps
- [ ] No secrets or sensitive data leaked
EOF

info "Wrote: $GEMINI_MD"

# ---------- Write settings.json (as provided) ----------
# NOTE: env values reference environment variables; user provided keys are exported above.
#       You can also persist exports to rc file via the prompt earlier.
cat > "$SETTINGS_JSON" <<'EOF'
{
  "general": {
    "previewFeatures": true
  },

  "context": {
    "fileName": ["GEMINI.md"],
    "includeDirectories": ["~/.gemini"],
    "loadMemoryFromIncludeDirectories": true
  },

  "mcpServers": {
    "exa": {
      "command": "npx",
      "args": ["-y", "exa-mcp-server"],
      "env": {
        "EXA_API_KEY": "$EXA_API_KEY"
      }
    },
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"],
      "env": {
        "CONTEXT7_API_KEY": "$CONTEXT7_API_KEY"
      }
    },
    "brave-search": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-brave-search"],
      "env": {
        "BRAVE_API_KEY": "$BRAVE_API_KEY"
      }
    },
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/storage/emulated/0/sandbox",
        "/data/data/com.termux/files/home/.gemini"
      ]
    }
  },

  "modelConfigs": {
    "customOverrides": [
      {
        "match": { "model": "gemini-3-pro-preview" },
        "modelConfig": {
          "generateContentConfig": {
            "temperature": 0.2,
            "topP": 0.95,
            "maxOutputTokens": 65535,
            "thinkingConfig": {
              "thinkingLevel": "HIGH",
              "includeThoughts": true
            }
          }
        }
      },
      {
        "match": { "model": "gemini-3-flash-preview" },
        "modelConfig": {
          "generateContentConfig": {
            "temperature": 0.2,
            "topP": 0.95,
            "maxOutputTokens": 65535,
            "thinkingConfig": {
              "thinkingLevel": "HIGH",
              "includeThoughts": true
            }
          }
        }
      },

      {
        "match": { "model": "gemini-2.5-pro" },
        "modelConfig": {
          "generateContentConfig": {
            "temperature": 0.2,
            "topP": 0.95,
            "maxOutputTokens": 65535,
            "thinkingConfig": {
              "thinkingBudget": 32768,
              "includeThoughts": true
            }
          }
        }
      },
      {
        "match": { "model": "gemini-2.5-flash" },
        "modelConfig": {
          "generateContentConfig": {
            "temperature": 0.2,
            "topP": 0.95,
            "maxOutputTokens": 65535,
            "thinkingConfig": {
              "thinkingBudget": 24576,
              "includeThoughts": true
            }
          }
        }
      },
      {
        "match": { "model": "gemini-2.5-flash-preview-09-2025" },
        "modelConfig": {
          "generateContentConfig": {
            "temperature": 0.2,
            "topP": 0.95,
            "maxOutputTokens": 65535,
            "thinkingConfig": {
              "thinkingBudget": 24576,
              "includeThoughts": true
            }
          }
        }
      },
      {
        "match": { "model": "gemini-2.5-flash-lite" },
        "modelConfig": {
          "generateContentConfig": {
            "temperature": 0.2,
            "topP": 0.95,
            "maxOutputTokens": 65535,
            "thinkingConfig": {
              "thinkingBudget": 24576,
              "includeThoughts": true
            }
          }
        }
      },
      {
        "match": { "model": "gemini-2.5-flash-lite-preview-09-2025" },
        "modelConfig": {
          "generateContentConfig": {
            "temperature": 0.2,
            "topP": 0.95,
            "maxOutputTokens": 65535,
            "thinkingConfig": {
              "thinkingBudget": 24576,
              "includeThoughts": true
            }
          }
        }
      }
    ]
  }
}
EOF

info "Wrote: $SETTINGS_JSON"

# ---------- Post-install notes ----------
cat <<EOF

[OK] Installation complete.

Files installed:
- $GEMINI_MD
- $SETTINGS_JSON

Next steps (Gemini CLI):
1) Open Gemini CLI
2) Run: /settings   (confirm Preview Features = true)
3) Run: /model      (choose Auto (Gemini 3) or Manual gemini-3-pro-preview)

Notes:
- MCP servers use npx. Ensure Node.js + npx are installed if you plan to use them.
- API keys were exported for this session. If you chose persistence, they were appended to your rc file.

EOF
