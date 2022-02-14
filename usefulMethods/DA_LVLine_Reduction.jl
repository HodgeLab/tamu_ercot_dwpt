# cd("C:\\Users\\A.J. Sauter\\github\\tamu_ercot_dwpt\\usefulMethods")
# include("DA_LVLine_Reduction.jl")

# MUST USE #MASTER branch of PowerSimulations.jl

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

using Gurobi #Cbc

Adopt = "_A05"
Method = "T100_"
tran_set = string(Adopt, Method)

# Link to system
DATA_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/data"
OUT_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/outputs"
main_dir = "C:\\Users\\A.J. Sauter\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling"
local_dir = "C:\\Users\\A.J. Sauter\\Documents"
system = System(joinpath(local_dir, "Local_Sys_Files/tamu_DA_sys.json"))

# BasePV System
#system = System(joinpath(main_dir, "test_outputs/tamu_DA_basePV_sys.json"))

#system = System(joinpath(main_dir, "active/tamu_DA_sys.json"))
#system = System(joinpath(DATA_DIR, "texas_data/DA_sys.json"))

c = 0

for l in get_components(Line, system)
   buses = get_arc(l)
   from_bus = get_from(buses)
   to_bus = get_to(buses)
   if get_base_voltage(from_bus) != get_base_voltage(to_bus)
      error()
   end
   if get_base_voltage(from_bus) < 230
      println("Line changed: ", get_name(l))
      set_x!(l, get_x(l)*0.5)
      global c = c + 1
   end
end

to_json(system, joinpath(local_dir, "Local_Sys_Files/tamu_DA_sys_LVLred.json"), force=true) #Low-Voltage Lines Reduced
println("New active system file has been created.")
println("Total lines updated: ", c)
