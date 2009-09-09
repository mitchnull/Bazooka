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

                leftSpacing = 10,
                centerSpacing = 20,
                rightSpacinig = 10,
                
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
                -- bar = 1,
                -- pos = 'left',
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

function Bazooka:createBar()
    local id = #self.bars + 1
    local db = self.db.profile.bars[id]
    local bar = {}
    bar.id = id
    bar.db = db
    bar.frame = CreateFrame("Frame", "BazookaBar_" .. id, UIParent)
    bar.centerFrame = CreateFrame("Frame", "BazookaBarC_" .. id, bar.frame)
    bar.centerFrame:SetPoint("CENTER", bar.frame, "CENTER", 0, 0)
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
    self.needUpdate = nil
    print("### updateAll")
end

function Bazooka:applySettings()
    if (not self:IsEnabled()) then
        self:OnDisable()
        return
    end
    self:toggleLocked(self.db.profile.locked == true)
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
