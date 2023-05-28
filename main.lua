local addon, BB = ...

local combat_start_t = 0
local mob_lvl = 0
local xp_gained = false

local function print_welcome_msg()
  local msg = "loaded. Happy hunting!\nType /bbc for help"
  BB.print_addon_msg(msg)
end

local function print_bb_failure_msg()
  local msg = "Bloodbath challenge failed!\n" ..
              "You have completed at least one quest. " ..
              "Consider making a new character!"
  BB.print_addon_msg(msg)
  PlaySound(8594)  -- A_OssirianIHaveFailed
end

-- Load variables and kill counter
BB.register("ADDON_LOADED",
  function(event, ...)
    if ... == addon then

      -- Load character database
      bbc_char_db = bbc_char_db or BB.default_db

      if UnitGUID("player") ~= bbc_char_db.guid then  -- new character
        bbc_char_db = BB.default_db
      end

      BB.db = bbc_char_db

      for k,v in pairs(BB.default_db) do  -- check missing keys
        if BB.db[k] == nil then BB.db[k] = v end
      end

      -- Load user config
      bbc_user_config = bbc_user_config or BB.default_config
      BB.config = bbc_user_config

      for k,v in pairs(BB.default_config) do  -- check missing keys
        if BB.config[k] == nil then BB.config[k] = v end
      end

      -- Initialize kill counter based on user config
      BB.kc:initialize()  -- from frames.lua

      BB.wait(4,
        function()
          -- Check for completed quests and warn player
          if BB.db.quests > 0 then
            print_bb_failure_msg()
          end
          -- Set max XP for current level (necessary at level 1)
          BB.db.curr_max_xp = UnitXPMax("player")
        end
      )
      print_welcome_msg()
    end
    BB.unregister("ADDON_LOADED")
  end
)

-- Start timer when combat is initiated
BB.register("PLAYER_REGEN_DISABLED",
  function()
    combat_start_t = time()  -- Unix time at which last fight was initiated
  end
)

