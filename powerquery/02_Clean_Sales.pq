// Query name: Clean_Sales   (load to a table on a sheet)
let
    // ---- 1. drop junk rows, then duplicate orders (exact copies, same OrderID) ----
    NoJunk  = Table.RemoveColumns(Table.SelectRows(Messy_Staged, each not [IsJunk]), {"IsJunk"}),
    NoDupes = Table.Distinct(NoJunk, {"OrderID"}),

    // ---- 2. sort by numeric order id (ids grow with time) ----
    WithNum = Table.AddColumn(NoDupes, "IdNum", each Number.FromText(Text.Middle([OrderID], 3), "en-US"), Int64.Type),
    Sorted  = Table.Buffer(Table.Sort(WithNum, {{"IdNum", Order.Ascending}})),

    // ---- 3. dates: ISO and 5-Nov-2024 are exact; dd/mm vs mm/dd is ambiguous ----
    ParseExact = (t as text) as nullable date =>
        let iso = try Date.FromText(t, [Format = "yyyy-MM-dd", Culture = "en-US"]) otherwise null,
            mon = try Date.FromText(t, [Format = "d-MMM-yyyy", Culture = "en-US"]) otherwise null
        in  if iso <> null then iso else mon,
    Exact   = Table.AddColumn(Sorted, "Exact", each ParseExact([OrderDate]), type nullable date),
    // last exact date above the row = anchor (OrderID order == chronological order)
    Anchor  = Table.FillDown(Table.AddColumn(Exact, "Anchor", each [Exact], type nullable date), {"Anchor"}),
    ResolveSlash = (t as text, anchor as nullable date) as date =>
        let p   = Text.Split(t, "/"),
            a   = Number.FromText(p{0}, "en-US"),
            b   = Number.FromText(p{1}, "en-US"),
            y   = Number.FromText(p{2}, "en-US"),
            dmy = try #date(y, b, a) otherwise null,
            mdy = try #date(y, a, b) otherwise null
        in  if dmy = null then mdy
            else if mdy = null then dmy
            else if anchor = null then dmy
            else if Number.Abs(Duration.Days(dmy - anchor)) <= Number.Abs(Duration.Days(mdy - anchor)) then dmy
            else mdy,
    Dated   = Table.AddColumn(Anchor, "Date", each if [Exact] <> null then [Exact] else ResolveSlash([OrderDate], [Anchor]), type date),
    DropTmp = Table.RemoveColumns(Dated, {"OrderDate", "Exact", "Anchor", "IdNum"}),
    Renamed = Table.RenameColumns(DropTmp, {{"Date", "OrderDate"}}),

    // ---- 4. category / region label normalisation ----
    CategoryMap = [hoodie = "Hoodies", hoodies = "Hoodies", tee = "T-Shirts", tees = "T-Shirts", tshirts = "T-Shirts",
                   #"t shirts" = "T-Shirts", #"t-shirts" = "T-Shirts", jacket = "Jackets", jackets = "Jackets",
                   pant = "Pants", pants = "Pants", cap = "Caps", caps = "Caps",
                   accessory = "Accessories", accessories = "Accessories", accesories = "Accessories"],
    RegionMap   = [#"north america" = "North America", na = "North America", #"n. america" = "North America",
                   europe = "Europe", eu = "Europe", #"united kingdom" = "United Kingdom", uk = "United Kingdom",
                   #"u.k." = "United Kingdom", #"asia-pacific" = "Asia-Pacific", #"asia pacific" = "Asia-Pacific",
                   apac = "Asia-Pacific", #"middle east" = "Middle East", me = "Middle East"],
    Mapped = Table.TransformColumns(Renamed, {
                {"Category", each Record.FieldOrDefault(CategoryMap, Text.Lower(_), "UNMAPPED"), type text},
                {"Region",   each Record.FieldOrDefault(RegionMap,   Text.Lower(_), "UNMAPPED"), type text}}),

    // ---- 5. numbers: strip $, USD and spaces ----
    ToNum = (t as nullable text) as nullable number =>
        if t = null then null else Number.FromText(Text.Select(t, {"0".."9", "."}), "en-US"),
    Numeric = Table.TransformColumns(Mapped, {
                {"Quantity", each ToNum(_), Int64.Type},
                {"UnitPrice", each ToNum(_), type number}, {"Discount", each ToNum(_), type number},
                {"Revenue", each ToNum(_), type number}, {"Cost", each ToNum(_), type number},
                {"Profit", each ToNum(_), type number}}),

    // ---- 6. blanks: caps/accessories are always One Size, the rest is flagged Unknown ----
    SizeFix = Table.AddColumn(Numeric, "SizeFixed",
                 each if [Size] <> null then [Size]
                      else if List.Contains({"Caps", "Accessories"}, [Category]) then "One Size" else "Unknown", type text),
    SizeSwap = Table.RenameColumns(Table.RemoveColumns(SizeFix, {"Size"}), {{"SizeFixed", "Size"}}),
    Filled  = Table.ReplaceValue(SizeSwap, null, "Unknown", Replacer.ReplaceValue, {"Color", "Channel", "CustomerType"}),

    // ---- 7. final column order + types ----
    Ordered = Table.ReorderColumns(Filled, {"OrderID", "OrderDate", "Product", "Category", "Size", "Color", "Channel",
                                            "Region", "Quantity", "UnitPrice", "Discount", "Revenue", "Cost", "Profit", "CustomerType"}),
    Typed   = Table.TransformColumnTypes(Ordered, {{"OrderDate", type date}, {"Quantity", Int64.Type}}, "en-US")
in
    Typed
