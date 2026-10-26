---
name: redactor-escalamiento-comercial
description: Guía ejecutiva y plantillas oficiales de memorandos para solicitar aprobaciones de excepción comercial ante el Regional Sales Director, RevOps, el Regional Credit Committee + Finance Director LATAM o el Executive Revenue Committee (ERC).
---

# Skill: Redactor de Escalamiento Comercial (`redactor-escalamiento-comercial`)

Utiliza esta skill siempre que una cotización **requiera escalamiento** o esté **bloqueada por margen piso** y el ejecutivo necesite redactar el memorando o correo formal de aprobación.

## Procedimiento Obligatorio
1. Carga el archivo `references/plantillas_memorandos_doa.md` usando `load_skill_resource`.
2. Consulta `consultar_precedentes_excepciones` en el servidor MCP para enriquecer la solicitud con las garantías de mitigación recomendadas por Finanzas/ERC.
3. Si falta algún dato del cliente, incluye marcadores visibles entre corchetes como `[COMPLETAR: Valor ACV]` para que el vendedor lo revise antes de enviar.
