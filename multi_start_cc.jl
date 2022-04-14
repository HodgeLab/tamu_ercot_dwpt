struct StandardCommitmentCC <: PSI.DecisionProblem end # This is my slightly tailored deterministic

struct CCConstraint <: PSI.ConstraintType end

function apply_cc_constraints!(model)
    optimization_container = PSI.get_optimization_container(model)
    restrictions = model.ext["cc_restrictions"]
    commitment_variables = PSI.get_variable(optimization_container, On(), PSY.ThermalMultiStart)
    time_steps = PSI.model_time_steps(optimization_container)
    constraint = PSI.add_constraint_container!(
        optimization_container,
        CCConstraint(),
        PSY.ThermalMultiStart,
        collect(keys(restrictions)),
        time_steps,
    )
    jump_model = PSI.get_jump_model(optimization_container)
    for t in time_steps, (k, v) in restrictions
        constraint[k, t] =
            JuMP.@constraint(jump_model, sum(commitment_variables[i, t] for i in v) <= 1)
    end
    return
end

function apply_must_run_constraints!(model)
    system = PSI.get_system(model)
    optimization_container = PSI.get_optimization_container(model)
    time_steps = PSI.model_time_steps(optimization_container)
    must_run_gens =
        [g for g in PSY.get_components(ThermalMultiStart, system, x -> PSY.get_must_run(x))]
    commitment_variables = PSI.get_variable(optimization_container, On(), PSY.ThermalMultiStart)
    for t in time_steps, g in get_name.(must_run_gens)
        JuMP.fix(commitment_variables[g, t], 1.0)
    end
end

function PSI.build_impl!(model::PSI.DecisionModel{StandardCommitmentCC})
    PSI.build_impl!(get_optimization_container(model), get_template(model), get_system(model))
    apply_cc_constraints!(model)
    apply_must_run_constraints!(model)
end
