using PowerSystems
#using PowerGraphics
using PowerSimulations
using InfrastructureSystems
const PSI = PowerSimulations
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

function tamuSimEx(run_spot, ex_only, ev_adpt_level, method, sim_name, nsteps, case)
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
    # Link to system
    if run_spot == "HOME"
        home_dir = "C:/Users/antho/github/tamu_ercot_dwpt"
        main_dir = "C:\\Users\\antho\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling"
        DATA_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/data"
        OUT_DIR = "D:/outputs"
        RES_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots"
        active_dir = "D:/active"
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
    elseif run_spot == "Alpine"
        home_dir = "/home/ansa1773/tamu_ercot_dwpt"
        main_dir = "/scratch/alpine/ansa1773/SIIP_Modeling"
        DATA_DIR = "/projects/ansa1773/SIIP_Modeling/data"
        OUT_DIR = "/scratch/alpine/ansa1773/SIIP_Modeling/outputs"
        RES_DIR = "/scratch/alpine/ansa1773/SIIP_Modeling/results"
        active_dir = "/scratch/alpine/ansa1773/SIIP_Modeling/active"
    elseif run_spot == "Summit"
        home_dir = "/home/ansa1773/tamu_ercot_dwpt"
        main_dir = "/scratch/summit/ansa1773/SIIP_Modeling"
        DATA_DIR = "/projects/ansa1773/SIIP_Modeling/data"
        OUT_DIR = "/scratch/summit/ansa1773/SIIP_Modeling/outputs"
        RES_DIR = "/scratch/summit/ansa1773/SIIP_Modeling/results"
        active_dir = "/scratch/summit/ansa1773/SIIP_Modeling/active"
    end
    #Alterante Systems
    #system = System(joinpath(main_dir, "active/tamu_DA_sys.json"))
    #system = System(joinpath(DATA_DIR, "texas_data/DA_sys.json"))

    if ex_only == true
        println("Ex Only")
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
        to_json(system, joinpath(active_dir, string(sim_name, tran_set, "_sys.json")), force=true)
        println("New active system file has been created.")
    end

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

    UC = DecisionModel(
            StandardCommitmentCC,
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
            initial_time = DateTime("2018-01-01T00:00:00"),
        )
    models = SimulationModels(UC)
    UC.ext["cc_restrictions"] = JSON.parsefile(joinpath(active_dir, "cc_restrictions.json"));

    DA_sequence = SimulationSequence(
        models = models,
        #intervals = intervals,
        ini_cond_chronology = InterProblemChronology()
    )

    sim = Simulation(
        name = string(sim_name, tran_set),
        steps = nsteps,
        models = models,
        sequence = DA_sequence,
        initial_time = DateTime("2018-01-01T00:00:00"),
        simulation_folder = OUT_DIR,
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
        #uc_results = get_decision_problem_results(results, "UC"); # UC stage result metadata
        #set_system!(uc_results, system)
    end
return execute_status
end

function tamuSimRes(run_spot, ev_adpt_level, method, sim_name)
    # Level of EV adoption (value from 0 to 1)
    Adopt = string("A", split(string(ev_adpt_level), ".")[2], "_")
    tran_set = string(Adopt, method)
    if run_spot == "HOME"
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
    elseif run_spot == "Alpine"
        home_dir = "/home/ansa1773/tamu_ercot_dwpt"
        main_dir = "/scratch/alpine/ansa1773/SIIP_Modeling"
        DATA_DIR = "/projects/ansa1773/SIIP_Modeling/data"
        OUT_DIR = "/scratch/alpine/ansa1773/SIIP_Modeling/outputs"
        RES_DIR = "/scratch/alpine/ansa1773/SIIP_Modeling/results"
        active_dir = "/scratch/alpine/ansa1773/SIIP_Modeling/active"
    elseif run_spot == "Summit"
        home_dir = "/home/ansa1773/tamu_ercot_dwpt"
        main_dir = "/scratch/alpine/ansa1773/SIIP_Modeling"
        DATA_DIR = "/projects/ansa1773/SIIP_Modeling/data"
        OUT_DIR = "/scratch/summit/ansa1773/SIIP_Modeling/outputs"
        RES_DIR = "/scratch/summit/ansa1773/SIIP_Modeling/results"
        active_dir = "/scratch/summit/ansa1773/SIIP_Modeling/active"
    end

    if !@isdefined(system)
        system = System(joinpath(active_dir, string(sim_name, tran_set, "_sys.json")))
    end
    if !@isdefined(results)
        # WHAT TO DO IF YOU ALREADY HAVE A RESULTS FOLDER:
        sim_folder = joinpath(OUT_DIR, string(sim_name, tran_set))
        sim_folder = joinpath(sim_folder, "$(maximum(parse.(Int64,readdir(sim_folder))))")
        results = SimulationResults(sim_folder);
    end
    if run_spot == "HOME" || run_spot == "Summit"
        uc_results = get_problem_results(results,"UC");
        set_system!(uc_results, system)
        timestamps = get_realized_timestamps(uc_results);
        #timestamps = DateTime("2018-07-08T00:00:00"):Millisecond(3600000):DateTime("2018-07-08T23:00:00")
        variables = read_realized_variables(uc_results);
        parameters = read_realized_parameters(uc_results);
        expressions = read_realized_expressions(uc_results);

        #NOTE: ALL READ_XXXX VARIABLES ARE IN NATURAL UNITS
        renPwr = variables["ActivePowerVariable__RenewableDispatch"]
        #thermPwr = variables["PowerAboveMinimumVariable__ThermalMultiStart"]
        thermPwr = read_realized_aux_variables(uc_results)["PowerOutput__ThermalMultiStart"]
        load_param = parameters["ActivePowerTimeSeriesParameter__PowerLoad"]
        resUp_param = variables["ActivePowerReserveVariable__VariableReserve__ReserveUp__REG_UP"]
        resDown_param = variables["ActivePowerReserveVariable__VariableReserve__ReserveDown__REG_DN"]
        resSpin_param = variables["ActivePowerReserveVariable__VariableReserve__ReserveUp__SPIN"]
        slackup_var = variables["SystemBalanceSlackUp__Bus"]
        slackdwn_var = variables["SystemBalanceSlackDown__Bus"]
        thermPcost = expressions["ProductionCostExpression__ThermalMultiStart"]

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
        #thermPwr = read_realized_variable(uc_results, "ActivePowerVariable__ThermalMultiStart")
        thermPwr = read_realized_aux_variables(uc_results)["PowerOutput__ThermalMultiStart"]
        load_param = read_realized_parameter(uc_results, "ActivePowerTimeSeriesParameter__PowerLoad")
        resUp_param = read_realized_parameter(uc_results, "RequirementTimeSeriesParameter__VariableReserve__ReserveUp__REG_UP")
        resDown_param = read_realized_parameter(uc_results, "RequirementTimeSeriesParameter__VariableReserve__ReserveDown__REG_DN")
        resSpin_param = read_realized_parameter(uc_results, "RequirementTimeSeriesParameter__VariableReserve__ReserveUp__SPIN")
        slackup_var = read_realized_variable(uc_results, "SystemBalanceSlackUp__Bus")
        slackdwn_var = read_realized_variable(uc_results, "SystemBalanceSlackDown__Bus")
        thermPcost = read_realized_expression(uc_results, "ProductionCostExpression__ThermalMultiStart")
    end
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
        string("Slack", xcelname),
        slackdf,
        overwrite=true,
        sheetname="Slack",
        anchor_cell="A1"
    )
    #XLSX.writetable(
    #    string("CURTAILMENT", xcelname),
    #    renCurtail,
    #    overwrite = true,
    #    sheetname="Ren_Curtailment",
    #    anchor_cell="A1"
    #)
    XLSX.writetable(
        string("DEMAND", xcelname),
        load_param,
        overwrite=true,
        sheetname="Demand",
        anchor_cell = "A1"
    )
