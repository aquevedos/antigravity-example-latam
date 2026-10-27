#!/usr/bin/env python3
# ruff: noqa
# Copyright 2026 Google LLC
# SPDX-License-Identifier: Apache-2.0
"""Servidor MCP de Operaciones Comerciales (RevOps) de Cymbal Group (SQLite)."""

import os
from pathlib import Path
import sqlite3
import tempfile

try:
    from mcp.server.fastmcp import FastMCP
except ModuleNotFoundError:
    from mcp.server.mcpserver import MCPServer as FastMCP

mcp = FastMCP("cymbal-revops-mcp")

_DEFAULT_DB = Path(__file__).resolve().parent / "revops_cymbal.db"
if os.access(_DEFAULT_DB.parent, os.W_OK) and (
    not _DEFAULT_DB.exists() or os.access(_DEFAULT_DB, os.W_OK)
):
    DB_PATH = _DEFAULT_DB
else:
    DB_PATH = Path(tempfile.gettempdir()) / "revops_cymbal.db"


def _init_db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS catalogo_skus (
            sku TEXT PRIMARY KEY,
            division TEXT NOT NULL,
            nombre TEXT NOT NULL,
            precio_lista_usd REAL NOT NULL,
            costo_unitario_usd REAL NOT NULL,
            unidad TEXT NOT NULL
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS clientes_corporativos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL UNIQUE,
            region TEXT NOT NULL,
            segmento TEXT NOT NULL,
            credit_score TEXT NOT NULL,
            plazo_actual_dias INTEGER NOT NULL,
            estado_cartera TEXT NOT NULL
        )
        """
    )

    cur_skus = conn.execute("SELECT COUNT(*) FROM catalogo_skus")
    if cur_skus.fetchone()[0] == 0:
        seed_skus = [
            (
                "CLD-ENT-SUITE",
                "cloud",
                "Cymbal Cloud Enterprise Suite",
                100.00,
                58.32,
                "licencia/año",
            ),
            (
                "CLD-DATA-AI",
                "cloud",
                "Cymbal Data & Vertex AI Workspace",
                250.00,
                145.80,
                "licencia/año",
            ),
            (
                "HW-EDGE-X9",
                "hardware",
                "Servidor Cymbal Edge Appliance X9",
                4500.00,
                2970.00,
                "unidad",
            ),
            (
                "HW-NET-CORE",
                "hardware",
                "Switch Cymbal Fabric Core 100G",
                2200.00,
                1430.00,
                "unidad",
            ),
            (
                "PS-ARCH-ENT",
                "servicios_profesionales",
                "Consultoría Arquitectura Cloud & Landing Zone",
                1800.00,
                1170.00,
                "jornada",
            ),
        ]
        conn.executemany(
            """
            INSERT INTO catalogo_skus
            (sku, division, nombre, precio_lista_usd, costo_unitario_usd, unidad)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            seed_skus,
        )

    cur_cli = conn.execute("SELECT COUNT(*) FROM clientes_corporativos")
    if cur_cli.fetchone()[0] == 0:
        seed_clientes = [
            (
                "Nordic FinTech Group",
                "EMEA",
                "Enterprise",
                "AAA (93/100)",
                30,
                "Al día — 4 años de antigüedad sin mora",
            ),
            (
                "Andes Retail Holding",
                "LATAM",
                "Enterprise",
                "BBB+ (76/100)",
                30,
                "Al día — Solicita expansión regional en Colombia, Chile y México",
            ),
            (
                "Pacific Motors Corp",
                "Norteamérica",
                "Enterprise",
                "AA (88/100)",
                30,
                "Al día — Acuerdo estratégico competitivo de renovación",
            ),
            (
                "Soluciones Andinas PyME",
                "LATAM",
                "SMB",
                "BB (62/100)",
                30,
                "Cuenta nueva — Requiere validación de solvencia para plazos extendidos",
            ),
            (
                "Iberia Telco MidMarket",
                "EMEA",
                "Mid-Market",
                "A- (81/100)",
                30,
                "Al día — Renovación anual activa",
            ),
        ]
        conn.executemany(
            """
            INSERT INTO clientes_corporativos
            (nombre, region, segmento, credit_score, plazo_actual_dias, estado_cartera)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            seed_clientes,
        )
    conn.commit()
    return conn


@mcp.tool()
def consultar_catalogo_precios(division: str = "todas") -> str:
    """Consulta en SQLite el catálogo oficial de SKUs de Cymbal Group (precios de lista MSRP en USD y costos unitarios).

    Args:
        division: Filtro opcional ('todas', 'cloud', 'hardware', 'servicios_profesionales').

    Returns:
        Tabla de SKUs con precio de lista MSRP y costo base unitario para cálculos de margen bruto.
    """
    conn = _init_db()
    div_norm = division.strip().lower()
    if div_norm in ("cloud", "hardware", "servicios_profesionales"):
        rows = conn.execute(
            "SELECT sku, division, nombre, precio_lista_usd, costo_unitario_usd, unidad FROM catalogo_skus WHERE division = ? ORDER BY sku",
            (div_norm,),
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT sku, division, nombre, precio_lista_usd, costo_unitario_usd, unidad FROM catalogo_skus ORDER BY division, sku"
        ).fetchall()
    conn.close()

    lineas = ["📦 Catálogo Oficial de Precios y Costos Cymbal Group (SQLite MCP):"]
    for sku, div, nombre, msrp, costo, unidad in rows:
        margen_lista = ((msrp - costo) / msrp) * 100.0 if msrp > 0 else 0.0
        lineas.append(
            f"- [{sku}] {nombre} ({div}) | MSRP: ${msrp:,.2f} USD/{unidad} | Costo base: ${costo:,.2f} USD | Margen a precio lista: {margen_lista:.1f}%"
        )
    return "\n".join(lineas)


@mcp.tool()
def consultar_riesgo_crediticio_cliente(busqueda: str = "todos") -> str:
    """Consulta en SQLite el perfil de riesgo crediticio, segmento, región e historial de pago de clientes corporativos.

    Args:
        busqueda: Nombre del cliente, región ('LATAM', 'EMEA', 'Norteamérica') o 'todos'.

    Returns:
        Ficha financiera y Credit Score de las cuentas encontradas.
    """
    conn = _init_db()
    termino = busqueda.strip()
    if termino.lower() in ("todos", "all", "*"):
        rows = conn.execute(
            "SELECT nombre, region, segmento, credit_score, plazo_actual_dias, estado_cartera FROM clientes_corporativos ORDER BY region, nombre"
        ).fetchall()
    else:
        patron = f"%{termino}%"
        rows = conn.execute(
            """
            SELECT nombre, region, segmento, credit_score, plazo_actual_dias, estado_cartera
            FROM clientes_corporativos
            WHERE LOWER(nombre) LIKE LOWER(?) OR LOWER(region) LIKE LOWER(?) OR LOWER(segmento) LIKE LOWER(?)
            ORDER BY nombre
            """,
            (patron, patron, patron),
        ).fetchall()
    conn.close()

    if not rows:
        return (
            f"🔎 No se encontró el cliente o filtro '{busqueda}' en la base SQLite de RevOps. "
            "Usa consultar_riesgo_crediticio_cliente('todos') para listar las cuentas registradas."
        )

    lineas = ["🏦 Ficha de Riesgo Crediticio Corporativo (SQLite MCP):"]
    for nombre, region, segmento, score, plazo, estado in rows:
        lineas.append(
            f"- {nombre} | Región: {region} | Segmento: {segmento} | Credit Score: {score} | Plazo actual: Net {plazo} | Cartera: {estado}"
        )
    return "\n".join(lineas)


@mcp.tool()
def consultar_precedentes_excepciones(tipo_excepcion: str) -> str:
    """Consulta criterios históricos y garantías de mitigación exigidas por Finanzas, Crédito o el ERC para aprobar excepciones.

    Args:
        tipo_excepcion: Tipo de caso ('margen_piso', 'credito_net90', 'descuento_cloud').

    Returns:
        Precedentes de gobernanza y contraprestaciones recomendadas para incluir en el memorando ejecutivo.
    """
    t = tipo_excepcion.strip().lower()
    if "margen" in t or "erc" in t or "piso" in t:
        return (
            "⚖️ Precedentes del Executive Revenue Committee (ERC — Dispensa de Margen Piso, Sección 1.3):\n"
            "- Órgano facultado único: Executive Revenue Committee (ERC) — Nivel 5 DoA.\n"
            "- Garantías exigidas habitualmente para evaluar márgenes < 25% en Enterprise:\n"
            "  1) Contrato multianual vinculante mínimo de 36 meses sin cláusula de salida anticipada.\n"
            "  2) Plan de rampa de precios (Price Uplift) que recupere >= 26% de margen bruto a partir del Año 2.\n"
            "  3) Desplazamiento documentado de competidor estratégico en cuenta Global 2000."
        )
    if "90" in t or "credito" in t or "crédito" in t or "latam" in t:
        return (
            "⚖️ Precedentes de Gobernanza Crediticia (Net 90 en LATAM, Sección 4.2):\n"
            "- Firmas obligatorias conjuntas: Regional Credit Committee (scoring) + Finance Director LATAM.\n"
            "- Garantías recomendadas para agilizar el visto bueno en LATAM:\n"
            "  1) Credit Score interno igual o superior a BBB+ sin moras previas.\n"
            "  2) Facturación anual anticipada o pago inicial del 20% al firmar la orden.\n"
            "  3) Cobertura de seguro de crédito comercial o carta de respaldo de casa matriz."
        )
    return (
        "⚖️ Precedentes de Descuento por Volumen (Sección 2.4 y Matriz DoA):\n"
        "- En Cloud EMEA y Norteamérica, compras > 15,000 licencias cuentan con hasta 15% preaprobado para el AE.\n"
        "- Para descuentos del 16% al 25% (Nivel 2 DoA — Regional Sales Director), se recomienda adjuntar comparativa competitiva y validar que el margen bruto supere el 25%."
    )


if __name__ == "__main__":
    mcp.run(transport="stdio")
