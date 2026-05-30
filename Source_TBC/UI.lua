local Backport = Auctionator.Backport

local function ApplyBackdrop(frame)
  if frame == nil or frame.SetBackdrop == nil then
    return
  end

  frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = {
      left = 4,
      right = 4,
      top = 4,
      bottom = 4,
    },
  })
  frame:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
  frame:SetBackdropBorderColor(0.6, 0.5, 0.2, 1)
end

local function CreateLabel(parent, size, text)
  local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  label:SetJustifyH("LEFT")
  label:SetText(text or "")
  local font, _, flags = label:GetFont()
  if font ~= nil then
    label:SetFont(font, size, flags)
  end
  return label
end

local function CreateButton(parent, width, height, text)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetWidth(width)
  button:SetHeight(height)
  button:SetText(text)
  return button
end

local function CreateNumericBox(parent, name, width, maxLetters)
  local box = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
  box:SetAutoFocus(false)
  box:SetWidth(width)
  box:SetHeight(20)
  box:SetNumeric(true)
  box:SetMaxLetters(maxLetters)
  box:SetTextInsets(6, 6, 0, 0)
  box:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  box:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)
  return box
end

local function CreateMoneyEditor(parent, namePrefix)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetWidth(210)
  frame:SetHeight(20)

  frame.gold = CreateNumericBox(frame, namePrefix .. "Gold", 52, 6)
  frame.gold:SetPoint("LEFT", frame, "LEFT", 0, 0)

  frame.goldLabel = CreateLabel(frame, 11, "g")
  frame.goldLabel:SetPoint("LEFT", frame.gold, "RIGHT", 2, 0)

  frame.silver = CreateNumericBox(frame, namePrefix .. "Silver", 36, 2)
  frame.silver:SetPoint("LEFT", frame.goldLabel, "RIGHT", 8, 0)

  frame.silverLabel = CreateLabel(frame, 11, "s")
  frame.silverLabel:SetPoint("LEFT", frame.silver, "RIGHT", 2, 0)

  frame.copper = CreateNumericBox(frame, namePrefix .. "Copper", 36, 2)
  frame.copper:SetPoint("LEFT", frame.silverLabel, "RIGHT", 8, 0)

  frame.copperLabel = CreateLabel(frame, 11, "c")
  frame.copperLabel:SetPoint("LEFT", frame.copper, "RIGHT", 2, 0)

  return frame
end

function Backport:SetMoneyEditorValue(editor, copper)
  if editor == nil then
    return
  end

  copper = math.max(0, math.floor(tonumber(copper) or 0))
  editor.gold:SetText(math.floor(copper / 10000))
  editor.silver:SetText(math.floor(math.mod(copper, 10000) / 100))
  editor.copper:SetText(math.mod(copper, 100))
end

function Backport:GetMoneyEditorValue(editor)
  if editor == nil then
    return 0
  end

  local gold = tonumber(editor.gold:GetText()) or 0
  local silver = tonumber(editor.silver:GetText()) or 0
  local copper = tonumber(editor.copper:GetText()) or 0
  return (gold * 10000) + (silver * 100) + copper
end

function Backport:SetStatus(message)
  if self.statusText ~= nil then
    self.statusText:SetText(message or "")
  end
end

function Backport:UpdateDurationButtons()
  if self.durationButtons == nil then
    return
  end

  for hours, button in pairs(self.durationButtons) do
    if self.selectedDuration == hours then
      button:Disable()
    else
      button:Enable()
    end
  end
end

function Backport:SetDuration(hours)
  self.selectedDuration = hours
  Auctionator.Config.Set("lastDuration", hours)
  self:UpdateDurationButtons()
end

function Backport:TogglePanel(forceShown)
  if self.frame == nil then
    return
  end

  local shouldShow = forceShown
  if shouldShow == nil then
    shouldShow = not self.frame:IsShown()
  end

  self.frame:SetShown(shouldShow)
  Auctionator.Config.Set("panelShown", shouldShow)

  if shouldShow then
    self:SetStatus(Auctionator.Localize("SEARCH_READY"))
  else
    self:SetStatus(Auctionator.Localize("STATUS_PANEL_HIDDEN"))
  end
end

