# cd("C:\\Users\\A.J. Sauter\\github\\tamu_ercot_dwpt\\Satellite_Execution")
# include("DWPT_Load_Verification.jl")

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

Adopt = "A100_"
Method = "T100"
tran_set = string(Adopt, Method)

# Link to system
DATA_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/data"
system = System(joinpath(DATA_DIR, "texas_data/DA_sys.json"))

# INITIALIZE LOADS:
# Get Bus Names
main_dir = "C:\\Users\\A.J. Sauter\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling"
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
    load_data = df[!, x]
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
