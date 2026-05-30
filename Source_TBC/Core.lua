local Backport = Auctionator.Backport

Backport.results = Backport.results or {}
Backport.currentQuery = nil
Backport.pendingQuery = nil
Backport.totalAuctions = 0
Backport.lastQueryAt = 0
Backport.selectedDuration = Auctionator.Config.Get("lastDuration") or Auctionator.Constants.Durations.Medium

function Backport:GetSellItemInfo()
  if GetAuctionSellItemInfo == nil then
    return nil
  end

  local name, texture, count, quality, canUse, price = GetAuctionSellItemInfo()
  if name == nil then
    return nil
  end

  local itemLink = nil
  if GetAuctionSellItemLink ~= nil then
    itemLink = GetAuctionSellItemLink()
  end

  return {
    name = name,
    texture = texture,
    count = count or 1,
    quality = quality or 1,
    canUse = canUse,
    vendorPrice = price or 0,
    itemLink = itemLink,
  }
end

function Backport:RefreshSellItem()
  local previousName = self.sellItem and self.sellItem.name or nil
  local previousCount = self.sellItem and self.sellItem.count or nil

  self.sellItem = self:GetSellItemInfo()
  self:UpdateSellDisplay()

  local currentName = self.sellItem and self.sellItem.name or nil
  local currentCount = self.sellItem and self.sellItem.count or nil
  if (previousName ~= currentName or previousCount ~= currentCount) and self.sellSuggestedValue ~= nil then
    self.sellSuggestedValue:SetText("-")
  end
end

function Backport:ApplyResultToSell(result)
  if result == nil or result.buyoutPrice == nil or result.buyoutPrice <= 0 then
    return
  end

  self:RefreshSellItem()
  if self.sellItem == nil then
    self:SetStatus(Auctionator.Localize("SELL_NO_ITEM"))
    return
  end

  local totalBuyout = self:Round(result.unitBuyout * self.sellItem.count)
  local bidPercent = Auctionator.Config.Get("startPricePercent") or 95
  local startPrice = math.max(1, self:Round(totalBuyout * bidPercent / 100))

  self:SetMoneyEditorValue(self.startPriceEditor, startPrice)
  self:SetMoneyEditorValue(self.buyoutPriceEditor, totalBuyout)
  self.sellSuggestedValue:SetText(string.format(Auctionator.Localize("SELL_SCAN_READY"), self:FormatMoney(totalBuyout), self:FormatMoney(self:Round(result.unitBuyout))))
end

function Backport:HandleResultClick(result)
  if result == nil then
    return
  end

  if IsShiftKeyDown() and result.itemLink ~= nil and ChatEdit_InsertLink ~= nil then
    ChatEdit_InsertLink(result.itemLink)
    return
  end

  self:ApplyResultToSell(result)
end

function Backport:StartSearch(term, page, exact, reason)
  term = self:Trim(term)
  if term == "" then
    self:SetStatus(Auctionator.Localize("SEARCH_TERM_EMPTY"))
    return
  end

  if string.len(term) > 63 then
    term = string.sub(term, 1, 63)
  end

  page = math.max(0, tonumber(page) or 0)
  exact = exact and true or false

  self.pendingQuery = {
    term = term,
    page = page,
    exact = exact,
    reason = reason or "search",
  }

  Auctionator.Config.Set("exactMatch", exact)
  self:SetStatus(Auctionator.Localize("SEARCH_WAIT"))
  self:TryStartPendingQuery()
end

function Backport:TryStartPendingQuery()
  if self.pendingQuery == nil or QueryAuctionItems == nil or CanSendAuctionQuery == nil then
    return
  end

  local ready = CanSendAuctionQuery()
  if not ready then
    self:SetStatus(Auctionator.Localize("SEARCH_WAIT"))
    return
  end

  if (GetTime() - (self.lastQueryAt or 0)) < self.QUERY_COOLDOWN then
    return
  end

  local query = self.pendingQuery
  self.pendingQuery = nil
  self.currentQuery = query
  self.lastQueryAt = GetTime()
  self.results = {}
  self.totalAuctions = 0
  self:UpdateResultsDisplay()
  self:RememberSearch(query.term)

  self:SetStatus(string.format(Auctionator.Localize("SEARCH_RUNNING"), query.term, query.page + 1))
  Auctionator.Debug("QueryAuctionItems(" .. query.term .. ", page=" .. query.page .. ")")
  QueryAuctionItems(query.term, nil, nil, 0, 0, 0, query.page, false, 0, false)
end

