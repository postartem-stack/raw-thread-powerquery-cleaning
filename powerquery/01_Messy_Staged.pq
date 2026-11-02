// Query name: Messy_Staged   (connection only - no need to load to a sheet)
// Everything as text, whitespace trimmed, blanks -> null, junk rows flagged.
let
    Source   = Csv.Document(File.Contents(SourcePath), [Delimiter = ",", Columns = 15, Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    Cols     = Table.ColumnNames(Promoted),
    AsText   = Table.TransformColumnTypes(Promoted, List.Transform(Cols, each {_, type text}), "en-US"),
    Trimmed  = Table.TransformColumns(AsText, List.Transform(Cols, each {_, each Text.Trim(Text.Clean(_)), type text})),
    Blanks   = Table.ReplaceValue(Trimmed, "", null, Replacer.ReplaceValue, Cols),
    // Junk = completely empty row, or the TEST ROW: no order id / no date / test marker
    Flagged  = Table.AddColumn(Blanks, "IsJunk",
                   each [OrderID] = null or [OrderDate] = null or [Product] = "TEST ROW", type logical)
in
    Flagged
