# cd("C:\\Users\\A.J. Sauter\\github\\tamu_ercot_dwpt")
#cd("C:\\Users\\antho\\github\\tamu_ercot_dwpt")
# include("DWPT_Duals_Ex_Only.jl")

# MUST USE #MASTER branch of PowerSimulations.jl

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

loc_run = true

if loc_run == true
    # Link to system
    home_dir = "C:/Users/antho/github/tamu_ercot_dwpt"
    main_dir = "C:\\Users\\antho\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling"
    DATA_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/data"
    OUT_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/outputs"
    RES_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots"
    active_dir = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/active"
else
    # Link to system
    home_dir = "/home/ansa1773/tamu_ercot_dwpt"
    main_dir = "/scratch/alpine/ansa1773/SIIP_Modeling"
    DATA_DIR = "/projects/ansa1773/SIIP_Modeling/data"
    OUT_DIR = "/scratch/alpine/ansa1773/SIIP_Modeling/outputs"
    RES_DIR = "/scratch/alpine/ansa1773/SIIP_Modeling/results"
    active_dir = "/scratch/alpine/ansa1773/SIIP_Modeling/active"
end

# Reduced_LVL System
system = System(joinpath(active_dir, "tamu_DA_sys_LVLred.json"))
# BasePV System
#system = System(joinpath(main_dir, "test_outputs/tamu_DA_basePV_sys.json"))
#Alterante Systems
#system = System(joinpath(main_dir, "active/tamu_DA_sys.json"))
#system = System(joinpath(DATA_DIR, "texas_data/DA_sys.json"))

# TO REMOVE ADDITIONAL SOLAR
pvs = get_components(RenewableDispatch, system) |> collect

origPV = ["Piano Solar", "Error Solar", "Bonus Solar", "Photo Solar", "Scene Solar",
            "Drama Solar", "Tooth Solar", "Hover Solar", "Straw Solar", "River Solar",
            "Spray 2 Solar", "Smoke Solar", "Rebel Solar", "Toast Solar", "Troop Solar",
            "Mercy Solar", "Storm Solar", "Arena Solar", "Feign Solar", "Glass Solar",
            "Blast Solar", "Giant Solar"]
#counter = 0
num_pvs = size(pvs)[1]
for x = 1: num_pvs
    if pvs[x].prime_mover == PrimeMovers.PVe && pvs[x].name in origPV
        set_available!(pvs[x], true)
    elseif pvs[x].prime_mover == PrimeMovers.PVe
        set_available!(pvs[x], false)
    end
end
to_json(system, joinpath(active_dir, string("tamu_DA_LVLr_BasePV_sys.json")), force=true)
println("New active system file has been created.")
