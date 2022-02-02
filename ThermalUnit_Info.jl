using PowerSystems
#using PowerGraphics # NOT COMPATIBLE ATM
using PowerSimulations
using InfrastructureSystems
const PSI = PowerSimulations

using CSV
using XLSX
using Plots
using Dates
using PyPlot
using DataFrames
using TimeSeries

# CCGT90 : Combined-Cycle Greater Than 90MW
# CCLE90 : Combined-Cycle Less than or Equal to 90MW
# CLLIG : Coal and Lignite
# GSNONR: Gas Steam non-reheat or boilder without air-preheater

local_dir = "C:\\Users\\A.J. Sauter\\Documents"
system = System(joinpath(local_dir, "Local_Sys_Files/tamu_DA_sys.json"))

cd("C:\\Users\\A.J. Sauter\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling\\data\\texas_data\\RT_Sys_Breakdown")
therm_dets = CSV.read("ERCOT_ThermalUnits.csv", DataFrame)

fueltype = []

for x = 1:353
    th_name = string(therm_dets[x, 1])
    new_therm = get_component(ThermalMultiStart, system, th_name)
    try
        append!(fueltype, [new_therm.ext["ERCOT_FUEL"]])
    catch
        append!(fueltype, ["missing?"])
    end
    println(fueltype[x], "  ", x)
end

println(fueltype)
