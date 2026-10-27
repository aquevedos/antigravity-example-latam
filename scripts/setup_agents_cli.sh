#!/usr/bin/env bash
# Copyright 2026 Google LLC
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# Google Agents CLI (ADK) — Instalador y Onboarding Automatizado (Español)
# Taller: Cymbal Group Sales Ops & Gobernanza Comercial (antigravity-example-latam)
# ==============================================================================
# Verifica y configura automáticamente en Google Cloud Shell, Linux y macOS:
#   1. Herramientas base (curl, git, python3 >= 3.11)
#   2. uv / uvx (gestor ultrarrápido de paquetes y herramientas Python)
#   3. Node.js / npx (opcional para 'npx skills add')
#   4. Google Cloud CLI (gcloud) + Terraform (para IaC declarativo)
#   5. Protección NO_GCE_CHECK=true fuera de GCE y UV_NO_CONFIG=1 para Cloud Build
#   6. Utilidad global 'agents-cli-env' en ~/.local/bin
#   7. Última versión de 'google-agents-cli' + soporte MCP + skill del taller
#
# Uso:
#   # Opción 1 (Desde el repositorio clonado / Cloud Shell):
#   bash scripts/setup_agents_cli.sh [--project PROJECT_ID] [--region global] [--api-key CLAVE] [--non-interactive]
#   # Opción 2 (En 1 línea vía curl — requiere que el repositorio en GitHub sea Public):
#   bash <(curl -fsSL https://raw.githubusercontent.com/aquevedos/antigravity-example-latam/main/scripts/setup_agents_cli.sh)
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}▸${NC} $*"; }
log_ok()    { echo -e "${GREEN}✓${NC} $*"; }
log_warn()  { echo -e "${YELLOW}⚠️  Aviso:${NC} $*"; }
log_err()   { echo -e "${RED}✗ Error:${NC} $*" >&2; }
log_step()  { echo -e "\n${BOLD}☁️  $*${NC}\n────────────────────────────────────────────────────────────────────"; }

INTERACTIVE=true
SKIP_APIS=false
TARGET_PROJECT="${GOOGLE_CLOUD_PROJECT:-${DEVSHELL_PROJECT_ID:-}}"
TARGET_REGION="${GOOGLE_CLOUD_LOCATION:-global}"
TARGET_API_KEY="${GEMINI_API_KEY:-${GOOGLE_API_KEY:-}}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project|-p) TARGET_PROJECT="${2:-}"; shift 2 ;;
    --project=*)  TARGET_PROJECT="${1#*=}"; shift ;;
    --region|-r)  TARGET_REGION="${2:-global}"; shift 2 ;;
    --region=*)   TARGET_REGION="${1#*=}"; shift ;;
    --api-key|-k) TARGET_API_KEY="${2:-}"; shift 2 ;;
    --api-key=*)  TARGET_API_KEY="${1#*=}"; shift ;;
    --non-interactive|-y) INTERACTIVE=false; shift ;;
    --skip-apis)  SKIP_APIS=true; shift ;;
    --help|-h)
      echo "Uso: bash $0 [--project PROJECT_ID] [--region global] [--api-key AI_STUDIO_KEY] [--non-interactive|-y] [--skip-apis]"
      exit 0
      ;;
    *) shift ;;
  esac
done

mkdir -p "${HOME}/.local/bin"
export PATH="${HOME}/.local/bin:${PATH}"

OS_RAW="$(uname -s)"
ARCH_RAW="$(uname -m)"
SHELL_RC="${HOME}/.bashrc"
[[ "${OS_RAW}" == "Darwin"* ]] && SHELL_RC="${HOME}/.zshrc"
touch "${SHELL_RC}"

persist_line() {
  local marker="$1"
  local line="$2"
  grep -v -F "${marker}" "${SHELL_RC}" > "${SHELL_RC}.tmp" 2>/dev/null || true
  echo "${line}" >> "${SHELL_RC}.tmp"
  mv "${SHELL_RC}.tmp" "${SHELL_RC}"
}

persist_line 'export PATH="$HOME/.local/bin:$PATH"' 'export PATH="$HOME/.local/bin:$PATH"'
persist_line "UV_NO_CONFIG=" 'export UV_NO_CONFIG="1"'
persist_line "GOOGLE_API_USE_CLIENT_CERTIFICATE=" 'export GOOGLE_API_USE_CLIENT_CERTIFICATE="false"'

export UV_NO_CONFIG="1"
export GOOGLE_API_USE_CLIENT_CERTIFICATE="false"

