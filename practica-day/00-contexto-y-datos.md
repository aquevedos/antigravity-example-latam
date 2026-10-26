# 00 — Contexto de Negocio y Preparación de Datos Normativos

⬅️ [Volver al Inicio](./README.md) | ➡️ [Siguiente: `01-spec.md` (Especificación del Agente)](./01-spec.md)

---

## 1. Escenario Empresarial: Cymbal Group (Sales Operations & RevOps)

En cualquier corporación global, uno de los mayores cuellos de botella en el ciclo de ingresos (*Quote-to-Cash*) es la **fricción operativa entre los equipos de Ventas y las áreas de Operaciones Comerciales (Sales Ops / RevOps), Finanzas y Legal**. Los ejecutivos de cuenta suelen perder días o semanas esperando validaciones sobre descuentos especiales, márgenes mínimos o términos de crédito antes de poder emitir una cotización formal.

### Tu Rol en el Taller
Actúas como **Arquitecto de Plataforma / Customer Engineer en Google Cloud** asesorando a **Cymbal Group**. El Vicepresidente de Operaciones Comerciales (*VP of Sales Operations*) identificó un desafío crítico tras varios años de fusiones y adquisiciones consecutivas:

- Los equipos comerciales navegan por un ecosistema fragmentado de portales internos, tablas de políticas dispersas, cotizadores heredados y hojas de cálculo departamentales.
- Los vendedores carecen de visibilidad inmediata sobre **umbrales de autonomía comercial**, **pisos de margen bruto (*Gross Margin Floor*)**, **matrices de delegación de autoridad (*DoA*)** y **plazos de crédito regionales**.
- El área de Finanzas recibe cientos de tickets manuales por operaciones que ya estaban preaprobadas en la política o que, por el contrario, violan pisos de rentabilidad innegociables.

---

## 2. Objetivo de la Solución

Construir y gobernar un **Asistente Interno de Operaciones de Ventas (`cymbal-sales-ops-agent`)** de extremo a extremo sobre Google Cloud que:

1. **Comprenda cada consulta comercial** identificando división de negocio, región, volumen de licencias/unidades, descuento solicitado, margen bruto resultante y plazo de facturación.
2. **Recupere y aplique estrictamente la normativa oficial** (`CG-SOP-2026-V1`), garantizando *Zero Hallucination* en cifras financieras y contractuales.
3. **Acelere el desarrollo mediante *Spec-Driven Development*** con **Google Antigravity**, **Google ADK (Agent Development Kit)** y **`agents-cli`**.
4. **Ofrezca una experiencia visual corporativa clara** en Python (**Streamlit**) diseñada con **colores de Google Cloud en tonos pasteles**, diferenciando visualmente operaciones preaprobadas, escalamientos y bloqueos de margen.
5. **Se despliegue bajo guardarraíles empresariales** utilizando **Terraform IaC**, cuentas de servicio con privilegios mínimos (IAM), **Agent Runtime**, **Gemini Enterprise** y evaluación continua de calidad (*LLM-as-a-Judge*).

---

## 3. Activos Normativos Listos para Usar

> [!TIP]
> **¡Ya incluidos en el repositorio!** Los documentos normativos ya se encuentran generados dentro de la carpeta [`./data/`](./data/), por lo que puedes pasar directamente a [`01-spec.md`](./01-spec.md) si estás realizando el taller rápido en local.

- **Versión Markdown (lectura local inmediata):** [`data/cymbal_sales_governance_policy.md`](./data/cymbal_sales_governance_policy.md)
- **Versión PDF (para Cloud Storage / Data Stores):** [`data/Cymbal_Group_Sales_Policy.pdf`](./data/Cymbal_Group_Sales_Policy.pdf)

---

## 4. (Opcional) Regenerar los Activos y Publicarlos en Google Cloud Storage

Si deseas simular desde cero la creación del documento normativo oficial y su aprovisionamiento seguro en un bucket de **Google Cloud Storage (GCS)** para entornos productivos, ejecuta los siguientes pasos desde la raíz de este repositorio:

### Paso 4.1: Generar el documento fuente en Markdown

