#!/usr/bin/env python
"""Calculate DeltaGcox and O2-based lambda values for FT-ICR MS formulas."""

from __future__ import annotations

import argparse
import math
import re
import sys
from pathlib import Path

try:
    import pandas as pd
except ImportError as exc:  # pragma: no cover - depends on the runtime environment.
    raise SystemExit(
        "Error: pandas is required. Install dependencies with: "
        "python -m pip install pandas openpyxl"
    ) from exc


ELEMENTS = ("C", "H", "N", "O", "S", "P", "Cl", "Br")
FORMULA_PATTERN = re.compile(r"(Cl|Br|C|H|N|O|S|P)(\d*(?:\.\d+)?)")

G_FORM = {
    "H2O": -237.2,
    "HCO3": -586.9,
    "NH4": -79.5,
    "HPO4": -1089.1,
    "HS": 12.0,
    "H": 0.0,
    "e": 0.0,
    "O2": 16.5,
    "biomass": -67.0,
}

ETA = 0.43
DELTA_G_SYN = 200.0
RT_LN10_PH7 = 8.31446261815324e-3 * 298.15 * math.log(10.0) * 7.0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Read an FT-ICR MS formula table and append ΔG0cox, λ, "
            "VK, and (DBE-O)/C."
        )
    )
    parser.add_argument("input", help="Input .csv or .xlsx file")
    parser.add_argument("output", help="Output .csv or .xlsx file")
    parser.add_argument(
        "--sheet",
        default=None,
        help="Excel sheet name or index for .xlsx input/output. Ignored for .csv.",
    )
    return parser.parse_args()


def read_table(path: Path, sheet: str | None) -> pd.DataFrame | dict[str, pd.DataFrame]:
    suffix = path.suffix.lower()
    if suffix == ".csv":
        return pd.read_csv(path)
    if suffix in {".xlsx", ".xls"}:
        # Without --sheet, process every worksheet in the workbook.
        return pd.read_excel(path, sheet_name=sheet if sheet is not None else None)
    raise ValueError(f"Unsupported input suffix: {path.suffix}. Use .csv or .xlsx.")


def write_table(
    data: pd.DataFrame | dict[str, pd.DataFrame], path: Path, sheet: str | None
) -> None:
    suffix = path.suffix.lower()
    if suffix == ".csv":
        if isinstance(data, dict):
            raise ValueError("CSV output can contain only one table. Use --sheet for Excel input.")
        data.to_csv(path, index=False)
        return
    if suffix in {".xlsx", ".xls"}:
        with pd.ExcelWriter(path) as writer:
            if isinstance(data, dict):
                for sheet_name, frame in data.items():
                    frame.to_excel(writer, index=False, sheet_name=str(sheet_name)[:31])
            else:
                sheet_name = str(sheet) if sheet is not None else "Sheet1"
                data.to_excel(writer, index=False, sheet_name=sheet_name[:31])
        return
    raise ValueError(f"Unsupported output suffix: {path.suffix}. Use .csv or .xlsx.")


def parse_formula(value: object) -> dict[str, float]:
    counts = {element: 0.0 for element in ELEMENTS}
    if pd.isna(value):
        return counts

    formula = str(value).strip()
    if not formula:
        return counts

    for element, number in FORMULA_PATTERN.findall(formula):
        counts[element] += float(number) if number else 1.0

    return counts


def extract_elements(df: pd.DataFrame) -> pd.DataFrame:
    existing_element_cols = [element for element in ELEMENTS if element in df.columns]

    if existing_element_cols:
        data = pd.DataFrame(index=df.index)
        for element in ELEMENTS:
            if element in df.columns:
                data[element] = pd.to_numeric(df[element], errors="coerce").fillna(0.0)
            else:
                data[element] = 0.0
        return data

    if "MolForm" not in df.columns:
        raise ValueError(
            "No element columns were found and the table does not contain a MolForm column."
        )

    parsed = df["MolForm"].apply(parse_formula)
    return pd.DataFrame(parsed.tolist(), index=df.index, columns=ELEMENTS).fillna(0.0)


