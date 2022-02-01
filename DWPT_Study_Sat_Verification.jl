using PowerSystems
using PowerSimulations
const PSI = PowerSimulations

using CSV
using XLSX
using Plots
using Dates
using PyPlot
using DataFrames
using TimeSeries

using Cbc #solver

# Link to system
DATA_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/data"
main_dir = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/"
#system = System(joinpath(main_dir, "data/texas_data/DA_sys.json"))
system = System(joinpath(main_dir, "active/tamu_DA_sys.json"))

#Create empty template
template_uc = OperationsProblemTemplate()

#Injection Device Formulations
set_device_model!(template_uc, ThermalMultiStart, ThermalStandardUnitCommitment)
set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
set_device_model!(template_uc, HydroDispatch, FixedOutput)

#Service Formulations
set_service_model!(template_uc, VariableReserve{ReserveUp}, RangeReserve)
set_service_model!(template_uc, VariableReserve{ReserveDown}, RangeReserve)

#Network Formulations
set_transmission_model!(template_uc, CopperPlatePowerModel)

#Create Optimizer
solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 1, "ratioGap" => 0.5)

#Build OperationsProblem
op_problem = OperationsProblem(template_uc, system; optimizer = solver, horizon = 24, warm_start = false)


OUT_DIR = "C:/Users/A.J. Sauter/OneDrive - UCB-O365/Active Research/ASPIRE/CoSimulation Project/Julia_Modeling/outputs"
build!(op_problem, output_dir = OUT_DIR)

solve!(op_problem)

#print_struct(PSI.ProblemResults)

res = ProblemResults(op_problem);

get_optimizer_stats(res)
get_objective_value(res)
