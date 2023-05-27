local addon, BB = ...

local f = CreateFrame("Frame")
local handlers = {}

f:SetScript("OnEvent",
  function(self, event, ...)
    local event_handlers = handlers[event] or {}
    for i, handler in ipairs(event_handlers) do
      handler(event, ...)
    end
  end
)

function BB.register(event, handler)
  handlers[event] = handlers[event] or {}
  table.insert(handlers[event], handler)
  f:RegisterEvent(event)
end

function BB.unregister(event, handler)
  handlers[event] = handlers[event] or {}
  table.remove(handlers[event], handler)
  f:UnregisterEvent(event)
end
