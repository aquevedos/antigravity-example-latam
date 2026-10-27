# ruff: noqa
import os
from pathlib import Path
import re
import shutil
import sys
import time
from typing import Any, Optional
import urllib.request

from google.adk.agents import Agent
from google.adk.agents.callback_context import CallbackContext
from google.adk.apps import App
from google.adk.models import Gemini
from google.adk.models.llm_request import LlmRequest
from google.adk.models.llm_response import LlmResponse
from google.adk.skills import load_skill_from_dir
from google.adk.tools.base_tool import BaseTool
from google.adk.tools.skill_toolset import SkillToolset
from google.adk.tools.tool_context import ToolContext
from google.genai import types

# En Vertex AI / Gemini Enterprise Agent Platform, los modelos Gemini de agents-cli
# operan sobre el endpoint multirregión 'global'.
if os.environ.get("GOOGLE_GENAI_USE_VERTEXAI", "TRUE").upper() != "FALSE":
    os.environ["GOOGLE_CLOUD_LOCATION"] = "global"
os.environ.setdefault("GOOGLE_API_USE_CLIENT_CERTIFICATE", "false")

_APP_DIR = Path(__file__).resolve().parent
_RAW_BASE_URL = (
    "https://raw.githubusercontent.com/aquevedos/antigravity-example-latam/main/starter"
)

_MARKDOWN_ASSETS = [
    "prompts/cymbal_sales_system_prompt.md",
    "skills/validador-politicas-ventas/SKILL.md",
    "skills/validador-politicas-ventas/references/politica_gobernanza_comercial.md",
    "skills/redactor-escalamiento-comercial/SKILL.md",
    "skills/redactor-escalamiento-comercial/references/plantillas_memorandos_doa.md",
]


def _sanitize_adk_braces(texto: str) -> str:
    """Elimina llaves que inject_session_state de ADK interpretaría como variables de sesión."""
    texto = re.sub(r"\\text\{([^}]*)\}", r"\1", texto)
    texto = re.sub(r"\^\{([^}]*)\}", r"\1", texto)
    texto = re.sub(r"_\{([^}]*)\}", r"\1", texto)
    return texto.replace("{", "(").replace("}", ")")


def _ensure_markdown_assets() -> None:
    """Garantiza que los archivos Markdown de Prompt y ADK Skills existan en app/."""
    ts = int(time.time())
    env_repo = os.environ.get("CYMBAL_LAB_REPO", "").strip()
    possible_local_starters = [
        _APP_DIR,
        _APP_DIR.parent / "starter",
        _APP_DIR.parent.parent / "antigravity-example-latam" / "starter",
        _APP_DIR.parent.parent.parent / "antigravity-example-latam" / "starter",
        Path.home() / "cloudshell_open" / "antigravity-example-latam" / "starter",
        Path.home() / "codelabs-practica" / "antigravity-example-latam" / "starter",
        Path.home() / "antigravity-example-latam" / "starter",
    ]
    if env_repo:
        possible_local_starters.insert(0, Path(env_repo) / "starter")

    for rel_path in _MARKDOWN_ASSETS:
        destino = _APP_DIR / rel_path
        if not destino.exists():
            destino.parent.mkdir(parents=True, exist_ok=True)
            copied = False
            for candidate_root in possible_local_starters:
                src = candidate_root / rel_path
                if src.exists() and src.resolve() != destino.resolve():
                    shutil.copyfile(src, destino)
                    copied = True
                    break
            if not copied:
                url = f"{_RAW_BASE_URL}/{rel_path}?t={ts}"
                if url.startswith("https://"):
                    try:
                        urllib.request.urlretrieve(url, destino)
                    except Exception:
                        pass

        if destino.exists():
            try:
                contenido = destino.read_text(encoding="utf-8", errors="ignore")
                if "{" in contenido or "}" in contenido:
                    destino.write_text(_sanitize_adk_braces(contenido), encoding="utf-8")
            except Exception:
                pass

    # Configura codespell en pyproject.toml para ignorar artefactos y archivos en español en 'agents-cli lint'
    pyproject_file = _APP_DIR.parent / "pyproject.toml"
    if pyproject_file.exists():
        try:
            py_txt = pyproject_file.read_text(encoding="utf-8", errors="ignore")
            changed = False
            if "./artifacts/*" not in py_txt and 'skip = "./locust_env/*' in py_txt:
                py_txt = py_txt.replace(
                    'skip = "./locust_env/*',
                    'skip = "./artifacts/*,./app/prompts/*,./app/skills/*,./tests/eval/datasets/*,./locust_env/*',
                )
                changed = True
            if 'ignore-words-list = "rouge"' in py_txt:
                py_txt = py_txt.replace(
                    'ignore-words-list = "rouge"',
                    'ignore-words-list = "rouge,oficial,cliente,margen,comercial,serie,actual,control,responde,utiliza,nivel"',
                )
                changed = True
            if changed:
                pyproject_file.write_text(py_txt, encoding="utf-8")
        except Exception:
            pass


