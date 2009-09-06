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

local LSM = LibStub:GetLibrary("LibSharedMedia-3.0", true)
local L = LibStub("AceLocale-3.0"):GetLocale(AppName)

-- internal vars

local _ -- throwaway

-- cached stuff

local GetCursorPosition = GetCursorPosition
local UIParent = UIParent

-- hard-coded config stuff

local DefaultBGTexture = "Blizzard Tooltip"
local DefaultBGFile = [[Interface\Tooltips\UI-Tooltip-Background]]
local DefaultEdgeTexture = "Blizzard Tooltip"
local DefaultEdgeFile = [[Interface\Tooltips\UI-Tooltip-Border]]
local DefaultFontName = "Friz Quadrata TT"
local DefaultFontPath = GameFontNormal:GetFont()
local DefaultFrameWidth = 112
local DefaultFrameHeight = 36
local Icon = [[Interface\Icons\INV_Misc_MissileSmall_Green]]

---------------------------------

Bazooka = LibStub("AceAddon-3.0"):NewAddon(AppName, "AceEvent-3.0")
Bazooka:SetDefaultModuleState(false)

Bazooka.version = VERSION
Bazooka.AppName = AppName
Bazooka.OptionsAppName = OptionsAppName

-- Default DB stuff

local function makeColor(r, g, b, a)
    a = a or 1.0
    return { ["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a }
end

local defaults = {
    profile = {
        locked = false,
    },
}

-- AceAddon stuff

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
end

function Bazooka:OnDisable()
    self:UnregisterAllEvents()
end

function Bazooka:applySettings()
    if (not self:IsEnabled()) then
        self:OnDisable()
        return
    end
    self:toggleLocked(self.db.profile.locked == true)
end

function Bazooka:profileChanged()
    local locked = self.db.profile.locked
    self:applySettings()
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
    local LDB = LibStub:GetLibrary("LibDataBroker-1.1", true)
    if (not LDB) then return end
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

-- LoD Options muckery

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

-- register slash command

SLASH_RANGEDISPLAY1 = "/bazooka"
SlashCmdList["BAZOOKA"] = function(msg)
    msg = strtrim(msg or "")
    if (msg == "locked") then
        Bazooka:toggleLocked()
    else
        Bazooka:openConfigDialog()
    end
end

CONFIGMODE_CALLBACKS = CONFIGMODE_CALLBACKS or {}
CONFIGMODE_CALLBACKS[AppName] = function(action)
    if (action == "ON") then
         Bazooka:toggleLocked(false)
    elseif (action == "OFF") then
         Bazooka:toggleLocked(true)
    end
end
