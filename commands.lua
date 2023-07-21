local addon, BB = ...

local function summarize_table_by_lvl(var, range)
  local msg = "   "
  local sum = 0
  local lvl = UnitLevel("player")
  local t_series = false

  if var == BB.db.time_per_lvl or var == BB.db.combat_time_per_lvl then
    t_series = true
  end

  for i=1,lvl-1 do
    sum = sum + var[i]

    if i % range == 1 or range == 1 then
      local intro = ""

      if range ~= 1 and i < lvl - 1 then
        local upper_bound = i + range - 1
        if i + range > lvl then upper_bound = lvl - 1 end
        intro = string.format("Level %d-%d: ", i, math.min(upper_bound, 60))
        msg = msg .. intro .. string.rep(" ", 13 - string.len(intro))
      else
        intro = string.format("Level %d: ", i)
        msg = msg .. intro .. string.rep(" ", 15 - string.len(intro))
      end
    end

    if (i % range == 0 or i == lvl - 1) and i ~= lvl then
      if t_series then sum = BB.display_t(sum) end
      msg = msg .. BB.highlight(sum) .. "\n"
      sum = 0
    end
  end
  print(msg)
end

local function get_table_size(t)
  local count = 0
  for k,v in pairs(t) do
    count = count + 1
  end
  return count
end

-- Command: toggle and customize kill counter (/bbc kills, /bbc kc)
local function customize_kc(args)

  -- Show/hide the kill counter
  if args:match("kills?$") or args:match("kc$") then
    BB.kc:toggle()
    local state = ""

    if BB.config.show_kc then
      state = "on"
    else
      state = "off"
    end

    BB.print_addon_msg("Kill counter " .. state)

  -- Change color
  elseif args:match("%d") then
    local colors = {}
    local pattern = "%d%.?%d*,?%s?"
    local m = args:match(pattern:rep(4))

    if m then
      for v in m:gmatch(pattern) do
        v = v:gsub(",", ""):gsub("%s", "")
        table.insert(colors, tonumber(v))
      end

      if #colors == 4 then
        local r, g, b, a = unpack(colors)

        if r <= 1 and g <= 1 and b <= 1 and a <= 1 then
          BB.kc:set_color(r, g, b, a)
        else
          BB.print_addon_msg("Values must be between 0 and 1")
        end
      else
        BB.print_addon_msg("4 values required (RGBA)")
      end
    else
      BB.print_addon_msg("RGBA values not recognized (4 required)")
    end

  -- Reset position and color
  elseif args:match("def") or args:match("res") then
    if args:match("pos") then
      BB.kc:reset_position()
      BB.print_addon_msg("Kill counter position to default")
    elseif args:match("col") then
      BB.kc:reset_color()
      BB.print_addon_msg("Kill counter color to default")
    else
      BB.kc:reset_defaults()
      BB.print_addon_msg("Kill counter reset to default settings")
    end
  else
    BB.print_addon_msg("Invalid command")
  end
end

-- Command: show statistics (/bbc stats, /bbc s)
local function show_stats()
  local n = BB.config.log_limit
  local current_sample_size = math.min(
    #BB.db.last_n_mobs_xp,
    #BB.db.last_n_lvl_diffs,
    #BB.db.last_n_kill_times
  )
  if current_sample_size == 0 then
    BB.print_addon_msg("Requires sample size of at least 1")
  else
    -- Determine appropriate sample size
    if current_sample_size < n then n = current_sample_size end

    -- Compute and report averages
    local xp = 0
    local lvl_diff = 0
    local combat_t = 0

    for i=1,n do
      xp = xp + BB.db.last_n_mobs_xp[i]
      lvl_diff = lvl_diff + BB.db.last_n_lvl_diffs[i]
      combat_t = combat_t + BB.db.last_n_kill_times[i]
    end

    local mobs_per_min = n / combat_t * 60
    local avg_xp = xp / n
    local avg_lvl_diff = lvl_diff / n
    local avg_combat_t = combat_t / n

    local xp_to_ding = UnitXPMax("player") - UnitXP("player")
    local mobs_to_ding = xp_to_ding / avg_xp
    local combat_t_to_ding = mobs_to_ding * avg_combat_t

    BB.print_addon_msg("Stats and predictions")

    print(string.format("Based on the last %d mobs:", n))
    print(
      "- Avg. mobs per minute (in combat) =",
      BB.highlight(string.format("%.1f", mobs_per_min))
    )
    print(
      "- Avg. mob XP gain =",
      BB.highlight(string.format("%.2f", avg_xp))
    )
    print(
      "- Avg. level difference =",
      BB.highlight(string.format("%.2f", avg_lvl_diff))
    )
    print(
      "- Avg. fight duration (s) =",
      BB.highlight(string.format("%.2f", avg_combat_t))
    )

    print("To reach next level:")
    print("- XP required =", BB.highlight(xp_to_ding))
    print("- Est. mobs to kill =", BB.highlight(math.ceil(mobs_to_ding)))
    print("- Est. combat time =", BB.highlight(BB.display_t(combat_t_to_ding)))

    -- Give info about combat time to played time ratio
    local cum_combat_t = 0
    local cum_t = 0

    if get_table_size(BB.db.combat_time_per_lvl) > 0 then
      for k,v in pairs(BB.db.combat_time_per_lvl) do
        cum_combat_t = cum_combat_t + v
        cum_t = cum_t + BB.db.time_per_lvl[k]
      end

      local cum_combat_t_pct = cum_combat_t / cum_t * 100
      local t_to_ding = 100 * combat_t_to_ding / cum_combat_t_pct

      print("- Est. total time =", BB.highlight(BB.display_t(t_to_ding)))
      print(
        string.format(
          "(Up to level %d, %.1f%% " ..
          "of total time was spent in combat)",
          UnitLevel("player"),
          cum_combat_t / cum_t * 100
        )
      )
    end
  end
