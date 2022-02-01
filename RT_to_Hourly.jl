# cd("C:\\Users\\A.J. Sauter\\github\\tamu_ercot_dwpt\\Satellite_Execution")
# include("RT_to_Hourly.jl")

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
using Statistics

using Cbc #solver

# Link to system
DATA_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/data"
sys_RT = System(joinpath(DATA_DIR, "texas_data/RT_sys.json"))

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
dates = DateTime(2018, 1, 1, 0):Hour(1):DateTime(2018, 12, 31, 23)
# Set forecast resolution
resolution = Dates.Hour(1)

load_tot = Vector{DataFrame}()
for x = 1: num_loads
    # Check for pre-existing DWPT PowerLoad components
    l_name = string(load_names[x])
    new_load = get_component(PowerLoad, sys_RT, l_name)
    load_hr = DataFrame(load_col = Float64[])
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
            for h = 0:23
                if sd < 10 && h < 10
                    current_date = string("2018-", m, "-0", sd, "T0", h, ":00:00")
                elseif sd >= 10 && h < 10
                    current_date = string("2018-", m, "-", sd, "T0", h, ":00:00")
                elseif sd < 10 && h >= 10
                    current_date = string("2018-", m, "-0", sd, "T", h, ":00:00")
                else #sd >=10 && h >= 10
                    current_date = string("2018-", m, "-", sd, "T", h, ":00:00")
                end
                load_data = get_time_series(Deterministic, new_load, "max_active_power", start_time = DateTime(current_date), count = 1).data
                forecast_window = collect(load_data[DateTime(current_date)])
                # So, THIS will be the one where we just take the datapoint. No averaging done to downscale
                push!(load_hr, [forecast_window[1]])
                # THIS is Averaging to accomplish downscaling
                # avg_val = mean(forecast_window[1:12])
                # push!(load_hr, [avg_val])
            end
        end
    end
    append!(load_tot, [load_hr])
    remove_time_series!(sys_RT, Deterministic, new_load, "max_active_power")
end

cd("C:\\Users\\A.J. Sauter\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling\\data\\texas_data\\RT_Sys_Breakdown")
ts_dets = CSV.read("RT_timeseries.csv", DataFrame)

area_tot = Vector{DataFrame}()
for x = 1:8
    a_name = string(ts_dets[1, x])
    new_area = get_component(Area, sys_RT, a_name)
    area_hr = DataFrame(area_col = Float64[])

    if isnothing(new_area)
        println("Area not found.")
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
            for h = 0:23
                if sd < 10 && h < 10
                    current_date = string("2018-", m, "-0", sd, "T0", h, ":00:00")
                elseif sd >= 10 && h < 10
                    current_date = string("2018-", m, "-", sd, "T0", h, ":00:00")
                elseif sd < 10 && h >= 10
                    current_date = string("2018-", m, "-0", sd, "T", h, ":00:00")
                else #sd >=10 && h >= 10
                    current_date = string("2018-", m, "-", sd, "T", h, ":00:00")
                end
                area_data = get_time_series(Deterministic, new_area, "max_active_power", start_time = DateTime(current_date), count = 1).data
                forecast_window = collect(area_data[DateTime(current_date)])
                # So, THIS will be the one where we just take the datapoint. No averaging done to downscale
                push!(area_hr, [forecast_window[1]])
                # THIS is Averaging to accomplish downscaling
                # avg_val = mean(forecast_window[1:12])
                # push!(load_hr, [avg_val])
            end
        end
    end
    append!(area_tot, [area_hr])
    remove_time_series!(sys_RT, Deterministic, new_area, "max_active_power")
end