function Backport:HandleAuctionItemListUpdate()
  if self.currentQuery == nil then
    return
  end

  local batchCount, totalCount = GetNumAuctionItems("list")
  self.totalAuctions = totalCount or batchCount or 0
  self.results = {}

  local cheapest = nil
  for index = 1, (batchCount or 0) do
    local info = { GetAuctionItemInfo("list", index) }
    local name = info[1]
    local count = info[3] or 1
    local quality = info[4] or 1
    local buyoutPrice = info[10] or 0
    local owner = info[13] or ""
    local itemLink = GetAuctionItemLink("list", index)

    if name ~= nil then
      local include = true
      if self.currentQuery.exact then
        include = string.lower(name) == string.lower(self.currentQuery.term)
      end

      if include then
        local result = {
          index = index,
          name = name,
          count = count,
          quality = quality,
          buyoutPrice = buyoutPrice,
          owner = owner,
          itemLink = itemLink,
          unitBuyout = buyoutPrice > 0 and (buyoutPrice / math.max(count, 1)) or 0,
        }

        table.insert(self.results, result)
        if result.buyoutPrice > 0 and (cheapest == nil or result.unitBuyout < cheapest.unitBuyout) then
          cheapest = result
        end
      end
    end
  end

  self:UpdateResultsDisplay()

  if #self.results == 0 then
    self:SetStatus(Auctionator.Localize("SEARCH_NONE"))
  else
    self:SetStatus(string.format(Auctionator.Localize("SEARCH_RESULTS"), #self.results, self.currentQuery.page + 1))
  end

  if cheapest ~= nil then
    self:StorePrice(self.currentQuery.term, cheapest)
  end

  if self.currentQuery.reason == "sell" then
    if cheapest ~= nil then
      self:ApplyResultToSell(cheapest)
    elseif self.sellSuggestedValue ~= nil then
      self.sellSuggestedValue:SetText(Auctionator.Localize("SELL_SCAN_NONE"))
    end
  end
end

function Backport:ScanSellItem()
  self:RefreshSellItem()
  if self.sellItem == nil then
    self:SetStatus(Auctionator.Localize("SELL_NO_ITEM"))
    return
  end

  self:StartSearch(self.sellItem.name, 0, true, "sell")
end

function Backport:CreateAuction()
  self:RefreshSellItem()
  if self.sellItem == nil then
    self:SetStatus(Auctionator.Localize("SELL_NO_ITEM"))
    return
  end

  if StartAuction == nil then
    self:SetStatus("StartAuction unavailable.")
    return
  end

  local startPrice = self:GetMoneyEditorValue(self.startPriceEditor)
  local buyoutPrice = self:GetMoneyEditorValue(self.buyoutPriceEditor)
  if startPrice <= 0 and buyoutPrice > 0 then
    local bidPercent = Auctionator.Config.Get("startPricePercent") or 95
    startPrice = math.max(1, self:Round(buyoutPrice * bidPercent / 100))
    self:SetMoneyEditorValue(self.startPriceEditor, startPrice)
  end

  if startPrice <= 0 then
    self:SetStatus(Auctionator.Localize("SELL_NO_PRICE"))
    return
  end

  if buyoutPrice > 0 and buyoutPrice < startPrice then
    buyoutPrice = startPrice
    self:SetMoneyEditorValue(self.buyoutPriceEditor, buyoutPrice)
  end

  local duration = self.selectedDuration or Auctionator.Constants.Durations.Medium
  StartAuction(startPrice, buyoutPrice, duration, self.sellItem.count or 1, 1)

  self:AddPostingHistory({
    timestamp = time(),
    name = self.sellItem.name,
    count = self.sellItem.count or 1,
    startPrice = startPrice,
    buyoutPrice = buyoutPrice,
    duration = duration,
  })

  local shownPrice = buyoutPrice > 0 and buyoutPrice or startPrice
  self.sellSuggestedValue:SetText(string.format(Auctionator.Localize("SELL_POSTED"), self.sellItem.name, self:FormatMoney(shownPrice)))
  self:SetStatus(string.format(Auctionator.Localize("SELL_POSTED"), self.sellItem.name, self:FormatMoney(shownPrice)))
end

function Backport:OnAuctionHouseShow()
  self:EnsureUI()
  if self.toggleButton ~= nil then
    self.toggleButton:Show()
  end
  if self.frame ~= nil and Auctionator.Config.Get("panelShown") then
    self.frame:Show()
  end

  self:RefreshSellItem()
  self:SetStatus(Auctionator.Localize("SEARCH_READY"))
end

function Backport:OnAuctionHouseClosed()
  if self.frame ~= nil then
    self.frame:Hide()
  end
  if self.toggleButton ~= nil then
    self.toggleButton:Hide()
  end
  GameTooltip:Hide()
end

local eventFrame = CreateFrame("Frame", "AuctionatorTBCEventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
eventFrame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
eventFrame:RegisterEvent("NEW_AUCTION_UPDATE")
eventFrame:RegisterEvent("AUCTION_OWNED_LIST_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" then
    local addonName = ...
    if addonName == "Auctionator" then
      Backport:InitSavedVariables()
    end
  elseif event == "AUCTION_HOUSE_SHOW" then
    Backport:OnAuctionHouseShow()
  elseif event == "AUCTION_HOUSE_CLOSED" then
    Backport:OnAuctionHouseClosed()
  elseif event == "AUCTION_ITEM_LIST_UPDATE" then
    Backport:HandleAuctionItemListUpdate()
  elseif event == "NEW_AUCTION_UPDATE" or event == "AUCTION_OWNED_LIST_UPDATE" then
    Backport:RefreshSellItem()
  end
end)

eventFrame:SetScript("OnUpdate", function(self, elapsed)
  self.elapsed = (self.elapsed or 0) + elapsed
  if self.elapsed < 0.2 then
    return
  end

  self.elapsed = 0
  if AuctionFrame ~= nil and AuctionFrame:IsVisible() then
    Backport:TryStartPendingQuery()
    Backport:RefreshSellItem()
  end
end)

SLASH_AUCTIONATOR2431 = "/atr"
SLASH_AUCTIONATOR2432 = "/auctionator"
SlashCmdList.AUCTIONATOR243 = function(message)
  local command = string.lower(Backport:Trim(message or ""))

  if command == "debug" then
    local newState = not Auctionator.Config.Get("debug")
    Auctionator.Config.Set("debug", newState)
    if newState then
      print(Auctionator.Localize("DEBUG_ON"))
    else
      print(Auctionator.Localize("DEBUG_OFF"))
    end
    return
  end

  if AuctionFrame ~= nil and AuctionFrame:IsVisible() then
    Backport:EnsureUI()
    Backport:TogglePanel()
    return
  end

  print(Auctionator.Localize("SLASH_HELP"))
end
