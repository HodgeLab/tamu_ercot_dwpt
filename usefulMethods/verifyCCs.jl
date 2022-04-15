using PowerSystems
using PowerGraphics
using PowerSimulations # NOTE: Package is PowerSimulations#master
using InfrastructureSystems
const PSI = PowerSimulations
using CSV
using XLSX
using Dates
using PlotlyJS
using DataFrames
using TimeSeries
using Gurobi
using Logging

using JSON
using JuMP

ev_adpt_level = .05
method = "T100"
case = "hs"
sim_name = string("dwpt-", case, "-lvlr-")
nsteps = 4
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

home_dir = "C:/Users/antho/github/tamu_ercot_dwpt"
main_dir = "C:\\Users\\antho\\OneDrive - UCB-O365\\Active Research\\ASPIRE\\CoSimulation Project\\Julia_Modeling"
OUT_DIR = "D:/outputs"
RES_DIR = "C:/Users/antho/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/Satellite_Execution/Result_Plots"
active_dir = "D:/active"

println("Locating existing system: ", sim_name, tran_set, "_sys.json")
system = System(joinpath(active_dir, string(sim_name, tran_set, "_sys.json")))

cd(home_dir)
#Create empty template, define Network Model, use slacks and duals
template_uc = ProblemTemplate(NetworkModel(
    DCPPowerModel,
    use_slacks = true,
    duals = [NodalBalanceActiveConstraint] #CopperPlateBalanceConstraint
))

#Injection Device Formulations
set_device_model!(template_uc, ThermalMultiStart, ThermalCompactUnitCommitment) #ThermalBasicUnitCommitment
#set_device_model!(template_uc, ThermalMultiStart, StandardCommitmentCC) #ThermalBasicUnitCommitment
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
    )
models = SimulationModels(UC)

UC.ext["cc_restrictions"] = JSON.parsefile(joinpath(active_dir, string(sim_name, tran_set, "_sys.json")))

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
    initial_time = DateTime("2018-01-01T00:00:00"), # Data for this sim is 2018
    simulation_folder = OUT_DIR, # specify location of your simulation output files
)
# Use serialize = false only during development
build_out = build!(sim, serialize = false; console_level = Logging.Error, file_level = Logging.Info)
solve!(UC)
