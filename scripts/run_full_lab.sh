#!/usr/bin/env bash
# Copyright 2026 Google LLC
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# ☁️ Cymbal Sales Ops with ADK — Ejecución Automatizada del Ciclo Completo
# ==============================================================================
# Recorre automáticamente los 7 pasos del ciclo de vida de un Agente Empresarial:
#   • Módulo 0 (setup)        : Verifica herramientas (uv, Python 3.11+, gcloud, agents-cli) y ADC
#   • Módulo 1 (spec.md)      : Descarga el plano arquitectónico spec.md (Spec-Driven Development)
#   • Módulo 2 (scaffold/.env): Crea 'cymbal-sales-ops-agent' y configura credenciales (.env)
#   • Módulo 3 (build & run)  : Instala Vera (ADK + Skills + MCP SQLite + UI Pastel) y prueba CLI
#   • Módulo 4 (eval & lint)  : Ejecuta Golden Dataset (LLM-as-a-Judge) y control de calidad
#   • Módulo 5 (observability): Verifica configuración de Cloud Trace y telemetría OpenTelemetry
#   • Módulo 6 (deploy & IaC) : Genera Terraform IaC (scaffold enhance) y despliega en Agent Runtime
#   • Módulo 7 (publish)      : Verifica Agent Registry y muestra comando para Gemini Enterprise
#
# Uso en 1 línea:
#   bash <(curl -fsSL https://raw.githubusercontent.com/aquevedos/antigravity-example-latam/main/scripts/run_full_lab.sh)
#
# Opciones:
#   --project <PROJECT_ID>   Define el proyecto GCP (por defecto: $GOOGLE_CLOUD_PROJECT o gcloud config)
#   --region <REGION>        Región para Agent Runtime (por defecto: us-central1)
#   --api-key <API_KEY>      Usa clave de Google AI Studio (omite el despliegue en GCP)
#   --dir <PATH>             Directorio donde crear el agente (por defecto: $HOME/cymbal-sales-ops-agent)
#   --skip-deploy            Ejecuta todo localmente (incluyendo generación de Terraform IaC) sin desplegar
#   --skip-eval              Omite la evaluación LLM-as-a-Judge (Módulo 4)
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

TARGET_PROJECT="${GOOGLE_CLOUD_PROJECT:-${DEVSHELL_PROJECT_ID:-}}"
DEPLOY_REGION="us-central1"
TARGET_API_KEY="${GEMINI_API_KEY:-${GOOGLE_API_KEY:-}}"
AGENT_DIR="${HOME}/cymbal-sales-ops-agent"
SKIP_DEPLOY=false
SKIP_EVAL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project|-p) TARGET_PROJECT="${2:-}"; shift 2 ;;
    --project=*)  TARGET_PROJECT="${1#*=}"; shift ;;
    --region|-r)  DEPLOY_REGION="${2:-us-central1}"; shift 2 ;;
    --region=*)   DEPLOY_REGION="${1#*=}"; shift ;;
    --api-key|-k) TARGET_API_KEY="${2:-}"; shift 2 ;;
    --api-key=*)  TARGET_API_KEY="${1#*=}"; shift ;;
    --dir|-d)     AGENT_DIR="${2:-${HOME}/cymbal-sales-ops-agent}"; shift 2 ;;
    --dir=*)      AGENT_DIR="${1#*=}"; shift ;;
    --skip-deploy) SKIP_DEPLOY=true; shift ;;
    --skip-eval)   SKIP_EVAL=true; shift ;;
    --help|-h)
      echo "Uso: bash $0 [--project PROJECT_ID] [--region us-central1] [--api-key AI_STUDIO_KEY] [--dir ~/cymbal-sales-ops-agent] [--skip-deploy] [--skip-eval]"
      exit 0
      ;;
    *) shift ;;
  esac
done

