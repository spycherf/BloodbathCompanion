local addon, BB = ...

-- Kill counter frame
BB.kc = CreateFrame("Frame", nil, UIParent)

function BB.kc:initialize()

  -- Position and size
  self:SetFrameStrata("MEDIUM")
  self:SetWidth(BB.config.kc_width)
  self:SetHeight(BB.config.kc_height)
  self:SetPoint(
    "TOPLEFT",
    UIParent,
    "BOTTOMLEFT",
    BB.config.kc_offset_x,
    BB.config.kc_offset_y
  )
  -- Textures
  self.t = self:CreateTexture("ARTWORK")
  self.t:SetColorTexture(
    BB.config.kc_color_r,
    BB.config.kc_color_g,
    BB.config.kc_color_b,
    BB.config.kc_color_a
  )
  self.t:SetAllPoints()

  -- Text
  self.text = self:CreateFontString(nil, "ARTWORK")
  self.text:SetPoint("CENTER", 0, 0)
  self.text:SetFont(
    "Fonts\\" .. BB.config.kc_font,
    BB.config.kc_fontsize,
    "OUTLINE"
  )

  -- Drag & drop (Ctrl + left click)
  self:SetMovable(true)
  self:EnableMouse(true)
  self:RegisterForDrag("LeftButton")
  self:SetScript("OnDragStart",
    function()
      if IsControlKeyDown() then self:StartMoving() end
    end
  )
  self:SetScript("OnDragStop",
    function()
      self:StopMovingOrSizing()
      BB.config.kc_offset_x = floor(self:GetLeft() + 0.5)
      BB.config.kc_offset_y = floor(self:GetTop() + 0.5)
    end
  )

  -- Display stats (right click)
  self:SetScript("OnMouseDown",
    function (self, button)
      if button == "RightButton" then
        DEFAULT_CHAT_FRAME.editBox:SetText("/bbc stats")
        ChatEdit_SendText(DEFAULT_CHAT_FRAME.editBox, 0)
      end
    end
  )

  -- Tooltip (mouseover)
  self:SetScript("OnEnter",
    function(self, motion)
      GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
      GameTooltip:SetText(
        "Ctrl + Left click to move\n" ..
        "Right click to show stats"
      )
    end
  )
  self:SetScript("OnLeave",
    function(self, motion)
      GameTooltip:Hide()
    end
  )

  if BB.config.show_kc then
    self:update_kills()
    self:Show()
  else
    self:Hide()
  end
end

function BB.kc:update_kills()
  self.text:SetText("Kills: " .. BB.db.xp_kills)
end

function BB.kc:toggle()
  if BB.config.show_kc then
    BB.config.show_kc = false
    self:Hide()
  else
    BB.config.show_kc = true
    self:update_kills()
    self:Show()
  end
end

function BB.kc:set_color(r, g, b, a)
  BB.config.kc_color_r = r
  BB.config.kc_color_g = g
  BB.config.kc_color_b = b
  BB.config.kc_color_a = a

  self.t:SetColorTexture(r, g, b, a)
  self.t:SetAllPoints()
end

function BB.kc:reset_position()
  BB.config.kc_offset_x = BB.default_config.kc_offset_x
  BB.config.kc_offset_y = BB.default_config.kc_offset_y
  self:ClearAllPoints()
  self:SetPoint(
    "TOPLEFT",
    UIParent,
    "BOTTOMLEFT",
    BB.config.kc_offset_x,
    BB.config.kc_offset_y
  )
end

function BB.kc:reset_color()
  BB.config.kc_color_r = BB.default_config.kc_color_r
  BB.config.kc_color_g = BB.default_config.kc_color_g
  BB.config.kc_color_b = BB.default_config.kc_color_b
  BB.config.kc_color_a = BB.default_config.kc_color_a
  self.t:SetColorTexture(
    BB.config.kc_color_r,
    BB.config.kc_color_g,
    BB.config.kc_color_b,
    BB.config.kc_color_a
  )
  self.t:SetAllPoints()
end

function BB.kc:reset_defaults()
  self:reset_position()
  self:reset_color()
end
