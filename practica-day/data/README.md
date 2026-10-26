# 📚 Activos Normativos — Cymbal Group Sales Operations

Esta carpeta contiene la base documental oficial simulada (**Documento ID: `CG-SOP-2026-V1`**) utilizada como fuente de verdad (*Single Source of Truth*) para fundamentar las respuestas del agente y de las Skills No-Code durante el taller.

## Contenido del Directorio

| Archivo | Formato | Propósito en la Arquitectura |
| :--- | :--- | :--- |
| [`cymbal_sales_governance_policy.md`](./cymbal_sales_governance_policy.md) | Markdown (`UTF-8`) | Fuente normativa estructurada para desarrollo rápido local y pruebas unitarias deterministas sin latencia de red. |
| [`Cymbal_Group_Sales_Policy.pdf`](./Cymbal_Group_Sales_Policy.pdf) | PDF | Documento corporativo listo para cargar en **Google Cloud Storage (GCS)** o en **Data Stores de Gemini Enterprise** (Agent Designer). |

## Resumen de Secciones Normativas (`CG-SOP-2026-V1`)

1. **Sección 1 — Pisos de Margen Bruto (*Gross Margin Floor*):**
   - `30%` SMB / Commercial | `28%` Mid-Market | `25%` Enterprise / Global Strategic.
   - Operaciones bajo el piso quedan **bloqueadas**; solo el **Executive Revenue Committee (ERC)** puede otorgar dispensa.
2. **Sección 2 — Matriz de Descuentos Comerciales y Autonomía por División:**
   - Hardware & Infraestructura, Servicios Profesionales y Cloud (EMEA y Norteamérica, con hasta **15% preaprobado autónomo** en compras `> 15,000` licencias).
3. **Sección 3 — Matriz de Delegación de Autoridad (*DoA*, Niveles 1 al 5):**
   - Desde *Account Executive* (Nivel 1) hasta *Executive Revenue Committee* (Nivel 5).
4. **Sección 4 — Gobernanza de Plazos de Crédito (*Credit Terms*):**
   - Estándar global `Net 30`. Plazos de alto riesgo (`Net 90` en LATAM) exigen aprobación dual obligatoria del **Regional Credit Committee** + firma del **Finance Director LATAM**.

---

⬅️ Volver al [Inicio del Repositorio](../README.md) | 📖 Ver instrucciones de generación en [`00-contexto-y-datos.md`](../00-contexto-y-datos.md)
