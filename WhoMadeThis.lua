-- Who Made This: shows which add-on created the UI under the mouse.
--
-- The client's frame:GetSourceLocation() gives the file that created a frame,
-- e.g. "Interface/AddOns/EllesmereUIUnitFrames/Player.lua:120"; the folder
-- after AddOns is the add-on. Frames without one fall back to matching their
-- name against loaded add-on names. Blizzard_* folders are the game's own UI.
--
--   /wmt         toggle a live tooltip that follows the mouse
--   /wmt print   list everything under the mouse in chat (copy it with
--                Chattynator's scissors button)
-- Both can also be bound under Key Bindings > AddOns.

local ADDON = ...

BINDING_HEADER_WHOMADETHIS = "Who Made This"
BINDING_NAME_WHOMADETHIS_TOGGLE = "Toggle live inspector"
BINDING_NAME_WHOMADETHIS_PRINT = "Print what's under the mouse"

local tooltip -- created below; never counted as "under the mouse"

-- Loaded add-on folder names, longest first, for the name fallback
local addonNames
local function AddonNames()
    if addonNames then return addonNames end
    addonNames = {}
    local count = C_AddOns and C_AddOns.GetNumAddOns() or GetNumAddOns()
    for i = 1, count do
        local name = (C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo)(i)
        local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded)(name)
        if name and loaded then addonNames[#addonNames + 1] = name end
    end
    table.sort(addonNames, function(a, b) return #a > #b end)
    return addonNames
end

local function SafeCall(object, method)
    local fn = object[method]
    if not fn then return nil end
    local ok, value = pcall(fn, object)
    if ok and (not issecretvalue or not issecretvalue(value)) then return value end
end

-- Add-on name, how it was found ("source"/"name"/nil), and the source file
local function Owner(frame)
    local location = SafeCall(frame, "GetSourceLocation")
    if type(location) == "string" then
        local addon = location:match("AddOns[\\/]([^\\/]+)")
        local file = location:match("([^\\/]+)$")
        if addon then
            if addon:find("^Blizzard_") then return "Blizzard", "source", addon .. "/" .. file end
            return addon, "source", file
        end
        return "Blizzard", "source", file
    end
    local name = SafeCall(frame, "GetName")
    if type(name) == "string" then
        local lower = name:lower()
        for _, addon in ipairs(AddonNames()) do
            local key = addon:lower():gsub("[^%w]", "")
            if #key >= 3 and lower:find(key, 1, true) == 1 then return addon, "name" end
        end
    end
    return nil
end

local function Describe(frame)
    local name = SafeCall(frame, "GetName") or SafeCall(frame, "GetDebugName")
        or ("<unnamed " .. (SafeCall(frame, "GetObjectType") or "frame") .. ">")
    if #name > 48 then name = "..." .. name:sub(-45) end
    local addon, how, file = Owner(frame)
    local owner
    if not addon then
        owner = "|cff999999unknown (likely Blizzard)|r"
    elseif addon == "Blizzard" then
        owner = "|cff999999Blizzard|r"
    else
        owner = "|cff33ff99" .. addon .. "|r" .. (how == "name" and " |cff999999(by name)|r" or "")
    end
    return name, owner, file
end

local function Forbidden(frame)
    return frame.IsForbidden and frame:IsForbidden()
end

-- The mouse-enabled frames under the cursor (what a click would hit)
local function MouseFrames()
    local list = {}
    if GetMouseFoci then
        for _, f in ipairs(GetMouseFoci()) do list[#list + 1] = f end
    elseif GetMouseFocus then
        list[1] = GetMouseFocus()
    end
    local out = {}
    for _, f in ipairs(list) do
        if f and f ~= WorldFrame and f ~= tooltip and not Forbidden(f) then out[#out + 1] = f end
    end
    return out
end

-- Every visible frame under the cursor, smallest first (catches bars,
-- backgrounds and text that don't take the mouse). Too slow for every frame,
-- so the live tooltip runs it a few times a second.
local function VisibleFrames(limit)
    local found = {}
    local f = EnumerateFrames()
    while f do
        if f ~= tooltip and f ~= UIParent and f ~= WorldFrame and not Forbidden(f)
            and SafeCall(f, "IsVisible") and SafeCall(f, "IsMouseOver") then
            local w, h = SafeCall(f, "GetWidth"), SafeCall(f, "GetHeight")
            if type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
                found[#found + 1] = { frame = f, area = w * h }
            end
        end
        f = EnumerateFrames(f)
    end
    table.sort(found, function(a, b) return a.area < b.area end)
    local out, seen = {}, {}
    for _, entry in ipairs(found) do
        local addon = Owner(entry.frame) or "?"
        local name = SafeCall(entry.frame, "GetName") or ""
        local key = addon .. "|" .. name
        if not seen[key] then
            seen[key] = true
            out[#out + 1] = entry.frame
            if limit and #out >= limit then break end
        end
    end
    return out
end

-- Lines describing what's under the mouse: the frame a click would hit,
-- its parents, and the other visible frames there
local function Report(visibleLimit)
    local lines = {}
    local focus = MouseFrames()
    if #focus > 0 then
        lines[#lines + 1] = { "|cffffd100Mouse is over:|r" }
        for _, f in ipairs(focus) do
            local name, owner, file = Describe(f)
            lines[#lines + 1] = { name, owner, file }
        end
        lines[#lines + 1] = { "|cffffd100Its parents:|r" }
        local parent, depth = SafeCall(focus[1], "GetParent"), 0
        while parent and parent ~= UIParent and depth < 8 do
            local name, owner = Describe(parent)
            lines[#lines + 1] = { "  " .. name, owner }
            parent, depth = SafeCall(parent, "GetParent"), depth + 1
        end
    end
    local visible = VisibleFrames(visibleLimit)
    if #visible > 0 then
        lines[#lines + 1] = { "|cffffd100Also drawn here (smallest first):|r" }
        for _, f in ipairs(visible) do
            local name, owner = Describe(f)
            lines[#lines + 1] = { name, owner }
        end
    end
    if #lines == 0 then lines[1] = { "Nothing but the game world here." } end
    return lines
end

-- Live tooltip -----------------------------------------------------------

tooltip = CreateFrame("GameTooltip", "WhoMadeThisTooltip", UIParent, "GameTooltipTemplate")
tooltip:SetFrameStrata("TOOLTIP")
tooltip:EnableMouse(false)

local active, elapsed = false, 0

local function Refresh()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:ClearAllPoints()
    -- Keep the tooltip away from the cursor, flipped near the screen edges
    local right = x / scale > UIParent:GetWidth() * 0.6
    local top = y / scale > UIParent:GetHeight() * 0.6
    tooltip:SetPoint((top and "TOP" or "BOTTOM") .. (right and "RIGHT" or "LEFT"), UIParent, "BOTTOMLEFT",
        x / scale + (right and -24 or 24), y / scale + (top and -24 or 24))
    tooltip:AddLine("Who Made This", 1, 1, 1)
    for _, line in ipairs(Report(6)) do
        if line[2] then tooltip:AddDoubleLine(line[1], line[2], 1, 1, 1) else tooltip:AddLine(line[1]) end
    end
    tooltip:AddLine("|cff999999/wmt to close, /wmt print to copy|r")
    tooltip:Show()
end

local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.2 then return end
    elapsed = 0
    Refresh()
end)

function WhoMadeThis_Toggle()
    active = not active
    if active then elapsed = 1; driver:Show() else driver:Hide(); tooltip:Hide() end
end

function WhoMadeThis_Print()
    print("|cff33ff99Who Made This:|r")
    for _, line in ipairs(Report(15)) do
        local text = line[1]
        if line[2] then text = text .. "  -  " .. line[2] end
        if line[3] then text = text .. "  |cff999999" .. line[3] .. "|r" end
        print(text)
    end
end

SLASH_WHOMADETHIS1 = "/wmt"
SLASH_WHOMADETHIS2 = "/whomadethis"
SlashCmdList.WHOMADETHIS = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "print" or msg == "p" then WhoMadeThis_Print() else WhoMadeThis_Toggle() end
end