function Backport:UpdateResultsDisplay()
  if self.resultRows == nil then
    return
  end

  for index, row in ipairs(self.resultRows) do
    local result = self.results[index]
    row.result = result
    if result ~= nil then
      local qualityColor = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[result.quality or 1]
      if qualityColor ~= nil then
        row.name:SetText(string.format("|cff%s%s|r x%s", qualityColor.hex, result.name or "?", result.count or 1))
      else
        row.name:SetText(string.format("%s x%s", result.name or "?", result.count or 1))
      end

      local owner = result.owner and result.owner ~= "" and (" - " .. result.owner) or ""
      local buyoutText = result.buyoutPrice and result.buyoutPrice > 0 and self:FormatMoney(result.buyoutPrice) or "-"
      local unitText = result.unitBuyout and result.unitBuyout > 0 and self:FormatMoney(self:Round(result.unitBuyout)) or "-"
      row.price:SetText(string.format("%s / %s%s", unitText, buyoutText, owner))
      row:Show()
    else
      row:Hide()
    end
  end

  local currentPage = 1
  if self.currentQuery ~= nil then
    currentPage = (self.currentQuery.page or 0) + 1
  end
  self.pageText:SetText(string.format(Auctionator.Localize("PAGE_LABEL"), currentPage))

  if self.currentQuery ~= nil and (self.currentQuery.page or 0) > 0 then
    self.prevButton:Enable()
  else
    self.prevButton:Disable()
  end

  local totalAuctions = self.totalAuctions or 0
  local hasNext = false
  if self.currentQuery ~= nil then
    local pageSize = self.PAGE_SIZE
    hasNext = ((self.currentQuery.page + 1) * pageSize) < totalAuctions
  end

  if hasNext then
    self.nextButton:Enable()
  else
    self.nextButton:Disable()
  end
end

function Backport:UpdateSellDisplay()
  if self.sellItemLabel == nil then
    return
  end

  if self.sellItem == nil then
    self.sellItemLabel:SetText(Auctionator.Localize("SELL_NONE"))
    self.sellStackLabel:SetText("")
    self.sellHintLabel:SetText(Auctionator.Localize("SELL_CLICK_HINT"))
    return
  end

  self.sellItemLabel:SetText(self.sellItem.name or "?")
  self.sellStackLabel:SetText(string.format(Auctionator.Localize("STACK"), self.sellItem.count or 1))
  self.sellHintLabel:SetText(Auctionator.Localize("SELL_CLICK_HINT"))
end

