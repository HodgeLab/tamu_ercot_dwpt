# cd("C:\\Users\\A.J. Sauter\\github\\tamu_ercot_dwpt")
# include(".\\usefulMethods\\Get_Sim_Results.jl")

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

run_spot = "Desktop"

# Level of EV adoption (value from 0 to 1)
ev_adpt_level = .05
Adopt = "A100_"
Method = "T100"
tran_set = string(Adopt, Method)
sim_name = "_dwpt-hs-lvlr_"

if run_spot == "HOME"
    # Link to system
    home_dir = "C:/Users/antho/github/tamu_ercot_dwpt"
    main_dir = "C:\\Users\\antho\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling"
    DATA_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/data"
    OUT_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/outputs"
    RES_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots"
    active_dir = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/active"
elseif run_spot == "SEEC"
    home_dir = "C:/Users/A.J. Sauter/github/tamu_ercot_dwpt"
    main_dir = "C:\\Users\\A.J. Sauter\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling"
    DATA_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/data"
    OUT_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/outputs"
    RES_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots"
    active_dir = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/active"
elseif run_spot == "Desktop"
    home_dir = "A:/Users/Documents/ASPIRE_Simulators/tamu_ercot_dwpt"
    main_dir = "A:/Users/AJ/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling"
    DATA_DIR = "A:/Users/AJ/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/data"
    OUT_DIR = "A:/Users/AJ/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/outputs"
    RES_DIR = "A:/Users/AJ/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots"
    active_dir = "A:/Users/AJ/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/active"
else
    # Link to system
    home_dir = "/home/ansa1773/tamu_ercot_dwpt"
    main_dir = "/projects/ansa1773/SIIP_Modeling"
    DATA_DIR = "/projects/ansa1773/SIIP_Modeling/data"
    OUT_DIR = "/projects/ansa1773/SIIP_Modeling/outputs"
    RES_DIR = "/projects/ansa1773/SIIP_Modeling/results"
    active_dir = "/projects/ansa1773/SIIP_Modeling/active"
end


system = System(joinpath(active_dir, string("tamu_DA_LVLr_", tran_set, "_sys.json")))

# WHAT TO DO IF YOU ALREADY HAVE A RESULTS FOLDER:

sim_folder = joinpath(OUT_DIR, string("dwpt-hs-lvlr-", tran_set))
sim_folder = joinpath(sim_folder, "$(maximum(parse.(Int64,readdir(sim_folder))))")
results = SimulationResults(sim_folder);
if run_spot == "HOME"
    uc_results = get_problem_results(results,"UC");
    set_system!(uc_results, system)
    timestamps = get_realized_timestamps(uc_results);
    #timestamps = DateTime("2018-07-08T00:00:00"):Millisecond(3600000):DateTime("2018-07-08T23:00:00")
    variables = read_realized_variables(uc_results);
    parameters = read_realized_parameters(uc_results);
    expressions = read_realized_expressions(uc_results);

    #NOTE: ALL READ_XXXX VARIABLES ARE IN NATURAL UNITS
    renPwr = variables["ActivePowerVariable__RenewableDispatch"]
    thermPwr = variables["ActivePowerVariable__ThermalMultiStart"]
    load_param = parameters["ActivePowerTimeSeriesParameter__PowerLoad"]
#    resUp_param = variables["ActivePowerReserveVariable__VariableReserve__ReserveUp__REG_UP"]
#    resDown_param = variables["ActivePowerReserveVariable__VariableReserve__ReserveDown__REG_DN"]
#    resSpin_param = variables["ActivePowerReserveVariable__VariableReserve__ReserveUp__SPIN"]
    slackup_var = variables["SystemBalanceSlackUp__Bus"]
    slackdwn_var = variables["SystemBalanceSlackDown__Bus"]

    thermPcost = expressions["ProductionCostExpression__ThermalMultiStart"]
    renPcost = expressions["ProductionCostExpression__RenewableDispatch"]

    # SYSTEM PRODUCTION COST CALCULATION
    sys_cost = zeros(120)
    gen_num = size(thermPcost[1,:])[1]
    for x = 1:size(sys_cost)[1]
        sys_cost[x] = sum(thermPcost[x, 2:gen_num])
    end
    sysCost = DataFrame()
    insertcols!(sysCost, 1, :DateTime => thermPcost[!,1])
    insertcols!(sysCost, 2, :ProductionCost => sys_cost)

    # CURTAILMENT CALCULATION
#    renList = collect(get_components(RenewableDispatch, system))
#    ren_tot = zeros(8760)
#    for x = 1:size(renList)[1]
#        new_ren = get_component(RenewableDispatch, system, renList[x].name)
#        ren_data = get_time_series(Deterministic, new_ren, "max_active_power", start_time = DateTime(current_date), count = 1).data
#        forecast_window_hr = collect(ren_data[DateTime(current_date)])[h]
#        ren_tot[(sd-1)*24+h] = ren_tot[(sd-1)*24+h] + forecast_window_hr
#    end