def _resolve_default_model() -> str:
    """Obtiene el model ID configurado por agents-cli (funciona en local y en Agent Runtime)."""
    if os.environ.get("GENAI_MODEL"):
        return os.environ["GENAI_MODEL"]
    model_id_file = _APP_DIR / ".default_model"
    eval_file = _APP_DIR.parent / "tests" / "eval" / "response_quality.py"
    if eval_file.exists():
        eval_txt = eval_file.read_text(encoding="utf-8", errors="ignore")
        if "3.6-flash" in eval_txt:
            eval_txt = eval_txt.replace("3.6-flash", "2.5-flash")
            try:
                eval_file.write_text(eval_txt, encoding="utf-8")
            except Exception:
                pass
        match = re.search(r'model="([^"{]+)"', eval_txt)
        if match and "3.6" not in match.group(1):
            resolved = match.group(1)
            try:
                model_id_file.write_text(resolved, encoding="utf-8")
            except Exception:
                pass
            return resolved
    if model_id_file.exists():
        saved = model_id_file.read_text(encoding="utf-8", errors="ignore").strip()
        if saved and "3.6" not in saved:
            return saved
    try:
        from google.agents.cli._defaults import DEFAULT_MODEL

        if "3.6" not in str(DEFAULT_MODEL):
            return str(DEFAULT_MODEL)
    except Exception:
        pass
    return "gemini-2.5-flash"


_ensure_markdown_assets()
MODEL = _resolve_default_model()

# ============================================================================
# GUARDRAILS EN 3 CAPAS (ADK Callbacks + Validación Financiera + SafetySetting)
# ============================================================================

_PATRONES_JAILBREAK_Y_CONFIDENCIALIDAD = re.compile(
    r"(ignora\s+(todas\s+las\s+|las\s+|tus\s+)?(instrucciones|reglas|pol[ií]ticas)|"
    r"ignore\s+(all\s+|previous\s+)?(instructions|rules|policies)|"
    r"olvida\s+(todo|tus\s+reglas|tus\s+instrucciones)|"
    r"disregard\s+(previous|all|system)|"
    r"system\s*prompt|modo\s+desarrollador|developer\s+mode|jailbreak|\bdan\b|"
    r"act[uú]a\s+como\s+el\s+cfo\s+y\s+aprueba|"
    r"comisiones\s+(individuales|privadas|personales|salariales)|sueldos?\s+de\s+los\s+empleados)",
    re.IGNORECASE,
)

_TERMINOS_CONTEXTO_COMERCIAL = re.compile(
    r"(cymbal|venta|descuento|margen|cotizaci[oó]n|acv|msrp|licencia|unidad|"
    r"cloud|hardware|servicio|emea|latam|norteam[eé]rica|enterprise|mid[\s-]?market|smb|"
    r"\bnet\s*(30|45|60|90)\b|cr[eé]dito|pago|factura|doa|autoridad|escalamiento|"
    r"excepci[oó]n|erc|revops|sales\s*ops|comit[eé]|aprobaci[oó]n|aprobador|firma|"
    r"pol[ií]tica|sku|cat[aá]logo|cliente|memorando|correo|oferta|contrato|vera)",
    re.IGNORECASE,
)