```bash
mkdir -p data

cat << 'EOF' > data/cymbal_sales_governance_policy.md
# Cymbal Group Global Sales Operations Governance and Pricing Policy
Document ID: CG-SOP-2026-V1
Classification: Confidential - Internal Sales & RevOps Use Only

## Sección 1: Pisos de Margen Bruto y Rentabilidad Mínima (Gross Margin Floor)
1.1 Objetivo: Garantizar la rentabilidad de todas las transacciones comerciales a nivel global.
1.2 Pisos de Margen Estándar:
  - Cuentas SMB / Commercial: Margen bruto mínimo obligatorio del 30%.
  - Cuentas Mid-Market: Margen bruto mínimo obligatorio del 28%.
  - Cuentas Enterprise / Global Strategic: Margen bruto mínimo innegociable del 25%.
1.3 Excepciones de Margen Piso:
  - Cualquier operación que resulte en un margen bruto inferior al 25% para Enterprise (o inferior al 28% para Mid-Market) queda automáticamente BLOQUEADA en el sistema de cotizaciones.
  - La única instancia facultada para otorgar dispensa comercial por debajo del margen piso es el Executive Revenue Committee (ERC). No tienen validez las aprobaciones unilaterales de directores de ventas ni gerentes regionales.

## Sección 2: Matriz de Descuentos Comerciales y Autonomía por División
2.1 Reglas Generales: Los descuentos se calculan sobre el precio de lista (MSRP) y dependen del volumen unitario o ACV (Annual Contract Value).
2.2 División Hardware & Infraestructura:
  - Hasta 1 000 unidades: Descuento máximo preaprobado del 8%.
  - 1 001 a 5 000 unidades: Descuento máximo del 12% (Requiere District Sales Manager).
2.3 División Servicios Profesionales:
  - Descuento máximo preaprobado: 5%. Todo descuento superior requiere visto bueno del VP of Professional Services.
2.4 División Cloud (EMEA y Norteamérica):
  - Compras de 1 a 5 000 licencias: Descuento autónomo del Account Executive de hasta el 5%.
  - Compras de 5 001 a 15 000 licencias: Descuento autónomo del Account Executive de hasta el 10%.
  - Compras superiores a 15 000 licencias (Enterprise Volume Tier): El Account Executive (AE) tiene autonomía de hasta el 15% de descuento directo preaprobado. Puede emitir la cotización directamente sin requerir escalamiento ni tickets de excepción.
  - Descuentos del 16% al 25%: Requieren autorización explícita del Regional Sales Director.

## Sección 3: Delegación de Autoridad (Delegation of Authority - DoA)
3.1 Matriz de Aprobaciones:
  - Nivel 1 (Account Executive): Autonomía según tabla de volumen (Sección 2).
  - Nivel 2 (Regional Sales Director): Descuentos hasta 20% en Cloud o contratos de hasta $500,000 USD.
  - Nivel 3 (VP of Sales Ops / RevOps Partner): Términos de pago no estándar hasta Net 60 días.
  - Nivel 4 (CFO Regional / Regional Credit Committee): Términos de pago de alto riesgo (Net 90 o superior) y contratos multilocalidad.
  - Nivel 5 (Executive Revenue Committee): Dispensas de margen piso (Gross Margin < 25%).

## Sección 4: Gobernanza de Plazos de Crédito y Facturación (Credit Terms)
4.1 Condiciones Estándar:
  - La condición contractual estándar por defecto a nivel global es Net 30 días.
  - Extensión a Net 45 o Net 60: Requiere evaluación de solvencia previa y aprobación de Sales Operations (RevOps).
4.2 Plazos de Crédito Fuera de Estándar (Alto Riesgo Financiero):
  - Plazos superiores a Net 60 días (incluyendo Net 90 días): Catalogados como riesgo financiero alto.
  - Para la región LATAM y mercados emergentes, cualquier solicitud de Net 90 días exige obligatoriamente:
    a) Análisis y scoring de riesgo del Regional Credit Committee.
    b) Aprobación formal y firma del Finance Director LATAM.
    c) Sin ambas aprobaciones, el sistema de facturación rechazará la orden.
EOF
```

### Paso 4.2: Compilar el archivo PDF oficial con `uv`

```bash
uv run --with fpdf2 python -c '
from fpdf import FPDF
import os

os.makedirs("data", exist_ok=True)

class SafePDF(FPDF):
    def header(self):
        self.set_font("Helvetica", "B", 12)
        self.cell(0, 10, "Cymbal Group - Commercial Governance Policy", align="C")
        self.ln(12)

pdf = SafePDF()
pdf.set_margins(left=20, top=20, right=20)
pdf.add_page()
pdf.set_font("Helvetica", size=10)

with open("data/cymbal_sales_governance_policy.md", "r", encoding="utf-8") as f:
    for line in f:
        text = line.strip()
        if not text:
            pdf.ln(4)
            continue

        clean = text.encode("latin-1", "replace").decode("latin-1")

        if clean.startswith("# "):
            pdf.set_font("Helvetica", "B", 14)
            pdf.multi_cell(w=pdf.epw, h=8, text=clean.replace("# ", ""))
            pdf.set_font("Helvetica", size=10)
            pdf.ln(2)
        elif clean.startswith("## "):
            pdf.set_font("Helvetica", "B", 11)
            pdf.multi_cell(w=pdf.epw, h=7, text=clean.replace("## ", ""))
            pdf.set_font("Helvetica", size=10)
            pdf.ln(1)
        else:
            pdf.multi_cell(w=pdf.epw, h=5, text=clean)

pdf.output("data/Cymbal_Group_Sales_Policy.pdf")
print("PDF generado exitosamente en: data/Cymbal_Group_Sales_Policy.pdf")
'
```

### Paso 4.3: Crear el Bucket Normativo en Cloud Storage (Buenas Prácticas de Gobernanza)

> [!IMPORTANT]
> Siguiendo estándares de seguridad empresarial en Google Cloud, habilitamos **acceso uniforme a nivel de bucket** (`--uniform-bucket-level-access`) y **prevención de acceso público** (`--public-access-prevention`) desde su creación.

```bash
export GCP_PROJECT_ID="<TU_PROYECTO_GCP>"
export GCP_REGION="us-central1"
export GCS_POLICY_BUCKET="${GCP_PROJECT_ID}-cymbal-sales-policies"

# 1. Crear el bucket seguro en la región del proyecto
gcloud storage buckets create "gs://${GCS_POLICY_BUCKET}" \
  --project="${GCP_PROJECT_ID}" \
  --location="${GCP_REGION}" \
  --uniform-bucket-level-access \
  --public-access-prevention

# 2. Subir el PDF normativo oficial
gcloud storage cp data/Cymbal_Group_Sales_Policy.pdf "gs://${GCS_POLICY_BUCKET}/Cymbal_Group_Sales_Policy.pdf"
```

---

➡️ **Continúa con la Especificación Técnica del Agente:** [`01-spec.md`](./01-spec.md)
