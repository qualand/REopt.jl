using REopt
using JuMP
# using Cbc
# using HiGHS
using Xpress
using JSON
# using CSV
using DelimitedFiles
using Plots

using Printf
using PyCall

ENV["NREL_DEVELOPER_API_KEY"]="ogQAO0gClijQdYn7WOKeIS02zTUYLbwYJJczH9St"

KWH_PER_MMBTU = 293.07107   # [kWh/mmbtu]
KW_PER_MW = 1000.           # [kW/MW]

function print_results(results)
    println("Sub-system Sizing:")
    if "PV" in keys(results)
        println(@sprintf("\tPV: %5.3f kW", results["PV"]["size_kw"]))  
    else
        println("\tPV not in results.")
    end
    if "ElectricStorage" in keys(results)
        println(@sprintf("\tElectricStorage: %5.3f kW", results["ElectricStorage"]["size_kw"]))
        println(@sprintf("\tElectricStorage: %5.3f kWh", results["ElectricStorage"]["size_kwh"])) 
    else
        println("\tElectricStorage not in results.")
    end
    if "ElectricHeater" in keys(results)
        println(@sprintf("\tElectric Heater: %5.3f kW", results["ElectricHeater"]["size_mmbtu_per_hour"] * 293.07107))  # mmbtu/hr -> kW
    else
        println("\tElectric Heater not in results.")
    end
    if "HotSensibleTes" in keys(results)
        println(@sprintf("\tHot Sensible TES: %5.3f m^3", results["HotSensibleTes"]["size_gal"] / 264.1725))    # gal -> m^3
    else
        println("\tHot Sensible TES not in results.")
    end
    if "HotThermalStorage" in keys(results)
        println(@sprintf("\tHot Thermal Storage: %5.3f gal", results["HotThermalStorage"]["size_gal"])) 
    else
        println("\tHot TES not in results.")
    end
    if "SteamTurbine" in keys(results)
        println(@sprintf("\tSteam Turbine: %5.3f kW", results["SteamTurbine"]["size_kw"]))
    else
        println("\tSteam Turbine not in results.")
    end

    println("Summary of Loads:")
    if "ElectricLoad" in keys(results)
        println("\tAnnual electric load: ", results["ElectricLoad"]["annual_calculated_kwh"], " kWh")
    else
        println("\tNo Electric Load.")
    end
    println("\tAnnual process heat load: ", results["HeatingLoad"]["annual_calculated_process_heat_thermal_load_mmbtu"], " mmbtu")
    println("\tAnnual space heating load: ", results["HeatingLoad"]["annual_calculated_space_heating_thermal_load_mmbtu"], " mmbtu")
    println("\tAnnual hot water load: ", results["HeatingLoad"]["annual_calculated_dhw_thermal_load_mmbtu"], " mmbtu")
    println("\tAnnual total heating load: ", results["HeatingLoad"]["annual_calculated_total_heating_thermal_load_mmbtu"], " mmbtu")

    println("Financial:")
    if "ElectricUtility" in keys(results)
        println("\tAnnual grid purchases: ", results["ElectricUtility"]["annual_energy_supplied_kwh"], " kWh")
    end
    if "Financial" in keys(results)
        println("\tLifecyle Electrical Bill After Tax: \$", results["Financial"]["lifecycle_elecbill_after_tax"])
        println("\tLifecyle Fuel Bill After Tax: \$", results["Financial"]["lifecycle_fuel_costs_after_tax"])
    else
        println("\tNo financial in results.")
    end

    println("Generation:")
    if "PV" in keys(results)
        println("\tPV production: ", results["PV"]["annual_energy_produced_kwh"], " kWh")
    end

    if "ExistingBoiler" in keys(results)
        println("Existing Boiler:")
        println("\tBoiler to Turbine: ", round(sum(results["ExistingBoiler"]["thermal_to_steamturbine_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tBoiler to Load: ", round(sum(results["ExistingBoiler"]["thermal_to_load_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tBoiler to Storage: ", round(sum(results["ExistingBoiler"]["thermal_to_storage_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tBoiler to Hot Water: ", round(sum(results["ExistingBoiler"]["thermal_to_dhw_load_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tBoiler to Space Heating: ", round(sum(results["ExistingBoiler"]["thermal_to_space_heating_load_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tBoiler to Process Heat: ", round(sum(results["ExistingBoiler"]["thermal_to_process_heat_load_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tAnnual production: ", results["ExistingBoiler"]["annual_thermal_production_mmbtu"], " mmbtu")
    else
        println("No Existing Boiler in results.")
    end

    if "ElectricHeater" in keys(results)
        println("Charging:")
        println("\tElectricHeater Size: ", results["ElectricHeater"]["size_mmbtu_per_hour"], " mmbtu/hr")
        println("\tElectricHeater Electric Consumption: ", round(results["ElectricHeater"]["annual_electric_consumption_kwh"], digits = 2), " kWh")
        println("\tElectricHeater Thermal to Load: ", round(sum(results["ElectricHeater"]["thermal_to_load_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tElectricHeater Thermal to Turbine: ", round(sum(results["ElectricHeater"]["thermal_to_steamturbine_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tElectricHeater Thermal to All Hot Storage: ", round(sum(results["ElectricHeater"]["thermal_to_storage_series_mmbtu_per_hour"]),digits = 2), " mmbtu")
        println("\tElectricHeater Thermal to HotSensibleTes: ", round(sum(results["ElectricHeater"]["thermal_to_hot_sensible_tes_series_mmbtu_per_hour"]),digits = 2), " mmbtu")
        println("\tElectricHeater Thermal to Hot Water: ", round(sum(results["ElectricHeater"]["thermal_to_dhw_load_series_mmbtu_per_hour"]),digits = 2), " mmbtu")
        println("\tElectricHeater Thermal to Space Heating: ", round(sum(results["ElectricHeater"]["thermal_to_space_heating_load_series_mmbtu_per_hour"]),digits = 2), " mmbtu")
        println("\tElectricHeater Thermal to Process Heat: ", round(sum(results["ElectricHeater"]["thermal_to_process_heat_load_series_mmbtu_per_hour"]),digits = 2), " mmbtu")
    end
    if "HotSensibleTes" in keys(results)
        println("Discharging:")
        println("\tHotSensibleTes Size: ", results["HotSensibleTes"]["size_gal"], " gal")
        println("\tHotSensibleTes Size: ", results["HotSensibleTes"]["size_kwh"], " kWh")
        println("\tHotSensibleTes to Turbine: ", round(sum(results["HotSensibleTes"]["storage_to_turbine_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tHotSensibleTes to Load: ", round(sum(results["HotSensibleTes"]["storage_to_load_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
    end
    if "HotThermalStorage" in keys(results)
        println("\tHotThermalStorage Size: ", results["HotThermalStorage"]["size_gal"], " gal")
        println("\tHotThermalStorage Size: ", results["HotThermalStorage"]["size_kwh"], " kWh")
        if results["HotThermalStorage"]["size_kwh"] != 0.0
            println("\tHotThermalStorage to Turbine: ", round(sum(results["HotThermalStorage"]["storage_to_turbine_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
            println("\tHotThermalStorage to Load: ", round(sum(results["HotThermalStorage"]["storage_to_load_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        end
    end
    if "SteamTurbine" in keys(results)
        println("Steam Turbine:")
        println("\tSteam Turbine Size: ", results["SteamTurbine"]["size_kw"], " kW")
        println("\tAnnual thermal consumption: ", results["SteamTurbine"]["annual_thermal_consumption_mmbtu"], " mmbtu")
        println("\tAnnual electric production: ", results["SteamTurbine"]["annual_electric_production_kwh"], " kWh")
        println("\tAnnual thermal production: ", results["SteamTurbine"]["annual_thermal_production_mmbtu"], " mmbtu")
        println("\tSteam Turbine to All Hot Thermal Storage: ", round(sum(results["SteamTurbine"]["thermal_to_storage_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tSteam Turbine to Hot Sensible TES: ", round(sum(results["SteamTurbine"]["thermal_to_hot_sensible_tes_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tSteam Turbine to Hot Water Load: ", round(sum(results["SteamTurbine"]["thermal_to_dhw_load_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tSteam Turbine to Space Heating Load: ", round(sum(results["SteamTurbine"]["thermal_to_space_heating_load_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tSteam Turbine to Process Heat Load: ", round(sum(results["SteamTurbine"]["thermal_to_process_heat_load_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
    end
end

function export_results_to_json(results, json_file_name)

    for tech in keys(results)
        if typeof(results[tech]) <: Dict
            for key in keys(results[tech])
                if typeof(results[tech][key]) <: JuMP.Containers.DenseAxisArray
                    results[tech][key] = Array(results[tech][key])
                elseif typeof(results[tech][key]) <: Vector
                    results[tech][key] = Array(results[tech][key])
                end
            end
        end
    end
    json_string = JSON.json(results)
    open(json_file_name, "w") do file
        write(file, json_string)
    end
end

function add_tariff_data_to_results(results, p)
    results["ElectricTariff"]["energy_rates_per_kwh"] = p.s.electric_tariff.energy_rates
    results["ElectricTariff"]["monthly_demand_rates_per_kw"] = p.s.electric_tariff.monthly_demand_rates
    results["ElectricTariff"]["time_steps_monthly"] = p.s.electric_tariff.time_steps_monthly
    results["ElectricTariff"]["tou_demand_rates_per_kw"] = p.s.electric_tariff.tou_demand_rates
    results["ElectricTariff"]["tou_demand_time_steps"] = p.s.electric_tariff.tou_demand_ratchet_time_steps
    return results
end

function solve_model_save_res(input_dict, print_msg, res_file)
    # Set up scenario
    s = Scenario(input_dict)
    p = REoptInputs(s)

    # Create model with solver params and solve
    # Xpress solver options: https://www.fico.com/fico-xpress-optimization/docs/latest/solver/optimizer/HTML/chapter7.html
    m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => 0.01, "OUTPUTLOG" => 1, "MAXTIME" => 500))
    results = run_reopt(m1, p)

    # Print results
    println(print_msg)
    print_results(results)

    # Add electric tariff and save results
    results = add_tariff_data_to_results(results, p)
    export_results_to_json(results, res_file)
end

is_bau = true
is_pv_bat_eh_ots = true
is_pv_bat_hp_ots = true
is_pv_ptes_ots = true
run_retire_boiler_cases = true

results_root = "C:/Users/whamilt2/Documents/Projects/LDRD_PTES_CHP/reopt_study/results_zerominTES/"

# Reading Site and Load data
site_load = JSON.parsefile("./test/scenarios/CA_flatloads.json")
# Flat process heat load
heat_load_mw = 1  # [MWt]
heat_load_mmbtu_per_hour = heat_load_mw * KW_PER_MW * (1/KWH_PER_MMBTU) / site_load["ExistingBoiler"]["efficiency"]
site_load["ProcessHeatLoad"] = Dict()
site_load["ProcessHeatLoad"]["fuel_loads_mmbtu_per_hour"] = ones(8760) .* heat_load_mmbtu_per_hour
site_load["ProcessHeatLoad"]["fuel_loads_mmbtu_per_hour"][1] = 0.0  #initialize so that storage may charge in the first time period

## Case 0: BAU
if is_bau
    solve_model_save_res(site_load, 
    "Results of Case 0: Business as Usual (BAU)",
    results_root * "case0_bau_results.json")
end

##Case 1 and 4: Only PV, Battery, and Elecric Heater -> low-temp TES
if is_pv_bat_eh_ots
    d = JSON.parsefile("./test/scenarios/pv_battery_eh_lowtempTES.json")
    d = merge(d, site_load)

    # Fix PV capacity - if needed
    #d["PV"]["existing_kw"] = 100000.0
    #d["PV"]["min_kw"] = 91608.0 #90000.0 #100000.0
    #d["PV"]["max_kw"] = 91608.0 #90000.0 #100000.0
    d["PV"]["max_kw"] = 1000000.0

    solve_model_save_res(d, 
    "Results of Case 1: Only PV, Battery, Elecric Heater -> low-temp TES",
    results_root * "case1_pv_bat_eh_ots_results.json")

    if run_retire_boiler_cases
        # Retire boiler
        d["ExistingBoiler"]["retire_in_optimal"] = true
        solve_model_save_res(d, 
        "Results of Case 4: (retire boiler) Only PV, Battery, Elecric Heater -> low-temp TES",
        results_root * "case4_retireBoiler_pv_bat_eh_ots_results.json")
    end
end

##Case 2 and 5: Only PV, Battery, and Heat Pump -> low-temp TES
if is_pv_bat_hp_ots
    # d = JSON.parsefile("./test/scenarios/pv_battery_hp_lowtempTES.json")  # Modifying electric heater case
    d = JSON.parsefile("./test/scenarios/pv_battery_eh_lowtempTES.json")
    d = merge(d, site_load)

    # Heat pump parameters modifications
    d["ElectricHeater"]["cop"] = 2.0
    d["ElectricHeater"]["installed_cost_per_mmbtu_per_hour"] = 161189.0
    d["ElectricHeater"]["om_cost_per_mmbtu_per_hour"] = 8060.0              # ~5% of installed cost
    
    # Fix PV capacity
    #d["PV"]["existing_kw"] = 100000.0
    #d["PV"]["min_kw"] = 91608.0 #90000.0 #100000.0
    #d["PV"]["max_kw"] = 91608.0 #90000.0 #100000.0
    d["PV"]["max_kw"] = 1000000.0

    solve_model_save_res(d, 
    "Results of Case 2: PV, Battery, Heat pump -> low-temp TES",
    results_root * "case2_pv_bat_hp_ots_results.json")

    if run_retire_boiler_cases
        # Retire boiler
        d["ExistingBoiler"]["retire_in_optimal"] = true
        solve_model_save_res(d, 
        "Results of Case 5: (retire boiler) Only PV, Battery, Heat pump -> low-temp TES",
        results_root * "case5_retireBoiler_pv_bat_hp_ots_results.json")
    end
end

##Case 3 and 6: PV, PTES (Electric Heater, Hot Sensible TES, Steam Turbine) -> low-temp TES
if is_pv_ptes_ots
    d = JSON.parsefile("./test/scenarios/pv_PTES_lowtempTES.json")
    d = merge(d, site_load)

    # Fix PV capacity
    #d["PV"]["existing_kw"] = 100000.0
    #d["PV"]["min_kw"] = 36100.0 #90000.0 #100000.0
    #d["PV"]["max_kw"] = 36100.0 #90000.0 #100000.0
    d["PV"]["max_kw"] = 1000000.0

    solve_model_save_res(d, 
    "Results of Case 3: PV, PTES (Electric Heater, Hot Sensible TES, Steam Turbine) -> low-temp TES",
    results_root * "case3_pv_PTES_ots_results.json")

    if run_retire_boiler_cases
        # Retire boiler
        d["ExistingBoiler"]["retire_in_optimal"] = true
        solve_model_save_res(d, 
        "Results of Case 6: (retire boiler) PV, PTES (Electric Heater, Hot Sensible TES, Steam Turbine) -> low-temp TES",
        results_root * "case6_pv_PTES_ots_results.json")
    end
end