# ==============================================================================
# 1. Protecciones de Entorno (Cloud Shell vs. Máquina Local)
# ==============================================================================
log_step "1. Verificando Entorno Operativo y Protecciones de Red"

if [[ "${CLOUD_SHELL:-}" == "true" ]] || [[ -n "${DEVSHELL_PROJECT_ID:-}" ]]; then
  unset NO_GCE_CHECK || true
  log_ok "Google Cloud Shell detectado (Proyecto activo: ${DEVSHELL_PROJECT_ID:-(no definido)})."
elif ! curl -s -f -m 1 -H "Metadata-Flavor: Google" "http://169.254.169.254/computeMetadata/v1/instance/id" >/dev/null 2>&1; then
  export NO_GCE_CHECK="true"
  persist_line "NO_GCE_CHECK=" 'export NO_GCE_CHECK="true"'
  log_ok "NO_GCE_CHECK=true activado (evita esperas de 9s al servidor de metadatos fuera de GCE)."
fi

# ==============================================================================
# 2. Gestor uv / uvx y Python >= 3.11
# ==============================================================================
log_step "2. Verificando Gestor Python (uv) y Runtime Python 3.11+"

if ! command -v uv >/dev/null 2>&1; then
  log_info "Instalando Astral uv en ~/.local/bin..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="${HOME}/.local/bin:${PATH}"
fi
log_ok "uv listo: $(uv --version)"

if ! python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)' 2>/dev/null; then
  log_info "Instalando Python 3.12 gestionado por uv..."
  uv python install 3.12
fi
log_ok "Python listo: $(python3 --version 2>/dev/null || uv run python --version)"

# ==============================================================================
# 3. Google Cloud CLI y Terraform (Gobernanza Declarativa IaC)
# ==============================================================================
log_step "3. Verificando Google Cloud CLI (gcloud) y Terraform IaC"

if command -v gcloud >/dev/null 2>&1; then
  log_ok "gcloud detectado: $(gcloud --version 2>/dev/null | head -n 1)"
else
  log_warn "gcloud no está instalado. Si planeas desplegar en Vertex AI Agent Runtime, instala Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
fi

if command -v terraform >/dev/null 2>&1; then
  log_ok "Terraform detectado: $(terraform version | head -n 1)"
else
  log_warn "Terraform no detectado localmente (Cloud Shell ya lo incluye preinstalado; 'agents-cli deploy' también opera vía API)."
fi

# ==============================================================================
# 4. Instalar Helper 'agents-cli-env' y 'google-agents-cli'
# ==============================================================================
log_step "4. Instalando 'google-agents-cli' y Utilidad 'agents-cli-env'"

SCRIPT_DIR_LOCAL="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
LOCAL_REPO_DIR=""
for candidate in \
  "${SCRIPT_DIR_LOCAL}/.." \
  "$(pwd)" \
  "${HOME}/cloudshell_open/antigravity-example-latam" \
  "${HOME}/codelabs-practica/antigravity-example-latam" \
  "${HOME}/antigravity-example-latam"; do
  if [[ -n "${candidate}" && -f "${candidate}/scripts/agents-cli-env.sh" ]]; then
    LOCAL_REPO_DIR="$(cd "${candidate}" && pwd)"
    break
  fi
done

if [[ -n "${SCRIPT_DIR_LOCAL}" && -f "${SCRIPT_DIR_LOCAL}/agents-cli-env.sh" ]]; then
  cp "${SCRIPT_DIR_LOCAL}/agents-cli-env.sh" "${HOME}/.local/bin/agents-cli-env"
elif [[ -n "${LOCAL_REPO_DIR}" && -f "${LOCAL_REPO_DIR}/scripts/agents-cli-env.sh" ]]; then
  cp "${LOCAL_REPO_DIR}/scripts/agents-cli-env.sh" "${HOME}/.local/bin/agents-cli-env"
elif ! curl -fsSL "https://raw.githubusercontent.com/aquevedos/antigravity-example-latam/main/scripts/agents-cli-env.sh?t=$(date +%s)" \
  -o "${HOME}/.local/bin/agents-cli-env" 2>/dev/null; then
  cat << 'ENVEOF' > "${HOME}/.local/bin/agents-cli-env"
