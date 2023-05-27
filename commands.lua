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
        intro = string.format("level %d: ", i)
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

-- Command: toggle and customize kill counter (/bbc kills, /bbc kc)
local function customize_kc(args)

  -- Show/hide the kill counter
  if args:match("kills?$") or args:match("kc$") then
    local state = ""

    if BB.config.show_kc then
      state = "on"
    else
      state = "off"
    end

    BB.kc:toggle()
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

      if table.getn(colors) == 4 then
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
      BB.print_addon_msg("Kill counter reset to default")
    end
  else
    BB.print_addon_msg("Invalid command")
  end
end

-- Command: show statistics (/bbc stats, /bbc s)
local function show_stats()
  local n = BB.config.log_limit
  local current_sample_size = math.min(
    table.getn(BB.db.last_n_mobs_xp),
    table.getn(BB.db.last_n_kill_times)
  )
  if current_sample_size == 0 then
    BB.print_addon_msg("Requires sample size of at least 1")
  else
    -- Determine appropriate sample size
    if current_sample_size < n then n = current_sample_size end

    -- Compute and report averages
    local xp = 0
    local combat_t = 0

    for i=1,n do
      xp = xp + BB.db.last_n_mobs_xp[i]
      combat_t = combat_t + BB.db.last_n_kill_times[i]
    end

    local avg_xp = xp / n
    local avg_combat_t = combat_t / n
    local mobs_per_min = n / combat_t * 60

    local xp_to_ding = UnitXPMax("player") - UnitXP("player")
    local mobs_to_ding = xp_to_ding / avg_xp
    local combat_t_to_ding = mobs_to_ding * avg_combat_t

    BB.print_addon_msg("Stats and predictions")

    print(string.format("Based on the last %d mobs:", n))
    print(
      "- Avg. mob per minute (in combat) =",
      BB.highlight(string.format("%.1f", mobs_per_min))
    )
    print(
      "- Avg. mob XP gain =",
      BB.highlight(string.format("%.2f", avg_xp))
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
    local lvl = UnitLevel("player")

    if lvl > 1 then
      local cum_combat_t = 0
      local cum_t = 0

      for i=1,lvl-1 do
        cum_combat_t = cum_combat_t + BB.db.combat_time_per_lvl[i]
        cum_t = cum_t + BB.db.time_per_lvl[i]
      end

      local cum_combat_t_pct = cum_combat_t / cum_t * 100
      local t_to_ding = 100 * combat_t_to_ding / cum_combat_t_pct

      print("- Est. total time =", BB.highlight(BB.display_t(t_to_ding)))
      print(
        string.format(
          "(Up to level %d, %.1f%% " ..
          "of total time was spent in combat)",
          lvl,
          cum_combat_t / cum_t * 100
        )
      )
    end
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
    string.format("based on the last %d mobs, ", BB.config.log_limit) ..
    "then estimates the number of mobs to kill and " ..
    "combat + total time to reach the next level.\n" ..
    "Can also be shown by right clicking the kill counter."
  )

  -- see show_db()
  print(
    "- " .. BB.highlight("print") .. " or " ..
    BB.highlight("pp [lvls_per_row]")
  )
  print(
    "  Displays the most relevant data from the character's database " ..
    "(for full data, use /dump bbc_char_db instead)."
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
  elseif args:match("^print") or args:match("^pp") then
    show_db(args)
  else
    show_help()
  end
end

SLASH_BLOODBATHCOMPANION1, SLASH_BLOODBATHCOMPANION2 = "/bloodbath", "/bbc"
SlashCmdList["BLOODBATHCOMPANION"] = slash_command_handler
