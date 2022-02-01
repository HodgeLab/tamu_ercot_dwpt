# Commands for Julia Window:
# cd("C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution")
# include("DWPT_Study_Verification.jl")

using PowerSystems
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

using Cbc #solver

# Link to system
DATA_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/data"
main_dir = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/"
#system = System(joinpath(main_dir, "data/texas_data/DA_sys.json"))
system = System(joinpath(main_dir, "active/tamu_DA_sys.json"))

#Create Optimizer
solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 1, "ratioGap" => 0.5)

OUT_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/outputs"

problems = SimulationProblems(UC = OperationsProblem(template_uc, system, optimizer = solver, warm_start = false))

intervals = Dict("UC" => (Hour(24),Consecutive()))

DA_sequence = SimulationSequence(
    problems = problems,
    intervals = intervals,
    ini_cond_chronology = IntraProblemChronology()
)

sim = Simulation(
    name = "dwpt-week-test",
    steps = 60,
    problems = problems,
    sequence = DA_sequence,
    #initial_time = DateTime("2018-03-29T00:00:00"),
    initial_time = DateTime("2018-06-01T00:00:00"),
    #initial_time = DateTime("2018-09-23T00:00:00")
    #initial_time = DateTime("2018-12-22T00:00:00")
    simulation_folder = DATA_DIR
)

build!(sim)

execute!(sim, enable_progress_bar = false)

results = SimulationResults(sim);
uc_results = get_problem_results(results, "UC"); # UC stage result metadata

read_parameter(
    uc_results,
    :P__max_active_power__RenewableDispatch_max_active_power,
    #initial_time = DateTime("2018-03-29T00:00:00"),
    initial_time = DateTime("2018-06-01T00:00:00"),
    #initial_time = DateTime("2018-09-23T00:00:00")
    #initial_time = DateTime("2018-12-22T00:00:00")
    count = 60,
)

# Execute Plotting
println("MADE IT TO PLOTTING")
gr() # Loads the GR backend
#plotlyjs() # Loads the JS backend - PROBLEMCHILD
timestamps = get_realized_timestamps(uc_results)
variables = read_realized_variables(uc_results)
#plot_dataframe(variables[:P__RenewableDispatch], timestamps)
# TO MAKE A STACK OR BAR CHART:
#plot_dataframe(variables[:P__ThermalMultiStart], timestamps; stack = true)
#plot_dataframe(variables[:P__RenewableDispatch], timestamps; bar = true)

# STACKED GENERATION PLOT:
generation = get_generation_data(uc_results)
date_folder = "Sep30_21/"
sim_week = "_SummerWeek_"
traffic_setting = "#A50_H100"
simplegen = string("SimpleGenStack", sim_week, traffic_setting)
#plot_dir = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Anna_outputs/results/"
plot_dir = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots/"
plot_pgdata(generation, stack = true; title = simplegen, save = string(plot_dir, date_folder), format = "png");

# Stacked Gen by Fuel Type:
fuelgen = string("FuelGenStack", sim_week, traffic_setting)
plot_fuel(uc_results, stack = true; title = fuelgen, save = string(plot_dir, date_folder), format = "png");

# Reserves Plot
reserves = get_service_data(uc_results)
resgen = string("Reserves", sim_week, traffic_setting)
plot_pgdata(reserves; title = resgen, save = string(plot_dir, date_folder), format = "png");
