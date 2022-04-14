#home_dir = "C:/Users/antho/github/tamu_ercot_dwpt"
#home_dir = "C:/Users/A.J. Sauter/github/tamu_ercot_dwpt"
#home_dir = "A:/Users/Documents/ASPIRE_Simulators/tamu_ercot_dwpt"
#home_dir = "/home/ansa1773/tamu_ercot_dwpt"
# cd(home_dir)
# include("DWPT_SimRun.jl")

#run_spot = "Alpine"
#case = "hs"
# Level of EV adoption (value from 0 to 1)
#ev_adpt_level = .05

include("simFunctions.jl")
function simRun(run_spot, case, ev_adpt_level)
    ex_only = false
    nsteps = 2
    sim_name = string("dwpt-", case, "-lvlr-")
    method = "T100"
    tamuSimEx(run_spot, ex_only, ev_adpt_level, method, sim_name, nsteps, case)
#    tamuSimRes(run_spot, ev_adpt_level, method, sim_name)
end
