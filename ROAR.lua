ROAR = {}
ROAR.version = 0.3
env.info("ROAR: RotorOps Air Race Script Started v."..ROAR.version)
trigger.action.outText("STAY ON THE GROUND!  Start the race coundown from F10 menu when all players ready.", 600, true)

ROAR.standings = {}
ROAR.start_time = 0
ROAR.grace_time = 300  --seconds after the winner finishes, the mission will end
ROAR.start_countdown = 30
ROAR.zone_gates = {}

ROAR.player_unit_names = {
	'P1',
	'P2',
	'P3',
	'P4',
	'P5',
	'P6',
	'P7',
	'P8',
	'P9',
	'P10',
	'P11',
	'P12',
	'P13',
	'P14',
	'P15',
	'P16',
}

ROAR.player_data = {}
ROAR.first_place = {name=nil, gate=0}

for index, _unit_name in pairs(ROAR.player_unit_names) do
	ROAR.player_data[_unit_name] = {finished=false, gate=0}
end

function ROAR.smoke()
    for zone, zoneobj in pairs(mist.DBs.zonesByName) do --smoke_color  Green=0 Red=1 White=2 Orange=3 Blue=4 NONE= -1
		env.info("ROAR: found zone: " .. zone)
        if string.find(zone, "GREEN") then
            trigger.action.smoke(trigger.misc.getZone(zone).point , 0)  
        elseif string.find(zone, "RED") then
            trigger.action.smoke(trigger.misc.getZone(zone).point , 1)  
        elseif string.find(zone, "WHITE") then
            trigger.action.smoke(trigger.misc.getZone(zone).point , 2)  
        elseif string.find(zone, "ORANGE") then
            trigger.action.smoke(trigger.misc.getZone(zone).point , 3)  
        elseif string.find(zone, "BLUE") then
            trigger.action.smoke(trigger.misc.getZone(zone).point , 4)  
        end
    end
    timer.scheduleFunction(ROAR.smoke, {}, timer.getTime() + 280)
end
timer.scheduleFunction(ROAR.smoke, {}, timer.getTime() + 5)

--trigger.action.setUserFlag('SSB', 100) --set up slot blocking





local function tableHasKey(table,key)
	if table then
	  return table[key] ~= nil
	else 
	  env.warning("table parameter not provided")
	  return nil
	end
end

function ROAR.raceEndCountdown(secs)
	trigger.action.setUserFlag('race_end_countdown', 1)
	
	if secs then
		ROAR.grace_time = secs
	end

	env.warning("ROAR: Race will end in ".. ROAR.grace_time .. " seconds")

	local function countdown()
		local minutes = math.floor(ROAR.grace_time / 60)
		local seconds = ROAR.grace_time - (minutes * 60) --handle as string
		if seconds < 10 then
			seconds = "0" .. seconds
		end
		if ROAR.grace_time <= 30 then
			trigger.action.outText("Race will end in "..minutes..":"..seconds, 2, true)
		end
		ROAR.grace_time = ROAR.grace_time - 1
		if ROAR.grace_time <= 0 then
			trigger.action.setUserFlag('race_ended', 1) --use this flag to end the mission in the mission editor
		else
			timer.scheduleFunction(countdown, {}, timer.getTime() + 1)
		end
	end
	countdown()
end

