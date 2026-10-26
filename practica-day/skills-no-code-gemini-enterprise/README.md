# 🧩 Guía Práctica: Skills No-Code y Agent Designer en Gemini Enterprise

⬅️ [Volver al Inicio del Repositorio](../README.md) | 🛠️ [Ir al Laboratorio Pro-Code con ADK (`02-guia-paso-a-paso.md`)](../02-guia-paso-a-paso.md)

---

Esta sección está diseñada para que **analistas de operaciones comerciales (RevOps), líderes de negocio, finanzas y RR. HH.** puedan crear, subir y probar **Skills sin código** dentro de **Gemini Enterprise**, así como reutilizarlas en **Agentes No-Code con Agent Designer**.

---

## 1. ¿Qué es una Skill en Gemini Enterprise?

Una **Skill** es un paquete reutilizable de instrucciones en lenguaje natural (guardado en un archivo [`SKILL.md`](./plantilla-mi-primer-skill/SKILL.md)) que enseña al asistente de Gemini Enterprise a ejecutar un proceso normativo o de negocio con precisión:

- **Cero código:** No requiere programar en Python ni administrar infraestructura; solo redactar reglas claras, pasos y tablas en Markdown.
- **Activación inteligente:** Gemini Enterprise analiza el campo `description` y activa la skill automáticamente cuando detecta una consulta relacionada, o de forma explícita con `/` o `@`.
- **Portabilidad inmediata:** Cualquier archivo `SKILL.md` válido puede compartirse en GitHub e importarse directamente desde el navegador.

---

## 2. Anatomía de un Archivo `SKILL.md`

Todo archivo `SKILL.md` consta de **dos bloques**: el encabezado de metadatos (*YAML frontmatter* entre líneas `---`) y las instrucciones estructuradas en Markdown.

```markdown
---
name: nombre-corto-con-guiones
description: Explica qué hace la skill y CUÁNDO debe activarse. Gemini lee este texto para saber cuándo usarla automáticamente.
---

# Título Visible de la Skill

## 1. Rol y Objetivo
Define el perfil experto del asistente y qué problema de negocio resuelve.

## 2. Reglas de Negocio (Qué sí y qué no hacer)
- Regla 1 (ej. umbrales financieros, límites de aprobación, tono ejecutivo).
- Regla 2 (ej. respuesta exacta cuando un caso no aparece en la política).

## 3. Pasos para Responder
1. Extraer los parámetros clave de la consulta del usuario.
2. Contrastar contra la tabla normativa incluida.
3. Emitir el dictamen en el formato estándar.

## 4. Formato de Salida
Especifica la estructura visual esperada (estado semafórico, tabla o memorando).
```

> [!IMPORTANT]
> **Regla de oro:** Las tres líneas `---` iniciales deben comenzar exactamente en la **línea 1** del archivo, sin líneas en blanco ni títulos previos.

---

## 3. Cómo Crear o Importar una Skill en Gemini Enterprise

### Opción A: Crear la Skill conversando con Gemini (100% Visual)
1. Inicia sesión en la aplicación web de **Gemini Enterprise**.
2. En el panel lateral izquierdo, selecciona **Skills**.
3. Haz clic en **+** y elige **Create skill with Gemini**.
4. Completa el **Nombre** y la **Descripción** indicando cuándo debe activarse.
5. Pega las instrucciones en lenguaje natural (puedes copiar cualquiera de los ejemplos de esta carpeta) y haz clic en **Save**.

### Opción B: Subir un archivo `SKILL.md` listo (Recomendado)
1. En el menú izquierdo de **Gemini Enterprise**, abre **Skills**.
2. Haz clic en **+** y selecciona **Upload skill**.
3. Sube cualquiera de los archivos listos de este directorio (por ejemplo, [`01-validador-politicas-ventas/SKILL.md`](./01-validador-politicas-ventas/SKILL.md)).
4. Haz clic en **Import**; Gemini extraerá el nombre y la descripción automáticamente.