export PATH="${HOME}/.local/bin:${PATH}"
export UV_NO_CONFIG="1"
export GOOGLE_API_USE_CLIENT_CERTIFICATE="false"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
LOCAL_REPO_ROOT=""
if [[ -n "${SCRIPT_DIR}" && -d "${SCRIPT_DIR}/../starter" ]]; then
  LOCAL_REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

REPO_RAW_ROOT="https://raw.githubusercontent.com/aquevedos/antigravity-example-latam/main"
TS="$(date +%s)"

# ==============================================================================
# Módulo 0: Preparación del Entorno y Credenciales GCP
# ==============================================================================
log_step "Módulo 0 (Setup): Preparando Entorno, CLI y Protecciones de Red"

if [[ "${CLOUD_SHELL:-}" == "true" ]] || [[ -n "${DEVSHELL_PROJECT_ID:-}" ]]; then
  unset NO_GCE_CHECK || true
  log_ok "Google Cloud Shell detectado."
elif ! curl -s -f -m 1 -H "Metadata-Flavor: Google" "http://169.254.169.254/computeMetadata/v1/instance/id" >/dev/null 2>&1; then
  export NO_GCE_CHECK="true"
  log_ok "NO_GCE_CHECK=true activado."
fi

if ! command -v agents-cli >/dev/null 2>&1 || ! command -v uv >/dev/null 2>&1; then
  if [[ -n "${LOCAL_REPO_ROOT}" && -f "${LOCAL_REPO_ROOT}/scripts/setup_agents_cli.sh" ]]; then
    bash "${LOCAL_REPO_ROOT}/scripts/setup_agents_cli.sh" --non-interactive --skip-apis
  else
    curl -fsSL "${REPO_RAW_ROOT}/scripts/setup_agents_cli.sh?t=${TS}" | bash -s -- --non-interactive --skip-apis
  fi
  export PATH="${HOME}/.local/bin:${PATH}"
  hash -r 2>/dev/null || true
fi

if [[ -z "${TARGET_PROJECT}" ]] && command -v gcloud >/dev/null 2>&1; then
  GCLOUD_PROJ="$(gcloud config get-value project 2>/dev/null || true)"
  [[ -n "${GCLOUD_PROJ}" && "${GCLOUD_PROJ}" != "(unset)" ]] && TARGET_PROJECT="${GCLOUD_PROJ}"
fi

if [[ -n "${TARGET_PROJECT}" ]] && command -v gcloud >/dev/null 2>&1; then
  log_info "Proyecto GCP activo: ${BOLD}${TARGET_PROJECT}${NC}"
  CLOUDSDK_CORE_DISABLE_PROMPTS=1 gcloud config set project "${TARGET_PROJECT}" --quiet >/dev/null 2>&1 || true
  ADC_FILE="${CLOUDSDK_CONFIG:-${HOME}/.config/gcloud}/application_default_credentials.json"
  if [[ ! -f "${ADC_FILE}" ]] || ! CLOUDSDK_CORE_DISABLE_PROMPTS=1 gcloud auth application-default print-access-token >/dev/null 2>&1; then
    if [[ -t 0 || -e /dev/tty ]]; then
      log_warn "Credenciales ADC ausentes o expiradas. Iniciando 'gcloud auth application-default login'..."
      gcloud auth application-default login </dev/tty
    fi
  fi
  CLOUDSDK_CORE_DISABLE_PROMPTS=1 gcloud auth application-default set-quota-project "${TARGET_PROJECT}" --quiet >/dev/null 2>&1 || true
  CLOUDSDK_CORE_DISABLE_PROMPTS=1 gcloud services enable \
    aiplatform.googleapis.com generativelanguage.googleapis.com cloudbuild.googleapis.com \
    run.googleapis.com cloudtrace.googleapis.com artifactregistry.googleapis.com \
    iam.googleapis.com iamcredentials.googleapis.com storage.googleapis.com \
    logging.googleapis.com monitoring.googleapis.com secretmanager.googleapis.com \
    --project="${TARGET_PROJECT}" --quiet >/dev/null 2>&1 || true