else
    uc_results = get_decision_problem_results(results, "UC");
    set_system!(uc_results, system)
    timestamps = get_realized_timestamps(uc_results);
    variables = read_realized_variables(uc_results);

    #NOTE: ALL READ_XXXX VARIABLES ARE IN NATURAL UNITS
    renPwr = read_realized_variable(uc_results, "ActivePowerVariable__RenewableDispatch")
    thermPwr = read_realized_variable(uc_results, "ActivePowerVariable__ThermalMultiStart")
    load_param = read_realized_parameter(uc_results, "ActivePowerTimeSeriesParameter__PowerLoad")
    resUp_param = read_realized_parameter(uc_results, "RequirementTimeSeriesParameter__VariableReserve__ReserveUp__REG_UP")
    resDown_param = read_realized_parameter(uc_results, "RequirementTimeSeriesParameter__VariableReserve__ReserveDown__REG_DN")
    resSpin_param = read_realized_parameter(uc_results, "RequirementTimeSeriesParameter__VariableReserve__ReserveUp__SPIN")
    slackup_var = read_realized_variable(uc_results, "SystemBalanceSlackUp__Bus")
    slackdwn_var = read_realized_variable(uc_results, "SystemBalanceSlackDown__Bus")

    # FOR HANDLING SLACK VARIABLES (UNRESERVED LOAD)
    # Current number of buses
    bus_num = size(slackup_var[1,:])[1]
    sys_slackup = zeros(bus_num)
    sys_slackdwn = zeros(bus_num)
    for x in 1:size(slackup_var[!,1])[1]
        sys_slackup[x] = sum(slackup_var[x, 2:bus_num])
        sys_slackdwn[x] = sum(slackdwn_var[x, 2:bus_num])
    end

    slackdf = DataFrame()
    insertcols!(slackdf, 1, :DateTime => slackdwn_var[!,1])
    insertcols!(slackdf, 2, :SlackUp => sys_slackup)
    insertcols!(slackdf, 3, :SlackDown => sys_slackdwn)
end

# Execute Plotting
gr() # Loads the GR backend
plotlyjs() # Loads the JS backend
#plot_dataframe(variables[:P__RenewableDispatch], timestamps)
# TO MAKE A STACK OR BAR CHART:
#plot_dataframe(variables[:P__ThermalMultiStart], timestamps; stack = true)
#plot_dataframe(variables[:P__RenewableDispatch], timestamps; bar = true)

# STACKED GENERATION PLOT:
generation = [renPwr, thermPwr]
date_folder="/Feb22_22"
dem_name = string("PowerLoadDemand", sim_name, tran_set)
#plot_demand(load_param, slackup_var, stack = true; title = dem_name, save = string(RES_DIR, date_folder), format = "svg");
#plot_dataframe(load_param, slackup_var, stack = true; title = dem_name, save = string(RES_DIR, date_folder), format = "svg");

# Stacked Gen by Fuel Type:
fuelgen = string("FuelGenStack", sim_name, tran_set)
plot_fuel(uc_results, stack = true; title = fuelgen, save = string(RES_DIR, date_folder), format = "svg"); #To Specify Window: initial_time = DateTime("2018-01-01T00:00:00"), count = 168
#plot_dataframe(renPwr, thermPwr, stack = true; title = fuelgen, save = string(RES_DIR, date_folder), format = "svg");

# Reserves Plot
resgen = string("Reserves", sim_name, tran_set)
#plot_dataframe(resUp_param, resDown_param; title = resgen, save = string(RES_DIR, date_folder), format = "svg");

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
#XLSX.writetable(
#    string("TH_GEN", xcelname),
#    thermPwr,
#    overwrite=true,
#    sheetname="TH_Dispatch",
#    anchor_cell="A1"
#)

XLSX.writetable(
    string("PROD_COST", xcelname),
    sysCost,
    overwrite=true,
    sheetname="Prod_Cost",
    anchor_cell="A1"
)

#XLSX.writetable(
#    string("CURTAILMENT", xcelname),
#    renCurtail,
#    overwrite = true,
#    sheetname="Ren_Curtailment",
#    anchor_cell="A1"
#)

#XLSX.writetable(
#    string("DEMAND", xcelname),
#    load_param,
#    overwrite=true,
#    sheetname="Demand",
#    anchor_cell = "A1"
#)
#XLSX.writetable(
#    string("RESERVES", xcelname),
#    resUp_param,
#    overwrite=true,
#    sheetname="ResUP",
#    anchor_cell = "A1"
#)
#XLSX.writetable(
#    string("RESERVES", xcelname),
#    resDown_param,
#    overwrite=true,
#    sheetname="ResDWN",
#    anchor_cell = "A1"
#)
#XLSX.writetable(
#    string("RESERVES", xcelname),
#    resSpin_param,
#    overwrite=true,
#    sheetname="ResSPIN",
#    anchor_cell = "A1"
#)
