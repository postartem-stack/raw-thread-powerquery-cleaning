// Query name: Validation_Summary   (load to a sheet named "Validation summary")
let
    Clean     = Clean_Sales,
    Rows      = Table.ToRecords(Clean),
    InputRows = Table.RowCount(Messy_Staged),
    JunkRows  = List.Count(List.Select(Table.ToRecords(Messy_Staged), each [IsJunk])),
    OutRows   = Table.RowCount(Clean),
    DupRows   = InputRows - JunkRows - OutRows,
    SlashDates = List.Count(List.Select(Table.ToRecords(Messy_Staged), each [OrderDate] <> null and Text.Contains([OrderDate], "/"))),
    CountIf   = (f as function) as number => List.Count(List.Select(Rows, f)),
    Dates     = Clean[OrderDate],

    Checks = {
        // {Check, Value, Expected, Passed}
        {"Rows in raw export",                     InputRows, null, null},
        {"Junk / empty / TEST rows removed",       JunkRows,  2,    JunkRows = 2},
        {"Duplicate orders removed",               DupRows,   120,  DupRows = 120},
        {"Rows in clean table",                    OutRows,   10000, OutRows = 10000},
        {"Slash dates resolved (dd/mm vs mm/dd)",  SlashDates, null, null},
        {"Duplicate OrderIDs left",                OutRows - List.Count(List.Distinct(Clean[OrderID])), 0,
              OutRows - List.Count(List.Distinct(Clean[OrderID])) = 0},
        {"Unmapped category labels",               CountIf(each [Category] = "UNMAPPED"), 0, CountIf(each [Category] = "UNMAPPED") = 0},
        {"Unmapped region labels",                 CountIf(each [Region] = "UNMAPPED"),   0, CountIf(each [Region] = "UNMAPPED") = 0},
        {"Dates outside 2024-01-01..2025-03-31",   CountIf(each [OrderDate] < #date(2024,1,1) or [OrderDate] > #date(2025,3,31)), 0,
              CountIf(each [OrderDate] < #date(2024,1,1) or [OrderDate] > #date(2025,3,31)) = 0},
        {"Revenue <> Qty x Price x (1-Disc) (>0.011)", CountIf(each Number.Abs([Revenue] - [Quantity] * [UnitPrice] * (1 - [Discount])) > 0.011), 0,
              CountIf(each Number.Abs([Revenue] - [Quantity] * [UnitPrice] * (1 - [Discount])) > 0.011) = 0},
        {"Profit <> Revenue - Cost (>0.011)",      CountIf(each Number.Abs([Profit] - ([Revenue] - [Cost])) > 0.011), 0,
              CountIf(each Number.Abs([Profit] - ([Revenue] - [Cost])) > 0.011) = 0},
        {"Size unknown (blank in source)",         CountIf(each [Size] = "Unknown"), null, null},
        {"Color unknown (blank in source)",        CountIf(each [Color] = "Unknown"), null, null},
        {"Channel unknown (blank in source)",      CountIf(each [Channel] = "Unknown"), null, null},
        {"CustomerType unknown (blank in source)", CountIf(each [CustomerType] = "Unknown"), null, null},
        {"Net revenue, clean table ($)",           Number.Round(List.Sum(Clean[Revenue]), 2), null, null}
    },
    Result = #table(type table [Check = text, Value = number, Expected = nullable number, Status = text],
                List.Transform(Checks, each {_{0}, _{1}, _{2}, if _{3} = null then "info" else if _{3} then "OK" else "FAIL"}))
in
    Result