hydro_tot = Vector{DataFrame}()
for x = 1:33
    h_name = string(ts_dets[2, x])
    new_hydro = get_component(HydroDispatch, sys_RT, h_name)
    hydro_hr = DataFrame(hydro_col = Float64[])

    if isnothing(new_hydro)
        println("Load not found.")
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
            for h = 0:23
                if sd < 10 && h < 10
                    current_date = string("2018-", m, "-0", sd, "T0", h, ":00:00")
                elseif sd >= 10 && h < 10
                    current_date = string("2018-", m, "-", sd, "T0", h, ":00:00")
                elseif sd < 10 && h >= 10
                    current_date = string("2018-", m, "-0", sd, "T", h, ":00:00")
                else #sd >=10 && h >= 10
                    current_date = string("2018-", m, "-", sd, "T", h, ":00:00")
                end
                hydro_data = get_time_series(Deterministic, new_hydro, "max_active_power", start_time = DateTime(current_date), count = 1).data
                forecast_window = collect(hydro_data[DateTime(current_date)])
                # So, THIS will be the one where we just take the datapoint. No averaging done to downscale
                push!(hydro_hr, [forecast_window[1]])
                # THIS is Averaging to accomplish downscaling
                # avg_val = mean(forecast_window[1:12])
                # push!(load_hr, [avg_val])
            end
        end
    end
    append!(hydro_tot, [hydro_hr])
    remove_time_series!(sys_RT, Deterministic, new_hydro, "max_active_power")
end

ren_tot = Vector{DataFrame}()
for x = 1:219
    r_name = string(ts_dets[3, x])
    new_ren = get_component(RenewableDispatch, sys_RT, r_name)
    ren_hr = DataFrame(ren_col = Float64[])

    if isnothing(new_ren)
        println("Load not found.")
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
            for h = 0:23
                if sd < 10 && h < 10
                    current_date = string("2018-", m, "-0", sd, "T0", h, ":00:00")
                elseif sd >= 10 && h < 10
                    current_date = string("2018-", m, "-", sd, "T0", h, ":00:00")
                elseif sd < 10 && h >= 10
                    current_date = string("2018-", m, "-0", sd, "T", h, ":00:00")
                else #sd >=10 && h >= 10
                    current_date = string("2018-", m, "-", sd, "T", h, ":00:00")
                end
                ren_data = get_time_series(Deterministic, new_ren, "max_active_power", start_time = DateTime(current_date), count = 1).data
                forecast_window = collect(ren_data[DateTime(current_date)])
                # So, THIS will be the one where we just take the datapoint. No averaging done to downscale
                push!(ren_hr, [forecast_window[1]])
                # THIS is Averaging to accomplish downscaling
                # avg_val = mean(forecast_window[1:12])
                # push!(load_hr, [avg_val])
            end
        end
    end
    append!(ren_tot, [ren_hr])
    remove_time_series!(sys_RT, Deterministic, new_ren, "max_active_power")
end

nonspin_tot = Vector{DataFrame}()
for x = 1:1
    new_nonspin = get_component(VariableReserveNonSpinning, sys_RT, "NONSPIN")
    nonspin_hr = DataFrame(nonspin_col = Float64[])

    if isnothing(new_nonspin)
        println("Load not found.")
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
            for h = 0:23
                if sd < 10 && h < 10
                    current_date = string("2018-", m, "-0", sd, "T0", h, ":00:00")
                elseif sd >= 10 && h < 10
                    current_date = string("2018-", m, "-", sd, "T0", h, ":00:00")
                elseif sd < 10 && h >= 10
                    current_date = string("2018-", m, "-0", sd, "T", h, ":00:00")
                else #sd >=10 && h >= 10
                    current_date = string("2018-", m, "-", sd, "T", h, ":00:00")
                end
                nonspin_data = get_time_series(Deterministic, new_nonspin, "max_active_power", start_time = DateTime(current_date), count = 1).data
                forecast_window = collect(nonspin_data[DateTime(current_date)])
                # So, THIS will be the one where we just take the datapoint. No averaging done to downscale
                push!(nonspin_hr, [forecast_window[1]])
                # THIS is Averaging to accomplish downscaling
                # avg_val = mean(forecast_window[1:12])
                # push!(load_hr, [avg_val])
            end
        end
    end
    append!(nonspin_tot, [nonspin_hr])
    remove_time_series!(sys_RT, Deterministic, new_nonspin, "max_active_power")
end