function Backport:EnsureUI()
  if self.frame ~= nil then
    return
  end

  if AuctionFrame == nil then
    return
  end

  self.toggleButton = CreateFrame("Button", "AuctionatorToggleButton", AuctionFrame, "UIPanelButtonTemplate")
  self.toggleButton:SetWidth(44)
  self.toggleButton:SetHeight(22)
  self.toggleButton:SetPoint("TOPLEFT", AuctionFrame, "TOPRIGHT", 8, -28)
  self.toggleButton:SetText(Auctionator.Localize("TOGGLE"))
  self.toggleButton:SetScript("OnClick", function()
    Backport:TogglePanel()
  end)

  self.frame = CreateFrame("Frame", "AuctionatorBackportFrame", UIParent)
  self.frame:SetWidth(350)
  self.frame:SetHeight(500)
  self.frame:SetPoint("TOPLEFT", AuctionFrame, "TOPRIGHT", 8, -56)
  self.frame:SetFrameStrata("MEDIUM")
  self.frame:Hide()
  ApplyBackdrop(self.frame)

  self.title = CreateLabel(self.frame, 14, Auctionator.Localize("PANEL_TITLE"))
  self.title:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 14, -14)

  self.closeButton = CreateButton(self.frame, 24, 20, "X")
  self.closeButton:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -10, -10)
  self.closeButton:SetScript("OnClick", function()
    Backport:TogglePanel(false)
  end)

  self.searchHeader = CreateLabel(self.frame, 12, Auctionator.Localize("SEARCH_HEADER"))
  self.searchHeader:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 14, -42)

  self.searchBox = CreateFrame("EditBox", "AuctionatorTBCSearchBox", self.frame, "InputBoxTemplate")
  self.searchBox:SetAutoFocus(false)
  self.searchBox:SetWidth(210)
  self.searchBox:SetHeight(20)
  self.searchBox:SetPoint("TOPLEFT", self.searchHeader, "BOTTOMLEFT", 0, -8)
  self.searchBox:SetTextInsets(6, 6, 0, 0)
  self.searchBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  self.searchBox:SetScript("OnEnterPressed", function(self)
    Backport:StartSearch(self:GetText(), 0, Backport.exactCheckbox:GetChecked(), "search")
    self:ClearFocus()
  end)

  self.searchButton = CreateButton(self.frame, 90, 22, Auctionator.Localize("SEARCH_BUTTON"))
  self.searchButton:SetPoint("LEFT", self.searchBox, "RIGHT", 8, 0)
  self.searchButton:SetScript("OnClick", function()
    Backport:StartSearch(Backport.searchBox:GetText(), 0, Backport.exactCheckbox:GetChecked(), "search")
  end)

  self.exactCheckbox = CreateFrame("CheckButton", "AuctionatorTBCExactCheckbox", self.frame, "UICheckButtonTemplate")
  self.exactCheckbox:SetPoint("TOPLEFT", self.searchBox, "BOTTOMLEFT", -4, -4)
  self.exactCheckbox:SetChecked(Auctionator.Config.Get("exactMatch"))
  getglobal("AuctionatorTBCExactCheckboxText"):SetText(Auctionator.Localize("SEARCH_EXACT"))
  self.exactCheckbox:SetScript("OnClick", function(self)
    Auctionator.Config.Set("exactMatch", self:GetChecked() and true or false)
  end)

  self.statusText = CreateLabel(self.frame, 11, Auctionator.Localize("SEARCH_READY"))
  self.statusText:SetWidth(312)
  self.statusText:SetPoint("TOPLEFT", self.exactCheckbox, "BOTTOMLEFT", 4, -6)

  self.resultsHeader = CreateLabel(self.frame, 12, "Results")
  self.resultsHeader:SetPoint("TOPLEFT", self.statusText, "BOTTOMLEFT", 0, -10)

  self.results = {}
  self.resultRows = {}
  local previousRow = nil
  for index = 1, 8 do
    local row = CreateFrame("Button", nil, self.frame)
    row:SetWidth(318)
    row:SetHeight(30)
    if previousRow == nil then
      row:SetPoint("TOPLEFT", self.resultsHeader, "BOTTOMLEFT", 0, -6)
    else
      row:SetPoint("TOPLEFT", previousRow, "BOTTOMLEFT", 0, -4)
    end
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:SetScript("OnClick", function(self)
      Backport:HandleResultClick(self.result)
    end)
    row:SetScript("OnEnter", function(self)
      if self.result ~= nil and self.result.itemLink ~= nil then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.result.itemLink)
        GameTooltip:Show()
      end
    end)
    row:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    row.name = CreateLabel(row, 11, "")
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -2)
    row.name:SetWidth(312)

    row.price = CreateLabel(row, 10, "")
    row.price:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
    row.price:SetWidth(312)
    row.price:SetTextColor(0.85, 0.82, 0.62)

    row:Hide()
    table.insert(self.resultRows, row)
    previousRow = row
  end

  self.prevButton = CreateButton(self.frame, 60, 22, Auctionator.Localize("PAGE_PREV"))
  self.prevButton:SetPoint("TOPLEFT", previousRow, "BOTTOMLEFT", 0, -8)
  self.prevButton:SetScript("OnClick", function()
    if Backport.currentQuery ~= nil then
      Backport:StartSearch(Backport.currentQuery.term, Backport.currentQuery.page - 1, Backport.currentQuery.exact, Backport.currentQuery.reason)
    end
  end)

  self.pageText = CreateLabel(self.frame, 11, string.format(Auctionator.Localize("PAGE_LABEL"), 1))
  self.pageText:SetPoint("LEFT", self.prevButton, "RIGHT", 12, 0)

  self.nextButton = CreateButton(self.frame, 60, 22, Auctionator.Localize("PAGE_NEXT"))
  self.nextButton:SetPoint("LEFT", self.pageText, "RIGHT", 12, 0)
  self.nextButton:SetScript("OnClick", function()
    if Backport.currentQuery ~= nil then
      Backport:StartSearch(Backport.currentQuery.term, Backport.currentQuery.page + 1, Backport.currentQuery.exact, Backport.currentQuery.reason)
    end
  end)

  self.sellHeader = CreateLabel(self.frame, 12, Auctionator.Localize("SELL_HEADER"))
  self.sellHeader:SetPoint("TOPLEFT", self.prevButton, "BOTTOMLEFT", 0, -18)

  self.sellItemLabel = CreateLabel(self.frame, 11, Auctionator.Localize("SELL_NONE"))
  self.sellItemLabel:SetWidth(250)
  self.sellItemLabel:SetPoint("TOPLEFT", self.sellHeader, "BOTTOMLEFT", 0, -8)

  self.sellStackLabel = CreateLabel(self.frame, 10, "")
  self.sellStackLabel:SetPoint("TOPLEFT", self.sellItemLabel, "BOTTOMLEFT", 0, -4)

  self.sellRefreshButton = CreateButton(self.frame, 70, 22, Auctionator.Localize("SELL_REFRESH"))
  self.sellRefreshButton:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -16, -328)
  self.sellRefreshButton:SetScript("OnClick", function()
    Backport:RefreshSellItem()
  end)

  self.sellScanButton = CreateButton(self.frame, 90, 22, Auctionator.Localize("SELL_SCAN"))
  self.sellScanButton:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -16, -356)
  self.sellScanButton:SetScript("OnClick", function()
    Backport:ScanSellItem()
  end)

  self.sellHintLabel = CreateLabel(self.frame, 10, Auctionator.Localize("SELL_CLICK_HINT"))
  self.sellHintLabel:SetWidth(312)
  self.sellHintLabel:SetPoint("TOPLEFT", self.sellStackLabel, "BOTTOMLEFT", 0, -8)

  self.sellSuggestedLabel = CreateLabel(self.frame, 11, Auctionator.Localize("SELL_SUGGEST"))
  self.sellSuggestedLabel:SetPoint("TOPLEFT", self.sellHintLabel, "BOTTOMLEFT", 0, -10)

  self.sellSuggestedValue = CreateLabel(self.frame, 10, "-")
  self.sellSuggestedValue:SetWidth(312)
  self.sellSuggestedValue:SetPoint("TOPLEFT", self.sellSuggestedLabel, "BOTTOMLEFT", 0, -4)
  self.sellSuggestedValue:SetTextColor(0.85, 0.82, 0.62)

  self.startPriceLabel = CreateLabel(self.frame, 11, Auctionator.Localize("SELL_START"))
  self.startPriceLabel:SetPoint("TOPLEFT", self.sellSuggestedValue, "BOTTOMLEFT", 0, -10)

  self.startPriceEditor = CreateMoneyEditor(self.frame, "AuctionatorTBCStartPrice")
  self.startPriceEditor:SetPoint("TOPLEFT", self.startPriceLabel, "BOTTOMLEFT", 0, -4)

  self.buyoutPriceLabel = CreateLabel(self.frame, 11, Auctionator.Localize("SELL_BUYOUT"))
  self.buyoutPriceLabel:SetPoint("TOPLEFT", self.startPriceEditor, "BOTTOMLEFT", 0, -10)

  self.buyoutPriceEditor = CreateMoneyEditor(self.frame, "AuctionatorTBCBuyoutPrice")
  self.buyoutPriceEditor:SetPoint("TOPLEFT", self.buyoutPriceLabel, "BOTTOMLEFT", 0, -4)

  self.durationLabel = CreateLabel(self.frame, 11, Auctionator.Localize("SELL_DURATION"))
  self.durationLabel:SetPoint("TOPLEFT", self.buyoutPriceEditor, "BOTTOMLEFT", 0, -10)

  self.durationButtons = {}
  local durations = {
    Auctionator.Constants.Durations.Short,
    Auctionator.Constants.Durations.Medium,
    Auctionator.Constants.Durations.Long,
  }
  local previousDuration = nil
  for _, hours in ipairs(durations) do
    local button = CreateButton(self.frame, 52, 22, tostring(hours) .. "h")
    if previousDuration == nil then
      button:SetPoint("TOPLEFT", self.durationLabel, "BOTTOMLEFT", 0, -4)
    else
      button:SetPoint("LEFT", previousDuration, "RIGHT", 8, 0)
    end
    button:SetScript("OnClick", function()
      Backport:SetDuration(hours)
    end)
    self.durationButtons[hours] = button
    previousDuration = button
  end

  self.postButton = CreateButton(self.frame, 120, 24, Auctionator.Localize("SELL_POST"))
  self.postButton:SetPoint("TOPLEFT", previousDuration, "BOTTOMLEFT", -120, -16)
  self.postButton:SetScript("OnClick", function()
    Backport:CreateAuction()
  end)

  self:SetDuration(Auctionator.Config.Get("lastDuration") or Auctionator.Constants.Durations.Medium)
  self:UpdateResultsDisplay()
  self:UpdateSellDisplay()
end
