# cd("C:\\Users\\A.J. Sauter\\github\\tamu_ercot_dwpt\\Satellite_Execution")
# include("DWPT_NoDuals_Ex_Only.jl")

using PowerSystems
using PowerGraphics
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

#ENV["GUROBI_HOME"] = "C:\\gurobi950\\win64"
#import Pkg
#Pkg.add("Gurobi")
#Pkg.build("Gurobi")

# UPDATE SOLVER: GORUBI
using Gurobi #solver (Cbc)

Adopt = "A100_"
Method = "T100"
tran_set = string(Adopt, Method)

# Link to system
DATA_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/data"
main_dir = "C:\\Users\\A.J. Sauter\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling"
system = System(joinpath(main_dir, "active/tamu_DA_sys.json"))
#system = System(joinpath(DATA_DIR, "texas_data/DA_sys.json"))

# Set dates for sim
dates = DateTime(2018, 1, 1, 0):Hour(1):DateTime(2019, 1, 2, 23)
# Set forecast resolution
resolution = Dates.Hour(1)

# START VERIFICATION:
println("MADE IT TO VERIFICATION")
cd("C:\\Users\\A.J. Sauter\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling\\Satellite_Execution")
#Create empty template
template_uc = OperationsProblemTemplate()

#Injection Device Formulations
set_device_model!(template_uc, ThermalMultiStart, ThermalStandardUnitCommitment) #ThermalStandardUnitCommitment
set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
set_device_model!(template_uc, HydroDispatch, FixedOutput)

#Service Formulations
set_service_model!(template_uc, VariableReserve{ReserveUp}, RangeReserve)
set_service_model!(template_uc, VariableReserve{ReserveDown}, RangeReserve)

#Network Formulations
set_transmission_model!(template_uc, CopperPlatePowerModel) #DCPPowerModel)

#Create Optimizer
solver = optimizer_with_attributes(Gurobi.Optimizer) #"ratioGap" => 0.5)

#Build OperationsProblem
op_problem = OperationsProblem(template_uc, system; optimizer = solver, horizon = 24, balance_slack_variables = true, optimizer_log_print = true) #warm_start = false

OUT_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/outputs"
build!(op_problem, output_dir = OUT_DIR)

solve!(op_problem)

#print_struct(PSI.ProblemResults)

res = ProblemResults(op_problem);

get_optimizer_stats(res)
get_objective_value(res)

# START EXECUTION:
println("MADE IT TO EXECUTION")
#Create Optimizer
solver = optimizer_with_attributes(Gurobi.Optimizer) #"logLevel" => 1, "ratioGap" => 0.5)

problems = SimulationProblems(UC = OperationsProblem(template_uc, system, optimizer = solver))

intervals = Dict("UC" => (Hour(24),Consecutive()))

DA_sequence = SimulationSequence(
    problems = problems,
    intervals = intervals,
    ini_cond_chronology = IntraProblemChronology()
)

sim = Simulation(
    name = string("dwpt-week-", tran_set),
    steps = 7,
    problems = problems,
    sequence = DA_sequence,
    #initial_time = DateTime("2018-03-29T00:00:00"),
    #initial_time = DateTime("2018-08-05T00:00:00"),
    #initial_time = DateTime("2018-09-23T00:00:00")
    initial_time = DateTime("2018-01-01T00:00:00"),
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
    #initial_time = DateTime("2018-08-05T00:00:00"),
    #initial_time = DateTime("2018-09-23T00:00:00")
    initial_time = DateTime("2018-01-01T00:00:00"),
    count = 7,
)

set_system!(uc_results, system)

# Execute Plotting
println("MADE IT TO PLOTTING")
gr() # Loads the GR backend
plotlyjs() # Loads the JS backend
timestamps = get_realized_timestamps(uc_results)
variables = read_realized_variables(uc_results)
#plot_dataframe(variables[:P__RenewableDispatch], timestamps)
# TO MAKE A STACK OR BAR CHART:
#plot_dataframe(variables[:P__ThermalMultiStart], timestamps; stack = true)
#plot_dataframe(variables[:P__RenewableDispatch], timestamps; bar = true)

# STACKED GENERATION PLOT:
generation = get_generation_data(uc_results)
date_folder = "Jan14_22/"
sim_week = "_WinterWeek_PeakEV_Part2_"
sim_startday = "_01-01"
simplegen = string("SimpleGenStack", sim_week, tran_set, sim_startday)
plot_dir = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots/"
plot_pgdata(generation, stack = true; title = simplegen, save = string(plot_dir, date_folder), format = "png");

# Stacked Gen by Fuel Type:
fuelgen = string("FuelGenStack", sim_week, tran_set, sim_startday)
plot_fuel(uc_results, stack = true; title = fuelgen, save = string(plot_dir, date_folder), format = "png");

# Reserves Plot
reserves = get_service_data(uc_results)
resgen = string("Reserves", sim_week, tran_set, sim_startday)
plot_pgdata(reserves; title = resgen, save = string(plot_dir, date_folder), format = "png");

# Write Excel Output Files
cd(string("C:\\Users\\A.J. Sauter\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling\\Satellite_Execution\\Result_Plots\\", date_folder))
xcelname = string("_Output", sim_week, tran_set, sim_startday, ".xlsx")
# Simple XLSX file output with ability to overwrite
XLSX.writetable(
    string("RE_GEN", xcelname),
    variables[:P__RenewableDispatch],
    overwrite=true,
    sheetname="RE_Dispatch",
    anchor_cell="A1"
)
XLSX.writetable(
    string("TH_GEN", xcelname),
    variables[:P__ThermalMultiStart],
    overwrite=true,
    sheetname="TH_Dispatch",
    anchor_cell="A1"
)
#XLSX.writetable(
#    string("Curtailed", xcelname),
#    variables[:______], FILL THIS IN
#    overwrite=true,
#    sheetname="Curtailments",
#    anchor_cell="A1"
#)
