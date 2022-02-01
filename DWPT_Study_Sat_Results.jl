# Commands for Julia Window:
# cd("C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution")
# include("DWPT_Study_Sat_Results.jl")

using PowerSystems
using PowerGraphics
using PowerSimulations
using InfrastructureSystems
const PSI = PowerSimulations


using Dates
using Plots
using PyPlot
using DataFrames

using Cbc #solver

# Link to system
DATA_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/data"
system = System(joinpath(DATA_DIR, "texas_data/DA_sys.json"))

# WHAT TO DO IF YOU ALREADY HAVE A RESULTS FOLDER:

sim_folder = joinpath(DATA_DIR, "dwpt-week-A40_H100")
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
