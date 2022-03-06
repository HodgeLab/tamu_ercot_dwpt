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

loc_run = false

# Level of EV adoption (value from 0 to 1)
ev_adpt_level = .05
Adopt = "A05_"
Method = "T100"
tran_set = string(Adopt, Method)
sim_name = "_dwpt-test_"

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
    main_dir = "/scratch/summit/ansa1773/SIIP_Modeling"
    DATA_DIR = "/projects/ansa1773/SIIP_Modeling/data"
    OUT_DIR = "/scratch/summit/ansa1773/SIIP_Modeling/outputs"
    RES_DIR = "/scratch/summit/ansa1773/SIIP_Modeling/results"
    active_dir = "/scratch/summit/ansa1773/SIIP_Modeling/active"
end

# Reduced_LVL System
system = System(joinpath(active_dir, string("tamu_DA_LVLr_", tran_set, "_sys.json")))
# BasePV System
#system = System(joinpath(main_dir, "test_outputs/tamu_DA_basePV_sys.json"))
#Alterante Systems
#system = System(joinpath(main_dir, "active/tamu_DA_sys.json"))
#system = System(joinpath(DATA_DIR, "texas_data/DA_sys.json"))

# Set dates for sim
dates = DateTime(2018, 1, 1, 0):Hour(1):DateTime(2019, 1, 2, 23)
# Set forecast resolution
resolution = Dates.Hour(1)

# START EXECUTION:
println("MADE IT TO EXECUTION")
cd(home_dir)
#Create empty template
template_uc = ProblemTemplate(NetworkModel(
    DCPPowerModel, #CopperPlatePowerModel,
    use_slacks = true,
    duals = [NodalBalanceActiveConstraint] #CopperPlateBalanceConstraint  ActivePowerNodalBalance
))

#Injection Device Formulations
set_device_model!(template_uc, ThermalMultiStart, ThermalBasicUnitCommitment) #ThermalStandardUnitCommitment
#set_device_model!(template_uc, ThermalMultiStart, ThermalStandardUnitCommitment)
#set_device_model!(template_uc, ThermalMultiStart, ThermalBasicCompactUnitCommitment)
set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
set_device_model!(template_uc, HydroDispatch, FixedOutput)
# Check these? May be diff. for TAMU
set_device_model!(template_uc, Line, StaticBranchUnbounded)
set_device_model!(template_uc, Transformer2W, StaticBranchUnbounded)
set_device_model!(template_uc, TapTransformer, StaticBranchUnbounded)

#Service Formulations
set_service_model!(template_uc, VariableReserve{ReserveUp}, RangeReserve)
set_service_model!(template_uc, VariableReserve{ReserveDown}, RangeReserve)

models = SimulationModels(
    decision_models = [
        DecisionModel(
            template_uc,
            system;
            name = "UC",
            optimizer = optimizer_with_attributes(
                Gurobi.Optimizer,
                #"logLevel" => 1,
            ),
            system_to_file = false,
            initialize_model = false, # Changed!
            #calculate_conflict = true,
            optimizer_solve_log_print = true,
            direct_mode_optimizer = true,
        )
    ]
)

DA_sequence = SimulationSequence(
    models = models,
    #intervals = intervals,
    ini_cond_chronology = InterProblemChronology()
)

sim = Simulation(
    name = string("dwpt-test-", tran_set),
    steps = 1,
    models = models,
    sequence = DA_sequence,
    #initial_time = DateTime("2018-03-29T00:00:00"),
    #initial_time = DateTime("2018-08-05T00:00:00"),
    #initial_time = DateTime("2018-09-23T00:00:00")
    initial_time = DateTime("2018-01-01T00:00:00"),
    simulation_folder = OUT_DIR,
)
# Use serialize = false only during development
println("")
println("building sim...")
build_out = build!(sim, serialize = false)
println("begin execution:")
execute!(sim)
println("")

results = SimulationResults(sim);
uc_results = get_problem_results(results, "UC"); # UC stage result metadata
set_system!(uc_results, system)
# Execute Results
println("MADE IT TO RESULTS")

timestamps = get_realized_timestamps(uc_results)
variables = read_realized_variables(uc_results)
parameters = read_realized_parameters(uc_results)

# GET RESULTS FROM THIS System
# FROM #master BRANCH:
# variables.keys
# variables.vals
renPwr = variables["ActivePowerVariable__RenewableDispatch"]
thermPwr = variables["ActivePowerVariable__ThermalMultiStart"]
load_param = parameters["ActivePowerTimeSeriesParameter__PowerLoad"]
resUp_param = parameters["RequirementTimeSeriesParameter__VariableReserve__ReserveUp__REG_UP"]
resDown_param = parameters["RequirementTimeSeriesParameter__VariableReserve__ReserveDown__REG_DN"]
resSpin_param = parameters["RequirementTimeSeriesParameter__VariableReserve__ReserveUp__REG_UP"]