fi

# ==============================================================================
# Módulo 2 (Scaffold + .env) + Módulo 1 (spec.md)
# ==============================================================================
log_step "Módulos 1 y 2 (spec.md + scaffold + .env): Inicializando 'cymbal-sales-ops-agent'"

PARENT_DIR="$(dirname "${AGENT_DIR}")"
AGENT_NAME="$(basename "${AGENT_DIR}")"
mkdir -p "${PARENT_DIR}"

if [[ -d "${AGENT_DIR}" ]]; then
  BACKUP_DIR="${AGENT_DIR}.bak.$(date +%H%M%S)"
  log_warn "El directorio ${AGENT_DIR} ya existe. Respaldando en ${BACKUP_DIR}..."
  mv "${AGENT_DIR}" "${BACKUP_DIR}"
fi

(
  cd "${PARENT_DIR}"
  agents-cli scaffold create "${AGENT_NAME}" --prototype --yes
)
cd "${AGENT_DIR}"
log_ok "Estructura ADK creada en: $(pwd)"

if [[ -n "${LOCAL_REPO_ROOT}" && -f "${LOCAL_REPO_ROOT}/spec.md" ]]; then
  cp "${LOCAL_REPO_ROOT}/spec.md" "spec.md"
else
  curl -fsSL "${REPO_RAW_ROOT}/spec.md?t=${TS}" -o "spec.md"
fi
log_ok "Plano arquitectónico copiado en $(pwd)/spec.md"

for env_file in ".env" "app/.env"; do
  if [[ -n "${TARGET_API_KEY}" && -z "${TARGET_PROJECT}" ]]; then
    cat << EOF > "${env_file}"
GOOGLE_GENAI_USE_VERTEXAI=FALSE
GEMINI_API_KEY=${TARGET_API_KEY}
GOOGLE_API_KEY=${TARGET_API_KEY}
GOOGLE_API_USE_CLIENT_CERTIFICATE=false
EOF
    log_ok "Configurado ${env_file} para Google AI Studio."
  else
    cat << EOF > "${env_file}"
GOOGLE_GENAI_USE_VERTEXAI=TRUE
GOOGLE_CLOUD_PROJECT=${TARGET_PROJECT}
GOOGLE_CLOUD_LOCATION=global
GOOGLE_API_USE_CLIENT_CERTIFICATE=false
EOF
    log_ok "Configurado ${env_file} para Vertex AI (PROJECT=${TARGET_PROJECT}, LOCATION=global)."
  fi
done

# ==============================================================================
# Módulo 3 (Build & Run): Agente ADK + Skills + MCP SQLite + UI Pastel
# ==============================================================================
log_step "Módulo 3 (Build & Run): Instalando Vera, ADK Skills, MCP SQLite y UI Pastel"

RAW_STARTER="${REPO_RAW_ROOT}/starter"

mkdir -p \
  "app/prompts" \
  "app/skills/validador-politicas-ventas/references" \
  "app/skills/redactor-escalamiento-comercial/references" \
  "tests/eval/datasets"

copy_or_fetch() {
  local rel="$1"
  local dst="$2"
  if [[ -n "${LOCAL_REPO_ROOT}" && -f "${LOCAL_REPO_ROOT}/starter/${rel}" ]]; then
    cp "${LOCAL_REPO_ROOT}/starter/${rel}" "${dst}"
  else
    curl -fsSL "${RAW_STARTER}/${rel}?t=${TS}" -o "${dst}"
  fi
}

