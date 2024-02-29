# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
function add_storage_size_constraints(m, p, b; _n="")
    # TODO add formal types for storage (i.e. "b")

	# Constraint (4b)-1: Lower bound on Storage Energy Capacity
	@constraint(m,
        m[Symbol("dvStorageEnergy"*_n)][b] >= p.s.storage.attr[b].min_kwh
    )

	# Constraint (4b)-2: Upper bound on Storage Energy Capacity
	@constraint(m,
        m[Symbol("dvStorageEnergy"*_n)][b] <= p.s.storage.attr[b].max_kwh
    )

	# Constraint (4c)-1: Lower bound on Storage Power Capacity
	@constraint(m,
        m[Symbol("dvStoragePower"*_n)][b] >= p.s.storage.attr[b].min_kw
    )

	# Constraint (4c)-2: Upper bound on Storage Power Capacity
	@constraint(m,
        m[Symbol("dvStoragePower"*_n)][b] <= p.s.storage.attr[b].max_kw
    )
end

function add_hydrogen_storage_size_constraints(m, p, b; _n="")
    # TODO add formal types for storage (i.e. "b")

	# Constraint (4b)-1: Lower bound on Storage Energy Capacity
	@constraint(m,
        m[Symbol("dvStorageEnergy"*_n)][b] >= p.s.storage.attr[b].min_kg
    )

	# Constraint (4b)-2: Upper bound on Storage Energy Capacity
	@constraint(m,
        m[Symbol("dvStorageEnergy"*_n)][b] <= p.s.storage.attr[b].max_kg
    )

	# # Constraint (4c)-1: Lower bound on Storage Power Capacity
	# @constraint(m,
    #     m[Symbol("dvStoragePower"*_n)][b] >= p.s.storage.attr[b].min_kw
    # )

	# # Constraint (4c)-2: Upper bound on Storage Power Capacity
	# @constraint(m,
    #     m[Symbol("dvStoragePower"*_n)][b] <= p.s.storage.attr[b].max_kw
    # )
end

function add_general_storage_dispatch_constraints(m, p, b; _n="")
    # Constraint (4a): initial state of charge
	@constraint(m,
        m[Symbol("dvStoredEnergy"*_n)][b, 0] == p.s.storage.attr[b].soc_init_fraction * m[Symbol("dvStorageEnergy"*_n)][b]
    )

    #Constraint (4n): State of charge upper bound is storage system size
    @constraint(m, [ts in p.time_steps],
        m[Symbol("dvStoredEnergy"*_n)][b,ts] <= m[Symbol("dvStorageEnergy"*_n)][b]
    )

    # Constraint (4j): Minimum state of charge
	@constraint(m, [ts in p.time_steps],
        m[Symbol("dvStoredEnergy"*_n)][b, ts] >= p.s.storage.attr[b].soc_min_fraction * m[Symbol("dvStorageEnergy"*_n)][b]
    )

    #Constraint (4j): Dispatch from storage is no greater than power capacity
	@constraint(m, [ts in p.time_steps],
        m[Symbol("dvStoragePower"*_n)][b] >= m[Symbol("dvDischargeFromStorage"*_n)][b, ts]
    )

end


