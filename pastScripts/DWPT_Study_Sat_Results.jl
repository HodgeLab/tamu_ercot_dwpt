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

sim_folder = joinpath(DATA_DIR, "dwpt-week-_A05T100_")
sim_folder = joinpath(sim_folder, "$(maximum(parse.(Int64,readdir(sim_folder))))")
results = SimulationResults(sim_folder);
uc_results = get_problem_results(results, "UC")

set_system!(uc_results, system)

# Execute Plotting
gr() # Loads the GR backend
# # Loads the JS backend
timestamps = get_realized_timestamps(uc_results)
timestamps2 = DateTime("2018-07-08T00:00:00"):Millisecond(3600000):DateTime("2018-07-08T23:00:00")
variables = read_realized_variables(uc_results);
#plot_dataframe(variables[:P__RenewableDispatch], timestamps)
# TO MAKE A STACK OR BAR CHART:
#plot_dataframe(variables[:P__ThermalMultiStart], timestamps; stack = true)
#plot_dataframe(variables[:P__RenewableDispatch], timestamps; bar = true)

# STACKED GENERATION PLOT:
generation = get_generation_data(uc_results);
date_folder = "Jan14_22/"
sim_week = "_SummerDay2"
simplegen = string("SimpleGenStack", sim_week)
plot_dir = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots/"
plot_demand(result, initial_time = DateTime("2018-01-01T00:00:00"), count = 100)


# Stacked Gen by Fuel Type:
fuelgen = string("FuelGenStack", sim_week)
plot_fuel(uc_results, initial_time = DateTime("2018-01-01T00:00:00"), count = 168, stack = true; title = fuelgen, save = string(plot_dir, date_folder), format = "svg");

# Reserves Plot
reserves = get_service_data(uc_results)
resgen = string("Reserves", sim_week)
plot_pgdata(reserves; title = resgen, save = string(plot_dir, date_folder), format = "png");