def donor_formation_energy(
    c: float,
    h: float,
    n: float,
    o: float,
    s: float,
    p: float,
    ne: float,
    delta_gcox: float,
) -> tuple[float, float, float]:
    """Estimate donor Gibbs formation energy from the O2 oxidation reaction.

    The catabolic oxidation is:
    donor + a H2O + ne/4 O2 -> C HCO3- + N NH4+ + P HPO4^2-
                                + S HS- + b H+
    """
    water = 3.0 * c + 4.0 * p - o
    protons = h + 2.0 * water - c - 4.0 * n - p - s

    product_g = (
        c * G_FORM["HCO3"]
        + n * G_FORM["NH4"]
        + p * G_FORM["HPO4"]
        + s * G_FORM["HS"]
        + protons * G_FORM["H"]
    )
    reactant_g_without_donor = water * G_FORM["H2O"] + (ne / 4.0) * G_FORM["O2"]
    delta_g_oxidation = c * delta_gcox

    donor_g = product_g - reactant_g_without_donor - delta_g_oxidation
    return donor_g, water, protons


def catabolic_delta_g_pH7(
    c: float,
    n: float,
    s: float,
    p: float,
    ne: float,
    donor_g: float,
    water: float,
    protons: float,
) -> float:
    products = (
        c * G_FORM["HCO3"]
        + n * G_FORM["NH4"]
        + p * G_FORM["HPO4"]
        + s * G_FORM["HS"]
        + protons * G_FORM["H"]
    )
    reactants = donor_g + water * G_FORM["H2O"] + (ne / 4.0) * G_FORM["O2"]
    delta_g = products - reactants

    # Biological standard state at pH 7: add RT ln(10^-7) for each product H+.
    return delta_g - protons * RT_LN10_PH7


def anabolic_delta_g_pH7(
    c: float,
    h: float,
    n: float,
    o: float,
    s: float,
    p: float,
    donor_g: float,
) -> float:
    """Calculate anabolic DeltaG for forming 1 C-mol biomass.

    Biomass formula is CH1.8N0.2O0.5. Donor carbon supplies biomass carbon;
    NH4+, HPO4^2-, HS-, H2O, H+, and electrons balance the remaining atoms
    and charge. Electron Gibbs formation energy is zero.
    """
    donor = 1.0 / c
    r_hco3 = 1.0 - donor * c
    r_nh4 = 0.2 - donor * n
    r_hpo4 = -donor * p
    r_hs = -donor * s
    r_h2o = 0.5 - donor * o - 3.0 * r_hco3 - 4.0 * r_hpo4
    r_h = (
        1.8
        - donor * h
        - 2.0 * r_h2o
        - r_hco3
        - 4.0 * r_nh4
        - r_hpo4
        - r_hs
    )
    r_e = -r_hco3 + r_nh4 - 2.0 * r_hpo4 - r_hs + r_h

    reactants = (
        donor * donor_g
        + r_h2o * G_FORM["H2O"]
        + r_hco3 * G_FORM["HCO3"]
        + r_nh4 * G_FORM["NH4"]
        + r_hpo4 * G_FORM["HPO4"]
        + r_hs * G_FORM["HS"]
        + r_h * G_FORM["H"]
        + r_e * G_FORM["e"]
    )
    delta_g = G_FORM["biomass"] - reactants

    # H+ has conventional stoichiometric coefficient -r_h.
    return delta_g + r_h * RT_LN10_PH7


def calculate_row(row: pd.Series) -> tuple[float, float]:
    c = float(row["C"])
    h = float(row["H"])
    n = float(row["N"])
    o = float(row["O"])
    s = float(row["S"])
    p = float(row["P"])
    cl = float(row["Cl"])
    br = float(row["Br"])

    if c <= 0.0:
        return math.nan, math.nan

    ne = 4.0 * c + h - 3.0 * n - 2.0 * o + 5.0 * p - 2.0 * s - cl - br
    nosc = 4.0 - ne / c
    delta_gcox = 60.3 - 28.5 * nosc

    if cl > 0.0 or br > 0.0:
        return delta_gcox, math.nan

    if ne <= 0.0:
        return delta_gcox, math.nan

    try:
        donor_g, water_cat, protons_cat = donor_formation_energy(
            c, h, n, o, s, p, ne, delta_gcox
        )
        delta_gcat = catabolic_delta_g_pH7(
            c, n, s, p, ne, donor_g, water_cat, protons_cat
        )
        delta_gan = anabolic_delta_g_pH7(c, h, n, o, s, p, donor_g)

        delta_gcat_per_o2 = delta_gcat / (ne / 4.0)
        if delta_gcat_per_o2 >= 0.0:
            return delta_gcox, math.nan

        m = 1.0 if delta_gan < 0.0 else -1.0
        lambda_o2 = (
            delta_gan * (ETA**m) + DELTA_G_SYN
        ) / (-delta_gcat_per_o2 * ETA)

        if not math.isfinite(lambda_o2):
            lambda_o2 = math.nan
        return delta_gcox, lambda_o2
    except (ArithmeticError, FloatingPointError, ValueError, ZeroDivisionError):
        return delta_gcox, math.nan


