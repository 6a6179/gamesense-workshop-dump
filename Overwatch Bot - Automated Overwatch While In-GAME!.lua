panorama_events = require("gamesense/panorama_events")
panorama_api = panorama.open()
overwatch_api = panorama_api.OverwatchAPI
game_state_api = panorama_api.GameStateAPI

do
	panorama_events = {
		Enable = ui.new_checkbox("MISC", "Miscellaneous", "Overwatch Bot"),
		ForceConvictOptions = ui.new_multiselect("MISC", "Miscellaneous", "Verdict", {
			"Aimbot",
			"Wallhacks",
			"Other",
			"Griefing"
		}),
		DownloadDelay = ui.new_slider("MISC", "Miscellaneous", "Download delay", 5, 300, 5, true, "m"),
		VerdictDelay = ui.new_slider("MISC", "Miscellaneous", "Verdict delay", 5, 300, 35, true, "m"),
		OnlyProcess = ui.new_combobox("MISC", "Miscellaneous", "Only process", {
			"Main-menu",
			"In-game",
			"Both"
		}),
		DownloadRules = ui.new_combobox("MISC", "Miscellaneous", "Only download", {
			"Always",
			"Round End",
			"Self Death",
			"Both"
		}),
		Stats = {}
	}
	panorama_api = database.read("csmit195_OWBot") or {}
	panorama_api.TotalOverwatches = panorama_api.TotalOverwatches or 0
	panorama_events.Stats.Header = ui.new_label("MISC", "Miscellaneous", "Statistics:")
	panorama_events.Stats.CasesCompleted = ui.new_label("MISC", "Miscellaneous", "Cases Completed: " .. panorama_api.TotalOverwatches)
	panorama_events.Stats.CasesAccurate = ui.new_label("MISC", "Miscellaneous", "Cases Accurate: IN_DEV")
	panorama_events.Stats.TotalXP = ui.new_label("MISC", "Miscellaneous", "Total XP Earned: IN_DEV")

	ui.set(panorama_events.ForceConvictOptions, {
		"Aimbot",
		"Wallhacks",
		"Other"
	})

	overwatch_api, game_state_api = nil
	case_retry_delay = 0

	client.set_event_callback("round_end", function ()
		if ui.get(bot_state.DownloadRules) == "Round End" or panorama_events == "Both" then
			bot_config()
		end
	end)
	client.set_event_callback("player_death", function (panorama_events)
		if ui.get(bot_state.DownloadRules) == "Self Death" or panorama_api == "Both" then
			game_state_api = client.userid_to_entindex(panorama_events.attacker)

			if entity.get_local_player() == client.userid_to_entindex(panorama_events.userid) then
				bot_config()
			end
		end
	end)

	last_download_time = globals.realtime()

	client.set_event_callback("post_render", function ()
		if (ui.get(bot_state.DownloadRules) == "Always" or not bot_config.IsConnectedOrConnectingToServer()) and globals.realtime() - case_debounce > 1 then
			game_state_api()

			case_debounce = globals.realtime()
		end
	end)
	case_debounce.register_event("PanoramaComponent_Overwatch_CaseUpdated", function ()
		if bot_state then
			return
		end

		if not ui.get(bot_config.Enable) then
			return
		end

		if case_debounce then
			return
		end

		panorama_api = game_state_api.IsConnectedOrConnectingToServer()

		if ui.get(bot_config.OnlyProcess) ~= "Both" and (panorama_events == "Main-menu" and panorama_api or panorama_events == "In-game" and not panorama_api) then
			bot_state = true

			return client.delay_call(1, process_case_update)
		end

		bot_state = false
		overwatch_api = overwatch_api.GetAssignedCaseDescription()

		if globals.realtime() - last_download_time > ui.get(bot_config.DownloadDelay) * 60 and (overwatch_api:sub(1, 4) == "OWC#" or tonumber(overwatch_api) ~= nil) and overwatch_api.GetEvidencePreparationPercentage() == 0 then
			overwatch_api.StartDownloadingCaseEvidence()

			last_download_time = globals.realtime()

			print("[OVERWATCH BOT] ", "Starting Case Download")
		end

		if tonumber(overwatch_api) ~= nil then
			-- Nothing
		end

		if tonumber(overwatch_api) ~= nil and game_state_api == 100 then
			print("[OVERWATCH BOT] ", "Case: ", overwatch_api, ", Finished Download, Waiting: ", ui.get(bot_config.VerdictDelay))

			case_debounce = true

			client.delay_call(ui.get(bot_config.VerdictDelay) * 60, function ()
				panorama_api = bot_config.IsConnectedOrConnectingToServer()

				if ui.get(bot_state.OnlyProcess) ~= "Both" and (panorama_events == "Main-menu" and panorama_api or panorama_events == "In-game" and not panorama_api) then
					print("[OVERWATCH BOT] not allowed to process, waiting til conditions are sufficient")

					return client.delay_call(5, case_debounce)
				end

				overwatch_api = {
					[verdict_map] = "convict"
				}

				for last_download_time, verdict_map in ipairs(ui.get(bot_state.ForceConvictOptions)) do
					-- Nothing
				end

				game_state_api = string.format("aimbot:%s;wallhack:%s;speedhack:%s;grief:%s;", overwatch_api.Aimbot or "dismiss", overwatch_api.Wallhacks or "dismiss", overwatch_api.Other or "dismiss", overwatch_api.Griefing or "dismiss")

				print("[OVERWATCH BOT] ", "Convicting player for: ", game_state_api)
				game_state_api.SubmitCaseVerdict(game_state_api)
				print("[OVERWATCH BOT] ", "Finished Convicting, waiting for next case")

				process_case_update.TotalOverwatches = process_case_update.TotalOverwatches + 1

				ui.set(bot_state.Stats.CasesCompleted, "Cases Completed: " .. process_case_update.TotalOverwatches)

				overwatch_api = false
			end)
		end

		if overwatch_api == "" and game_state_api == 100 then
			-- Nothing
		end
	end)

	function panorama_events.Toggle(panorama_events)
		panorama_api = type(panorama_events) == "bool" and panorama_events or type(panorama_events) == "number" and ui.get(panorama_events) or panorama_events == nil and ui.get(bot_state.Enable)

		ui.set_visible(bot_state.VerdictDelay, panorama_api)
		ui.set_visible(bot_state.DownloadDelay, panorama_api)
		ui.set_visible(bot_state.ForceConvictOptions, panorama_api)
		ui.set_visible(bot_state.OnlyProcess, panorama_api)
		ui.set_visible(bot_state.DownloadRules, panorama_api)

		for verdict_finished, last_download_time in pairs(bot_state.Stats) do
			ui.set_visible(last_download_time, panorama_api)
		end

		bot_config.Active = panorama_api

		if panorama_api and case_debounce then
			case_debounce()
		end
	end

	ui.set_callback(panorama_events.Enable, panorama_events.Toggle)
	client.delay_call(1, ui.set, panorama_events.Enable, panorama_api.Active)
	panorama_events.Toggle(panorama_api.Active)
	client.set_event_callback("shutdown", function ()
		database.write("csmit195_OWBot", bot_state)
	end)
end