-- Save combat time after combat is terminated (fleeing doesn't count)
BB.register("PLAYER_LEAVE_COMBAT",
  function()
    if xp_gained then  -- prevents from firing when just changing targets
      xp_gained = false

      local elapsed = time() - combat_start_t
      combat_start_t = time()  -- reset to handle multiple mobs in same fight

      -- Save kill time
      if table.getn(BB.db.last_n_kill_times) >= BB.config.log_limit then
        table.remove(BB.db.last_n_kill_times)
      end

      table.insert(BB.db.last_n_kill_times, 1, elapsed)

      -- Update total combat time
      BB.db.total_combat_time = BB.db.total_combat_time + elapsed
    end
  end
)

-- Update character database when XP is gained from mob or quest
BB.register("CHAT_MSG_COMBAT_XP_GAIN",
  function(event, ...)
    local msg = select(1, ...)
    local xp_gain = msg:match("%d+%s?%a+%."):match("%d+")
    local pattern = COMBATLOG_XPGAIN_FIRSTPERSON:gsub("%%s", "%%a+")
    pattern = pattern:gsub("%%d", "%%d+")
    xp_gained = true

    if string.match(msg, pattern) then  -- a mob has been killed
      BB.db.mob_xp = BB.db.mob_xp + xp_gain
      BB.db.xp_kills = BB.db.xp_kills + 1
      BB.kc:update_kills()  -- from frames.lua

      -- Update number of kills at current level
      local lvl = UnitLevel("player")

      if BB.db.xp_kills_per_lvl[lvl] == nil then
        BB.db.xp_kills_per_lvl[lvl] = 1
      else
        BB.db.xp_kills_per_lvl[lvl] = BB.db.xp_kills_per_lvl[lvl] + 1
      end

      -- Save XP gain
      if table.getn(BB.db.last_n_mobs_xp) >= BB.config.log_limit then
        table.remove(BB.db.last_n_mobs_xp)
      end

      table.insert(BB.db.last_n_mobs_xp, 1, xp_gain)

      -- Save difference with mob level (from COMBAT_LOG_EVENT_UNFILTERED)
      local lvl_diff = 0
      if mob_lvl ~= -1 then lvl_diff = mob_lvl - lvl end

      if table.getn(BB.db.last_n_lvl_diffs) >= BB.config.log_limit then
        table.remove(BB.db.last_n_lvl_diffs)
      end

      table.insert(BB.db.last_n_lvl_diffs, 1, lvl_diff)

    else  -- a quest has been completed
      BB.db.quests = BB.db.quests + 1
      BB.db.quest_xp = BB.db.quest_xp + xp_gain
      BB.wait(1, print_bb_failure_msg)
    end

    -- Update total XP
    BB.db.total_xp = BB.db.total_xp + xp_gain
  end
)

-- Log any kill regardless of XP (+ capture mob level)
BB.register("COMBAT_LOG_EVENT_UNFILTERED",
  function()
    local _, subevent, _, src_guid = CombatLogGetCurrentEventInfo()
    local overkill = -1

    if src_guid == BB.db.guid then
      --[[
      Attempt to capture mob level to compute level difference later
      when CHAT_MSG_COMBAT_XP_GAIN is fired
      This is not always reliable, as the current target might be different
      than the mob killed, but capturing mob level in CHAT_MSG_COMBAT_XP_GAIN
      is even more unreliable
      --]]
      if subevent:match("^SPE.*DAMAGE$") or subevent:match("^RAN.*DAMAGE$") then
        overkill = select(16, CombatLogGetCurrentEventInfo())
        if overkill >= 0 then
          mob_lvl = UnitLevel("target")
        end
      elseif subevent == "SWING_DAMAGE" then
        overkill = select(13, CombatLogGetCurrentEventInfo())
        if overkill >= 0 then
          mob_lvl = UnitLevel("target")
        end
      -- Log any kill regardless of XP
      elseif subevent == "PARTY_KILL" then
        BB.db.total_kills = BB.db.total_kills + 1
      end
    end
  end
)

-- Update XP when discovering a new zone
BB.register("ZONE_CHANGED",
  function()  -- Delay by 5 seconds so UnitXP can return the correct value
    BB.wait(5,
      function()
        local actual_total_xp = BB.db.cum_xp + UnitXP("player")
        local xp_diff = actual_total_xp - BB.db.total_xp
        if xp_diff > 0 then
          BB.db.total_xp = actual_total_xp
          BB.db.zone_xp = BB.db.zone_xp + xp_diff
        end
      end
    )
  end
)

-- Update data for previous level after leveling up
BB.register("PLAYER_LEVEL_UP",
  function()
    -- Fire TIME_PLAYED_MSG to update total time played
    RequestTimePlayed()

    -- Wait otherwise UnitLevel/UnitXPMax get values from previous level
    BB.wait(3,
      function()
        BB.db.cum_xp = BB.db.cum_xp + BB.db.curr_max_xp
        BB.db.curr_max_xp = UnitXPMax("player")
        local prev_lvl = UnitLevel("player") - 1

        -- Save combat time for previous level
        BB.db.prev_lvl_combat_time = BB.db.total_combat_time - BB.db.prev_lvl_combat_time
        BB.db.combat_time_per_lvl[prev_lvl] = BB.db.prev_lvl_combat_time

        -- Save total time for previous level
        BB.db.prev_lvl_time = BB.db.total_time - BB.db.prev_lvl_time
        BB.db.time_per_lvl[prev_lvl] = BB.db.prev_lvl_time

        -- Report about /played time and time spent in combat
        local combat_t_pct = BB.db.total_combat_time / BB.db.total_time * 100
        local prev_lvl_combat_t_pct = BB.db.combat_time_per_lvl[prev_lvl] / BB.db.time_per_lvl[prev_lvl] * 100

        BB.print_addon_msg("Congrats!")
        print(
          "Time spent in previous level: " ..
          BB.highlight(BB.display_t(BB.db.prev_lvl_time))
        )
        print(
          "So far, you have spent " ..
          BB.highlight(string.format("%.1f", combat_t_pct)) ..
          "% of your time in combat! (" ..
          BB.highlight(string.format("%.1f", prev_lvl_combat_t_pct)) ..
          "% in previous level)"
        )
      end
    )
  end
)

BB.register("TIME_PLAYED_MSG",
  function(event, ...)
    local total_played = select(1, ...)
    BB.db.total_time = total_played
  end
)