### Opción C: Subir un paquete `.zip` con documentos de referencia
Cuando tu skill necesita apoyarse en manuales extensos:
- El archivo `SKILL.md` **debe ubicarse en la raíz del `.zip`** (no dentro de una subcarpeta anidada).
- Puedes incluir una subcarpeta `references/` con manuales o anexos normativos.
- Tienes el archivo [`01-validador-politicas-ventas.zip`](./01-validador-politicas-ventas.zip) listo para probar directamente en **Skills → + → Upload skill**.

---

## 4. Cómo Invocar y Probar tu Skill en el Chat

| Método | Cómo usarlo | Ejemplo práctico de prueba |
| :--- | :--- | :--- |
| **Menú rápido (`/`)** | Escribe `/` en la caja de chat para listar tus skills activas. | `/validador-politicas-ventas Un cliente EMEA pide 14% de descuento en 18,000 licencias Cloud.` |
| **Mención (`@`)** | Escribe `@` y elige el nombre de la skill. | `@redactor-escalamiento-comercial Necesito pedir excepción por margen bruto del 19% en Norteamérica.` |
| **Automático** | Escribe tu consulta de forma natural; Gemini la activará según su `description`. | `¿Me reembolsan una película del televisor del hotel y una cena de 110 CHF en Zúrich?` |

---

## 5. De Skill a Agente Empresarial en Agent Designer (No-Code)

> [!TIP]
> En el chat de Gemini Enterprise no se invoca un `@Agente` y una `/Skill` simultáneamente en el mismo mensaje. Si deseas publicar un **Agente No-Code compartido para toda un área** usando **Agent Designer**:

1. Abre **Agent Designer** en Gemini Enterprise y crea un nuevo agente (recomendando identidad visual limpia en **tonos pasteles de Google Cloud**).
2. Copia las secciones **Rol, Reglas, Pasos y Formato** de tu `SKILL.md` en el campo **Instructions** del agente.
3. Adjunta tus documentos oficiales en PDF (como [`../data/Cymbal_Group_Sales_Policy.pdf`](../data/Cymbal_Group_Sales_Policy.pdf)) dentro de **Data Stores** para habilitar fundamentación documental (*grounding*).
4. Valida los escenarios A, B y C en el panel **Preview** y haz clic en **Publish**.

---

## 6. Catálogo de Recursos Incluidos en esta Carpeta

| Recurso | Propósito de Negocio | Qué Aprenderás |
| :--- | :--- | :--- |
| [`01-validador-politicas-ventas/SKILL.md`](./01-validador-politicas-ventas/SKILL.md) | Validar descuentos comerciales, márgenes piso y plazos `Net 30/60/90`. | Traducir políticas financieras y matrices *DoA* en una skill determinista. |
| [`01-validador-politicas-ventas.zip`](./01-validador-politicas-ventas.zip) | Paquete `.zip` con `SKILL.md` en la raíz + anexos en `references/`. | Empaquetar e importar skills con documentación de respaldo. |
| [`02-redactor-escalamiento-comercial/SKILL.md`](./02-redactor-escalamiento-comercial/SKILL.md) | Redactar memorandos ejecutivos de excepción para Finanzas, Crédito o el *ERC*. | Validar datos faltantes con marcadores `[COMPLETAR]` antes de emitir un correo. |
| [`03-auditor-gastos-viaje-rrhh/SKILL.md`](./03-auditor-gastos-viaje-rrhh/SKILL.md) | Auditar reportes de gastos de viaje (vuelos `< 6h`, comidas en Suiza, hotel). | Clasificar ítems en tablas de reembolsables, parciales y excluidos. |
| [`plantilla-mi-primer-skill/SKILL.md`](./plantilla-mi-primer-skill/SKILL.md) | Plantilla guiada lista para rellenar. | Diseñar tu propia skill departamental desde cero en 5 minutos. |
