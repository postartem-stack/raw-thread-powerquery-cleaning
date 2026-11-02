# RAW THREAD — Data Cleaning with Power Query (Case 3)

A messy 10,122-row sales export turned into a clean, validated 10,000-row table
by a Power Query pipeline. Hit **Refresh** and the whole cleaning re-runs.
Demo project on synthetic data for a fictional brand — no real customers.

## What the pipeline fixes

| Problem in the export | Fix |
|---|---|
| 4 date formats (`2024-11-05`, `5-Nov-2024`, `05/11/2024`, `11/05/2024`) | ISO and named-month parsed directly. For `dd/mm` vs `mm/dd`, Order IDs grow with time, so the nearest unambiguous date above the row decides |
| 25 spellings of 6 categories (`Tees`, `HOODIES`, `Accesories`…) | lookup record -> 6 canonical labels |
| Region variants (`EU`, `NA`, `U.K.`, `APAC`, `N. America`…) | lookup record -> 5 canonical regions |
| `$89.12`, `USD 26.27`, trailing spaces in numbers | non-numeric characters stripped, parsed with `en-US` culture |
| Leading/trailing whitespace in text | `Text.Trim` on every column |
| Blank Size / Color / Channel / CustomerType | Caps & Accessories -> `One Size`; everything else `Unknown` (not guessed) |
| 120 exact duplicate orders | `Table.Distinct` on `OrderID` |
| Empty row + `TEST ROW` | filtered out |

## Files

```
powerquery/
  00_SourcePath.pq          path to the CSV (edit this one line)
  01_Messy_Staged.pq        load as text, trim, flag junk       (connection only)
  02_Clean_Sales.pq         the cleaning steps                  (load to a sheet)
  03_Validation_Summary.pq  checks table                        (load to "Validation summary")
scripts/verify_cleaning.py  same rules in Python, compared with the gold file
raw_thread_sales_messy.csv  input      raw_thread_sales_clean.csv  gold reference
RAW_THREAD_data_dictionary.md  schema and the list of injected problems
```

## How to use in Excel (Windows or Mac 365)

1. Data -> Get Data -> Launch Power Query Editor.
2. Create a blank query for each `.pq` file, in order, open **Advanced Editor**,
   paste the file, and give the query exactly the name in its first comment
   (`SourcePath`, `Messy_Staged`, `Clean_Sales`, `Validation_Summary`).
3. Set the path in `SourcePath`. Load `Clean_Sales` and `Validation_Summary` to tables.

## Validation summary (expected result)

| Check | Expected |
|---|---|
| Junk rows removed | 2 |
| Duplicates removed | 120 |
| Rows in clean table | 10,000 |
| Duplicate OrderIDs / unmapped labels / dates out of range | 0 |
| Revenue = Qty x Price x (1 - Discount), Profit = Revenue - Cost | 0 exceptions |
| Net revenue | $4,022,080.20 |
| Unknown after cleaning (blank in source) | Size 222, Color 324, Channel 259, CustomerType 289 |

## Verification

```bash
python3 scripts/verify_cleaning.py
```

Applies the same rules in Python and compares all 10,000 rows with
`raw_thread_sales_clean.csv`: dates, products, categories, regions, prices,
revenue, cost, profit and every non-blank attribute match. The `.pq` files
were written to mirror this script step by step, but were **not executed in
Power Query in this repo's build environment** (macOS, no Windows Excel) — if a
check in the Validation summary shows FAIL after you load them, that is the first
place to look.
