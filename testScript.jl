function fun1(x, y)
    z = x + y
    bubble = println("Proof it works: ", z)
    return println("It worked")
end

#OUT_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/outputs"
OUT_DIR = "D:/outputs"
RES_DIR = "D:/results"

ev_adpt_level = 1
method = "H100"
case = "hs"
#RES_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots"
if ev_adpt_level == 1
    Adopt = "A100_"
elseif ev_adpt_level == 0
    Adopt = "A0_"
else
    Adopt = string("A", split(string(ev_adpt_level), ".")[2], "_")
    if sizeof(Adopt) == 3
        Adopt = string(split(Adopt, "_")[1], "0", "_")
    end
end
tran_set = string(Adopt, method)
sim_name = string("dwpt-", case, "-lvlr-")

#sim_name = "no-dwpt-hs-A0_T100"
sim_folder = joinpath(OUT_DIR, string(sim_name, tran_set))
sim_folder = joinpath(sim_folder, "$(maximum(parse.(Int64,readdir(sim_folder))))")
results = SimulationResults(sim_folder; ignore_status=true);
uc_results = get_decision_problem_results(results, "UC");

active_dir = "D:/active"
system = System(joinpath(active_dir, string(sim_name, tran_set, "_sys.json")));
set_system!(uc_results, system);
p2 = plot_fuel(uc_results);
PlotlyJS.savefig(p2, string("FuelPlot_", sim_name, tran_set, ".pdf"), width = 400*5, height = 400 )

p3 = plot_fuel(uc_results; horizon = 24, start_time = DateTime("2018-04-14T00:00:00"))
PlotlyJS.savefig(p3, string("FuelPlot_", sim_name, tran_set, "_PeakCurtail.pdf"))

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

# Can do the same thing with OnVariable
thermPcost = read_realized_expression(uc_results, "ProductionCostExpression__ThermalMultiStart");
cost_sums_Comp = combine(thermPcost[!, 2:354], names(thermPcost[!, 2:354]) .=> sum)
cost_diff = cost_sums_MS .- cost_sums_Comp
xcelname = string("_Output_", sim_name, tran_set, ".xlsx")
XLSX.writetable(
    string("Cost_per_Unit_Compare", xcelname),
    cost_diff,
    overwrite=true,
    sheetname="Therm_Cost",
    anchor_cell="A1"
)

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

thermPwr = read_realized_aux_variables(uc_results)["PowerOutput__ThermalMultiStart"];
# HOW TO SPLIT UP THERMAL GEN BY TYPE
ngCCList = []
ngCC_pwr = 0
ngCTList = []
ngCT_pwr = 0
ngSTList = []
ngST_pwr = 0
ng_List = []
ng_pwr = 0
coList = []
co_pwr = 0
nucList = []
nuc_pwr = 0
thermList = collect(get_components(ThermalMultiStart, system));
for x = 1:size(thermList)[1]
    if "NATURAL_GAS" == string(thermList[x].fuel)
        if "CC" == string(thermList[x].prime_mover)
            append!(ngCCList, [thermList[x].name])
            ngCC_pwr = ngCC_pwr + sum(thermPwr[!,thermList[x].name])
        elseif "CT" == string(thermList[x].prime_mover)
            append!(ngCTList, [thermList[x].name])
            ngCT_pwr = ngCT_pwr + sum(thermPwr[!, thermList[x].name])
        elseif "ST" == string(thermList[x].prime_mover)
            append!(ngSTList, [thermList[x].name])
            ngST_pwr = ngST_pwr + sum(thermPwr[!, thermList[x].name])
        else
            append!(ng_List, [thermList[x].name])
            ng_pwr = ng_pwr + sum(thermPwr[!, thermList[x].name])
        end
    elseif "COAL" == string(thermList[x].fuel)
        append!(coList, [thermList[x].name])
        co_pwr = co_pwr + sum(thermPwr[!, thermList[x].name])
    elseif "NUCLEAR" == string(thermList[x].fuel)
        append!(nucList, [thermList[x].name])
        nuc_pwr = nuc_pwr + sum(thermPwr[!, thermList[x].name])
    end
end
ngCC = DataFrame();
ngCT = DataFrame();
ngST = DataFrame();
insertcols!(ngCC, 1, :DateTime => thermPwr[!, 1]);
insertcols!(ngCT, 1, :DateTime => thermPwr[!, 1]);
insertcols!(ngST, 1, :DateTime => thermPwr[!, 1]);
for x=1:size(ngCCList)[1]
    insertcols!(ngCC, ngCCList[x] => thermPwr[!, ngCCList[x]]);
end
for x=1:size(ngCTList)[1]
    insertcols!(ngCT, ngCTList[x] => thermPwr[!, ngCTList[x]]);
end
for x=1:size(ngSTList)[1]
    insertcols!(ngST, ngSTList[x] => thermPwr[!, ngSTList[x]]);
