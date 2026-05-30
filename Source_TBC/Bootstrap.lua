Auctionator.Backport = Auctionator.Backport or {}

local Backport = Auctionator.Backport

Backport.PAGE_SIZE = NUM_AUCTION_ITEMS_PER_PAGE or 50
Backport.QUERY_COOLDOWN = 0.35
Backport.defaults = {
  debug = false,
  panelShown = true,
  lastDuration = Auctionator.Constants.Durations.Medium,
  startPricePercent = 95,
  exactMatch = false,
}

local function DeepCopy(source)
  local copy = {}
  for key, value in pairs(source) do
    if type(value) == "table" then
      copy[key] = DeepCopy(value)
    else
      copy[key] = value
    end
  end
  return copy
end

function Auctionator.Debug(message)
  if AUCTIONATOR_CONFIG == nil or not AUCTIONATOR_CONFIG.debug then
    return
  end

  if DEFAULT_CHAT_FRAME ~= nil then
    DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0Auctionator|r " .. tostring(message))
  end
end

function Backport:InitSavedVariables()
  AUCTIONATOR_CONFIG = AUCTIONATOR_CONFIG or {}
  AUCTIONATOR_SAVEDVARS = AUCTIONATOR_SAVEDVARS or {}
  AUCTIONATOR_PRICE_DATABASE = AUCTIONATOR_PRICE_DATABASE or {}
  AUCTIONATOR_POSTING_HISTORY = AUCTIONATOR_POSTING_HISTORY or {}
  AUCTIONATOR_RECENT_SEARCHES = AUCTIONATOR_RECENT_SEARCHES or {}
  AUCTIONATOR_CHARACTER_CONFIG = AUCTIONATOR_CHARACTER_CONFIG or {}

  for key, value in pairs(self.defaults) do
    if AUCTIONATOR_CONFIG[key] == nil then
      AUCTIONATOR_CONFIG[key] = value
    end
  end

  Auctionator.State = Auctionator.State or {}
  Auctionator.State.Loaded = true
  Auctionator.State.BackportLoaded = true
  Auctionator.State.CurrentVersion = "323-tbc-backport"
end

function Auctionator.Config.Get(key)
  if AUCTIONATOR_CONFIG == nil then
    return nil
  end
  return AUCTIONATOR_CONFIG[key]
end

function Auctionator.Config.Set(key, value)
  AUCTIONATOR_CONFIG = AUCTIONATOR_CONFIG or {}
  AUCTIONATOR_CONFIG[key] = value
end

function Backport:Trim(text)
  return (string.gsub(text or "", "^%s*(.-)%s*$", "%1"))
end

function Backport:Round(value)
  if value == nil then
    return 0
  end
  return math.floor(value + 0.5)
end

function Backport:FormatMoney(copper)
  copper = math.max(0, math.floor(tonumber(copper) or 0))
  local gold = math.floor(copper / 10000)
  local silver = math.floor(math.mod(copper, 10000) / 100)
  local copperOnly = math.mod(copper, 100)
  return string.format("%dg %02ds %02dc", gold, silver, copperOnly)
end

function Backport:RememberSearch(term)
  term = self:Trim(term)
  if term == "" then
    return
  end

  local updated = { term }
  for _, existing in ipairs(AUCTIONATOR_RECENT_SEARCHES) do
    if string.lower(existing) ~= string.lower(term) then
      table.insert(updated, existing)
    end
    if #updated >= 10 then
      break
    end
  end
  AUCTIONATOR_RECENT_SEARCHES = updated
end

function Backport:StorePrice(term, result)
  if term == nil or term == "" or result == nil or result.buyoutPrice == nil or result.buyoutPrice <= 0 then
    return
  end

  AUCTIONATOR_PRICE_DATABASE[string.lower(term)] = {
    name = result.name,
    minBuyout = self:Round(result.unitBuyout),
    stackSize = result.count,
    seenAt = time(),
  }
end

function Backport:AddPostingHistory(entry)
  if entry == nil then
    return
  end

  table.insert(AUCTIONATOR_POSTING_HISTORY, 1, DeepCopy(entry))
  while #AUCTIONATOR_POSTING_HISTORY > 50 do
    table.remove(AUCTIONATOR_POSTING_HISTORY)
  end
end