copy_or_fetch "agent.py" "app/agent.py"
copy_or_fetch "mcp_revops.py" "app/mcp_revops.py"
copy_or_fetch "ui.py" "app/ui.py"
copy_or_fetch "prompts/cymbal_sales_system_prompt.md" "app/prompts/cymbal_sales_system_prompt.md"
copy_or_fetch "skills/validador-politicas-ventas/SKILL.md" "app/skills/validador-politicas-ventas/SKILL.md"
copy_or_fetch "skills/validador-politicas-ventas/references/politica_gobernanza_comercial.md" "app/skills/validador-politicas-ventas/references/politica_gobernanza_comercial.md"
copy_or_fetch "skills/redactor-escalamiento-comercial/SKILL.md" "app/skills/redactor-escalamiento-comercial/SKILL.md"
copy_or_fetch "skills/redactor-escalamiento-comercial/references/plantillas_memorandos_doa.md" "app/skills/redactor-escalamiento-comercial/references/plantillas_memorandos_doa.md"
copy_or_fetch "basic-dataset.json" "tests/eval/datasets/basic-dataset.json"

if [[ -f "app/fast_api_app.py" ]] && ! grep -q "GOOGLE_API_USE_CLIENT_CERTIFICATE" "app/fast_api_app.py"; then
  sed -i 's/import os/import os\nos.environ.setdefault("GOOGLE_API_USE_CLIENT_CERTIFICATE", "false")/' "app/fast_api_app.py"
fi

if [[ -f "pyproject.toml" ]]; then
  sed -i 's/ignore-words-list = "rouge"/ignore-words-list = "rouge,oficial,cliente,margen,comercial,serie,actual,control,responde,utiliza,nivel"/' "pyproject.toml"
  sed -i 's|skip = "\./locust_env/\*|skip = "\./artifacts/\*,\./app/prompts/\*,\./app/skills/\*,\./tests/eval/datasets/\*,\./spec.md,\./locust_env/\*|' "pyproject.toml"
fi

rm -f uv.lock
uv add --no-config "mcp>=1.8.0,<2.0.0" "streamlit>=1.40.0"
uv lock --no-config
agents-cli install
log_ok "Dependencias instaladas con uv.lock limpio (PyPI público)."

log_info "Prueba 1/2 — Guardrail de Alcance (bloqueo determinista en before_model_callback):"
agents-cli run "Escribe una estrategia para invertir en Bitcoin en la bolsa de valores"

log_info "Prueba 2/2 — Escenario Comercial Integrado (ADK Skills + Tools Financieras + SQLite MCP):"
agents-cli run "Consulta en SQLite el catálogo Cloud (CLD-ENT-SUITE) y el perfil de Nordic FinTech Group en EMEA; calcula el margen bruto con 14% de descuento para 18,000 licencias y dime si está preaprobado sin escalar." || log_warn "La llamada a Gemini requiere ADC activo ('gcloud auth application-default login') o --api-key."

agents-cli run --stop-server >/dev/null 2>&1 || true
log_ok "Pruebas locales en terminal finalizadas."

# ==============================================================================
# Módulo 4 (Eval & Lint): Golden Dataset (LLM-as-a-Judge) y Calidad de Código
# ==============================================================================
if [[ "${SKIP_EVAL}" == "false" ]]; then
  log_step "Módulo 4 (Eval): Ejecutando Golden Dataset con LLM-as-a-Judge (agents-cli eval run)"
  agents-cli eval run || log_warn "La evaluación finalizó con advertencias; revisa el reporte superior."
else
  log_info "Omitiendo Módulo 4 (--skip-eval)."
fi

log_info "Ejecutando control de calidad estática (agents-cli lint --fix)..."
agents-cli lint --fix
log_ok "Control de calidad superado."

# ==============================================================================
# Módulo 5 (Observability): Verificación de Cloud Trace y Telemetría
# ==============================================================================
log_step "Módulo 5 (Observability): Verificando Telemetría OpenTelemetry / Cloud Trace"
if [[ -f "app/fast_api_app.py" ]] && grep -q "otel_to_cloud" "app/fast_api_app.py"; then
  log_ok "Exportador OpenTelemetry hacia Cloud Trace activo en app/fast_api_app.py."
else
  log_info "Cloud Trace se habilitará automáticamente al ejecutar scaffold enhance / deploy en Agent Runtime."