def get_numeric_column(df: pd.DataFrame, column: str) -> pd.Series:
    if column not in df.columns:
        return pd.Series(math.nan, index=df.index, dtype="float64")
    return pd.to_numeric(df[column], errors="coerce")


def classify_vk(oc: float, hc: float) -> str:
    if pd.isna(oc) or pd.isna(hc):
        return "Other"

    if 0.0 <= oc < 0.3 and 1.5 <= hc <= 2.0:
        return "Lipids"
    if 0.3 <= oc < 0.67 and 1.5 <= hc <= 2.2:
        return "Aliphatic"
    if 0.1 < oc <= 0.67 and 0.7 <= hc < 1.5:
        return "Lignin"
    if 0.67 <= oc <= 1.2 and 1.5 <= hc <= 2.4:
        return "Carbohydrates"
    if 0.0 <= oc <= 0.1 and 0.7 <= hc < 1.5:
        return "Unsaturated"
    if 0.0 <= oc <= 0.67 and 0.2 <= hc < 0.7:
        return "Aromatic"
    if 0.67 < oc <= 1.0 and 0.6 <= hc < 1.5:
        return "Tannin"
    return "Other"


def calculate_vk(df: pd.DataFrame, elements: pd.DataFrame) -> pd.Series:
    oc = get_numeric_column(df, "O/C")
    hc = get_numeric_column(df, "H/C")

    missing_oc = oc.isna()
    missing_hc = hc.isna()
    c = elements["C"].replace(0.0, math.nan)
    if missing_oc.any():
        oc.loc[missing_oc] = elements.loc[missing_oc, "O"] / c.loc[missing_oc]
    if missing_hc.any():
        hc.loc[missing_hc] = elements.loc[missing_hc, "H"] / c.loc[missing_hc]

    return pd.Series(
        [classify_vk(oc_value, hc_value) for oc_value, hc_value in zip(oc, hc)],
        index=df.index,
    )


def calculate_dbe_minus_o_per_c(df: pd.DataFrame, elements: pd.DataFrame) -> pd.Series:
    dbe = get_numeric_column(df, "DBE")
    oxygen = get_numeric_column(df, "O")
    carbon = get_numeric_column(df, "C")

    missing_o = oxygen.isna()
    missing_c = carbon.isna()
    if missing_o.any():
        oxygen.loc[missing_o] = elements.loc[missing_o, "O"]
    if missing_c.any():
        carbon.loc[missing_c] = elements.loc[missing_c, "C"]

    carbon = carbon.replace(0.0, math.nan)
    return (dbe - oxygen) / carbon


def append_calculations(df: pd.DataFrame) -> pd.DataFrame:
    elements = extract_elements(df)
    results = elements.apply(calculate_row, axis=1, result_type="expand")
    results.columns = ["DeltaGcox_kJ_Cmol", "lambda_O2"]

    output = df.copy()
    output["ΔG0cox"] = results["DeltaGcox_kJ_Cmol"]
    output["λ"] = results["lambda_O2"]
    output["VK"] = calculate_vk(df, elements)
    output["(DBE-O)/C"] = calculate_dbe_minus_o_per_c(df, elements)
    return output


def main() -> int:
    args = parse_args()
    input_path = Path(args.input)
    output_path = Path(args.output)

    try:
        if not input_path.exists():
            raise FileNotFoundError(f"Input file not found: {input_path}")

        data = read_table(input_path, args.sheet)
        if isinstance(data, dict):
            output = {
                sheet_name: append_calculations(frame)
                for sheet_name, frame in data.items()
            }
            row_count = sum(len(frame) for frame in output.values())
        else:
            output = append_calculations(data)
            row_count = len(output)

        write_table(output, output_path, args.sheet)
        print(f"Wrote {row_count} rows to {output_path}")
        return 0
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