function ROAR.loop() 

	local display_leader = false

	for index, _unit_name in pairs(ROAR.player_unit_names) do
		unit = Unit.getByName(_unit_name)
		if unit then
			local next_gate = ROAR.player_data[_unit_name].gate + 1
			local next_gate_name = 'GATE-' .. next_gate
			local unit_table = mist.getUnitsInZones(mist.makeUnitTable({'[all]'}), {next_gate_name})

			for index, u in pairs(unit_table) do
				if u:getID() == unit:getID() then
					trigger.action.setUserFlag(_unit_name, next_gate)
					trigger.action.outSoundForGroup(unit:getGroup():getID(), 'ding.ogg')
					trigger.action.outTextForUnit(unit:getID() , "You passed gate " .. next_gate .. " of " .. #ROAR.zone_gates , 5 , false)
					if next_gate > ROAR.first_place.gate then  --find who's in first
						local player_name = _unit_name
						if u:getPlayerName() then
							player_name = u:getPlayerName()
						end
						ROAR.first_place = {name=player_name, gate=next_gate}
						display_leader = true
					end
				end
			end

			local player_flag = trigger.misc.getUserFlag(_unit_name)
			if player_flag > ROAR.player_data[_unit_name].gate then
				
			end
			ROAR.player_data[_unit_name].gate = player_flag
			local gate_flag = _unit_name..'-'..player_flag  --ie P1-3 means player 1 activated gate 3
			trigger.action.setUserFlag(gate_flag, 1)
			
			if player_flag == #ROAR.zone_gates then  --if a player has activated the last gate
				local finished = true
				for i = 1, #ROAR.zone_gates do
					if trigger.misc.getUserFlag(_unit_name..'-'..i) == 0 then
						finished = false
					end
				end
				if finished and not ROAR.player_data[_unit_name].finished then
					ROAR.player_data[_unit_name].finished = true
					local finish_seconds = timer.getTime() - ROAR.start_time
					local place = #ROAR.standings + 1
					local minutes = math.floor(finish_seconds / 60)
					local seconds = finish_seconds - (minutes * 60) --handle as string
					if seconds < 10 then
						seconds = "0" .. seconds
					end
					local _finish_time_string = minutes..':'..seconds
					ROAR.standings[place] = {unit_name=_unit_name, finish_time=finish_seconds, finish_time_string=_finish_time_string}
					
					local player_name = _unit_name
					if unit:getPlayerName() then
						player_name = unit:getPlayerName()
					end
					trigger.action.outText('#'.. place .. "  " .. player_name .. " FINISHED!   ".._finish_time_string, 600, false)
					env.info("ROAR: ".. player_name .. " FINISHED!   ".._finish_time_string)
					
					if place == 1 then
                        trigger.action.outSound('winner.ogg')
						ROAR.raceEndCountdown()
					end
					
				end
			end
			
		end
	end

	if #ROAR.standings == 0 and ROAR.first_place.name and display_leader then
		trigger.action.outText(ROAR.first_place.name .. " is in the lead!   Gate " .. ROAR.first_place.gate .. " of " .. #ROAR.zone_gates, 5, false)
	end
		
	
	local id = timer.scheduleFunction(ROAR.loop, 1, timer.getTime() + 0.1)
end


function ROAR.endRace()
	ROAR.raceEndCountdown(20)
	env.info("ROAR: race end requested")
end

function ROAR.delayRace()
	ROAR.start_countdown = 30
	env.info("ROAR: race start delayed")
    trigger.action.outSound('standby.ogg')
end

function ROAR.startRace()

	trigger.action.setUserFlag('race_start_countdown', next_gate)
	missionCommands.removeItem(commandDB['start_race'])
	commandDB['delay_race'] = missionCommands.addCommand( "Delay race start"  , nil , ROAR.delayRace)
    trigger.action.outSound('race_starting.ogg')

	for zone, zoneobj in pairs(mist.DBs.zonesByName) do 
		if string.find(zone, "GATE-") then
			ROAR.zone_gates[#ROAR.zone_gates + 1] = zone
		end
	end

	local function countdown()
		local minutes = math.floor(ROAR.start_countdown / 60)
		local seconds = ROAR.start_countdown - (minutes * 60) --handle as string
		if seconds < 10 then
			seconds = "0" .. seconds
		end
		trigger.action.outText("RACE WILL START IN "..minutes..":"..seconds .. "   STAY ON THE GROUND!!", 2, true)
		ROAR.start_countdown = ROAR.start_countdown - 1
		if ROAR.start_countdown <= 0 then
			commandDB['end_race'] = missionCommands.addCommand( "End Race for all players"  , nil , ROAR.endRace)
			missionCommands.removeItem(commandDB['delay_race'])
            trigger.action.outSound('lets_go.ogg')
			trigger.action.outText("LET'S GO!!!!!", 10, true)
			trigger.action.setUserFlag('ALL_PLAYERS', 100) --slot block all in group
			trigger.action.setUserFlag('race_started', 1)
			start_time = timer.getTime()
			ROAR.loop()
		else
			timer.scheduleFunction(countdown, {}, timer.getTime() + 1)
		end
	end
	countdown()

end


commandDB = {}
commandDB['start_race'] = missionCommands.addCommand( "Start Race Countdown"  , nil , ROAR.startRace)
