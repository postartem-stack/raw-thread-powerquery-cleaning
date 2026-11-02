"""Reference implementation of the Power Query cleaning rules + check against the gold file.

Mirrors RAW_THREAD_Cleaning.pq step by step, so the M pipeline's expected
output can be verified without Power BI/Excel:

    python3 scripts/verify_cleaning.py

Compares every field that the messy export still carries (blanks are
excluded, they are not recoverable) with raw_thread_sales_clean.csv.
"""
import csv, re, sys
from datetime import date, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MONTHS = {m: i for i, m in enumerate(
    "jan feb mar apr may jun jul aug sep oct nov dec".split(), 1)}

CATEGORY = {
    "hoodie": "Hoodies", "hoodies": "Hoodies",
    "tee": "T-Shirts", "tees": "T-Shirts", "tshirts": "T-Shirts",
    "t shirts": "T-Shirts", "t-shirts": "T-Shirts",
    "jacket": "Jackets", "jackets": "Jackets",
    "pant": "Pants", "pants": "Pants",
    "cap": "Caps", "caps": "Caps",
    "accessory": "Accessories", "accessories": "Accessories",
    "accesories": "Accessories",
}
REGION = {
    "north america": "North America", "na": "North America",
    "n. america": "North America",
    "europe": "Europe", "eu": "Europe",
    "united kingdom": "United Kingdom", "uk": "United Kingdom",
    "u.k.": "United Kingdom",
    "asia-pacific": "Asia-Pacific", "asia pacific": "Asia-Pacific",
    "apac": "Asia-Pacific",
    "middle east": "Middle East", "me": "Middle East",
}


def num(s):
    s = re.sub(r"[^0-9.\-]", "", s)  # drops $, USD, spaces
    return float(s)


def parse_unambiguous(s):
    s = s.strip()
    if m := re.fullmatch(r"(\d{4})-(\d\d)-(\d\d)", s):
        return date(int(m[1]), int(m[2]), int(m[3]))
    if m := re.fullmatch(r"(\d{1,2})-([A-Za-z]{3})-(\d{4})", s):
        return date(int(m[3]), MONTHS[m[2].lower()], int(m[1]))
    return None


def candidates(s):
    """dd/mm/yyyy vs mm/dd/yyyy: return every valid reading."""
    m = re.fullmatch(r"(\d\d)/(\d\d)/(\d{4})", s.strip())
    a, b, y = int(m[1]), int(m[2]), int(m[3])
    out = []
    for d, mo in ((a, b), (b, a)):  # DMY, then MDY
        try:
            out.append(date(y, mo, d))
        except ValueError:
            pass
    return list(dict.fromkeys(out))


def clean(rows):
    stats = {"input": len(rows)}
    rows = [{k: (v or "").strip() for k, v in r.items()} for r in rows]
    rows = [r for r in rows if r["OrderID"] and r["OrderDate"] and r["Product"] != "TEST ROW"]
    stats["junk"] = stats["input"] - len(rows)
    seen, uniq = set(), []
    for r in rows:
        if r["OrderID"] not in seen:
            seen.add(r["OrderID"]); uniq.append(r)
    stats["duplicates"] = len(rows) - len(uniq)
    rows = sorted(uniq, key=lambda r: int(r["OrderID"][3:]))
    # Dates: OrderID grows with time, so the last unambiguous date above a row
    # is the anchor that decides between dd/mm and mm/dd.
    anchor, amb = None, 0
    for r in rows:
        d = parse_unambiguous(r["OrderDate"])
        if d is None:
            c = candidates(r["OrderDate"])
            if len(c) == 2 and c[0] != c[1]:
                amb += 1
                d = min(c, key=lambda x: abs((x - anchor).days)) if anchor else c[0]
            else:
                d = c[0]
        else:
            anchor = d
        r["OrderDate"] = d.isoformat()
    stats["ambiguous_dates"] = amb
    for r in rows:
        r["Category"] = CATEGORY[r["Category"].lower()]
        r["Region"] = REGION[r["Region"].lower()]
        for k in ("UnitPrice", "Discount", "Revenue", "Cost", "Profit"):
            r[k] = num(r[k])
        r["Quantity"] = int(r["Quantity"])
        if not r["Size"]:
            r["Size"] = "One Size" if r["Category"] in ("Caps", "Accessories") else "Unknown"
        for k in ("Color", "Channel", "CustomerType"):
            r[k] = r[k] or "Unknown"
    return rows, stats


def main():
    src = ROOT / "raw_thread_sales_messy.csv"
    gold = {r["OrderID"]: r for r in csv.DictReader(open(ROOT / "raw_thread_sales_clean.csv"))}
    rows, stats = clean(list(csv.DictReader(open(src, encoding="utf-8-sig"))))
    bad = {}
    for r in rows:
        g = gold[r["OrderID"]]
        for k in ("OrderDate", "Product", "Category", "Region"):
            if r[k] != g[k]: bad[k] = bad.get(k, 0) + 1
        for k in ("UnitPrice", "Discount", "Revenue", "Cost", "Profit"):
            if abs(r[k] - float(g[k])) > 0.005: bad[k] = bad.get(k, 0) + 1
        if r["Quantity"] != int(g["Quantity"]): bad["Quantity"] = bad.get("Quantity", 0) + 1
        for k in ("Size", "Color", "Channel", "CustomerType"):
            if r[k] not in ("Unknown",) and r[k] != g[k] and not (k == "Size" and r[k] == "One Size" and g[k] == "One Size"):
                bad[k] = bad.get(k, 0) + 1
    unknown = {k: sum(r[k] == "Unknown" for r in rows) for k in ("Size", "Color", "Channel", "CustomerType")}
    print("stats:", stats, "| output rows:", len(rows), "| gold rows:", len(gold))
    print("unknown (blank in source, not recoverable):", unknown)
    print("mismatches vs gold:", bad or "none")
    ok = len(rows) == len(gold) and set(r["OrderID"] for r in rows) == set(gold) and not bad
    print("PASS" if ok else "FAIL")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
