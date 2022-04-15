"""
Step 1. Package Initialization
Julia implements packages to access libraries with methods/functions (like Python!)

To install a package via the Julia REPL (command window), type "]" to enter the
Pkg handler. This will allow you to add or remove packages from the current
environment. If no environment is specified, a default environment will be
created at the default path for the Julia application.

To activate an environment, type: "activate" and the name of the environment.
To create an environment, use the same steps as above. As long as the environment
name has not been taken in the current directory, a new file path will be created
with its own "Manifest.toml" and "Project.toml" files.
For ex. "activate cosim" will activate or create the "cosim" environment.

To add a package to an existing environment, type: "add" and the name of the package.
Julia will search github for the specified package.
    If the package is being pulled from a subsidiary branch in a github repo,
    type the name of the package, then "#" and the name of the branch.
    For ex. "add PowerSimulations#master" will pull the PowerSimulations package
    from the "master" branch in the repo.

You will only need to add packages to your environment once!
The following packages are required to use SIIP's Production Cost Modeling framework:
"""
# The "using" commands will "import" packages to the active REPL
using PowerSystems
using PowerGraphics
using PowerSimulations # NOTE: Package is PowerSimulations#master
using InfrastructureSystems
# This creates a variable so "PowerSimulations" does not need to be typed out.
const PSI = PowerSimulations
using CSV
using XLSX
using Dates
using PlotlyJS
using DataFrames
using TimeSeries
using Gurobi # NOTE: This package requires a Gurobi academic license
# Go here: https://www.gurobi.com/login/ and sign up for an account with your
# university email address. Then get yourself an academic license, and follow
# the online instructions.
using Logging

"""
Step 2. Set Simulation Parameters

The following variables influence the external parameters of the simulation.
For example, ev_adpt_level controls the number of EVs charging on the system.
A value of 1 implies that 100% of vehicles driving are EVs. A value of 0.5
implies only 50% of vehicles on the road are EVs.

system_exists defines whether the system file for the simulation has already
been created. If yes, the script will locate and activate the existing system. If
no, the script will create a new system file from the given external parameters.

nsteps determines the number of steps in the simulation. This is based on
the simulation's forecast window, which for day-ahead (DA) systems is 24 hrs.
For ex. nsteps = 3 indicates a 3-day simulation from the initial start date.
    The initial start date is determined in Step 5.

sim_name, case, and method are all meant to define the current simulation by
conforming to a folder/file naming convention. These variables also help define
the parameters for newly created system files.
    dwpt - dynamic wireless power transfer
    home - home charging
    lvlr - low-voltage line reduction

    hs - high-solar case
    bpv - base-PV case

    T100 - 100% in-transit charging
    H100 - 100% at-home charging
"""
system_exists == true
ev_adpt_level = 1
method = T100
sim_name = string("dwpt-", case, "-lvlr-")
nsteps = 2
case = 'hs'
# Level of EV adoption (value from 0 to 1)
if ev_adpt_level == 1
    Adopt = "A100"
else
    Adopt = string("A", split(string(ev_adpt_level), ".")[2], "_")
    if sizeof(Adopt) == 3
        Adopt = string(split(Adopt, "_")[1], "0", "_")
    end
end
tran_set = string(Adopt, method)

"""
Step 3. Setting Directories

The complex nature of this simulator requires data flow from several different
file locations. It is crucial to understand the main purpose of each directory,
and ensure your directories have the appropriate data in each location.

home_dir: Home Directory
    For any and all additional Julia scripts.
    Typically separate from the Main Directory, esp. if linked to a git repo.
main_dir: Main Directory
    Location of called Excel files as well as all other data-based directories.
OUT_DIR: Output Directory
    Location of simulation output files.
RES_DIR: Results Directory
    Location of simulation results (graphs/plots and spreadsheets).
active_dir: Active Directory
    Location of active system files. If a system file has been created, it does
    not need to be recreated for every sim. All system files should go here.
"""
# Link to system
home_dir = "C:/Users/antho/github/tamu_ercot_dwpt"
main_dir = "C:\\Users\\antho\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling"
OUT_DIR = "D:/outputs"
RES_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots"
active_dir = "D:/active"

"""
Step 4. Activate/Create the System

If the system already exists, it can be activated by calling the "System" function
on the full file path name for the system .json file.

If the system does not exist, then a "base" system will be used to add EV demand
data to the load buses of the "base" system .json file. These "base" system files
already have the grid network, line data, existing demand data and generator data.

EV demand data is added to the system by pairing demand to each load bus in the
system. Several Excel and CSV spreadsheets are used to incorporate this data.
No changes to these spreadsheets are required. Like, definitely don't mess with
them unless you know what will happen when you do, and you've contacted A.J.
"""

