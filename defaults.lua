local addon, BB = ...

BB.default_db = {
  guid = UnitGUID("player"),  -- character unique identifier

  total_xp = 0,               -- total XP gained
  cum_xp = 0,                 -- total XP gained until end of previous level
  curr_max_xp = 0,            -- maximum XP for the current level
  mob_xp = 0,                 -- XP gained from killing mobs
  zone_xp = 0,                -- XP gained from discovering new zones
  quest_xp = 0,               -- XP gained from quests
  quests = 0,                 -- number of quests completed

  total_kills = 0,            -- total mobs killed (incl. no XP)
  xp_kills = 0,               -- mobs killed with XP gain
  xp_kills_per_lvl = {},      -- mobs killed with XP gain at each level

  last_n_mobs_xp = {},        -- individual XP gains from the last n mobs
  last_n_lvl_diffs = {},      -- difference with level of the last n mobs
  last_n_kill_times = {},     -- individual kill times from the last n mobs

  total_combat_time = 0,      -- total time spent in combat (excl. fleeing)
  prev_lvl_combat_time = 0,   -- time spent in combat during previous level
  combat_time_per_lvl = {},   -- time spent in combat at each level

  total_time = 0,             -- total time played (updated only with /played)
  prev_lvl_time = 0,          -- time played in previous level
  time_per_lvl = {},          -- time played at each level
}

BB.default_config = {
  log_limit = 30,             -- number of last fights to log (XP + duration)

  show_kc = true,             -- kill counter settings
  kc_width = 256,
  kc_height = 32,
  kc_offset_x = 630,
  kc_offset_y = 600,
  kc_color_r = 0.3,
  kc_color_g = 0.1,
  kc_color_b = 0.1,
  kc_color_a = 0.6,
  kc_font = "FRIZQT__.ttf",
  kc_fontsize = 20,
}