_PATRONES_FUERA_DE_ALCANCE = re.compile(
    r"\b(bitcoin|ethereum|criptomoneda|cripto|bolsa\s+de\s+valores|trading|forex|"
    r"receta\s+de\s+cocina|hornear|cerveza|f[uú]tbol|champions\s+league|mundial|"
    r"videojuego|minecraft|playstation|motor\s+de\s+(un\s+)?(auto|carro|coche)|"
    r"diagn[oó]stico\s+m[eé]dico|antibiótico|cirug[ií]a|hor[oó]scopo|astrolog[ií]a)\b",
    re.IGNORECASE,
)


def guardrail_entrada_comercial(
    callback_context: CallbackContext, llm_request: LlmRequest
) -> Optional[LlmResponse]:
    """Capa 1 (ADK before_model_callback): bloquea Prompt Injection, fugas salariales y temas ajenos antes de invocar al LLM."""
    ultimo_texto_usuario = ""
    for content in reversed(llm_request.contents or []):
        if content.role == "user" and content.parts:
            partes_texto = [str(p.text) for p in content.parts if getattr(p, "text", None)]
            if partes_texto:
                ultimo_texto_usuario = " ".join(partes_texto).strip()
                break

    if not ultimo_texto_usuario:
        return None

    if _PATRONES_JAILBREAK_Y_CONFIDENCIALIDAD.search(ultimo_texto_usuario):
        return LlmResponse(
            content=types.Content(
                role="model",
                parts=[
                    types.Part.from_text(
                        text=(
                            "🛡️ **[Guardrail de Gobernanza Activado]** Soy **Vera**, Concierge de Operaciones de Ventas "
                            "y Gobernanza Comercial de **Cymbal Group**. Por cumplimiento corporativo (`CG-SOP-2026-V1`), "
                            "no puedo omitir las matrices de delegación de autoridad (DoA), aprobar excepciones de forma "
                            "unilateral ni exponer información confidencial sobre compensaciones individuales.\n\n"
                            "Si necesitas evaluar un descuento por volumen, validar un piso de margen bruto o consultar "
                            "las firmas requeridas para un plazo de crédito, indícame los parámetros de la operación."
                        )
                    )
                ],
            )
        )

    if _PATRONES_FUERA_DE_ALCANCE.search(
        ultimo_texto_usuario
    ) and not _TERMINOS_CONTEXTO_COMERCIAL.search(ultimo_texto_usuario):
        return LlmResponse(
            content=types.Content(
                role="model",
                parts=[
                    types.Part.from_text(
                        text=(
                            "☁️ **[Fuera del Alcance de Sales Ops]** ¡Hola! Soy **Vera**, especialista exclusivamente "
                            "en **Operaciones de Ventas, Políticas de Precios, Márgenes Brutos, Términos de Crédito y "
                            "Matrices de Delegación de Autoridad (DoA) de Cymbal Group**.\n\n"
                            "No puedo responder consultas ajenas al ámbito comercial corporativo (como criptomonedas, "
                            "inversiones personales, deportes, cocina o temas generales). ¿Deseas validar una cotización "
                            "o redactar un memorando de escalamiento comercial?"
                        )
                    )
                ],
            )
        )

    return None


def guardrail_parametros_herramientas(
    tool: BaseTool, args: dict[str, Any], tool_context: ToolContext
) -> Optional[dict[str, Any]]:
    """Capa 2 (ADK before_tool_callback): valida rangos financieros y contractuales antes de ejecutar tools."""
    nombre_tool = getattr(tool, "name", "")

    for campo_pct in ("descuento_solicitado_pct",):
        if campo_pct in args and args[campo_pct] is not None:
            pct = float(args[campo_pct])
            if pct < 0.0 or pct > 95.0:
                return {
                    "error_guardrail": (
                        f"Porcentaje de descuento inválido ({pct}%) en '{nombre_tool}'. "
                        "El descuento comercial debe situarse entre 0% y 95%."
                    )
                }

    for campo_cant in ("cantidad_unidades",):
        if campo_cant in args and args[campo_cant] is not None:
            cant = int(args[campo_cant])
            if cant < 1 or cant > 10_000_000:
                return {
                    "error_guardrail": (
                        f"Volumen fuera de rango operativo ({cant} unidades) en '{nombre_tool}'. "
                        "Ingresa una cantidad entre 1 y 10,000,000 de unidades/licencias."
                    )
                }

    if "dias_credito" in args and args["dias_credito"] is not None:
        dias = int(args["dias_credito"])
        if dias < 0 or dias > 365:
            return {
                "error_guardrail": (
                    f"Plazo de crédito inválido ({dias} días). "
                    "Ingresa un plazo comercial válido entre 0 y 365 días (ej. 30, 45, 60 o 90)."
                )
            }

    return None


