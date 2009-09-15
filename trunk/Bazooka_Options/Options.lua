local AceConfig = LibStub("AceConfig-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(Bazooka.OptionsAppName)
local LL = LibStub("AceLocale-3.0"):GetLocale(Bazooka.AppName)

local MinFontSize = 5
local MaxFontSize = 30

local lastConfiguredOpts -- stupid hack to remember last open config frame

local _

local FontOutlines = {
    [""] = L["None"],
    ["OUTLINE"] = L["Normal"],
    ["THICKOUTLINE"] = L["Thick"],
}

local FrameStratas = {
    ["HIGH"] = L["High"],
    ["MEDIUM"] = L["Medium"],
    ["LOW"] = L["Low"],
}

local AttachPositions = {
    ['top'] = L["Top"],
    ['bottom'] = L["Bottom"],
    ['none'] = L["None"],
}

function Bazooka:openConfigDialog(opts)
    opts = opts or lastConfiguredOpts
    if (opts) then
        InterfaceOptionsFrame_OpenToCategory(opts)
    else
        InterfaceOptionsFrame_OpenToCategory(self.profiles) -- to expand our tree
        InterfaceOptionsFrame_OpenToCategory(self.opts)
    end
end

function Bazooka:getOption(info)
    return self.db.profile[info[#info]]
end

function Bazooka:setOption(info, value)
    self.db.profile[info[#info]] = value
    self:applySettings()
end

local function dummy()
end

local function yes()
    return true
end

do
    local self = Bazooka

    local mainOptions = {
        type = 'group',
        childGroups = 'tab',
        inline = true,
        name = Bazooka.AppName,
        handler = Bazooka,
        get = "getOption",
        set = "setOption",
        order = 10,
        args = {
            locked = {
                type = 'toggle',
                width = 'full',
                name = L["Locked"],
                order = 110,
                disabled = function()
                    lastConfiguredOpts = nil
                    return false
                end,
            },
        },
    }

    local function registerSubOptions(name, opts)
        local appName = self.AppName .. "." .. name
        AceConfig:RegisterOptionsTable(appName, opts)
        return ACD:AddToBlizOptions(appName, opts.name or name, self.AppName)
    end

    -- BEGIN

    self.optionsLoaded = true

    -- remove dummy options frame, ugly hack
    if (self.dummyOpts) then 
        for k, f in ipairs(INTERFACEOPTIONS_ADDONCATEGORIES) do
            if (f == self.dummyOpts) then
                tremove(INTERFACEOPTIONS_ADDONCATEGORIES, k)
                f:SetParent(UIParent)
                break
            end
        end
        self.dummyOpts = nil
    end

    AceConfig:RegisterOptionsTable(self.AppName, mainOptions)
    self.opts = ACD:AddToBlizOptions(self.AppName, self.AppName)
    self.setupDBOptions = function(self)
        local profiles =  AceDBOptions:GetOptionsTable(self.db)
        LibStub("LibDualSpec-1.0"):EnhanceOptions(profiles, self.db)
        profiles.disabled = function()
            lastConfiguredOpts = self.profiles
            return false
        end
        self.profiles = registerSubOptions('profiles', profiles)
    end

    if (self.db) then -- trickery to make it work with a straight checkout
        self:setupDBOptions()
        self.setupDBOptions = nil
    end
end