# FROM #DEV BRANCH:
# keys(variables)
# collect(values(variables[ENTER KEY HERE])
#slackUp = get!(variables, PowerSimulations.VariableKey{SystemBalanceSlackUp, System}(""), 1)
#slackDown = get!(variables, PowerSimulations.VariableKey{SystemBalanceSlackDown, System}(""), 1)
#renPwr = get!(variables, PowerSimulations.VariableKey{ActivePowerVariable, RenewableDispatch}(""), 1)
#thermPwr = get!(variables, PowerSimulations.VariableKey{ActivePowerVariable, ThermalMultiStart}(""), 1)
#spinRes = get!(variables, PowerSimulations.VariableKey{ActivePowerReserveVariable, VariableReserve{ReserveUp}}("SPIN"), 1)
#regDwn = get!(variables, PowerSimulations.VariableKey{ActivePowerReserveVariable, VariableReserve{ReserveDown}}("REG_DN"), 1)
#regUp = get!(variables, PowerSimulations.VariableKey{ActivePowerReserveVariable, VariableReserve{ReserveUp}}("REG_UP"), 1)
#thermOn = get!(variables, PowerSimulations.VariableKey{OnVariable, ThermalMultiStart}(""), 1)
#thermStart = get!(variables, PowerSimulations.VariableKey{StartVariable, ThermalMultiStart}(""), 1)
#thermStop = get!(variables, PowerSimulations.VariableKey{StopVariable, ThermalMultiStart}(""), 1)

date_folder = "/Feb22_22/"
sim_week = "_LVL_Red_TEST1_"
sim_startday = "_01-01"
fuelgen = string("FuelGenStack", sim_week)
plot_fuel(uc_results, stack = true; title = fuelgen, save = string(RES_DIR, date_folder), format = "svg"); #To Specify Window: initial_time = DateTime("2018-01-01T00:00:00"), count = 168
# NOTE: Zoom in with plotlyJS backend

# Demand Plot
dem_name = string("PowerLoadDemand", sim_week)
load_demand = get_load_data(uc_results);
plot_demand(uc_results; title = load_demand, save = string(RES_DIR, date_folder), format = "svg"); #To Specify Window: initial_time = DateTime("2018-01-01T00:00:00"), count = 100)
# NOTE: Zoom in with plotlyJS backend

# Reserves Plot
resgen = string("Reserves", sim_week, tran_set, sim_startday)
reserves = get_service_data(uc_results);
plot_pgdata(reserves; title = resgen, save = string(RES_DIR, date_folder), format = "svg");
# NOTE: Zoom in with plotlyJS backend

# Write Excel Output Files
cd(string(RES_DIR, date_folder))
xcelname = string("_Output", sim_week, tran_set, sim_startday, ".xlsx")
# Simple XLSX file output with ability to overwrite
XLSX.writetable(
    string("RE_GEN", xcelname),
    renPwr,
    overwrite=true,
    sheetname="RE_Dispatch",
    anchor_cell="A1"
)
XLSX.writetable(
    string("TH_GEN", xcelname),
    thermPwr,
    overwrite=true,
    sheetname="TH_Dispatch",
    anchor_cell="A1"
)
XLSX.writetable(
    string("DEMAND", xcelname),
    load_param,
    overwrite=true,
    sheetname="Demand",
    anchor_cell = "A1"
)
XLSX.writetable(
    string("RESERVES", xcelname),
    resUp_param,
    overwrite=true,
    sheetname="ResUP",
    anchor_cell = "A1"
)
XLSX.writetable(
    string("RESERVES", xcelname),
    resDown_param,
    overwrite=true,
    sheetname="ResDWN",
    anchor_cell = "A1"
)
XLSX.writetable(
    string("RESERVES", xcelname),
    resSpin_param,
    overwrite=true,
    sheetname="ResSPIN",
    anchor_cell = "A1"
)

"""
# COMPARE INITIAL CONDITIONS:
# Step 1. BUILD SIM BUT DO NOT EXECUTE

uc_model = get_simulation_model(sim, :UC)
container_uc = PSI.get_optimization_container(uc_model)

container_uc. # (PRESS TAB TO SHOW FIELDS)
container_uc.initial_conditions # (SHOWS DICT WITH KEYS)

keys(container_uc.initial_conditions)
ics_values = container_uc.initial_conditions[ COPY PASTE DEVICE STATUS ];

for ic in ics_values
@show PSI.get_component_name(ic)
@show PSI.get_condition(ic)
end
"""