function add_elec_storage_dispatch_constraints(m, p, b; _n="")
				
	# Constraint (4g): state-of-charge for electrical storage - with grid
	@constraint(m, [ts in p.time_steps_with_grid],
        m[Symbol("dvStoredEnergy"*_n)][b, ts] == m[Symbol("dvStoredEnergy"*_n)][b, ts-1] + p.hours_per_time_step * (  
            sum(p.s.storage.attr[b].charge_efficiency * m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for t in p.techs.elec) 
            + p.s.storage.attr[b].grid_charge_efficiency * m[Symbol("dvGridToStorage"*_n)][b, ts] 
            - m[Symbol("dvDischargeFromStorage"*_n)][b,ts] / p.s.storage.attr[b].discharge_efficiency
            - m[Symbol("dvStorageToElectrolyzer"*_n)][b,ts] / p.s.storage.attr[b].discharge_efficiency
            - m[Symbol("dvStorageToCompressor"*_n)][b,ts] / p.s.storage.attr[b].discharge_efficiency
        )
        - ((p.s.storage.attr[b].daily_leakage_fraction/24/p.hours_per_time_step) * m[Symbol("dvStoredEnergy"*_n)][b, ts])
	)

	# Constraint (4h): state-of-charge for electrical storage - no grid
	@constraint(m, [ts in p.time_steps_without_grid],
        m[Symbol("dvStoredEnergy"*_n)][b, ts] == m[Symbol("dvStoredEnergy"*_n)][b, ts-1] + p.hours_per_time_step * (  
            sum(p.s.storage.attr[b].charge_efficiency * m[Symbol("dvProductionToStorage"*_n)][b,t,ts] for t in p.techs.elec) 
            - m[Symbol("dvDischargeFromStorage"*_n)][b, ts] / p.s.storage.attr[b].discharge_efficiency
            - m[Symbol("dvStorageToElectrolyzer"*_n)][b, ts] / p.s.storage.attr[b].discharge_efficiency
            - m[Symbol("dvStorageToCompressor"*_n)][b, ts] / p.s.storage.attr[b].discharge_efficiency
        )
        - ((p.s.storage.attr[b].daily_leakage_fraction/24/p.hours_per_time_step) * m[Symbol("dvStoredEnergy"*_n)][b, ts])
    )

	# Constraint (4i)-1: Dispatch to electrical storage is no greater than power capacity
	@constraint(m, [ts in p.time_steps],
        m[Symbol("dvStoragePower"*_n)][b] >= 
            sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for t in p.techs.elec) + m[Symbol("dvGridToStorage"*_n)][b, ts]
    )
	
	#Constraint (4k)-alt: Dispatch to and from electrical storage is no greater than power capacity
	@constraint(m, [ts in p.time_steps_with_grid],
        m[Symbol("dvStoragePower"*_n)][b] >= m[Symbol("dvDischargeFromStorage"*_n)][b, ts] 
            + m[Symbol("dvStorageToElectrolyzer"*_n)][b, ts] + m[Symbol("dvStorageToCompressor"*_n)][b, ts] +
            sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for t in p.techs.elec) + m[Symbol("dvGridToStorage"*_n)][b, ts]
    )

	#Constraint (4l)-alt: Dispatch from electrical storage is no greater than power capacity (no grid connection)
	@constraint(m, [ts in p.time_steps_without_grid],
        m[Symbol("dvStoragePower"*_n)][b] >= m[Symbol("dvDischargeFromStorage"*_n)][b,ts] + 
            m[Symbol("dvStorageToElectrolyzer"*_n)][b, ts] + m[Symbol("dvStorageToCompressor"*_n)][b, ts] +
            sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for t in p.techs.elec)
    )
					
    # Remove grid-to-storage as an option if option to grid charge is turned off
    if !(p.s.storage.attr[b].can_grid_charge)
        for ts in p.time_steps_with_grid
            fix(m[Symbol("dvGridToStorage"*_n)][b, ts], 0.0, force=true)
        end
	end

    if p.s.storage.attr[b].minimum_avg_soc_fraction > 0
        avg_soc = sum(m[Symbol("dvStoredEnergy"*_n)][b, ts] for ts in p.time_steps) /
                   (8760. / p.hours_per_time_step)
        @constraint(m, avg_soc >= p.s.storage.attr[b].minimum_avg_soc_fraction * 
            sum(m[Symbol("dvStorageEnergy"*_n)][b])
        )
    end
end