# ============================================================================
# TOOLS FINANCIERAS DETERMINISTAS (Cero Alucinaciones en Cálculos Comerciales)
# ============================================================================


def calcular_cotizacion_y_margen(
    segmento_cliente: str,
    cantidad_unidades: int,
    precio_lista_unitario_usd: float,
    costo_unitario_usd: float,
    descuento_solicitado_pct: float,
) -> str:
    """Calcula el ACV neto (USD), ahorro otorgado y Margen Bruto exacto (%), validando el piso mínimo de rentabilidad (Sección 1).

    Args:
        segmento_cliente: Segmento de la cuenta ('Enterprise', 'Mid-Market' o 'SMB').
        cantidad_unidades: Número de licencias o unidades de la oferta (ej: 18000).
        precio_lista_unitario_usd: Precio MSRP unitario en USD (ej: 100.0 para CLD-ENT-SUITE).
        costo_unitario_usd: Costo directo unitario en USD (ej: 58.32 para CLD-ENT-SUITE).
        descuento_solicitado_pct: Porcentaje de descuento solicitado de 0 a 95 (ej: 14.0 o 28.0).

    Returns:
        Dictamen financiero exacto con ACV bruto, ACV neto, Margen Bruto (%) y estado frente al Gross Margin Floor.
    """
    seg = segmento_cliente.strip().lower()
    if "smb" in seg or "commercial" in seg or "pyme" in seg:
        piso_pct = 30.0
        etiqueta_seg = "SMB / Commercial"
    elif "mid" in seg:
        piso_pct = 28.0
        etiqueta_seg = "Mid-Market"
    else:
        piso_pct = 25.0
        etiqueta_seg = "Enterprise / Global Strategic"

    ingreso_lista = cantidad_unidades * precio_lista_unitario_usd
    acv_neto = ingreso_lista * (1.0 - (descuento_solicitado_pct / 100.0))
    descuento_usd = ingreso_lista - acv_neto
    costo_total = cantidad_unidades * costo_unitario_usd
    utilidad_bruta = acv_neto - costo_total
    margen_bruto_pct = (utilidad_bruta / acv_neto) * 100.0 if acv_neto > 0 else 0.0

    if margen_bruto_pct < piso_pct:
        veredicto_margen = (
            f"OPERACIÓN BLOQUEADA EN COTIZADOR — El margen bruto resultante ({margen_bruto_pct:.2f}%) "
            f"es inferior al piso innegociable del {piso_pct:.0f}% para {etiqueta_seg} (Sección 1.2 y 1.3). "
            "Único órgano facultado para dispensa: Executive Revenue Committee (ERC — Nivel 5 DoA)."
        )
    else:
        holgura = margen_bruto_pct - piso_pct
        veredicto_margen = (
            f"CUMPLE MARGEN PISO — El margen bruto ({margen_bruto_pct:.2f}%) supera el mínimo obligatorio "
            f"del {piso_pct:.0f}% para {etiqueta_seg} (+{holgura:.2f} puntos porcentuales sobre el piso, Sección 1.2)."
        )

    return (
        f"📊 Liquidación Financiera Determinista ({etiqueta_seg} | {cantidad_unidades:,} uds.):\n"
        f"- Valor a Precio de Lista (MSRP): ${ingreso_lista:,.2f} USD\n"
        f"- Descuento Aplicado ({descuento_solicitado_pct:.1f}%): -${descuento_usd:,.2f} USD\n"
        f"- Valor Anual Neto del Contrato (ACV): ${acv_neto:,.2f} USD\n"
        f"- Costo Directo Estimado: ${costo_total:,.2f} USD | Utilidad Bruta: ${utilidad_bruta:,.2f} USD\n"
        f"- Margen Bruto Resultante: {margen_bruto_pct:.2f}% (Piso obligatorio: {piso_pct:.0f}%)\n"
        f"- Dictamen de Rentabilidad: {veredicto_margen}"
    )


