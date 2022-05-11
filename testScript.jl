function fun1(x, y)
    z = x + y
    bubble = println("Proof it works: ", z)
    return println("It worked")
end

#OUT_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/outputs"
OUT_DIR = "D:/outputs/MultiStart_Test"
RES_DIR = "D:/results"
#RES_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots"
tran_set = "A100_T100_Comp"
case = "hs"
sim_name = string("dwpt-", case, "-lvlr-")
#sim_name = "no-dwpt-hs-A0_T100"
sim_folder = joinpath(OUT_DIR, string(sim_name, tran_set))
sim_folder = joinpath(sim_folder, "$(maximum(parse.(Int64,readdir(sim_folder))))")
results = SimulationResults(sim_folder; ignore_status=true);
uc_results = get_decision_problem_results(results, "UC");

active_dir = "D:/active"
system = System(joinpath(active_dir, string(sim_name, tran_set, "_sys.json")));
set_system!(uc_results, system)

gr()
plotlyjs()
fuelgen = string("FuelGenStack", sim_name, tran_set)
plot_fuel(uc_results, stack = true; title = fuelgen, save = string(RES_DIR), format = "svg")
renPwr = read_realized_variable(uc_results, "ActivePowerVariable__RenewableDispatch");
hydPwr = read_realized_parameter(uc_results, "ActivePowerTimeSeriesParameter__HydroDispatch");
thermPwr = read_realized_aux_variables(uc_results)["PowerOutput__ThermalMultiStart"];
load_param = parameters["ActivePowerTimeSeriesParameter__PowerLoad"];
duals = read_realized_dual(uc_results, "NodalBalanceActiveConstraint__Bus");
sys_pwr = zeros(size(renPwr[!,1])[1]);
ren_pwr = zeros(size(renPwr[!,1])[1]);
therm_pwr = zeros(size(thermPwr[!,1])[1]);
hyd_pwr = zeros(size(hydPwr[!,1])[1]);
ren_num = size(renPwr[1,:])[1];
therm_num = size(thermPwr[1,:])[1];
hyd_num = size(hydPwr[1,:])[1];
for x = 1:size(sys_pwr)[1]
    ren_pwr[x] = sum(renPwr[x, 2:ren_num])
    therm_pwr[x] = sum(thermPwr[x, 2:therm_num])
    hyd_pwr[x] = sum(hydPwr[x, 2:hyd_num])
    sys_pwr[x] = (sum(renPwr[x, 2:ren_num]) + sum(thermPwr[x, 2:therm_num]) + sum(hydPwr[x, 2:hyd_num]))
end
sysPwr = DataFrame()
insertcols!(sysPwr, 1, :DateTime => renPwr[!, 1]);
insertcols!(sysPwr, 2, :Renewables => ren_pwr);
insertcols!(sysPwr, 3, :Thermal => therm_pwr);
insertcols!(sysPwr, 4, :Hydro => hyd_pwr);
insertcols!(sysPwr, 5, :SystemPower => sys_pwr);

#date_folder = "/Mar29_22"
#cd(string(RES_DIR, date_folder))
xcelname = string("_Output_", sim_name, tran_set, ".xlsx")
XLSX.writetable(
    string("Sys_GEN", xcelname),
    sysPwr,
    overwrite=true,
    sheetname="Dispatch",
    anchor_cell="A1"
)
XLSX.writetable(
    string("DUALS", xcelname),
    duals,
    overwrite=true,
    sheetname="Duals Outputs",
    anchor_cell = "A1"
)
load_num = size(load_param[1, :])[1];
sys_demand = zeros(size(load_param[!, 1])[1]);
for x=1:size(sys_demand)[1]
   sys_demand[x] = sum(load_param[x, 2:load_num])
end
sysDemand = DataFrame()
insertcols!(sysDemand, 1, :DateTime => load_param[!, 1]);
insertcols!(sysDemand, 2, :SystemDemand => -sys_demand);
xcelname = string("_Output_", sim_name, tran_set, ".xlsx")
XLSX.writetable(
    string("SysDemand", xcelname),
    sysDemand,
    overwrite=true,
    sheetname="sys demand MWh",
    anchor_cell="A1"
)

p2 = plot_fuel(uc_results; stair = true)
PlotlyJS.savefig(p2, "RTS_bus_fuel_uc_Comp.pdf", width = 400*5, height = 400 )

must_run_gens =
    [g for g in get_components(ThermalMultiStart, system, x -> get_must_run(x))];
must_run_names = PSI.get_name.(must_run_gens)

must_run_prod = zeros(size(thermPwr[!, 1])[1],size(must_run_names)[1]);

mustRun = DataFrame()
for g in range(1, size(must_run_names)[1], step=1)
    must_run_prod[:,g] = thermPwr[!, must_run_names[g]]
    insertcols!(mustRun, g, must_run_names[g] => must_run_prod[:, g])
end
cd(RES_DIR)
xcelname = string("_Output", sim_name, tran_set, ".xlsx")
XLSX.writetable(
    string("MustRunGen_2_", xcelname),
    mustRun,
    overwrite=true,
    sheetname="MustRuns",
    anchor_cell="A1"
)

thermPcost = read_realized_expression(uc_results, "ProductionCostExpression__ThermalMultiStart");
# SYSTEM PRODUCTION COST CALCULATION
sys_cost = zeros(size(thermPcost[!,1])[1]);
gen_num = size(thermPcost[1,:])[1];
for x = 1:size(sys_cost)[1]
    sys_cost[x] = sum(thermPcost[x, 2:gen_num]);
end
sysCost = DataFrame()
insertcols!(sysCost, 1, :DateTime => thermPcost[!,1]);
insertcols!(sysCost, 2, :ProductionCost => sys_cost);
date_folder = "/Mar29_22"
cd(string(RES_DIR, date_folder))
xcelname = string("_Output", sim_name, tran_set, ".xlsx")
XLSX.writetable(
    string("PROD_COST", xcelname),
    sysCost,
    overwrite=true,
    sheetname="Prod_Cost",
    anchor_cell="A1"
)

results_em = get_emulation_problem_results(results)
on = read_realized_variable(uc_results, "OnVariable__ThermalMultiStart");
ton = read_realized_aux_variable(uc_results, "TimeDurationOn__ThermalMultiStart");
tof = read_realized_aux_variable(uc_results, "TimeDurationOff__ThermalMultiStart");
plot(
    [
        scatter(y=ton[!, "BAYTOWN_ENERGY2_CC2"], name="Time On"),
        scatter(y=tof[!, "BAYTOWN_ENERGY2_CC2"], name="Time Off"),
        scatter(y=100 .* on[!, "BAYTOWN_ENERGY2_CC2"], name="Status [0, 100]"),
    ],
    Layout(title="UC Results"),
)
ton_em = read_realized_aux_variable(results_em, "TimeDurationOff__ThermalMultiStart");
toff_em = read_realized_aux_variable(results_em, "TimeDurationOff__ThermalMultiStart");
on_em = read_realized_variable(results_em, "OnVariable__ThermalMultiStart");
plot(
           [
               scatter(y=ton_em[!, "BAYTOWN_ENERGY2_CC2"], name="Time On"),
               scatter(y=toff_em[!, "BAYTOWN_ENERGY2_CC2"], name="Time Off"),
               scatter(y=100 .* on_em[!, "BAYTOWN_ENERGY2_CC2"], name="Status [0, 100]"),
           ],
           Layout(title="Emulator Results"),
       )
