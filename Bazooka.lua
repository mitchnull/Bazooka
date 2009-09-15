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

---------------------------------

Bazooka = LibStub("AceAddon-3.0"):NewAddon(AppName, "AceEvent-3.0")
local Bazooka = Bazooka

Bazooka:SetDefaultModuleState(false)

Bazooka.version = VERSION
Bazooka.AppName = AppName
Bazooka.OptionsAppName = OptionsAppName

Bazooka.draggedPlugin = nil
Bazooka.draggedBar = nil
Bazooka.bars = {}
Bazooka.plugins = {}
Bazooka.disableUpdates = nil
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
        self.frame.bzkBar = bar
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

function Bar:getSpacing(area)
    if (area == 'left' or area == 'right') then
        return self.db.sideSpacing
    else
        return self.db.centerSpacing
    end
end

function Bar:highlight(x, w)
    if (not x) then
        if (self.hl) then
            self.hl:Hide()
        end
        return
    end
    if (not self.hl) then
        self.hl = self.frame:CreateTexture("BazookaBarHL_" .. self.id, "OVERLAY")
        self.hl:SetTexture(HighlightImage)
    end
    if (not w or w <= 0) then
        w = 2
    end
    self.hl:ClearAllPoints()
    self.hl:SetPoint("TOP", self.frame, "TOP", 0, 0)
    self.hl:SetPoint("BOTTOM", self.frame, "BOTTOM", 0, 0)
    self.hl:SetPoint("LEFT", self.frame, "LEFT", x - w, 0)
    self.hl:SetPoint("RIGHT", self.frame, "LEFT", x + w, 0)
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
    plugin.frame:ClearAllPoints()
    self:setRightAttachPoint(lp, rp)
    self:setLeftAttachPoint(rp, lp)
    if (plugin.area == 'center') then
        self:updateCenterWidth()
    end
    self.allPlugins[plugin.name] = nil
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
    self.allPlugins[plugin.name] = plugin
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
        printf("### fetching: %s -> %s", tostring(self.db.bgBorderTexture), tostring(bg.edgeFile))
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
    printf("### edgeSize: %d", bg.edgeSize)
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
        if (not dbFontPath) then
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

    OnEnter = function(frame)
        frame.bzkPlugin:highlight(true)
    end,
    OnLeave = function(frame)
        frame.bzkClicked = nil
        frame.bzkPlugin:highlight(false)
    end,
    OnMouseDown = function(frame, ...)
        frame.bzkClicked = true
    end,
    OnMouseUp = function(frame, ...)
        if (not frame.bzkClicked or frame:IsDragging()) then
            return
        end
        local self = frame.bzkPlugin
        if (self.dataobj.OnClick) then
            self.dataobj.OnClick(frame, ...)
        end
    end,
    OnDragStart = function(frame, ...)
        frame.bzkClicked = nil
        frame:SetAlpha(0.5)
        frame.bzkPlugin:detach()
        frame:StartMoving()
    end,
    OnDragStop = function(frame, ...)
        frame:StopMovingOrSizing()
        frame:SetAlpha(1.0)
        frame.bzkPlugin:attach() -- FIXME: check for valid drop position
    end,
}

setDeepCopyIndex(Plugin)

function Plugin:New(name, dataobj, db)
    local plugin = setmetatable({}, Plugin)
    plugin.name = name
    plugin.dataobj = dataobj
    plugin.db = db
    plugin:updateLabel()
    plugin:applySettings()
    return plugin
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
        if (self.bar and self.area == 'center') then
            self.bar:updateCenterWidth()
        end
    end
end

function Plugin:enable()
    if (not self.frame) then
        self.frame = CreateFrame("Frame", "BazookaPlugin_" .. self.name, UIParent)
        self.frame.bzkPlugin = self
        -- FIXME
        self.frame:SetScript("OnEnter", Plugin.OnEnter)
        self.frame:SetScript("OnLeave", Plugin.OnLeave)
        self.frame:SetScript("OnMouseUp", Plugin.OnMouseUp)
        self.frame:SetScript("OnMouseDown", Plugin.OnMouseDown)
        self.frame:SetScript("OnDragStart", Plugin.OnDragStart)
        self.frame:SetScript("OnDragStop", Plugin.OnDragStop)
        self.frame:EnableMouse(true)
    end
    self.frame:Show()
    if (Bazooka.db.profile.locked) then
        self:lock()
    else
        self:unlock()
    end
end

function Plugin:disable()
    if (self.frame) then
        self.frame:ClearAllPoints()
        self.frame:Hide()
    end
end

