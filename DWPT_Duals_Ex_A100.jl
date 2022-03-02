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
sim_name = "_dwpt-hs-lvlr_"

if loc_run == true
    # Link to system
    home_dir = "C:/Users/antho/github/tamu_ercot_dwpt"
    main_dir = "C:\\Users\\antho\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling"
    DATA_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/data"
    OUT_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/outputs"
    RES_DIR = "C:/Users/antho/OneDrive - UCB-0365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots"
    active_dir = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/active"
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
df = DataFrame(XLSX.readtable(string("ABM_Energy_Output_A100_T100_v4.xlsx"), "load_demand")...)

for x = 1: num_loads
    # Extract power demand column
    load_data = df[!, x]*ev_adpt_level
    if maximum(load_data) > 2
        @error("$x - $(maximum(load_data))")
    end
    # Convert to TimeArray
    load_array = TimeArray(dates, load_data)
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
    else
        # Add deterministic forecast to the system
        # NOTE: run another "try" instance w/o the "catch", add_time_series after it
        try
            remove_time_series!(system, Deterministic, new_load, "max_active_power")
        catch
        end
        add_time_series!(system, new_load, time_series)
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
                "CPXPARAM_MIP_Tolerances_MIPGap" => 1e-3,
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
    ini_cond_chronology = InterProblemChronology()
)

sim = Simulation(
    name = string("dwpt-hs-lvlr-", tran_set),
    steps = 365,
    models = models,
    sequence = DA_sequence,
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
renPwr = variables["ActivePowerVariable__RenewableDispatch"]
thermPwr = variables["ActivePowerVariable__ThermalMultiStart"]
load_param = parameters["ActivePowerTimeSeriesParameter__PowerLoad"]
resUp_param = parameters["RequirementTimeSeriesParameter__VariableReserve__ReserveUp__REG_UP"]
resDown_param = parameters["RequirementTimeSeriesParameter__VariableReserve__ReserveDown__REG_DN"]
resSpin_param = parameters["RequirementTimeSeriesParameter__VariableReserve__ReserveUp__REG_UP"]

date_folder = "Feb22_22/"
fuelgen = string("FuelGenStack", sim_name)
plot_fuel(uc_results, stack = true; title = fuelgen, save = string(RES_DIR, date_folder), format = "svg"); #To Specify Window: initial_time = DateTime("2018-01-01T00:00:00"), count = 168
# NOTE: Zoom in with plotlyJS backend

# Demand Plot
dem_name = string("PowerLoadDemand", sim_name)
load_demand = get_load_data(uc_results);
plot_demand(uc_results; title = dem_name, save = string(RES_DIR, date_folder), format = "svg"); #To Specify Window: initial_time = DateTime("2018-01-01T00:00:00"), count = 100)
# NOTE: Zoom in with plotlyJS backend

# Reserves Plot
resgen = string("Reserves", sim_name, tran_set)
reserves = get_service_data(uc_results);
plot_pgdata(reserves; title = resgen, save = string(RES_DIR, date_folder), format = "svg");
# NOTE: Zoom in with plotlyJS backend

# Write Excel Output Files
cd(string(RES_DIR, date_folder))
xcelname = string("_Output", sim_name, tran_set, ".xlsx")
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
