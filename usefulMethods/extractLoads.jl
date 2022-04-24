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
using Statistics

home_dir = "C:/Users/antho/github/tamu_ercot_dwpt/usefulMethods"

function extractLoads()
    cd("C:\\Users\\antho\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling")
    bus_details = CSV.read("bus_load_coords.csv", DataFrame)
    bus_names = bus_details[:,1]
    load_names = bus_details[:,2]

    cd(string("C:\\Users\\antho\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Texas Traffic Data\\STAR II Database\\Load_Volumes_post"))
    load_list = readdir()
    dim_loads = size(load_list)
    num_loads = dim_loads[1]


    load_tot = DataFrame()
    for x = 1: num_loads
        # Check for pre-existing DWPT PowerLoad components
        l_name = string(load_names[x])
        new_load = get_component(PowerLoad, system, l_name)
        load_hr = []
        if isnothing(new_load)
            println("Load not found: ")
            println(new_load)
        else
            for d = 1:365
                if d <= 31
                    m = "01"
                    sd = d
                elseif d <= 59
                    m = "02"
                    sd = d-31
                elseif d <= 90
                    m = "03"
                    sd = d-59
                elseif d <= 120
                    m = "04"
                    sd = d-90
                elseif d <= 151
                    m = "05"
                    sd = d-120
                elseif d <= 181
                    m = "06"
                    sd = d-151
                elseif d <= 212
                    m = "07"
                    sd = d-181
                elseif d <= 243
                    m = "08"
                    sd = d-212
                elseif d <= 273
                    m = "09"
                    sd = d-243
                elseif d <= 304
                    m = "10"
                    sd = d - 273
                elseif d <= 334
                    m = "11"
                    sd = d-304
                else
                    m = "12"
                    sd = d-334
                end
                if sd < 10
                    current_date = string("2018-", m, "-0", sd, "T00:00:00")
                else
                    current_date = string("2018-", m, "-", sd, "T00:00:00")
                end
                load_data = get_time_series_values(Deterministic, new_load, "max_active_power", start_time = DateTime(current_date), len = 24)
                load_data .*= get_max_active_power(new_load)
                append!(load_hr, load_data)
            end
        end
        insertcols!(load_tot, x, load_names[x] => load_hr[:, 1])
    end

cd("C:\\Users\\antho\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Texas Traffic Data\\NHTS_Database\\ABM_Outputs\\Ext_Tracts")
sys_demand = zeros(size(load_tot[!, 1])[1]);
for x=1:size(sys_demand)[1]
   sys_demand[x] = sum(load_data[x, 1:1125])
end
sysDemand = DataFrame()
insertcols!(sysDemand, 1, :DateTime => load_data[!, 1]);
insertcols!(sysDemand, 2, :SystemDemand => -sys_demand);

#XLSX.writetable(
#    "tamu_Demand.xlsx",
#    load_tot,
#    overwrite=true,
#    sheetname="loads pu",
#    anchor_cell="A1"
#)

XLSX.writetable(
    "tamu_Demand.xlsx",
    sysDemand,
    overwrite=true,
    sheetname="sys demand MWh",
    anchor_cell="A1"
)
return load_tot
end