end
ngCC_hourly = []
ngCT_hourly = []
ngST_hourly = []
for x=1:8760
    append!(ngCC_hourly, sum(ngCC[x, 2:size(ngCCList)[1]]))
    append!(ngCT_hourly, sum(ngCT[x, 2:size(ngCTList)[1]]))
    append!(ngST_hourly, sum(ngST[x, 2:size(ngSTList)[1]]))
end
thermPwrByType = DataFrame()
insertcols!(thermPwrByType, 1, :DateTime => thermPwr[!, 1]);
insertcols!(thermPwrByType, 2, :ngCC => ngCC_hourly);
insertcols!(thermPwrByType, 3, :ngCT => ngCT_hourly);
insertcols!(thermPwrByType, 4, :ngST => ngST_hourly);
cd(string(RES_DIR))
xcelname = string("_Output_", sim_name, tran_set, ".xlsx")
# Simple XLSX file output with ability to overwrite
XLSX.writetable(
    string("Therm_By_Type_", xcelname),
    thermPwrByType,
    overwrite=true,
    sheetname="Thermal",
    anchor_cell="A1"
)

# Total Hydropowr
hydPwr = read_realized_parameter(uc_results, "ActivePowerTimeSeriesParameter__HydroDispatch");
hydPwr2 = hydPwr[!, 2:34]
tot_hydPwr = sum(sum(eachcol(hydPwr2)))

renPwr = read_realized_variable(uc_results, "ActivePowerVariable__RenewableDispatch");
# Split between Solar and Wind
windList = []
wind_pwr = 0
pvList = []
pv_pwr = 0
renList = collect(get_components(RenewableDispatch, system));
for x = 1:size(renList)[1]
    if renList[x].available == true
        if "WT" == string(renList[x].prime_mover)
            append!(windList, [renList[x].name])
            wind_pwr = wind_pwr + sum(renPwr[!,renList[x].name])
        elseif "PVe" == string(renList[x].prime_mover)
            append!(pvList, [renList[x].name])
            pv_pwr = pv_pwr + sum(renPwr[!, renList[x].name])
        end
    end
end

AnnGen = DataFrame()
insertcols!(AnnGen, 1, :Nuclear => nuc_pwr);
insertcols!(AnnGen, 2, :Coal => co_pwr);
insertcols!(AnnGen, 3, :NG_Other => ng_pwr);
insertcols!(AnnGen, 4, :NG_ST => ngST_pwr);
insertcols!(AnnGen, 5, :NG_CT => ngCT_pwr);
insertcols!(AnnGen, 6, :NG-CC => ngCC_pwr);
insertcols!(AnnGen, 7, :Hydro => tot_hydPwr);
insertcols!(AnnGen, 8, :Wind => wind_pwr);
insertcols!(AnnGen, 9, :PV => pv_pwr);

XLSX.writetable(
    string("Ann_Generation_", xcelname),
    AnnGen,
    overwrite=true,
    sheetname="Thermal",
    anchor_cell="A1"
)

println(string("Nuclear: ", nuc_pwr))
println(string("Coal: ", co_pwr))
println(string("NG - Other: ", ng_pwr))
println(string("NG ST: ", ngST_pwr))
println(string("NG CT: ", ngCT_pwr))
println(string("NG CC: ", ngCC_pwr))
println(string("Hydro: ", tot_hydPwr))
println(string("Wind: ", wind_pwr))
println(string("PV: ", pv_pwr))

# CHECKING BASE PV CAPS
renList = collect(get_components(RenewableDispatch, system));
BaseCap = 0
origPV = ["Piano Solar", "Error Solar", "Bonus Solar", "Photo Solar", "Scene Solar",
            "Drama Solar", "Tooth Solar", "Hover Solar", "Straw Solar", "River Solar",
            "Spray 2 Solar", "Smoke Solar", "Rebel Solar", "Toast Solar", "Troop Solar",
            "Mercy Solar", "Storm Solar", "Arena Solar", "Feign Solar", "Glass Solar",
            "Blast Solar", "Giant Solar"]
pvList = []
for x = 1:size(renList)[1]
    if "PVe" == string(renList[x].prime_mover)
        append!(pvList, [renList[x].name])
    end
end
pvCap = []
for x = 1:size(renList)[1]
    if renList[x].name in pvList
        append!(pvCap, [renList[x].base_power])
    end
end
for x = 1:size(pvList)[1]
    if occursin("Barilla", pvList[x])
        print("yay")
        print(pvList[x])
    end
end
pvStuff = cat(pvList, pvCap; dims=2)
pvSubset = []
subsetCap = 0
for x = 1:size(pvStuff)[1]
    if pvStuff[x, :][1] in origPV
        append!(pvSubset, [pvStuff[x, :]])
        subsetCap = subsetCap + pvStuff[x, :][2]
    end
end