#!/usr/bin/env bash
set -euo pipefail
FILES=()
[[ -f ".env" ]]     && FILES+=(".env")
[[ -f "app/.env" ]] && FILES+=("app/.env")
if [[ ${#FILES[@]} -eq 0 ]]; then
  if [[ -d "app" ]]; then FILES=(".env" "app/.env"); else FILES=(".env"); fi
fi
MODE="${1:-status}"
case "${MODE}" in
  aistudio)
    KEY="${2:-${GEMINI_API_KEY:-${GOOGLE_API_KEY:-}}}"
    [[ -z "${KEY}" ]] && { echo "Uso: agents-cli-env aistudio <TU_CLAVE_AI_STUDIO>"; exit 1; }
    for TARGET_ENV in "${FILES[@]}"; do
      touch "${TARGET_ENV}"
      grep -v -E "^(GOOGLE_GENAI_USE_VERTEXAI|GEMINI_API_KEY|GOOGLE_API_KEY|GOOGLE_API_USE_CLIENT_CERTIFICATE)=" "${TARGET_ENV}" > "${TARGET_ENV}.tmp" || true
      printf "GOOGLE_GENAI_USE_VERTEXAI=FALSE\nGEMINI_API_KEY=%s\nGOOGLE_API_KEY=%s\nGOOGLE_API_USE_CLIENT_CERTIFICATE=false\n" "${KEY}" "${KEY}" >> "${TARGET_ENV}.tmp"
      mv "${TARGET_ENV}.tmp" "${TARGET_ENV}"
      echo "✓ Configurado ${TARGET_ENV} para Google AI Studio (GOOGLE_GENAI_USE_VERTEXAI=FALSE)."
    done
    ;;
  vertex)
    PROJ="${2:-${GOOGLE_CLOUD_PROJECT:-${DEVSHELL_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}}}"
    LOC="${3:-global}"
    [[ -z "${PROJ}" || "${PROJ}" == "(unset)" ]] && { echo "Uso: agents-cli-env vertex <PROJECT_ID> [REGION]"; exit 1; }
    CLOUDSDK_CORE_DISABLE_PROMPTS=1 gcloud config set project "${PROJ}" --quiet >/dev/null 2>&1 || true
    ADC_FILE_CHECK="${CLOUDSDK_CONFIG:-${HOME}/.config/gcloud}/application_default_credentials.json"
    if [[ ! -f "${ADC_FILE_CHECK}" ]] || ! CLOUDSDK_CORE_DISABLE_PROMPTS=1 gcloud auth application-default print-access-token >/dev/null 2>&1; then
      gcloud auth application-default login </dev/tty
    fi
    CLOUDSDK_CORE_DISABLE_PROMPTS=1 gcloud auth application-default set-quota-project "${PROJ}" --quiet >/dev/null 2>&1 || true
    CLOUDSDK_CORE_DISABLE_PROMPTS=1 gcloud services enable serviceusage.googleapis.com cloudresourcemanager.googleapis.com aiplatform.googleapis.com generativelanguage.googleapis.com cloudbuild.googleapis.com run.googleapis.com cloudtrace.googleapis.com artifactregistry.googleapis.com iam.googleapis.com iamcredentials.googleapis.com storage.googleapis.com logging.googleapis.com monitoring.googleapis.com secretmanager.googleapis.com --project="${PROJ}" --quiet >/dev/null 2>&1 || true
    for TARGET_ENV in "${FILES[@]}"; do
      touch "${TARGET_ENV}"
      grep -v -E "^(GOOGLE_CLOUD_PROJECT|GOOGLE_CLOUD_LOCATION|GOOGLE_GENAI_USE_VERTEXAI|GOOGLE_API_USE_CLIENT_CERTIFICATE)=" "${TARGET_ENV}" > "${TARGET_ENV}.tmp" || true
      printf "GOOGLE_GENAI_USE_VERTEXAI=TRUE\nGOOGLE_CLOUD_PROJECT=%s\nGOOGLE_CLOUD_LOCATION=%s\nGOOGLE_API_USE_CLIENT_CERTIFICATE=false\n" "${PROJ}" "${LOC}" >> "${TARGET_ENV}.tmp"
      mv "${TARGET_ENV}.tmp" "${TARGET_ENV}"
      echo "✓ Configurado ${TARGET_ENV} para Vertex AI (PROJECT=${PROJ}, LOCATION=${LOC})."
    done
    ;;
  *)
    echo "Uso: agents-cli-env vertex <PROJECT_ID> [REGION] | agents-cli-env aistudio <CLAVE_AI_STUDIO>"
    ;;
esac
ENVEOF
fi
chmod +x "${HOME}/.local/bin/agents-cli-env"
log_ok "Helper 'agents-cli-env' instalado en ~/.local/bin/agents-cli-env."