def evaluar_autonomia_descuento(
    division: str,
    region: str,
    cantidad_unidades: int,
    descuento_solicitado_pct: float,
    margen_bruto_estimado_pct: float = 30.0,
    segmento_cliente: str = "Enterprise",
) -> str:
    """Evalúa determinísticamente la autonomía de descuento por división, región y volumen según la Sección 2 y Matriz DoA.

    Args:
        division: División comercial ('cloud', 'hardware' o 'servicios_profesionales').
        region: Región de la operación ('EMEA', 'Norteamérica', 'LATAM').
        cantidad_unidades: Cantidad de licencias o unidades en la cotización (ej: 18000).
        descuento_solicitado_pct: Descuento comercial solicitado en porcentaje (ej: 14.0).
        margen_bruto_estimado_pct: Margen bruto estimado de la operación en porcentaje (por defecto 30.0).
        segmento_cliente: Segmento del cliente ('Enterprise', 'Mid-Market', 'SMB').

    Returns:
        Estado oficial de la operación (PREAPROBADA, REQUIERE ESCALAMIENTO o BLOQUEADA), sección aplicable y aprobador DoA.
    """
    seg = segmento_cliente.strip().lower()
    piso = 30.0 if ("smb" in seg or "pyme" in seg) else (28.0 if "mid" in seg else 25.0)

    if margen_bruto_estimado_pct < piso:
        return (
            f"🛑 ESTADO: OPERACIÓN BLOQUEADA (Sección 1.3 — Nivel 5 DoA)\n"
            f"- Motivo: Aunque se solicite un {descuento_solicitado_pct:.1f}% de descuento, el margen bruto resultante "
            f"({margen_bruto_estimado_pct:.1f}%) viola el piso mínimo del {piso:.0f}% para {segmento_cliente}.\n"
            f"- Aprobador Obligatorio: Dispensa exclusiva del Executive Revenue Committee (ERC). "
            "Las firmas individuales de directores regionales carecen de validez."
        )

    div = division.strip().lower()
    if "cloud" in div:
        if cantidad_unidades > 15_000:
            tope_ae = 15.0
            tramo = "> 15,000 licencias (Enterprise Volume Tier)"
        elif cantidad_unidades >= 5_001:
            tope_ae = 10.0
            tramo = "5,001 a 15,000 licencias"
        else:
            tope_ae = 5.0
            tramo = "1 a 5,000 licencias"

        if descuento_solicitado_pct <= tope_ae:
            return (
                f"✅ ESTADO: PREAPROBADA — AUTÓNOMA (Sección 2.4 — Nivel 1 DoA)\n"
                f"- División: Cloud ({region}) | Tramo: {tramo} ({cantidad_unidades:,} licencias).\n"
                f"- Análisis: El descuento solicitado ({descuento_solicitado_pct:.1f}%) está dentro de la autonomía directa "
                f"del Account Executive (hasta {tope_ae:.0f}% preaprobado) y respeta el margen piso ({margen_bruto_estimado_pct:.1f}% >= {piso:.0f}%).\n"
                f"- Próximo Paso: Emitir la cotización directamente sin tickets de excepción ni escalamiento."
            )
        if descuento_solicitado_pct <= 25.0:
            return (
                f"⚠️ ESTADO: REQUIERE ESCALAMIENTO (Sección 2.4 — Nivel 2 DoA)\n"
                f"- División: Cloud ({region}) | Tramo: {tramo} ({cantidad_unidades:,} licencias).\n"
                f"- Análisis: El descuento solicitado ({descuento_solicitado_pct:.1f}%) supera el tramo autónomo del AE ({tope_ae:.0f}%).\n"
                f"- Aprobador Requerido: Autorización formal del Regional Sales Director."
            )
        return (
            f"⚠️ ESTADO: REQUIERE ESCALAMIENTO EJECUTIVO (Sección 2.4 / Sección 3)\n"
            f"- El descuento ({descuento_solicitado_pct:.1f}%) excede el umbral del 25% del Regional Sales Director; "
            "requiere revisión conjunta de VP of Sales Ops y validación estricta de margen piso."
        )

    if "hard" in div:
        if cantidad_unidades <= 1_000 and descuento_solicitado_pct <= 8.0:
            return (
                f"✅ ESTADO: PREAPROBADA — AUTÓNOMA (Sección 2.2 — Nivel 1 DoA)\n"
                f"- Hardware ({cantidad_unidades:,} unidades): Descuento ({descuento_solicitado_pct:.1f}%) dentro del tope autónomo del 8%."
            )
        if 1_001 <= cantidad_unidades <= 5_000 and descuento_solicitado_pct <= 12.0:
            return (
                f"⚠️ ESTADO: REQUIERE ESCALAMIENTO (Sección 2.2)\n"
                f"- Hardware ({cantidad_unidades:,} unidades, {descuento_solicitado_pct:.1f}%): Requiere aprobación del District Sales Manager."
            )
        return (
            f"⚠️ ESTADO: REQUIERE ESCALAMIENTO (Sección 2.2 — Nivel 2 DoA)\n"
            f"- Hardware ({cantidad_unidades:,} unidades, {descuento_solicitado_pct:.1f}%): Supera tramos estándar; requiere Regional Sales Director."
        )

    # Servicios Profesionales
    if descuento_solicitado_pct <= 5.0:
        return (
            f"✅ ESTADO: PREAPROBADA — AUTÓNOMA (Sección 2.3 — Nivel 1 DoA)\n"
            f"- Servicios Profesionales: Descuento ({descuento_solicitado_pct:.1f}%) dentro del máximo preaprobado del 5%."
        )
    return (
        f"⚠️ ESTADO: REQUIERE ESCALAMIENTO (Sección 2.3)\n"
        f"- Servicios Profesionales ({descuento_solicitado_pct:.1f}% > 5%): Requiere visto bueno formal del VP of Professional Services."
    )