#    XLSX.writetable(
#        string("RESERVES", xcelname),
#        resUp_param,
#        overwrite=true,
#        sheetname="ResUP",
#        anchor_cell = "A1"
#    )
#    XLSX.writetable(
#        string("RESERVES", xcelname),
#        resDown_param,
#        overwrite=true,
#        sheetname="ResDWN",
#        anchor_cell = "A1"
#    )
#    XLSX.writetable(
#        string("RESERVES", xcelname),
#        resSpin_param,
#        overwrite=true,
#        sheetname="ResSPIN",
#        anchor_cell = "A1"
#    )

    # Execute Plotting
#    gr() # Loads the GR backend
#    plotlyjs() # Loads the JS backend
    # STACKED GENERATION PLOT:
    dem_name = string("PowerLoadDemand", sim_name, tran_set)
    #plot_demand(load_param, slackup_var, stack = true; title = dem_name, save = string(RES_DIR, date_folder), format = "svg");
    #plot_dataframe(load_param, slackup_var, stack = true; title = dem_name, save = string(RES_DIR, date_folder), format = "svg");
    # Stacked Gen by Fuel Type:
    fuelgen = string("FuelGenStack", sim_name, tran_set)
    #plot_fuel(uc_results, stack = true; title = fuelgen, save = string(RES_DIR), format = "svg");
    #To Specify Window: initial_time = DateTime("2018-01-01T00:00:00"), count = 168
    #plot_dataframe(renPwr, thermPwr, stack = true; title = fuelgen, save = string(RES_DIR, date_folder), format = "svg");
    # Reserves Plot
    resgen = string("Reserves", sim_name, tran_set)
    #plot_dataframe(resUp_param, resDown_param; title = resgen, save = string(RES_DIR, date_folder), format = "svg");
end

