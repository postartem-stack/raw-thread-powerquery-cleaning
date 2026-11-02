# RAW THREAD — Demo Sales Dataset

Synthetic sales data for a fictional premium streetwear brand.
Built to power the Upwork portfolio cases. **Not real customer data** —
generated with a fixed random seed, so it's fully reproducible.

Brand palette: **Charcoal `#1A1A1A`** · **Bone `#E8E0D0`**

## Files
- `raw_thread_sales_clean.csv` — 10,000 rows, clean. Use for Case 1 (Excel
  dashboard), Case 2 (Python PDF report), Case 4 (Power BI).
- `raw_thread_sales_messy.csv` — 10,122 rows, deliberately dirty. Use for
  Case 3 (Power Query cleaning & validation).

## Schema (clean file)
| Column | Type | Notes |
|---|---|---|
| OrderID | text | Unique, format `RT-1XXXXX` |
| OrderDate | date (ISO) | 2024-01-01 → 2025-03-31 (15 months) |
| Product | text | e.g. "Heavyweight Hoodie" |
| Category | text | Hoodies, T-Shirts, Jackets, Pants, Caps, Accessories |
| Size | text | XS–XXL for apparel; "One Size" for caps/accessories |
| Color | text | Charcoal, Bone, Black, Off-White, Olive, Rust |
| Channel | text | Online Store, Wholesale, Pop-up |
| Region | text | North America, Europe, United Kingdom, Asia-Pacific, Middle East |
| Quantity | int | 1–3 retail; 6–40 wholesale (bulk) |
| UnitPrice | number | Per-unit price (wholesale ~45% lower) |
| Discount | number | 0–0.20 (promos, heavier in Nov/Dec) |
| Revenue | number | Quantity × UnitPrice × (1 − Discount) |
| Cost | number | Total unit cost × quantity |
| Profit | number | Revenue − Cost |
| CustomerType | text | New / Returning |

## Built-in patterns (good for "insights" in your case studies)
- **Seasonality:** revenue peaks Nov–Dec (holiday) with an Aug–Sep bump;
  Jan–Feb are slow.
- **Category × season:** Hoodies & Jackets spike in cold months; T-Shirts &
  Caps in warm months.
- **YoY growth:** ~+36% Q1-2024 vs Q1-2025.
- **Channel insight:** Wholesale drives the majority of revenue via bulk
  orders — a clear finding to highlight on a dashboard.
- **Margin:** ~45% overall.

## Messiness injected (messy file) — the cleaning to-do list
1. Mixed date formats: `2024-11-05`, `05/11/2024`, `11/05/2024`, `5-Nov-2024`
2. Inconsistent category labels: `hoodies`, `HOODIES`, `Tees`, `Accesories`
3. Region variants/typos: `EU`/`Europe`, `NA`/`North America`, `UK`/`U.K.`
4. Currency junk in numbers: `$89.12`, `USD 26.27`, trailing spaces
5. Blank cells in Size / Color / Channel / CustomerType
6. Stray leading/trailing whitespace in text fields
7. ~120 duplicate rows
8. A couple of junk/empty rows (incl. a `TEST ROW`)

> Suggested case caption: *"Demo project built on sample data to showcase
> the workflow — from a messy 10k-row export to a clean, validated table."*