resup_tot = Vector{DataFrame}()
for x = 1:2
    resup_name = string(ts_dets[5,x])
    new_resup = get_component(VariableReserve{ReserveUp}, sys_RT, resup_name)
    resup_hr = DataFrame(resup_col = Float64[])

    if isnothing(new_resup)
        println("Load not found.")
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
            for h = 0:23
                if sd < 10 && h < 10
                    current_date = string("2018-", m, "-0", sd, "T0", h, ":00:00")
                elseif sd >= 10 && h < 10
                    current_date = string("2018-", m, "-", sd, "T0", h, ":00:00")
                elseif sd < 10 && h >= 10
                    current_date = string("2018-", m, "-0", sd, "T", h, ":00:00")
                else #sd >=10 && h >= 10
                    current_date = string("2018-", m, "-", sd, "T", h, ":00:00")
                end
                resup_data = get_time_series(Deterministic, new_resup, "max_active_power", start_time = DateTime(current_date), count = 1).data
                forecast_window = collect(resup_data[DateTime(current_date)])
                # So, THIS will be the one where we just take the datapoint. No averaging done to downscale
                push!(resup_hr, [forecast_window[1]])
                # THIS is Averaging to accomplish downscaling
                # avg_val = mean(forecast_window[1:12])
                # push!(load_hr, [avg_val])
            end
        end
    end
    append!(resup_tot, [resup_hr])
    remove_time_series!(sys_RT, Deterministic, new_resup, "max_active_power")
end

resdn_tot = Vector{DataFrame}()
for x = 1:1
    new_resdn = get_component(VariableReserve{ReserveDown}, sys_RT, "RES_DN")
    resdn_hr = DataFrame(resdn_col = Float64[])

    if isnothing(new_resdn)
        println("Load not found.")
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
            for h = 0:23
                if sd < 10 && h < 10
                    current_date = string("2018-", m, "-0", sd, "T0", h, ":00:00")
                elseif sd >= 10 && h < 10
                    current_date = string("2018-", m, "-", sd, "T0", h, ":00:00")
                elseif sd < 10 && h >= 10
                    current_date = string("2018-", m, "-0", sd, "T", h, ":00:00")
                else #sd >=10 && h >= 10
                    current_date = string("2018-", m, "-", sd, "T", h, ":00:00")
                end
                resdn_data = get_time_series(Deterministic, new_resdn, "max_active_power", start_time = DateTime(current_date), count = 1).data
                forecast_window = collect(resdn_data[DateTime(current_date)])
                # So, THIS will be the one where we just take the datapoint. No averaging done to downscale
                push!(resdn_hr, [forecast_window[1]])
                # THIS is Averaging to accomplish downscaling
                # avg_val = mean(forecast_window[1:12])
                # push!(load_hr, [avg_val])
            end
        end
    end
    append!(resdn_tot, [resdn_hr])
    remove_time_series!(sys_RT, Deterministic, new_resdn, "max_active_power")
end


for x = 1: num_loads
# SET NEW TIMESERIES DATA
    # Convert to TimeArray
    load_array = TimeArray(dates, load_tot[x].load_col)
    # Create forecast dictionary
    forecast_data = Dict()
    for i = 1:365
        strt = (i-1)*24+1
        finish = i*24
        forecast_data[dates[strt]] = load_tot[x].load_col[strt:finish]
    end
    # Create deterministic time series data
    time_series = Deterministic("max_active_power",forecast_data, resolution)
    # Remove 5-minute time series data from the system
    remove_time_series!(sys_RT, Deterministic, new_load, "max_active_power")
    # Add deterministic forecast to the system
    add_time_series!(sys_RT, new_load, time_series)
end
#to_json(sys_RT, joinpath(main_dir, "active/tamu_RT_sys.json"), force=true)
#println("New active system file has been created.")

# PULL DATA FROM LOAD_TOT (first load, first value)
# load_tot[1].load_col[1]

# PULLS FULL SET OF TIME SERIES VALUES
# Count and start_time only pull a subset
#load_ta_full = get_time_series(
#    Deterministic,
#    new_load,
#    "max_active_power"
#)

# Get Data from subset of time series values
#load_ta_data = get_time_series(
#    Deterministic,
#    new_load,
#    "max_active_power",
#    start_time = DateTime("2018-01-01T00:00:00"),
#    count = 1,
#).data

# Pull out vector of values from Sorted Dictionary by DateTime
# apple = collect(load_ta_data[DateTime("2018-01-01T00:00:00")])
