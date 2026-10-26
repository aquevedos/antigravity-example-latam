---
name: validador-politicas-ventas
description: Manual normativo oficial CG-SOP-2026-V1 de Cymbal Group con pisos de margen bruto (Sección 1), descuentos máximos por división y volumen (Sección 2), matriz de delegación de autoridad DoA Niveles 1 al 5 (Sección 3) y gobernanza de plazos de crédito Net 30, Net 45, Net 60 y Net 90 en LATAM, EMEA y Norteamérica (Sección 4).
---

# Skill: Validador de Políticas de Ventas y Gobernanza Comercial (`validador-politicas-ventas`)

Utiliza esta skill siempre que el usuario consulte:
1. Si un porcentaje de descuento por volumen está preaprobado o requiere escalamiento;
2. Si un margen bruto estimado cumple o infringe el piso mínimo (*Gross Margin Floor*) del segmento;
3. Qué firmas o comités exige un plazo de pago extendido (`Net 45`, `Net 60` o `Net 90`, especialmente en `LATAM`).

## Procedimiento Obligatorio
1. Carga el documento oficial `references/politica_gobernanza_comercial.md` usando `load_skill_resource`.
2. Combina la lectura normativa con las herramientas deterministas `evaluar_autonomia_descuento`, `calcular_cotizacion_y_margen` o `evaluar_plazo_credito` para confirmar cálculos exactos sin suposiciones.
3. Si la consulta menciona un cliente o SKU específico de Cymbal Group, consulta primero el servidor MCP (`consultar_catalogo_precios` o `consultar_riesgo_crediticio_cliente`).
