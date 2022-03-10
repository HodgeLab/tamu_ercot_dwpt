# cd("C:\\Users\\A.J. Sauter\\github\\tamu_ercot_dwpt")
# include("DWPT_Duals_Execution.jl")

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

run_spot = "HOME"

# Level of EV adoption (value from 0 to 1)
ev_adpt_level = .05
Adopt = "A05_"
Method = "T100"
tran_set = string(Adopt, Method)
sim_name = "_dwpt-hs-lvlr_"

if run_spot == "HOME"
    # Link to system
    home_dir = "C:/Users/antho/github/tamu_ercot_dwpt"
    main_dir = "C:\\Users\\antho\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling"
    DATA_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/data"
    OUT_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/outputs"
    RES_DIR = "C:/Users/antho/OneDrive - UCB-0365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots"
    active_dir = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/active"
elseif run_spot == "SEEC"
    home_dir = "C:/Users/A.J. Sauter/github/tamu_ercot_dwpt"
    main_dir = "C:\\Users\\A.J. Sauter\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling"
    DATA_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/data"
    OUT_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/outputs"
    RES_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-0365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots"
    active_dir = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/active"
elseif run_spot == "Desktop"
    home_dir = "A:/Users/Documents/ASPIRE_Simulators/tamu_ercot_dwpt"
    main_dir = "A:/Users/AJ/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling"
    DATA_DIR = "A:/Users/AJ/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/data"
    OUT_DIR = "A:/Users/AJ/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/outputs"
    RES_DIR = "A:/Users/AJ/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots"
    active_dir = "A:/Users/AJ/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/active"
else
    # Link to system
    home_dir = "/home/ansa1773/tamu_ercot_dwpt"
    main_dir = "/projects/ansa1773/SIIP_Modeling"
    DATA_DIR = "/projects/ansa1773/SIIP_Modeling/data"
    OUT_DIR = "/projects/ansa1773/SIIP_Modeling/outputs"
    RES_DIR = "/projects/ansa1773/SIIP_Modeling/results"
    active_dir = "/projects/ansa1773/SIIP_Modeling/active"
end


system = System(joinpath(DATA_DIR, "tamu_DA_LVLr_bpv_A05_T100_sys.json"))

# WHAT TO DO IF YOU ALREADY HAVE A RESULTS FOLDER:

sim_folder = joinpath(OUT_DIR, "dwpt-bpv-lvlr-A05_T100")
sim_folder = joinpath(sim_folder, "$(maximum(parse.(Int64,readdir(sim_folder))))")
results = SimulationResults(sim_folder);
uc_results = get_problem_results(results, "UC")

set_system!(uc_results, system)

# Execute Plotting
gr() # Loads the GR backend
#plotlyjs() # Loads the JS backend - PROBLEMCHILD
timestamps = get_realized_timestamps(uc_results)
timestamps = DateTime("2018-07-08T00:00:00"):Millisecond(3600000):DateTime("2018-07-08T23:00:00")
variables = read_realized_variables(uc_results)
#plot_dataframe(variables[:P__RenewableDispatch], timestamps)
# TO MAKE A STACK OR BAR CHART:
#plot_dataframe(variables[:P__ThermalMultiStart], timestamps; stack = true)
#plot_dataframe(variables[:P__RenewableDispatch], timestamps; bar = true)

# STACKED GENERATION PLOT:
generation = get_generation_data(uc_results)
date_folder = "Sep30_21/"
sim_week = "_SummerDay"
simplegen = string("SimpleGenStack", sim_week)
plot_dir = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots/"
plot_pgdata(generation, stack = true; title = simplegen, save = string(plot_dir, date_folder), format = "png");

# Stacked Gen by Fuel Type:
fuelgen = string("FuelGenStack", sim_week)
plot_fuel(uc_results, stack = true; title = fuelgen, save = string(plot_dir, date_folder), format = "png");

# Reserves Plot
reserves = get_service_data(uc_results)
resgen = string("Reserves", sim_week)
plot_pgdata(reserves; title = resgen, save = string(plot_dir, date_folder), format = "png");
