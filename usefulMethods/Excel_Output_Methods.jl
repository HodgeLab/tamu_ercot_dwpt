# Writes XLSX file with multiple tabs
XLSX.writetable(
    "output3.xlsx",
    RE_GEN = (collect(DataFrames.eachcol(variables[:P__RenewableDispatch])), names(variables[:P__RenewableDispatch])),
    THERM_GEN = (collect(DataFrames.eachcol(variables[:P__ThermalMultiStart])), names(variables[:P__ThermalMultiStart]))
)

# Simple XLSX file output with ability to overwrite
XLSX.writetable(
    "output2.xlsx",
    variables[:P__RenewableDispatch],
    overwrite=true,
    sheetname="RE_Dispatch",
    anchor_cell="A1"
)

# Simple CSV output from DataFrame
CSV.write("output_test.csv", variables[:P__RenewableDispatch])