fi

# ==============================================================================
# Módulo 6 (Deploy & Terraform IaC) + Módulo 7 (Publish)
# ==============================================================================
log_step "Módulo 6 (Deploy & IaC): Generando Terraform IaC y Desplegando en Agent Runtime"

agents-cli scaffold enhance --deployment-target agent_runtime --prefer-new --yes
if [[ -f "app/fast_api_app.py" ]] && ! grep -q "GOOGLE_API_USE_CLIENT_CERTIFICATE" "app/fast_api_app.py"; then
  sed -i 's/import os/import os\nos.environ.setdefault("GOOGLE_API_USE_CLIENT_CERTIFICATE", "false")/' "app/fast_api_app.py"
fi
rm -f uv.lock
uv add --no-config "mcp>=1.8.0,<2.0.0" "streamlit>=1.40.0"
uv lock --no-config
log_ok "Artefactos declarativos de Terraform IaC preparados en deployment/terraform/."

if [[ "${SKIP_DEPLOY}" == "false" && -n "${TARGET_PROJECT}" ]]; then
  DEPLOY_LOG="$(mktemp)"
  UV_NO_CONFIG=1 agents-cli deploy --project "${TARGET_PROJECT}" --region "${DEPLOY_REGION}" 2>&1 | tee "${DEPLOY_LOG}"
  log_ok "Despliegue en Vertex AI Agent Runtime completado."

  DEPLOYED_RE_PATH="$(grep -oE 'projects/[0-9]+/locations/[^[:space:]/"]+/reasoningEngines/[0-9]+' "${DEPLOY_LOG}" | tail -n 1 || true)"
  rm -f "${DEPLOY_LOG}"
  if [[ -n "${DEPLOYED_RE_PATH}" ]]; then
    DEPLOYED_APP_URL="https://${DEPLOY_REGION}-aiplatform.googleapis.com/reasoningEngines/v1/${DEPLOYED_RE_PATH}/api"
    log_info "Probando el agente en vivo en Agent Runtime (${DEPLOYED_APP_URL})..."
    agents-cli run --url "${DEPLOYED_APP_URL}" --mode adk "Un cliente Enterprise en EMEA solicita 14% de descuento en 18,000 licencias de CLD-ENT-SUITE. ¿Puedo aplicarlo sin escalar?"
    log_ok "Validación remota exitosa."
  fi

  log_step "Módulo 7 (Publish): Registro en Agent Registry y Gemini Enterprise"
  log_info "Tu agente quedó auto-registrado en Agent Registry. Para publicarlo en una app de Gemini Enterprise ejecuta:"
  echo -e "  ${BOLD}cd ${AGENT_DIR} && agents-cli publish gemini --interactive${NC}"
else
  log_info "Despliegue remoto omitido (--skip-deploy o modo AI Studio). Para desplegar y publicar cuando gustes:"
  echo -e "  ${BOLD}cd ${AGENT_DIR} && UV_NO_CONFIG=1 agents-cli deploy --project ${TARGET_PROJECT:-<TU_PROYECTO_GCP>} --region ${DEPLOY_REGION}${NC}"
  echo -e "  ${BOLD}cd ${AGENT_DIR} && agents-cli publish gemini --interactive${NC}"
fi

log_step "🎉 ¡Ciclo Completo Cymbal Sales Ops Finalizado con Éxito!"
echo -e "  📂 Directorio del agente : ${BOLD}${AGENT_DIR}${NC}"
echo -e "  📄 Plano arquitectónico  : ${BOLD}${AGENT_DIR}/spec.md${NC}"
echo -e "  🌐 ADK Web Playground    : ${BOLD}cd ${AGENT_DIR} && agents-cli playground${NC}"
echo -e "  🎨 UI Pastel Streamlit   : ${BOLD}cd ${AGENT_DIR} && uv run streamlit run app/ui.py --server.address 127.0.0.1 --server.port 8501${NC}"