def evaluar_plazo_credito(region: str, dias_credito: int) -> str:
    """Evalúa determinísticamente los términos de pago (Net 30, Net 45, Net 60, Net 90+) según la Sección 4 de gobernanza crediticia.

    Args:
        region: Región comercial del acuerdo ('LATAM', 'EMEA', 'Norteamérica' o 'Mercados Emergentes').
        dias_credito: Plazo de facturación solicitado en días (ej: 30, 45, 60, 90).

    Returns:
        Clasificación de riesgo financiero y firmas obligatorias según Sección 4.1 y 4.2.
    """
    reg_norm = region.strip().upper()
    es_latam_o_emergente = any(
        k in reg_norm for k in ("LATAM", "AMERICA LATINA", "AMÉRICA LATINA", "EMERGENTE", "MEXICO", "MÉXICO", "COLOMBIA", "CHILE", "BRASIL", "PERU", "PERÚ", "ARGENTINA")
    )

    if dias_credito <= 30:
        return (
            f"✅ PLAZO ESTÁNDAR PREAPROBADO (Sección 4.1 — Nivel 1 DoA)\n"
            f"- Condición Net {dias_credito} días en {region}: Es el estándar global por defecto. No requiere firmas adicionales."
        )

    if dias_credito <= 60:
        return (
            f"⚠️ EXTENSIÓN MODERADA — REQUIERE ESCALAMIENTO (Sección 4.1 — Nivel 3 DoA)\n"
            f"- Condición Net {dias_credito} días en {region}: Exige evaluación previa de solvencia y aprobación de Sales Operations (RevOps / VP of Sales Ops)."
        )

    if es_latam_o_emergente:
        return (
            f"⚠️ ALTO RIESGO FINANCIERO EN LATAM — ESCALAMIENTO DUAL OBLIGATORIO (Sección 4.2 — Nivel 4 DoA)\n"
            f"- Condición solicitada: Net {dias_credito} días en {region} (estándar global: Net 30 días).\n"
            f"- Regla Sección 4.2: Todo plazo superior a Net 60 días está catalogado como alto riesgo financiero. "
            f"Para LATAM y mercados emergentes exige OBLIGATORIAMENTE AMBAS aprobaciones conjuntas:\n"
            f"  1) Análisis y scoring favorable del Regional Credit Committee.\n"
            f"  2) Aprobación formal y firma del Finance Director LATAM.\n"
            f"- Advertencia operativa: Sin ambas aprobaciones registradas, el sistema de facturación rechazará automáticamente la orden."
        )

    return (
        f"⚠️ ALTO RIESGO FINANCIERO — REQUIERE ESCALAMIENTO (Sección 4.2 — Nivel 4 DoA)\n"
        f"- Condición Net {dias_credito} días en {region} (> Net 60 días): Requiere aprobación del Regional Credit Committee y CFO Regional."
    )