log_info "Instalando/actualizando google-agents-cli..."
uv tool install --upgrade --force google-agents-cli
hash -r 2>/dev/null || true
log_ok "agents-cli listo: $(agents-cli --version 2>/dev/null | head -n 1 || echo 'instalado')"

# ==============================================================================
# 5. Configurar Credenciales GCP / AI Studio y Habilitar APIs
# ==============================================================================
log_step "5. Alineando Proyecto GCP, Credenciales ADC y APIs de Vertex AI"

if [[ -z "${TARGET_PROJECT}" ]] && command -v gcloud >/dev/null 2>&1; then
  GCLOUD_PROJ="$(gcloud config get-value project 2>/dev/null || true)"
  [[ -n "${GCLOUD_PROJ}" && "${GCLOUD_PROJ}" != "(unset)" ]] && TARGET_PROJECT="${GCLOUD_PROJ}"
fi

if [[ -n "${TARGET_API_KEY}" && -z "${TARGET_PROJECT}" ]]; then
  "${HOME}/.local/bin/agents-cli-env" aistudio "${TARGET_API_KEY}" || true
elif [[ -n "${TARGET_PROJECT}" ]] && command -v gcloud >/dev/null 2>&1; then
  if [[ "${SKIP_APIS}" == "false" ]]; then
    "${HOME}/.local/bin/agents-cli-env" vertex "${TARGET_PROJECT}" "${TARGET_REGION}" || true
  fi
elif [[ "${INTERACTIVE}" == "true" && ( -t 0 || -e /dev/tty ) ]]; then
  echo -en "${BLUE}▸${NC} Ingresa tu Google Cloud Project ID (o presiona ENTER para configurar después): " >/dev/tty
  read -r INPUT_PROJ </dev/tty || true
  if [[ -n "${INPUT_PROJ}" ]]; then
    TARGET_PROJECT="${INPUT_PROJ}"
    "${HOME}/.local/bin/agents-cli-env" vertex "${TARGET_PROJECT}" "${TARGET_REGION}" || true
  fi
fi

# ==============================================================================
# 6. Preconfigurar Plantilla MCP y Skill del Taller
# ==============================================================================
log_step "6. Preconfigurando Soporte MCP (FastMCP) y Skill del Taller"

if [[ -n "${LOCAL_REPO_DIR}" && -d "${LOCAL_REPO_DIR}/skills/cymbal-sales-ops-adk" ]]; then
  mkdir -p "${HOME}/.agents/skills"
  cp -r "${LOCAL_REPO_DIR}/skills/cymbal-sales-ops-adk" "${HOME}/.agents/skills/"
  log_ok "Skill 'cymbal-sales-ops-adk' sincronizada localmente en ~/.agents/skills/."
elif command -v npx >/dev/null 2>&1; then
  npx -y skills add https://github.com/aquevedos/antigravity-example-latam -y --all -g >/dev/null 2>&1 || true
  log_ok "Skill 'cymbal-sales-ops-adk' verificada para tu Coding Agent."
fi

python3 - << 'PYEOF' 2>/dev/null || true
import glob, os
uv_tools = os.path.expanduser("~/.local/share/uv/tools/google-agents-cli")
for cfg in glob.glob(os.path.join(uv_tools, "**/scaffold/agents/adk/.template/templateconfig.yaml"), recursive=True):
    txt = open(cfg, encoding="utf-8").read()
    if '"mcp>=' not in txt:
        txt = txt.replace(
            '- "a2a-sdk[http-server]>=1.0,<2"',
            '- "a2a-sdk[http-server]>=1.0,<2"\n    - "mcp>=1.8.0"',
        )
        open(cfg, "w", encoding="utf-8").write(txt)
PYEOF
log_ok "Plantilla ADK de agents-cli lista con soporte nativo para 'mcp>=1.8.0'."

log_step "🎉 ¡Entorno Listo para el Taller Cymbal Sales Ops!"
echo -e "  ${GREEN}✓${NC} Sistema / Arq.:  ${OS_RAW} (${ARCH_RAW})"
echo -e "  ${GREEN}✓${NC} uv:              $(uv --version)"
echo -e "  ${GREEN}✓${NC} Proyecto GCP:    ${TARGET_PROJECT:-(pendiente de definir)}"
echo -e "  ${GREEN}✓${NC} Helper .env:     agents-cli-env"
echo -e "\nEjecuta ${BOLD}source ${SHELL_RC}${NC} y verifica tu instalación con: ${BOLD}agents-cli info${NC}"