function tamuProd(case, ev_adpt_level)
    home_dir = "C:/Users/antho/github/tamu_ercot_dwpt"
    OUT_DIR = "D:/outputs/CompactThermal Set 1"
    RES_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots"
    if ev_adpt_level == 1
        Adopt = "A100"
    else
        Adopt = string("A", split(string(ev_adpt_level), ".")[2], "_")
        if sizeof(Adopt) == 3
            Adopt = string(split(Adopt, "_")[1], "0", "_")
        end
    end
    method = "T100"
    tran_set = string(Adopt, method)
    sim_name = string("dwpt-", case, "-lvlr-")
    sim_folder = joinpath(OUT_DIR, string(sim_name, tran_set))
    sim_folder = joinpath(sim_folder, "$(maximum(parse.(Int64,readdir(sim_folder))))")
    results = SimulationResults(sim_folder; ignore_status=true);
    uc_results = get_decision_problem_results(results, "UC")

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
        string("PROD_COST_NEW", xcelname),
        sysCost,
        overwrite=true,
        sheetname="Prod_Cost",
        anchor_cell="A1"
    )
end

function tamuGen(case, ev_adpt_level)
    home_dir = "C:/Users/antho/github/tamu_ercot_dwpt"
    OUT_DIR = "D:/outputs/CompactThermal Set 1"
    RES_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots"
    if ev_adpt_level == 1
        Adopt = "A100"
    else
        Adopt = string("A", split(string(ev_adpt_level), ".")[2], "_")
        if sizeof(Adopt) == 3
            Adopt = string(split(Adopt, "_")[1], "0", "_")
        end
    end
    method = "T100"
    tran_set = string(Adopt, method)
    sim_name = string("dwpt-", case, "-lvlr-")
    sim_folder = joinpath(OUT_DIR, string(sim_name, tran_set))
    sim_folder = joinpath(sim_folder, "$(maximum(parse.(Int64,readdir(sim_folder))))")
    results = SimulationResults(sim_folder; ignore_status=true);
    uc_results = get_decision_problem_results(results, "UC")

#    renPwr = read_realized_variable(uc_results, "ActivePowerVariable__RenewableDispatch");
    thermPwr = read_realized_aux_variables(uc_results)["PowerOutput__ThermalMultiStart"];
    sys_pwr = zeros(size(renPwr[!,1])[1]);
#    ren_num = size(renPwr[1,:])[1];
    therm_num = size(thermPwr[1,:])[1];
    for x = 1:size(sys_pwr)[1]
#        sys_pwr[x] = (sum(renPwr[x, 2:ren_num]) + sum(thermPwr[x, 2:therm_num]))*100
        sys_pwr[x] = sum(thermPwr[x, 2:therm_num])*100
    end
#    sysPwr = DataFrame()
#    insertcols!(sysPwr, 1, :DateTime => renPwr[!, 1]);
#    insertcols!(sysPwr, 2, :SystemPower => sys_pwr);

    ThPwr = DataFrame()
    insertcols!(ThPwr, 1, :DateTime => thermPwr[!, 1]);
    insertcols!(ThPwr, 2, :ThermPower => sys_pwr);
    date_folder = "/Mar29_22"
    cd(string(RES_DIR, date_folder))
    xcelname = string("_Output", sim_name, tran_set, ".xlsx")
#    XLSX.writetable(
#        string("GEN", xcelname),
#        sysPwr,
#        overwrite=true,
#        sheetname="Dispatch",
#        anchor_cell="A1"
#    )
    XLSX.writetable(
        string("TH_GEN", xcelname),
        ThPwr,
        overwrite=true,
        sheetname="TH_Dispatch",
        anchor_cell="A1"
    )
end

function tamuCurt(case, ev_adpt_level)
    home_dir = "C:/Users/antho/github/tamu_ercot_dwpt"
    active_dir = "D:/active"
    OUT_DIR = "D:/outputs/CompactThermal Set 1"
    RES_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots"
    if ev_adpt_level == 1
        Adopt = "A100"
    else
        Adopt = string("A", split(string(ev_adpt_level), ".")[2], "_")
        if sizeof(Adopt) == 3
            Adopt = string(split(Adopt, "_")[1], "0", "_")
        end
    end
    method = "T100"
    tran_set = string(Adopt, method)
    sim_name = string("dwpt-", case, "-lvlr-")
    system = System(joinpath(active_dir, string(sim_name, tran_set, "_sys.json")));
    sim_folder = joinpath(OUT_DIR, string(sim_name, tran_set))
    sim_folder = joinpath(sim_folder, "$(maximum(parse.(Int64,readdir(sim_folder))))")
    results = SimulationResults(sim_folder; ignore_status=true);
    uc_results = get_decision_problem_results(results, "UC")
    # CURTAILMENT CALCULATION
    renList = collect(get_components(RenewableDispatch, system));
    ren_tot = zeros(8760);
    for x = 1:size(renList)[1]
        new_ren = get_component(RenewableDispatch, system, renList[x].name)
        ren_data = get_time_series(Deterministic, new_ren, "max_active_power", count = 365).data;
        for h = 1:size(ren_tot)[1]
            d = Int.(floor(h/24) + 1)
            fh = 1
            forecast_window_hr = collect(ren_data)[d][2][fh]
            ren_tot[h] = ren_tot[h] + forecast_window_hr
        end
    end

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
        string("CURTAILMENT", xcelname),
        renCurtail,
        overwrite = true,
        sheetname="Ren_Curtailment",
        anchor_cell="A1"
    )
end
