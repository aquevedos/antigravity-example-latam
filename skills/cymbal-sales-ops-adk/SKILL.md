---
name: cymbal-sales-ops-adk
description: Especialista en ingeniería de agentes de Operaciones Comerciales y Gobernanza (Sales Ops & RevOps) con Google ADK, cálculos financieros deterministas (ACV, Margen Bruto, Matriz DoA, Términos de Crédito), servidores MCP con FastMCP + SQLite, interfaces en colores pasteles de Google Cloud e infraestructura declarativa en Terraform para cymbal-sales-ops-agent.
---

# ☁️ Skill: Cymbal Sales Ops & Governance ADK (`cymbal-sales-ops-adk`)

Utiliza esta skill siempre que el usuario pida extender las herramientas financieras, agregar políticas regionales, conectar servidores **MCP (`McpToolset`)**, personalizar la interfaz visual o ampliar el dataset de evaluación (`tests/eval/datasets/basic-dataset.json`) del proyecto **`cymbal-sales-ops-agent`**.

## 1. Fórmulas Financieras Deterministas (Cero Alucinaciones Numéricas)

Implementa siempre los cálculos comerciales en funciones puras de Python (nunca dejes que el LLM estime márgenes ni descuentos mentalmente):

1. **Cotización Anual (`ACV`) y Margen Bruto (`Gross Margin %`):**
   - `ingreso_lista_usd = cantidad_unidades * precio_lista_unitario_usd`
   - `acv_neto_usd = ingreso_lista_usd * (1.0 - (descuento_pct / 100.0))`
   - `costo_total_usd = cantidad_unidades * costo_unitario_usd`
   - `margen_bruto_pct = ((acv_neto_usd - costo_total_usd) / acv_neto_usd) * 100.0`

2. **Pisos de Margen Bruto Innegociables (`CG-SOP-2026-V1` Sección 1):**
   - `SMB / Commercial`: mínimo `30.0%`
   - `Mid-Market`: mínimo `28.0%`
   - `Enterprise / Global Strategic`: mínimo `25.0%`
   - Si `margen_bruto_pct < piso_segmento`, la operación queda **BLOQUEADA** y exige dispensa exclusiva del **Executive Revenue Committee (ERC)** (Nivel 5 DoA).

3. **Autonomía Comercial en Cloud EMEA / Norteamérica (Sección 2.4):**
   - `1 a 5,000` licencias: hasta `5%` preaprobado autónomo.
   - `5,001 a 15,000` licencias: hasta `10%` preaprobado autónomo.
   - `> 15,000` licencias: hasta **`15%` preaprobado autónomo** (sin tickets ni escalamiento).
   - `16% a 25%`: requiere aprobación del **Regional Sales Director**.

4. **Gobernanza de Crédito Regional (Sección 4.2):**
   - `Net 30`: estándar global preaprobado.
   - `Net 45` / `Net 60`: evaluación de solvencia + aprobación de **Sales Operations (RevOps)**.
   - `Net 90+` en **LATAM y mercados emergentes**: requiere obligatoriamente **aprobación dual** del **Regional Credit Committee** + firma del **Finance Director LATAM**.

## 2. Patrón de Integración MCP en Google ADK (`McpToolset`)

Conecta siempre el servidor `FastMCP` usando `sys.executable` para garantizar que el subproceso se ejecute dentro del mismo `.venv` administrado por `uv`, y usa consultas parametrizadas (`?`) en SQLite:

```python
from pathlib import Path
import sys
from google.adk.tools.mcp_tool.mcp_toolset import McpToolset
from mcp import StdioServerParameters

revops_mcp = McpToolset(
    connection_params=StdioServerParameters(
        command=sys.executable,
        args=[str(Path(__file__).parent / "mcp_revops.py")],
    ),
)
```

## 3. Estándar Visual (Colores de Google Cloud y Tonos Pasteles)

Toda interfaz web (`ui.py`) o diagrama de arquitectura debe emplear la paleta pastel oficial de Google Cloud:
- **Azul Pastel (Informativo):** Fondo `#E8F0FE`, borde `#AECBFA`, texto `#174EA6`
- **Verde Pastel (Preaprobada):** Fondo `#E6F4EA`, borde `#A8DAB5`, texto `#0D652D`
- **Amarillo Pastel (Escalamiento DoA):** Fondo `#FEF7E0`, borde `#FDE293`, texto `#B06000`
- **Rojo Pastel (Bloqueada):** Fondo `#FCE8E6`, borde `#F6AEA9`, texto `#A50E0E`

## 4. Evaluación Automatizada en `agents-cli`

- El dataset principal reside en **`tests/eval/datasets/basic-dataset.json`** y se ejecuta mediante `agents-cli eval run`.
- Cada caso en `"eval_cases"` debe definir `"eval_case_id"`, `"prompt"` (`role: "user"`) y `"reference"` (`response.role: "model"`).