function add_hot_thermal_storage_dispatch_constraints(m, p, b; _n="")

    # # Constraint (4f)-1: (Hot) Thermal production sent to storage or grid must be less than technology's rated production
	# # Constraint (4f)-1a: BoilerTechs
	for t in p.techs.boiler
		if !isempty(p.techs.steam_turbine) && (t in p.techs.can_supply_steam_turbine)
            @constraint(m, [b in p.s.storage.types.hot, ts in p.time_steps],
                    m[Symbol("dvProductionToStorage"*_n)][b,t,ts] + m[Symbol("dvThermalToSteamTurbine"*_n)][t,ts]  <=
                    m[Symbol("dvThermalProduction"*_n)][t,ts]
                    )
        else
            @constraint(m, [b in p.s.storage.types.hot, ts in p.time_steps],
                    m[Symbol("dvProductionToStorage"*_n)][b,t,ts]  <=
                    m[Symbol("dvThermalProduction"*_n)][t,ts]
                    )
        end
    end

    if !isempty(p.techs.electric_heater)
        for t in p.techs.electric_heater
            if !isempty(p.techs.steam_turbine) && (t in p.techs.can_supply_steam_turbine)
                @constraint(m, [b in p.s.storage.types.hot, ts in p.time_steps],
                        m[Symbol("dvProductionToStorage"*_n)][b,t,ts] + m[Symbol("dvThermalToSteamTurbine"*_n)][t,ts]  <=
                        m[Symbol("dvThermalProduction"*_n)][t,ts]
                        )
            else
                @constraint(m, [b in p.s.storage.types.hot, ts in p.time_steps],
                        m[Symbol("dvProductionToStorage"*_n)][b,t,ts]  <=
                        m[Symbol("dvThermalProduction"*_n)][t,ts]
                        )
            end
        end
    end

    # Constraint (4f)-1b: SteamTurbineTechs
	if !isempty(p.techs.steam_turbine)
		@constraint(m, SteamTurbineTechProductionFlowCon[b in p.s.storage.types.hot, t in p.techs.steam_turbine, ts in p.time_steps],
			m[Symbol("dvProductionToStorage"*_n)][b,t,ts] <=  m[Symbol("dvThermalProduction"*_n)][t,ts]
			)
	end

    # # Constraint (4g): CHP Thermal production sent to storage or grid must be less than technology's rated production
	if !isempty(p.techs.chp)
		if !isempty(p.techs.steam_turbine) && p.s.chp.can_supply_steam_turbine
            @constraint(m, CHPTechProductionFlowCon[b in p.s.storage.types.hot, t in p.techs.chp, ts in p.time_steps],
                    m[Symbol("dvProductionToStorage"*_n)][b,t,ts] + m[Symbol("dvProductionToWaste"*_n)][t,ts] + m[Symbol("dvThermalToSteamTurbine"*_n)][t,ts] <=
                    m[Symbol("dvThermalProduction"*_n)][t,ts]
                    )
        else
            @constraint(m, CHPTechProductionFlowCon[b in p.s.storage.types.hot, t in p.techs.chp, ts in p.time_steps],
                    m[Symbol("dvProductionToStorage"*_n)][b,t,ts] + m[Symbol("dvProductionToWaste"*_n)][t,ts] <=
                    m[Symbol("dvThermalProduction"*_n)][t,ts]
                    )
        end
	end

    # Constraint (4j)-1: Reconcile state-of-charge for (hot) thermal storage
	@constraint(m, [b in p.s.storage.types.hot, ts in p.time_steps],
    m[Symbol("dvStoredEnergy"*_n)][b,ts] == m[Symbol("dvStoredEnergy"*_n)][b,ts-1] + (1/p.s.settings.time_steps_per_hour) * (
        sum( p.s.storage.attr[b].charge_efficiency * m[Symbol("dvProductionToStorage"*_n)][b,t,ts] for t in union(p.techs.heating, p.techs.chp)) -
        m[Symbol("dvDischargeFromStorage"*_n)][b,ts] / p.s.storage.attr[b].discharge_efficiency -
        p.s.storage.attr[b].thermal_decay_rate_fraction * m[Symbol("dvStorageEnergy"*_n)][b]
        )
    )
    
    #Constraint (4n)-1: Dispatch to and from thermal storage is no greater than power capacity
	@constraint(m, [b in p.s.storage.types.hot, ts in p.time_steps],
        m[Symbol("dvStoragePower"*_n)][b] >= 
        m[Symbol("dvDischargeFromStorage"*_n)][b,ts] + 
        sum(m[Symbol("dvProductionToStorage"*_n)][b,t,ts] for t in union(p.techs.heating, p.techs.chp))
    )
    # TODO missing thermal storage constraints from API ???

end

function add_cold_thermal_storage_dispatch_constraints(m, p, b; _n="")

    # Constraint (4f)-2: (Cold) Thermal production sent to storage or grid must be less than technology's rated production
	if !isempty(p.techs.cooling)
		@constraint(m, CoolingTechProductionFlowCon[b in p.s.storage.types.cold, t in p.techs.cooling, ts in p.time_steps],
    	        m[Symbol("dvProductionToStorage"*_n)][b,t,ts]  <=
				m[Symbol("dvThermalProduction"*_n)][t,ts]
				)
	end

    # Constraint (4j)-2: Reconcile state-of-charge for (cold) thermal storage
	@constraint(m, ColdTESInventoryCon[b in p.s.storage.types.cold, ts in p.time_steps],
    m[Symbol("dvStoredEnergy"*_n)][b,ts] == m[Symbol("dvStoredEnergy"*_n)][b,ts-1] + (1/p.s.settings.time_steps_per_hour) * (
        sum(p.s.storage.attr[b].charge_efficiency * m[Symbol("dvProductionToStorage"*_n)][b,t,ts] for t in p.techs.cooling) -
        m[Symbol("dvDischargeFromStorage"*_n)][b,ts]/p.s.storage.attr[b].discharge_efficiency -
        p.s.storage.attr[b].thermal_decay_rate_fraction * m[Symbol("dvStorageEnergy"*_n)][b]
        )
    )

    #Constraint (4n)-2: Dispatch to and from thermal storage is no greater than power capacity
    @constraint(m, [b in p.s.storage.types.cold, ts in p.time_steps],
        m[Symbol("dvStoragePower"*_n)][b] >= m[Symbol("dvDischargeFromStorage"*_n)][b,ts] + 
        sum(m[Symbol("dvProductionToStorage"*_n)][b,t,ts] for t in p.techs.cooling)
    )
