function fun1(x, y)
    z = x + y
    bubble = println("Proof it works: ", z)
    return println("It worked")
end

#OUT_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/outputs"
OUT_DIR = "D:/outputs/CompactThermal Set 1"
RES_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots"
tran_set = "A10_T100"
case = "bpv"
sim_name = string("dwpt-", case, "-lvlr-")
sim_folder = joinpath(OUT_DIR, string(sim_name, tran_set))
sim_folder = joinpath(sim_folder, "$(maximum(parse.(Int64,readdir(sim_folder))))")
results = SimulationResults(sim_folder; ignore_status=true);
uc_results = get_decision_problem_results(results, "UC")

renPwr = read_realized_variable(uc_results, "ActivePowerVariable__RenewableDispatch");
thermPwr = read_realized_aux_variables(uc_results)["PowerOutput__ThermalMultiStart"];
sys_pwr = zeros(size(renPwr[!,1])[1]);
ren_num = size(renPwr[1,:])[1];
therm_num = size(thermPwr[1,:])[1];
for x = 1:size(sys_pwr)[1]
    sys_pwr[x] = (sum(renPwr[x, 2:ren_num]) + sum(thermPwr[x, 2:therm_num]))*100
end
sysPwr = DataFrame()
insertcols!(sysPwr, 1, :DateTime => renPwr[!, 1]);
insertcols!(sysPwr, 2, :SystemPower => sys_pwr);
date_folder = "/Mar29_22"
cd(string(RES_DIR, date_folder))
xcelname = string("_Output", sim_name, tran_set, ".xlsx")
XLSX.writetable(
    string("GEN", xcelname),
    sysPwr,
    overwrite=true,
    sheetname="Dispatch",
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
