--[[
Name: Bazooka
Revision: $Revision$
Author(s): mitch0
Website: http://www.wowace.com/projects/bazooka/
SVN: svn://svn.wowace.com/wow/bazooka/mainline/trunk
Description: Bazooka is a FuBar like broker display
License: Public Domain
]]

local AppName = "Bazooka"
local OptionsAppName = AppName .. "_Options"
local VERSION = AppName .. "-r" .. ("$Revision$"):match("%d+")

local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local LSM = LibStub:GetLibrary("LibSharedMedia-3.0", true)
local L = LibStub("AceLocale-3.0"):GetLocale(AppName)

-- internal vars

local _ -- throwaway
local uiScale = 1.0 -- just to be safe...

local function printf(...)
    print(string.format(...))
end

local function makeColor(r, g, b, a)
    a = a or 1.0
    return { ["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a }
end

local function colorToHex(color)
    return ("%02x%02x%02x%02x"):format((color.a and color.a * 255 or 255), color.r*255, color.g*255, color.b*255)	
end

-- cached stuff

local GetCursorPosition = GetCursorPosition
local UIParent = UIParent
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local tinsert = tinsert
local tremove = tremove
local tostring = tostring
local print = print
local pairs = pairs
local ipairs = ipairs
local type = type
local unpack = unpack
local wipe = wipe
local math = math

-- hard-coded config stuff

local Defaults =  {
--  bgTexture = "Blizzard Tooltip",
--  bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
    bgTexture = "Blizzard Dialog Background",
    bgFile = [[Interface\DialogFrame\UI-DialogBox-Background]],
--  edgeTexture = "Blizzard Tooltip",
--  edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
    edgeTexture = "None",
    edgeFile = [[Interface\None]],
    fontName = "Friz Quadrata TT",
    fontPath = GameFontNormal:GetFont(),
    fontSize = 12,
    fontOutline = "",
    iconSize = 16,
    frameWidth = 256,
    frameHeight = 20,
    labelColor = makeColor(0.9, 0.9, 0.9),
    textColor = makeColor(1.0, 0.82, 0),
    suffixColor = makeColor(0, 0.82, 0),
    sideSpacing = 8,
    centerSpacing = 16,
    iconTextSpacing = 2,
}

local Icon = [[Interface\Icons\INV_Gizmo_SuperSapperCharge]]
local UnlockedIcon = [[Interface\Icons\INV_Ammo_Bullet_03]]
local HighlightImage = [[Interface\AddOns\]] .. AppName .. [[\highlight.tga]]
local EmptyPluginWidth = 1
local NearSquared = 20 * 20
local MinDropPlaceHLDX = 3
local BzkDialogDisablePlugin = 'BAZOOKA_DISABLE_PLUGIN'

---------------------------------

Bazooka = LibStub("AceAddon-3.0"):NewAddon(AppName, "AceEvent-3.0")
local Bazooka = Bazooka

Bazooka:SetDefaultModuleState(false)

Bazooka.version = VERSION
Bazooka.AppName = AppName
Bazooka.OptionsAppName = OptionsAppName

Bazooka.draggedFrame = nil
Bazooka.bars = {}
Bazooka.plugins = {}
Bazooka.numBars = 0

-- Default DB stuff

local defaults = {
    profile = {
        locked = false,
        adjustFrames = false,
        simpleTip = true,
        disableHL = false,
        numBars = 1,


        bars = {
            ["**"] = {
                point = "CENTER",
                rePoint = "CENTER",
                x = 0,
                y = 0,
                sideSpacing = Defaults.sideSpacing,
                centerSpacing = Defaults.centerSpacing,
                iconTextSpacing = Defaults.iconTextSpacing,

                font = Defaults.fontName,
                fontSize = Defaults.fontSize,
                fontOutline = Defaults.fontOutline,

                iconSize = Defaults.iconSize,

                labelColor = Defaults.labelColor,
                textColor = Defaults.textColor,
                suffixColor = Defaults.suffixColor,
                
                attach = 'none',

                strata = "MEDIUM",

                frameWidth = Defaults.frameWidth,
                frameHeight = Defaults.frameHeight,

                bgEnabled = true,
                bgTexture = Defaults.bgTexture,
                bgBorderTexture = Defaults.edgeTexture,
                bgTile = false,
                bgTileSize = 32,
                bgEdgeSize = 16,
                bgColor = makeColor(0, 0, 0, 0.7),
                bgBorderColor = makeColor(0.8, 0.6, 0.0),
            },
            [1] = {
                attach = 'top',
            },
            [2] = {
                attach = 'bottom',
            },
        },
        plugins = {
            ["*"] = {
                ["**"] = {
                    enabled = false,
                    bar = 1,
                    area = 'left',
                    pos = nil,
                    disableTooltip = false,
                    disableTooltipInCombat = true,
                    disableMouseInCombat = false,
                    showIcon = true,
                    showLabel = false,
                    showText = true,
                },
            },
            ["launcher"] = {
                ["**"] = {
                    enabled = true,
                    bar = 1,
                    area = 'left',
                    pos = nil,
                    disableTooltip = false,
                    disableTooltipInCombat = true,
                    disableMouseInCombat = false,
                    showIcon = true,
                    showLabel = false,
                    showText = false,
                },
                ["Bazooka"] = {
                    area = 'center',
                },
            },
            ["data source"] = {
                ["**"] = {
                    enabled = true,
                    bar = 1,
                    area = 'right',
                    pos = nil,
                    disableTooltip = false,
                    disableTooltipInCombat = true,
                    disableMouseInCombat = false,
                    showIcon = true,
                    showLabel = false,
                    showText = true,
                },
                ["uClock"] = {
                    area = 'cright',
                },
            },
        },
    },
}

local function deepCopy(src)
    local res = {}
    for k, v in pairs(src) do
        if (type(v) == 'table') then
            v = deepCopy(v)
        end
        res[k] = v
    end
    return res
end

local function setDeepCopyIndex(proto)
    proto.__index = function(t, k)
        local v = proto[k]
        if (type(v) == 'table') then
            v = deepCopy(v)
        end
        t[k] = v
        return v
    end
end

local function updateUIScale()
    uiScale = UIParent:GetEffectiveScale()
end

local function getScaledCursorPosition()
    local x, y = GetCursorPosition()
    return x / uiScale, y / uiScale
end

local function distance2(x1, y1, x2, y2)
    return (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1)
end

local function getDistance2Frame(x, y, frame)
    local left, bottom, width, height = frame:GetRect()
    local dx, dy = 0, 0
    if (left > x) then
        dx = left - x
    elseif (x > left + width) then
        dx = x - (left + width)
    end
    if (bottom > y) then
        dy = bottom - y
    elseif (y > bottom + height) then
        dy = y - (bottom + height)
    end
    return dx * dx + dy * dy
end

-- BEGIN Bar stuff

local Bar = {
    id = nil,
    db = nil,
    frame = nil,
    centerFrame = nil,
    allPlugins = {},
    plugins = {
        left = {},
        cleft = {},
        center = {},
        cright = {},
        right = {},
    },
    inset = 0,
    backdrop = nil,
    hl = nil,
}

setDeepCopyIndex(Bar)

function Bar:New(id, db)
    local bar = setmetatable({}, Bar)
    bar:enable(id, db)
    bar:applySettings()
    return bar
end

function Bar:enable(id, db)
    self.id = id
    self.db = db
    if (not self.frame) then
        self.frame = CreateFrame("Frame", "BazookaBar_" .. id, UIParent)
        self.frame.bzkBar = self
        self.centerFrame = CreateFrame("Frame", "BazookaBarC_" .. id, self.frame)
        self.centerFrame:EnableMouse(false)
        self.centerFrame:SetPoint("TOP", self.frame, "TOP", 0, 0)
        self.centerFrame:SetPoint("BOTTOM", self.frame, "BOTTOM", 0, 0)
    end
    self:updateCenterWidth()
    self.frame:Show()
end

function Bar:disable()
    if (self.frame) then
        self.frame:Hide()
    end
    for name, plugin in pairs(self.allPlugins) do
        plugin:disable()
    end
    wipe(self.allPlugins)
    for area, plugins in pairs(self.plugins) do
        wipe(plugins)
    end
end

function Bar:getAreaCoords(area)
    if (area == 'left') then
        local left, bottom, width, height = self.frame:GetRect()
        return left, bottom + height / 2
    elseif (area == 'cleft') then
        local left, bottom, width, height = self.centerFrame:GetRect()
        return left, bottom + height / 2
    elseif (area == 'cright') then
        local left, bottom, width, height = self.centerFrame:GetRect()
        return left + width, bottom + height / 2
    elseif (area == 'right') then
        local left, bottom, width, height = self.frame:GetRect()
        return left + width, bottom + height / 2
    else -- center
        local left, bottom, width, height = self.centerFrame:GetRect()
        return left + width / 2, bottom + height / 2
    end
end

function Bar:getDropPlace(x, y)
    local dstArea, dstPos
    local minDist = math.huge
    for area, plugins in pairs(self.plugins) do
        if (#plugins == 0) then
            local dist = distance2(x, y, self:getAreaCoords(area))
            if (dist < minDist) then
                dstArea, dstPos, minDist = area, 1, dist
            end
        else
            for i, plugin in ipairs(plugins) do
                local pos, dist = plugin:getDropPlace(x, y)
                if (dist < minDist) then
                    dstArea, dstPos, minDist = area, pos, dist
                end
            end
        end
    end
    return dstArea, dstPos, minDist
end

function Bar:getSpacing(area)
    if (area == 'left' or area == 'right') then
        return self.db.sideSpacing
    else
        return self.db.centerSpacing
    end
end

function Bar:getHighlightCenter(area, pos)
    local plugins = self.plugins[area]
    if (#plugins == 0) then
        local x = self:getAreaCoords(area)
        return x
    end
    if (pos < 0) then
        pos = -pos
        for i, plugin in ipairs(plugins) do
            if (pos <= plugin.db.pos) then
                return plugin.frame:GetRight()
            end
        end
    else
        for i, plugin in ipairs(plugins) do
            if (pos <= plugin.db.pos) then
                return plugin.frame:GetLeft()
            end
        end
    end
    return plugins[#plugins].frame:GetRight()
end

function Bar:highlight(area, pos)
    if (not area) then
        if (self.hl) then
            self.hl:Hide()
        end
        return
    end
    if (not self.hl) then
        self.hlFrame = CreateFrame("Frame", "BazookaBarHLF_" .. self.id, self.frame)
        self.hlFrame:SetFrameLevel(self.frame:GetFrameLevel() + 5)
        self.hlFrame:EnableMouse(false)
        self.hlFrame:SetAllPoints()
        self.hl = self.hlFrame:CreateTexture("BazookaBarHL_" .. self.id, "OVERLAY")
        self.hl:SetTexture(HighlightImage)
    end
    local center = self:getHighlightCenter(area, pos) - self.frame:GetLeft()
    local dx = math.floor(self:getSpacing(area) / 2 + 0.5)
    if (dx < MinDropPlaceHLDX) then
        dx = MinDropPlaceHLDX
    end
    self.hl:ClearAllPoints()
    self.hl:SetPoint("TOP", self.frame, "TOP", 0, 0)
    self.hl:SetPoint("BOTTOM", self.frame, "BOTTOM", 0, 0)
    self.hl:SetPoint("LEFT", self.frame, "LEFT", center - dx, 0)
    self.hl:SetPoint("RIGHT", self.frame, "LEFT", center + dx, 0)
    self.hl:Show()
end

function Bar:updateCenterWidth()
    local cw = 0
    for i, p in ipairs(self.plugins.center) do
        cw = cw + p.frame:GetWidth()
    end
    local numGaps = #self.plugins.center + 1
    cw = cw + (numGaps * self.db.centerSpacing)
    if (cw <= 0) then
        cw = 1
    end
    self.centerFrame:SetWidth(cw)
end

function Bar:detachPlugin(plugin)
    local plugins = self.plugins[plugin.db.area]
    local lp, rp, index
    for i, p in ipairs(plugins) do
        if (index) then
            rp = p
            break
        end
        if (p == plugin) then
            index = i
        else
            lp = p
        end
    end
    if (not index) then
        return -- this should never happen
    end
    tremove(plugins, index)
    self.allPlugins[plugin.name] = nil
    plugin.frame:ClearAllPoints()
    self:setRightAttachPoint(lp, rp)
    self:setLeftAttachPoint(rp, lp)
    if (plugin.db.area == 'center') then
        self:updateCenterWidth()
    end
end

function Bar:attachPlugin(plugin, area, pos)
    area = area or "left"
    plugin.bar = self
    plugin.db.bar = self.id
    plugin.db.area = area
    local plugins = self.plugins[area]
    local lp, rp
    if (not pos) then
        local count = #self.plugins[area]
        if (count > 0) then
            lp = plugins[count]
            plugin.db.pos = lp.db.pos + 1
        else
            plugin.db.pos = 1
        end
        tinsert(plugins, plugin)
    else
        if (pos < 0) then
            pos = 1 - pos
        end
        plugin.db.pos = pos
        local rpi
        for i, p in ipairs(plugins) do
            if (pos <= p.db.pos) then
                if (not rp) then
                    rp = p
                    rpi = i
                end
                if (pos < p.db.pos) then
                    break
                end
                pos = pos + 1
                p.db.pos = pos
            elseif (not rp) then
                lp = p
            end
        end
        if (rpi) then
            tinsert(plugins, rpi, plugin)
        else
            tinsert(plugins, plugin)
        end
    end
    self.allPlugins[plugin.name] = plugin
    plugin.frame:SetParent(self.frame)
    plugin.frame:ClearAllPoints()
    plugin.frame:SetPoint("TOP", self.frame, "TOP")
    plugin.frame:SetPoint("BOTTOM", self.frame, "BOTTOM")
    self:setLeftAttachPoint(plugin, lp)
    self:setRightAttachPoint(plugin, rp)
    self:setRightAttachPoint(lp, plugin)
    self:setLeftAttachPoint(rp, plugin)
    plugin:globalSettingsChanged()
    if (area == "center") then
        self:updateCenterWidth()
    end
end

function Bar:getEdgeSpacing()
    return self.db.sideSpacing + self.inset
end

function Bar:setLeftAttachPoint(plugin, lp)
    if (not plugin) then
        return
    end
    local area = plugin.db.area
    if (area == "left") then
        if (lp) then
            plugin.frame:SetPoint("LEFT", lp.frame, "RIGHT", self.db.sideSpacing, 0)
        else
            plugin.frame:SetPoint("LEFT", self.frame, "LEFT", self:getEdgeSpacing(), 0)
        end
    elseif (area == "center") then
        if (lp) then
            plugin.frame:SetPoint("LEFT", lp.frame, "RIGHT", self.db.centerSpacing, 0)
        else
            plugin.frame:SetPoint("LEFT", self.centerFrame, "LEFT", self.db.centerSpacing, 0)
        end
    elseif (area == "cright") then
        if (lp) then
            plugin.frame:SetPoint("LEFT", lp.frame, "RIGHT", self.db.centerSpacing, 0)
        else
            plugin.frame:SetPoint("LEFT", self.centerFrame, "RIGHT", 0, 0)
        end
    end
end

function Bar:setRightAttachPoint(plugin, rp)
    if (not plugin) then
        return
    end
    local area = plugin.db.area
    if (area == "cleft") then
        if (rp) then
            plugin.frame:SetPoint("RIGHT", rp.frame, "LEFT", -self.db.centerSpacing, 0)
        else
            plugin.frame:SetPoint("RIGHT", self.centerFrame, "LEFT", 0, 0)
        end
    elseif (area == "right") then
        if (rp) then
            plugin.frame:SetPoint("RIGHT", rp.frame, "LEFT", -self.db.sideSpacing, 0)
        else
            plugin.frame:SetPoint("RIGHT", self.frame, "RIGHT", -self:getEdgeSpacing(), 0)
        end
    end
end

function Bar:applySettings()
    if (self.db.attach == "top") then
        self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        self.frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
        self.frame:SetHeight(self.db.frameHeight)
    elseif (self.db.attach == "bottom") then
        self.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
        self.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
        self.frame:SetHeight(self.db.frameHeight)
    else -- detached
        self.frame:SetPoint(self.db.point, UIParent, self.db.relPoint, self.db.x, self.db.y)
        self.frame:SetHeight(self.db.frameHeight)
        self.frame:SetWidth(self.db.frameWidth)
    end
    self.frame:SetFrameStrata(self.db.strata)
    self:applyFontSettings()
    self:applyBGSettings()
end

function Bar:applyBGSettings()
    if (not self.db.bgEnabled) then
        self.frame:SetBackdrop(nil)
        return
    end
    self.bg = self.bg or { insets = {} }
    local bg = self.bg
    if (LSM) then
        bg.bgFile = LSM:Fetch("background", self.db.bgTexture, true)
        if (not bg.bgFile) then
            bg.bgFile = Defaults.bgFile
            LSM.RegisterCallback(self, "LibSharedMedia_Registered", "mediaUpdate")
        end
        bg.edgeFile = LSM:Fetch("border", self.db.bgBorderTexture, true)
        if (not bg.edgeFile) then
            bg.edgeFile = Defaults.edgeFile
            LSM.RegisterCallback(self, "LibSharedMedia_Registered", "mediaUpdate")
        end
    else
        bg.bgFile = Defaults.bgFile
        bg.edgeFile = Defaults.edgeFile
    end
    bg.tile = self.db.bgTile
    bg.tileSize = self.db.bgTileSize
    bg.edgeSize = (bg.edgeFile and bg.edgeFile ~= [[Interface\None]]) and self.db.bgEdgeSize or 0
    local inset = math.floor(bg.edgeSize / 4)
    self.inset = inset
    bg.insets.left = inset
    bg.insets.right = inset
    bg.insets.top = inset
    bg.insets.bottom = inset
    self.frame:SetBackdrop(bg)
    self.frame:SetBackdropBorderColor(self.db.bgBorderColor.r, self.db.bgBorderColor.g, self.db.bgBorderColor.b, self.db.bgBorderColor.a)
end

function Bar:applyFontSettings()
    if (LSM) then
        self.dbFontPath = LSM:Fetch("font", self.db.font, true)
        if (not self.dbFontPath) then
            LSM.RegisterCallback(self, "LibSharedMedia_Registered", "mediaUpdate")
            self.dbFontPath = Defaults.fontPath
            return
        end
    end
    self:globalSettingsChanged()
end

function Bar:mediaUpdate(event, mediaType, key)
    if (mediaType == 'background') then
        if (key == self.db.bgTexture) then
            self:applyBGSettings()
        end
    elseif (mediaType == 'border') then
        if (key == self.db.bgBorderTexture) then
            self:applyBGSettings()
        end
    elseif (mediaType == 'font') then
        if (key == self.db.font) then
            self:applyFontSettings()
        end
    end
end

function Bar:globalSettingsChanged()
    for name, plugin in pairs(self.allPlugins) do
        plugin:globalSettingsChanged()
    end
end

Bazooka.Bar = Bar

-- END Bar stuff

-- BEGIN Plugin stuff

local Plugin = {
    name = nil,
    dataobj = nil,
    db = nil,
    frame = nil,
    icon = nil,
    text = nil,
    label = nil,
    hl = nil,
    iconSize = Defaults.iconSize,
    iconTextSpacing = Defaults.iconTextSpacing,
    fontSize = Defaults.fontSize,
    labelColorHex = colorToHex(Defaults.labelColor),
    suffixColorHex = colorToHex(Defaults.suffixColor),

}

setDeepCopyIndex(Plugin)

Plugin.OnEnter = function(frame)
    if (Bazooka.draggedFrame) then
        return
    end
    frame.bzkPlugin:highlight(true)
end

Plugin.OnLeave = function(frame)
    frame.bzkPlugin:highlight(nil)
end

Plugin.OnClick = function(frame, ...)
    local self = frame.bzkPlugin
    if (self.dataobj.OnClick) then
        self.dataobj.OnClick(frame, ...)
    end
end

Plugin.OnUpdate = function(frame, ...)
    local x, y = getScaledCursorPosition()
    if (x ~= Bazooka.lastX or y ~= Bazooka.lastY) then
        Bazooka.lastX, Bazooka.lastY = x, y
        Bazooka:highlight(Bazooka:getDropPlace(x, y))
    end
end

Plugin.OnDragStart = function(frame, ...)
    if (Bazooka.locked) then
        return
    end
    frame.bzkPlugin:highlight(nil)
    frame.bzkPlugin:detach()
    updateUIScale()
    frame:SetAlpha(0.7)
    Bazooka.draggedFrame, Bazooka.lastX, Bazooka.lastY = frame, nil, nil
    frame:StartMoving()
    frame:SetScript("OnUpdate", Plugin.OnUpdate)
end

Plugin.OnDragStop = function(frame, ...)
    if (Bazooka.locked) then
        return
    end
    frame:SetScript("OnUpdate", nil)
    frame:StopMovingOrSizing()
    frame:SetAlpha(1.0)
    Bazooka:highlight(nil)
    if (Bazooka.draggedFrame) then -- we'll signal an aborted drag with clearing draggedFrame
        Bazooka.draggedFrame = nil
        local bar, area, pos = Bazooka:getDropPlace(getScaledCursorPosition())
        if (bar) then
            bar:attachPlugin(frame.bzkPlugin, area, pos)
        else
            frame.bzkPlugin:reattach()
            Bazooka:openStaticDialog(BzkDialogDisablePlugin, frame.bzkPlugin, frame.bzkPlugin.label)
        end
    end
end

function Plugin:New(name, dataobj, db)
    local plugin = setmetatable({}, Plugin)
    plugin.name = name
    plugin.dataobj = dataobj
    plugin.db = db
    plugin:applySettings()
    return plugin
end

function Plugin:getDropPlace(x, y)
    local left, bottom, width, height = self.frame:GetRect()
    local ld = distance2(x, y, left, bottom + height / 2)
    local rd = distance2(x, y, left + width, bottom + height / 2)
    if (ld < rd) then
        return self.db.pos, ld
    else
        return -self.db.pos, rd
    end
end

function Plugin:highlight(flag)
    if (not flag or Bazooka.db.profile.disableHL) then
        if (self.hl) then
            self.hl:Hide()
        end
        return
    end
    if (not self.hl) then
        self.hl = self.frame:CreateTexture("BazookaHL_" .. self.name, "OVERLAY")
        self.hl:SetTexture(HighlightImage)
        self.hl:SetAllPoints()
    end
    self.hl:Show()
end

function Plugin:globalSettingsChanged()
    local bdb = self.bar and self.bar.db or Defaults
    self.labelColorHex = colorToHex(bdb.labelColor)
    self.suffixColorHex = colorToHex(bdb.suffixColor)
    self.iconTextSpacing = bdb.iconTextSpacing
    self.iconSize = bdb.iconSize
    self.fontSize = bdb.fontSize
    if (self.text) then
        local dbFontPath = self.bar and self.bar.dbFontPath or bdb.fontPath
        local fontPath, fontSize, fontOutline = self.text:GetFont()
        fontOutline = fontOutline or ""
        if (dbFontPath ~= fontPath or bdb.fontSize ~= fontSize or bdb.fontOutline ~= fontOutline) then
            self.text:SetFont(dbFontPath, self.fontSize, bdb.fontOutline)
        end
        self.text:SetTextColor(bdb.textColor.r, bdb.textColor.g, bdb.textColor.b, bdb.textColor.a)
    end
    if (self.icon) then
        self.icon:SetWidth(self.iconSize)
        self.icon:SetHeight(self.iconSize)
    end
    self:updateLayout()
end

function Plugin:createIcon()
    self.icon = self.frame:CreateTexture("BazookaPluginIcon_" .. self.name, "ARTWORK")
    self.icon:ClearAllPoints()
    local iconSize = Defaults.iconSize
    self.icon:SetWidth(iconSize)
    self.icon:SetHeight(iconSize)
    self.icon:SetPoint("LEFT", self.frame, "LEFT", 0, 0)
end

function Plugin:createText()
    self.text = self.frame:CreateFontString("BazookaPluginText_" .. self.name, "ARTWORK", "GameFontNormal")
    self.text:SetFont(Defaults.fontPath, Defaults.fontSize, Defaults.fontOutline)
end

function Plugin:updateLayout()
    local w = 0
    if (self.db.showText or self.db.showLabel) then
        local tw = self.text:GetStringWidth()
        local iw = self.db.showIcon and self.icon:GetWidth() or 0
        if (tw > 0) then
            local offset = (iw > 0) and (iw + self.iconTextSpacing) or 0
            self.text:SetPoint("LEFT", self.frame, "LEFT", offset, 0)
            w = offset + tw
        elseif (iw > 0) then
            w = iw
        else
            w = EmptyPluginWidth
        end
    elseif (self.db.showIcon) then
        local iw = self.icon:GetWidth()
        if (iw > 0) then
            w = iw
        else
            w = EmptyPluginWidth
        end
    else
        w = EmptyPluginWidth
    end
    if (w ~= self.frame:GetWidth()) then
        self.frame:SetWidth(w)
        if (self.bar and self.db.area == 'center') then
            self.bar:updateCenterWidth()
        end
    end
end

function Plugin:enable()
    if (not self.frame) then
        self.frame = CreateFrame("Button", "BazookaPlugin_" .. self.name, UIParent)
        self.frame.bzkPlugin = self
        self.frame:SetScript("OnEnter", Plugin.OnEnter)
        self.frame:SetScript("OnLeave", Plugin.OnLeave)
        self.frame:SetScript("OnClick", Plugin.OnClick)
        self.frame:RegisterForDrag("LeftButton")
        self.frame:RegisterForClicks("AnyUp")
        self.frame:SetMovable(true)
        self.frame:SetScript("OnDragStart", Plugin.OnDragStart)
        self.frame:SetScript("OnDragStop", Plugin.OnDragStop)
        self.frame:EnableMouse(true)
    end
    self.frame:Show()
end

function Plugin:disable()
    if (self.frame) then
        self.frame:ClearAllPoints()
        self.frame:Hide()
        self.bar = nil
    end
end

function Plugin:applySettings()
    if (not self.db.enabled) then
        self:detach()
        self:disable()
        return
    end
    self:enable()
    if (self.db.showIcon) then
        if (not self.icon) then
            self:createIcon()
        end
        self:setIcon()
        self:setIconColor()
        self:setIconCoords()
        self.icon:Show()
    elseif (self.icon) then
        self.icon:Hide()
    end
    if (self.db.showText or self.db.showLabel) then
        if (not self.text) then
            self:createText()
        end
        self:setText()
    elseif (self.text) then
        self.text:SetFormattedText("")
        self.text:Hide()
    end
    self:updateLabel()
    self:updateLayout()
end

function Plugin:setIcon()
    if (not self.db.showIcon) then
        return
    end
    local dataobj = self.dataobj
    local icon = self.icon
    icon:SetTexture(dataobj.icon)
end

function Plugin:setIconColor()
    if (not self.db.showIcon) then
        return
    end
    local dataobj = self.dataobj
    if (dataobj.iconR) then
        self.icon:SetVertexColor(dataobj.iconR, dataobj.iconG, dataobj.iconB)
    end
end

function Plugin:setIconCoords()
    if (not self.db.showIcon) then
        return
    end
    local dataobj = self.dataobj
    if (dataobj.iconCoords) then
        self.icon:SetTexCoord(unpack(dataobj.iconCoords))
    end
end

function Plugin:setText()
    local dataobj = self.dataobj
    if (self.db.showLabel) then
        if (self.db.showText and dataobj.text) then
            self.text:SetFormattedText("|c%s%s:|r %s", self.labelColorHex, self.label, dataobj.text)
        elseif (self.db.showText and dataobj.value and dataobj.suffix) then
            self.text:SetFormattedText("|c%s%s:|r %s %s", self.labelColorHex, self.label, dataobj.value, dataobj.suffix)
        else
            self.text:SetFormattedText("|c%s%s|r", self.labelColorHex, self.label)
        end
        self:updateLayout()
    elseif (self.db.showText) then
        if (dataobj.text) then
            self.text:SetFormattedText("%s", dataobj.text)
        elseif (dataobj.value and dataobj.suffix) then
            self.text:SetFormattedText("%s |c%s%s|r", dataobj.value, self.suffixColorHex, dataobj.suffix)
        else
            self.text:SetFormattedText("")
        end
        self:updateLayout()
    end
end

function Plugin:updateLabel()
    -- FIXME: muck around with dataobj.tocname?
    self.label = self.dataobj.label or self.name
    self:setText()
end

function Plugin:reattach()
    if (self.bar) then
        self.bar:attachPlugin(self, self.db.area, self.db.pos)
    end
end

function Plugin:detach()
    if (self.bar) then
        self.bar:detachPlugin(self)
        if (self.frame) then
            self.frame:SetFrameStrata("HIGH")
        end
    end
end

Bazooka.Plugin = Plugin

Bazooka.updaters = {
    label = Plugin.updateLabel,
    text = Plugin.setText,
    value = Plugin.setText,
    suffix = Plugin.setText,

    icon = Plugin.setIcon,
    iconR = Plugin.setIconColor,
    iconG = Plugin.setIconColor,
    iconB = Plugin.setIconColor,
    iconCoords = Plugin.setIconCoords,
}

-- END Plugin stuff

-- BEGIN AceAddon stuff

function Bazooka:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("BazookaDB", defaults)
    LibStub("LibDualSpec-1.0"):EnhanceDatabase(self.db, AppName)
    self.db.RegisterCallback(self, "OnProfileChanged", "profileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "profileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "profileChanged")
    self:profileChanged()
    self:setupDummyOptions()
    if (self.setupDBOptions) then -- trickery to make it work with a straight checkout
        self:setupDBOptions()
    end
    self:setupLDB()
end

function Bazooka:OnEnable(first)
    self.enabled = true
    self:init()
    LDB.RegisterCallback(self, "LibDataBroker_DataObjectCreated", "dataObjectCreated")
    LDB.RegisterCallback(self, "LibDataBroker_AttributeChanged", "attributeChanged")
end

function Bazooka:OnDisable()
    self.enabled = false
    self:UnregisterAllEvents()
    LDB.UnregisterAllCallbacks(self)
    for i, bar in ipairs(self.bars) do
        bar.frame:Hide()
    end
end

-- END AceAddon stuff

-- BEGIN handlers

function Bazooka:dataObjectCreated(event, name, dataobj)
    local plugin = self:createPlugin(name, dataobj)
end

function Bazooka:attributeChanged(event, name, attr, value, dataobj)
    local plugin = self.plugins[name]
    if (plugin and plugin.db.enabled) then
        local updater = self.updaters[attr]
        if (updater) then
            updater(plugin)
            return
        end
        print("### " .. tostring(name) .. "." .. tostring(attr) .. " = " ..  tostring(value))
    end
end

function Bazooka:profileChanged()
    if (not self.enabled) then
        return
    end
    self:init()
end

-- END handlers

function Bazooka:init()
    print("### init()")
    for i, bar in ipairs(self.bars) do
        bar:disable()
    end
    for name, plugin in pairs(self.plugins) do
        plugin:disable()
    end
    self.numBars = 0
    local numBars = self.db.profile.numBars
    if (not numBars or numBars <= 0) then
        numBars = 1
    end
    for i = 1, numBars do
        self:createBar()
    end
    self:initPlugins()
    self:applySettings()
end

function Bazooka:createBar()
    self.numBars = self.numBars + 1
    self.db.profile.numBars = self.numBars
    local id =  self.numBars
    local db = self.db.profile.bars[id]
    local bar = self.bars[id]
    if (bar) then
        bar:enable(id, db)
        bar:applySettings()
    else
        bar = Bar:New(id, db)
        self.bars[bar.id] = bar
    end
end

function Bazooka:removeBar(bar)
    if (self.numBars <= 1) then
        return
    end
    bar:disable()
    self.numBars = self.numBars - 1
    self.db.profile.numBars = self.numBars
    for i = bar.id, self.numBars do
        self.db.profile.bars[i] = self.db.profile.bars[i + 1]
        self.bars[i] = self.bars[i + 1]
    end
    self.db.profile.bars[self.numBars + 1] = nil
    self.bars[self.numBars + 1] = nil
    self:init()
end

function Bazooka:createPlugin(name, dataobj)
    local pt = dataobj.type or ""
    local db = self.db.profile.plugins[pt][name]
    local plugin = self.plugins[name]
    if (plugin) then
        plugin.db = db
        plugin.dataobj = dataobj
        plugin:applySettings()
    else
        plugin = Plugin:New(name, dataobj, db)
        self.plugins[name] = plugin
    end
    if (plugin.db.enabled) then
        self:attachPlugin(plugin)
    end
    return plugin
end

function Bazooka:disablePlugin(plugin)
    plugin.db.enabled = false
    plugin:applySettings()
end

function Bazooka:attachPlugin(plugin)
    local bar = self.bars[plugin.db.bar]
    if (not bar) then
        self.bars[1]:attachPlugin(plugin)
    else
        bar:attachPlugin(plugin, plugin.db.area, plugin.db.pos)
    end
end

function Bazooka:initPlugins()
    for name, dataobj in LDB:DataObjectIterator() do
        self:dataObjectCreated(nil, name, dataobj)
    end
end

function Bazooka:applySettings()
    if (not self:IsEnabled()) then
        self:OnDisable()
        return
    end
    self:toggleLocked(self.db.profile.locked == true)
    for i, bar in ipairs(self.bars) do
        bar:applySettings()
    end
    for name, plugin in pairs(self.plugins) do
        plugin:applySettings()
    end
end

function Bazooka:cancelDrag()
    local draggedFrame = self.draggedFrame
    self.draggedFrame = nil
    if (draggedFrame and draggedFrame.OnDragStop) then
        draggedFrame.OnDragStop(draggedFrame)
    end
end

function Bazooka:lock()
    self.locked = true
    self.ldb.icon = Icon
    self:cancelDrag()
end

function Bazooka:unlock()
    self.locked = false
    self.ldb.icon = UnlockedIcon
end

function Bazooka:toggleLocked(flag)
    if (flag == nil) then flag = not self.db.profile.locked end
    self.db.profile.locked = flag
    if (flag) then
        self:lock()
    else
        self:unlock()
    end
end

function Bazooka:setupLDB()
    local ldb = {
        type = "launcher",
        icon = Icon,
        OnClick = function(frame, button)
            if (button == "LeftButton") then
                self:toggleLocked()
            elseif (button == "RightButton") then
                self:openConfigDialog()
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine(self.AppName)
            tt:AddLine(L["|cffeda55fLeft Click|r to lock/unlock frames"])
            tt:AddLine(L["|cffeda55fRight Click|r to open the configuration window"])
        end,
    }
    LDB:NewDataObject(self.AppName, ldb)
    self.ldb = ldb
end

function Bazooka:getDropPlace(x, y)
    local dstBar, dstArea, dstPos
    local minDist = math.huge
    for i, bar in ipairs(self.bars) do
        local area, pos, dist = bar:getDropPlace(x, y)
        if (dist < minDist) then
            dstBar, dstArea, dstPos, minDist = bar, area, pos, dist
        end
    end
    if (minDist < NearSquared or getDistance2Frame(x, y, dstBar.frame) < NearSquared) then
        return dstBar, dstArea, dstPos
    end
end

function Bazooka:highlight(bar, area, pos)
-- FIXME: re-do highlight stuff so that the plugins don't overlap the HL texture
    if (self.hlBar and self.hlBar ~= bar) then
        self.hlBar:highlight(nil)
    end
    self.hlBar = bar
    if (bar) then
        bar:highlight(area, pos)
    end
end

-- BEGIN LoD Options muckery

function Bazooka:setupDummyOptions()
    if (self.optionsLoaded) then
        return
    end
    self.dummyOpts = CreateFrame("Frame", AppName .. "DummyOptions", UIParent)
    self.dummyOpts.name = AppName
    self.dummyOpts:SetScript("OnShow", function(frame)
        if (not self.optionsLoaded) then
            if (not InterfaceOptionsFrame:IsVisible()) then
                return -- wtf... Happens if you open the game map and close it with ESC
            end
            self:openConfigDialog()
        else
            frame:Hide()
        end
    end)
    InterfaceOptions_AddCategory(self.dummyOpts)
end

function Bazooka:loadOptions()
    if (not self.optionsLoaded) then
        self.optionsLoaded = true
        local loaded, reason = LoadAddOn(OptionsAppName)
        if (not loaded) then
            print("Failed to load " .. tostring(OptionsAppName) .. ": " .. tostring(reason))
        end
    end
end

function Bazooka:openConfigDialog(opts)
    -- this function will be overwritten by the Options module when loaded
    if (not self.optionsLoaded) then
        self:loadOptions()
        return self:openConfigDialog(opts)
    end
    InterfaceOptionsFrame_OpenToCategory(self.dummyOpts)
end

-- static dialog setup

function Bazooka:openStaticDialog(dialog, frameArg, textArg1, textArg2)
    local dialogFrame = StaticPopup_Show(dialog, textArg1, textArg2)
    if (dialogFrame) then
        dialogFrame.data = frameArg
    end
end

function Bazooka:closeStaticDialog(dialog)
    StaticPopup_Hide(dialog)
end

StaticPopupDialogs[BzkDialogDisablePlugin] = {
    text = L["Disable %s plugin?"],
    button1 = _G.YES,
    button2 = _G.NO,
    OnAccept = function(frame)
        if (not frame.data) then
            return
        end
        Bazooka:disablePlugin(frame.data)
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

-- END LoD Options muckery

-- register slash command

SLASH_BAZOOKA1 = "/bazooka"
SlashCmdList["BAZOOKA"] = function(msg)
    msg = strtrim(msg or "")
    if (msg == "locked") then
        Bazooka:toggleLocked()
    else
        Bazooka:openConfigDialog()
    end
end

-- CONFIGMODE

CONFIGMODE_CALLBACKS = CONFIGMODE_CALLBACKS or {}
CONFIGMODE_CALLBACKS[AppName] = function(action)
    if (action == "ON") then
         Bazooka:toggleLocked(false)
    elseif (action == "OFF") then
         Bazooka:toggleLocked(true)
    end
end

-- DEBUG
function Bazooka:dump()
    for name, plugin in pairs(self.plugins) do
        if (plugin.db.enabled) then
            printf("%s = { bar%d[%s][%d], width = %d }", plugin.name, plugin.db.bar, plugin.db.area, plugin.db.pos, plugin.frame:GetWidth())
            self:showPoints(plugin.frame)
        end
    end
end

function Bazooka:showPoints(frame)
    if (type(frame) ~= "table") then
        frame = _G[frame]
        if (type(frame) ~= "table") then
            print("### not a table")
            return
        end
    end
    local numPoints = frame:GetNumPoints()
    printf("### %s: (%d, %d), numPoints: %d", frame:GetName(), frame:GetWidth(), frame:GetHeight(), numPoints)
    for i = 1, numPoints do
        local point, relTo, relPoint, x, y = frame:GetPoint(i)
        printf("Point%d: %s, %s, %s, %d, %d", i, point, (relTo and relTo:GetName() or "nil"), relPoint, x, y)
    end
end
