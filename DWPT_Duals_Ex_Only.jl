# cd("C:\\Users\\A.J. Sauter\\github\\tamu_ercot_dwpt\\Satellite_Execution\\oldSchool")
# include("DWPT_Duals_Ex_Only.jl")

# MUST USE #DEV Version of PowerSimulations.jl

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

using Gurobi
#using Cbc

#ENV["GUROBI_HOME"] = "C:\\gurobi950\\win64"
#import Pkg
#Pkg.add("Gurobi")
#Pkg.build("Gurobi")

#using JuMP, Gurobi

# UPDATE SOLVER: GORUBI
#using Gorubi #solver

Adopt = "A100_"
Method = "T100"
tran_set = string(Adopt, Method)

# Link to system
DATA_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/data"
OUT_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/outputs"
main_dir = "C:\\Users\\A.J. Sauter\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling"
local_dir = "C:\\Users\\A.J. Sauter\\github\\tamu_ercot_dwpt"
system = System(joinpath(local_dir, "Local_Sys_Files/tamu_DA_sys.json"))

#system = System(joinpath(main_dir, "active/tamu_DA_sys.json"))
#system = System(joinpath(DATA_DIR, "texas_data/DA_sys.json"))

# Set dates for sim
dates = DateTime(2018, 1, 1, 0):Hour(1):DateTime(2019, 1, 2, 23)
# Set forecast resolution
resolution = Dates.Hour(1)

# START EXECUTION:
println("MADE IT TO EXECUTION")
cd("C:\\Users\\A.J. Sauter\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling\\Satellite_Execution")
#Create empty template
template_uc = ProblemTemplate(NetworkModel(
    CopperPlatePowerModel, #DCPPowerModel,
    use_slacks = true,
    duals = [CopperPlateBalanceConstraint] #CopperPlateBalanceConstraint
))

#Injection Device Formulations
#set_device_model!(template_uc, ThermalMultiStart, ThermalBasicUnitCommitment) #ThermalStandardUnitCommitment
#set_device_model!(template_uc, ThermalMultiStart, ThermalStandardUnitCommitment)
set_device_model!(template_uc, ThermalMultiStart, ThermalBasicCompactUnitCommitment)
set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
set_device_model!(template_uc, HydroDispatch, FixedOutput)
# Check these? May be diff. for TAMU
#set_device_model!(template_uc, Line, StaticBranchUnbounded)
#set_device_model!(template_uc, Transformer2W, StaticBranchUnbounded)
#set_device_model!(template_uc, TapTransformer, StaticBranchUnbounded)

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
                #"ratioGap" => 0.5
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
    name = string("dwpt-week-", tran_set),
    steps = 7,
    models = models,
    sequence = DA_sequence,
    #initial_time = DateTime("2018-03-29T00:00:00"),
    #initial_time = DateTime("2018-08-05T00:00:00"),
    #initial_time = DateTime("2018-09-23T00:00:00")
    initial_time = DateTime("2018-01-01T00:00:00"),
    simulation_folder = DATA_DIR,
)

# Use serialize = false only during development
build_out = build!(sim, serialize = false)
execute!(sim)

results = SimulationResults(sim);
uc_results = get_problem_results(results, "UC"); # UC stage result metadata

set_system!(uc_results, system)

# Execute Results
println("MADE IT TO RESULTS")

timestamps = get_realized_timestamps(uc_results)
variables = read_realized_variables(uc_results)

# GET RESULTS FROM THIS System
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

date_folder = "Jan14_22/"
sim_week = "_WinterWeek_PeakEV_DUALS"
sim_startday = "_01-01"
simplegen = string("SimpleGenStack", sim_week, tran_set, sim_startday)
plot_dir = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots/"

# Reserves Plot
resgen = string("Reserves", sim_week, tran_set, sim_startday)

# Write Excel Output Files
cd(string("C:\\Users\\A.J. Sauter\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling\\Satellite_Execution\\Result_Plots\\", date_folder))
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
#XLSX.writetable(
#    string("Curtailed", xcelname),
#    variables[:______], FILL THIS IN
#    overwrite=true,
#    sheetname="Curtailments",
#    anchor_cell="A1"
#)