if system_exists == true
    println("Locating existing system: ", sim_name, tran_set, "_sys.json")
    system = System(joinpath(active_dir, string(sim_name, tran_set, "_sys.json")))
else
    if case == "bpv"
        # BasePV System
        system = System(joinpath(active_dir, "tamu_DA_LVLr_BasePV_sys.json"))
    elseif case == "hs"
        # Reduced_LVL System
        system = System(joinpath(active_dir, "tamu_DA_sys_LVLred.json"))
    end
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
                name = string(l_name),
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
            try
                remove_time_series!(system, Deterministic, new_load, "max_active_power")
            catch
                #println("Time Series data did not previously exist. Now adding...")
            end
            add_time_series!(system, new_load, time_series)
            #println("Time series added.")
        end
    end
    to_json(system, joinpath(active_dir, string(sim_name, tran_set, "_sys.json")), force=true)
    println("New active system file has been created.")
end

"""
Step 5. Simulation Setup and Execution

Congrats, this is the fun part! In the following section, the internal
simulation parameters are defined. The sim is then built and executed.

Network Model Options:
DCPPowerModel: DC OPF power simulation
CopperPlateModel: Simple power sim with no line constraints

Thermal Models:
ThermalCompactUnitCommitment:
ThermalBasicUnitCommitment:
ThermalStandardUnitCommitment:

For all other injection device and service models, only one option currently.

Simulation Sequence is meant for mutliple models being incorporated into one
simulation, but it is still required for all sims.

Please see below for explanation of important parameters in both the model and
simulation variables.
"""
# START EXECUTION:
cd(home_dir)
#Create empty template, define Network Model, use slacks and duals
template_uc = ProblemTemplate(NetworkModel(
    DCPPowerModel,
    use_slacks = true,
    duals = [NodalBalanceActiveConstraint] #CopperPlateBalanceConstraint
))

#Injection Device Formulations
set_device_model!(template_uc, ThermalMultiStart, ThermalCompactUnitCommitment) #ThermalBasicUnitCommitment
set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
set_device_model!(template_uc, HydroDispatch, FixedOutput)
set_device_model!(template_uc, Line, StaticBranchUnbounded)
set_device_model!(template_uc, Transformer2W, StaticBranchUnbounded)
set_device_model!(template_uc, TapTransformer, StaticBranchUnbounded)
#Service Formulations
set_service_model!(template_uc, VariableReserve{ReserveUp}, RangeReserve)
set_service_model!(template_uc, VariableReserve{ReserveDown}, RangeReserve)

# This creates both a Simulation and a Decision Model for the sim
models = SimulationModels(
    decision_models = [
        DecisionModel(
            template_uc,
            system;
            name = "UC",
            # Determine optimizer parameters
            optimizer = optimizer_with_attributes(
                Gurobi.Optimizer,
                "MIPGap" => 1e-3,
            ),
            system_to_file = false,
            initialize_model = false,
            calculate_conflict = true, # used for debugging
            optimizer_solve_log_print = true, # used for debugging
            direct_mode_optimizer = true,
        )
    ]
)
# Initialize simulation sequence
# NOTE: This sequence is simplistic in that there is only one model
# Some simulations will incorporate a real-time (RT) model into the sequence
DA_sequence = SimulationSequence(
    models = models,
    #intervals = intervals,
    ini_cond_chronology = InterProblemChronology()
)
# Set final sim parameters
sim = Simulation(
    name = string(sim_name, tran_set),
    steps = nsteps, # This is based on forecast window. For DA sims, the step is
    # typically 24 hrs, thus a full year would be 365 steps.
    models = models,
    sequence = DA_sequence,
    initial_time = DateTime("2018-01-01T00:00:00"), # Data for this sim is 2018
    simulation_folder = OUT_DIR, # specify location of your simulation output files
)
# Use serialize = false only during development
build_out = build!(sim, serialize = false; console_level = Logging.Error, file_level = Logging.Info)
execute_status = execute!(sim)

if execute_status == PSI.RunStatus.FAILED
    uc = sim.models[1]
    conflict = sim.internal.container.infeasibility_conflict
    open("testOut.txt", "w") do io
    write(io, conflict) end
else
    results = SimulationResults(sim);
end

