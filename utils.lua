local addon, BB = ...

-- Print addon name with some formatting
function BB.print_addon_msg(msg)
	print ("|cffbb1337" .. "[" .. addon .. "]|r " .. msg)
end

-- Highlight text for display
function BB.highlight(str, color)
	color = color or "green"

	if color == "green" then
		return "|cff00ff00" .. str .. "|r"
	elseif color == "red" then
		return "|cffff0000" .. str .. "|r"
	end
end

--- Format seconds as hh:mm:ss for display
function BB.display_time(seconds)
	local h = floor(mod(seconds, 86400) / 3600)
	local m = floor(mod(seconds, 3600) / 60)
	local s = floor(mod(seconds, 60))
	return string.format("%02d:%02d:%02d", h, m, s)
end

-- Wait function to delay execution of another function (from WoWWiki)
local wait_table = {}
local wait_frame = nil

function BB.wait(delay, func, ...)
	if type(delay) ~= "number" or type(func) ~= "function" then
		return false
	end

	if wait_frame == nil then
		wait_frame = CreateFrame("Frame", "WaitFrame", UIParent)
		wait_frame:SetScript("onUpdate",
			function (self, elapse)
				local count = #wait_table
				local i = 1

				while i <= count do
					local waitRecord = tremove(wait_table, i)
					local d = tremove(waitRecord, 1)
					local f = tremove(waitRecord, 1)
					local p = tremove(waitRecord, 1)

					if d > elapse then
						tinsert(wait_table, i, {d - elapse, f, p})
						i = i + 1
					else
						count = count - 1
						f(unpack(p))
					end
				end
			end
		)
	end
	tinsert(wait_table, {delay, func, {...}})
	return true
end
