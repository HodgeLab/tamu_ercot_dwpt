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

using CPLEX

loc_run = false

# Level of EV adoption (value from 0 to 1)
ev_adpt_level = 1
Adopt = "A100_"
Method = "T100"
tran_set = string(Adopt, Method)

if loc_run == true
    # Link to system
    DATA_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/data"
    OUT_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/outputs"
    main_dir = "C:\\Users\\A.J. Sauter\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling"
    local_dir = "C:\\Users\\A.J. Sauter\\Documents"
else
    # Link to system
    home_dir = "/home/ansa1773/tamu_ercot_dwpt"
    main_dir = "/projects/ansa1773/SIIP_Modeling"
    DATA_DIR = "/projects/ansa1773/SIIP_Modeling/data"
    OUT_DIR = "/projects/ansa1773/SIIP_Modeling/outputs"
    RES_DIR = "/projects/ansa1773/SIIP_Modeling/results"
    active_dir = "/projects/ansa1773/SIIP_Modeling/active"
end

# Reduced_LVL System
system = System(joinpath(active_dir, "tamu_DA_sys_LVLred.json"))
# BasePV System
#system = System(joinpath(main_dir, "test_outputs/tamu_DA_basePV_sys.json"))
#Alterante Systems
#system = System(joinpath(main_dir, "active/tamu_DA_sys.json"))
#system = System(joinpath(DATA_DIR, "texas_data/DA_sys.json"))

# INITIALIZE LOADS:
# Get Bus Names
cd(main_dir)
bus_details = CSV.read("bus_load_coords.csv", DataFrame)
bus_names = bus_details[:,1]
load_names = bus_details[:,2]
dim_loads = size(load_names)
num_loads = dim_loads[1]

# Set dates for sim
dates = DateTime(2018, 1, 1, 0):Hour(1):DateTime(2019, 1, 2, 23)
# Set forecast resolution
resolution = Dates.Hour(1)

# Read from Excel File
df = DataFrame(XLSX.readtable(string("ABM_Energy_Output_", tran_set, "_v4.xlsx"), "load_demand")...)

for x = 1: num_loads
    # Extract power demand column
    load_data = df[!, x]*ev_adpt_level
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
to_json(system, joinpath(active_dir, "tamu_DA_LVLred_", tran_set, "_sys.json"), force=true)
println("New active system file has been created.")

# START EXECUTION:
println("MADE IT TO EXECUTION")
cd(home_dir)
#Create empty template
template_uc = ProblemTemplate(NetworkModel(
    DCPPowerModel,
    use_slacks = true,
    duals = [NodalBalanceActiveConstraint] #CopperPlateBalanceConstraint
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
                CPLEX.Optimizer,
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
    simulation_folder = OUT_DIR,
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

date_folder = "Feb22_22/"
sim_week = "_LVL_Red_TEST_"
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