end

-- Command: change fight log size (/bbc log)
local function set_log_limit(args)
  local n = args:match("%d+")

  if n then
    n = tonumber(n)
    if n <= 300 and n > 0 then
      BB.config.log_limit = n
      BB.print_addon_msg("Fight log size set to " .. BB.highlight(n))
    else
      BB.print_addon_msg("Enter a number between 1 and 300")
    end
  else
    n = BB.default_config.log_limit
    BB.config.log_limit = n
    BB.print_addon_msg("Fight log size reset to " .. n)
  end
end

-- Command: print some variables from character database (/bbc print, /bbc pp)
local function show_db(args)
  local lvls_per_row = tonumber(args:match("%d+")) or 10

  BB.print_addon_msg("Character data")

  print("Total XP gained: " .. BB.highlight(BB.db.total_xp))
  print("- from mobs: " .. BB.highlight(BB.db.mob_xp))
  print("- from new zones: " .. BB.highlight(BB.db.zone_xp))

  local color = "green"
  if BB.db.quests > 0 then color = "red" end
  print(
    string.format(
      "- from quests (%s): %s",
      BB.highlight(BB.db.quests, color),
      BB.highlight(BB.db.quest_xp, color)
    )
  )
  print("Total mobs killed: " .. BB.highlight(BB.db.total_kills))
  print("- with XP gain: " .. BB.highlight(BB.db.xp_kills))
  summarize_table_by_lvl(BB.db.xp_kills_per_lvl, lvls_per_row)

  print("Time played:")
  summarize_table_by_lvl(BB.db.time_per_lvl, lvls_per_row)

  print("- In combat:")
  summarize_table_by_lvl(BB.db.combat_time_per_lvl, lvls_per_row)
end

-- Default command: show help (/bloodbath, /bbc)
local function show_help()
  BB.print_addon_msg("Addon help")

  print(
    "Command usage: " ..
    BB.highlight("/bbc [arg1] [arg2] ... ") .. "([ ] = optional)"
  )

  print("Available arguments:")

  -- see customize_kc()
  print(
    "- " .. BB.highlight("kills") .. " or " ..
    BB.highlight("kc [r,g,b,a | reset [pos | color]]")
  )
  print(
    "  Toggles kill counter frame on/off (Ctrl + left click to move).\n" ..
    "The kill counter displays the number of mobs killed " ..
    "(only those where XP was gained)"
  )
  print(
    "  Color can be changed by giving RGBA values " ..
    "between 0.0 and 1.0 (e.g., /bbc kc 0.8,0.5,1,0.4)."
  )
  print(
    "  \"reset\" resets the kill counter to its default display settings. " ..
    "If \"pos\" or \"color\" is specified, " ..
    "resets only position or color respectively."
  )

  -- see show_stats()
  print("- " .. BB.highlight("stats") .. " or " .. BB.highlight("s"))
  print(
    "  Displays average mob XP gain + average fight duration " ..
    string.format(
      "based on the last %d mobs (can be changed with /bbc log), ",
      BB.config.log_limit
    ) ..
    "then estimates the number of mobs to kill and " ..
    "combat + total time to reach the next level.\n" ..
    "Can also be shown by right clicking the kill counter."
  )

  -- see set_log_limit()
  print("- " .. BB.highlight("log [size]"))
  print(
    "  Changes the number of last fights logged in the database, " ..
    "which is used by /bbc stats to compute averages " ..
    "(minimum = 1, maximum = 300).\n" ..
    string.format(
      "If no number specified, reverts to default value (%d).",
      BB.default_config.log_limit
    )
  )

  -- see show_db()
  print(
    "- " .. BB.highlight("print") .. " or " ..
    BB.highlight("pp [lvls_per_row]")
  )
  print(
    "  Displays the most relevant data from the character's database " ..
    "(for full data, check BloodbathCompanion.lua file instead)."
  )
  print(
    "  If lvls_per_row is specified (default = 10), " ..
    "creates bins with level range matching that number, " ..
    "and sums values in each bin " ..
    "(e.g., 5 -> summed values for levels 1-5, 6-10, etc.)"
  )
end

local function slash_command_handler(args, editbox)
  if args:match("^k") then
    customize_kc(args)
  elseif args:match("^stat") or args:match("^s$") then
    show_stats()
  elseif args:match("^log") then
    set_log_limit(args)
  elseif args:match("^print") or args:match("^pp") then
    show_db(args)
  else
    show_help()
  end
end

SLASH_BLOODBATHCOMPANION1, SLASH_BLOODBATHCOMPANION2 = "/bloodbath", "/bbc"
SlashCmdList["BLOODBATHCOMPANION"] = slash_command_handler