function Plugin:applySettings()
    if (not self.db.enabled) then
        self:disable()
        return
    end
    self:enable()
    if (self.db.showIcon) then
        if (not self.icon) then
            self:createIcon()
        end
        self:setIcon()
        self.icon:Show()
    elseif (self.icon) then
        self.icon:Hide()
    end
    if (true and (self.db.showText or self.db.showLabel)) then
        if (not self.text) then
            self:createText(self)
        end
        self:setText()
    elseif (self.text) then
        self.text:SetFormattedText("")
        self.text:Hide()
    end
    self:updateLayout()
end

function Plugin:lock()
    if (self.frame) then
        if (self.frame:IsDragging()) then
            self.frame:StopMovingOrSizing()
        end
        self.frame:RegisterForDrag(nil)
        self.frame:SetMovable(false)
    end
end

function Plugin:unlock()
    if (self.frame) then
        self.frame:RegisterForDrag("LeftButton")
        self.frame:SetMovable(true)
    end
end

function Plugin:setIcon()
    local dataobj = self.dataobj
    local icon = self.icon
    if (not dataobj.icon) then
        icon:SetTexture(MissingIcon)
        -- FIXME: maybe we need to SetTexCoord() and SetVertexColor() here?
    end
    icon:SetTexture(dataobj.icon)
    if (dataobj.iconR) then
        icon.SetVertexColor(dataobj.iconR, dataobj.iconG, dataobj.iconB)
    end
    if (dataobj.iconCoords) then
        icon:SetTexCoord(dataobj.iconCoords)
    end
end

function Plugin:setText()
    local dataobj = self.dataobj
    if (self.db.showLabel) then
        if (dataobj.text) then
            self.text:SetFormattedText("|c%s%s:|r %s", self.labelColorHex, self.label, dataobj.text)
        elseif (dataobj.value and dataobj.suffix) then
            self.text:SetFormattedText("|c%s%s:|r %s %s", self.labelColorHex, self.label, dataobj.value, dataobj.suffix)
        else
            self.text:SetFormattedText("|c%s%s|r", self.labelColorHex, self.label)
        end
    else
        if (dataobj.text) then
            self.text:SetFormattedText("%s", dataobj.text)
        elseif (dataobj.value and dataobj.suffix) then
            self.text:SetFormattedText("%s |c%s%s|r", dataobj.value, self.suffixColorHex, dataobj.suffix)
        else
            self.text:SetFormattedText("")
        end
    end
end

function Plugin:updateLabel()
    self.label = self.dataobj.label or self.name
    -- FIXME: muck around with dataobj.tocname?
end

function Plugin:attach()
    if (self.bar) then
        self.bar:attachPlugin(self, self.db.area, self.db.pos)
    end
end

function Plugin:detach()
    if (self.bar) then
        self.bar:detachPlugin(self)
    end
end

Bazooka.Plugin = Plugin

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
    print("### new DO: " .. tostring(name) .. " : " .. tostring(event))
    local plugin = self:createPlugin(name, dataobj)
end

function Bazooka:attributeChanged(event, name, attr, value, dataobj)
    print("### " .. tostring(name) .. "." .. tostring(attr) .. " = " ..  tostring(value))
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
    self:toggleLocked(self.db.profile.locked)
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

function Bazooka:attachPlugin(plugin)
    local bar = self.bars[plugin.db.bar]
    if (not bar) then
        self.bars[1]:attachPlugin(plugin)
    else
        bar:attachPlugin(plugin, plugin.db.area, plugin.db.pos)
    end
end

function Bazooka:initPlugins()
    local du = self.disableUpdates
    self.disableUpdates = true
    for name, dataobj in LDB:DataObjectIterator() do
        self:dataObjectCreated(nil, name, dataobj)
    end
    self.disableUpdates = du
    self:updateAll()
end

function Bazooka:updateAll()
    if (self.disableUpdates or InCombatLockdown()) then
        self.needUpdate = true
        return
    end
    self.needUpdate = false
    print("### updateAll")
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

function Bazooka:lock()
    self.db.profile.locked = true
    self.ldb.icon = Icon
    for name, plugin in pairs(self.plugins) do
        plugin:lock()
    end
end

function Bazooka:unlock()
    self.db.profile.locked = false
    self.ldb.icon = UnlockedIcon
    for name, plugin in pairs(self.plugins) do
        plugin:unlock()
    end
end

function Bazooka:toggleLocked(flag)
    if (flag == nil) then flag = not self.db.profile.locked end
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
        printf("%s = { bar%d[%s][%d], width = %d }", plugin.name, plugin.db.bar, plugin.db.area, plugin.db.pos, plugin.frame:GetWidth())
        self:showPoints(plugin.frame)
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