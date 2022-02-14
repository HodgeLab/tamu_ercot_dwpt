# cd("C:\\Users\\A.J. Sauter\\github\\tamu_ercot_dwpt")
# include("DWPT_Duals_Execution.jl")

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

Adopt = "A100_"
Method = "T100"
tran_set = string(Adopt, Method)

# Link to system
DATA_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/data"
OUT_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/outputs"
main_dir = "C:\\Users\\A.J. Sauter\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling"
local_dir = "C:\\Users\\A.J. Sauter\\Documents"
system = System(joinpath(DATA_DIR, "texas_data/DA_sys.json"))

# INITIALIZE LOADS:
# Get Bus Names
cd("C:\\Users\\A.J. Sauter\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling")
bus_details = CSV.read("bus_load_coords.csv", DataFrame)
bus_names = bus_details[:,1]
load_names = bus_details[:,2]

cd(string("C:\\Users\\A.J. Sauter\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Texas Traffic Data\\STAR II Database\\Load_Volumes_post"))
load_list = readdir()
dim_loads = size(load_list)
num_loads = dim_loads[1]

# Set dates for sim
dates = DateTime(2018, 1, 1, 0):Hour(1):DateTime(2019, 1, 2, 23)
# Set forecast resolution
resolution = Dates.Hour(1)

cd("C:\\Users\\A.J. Sauter\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Texas Traffic Data\\NHTS_Database\\ABM_Outputs")
# Read from Excel File
df = DataFrame(XLSX.readtable(string("ABM_Energy_Output_", tran_set, "_v4.xlsx"), "load_demand")...)

for x = 1: num_loads
    # Read from Excel File
    # xf = XLSX.readxlsx(string("ABM_Energy_Output_", tran_set, "_v4.xlsx"))
    # sh = xf["load_demand"]

    # Extract power demand column
    load_data = df[!, x]*0.05
    if maximum(load_data) > 2
        @error("$x - $(maximum(load_data))")
    end
    # Convert to TimeArray
    load_array = TimeArray(dates, load_data)
    #println(load_array[1])

    # Create forecast dictionary
    forecast_data = Dict()
    for i = 1:365
        strt = (i-1)*24+1
        finish = i*24+12
        forecast_data[dates[strt]] = load_data[strt:finish]
    end
    # Create deterministic time series data
    time_series = Deterministic("max_active_power",forecast_data, resolution)

    # Check for pre-existing DWPT PowerLoad components
    l_name = string(load_names[x], "_DWPT")
    new_load = get_component(PowerLoad, system, l_name)
    if isnothing(new_load)
        #println("Load not found. Now creating...")
        # Create new load
        new_load = PowerLoad(
            name = string(l_name), # ADD '_DWPT' to each bus name
            available = true,
            bus = get_component(Bus, system, bus_names[x]), # USE BUS_LOAD_COORDS.CSV COLUMN 1
            model = "ConstantPower",
            active_power = 1.0,
            reactive_power = 1.0,
            base_power = 100.0,
            max_active_power = 1.5,
            max_reactive_power = 1.3,
            services = [],
            )
        # Add component to system
        add_component!(system, new_load)
        # Add deterministic forecast to the system
        add_time_series!(system, new_load, time_series)
        #println("Load created, time series added.")
    else
        # Add deterministic forecast to the system
        # NOTE: run another "try" instance w/o the "catch", add_time_series after it
        try
            remove_time_series!(system, Deterministic, new_load, "max_active_power")
        catch
            #println("Time Series data did not previously exist. Now adding...")
        end
        add_time_series!(system, new_load, time_series)
        #println("Time series added.")
    end
end
to_json(system, joinpath(local_dir, "Local_Sys_Files/tamu_DA_sys.json"), force=true)
println("New active system file has been created.")

# START EXECUTION:
println("MADE IT TO EXECUTION")
cd("C:\\Users\\A.J. Sauter\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling\\Satellite_Execution")
#Create empty template
template_uc = ProblemTemplate(NetworkModel(
    DCPPowerModel,
    use_slacks = true,
    duals = [FlowActivePowerConstraint] #CopperPlateBalanceConstraint
))

#Injection Device Formulations
set_device_model!(template_uc, ThermalMultiStart, ThermalBasicUnitCommitment) #ThermalBasicUnitCommitment
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
                #"ratioGap" => 0.5
            ),
            system_to_file = false,
            initialize_model = false,
            #calculate_conflict = true,
            optimizer_solve_log_print = true,
            direct_mode_optimizer = true,
        )
    ]
)

DA_sequence = SimulationSequence(
    models = models,
    #intervals = intervals,
    ini_cond_chronology = IntraProblemChronology()
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
# FROM #master BRANCH:
# variables.keys
# variables.vals
renPwr = variables["ActivePowerVariable__RenewableDispatch"]
thermPwr = variables["ActivePowerVariable__ThermalMultiStart"]
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
