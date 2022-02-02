# cd("C:\\Users\\A.J. Sauter\\github\\tamu_ercot_dwpt\\Satellite_Execution")
# include("Anne_Execution.jl")


# test git updates
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

using Cbc #solver

tran_set = "Base_System"

# Link to system
DATA_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/data"
system = System(joinpath(DATA_DIR, "texas_data/DA_sys.json"))

# START VERIFICATION:
println("MADE IT TO VERIFICATION")
cd("C:\\Users\\A.J. Sauter\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling\\Satellite_Execution")
#Create empty template
template_uc = OperationsProblemTemplate()

#Injection Device Formulations
set_device_model!(template_uc, ThermalMultiStart, ThermalStandardUnitCommitment) #ThermalMultiStart, ThermalStandardUnitCommitment
set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
set_device_model!(template_uc, HydroDispatch, FixedOutput)

#Service Formulations
set_service_model!(template_uc, VariableReserve{ReserveUp}, RangeReserve)
set_service_model!(template_uc, VariableReserve{ReserveDown}, RangeReserve)

#Network Formulations
set_transmission_model!(template_uc, CopperPlatePowerModel)

#Create Optimizer
solver = optimizer_with_attributes(Cbc.Optimizer, "ratioGap" => 0.5)

#Build OperationsProblem
op_problem = OperationsProblem(template_uc, system; optimizer = solver, horizon = 24, warm_start = false, balance_slack_variables = true, optimizer_log_print = false)

OUT_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Anna_outputs/DA_sys"
build!(op_problem, output_dir = OUT_DIR)

solve!(op_problem)

#print_struct(PSI.ProblemResults)

res = ProblemResults(op_problem);

get_optimizer_stats(res)
get_objective_value(res)

# START EXECUTION:
println("MADE IT TO EXECUTION")
#Create Optimizer
solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 1, "ratioGap" => 0.5)

sys_RT = System(joinpath(DATA_DIR, "texas_data/RT_sys.json"))
template_ed = template_economic_dispatch()

set_device_model!(template_ed, ThermalMultiStart, ThermalBasicUnitCommitment)

problems = SimulationProblems(
    UC = OperationsProblem(template_uc, system, optimizer = solver),
    ED = OperationsProblem(
        template_ed,
        sys_RT,
        optimizer = solver,
        balance_slack_variables = true,
        warm_start = false,
        optimizer_log_print = false,
    ),
)

feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24))

feedforward = Dict(
    ("ED", :devices, :ThermalMultiStart) => SemiContinuousFF(
        binary_source_problem = PSI.ON,
        affected_variables = [PSI.ACTIVE_POWER],
    ),
)

intervals = Dict("UC" => (Hour(24),Consecutive()), "ED" => (Minute(5), Consecutive()))

DA_RT_sequence = SimulationSequence(
    problems = problems,
    intervals = intervals,
    ini_cond_chronology = InterProblemChronology(),
    feedforward_chronologies = feedforward_chronologies,
    feedforward = feedforward,
)

sim = Simulation(
    name = string("two-months-", tran_set),
    steps = 61,
    problems = problems,
    sequence = DA_RT_sequence,
    #initial_time = DateTime("2018-03-29T00:00:00"),
    initial_time = DateTime("2018-06-01T00:00:00"),
    #initial_time = DateTime("2018-09-23T00:00:00")
    #initial_time = DateTime("2018-12-22T00:00:00")
    simulation_folder = DATA_DIR
)

cd("C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Anna_outputs/RT_sys")
build!(sim)

execute!(sim, enable_progress_bar = false)

results = SimulationResults(sim);
uc_results = get_problem_results(results, "UC"); # UC stage result metadata
ed_results = get_problem_results(results, "ED"); # ED stage result metadata

read_variables(uc_results)
read_variables(ed_results)

#
#read_parameter(
#    uc_results,
#    :P__max_active_power__RenewableDispatch_max_active_power,
    #initial_time = DateTime("2018-03-29T00:00:00"),
#    initial_time = DateTime("2018-06-01T00:00:00"),
    #initial_time = DateTime("2018-09-23T00:00:00")
    #initial_time = DateTime("2018-12-22T00:00:00")
#    count = 60,
#)

#set_system!(uc_results, system)

# Execute Plotting
#println("MADE IT TO PLOTTING")
#gr() # Loads the GR backend
#plotlyjs() # Loads the JS backend
#timestamps = get_realized_timestamps(uc_results)
#variables = read_realized_variables(uc_results)
#plot_dataframe(variables[:P__RenewableDispatch], timestamps)
# TO MAKE A STACK OR BAR CHART:
#plot_dataframe(variables[:P__ThermalMultiStart], timestamps; stack = true)
#plot_dataframe(variables[:P__RenewableDispatch], timestamps; bar = true)

# STACKED GENERATION PLOT:
#generation = get_generation_data(uc_results)
#date_folder = "Oct8_21/"
#sim_week = "_SummerWeek_"
#sim_startday = "_8-05"
#simplegen = string("SimpleGenStack", sim_week, tran_set, sim_startday)
#plot_dir = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots/"
#plot_pgdata(generation, stack = true; title = simplegen, save = string(plot_dir, date_folder), format = "png");

# Stacked Gen by Fuel Type:
#fuelgen = string("FuelGenStack", sim_week, tran_set, sim_startday)
#plot_fuel(uc_results, stack = true; title = fuelgen, save = string(plot_dir, date_folder), format = "png");

# Reserves Plot
#reserves = get_service_data(uc_results)
#resgen = string("Reserves", sim_week, tran_set, sim_startday)
#plot_pgdata(reserves; title = resgen, save = string(plot_dir, date_folder), format = "png");


# USEFUL STUFF FROM JDL
#ld=first(get_components(PowerLoad,system))

# res = ProblemResults(op_problem);
# res.variable_values[:γ⁺__P]
# res.variable_values[:γ⁻__P]