end

function add_storage_sum_constraints(m, p; _n="")

	##Constraint (8c): Grid-to-storage no greater than grid purchases 
	@constraint(m, [ts in p.time_steps_with_grid],
      sum(m[Symbol("dvGridPurchase"*_n)][ts, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers) >= 
      sum(m[Symbol("dvGridToStorage"*_n)][b, ts] for b in p.s.storage.types.elec)
      + m[Symbol("dvGridToElectrolyzer"*_n)][ts]
      + m[Symbol("dvGridToCompressor"*_n)][ts]
    )
end

function add_hp_hydrogen_storage_dispatch_constraints(m, p, b; _n="")

    # @constraint(m, m[Symbol("dvStoredEnergy"*_n)][b, 3] == 10)
	# Constraint
	@constraint(m, [ts in p.time_steps],
        m[Symbol("dvStoredEnergy"*_n)][b, ts] == m[Symbol("dvStoredEnergy"*_n)][b, ts-1] + p.hours_per_time_step * (  
            sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for t in p.techs.compressor) 
            - m[Symbol("dvDischargeFromStorage"*_n)][b,ts]
        )
        - ((p.s.storage.attr[b].daily_leakage_fraction/24/p.hours_per_time_step) * m[Symbol("dvStoredEnergy"*_n)][b, ts])
	)

	# Constraint
	@constraint(m, [ts in p.time_steps],
        m[Symbol("dvStoragePower"*_n)][b] >= 
            sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for t in p.techs.compressor)
    )
	
	#Constraint
	@constraint(m, [ts in p.time_steps_with_grid],
        m[Symbol("dvStoragePower"*_n)][b] >= m[Symbol("dvDischargeFromStorage"*_n)][b, ts] + 
            sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for t in p.techs.compressor)
    )
					
    if p.s.storage.attr[b].minimum_avg_soc_fraction > 0
        avg_soc = sum(m[Symbol("dvStoredEnergy"*_n)][b, ts] for ts in p.time_steps) /
                   (8760. / p.hours_per_time_step)
        @constraint(m, avg_soc >= p.s.storage.attr[b].minimum_avg_soc_fraction * 
            sum(m[Symbol("dvStorageEnergy"*_n)][b])
        )
    end
end

function add_lp_hydrogen_storage_dispatch_constraints(m, p, b; _n="")
				
	# Constraint
	@constraint(m, [ts in p.time_steps],
        m[Symbol("dvStoredEnergy"*_n)][b, ts] == m[Symbol("dvStoredEnergy"*_n)][b, ts-1] + p.hours_per_time_step * (  
            sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for t in p.techs.electrolyzer) 
            - m[Symbol("dvDischargeFromStorage"*_n)][b,ts]
        )
        - ((p.s.storage.attr[b].daily_leakage_fraction/24/p.hours_per_time_step) * m[Symbol("dvStoredEnergy"*_n)][b, ts])
	)

    # Constraint
	@constraint(m, [b in p.s.storage.types.hydrogen_lp, ts in p.time_steps],
        sum(m[Symbol("dvDischargeFromStorage"*_n)][b,ts]) == 
            sum(p.production_factor[t, ts] * p.levelization_factor[t] * m[Symbol("dvRatedProduction"*_n)][t,ts] / p.s.compressor.efficiency_kwh_per_kg for t in p.techs.compressor)
            + sum(p.production_factor[t, ts] * p.levelization_factor[t] * m[Symbol("dvRatedProduction"*_n)][t,ts] / p.s.fuel_cell.efficiency_kwh_per_kg for t in p.techs.fuel_cell)
	)

	# Constraint
	@constraint(m, [ts in p.time_steps],
        m[Symbol("dvStoragePower"*_n)][b] >= 
            sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for t in p.techs.electrolyzer)
    )
	
	#Constraint
	@constraint(m, [ts in p.time_steps_with_grid],
        m[Symbol("dvStoragePower"*_n)][b] >= m[Symbol("dvDischargeFromStorage"*_n)][b, ts] + 
            sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for t in p.techs.electrolyzer)
    )
					
    if p.s.storage.attr[b].minimum_avg_soc_fraction > 0
        avg_soc = sum(m[Symbol("dvStoredEnergy"*_n)][b, ts] for ts in p.time_steps) /
                   (8760. / p.hours_per_time_step)
        @constraint(m, avg_soc >= p.s.storage.attr[b].minimum_avg_soc_fraction * 
            sum(m[Symbol("dvStorageEnergy"*_n)][b])
        )
    end
end