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

-- cached stuff

local GetCursorPosition = GetCursorPosition
local UIParent = UIParent
local InCombatLockdown = InCombatLockdown
local tinsert = tinsert

-- hard-coded config stuff

local DefaultBGTexture = "Blizzard Tooltip"
local DefaultBGFile = [[Interface\Tooltips\UI-Tooltip-Background]]
local DefaultEdgeTexture = "Blizzard Tooltip"
local DefaultEdgeFile = [[Interface\Tooltips\UI-Tooltip-Border]]
local DefaultFontName = "Friz Quadrata TT"
local DefaultFontPath = GameFontNormal:GetFont()
local DefaultFrameWidth = 112
local DefaultFrameHeight = 36
local Icon = [[Interface\Icons\INV_Gizmo_SuperSapperCharge]]
local MissingIcon = nil

local IconTextSpacing = 4

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

-- Default DB stuff

local function makeColor(r, g, b, a)
    a = a or 1.0
    return { ["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a }
end

local defaults = {
    profile = {
        locked = false,
        adjustFrames = false,
        simpleTip = true,
        defaults = {
            bars = {
                splitCenter = false,
                singleCentered = true,

                sideSpacing = 10,
                centerSpacing = 20,
                
                attach = 'top',

                font = DefaultFontName,
                fontSize = 12,
                fontOutline = "",

                labelColor = makeColor(1.0, 1.0, 1.0),
                textColor = makeColor(1.0, 0.82, 0),

                strata = "HIGH",

                frameWidth = DefaultFrameWidth,
                frameHeight = DefaultFrameHeight,

                bgEnabled = true,
                bgTexture = DefaultBGTexture,
                bgBorderTexture = DefaultEdgeTexture,
                bgTile = false,
                bgTileSize = 32,
                bgEdgeSize = 16,
                bgColor = makeColor(0, 0, 0, 0.7),
                bgBorderColor = makeColor(0.8, 0.6, 0.0),

            },
            plugins = {
                enabled = true,
                -- bar = 1,
                -- area = 'left',
                -- pos = nil,
                disableTooltip = false,
                disableTooltipInCombat = true,
                disableMouseInCombat = false,
                showIcon = true,
                showLabel = false,
                showText = true,
            },
        },
        bars = {},
        plugins = {},
    },
}

local function copyTable(src, dst)
    if (type(dst) ~= "table") then dst = {} end
    if (type(src) == "table") then
        for k, v in pairs(src) do
            if (type(v) == "table") then
                v = copyTable(v, dst[k])
            end
            dst[k] = v
        end
    end
    return dst
end

-- BEGIN Bar stuff

local Bar = {
    id = nil,
    db = nil,
    frame = nil,
    centerFrame = nil,
    plugins = {
        left = {},
        cleft = {},
        center = {},
        cright = {},
        right = {},
    },
    inset = 0,
    backdrop = nil,
}

function Bar:New(id, db)
    local bar = copyTable(Bar)
    bar.id = id
    bar.db = db
    bar.frame = CreateFrame("Frame", "BazookaBar_" .. id, UIParent)
    bar.centerFrame = CreateFrame("Frame", "BazookaBarC_" .. id, bar.frame)
    bar.centerFrame:EnableMouse(false)
    bar.centerFrame:SetPoint("CENTER", bar.frame, "CENTER", 0, 0)
    return bar
end

function Bar:attachPlugin(plugin, area, pos)
    area = area or "left"
    plugin.db.bar = self.id
    plugin.db.area = area
    local plugins = self.plugins[area]
    local lp, rp
    if (not pos) then
        local count = #self.plugins[area]
        if (count > 0) then
            lp = plugins[count]
            plugin.db.pos = lp.pos + 1
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
        tinsert(plugins, plugin, rpi)
    end
    plugin.frame:SetParent(self.frame)
    plugin.frame:ClearAllPoints()
    plugin.frame:SetPoint("TOP", self.frame, "TOP")
    plugin.frame:SetPoint("BOTTOM", self.frame, "BOTTOM")
    self:setLeftAttachPoint(plugin, lp)
    self:setRightAttachPoint(plugin, rp)
    self:setRightAttachPoint(lp, plugin)
    self:setLeftAttachPoint(rp, plugin)
    if (area == "center") then
        self.centerFrame:SetWidth(self:calculateCenterWidth())
    end
end

function Bar:calculateCenterWidth()
    local cw = 0
    for i, p in ipairs(self.plugins.center) do
        cw = cw + p.frame:GetWidth()
    end
    local numGaps = #self.plugins.center - 1
    if (numGaps > 0) then
        cw = cw + (numGaps * self.db.centerSpacing)
    end
    return cw
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
            plugin.frame:SetPoint("LEFT", self.centerFrame, "LEFT", 0, 0)
        end
    elseif (area == "cright") then
        if (lp) then
            plugin.frame:SetPoint("LEFT", lp.frame, "RIGHT", self.db.centerSpacing, 0)
        else
            plugin.frame:SetPoint("LEFT", self.centerFrame, "RIGHT", self.db.centerSpacing, 0)
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
            plugin.frame:SetPoint("RIGHT", self.centerFrame, "LEFT", -self.db.centerSpacing, 0)
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
    -- TODO
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
}

function Plugin:New(name, dataobj, db)
    local plugin = copyTable(Plugin)
    plugin.name = name
    plugin.dataobj = dataobj
    plugin.db = db
    plugin:updateLabel()
    plugin:applySettings()
    return plugin
end

function Plugin:createIcon()
    self.icon = self.frame:CreateTexture("BazookaPluginIcon_" .. self.name, "ARTWORK")
    self.icon:ClearAllPoints()
    local iconSize = self.db.fontSize
    self.icon:SetWidth(iconSize)
    self.icon:SetHeight(iconSize)
    self.icon:SetPoint("LEFT", self.frame, "LEFT", 0, 0)
end

function Plugin:createText()
    self.text = self.frame:CreateFontString("BazookaPluginText_" .. self.name, "ARTWORK", "GameFontNormal")
    self.textSetFont(DefaultFontPath, 10, "")
end

function Plugin:updateLayout()
    if (self.db.showText) then
        local tw = self.text:GetStringWidth()
        local offset = self.showIcon and (self.icon.getWidth() + IconTextSpacing) or 0
        self.text:SetPoint("LEFT", self.frame, "LEFT", offset, 0)
        self.frame:SetWidth(offset + tw)
    elseif (self.hasIcon) then
        self.frame:SetWidth(self.icon.GetWidth())
    else
        self.frame:SetWidth(0)
    end
end

function Plugin:enable()
    self.db.enabled = true
    if (not self.frame) then
        self.frame = CreateFrame("Frame", "BazookaPlugin_" .. self.name, UIParent)
    end
    self.frame:Show()
end

function Plugin:disable()
    self.db.enabled = false
    if (self.frame) then
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
        self.icon:SetTexture(self.dataobj.icon or MissingIcon)
        self.icon:Show()
    elseif (self.icon) then
        self.icon:Hide()
    end
    if (self.db.showText or self.db.showLabel) then
        if (not self.text) then
            self:createText(self)
        end
        self.text:SetFormattedText(self:getFormattedText())
    elseif (self.text) then
        self.text:SetFormattedText("")
        self.text:Hide()
    end
    self:updateLayout()
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
    -- FIXME: label/suffix color?
    if (self.db.showLabel) then
        if (dataobj.text) then
            self.text:SetFormattedText("%s: %s", self.label, dataobj.text)
        elseif (dataobj.value and dataobj.suffix) then
            self.text:SetFormattedText("%s: %s %s", self.label, dataobj.value, dataobj.suffix)
        else
            self.text:SetFormattedText(self.label)
        end
    else
        if (dataobj.text) then
            self.text:SetFormattedText(dataobj.text)
        elseif (dataobj.value and dataobj.suffix) then
            self.text:SetFormattedText("%s %s", dataobj.value, dataobj.suffix)
        else
            self.text:SetFormattedText("")
        end
    end
end

function Plugin:updateLabel()
    self.label = self.dataobj.label or self.name
    -- FIXME: muck around with dataobj.tocname?
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
    self:initPlugins()
    LDB.RegisterCallback(self, "LibDataBroker_DataObjectCreated", "dataObjectCreated")
    LDB.RegisterCallback(self, "LibDataBroker_AttributeChanged", "attributeChanged")
    if (#self.bars == 0) then
        self:createBar()
    end
    for i, bar in ipairs(self.bars) do
        bar.frame:Show()
    end
end

function Bazooka:OnDisable()
    self:UnregisterAllEvents()
    LDB.UnregisterAllCallbacks(self)
    for i, bar in ipairs(self.bars) do
        bar.frame:Hide()
    end
end

-- END AceAddon stuff

-- BEGIN handlers

function Bazooka:dataObjectCreated(name, dataobj)
    print("### new DO: " .. tostring(name))
end

function Bazooka:attributeChanged(name, attr, value, dataobj)
    print("### " .. tostring(name) .. "." .. tostring(attr) .. " = " ..  tostring(value))
end

function Bazooka:profileChanged()
    local locked = self.db.profile.locked
    self:applySettings()
end

-- END handlers

function Bazooka:createBar()
    local id = #self.bars + 1
    local db = self.db.profile.bars[id]
    if (not db) then
        db = copyTable(self.db.profile.defaults.bars)
        self.db.profile.bars[id] = db
    end
    return Bar:New(id, db)
end

function Bazooka:createPlugin(name, dataobj)
    local db = self.db.profile.plugins[name]
    if (not db) then
        db = copyTable(self.db.profile.defaults.plugins)
        self.db.profile.plugins[name] = db
        db.bar = 1
        db.area = "left"
    end
    local plugin = Plugin:New(name, dataobj, db)
    -- FIXME: only if enabled
    if (plugin.db.enabled) then
        self:attachPlugin(plugin, self.bars[plugin.db.bar], plugin.db.area, plugin.db.pos)
    end
    return plugin
end

function Bazooka:initPlugins()
    local du = self.disableUpdates
    self.disableUpdates = true
    for name, dataobj in LDB:DataObjectIterator() do
        self:dataObjectCreated(name, dataobj)
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
end

function Bazooka:unlock()
    self.db.profile.locked = false
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

function Bazooka:openConfigDialog(ud)
    -- this function will be overwritten by the Options module when loaded
    if (not self.optionsLoaded) then
        self:loadOptions()
        return self:openConfigDialog(ud)
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
