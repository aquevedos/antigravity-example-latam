#!/usr/bin/env bash
# Copyright 2026 Google LLC
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# agents-cli-env — Configura o alterna el proyecto ADK (.env y app/.env) entre
# Google Cloud Vertex AI (ADC) y Google AI Studio (API Key), valida que las
# credenciales ADC tengan alcance para Vertex AI (incluso en Cloud Shell) y
# habilita automáticamente las APIs empresariales necesarias en GCP.
# ==============================================================================
# Uso:
#   agents-cli-env vertex [PROJECT_ID] [REGION]
#   agents-cli-env aistudio <TU_CLAVE_AI_STUDIO>
# ==============================================================================

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
    if [[ -z "${KEY}" ]]; then
      echo "Uso: agents-cli-env aistudio <TU_CLAVE_AI_STUDIO>"
      exit 1
    fi
    for TARGET_ENV in "${FILES[@]}"; do
      touch "${TARGET_ENV}"
      grep -v -E "^(GOOGLE_GENAI_USE_VERTEXAI|GEMINI_API_KEY|GOOGLE_API_KEY|GOOGLE_API_USE_CLIENT_CERTIFICATE)=" "${TARGET_ENV}" > "${TARGET_ENV}.tmp" || true
      {
        echo "GOOGLE_GENAI_USE_VERTEXAI=FALSE"
        echo "GEMINI_API_KEY=${KEY}"
        echo "GOOGLE_API_KEY=${KEY}"
        echo "GOOGLE_API_USE_CLIENT_CERTIFICATE=false"
      } >> "${TARGET_ENV}.tmp"
      mv "${TARGET_ENV}.tmp" "${TARGET_ENV}"
      echo "✓ Configurado ${TARGET_ENV} para Google AI Studio (GOOGLE_GENAI_USE_VERTEXAI=FALSE)."
    done
    echo "  Ahora ejecuta: agents-cli playground"
    ;;
  vertex)
    PROJ="${2:-${GOOGLE_CLOUD_PROJECT:-${DEVSHELL_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}}}"
    LOC="${3:-global}"
    if [[ -z "${PROJ}" || "${PROJ}" == "(unset)" ]]; then
      echo "Uso: agents-cli-env vertex <PROJECT_ID> [REGION]"
      exit 1
    fi

    CLOUDSDK_CORE_DISABLE_PROMPTS=1 gcloud config set project "${PROJ}" --quiet >/dev/null 2>&1 || true

    # En Cloud Shell, el servidor de metadatos no posee alcance de Vertex AI; exige archivo ADC explícito
    ADC_FILE_CHECK="${CLOUDSDK_CONFIG:-${HOME}/.config/gcloud}/application_default_credentials.json"
    if [[ ! -f "${ADC_FILE_CHECK}" ]] || ! CLOUDSDK_CORE_DISABLE_PROMPTS=1 gcloud auth application-default print-access-token >/dev/null 2>&1; then
      echo "⚠️  Credenciales ADC ausentes o expiradas en ${ADC_FILE_CHECK} (el servidor de metadatos de Cloud Shell no tiene alcance para Vertex AI)."
      echo "▸ Iniciando 'gcloud auth application-default login'..."
      gcloud auth application-default login </dev/tty
    fi
    CLOUDSDK_CORE_DISABLE_PROMPTS=1 gcloud auth application-default set-quota-project "${PROJ}" --quiet >/dev/null 2>&1 || true

    echo "▸ Habilitando APIs de Vertex AI, Cloud Build, IAM y Agent Runtime en el proyecto '${PROJ}'..."
    CLOUDSDK_CORE_DISABLE_PROMPTS=1 gcloud services enable \
      serviceusage.googleapis.com \
      cloudresourcemanager.googleapis.com \
      --project="${PROJ}" --quiet >/dev/null 2>&1 || true
    CLOUDSDK_CORE_DISABLE_PROMPTS=1 gcloud services enable \
      aiplatform.googleapis.com \
      generativelanguage.googleapis.com \
      cloudbuild.googleapis.com \
      run.googleapis.com \
      cloudtrace.googleapis.com \
      artifactregistry.googleapis.com \
      iam.googleapis.com \
      iamcredentials.googleapis.com \
      storage.googleapis.com \
      logging.googleapis.com \
      monitoring.googleapis.com \
      secretmanager.googleapis.com \
      --project="${PROJ}" --quiet >/dev/null 2>&1 || true

    for TARGET_ENV in "${FILES[@]}"; do
      touch "${TARGET_ENV}"
      grep -v -E "^(GOOGLE_CLOUD_PROJECT|GOOGLE_CLOUD_LOCATION|GOOGLE_GENAI_USE_VERTEXAI|GOOGLE_API_USE_CLIENT_CERTIFICATE)=" "${TARGET_ENV}" > "${TARGET_ENV}.tmp" || true
      {
        echo "GOOGLE_GENAI_USE_VERTEXAI=TRUE"
        echo "GOOGLE_CLOUD_PROJECT=${PROJ}"
        echo "GOOGLE_CLOUD_LOCATION=${LOC}"
        echo "GOOGLE_API_USE_CLIENT_CERTIFICATE=false"
      } >> "${TARGET_ENV}.tmp"
      mv "${TARGET_ENV}.tmp" "${TARGET_ENV}"
      echo "✓ Configurado ${TARGET_ENV} para Vertex AI (PROJECT=${PROJ}, LOCATION=${LOC})."
    done
    echo "  Ahora ejecuta: agents-cli playground"
    ;;
  *)
    for TARGET_ENV in "${FILES[@]}"; do
      echo "Configuración activa en ${TARGET_ENV} (variables no sensibles):"
      grep -E "^(GOOGLE_GENAI_USE_VERTEXAI|GOOGLE_CLOUD_PROJECT|GOOGLE_CLOUD_LOCATION)=" "${TARGET_ENV}" 2>/dev/null || echo "  (sin configurar)"
    done
    echo ""
    echo "Uso:"
    echo "  agents-cli-env vertex <PROJECT_ID> [REGION]      # Configura .env para Vertex AI, valida ADC y habilita APIs"
    echo "  agents-cli-env aistudio <CLAVE_AI_STUDIO>        # Configura .env para Google AI Studio"
    ;;
esac
