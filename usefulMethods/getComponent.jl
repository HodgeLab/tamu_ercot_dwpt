
# HOW TO GET BATTERY MAX CAPS FROM SYSTEM
capsum = 0
for x in get_components(GenericBattery, system)
    show(get_name(x))
    println()
    soc_lim = get_state_of_charge_limits(x)
    bp = get_base_power(x)
    batcap = soc_lim.max*bp
    capsum = capsum + batcap
    println("Capacity: ", batcap)
    println()
    println()
end