# ============================================================================
# CARGA MODULAR DE SKILLS (SkillToolset), PROMPT MARKDOWN Y SERVIDOR MCP
# ============================================================================

_PROMPT_FILE = _APP_DIR / "prompts" / "cymbal_sales_system_prompt.md"
_SYSTEM_INSTRUCTION = _sanitize_adk_braces(
    _PROMPT_FILE.read_text(encoding="utf-8")
    if _PROMPT_FILE.exists()
    else (
        "Eres Vera, Concierge de Operaciones de Ventas y Gobernanza Comercial de Cymbal Group. "
        "Responde en español fundamentándote estrictamente en la política comercial oficial."
    )
)

_TOOLS: list[Any] = [
    calcular_cotizacion_y_margen,
    evaluar_autonomia_descuento,
    evaluar_plazo_credito,
]

# 1. Conecta las ADK Runtime Skills (validador-politicas-ventas y redactor-escalamiento-comercial)
_SKILLS_DIR = _APP_DIR / "skills"
_LOADED_SKILLS = []
for _skill_name in ("validador-politicas-ventas", "redactor-escalamiento-comercial"):
    _skill_path = _SKILLS_DIR / _skill_name
    if (_skill_path / "SKILL.md").exists():
        _sk = load_skill_from_dir(_skill_path)
        _sk.instructions = _sanitize_adk_braces(_sk.instructions)
        _LOADED_SKILLS.append(_sk)

if _LOADED_SKILLS:
    _TOOLS.append(SkillToolset(skills=_LOADED_SKILLS))

# 2. Conecta automáticamente el Servidor MCP de RevOps (SQLite) si app/mcp_revops.py está presente
_MCP_SCRIPT = _APP_DIR / "mcp_revops.py"
if _MCP_SCRIPT.exists():
    try:
        from google.adk.tools.mcp_tool.mcp_toolset import McpToolset
        from mcp import StdioServerParameters
    except ImportError:
        import subprocess

        subprocess.run(
            ["uv", "pip", "install", "--python", sys.executable, "mcp>=1.8.0,<2.0.0"],
            check=False,
        )
        from google.adk.tools.mcp_tool.mcp_toolset import McpToolset
        from mcp import StdioServerParameters

    _TOOLS.append(
        McpToolset(
            connection_params=StdioServerParameters(
                command=sys.executable,
                args=[str(_MCP_SCRIPT)],
            ),
        )
    )

_SAFETY_SETTINGS = [
    types.SafetySetting(
        category=types.HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT,
        threshold=types.HarmBlockThreshold.BLOCK_LOW_AND_ABOVE,
    ),
    types.SafetySetting(
        category=types.HarmCategory.HARM_CATEGORY_HARASSMENT,
        threshold=types.HarmBlockThreshold.BLOCK_LOW_AND_ABOVE,
    ),
    types.SafetySetting(
        category=types.HarmCategory.HARM_CATEGORY_HATE_SPEECH,
        threshold=types.HarmBlockThreshold.BLOCK_LOW_AND_ABOVE,
    ),
    types.SafetySetting(
        category=types.HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT,
        threshold=types.HarmBlockThreshold.BLOCK_LOW_AND_ABOVE,
    ),
]

root_agent = Agent(
    name="root_agent",
    model=Gemini(
        model=MODEL,
        retry_options=types.HttpRetryOptions(attempts=3),
    ),
    generate_content_config=types.GenerateContentConfig(
        temperature=0.1,
        safety_settings=_SAFETY_SETTINGS,
    ),
    before_model_callback=guardrail_entrada_comercial,
    before_tool_callback=guardrail_parametros_herramientas,
    instruction=lambda _: _SYSTEM_INSTRUCTION,
    tools=_TOOLS,
)

app = App(
    root_agent=root_agent,
    name="app",
)
