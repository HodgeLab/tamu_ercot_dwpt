#home_dir = "C:/Users/antho/github/tamu_ercot_dwpt"
#home_dir = "C:/Users/A.J. Sauter/github/tamu_ercot_dwpt"
#home_dir = "A:/Users/Documents/ASPIRE_Simulators/tamu_ercot_dwpt"
#home_dir = "/home/ansa1773/tamu_ercot_dwpt"
# cd(home_dir)
# include("DWPT_SimRun.jl")

include("simFunctions.jl")

# MUST USE #DEV Version of PowerSimulations.jl
using PowerSystems
using PowerGraphics
using PowerSimulations
using InfrastructureSystems
const PSI = PowerSimulations
using CSV
using XLSX
using Plots
using Dates
#using PyPlot
using DataFrames
using TimeSeries
using Gurobi

run_spot = "Alpine"
ex_only = false
case = "hs"
sim_name = string("dwpt-", case, "-lvlr-")

# Level of EV adoption (value from 0 to 1)
ev_adpt_level = .05
method = "T100"

tamuSimEx(run_spot, ex_only, ev_adpt_level, method, sim_name, case)
tamuSimRes(run_spot, ex_only, ev_adpt_level, method, sim_name)
