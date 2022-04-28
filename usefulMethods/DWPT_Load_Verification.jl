using PowerSystems
#using PowerGraphics
using PowerSimulations
using InfrastructureSystems
const PSI = PowerSimulations
const PSY = PowerSystems
using CSV
using XLSX
using Dates
using PlotlyJS
#using PyPlot
#using Plots
using DataFrames
using TimeSeries
using Gurobi
using Logging
using JSON
using JuMP

home_dir = "C:/Users/antho/github/tamu_ercot_dwpt"
main_dir = "C:\\Users\\antho\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling"
DATA_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/data"
OUT_DIR = "D:/outputs"
RES_DIR = "D:/results"
active_dir = "D:/active"

case = "hs"
Adopt = "A100_"
Method = "T100"
ev_adpt_level = 1;
tran_set = string(Adopt, Method)
sim_name = string("dwpt-", case, "-lvlr-")
# Link to system
system = System(joinpath(active_dir, "tamu_DA_sys_LVLred.json"));
# Set dates for sim
dates = DateTime(2018, 1, 1, 0):Hour(1):DateTime(2019, 1, 2, 23);
# Set forecast resolution
resolution = Dates.Hour(1);

# INITIALIZE LOADS:
# Get Bus Names
cd(main_dir)
bus_details = CSV.read("bus_load_coords.csv", DataFrame);
bus_names = bus_details[:,1];
load_names = bus_details[:,2];
dim_loads = size(load_names);
num_loads = dim_loads[1];

df = DataFrame(XLSX.readtable(string("ABM_Energy_Output_A100_T100_v5.xlsx"), "load_demand")...);
# Read from Excel File
for x = 1: num_loads
    # Extract power demand column
    load_data = df[!, x+1]*ev_adpt_level;
    peak_load = maximum(load_data);
    # Convert to TimeArray
    load_array = TimeArray(dates, load_data);
    # Create forecast dictionary
    forecast_data = Dict()
    for i = 1:365
        strt = (i-1)*24+1
        finish = i*24+12
        #peak_load = maximum(load_data[strt:finish])
        forecast_data[dates[strt]] = load_data[strt:finish]
    end
    # Create deterministic time series data
    time_series = Deterministic("max_active_power",forecast_data, resolution);
    l_name = string(load_names[x], "_DWPT");
    new_load = get_component(PowerLoad, system, l_name)
    try
        remove_component!(system, new_load)
    end
    # Create new load
    new_load = PowerLoad(
        name = string(l_name), # ADD '_DWPT' to each bus name
        available = true,
        bus = get_component(Bus, system, bus_names[x]), # USE BUS_LOAD_COORDS.CSV COLUMN 1
        model = "ConstantPower",
        active_power = 1,
        reactive_power = 1,
        base_power = 100.0,
        max_active_power = 1,
        max_reactive_power = 1,
        services = [],
    )
    # Add component to system
    add_component!(system, new_load)
    # Add deterministic forecast to the system
    add_time_series!(system, new_load, time_series)
end
to_json(system, joinpath(active_dir, string(sim_name, tran_set, "TEST1_sys.json")), force=true)
println("New active system file has been created.")

global total_load = zeros(36);
for l in get_components(PowerLoad, system)
    global total_load += get_time_series_values(Deterministic, l, "max_active_power", start_time = DateTime(2018, 1, 1, 0))*100#*get_max_active_power(l)
end

resLoad = DataFrame()
insertcols!(resLoad, 1, :DateTime => dates[1:36]);
insertcols!(resLoad, 2, :ResultingLoad => total_load);
println(resLoad)

#XLSX.writetable(
#    "tamu_resLoad_woop.xlsx",
#    resLoad,
#    overwrite=true,
#    sheetname="sys demand MWh",
#    anchor_cell="A1"
#)