"""
Step 6. Collect and Present Simulation Results

So you've successfully executed your sim! Now what...?

The good news is, if you've successfully run your sim, you can re-run this
section as many times as you need to pull out different results.

First, check to see if the system/results are already defined. If this is run as
a single script, they will be. If this section is re-run after closing the REPL,
the system and results will be re-initialized in the current REPL.

After that, pull out the important sim variables:
renPwr: power output from all renewable generation units
thermPwr: power output from all thermal generation units
load_param: demand from all load buses
etc...

Quick calculations for total system slack (unserved load) and total system
production cost can be found below.

Also included:
    production cost data written to an Excel spreadsheet
    stacked generation plot by fuel-type
        - As of this writing, this plotting function is not functional
"""
if !@isdefined(system)
    system = System(joinpath(active_dir, string(sim_name, tran_set, "_sys.json")))
end
if !@isdefined(results)
    # WHAT TO DO IF YOU ALREADY HAVE A RESULTS FOLDER:
    sim_folder = joinpath(OUT_DIR, string(sim_name, tran_set))
    sim_folder = joinpath(sim_folder, "$(maximum(parse.(Int64,readdir(sim_folder))))")
    results = SimulationResults(sim_folder);
end

uc_results = get_decision_problem_results(results, "UC");
set_system!(uc_results, system)
timestamps = get_realized_timestamps(uc_results);
variables = read_realized_variables(uc_results);

#NOTE: ALL READ_XXXX VARIABLES ARE IN NATURAL UNITS**
# ^ Can confirm, not all variables are in natural units. Some are in p.u...
renPwr = read_realized_variable(uc_results, "ActivePowerVariable__RenewableDispatch")
thermPwr = read_realized_aux_variables(uc_results)["PowerOutput__ThermalMultiStart"]
load_param = read_realized_parameter(uc_results, "ActivePowerTimeSeriesParameter__PowerLoad")
resUp_param = read_realized_parameter(uc_results, "RequirementTimeSeriesParameter__VariableReserve__ReserveUp__REG_UP")
resDown_param = read_realized_parameter(uc_results, "RequirementTimeSeriesParameter__VariableReserve__ReserveDown__REG_DN")
resSpin_param = read_realized_parameter(uc_results, "RequirementTimeSeriesParameter__VariableReserve__ReserveUp__SPIN")
slackup_var = read_realized_variable(uc_results, "SystemBalanceSlackUp__Bus")
slackdwn_var = read_realized_variable(uc_results, "SystemBalanceSlackDown__Bus")
thermPcost = read_realized_expression(uc_results, "ProductionCostExpression__ThermalMultiStart")
# FOR HANDLING SLACK VARIABLES (UNRESERVED LOAD)
# Current number of buses
bus_num = size(slackup_var[1,:])[1]
sys_slackup = zeros(size(slackup_var[!,1])[1])
sys_slackdwn = zeros(size(slackup_var[!,1])[1])
for x in 1:size(slackup_var[!,1])[1]
    sys_slackup[x] = sum(slackup_var[x, 2:bus_num])
    sys_slackdwn[x] = sum(slackdwn_var[x, 2:bus_num])
end
slackdf = DataFrame()
insertcols!(slackdf, 1, :DateTime => slackdwn_var[!,1])
insertcols!(slackdf, 2, :SlackUp => sys_slackup)
insertcols!(slackdf, 3, :SlackDown => sys_slackdwn)

# SYSTEM PRODUCTION COST CALCULATION
sys_cost = zeros(size(thermPcost[!,1])[1])
gen_num = size(thermPcost[1,:])[1]
for x = 1:size(sys_cost)[1]
    sys_cost[x] = sum(thermPcost[x, 2:gen_num])
end
sysCost = DataFrame()
insertcols!(sysCost, 1, :DateTime => thermPcost[!,1])
insertcols!(sysCost, 2, :ProductionCost => sys_cost)

# Write Excel Output Files
date_folder = "/Mar29_22"
cd(string(RES_DIR, date_folder))
xcelname = string("_Output", sim_name, tran_set, ".xlsx")
# Simple XLSX file output with ability to overwrite
XLSX.writetable(
    string("PROD_COST", xcelname),
    sysCost,
    overwrite=true,
    sheetname="Prod_Cost",
    anchor_cell="A1"
)
# Execute Plotting
gr() # Loads the GR backend
plotlyjs() # Loads the JS backend
# STACKED GENERATION PLOT:
# Stacked Gen by Fuel Type:
fuelgen = string("FuelGenStack", sim_name, tran_set)
#plot_fuel(uc_results, stack = true; title = fuelgen, save = string(RES_DIR, date_folder), format = "svg");
#To Specify Window: initial_time = DateTime("2018-01-01T00:00:00"), count = 168
