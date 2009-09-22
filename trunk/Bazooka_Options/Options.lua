local Bazooka = Bazooka
local Bar = Bazooka.Bar
local Plugin = Bazooka.Plugin
local Defaults = Bazooka.Defaults

local ACR = LibStub("AceConfigRegistry-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(Bazooka.OptionsAppName)
local LL = LibStub("AceLocale-3.0"):GetLocale(Bazooka.AppName)

local MinFontSize = 5
local MaxFontSize = 30
local MinIconSize = 5
local MaxIconSize = 40

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

local function getColor(dbcolor)
    return dbcolor.r, dbcolor.g, dbcolor.b, dbcolor.a
end

local function setColor(dbcolor, r, g, b, a)
    dbcolor.r, dbcolor.g, dbcolor.b, dbcolor.a = r, g, b, a
end

function Bazooka:openConfigDialog(opts)
    opts = opts or lastConfiguredOpts
    if opts then
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

-- BEGIN Bar stuff

local barOptionArgs = {
    attach = {
        type = 'select',
        name = L["Attach point"],
        values = Bazooka.AttachNames,
        order = 1,
    },
    strata = {
        type = 'select',
        name = L["Strata"],
        desc = L["Frame strata"],
        values = FrameStratas,
        order = 5,
    },
    fadeInCombat =  {
        type = 'toggle',
        name = L["Fade in combat"],
        disabled = function()
            lastConfiguredOpts = Bazooka.barOpts
            return false
        end,
        order = 10,
    },
    fadeOutOfCombat =  {
        type = 'toggle',
        name = L["Fade out of combat"],
        order = 20,
    },
    disableMouseInCombat = {
        type = 'toggle',
        name = L["Disable mouse in combat"],
        order = 30,
    },
    disableMouseOutOfCombat = {
        type = 'toggle',
        name = L["Disable mouse out of combat"],
        order = 40,
    },
    fadeAlpha = {
        type = 'range',
        name = L["Fade opacity"],
        min = 0,
        max = 1.0,
        isPercent = true,
        step = 0.01,
        width = 'full',
        order = 50,
    },
    sideSpacing = {
        type = 'range',
        name = L["Side spacing"],
        min = 0,
        max = 50,
        step = 1,
        order = 60,
    },
    centerSpacing = {
        type = 'range',
        name = L["Center spacing"],
        min = 0,
        max = 50,
        step = 1,
        order = 70,
    },
    iconTextSpacing = {
        type = 'range',
        name = L["Icon-text spacing"],
        min = 0,
        max = 20,
        step = 1,
        order = 80,
    },

    font = {
        type = "select", dialogControl = 'LSM30_Font',
        name = L["Font"],
        --desc = L["Font"],
        values = AceGUIWidgetLSMlists.font,
        order = 90,
    },
    fontSize = {
        type = 'range',
        name = L["Font size"],
        --desc = L["Font size"],
        min = MinFontSize,
        max = MaxFontSize,
        step = 1,
        order = 100,
    },
    fontOutline = {
        type = 'select',
        name = L["Font outline"],
        --desc = L["Font outline"],
        values = FontOutlines,
        order = 110,
    },
    iconSize = {
        type = 'range',
        name = L["Icon size"],
        min = MinIconSize,
        max = MaxIconSize,
        step = 1,
        order = 120,
    },

    labelColor = {
        type = 'color',
        name = L["Label color"],
        hasAlpha = true,
        order = 130,
        get = "getColorOption",
        set = "setColorOption",
    },
    textColor = {
        type = 'color',
        name = L["Text color"],
        hasAlpha = true,
        order = 140,
        get = "getColorOption",
        set = "setColorOption",
    },
    suffixColor = {
        type = 'color',
        name = L["Suffix color"],
        hasAlpha = true,
        order = 150,
        get = "getColorOption",
        set = "setColorOption",
    },

    frameWidth = {
        type = 'range',
        name = L["Width"],
        disabled = "isFrameWidthDisabled",
        min = Defaults.minFrameWidth,
        max = Defaults.maxFrameWidth,
        step = 1,
        order = 160,
    },
    frameHeight = {
        type = 'range',
        name = L["Height"],
        min = Defaults.minFrameHeight,
        max = Defaults.maxFrameHeight,
        step = 1,
        order = 170,
    },

    bg = {
        type = 'group',
        name = "",
--        name = L["Background Options"],
        disabled = "isBGDisabled",
        inline = true,
        order = 200,
        args = {
            bgEnabled = {
                type = 'toggle',
                order = 1,
                name = L["Enable Background"],
                disabled = false,
            },
            bgTexture = {
                type = "select", dialogControl = 'LSM30_Background',
                order = 11,
                name = L["Background Texture"],
                values = AceGUIWidgetLSMlists.background,
            },
            bgBorderTexture = {
                type = "select", dialogControl = 'LSM30_Border',
                order = 12,
                name = L["Border Texture"],
                values = AceGUIWidgetLSMlists.border,
            },
            bgColor = {
                type = "color",
                order = 13,
                name = L["Background Color"],
                hasAlpha = true,
                get = "getColorOption",
                set = "setColorOption",
            },
            bgBorderColor = {
                type = "color",
                order = 14,
                name = L["Border Color"],
                hasAlpha = true,
                get = "getColorOption",
                set = "setColorOption",
            },
            bgTile = {
                type = "toggle",
                order = 2,
                name = L["Tile Background"],
            },
            bgTileSize = {
                type = "range",
                order = 16,
                name = L["Background Tile Size"],
                desc = L["The size used to tile the background texture"],
                min = 16, max = 256, step = 1,
                disabled = "isTileSizeDisabled",
            },
            bgEdgeSize = {
                type = "range",
                order = 17,
                name = L["Border Thickness"],
                min = 1, max = 16, step = 1,
            },
        },
    },
    removeBar = {
        type = 'execute',
        name = L["Remove Bar"],
        confirm = true,
        width = 'full',
        func = function(info)
            Bazooka:removeBar(info.handler)
        end,
        order = 300,
    },
}

local barOptions = {
    type = 'group',
    childGroups = 'tab',
    inline = true,
    name = L["Bars"],
    get = "getOption",
    set = "setOption",
    order = 10,
    args = {
    },
}

function Bar:isBGDisabled()
    return not self.db.bgEnabled
end

function Bar:isFrameWidthDisabled()
    return self.db.attach ~= 'none'
end

function Bar:isTileSizeDisabled()
    return not (self.db.bgEnabled and self.db.bgTile)
end

function Bar:setOption(info, value)
    self.db[info[#info]] = value
    self:applySettings()
end

function Bar:getOption(info)
    return self.db[info[#info]]
end

function Bar:setColorOption(info, r, g, b, a)
    setColor(self.db[info[#info]], r, g, b, a)
    self:applySettings()
end

function Bar:getColorOption(info)
    return getColor(self.db[info[#info]])
end

local function makeBarOptions(bar)
    return {
        type = 'group',
        inline = false,
        name = LL["Bar"] .. '#' .. bar.id,
        handler = bar,
        order = bar.id,
        args = barOptionArgs,
    }
end

local function addBarOptions(bar)
    if not bar.opts then
        bar.opts = makeBarOptions(bar)
    end
    bar.opts.handler = bar
end

local origCreateBar = Bazooka.createBar
function Bazooka:createBar(...)
    local bar = origCreateBar(self, ...)
    addBarOptions(bar)
    self:updateBarOptions()
    return bar
end

local origRemoveBar = Bazooka.removeBar
function Bazooka:removeBar(...)
    origRemoveBar(self, ...)
    self:updateBarOptions()
end

function Bazooka:updateBarOptions()
    wipe(barOptions.args)
    for i = 1, self.numBars do
        local bar = self.bars[i]
        addBarOptions(bar)
        barOptions.args["bar" .. bar.id] = bar.opts
    end
    ACR:NotifyChange(self.AppName .. ".bars")
end

-- END Bar stuff

-- BEGIN Plugin stuff

local pluginOptions = {
    type = 'group',
    childGroups = 'tree',
    inline = true,
    name = L["Plugins"],
    get = "getOption",
    set = "setOption",
    order = 10,
    args = {
    },
}

local pluginOptionArgs = {
    enabled = {
        type = 'toggle',
        width = 'full',
        name = L["Enabled"],
        order = 10,
        disabled = function()
            lastConfiguredOpts = Bazooka.pluginOpts
            return false
        end,
    },
--    bar = 1,
--    area = 'left',
--    pos = nil,
    showIcon = {
        type = 'toggle',
        name = L["Show icon"],
        order = 120,
        disabled = "isDisabled",
    },
    showLabel = {
        type = 'toggle',
        name = L["Show label"],
        order = 130,
        disabled = "isDisabled",
    },
    showTitle = {
        type = 'toggle',
        name = L["Show title"],
        order = 140,
        disabled = "isTitleDisabled",
    },
    showText = {
        type = 'toggle',
        name = L["Show text"],
        order = 150,
        disabled = "isDisabled",
    },
    hideTipOnClick = {
        type = 'toggle',
        name = L["Hide tooltip on click"],
        order = 200,
        disabled = "isDisabled",
    },
    disableTooltip = {
        type = 'toggle',
        name = L["Disable tooltip"],
        order = 200,
        disabled = "isDisabled",
    },
    disableTooltipInCombat = {
        type = 'toggle',
        name = L["Disable tooltip in combat"],
        order = 210,
        disabled = "isDisabled",
    },
    disableMouseInCombat = {
        type = 'toggle',
        name = L["Disable mouse in combat"],
        order = 220,
        disabled = "isDisabled",
    },
    disableMouseOutOfCombat = {
        type = 'toggle',
        name = L["Disable mouse out of combat"],
        order = 230,
        disabled = "isDisabled",
    },
    shrinkThreshold = {
        type = 'range',
        name = L["Shrink threshold"],
        order = 300,
        min = 0,
        max = 100,
        step = 1,
        disabled = "isDisabled",
    },
}

function Plugin:getColoredTitle()
    return self.db.enabled and self.title or "|cCCed1100" .. self.title .."|r"
end

function Plugin:setOption(info, value)
    self.db[info[#info]] = value
    self:applySettings()
    if info[#info] == 'enabled' then
        if value then
            Bazooka:attachPlugin(self)
        end
        plugin.opts.name = self:getColoredTitle()
        -- ACR:NotifyChange(Bazooka.AppName .. ".plugins")
    end
end

function Plugin:getOption(info)
    return self.db[info[#info]]
end

function Plugin:isDisabled()
    return not self.db.enabled
end

function Plugin:isTitleDisabled()
    return not (self.db.enabled and self.db.showLabel)
end

local function makePluginOptions(plugin)
    return {
        type = 'group',
        inline = false,
        name = plugin:getColoredTitle(),
        handler = plugin,
        args = pluginOptionArgs,
    }
end

local function addPluginOptions(plugin)
    if not plugin.opts then
        plugin.opts = makePluginOptions(plugin)
    end
    plugin.opts.handler = plugin
    return plugin
end

local origCreatePlugin = Bazooka.createPlugin
function Bazooka:createPlugin(...)
    local plugin = origCreatePlugin(self, ...)
    addPluginOptions(plugin)
    pluginOptions.args[plugin.name] = plugin.opts
    ACR:NotifyChange(self.AppName .. ".plugins")
    return plugin
end

-- END Plugin stuff

local origProfileChanged = Bazooka.profileChanged
function Bazooka:profileChanged(...)
    origProfileChanged(self, ...)
    self:updateBarOptions()
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
                name = L["Locked"],
                order = 10,
                disabled = function()
                    lastConfiguredOpts = nil
                    return false
                end,
            },
            simpleTip = {
                type = 'toggle',
                name = L["Enable Simple Tooltips"],
                order = 20,
            },
            adjustFrames = {
                type = 'toggle',
                name = L["Adjust Frames"],
                order = 30,
            },
            enableHL = {
                type = 'toggle',
                name = L["Enable Highlight"],
                order = 40,
            },
            fadeOutDelay = {
                type = 'range',
                width = 'full',
                name = L["Fade-out delay"],
                min = 0,
                max = 5,
                step = 0.1,
                order = 50,
            },
            fadeOutDuration = {
                type = 'range',
                width = 'full',
                name = L["Fade-out duration"],
                min = 0,
                max = 3,
                step = 0.05,
                order = 60,
            },
            fadeInDuration = {
                type = 'range',
                width = 'full',
                name = L["Fade-in duration"],
                min = 0,
                max = 3,
                step = 0.05,
                order = 70,
            },
            createBar = {
                type = 'execute',
                name = L["Create New Bar"],
                width = 'full',
                func = function()
                    Bazooka:createBar()
                end,
                order = 100,
            },
        },
    }

    local function registerSubOptions(name, opts)
        local appName = self.AppName .. "." .. name
        ACR:RegisterOptionsTable(appName, opts)
        return ACD:AddToBlizOptions(appName, opts.name or name, self.AppName)
    end

    -- BEGIN

    self.optionsLoaded = true

    -- remove dummy options frame, ugly hack
    if self.dummyOpts then 
        for k, f in ipairs(INTERFACEOPTIONS_ADDONCATEGORIES) do
            if f == self.dummyOpts then
                tremove(INTERFACEOPTIONS_ADDONCATEGORIES, k)
                f:SetParent(UIParent)
                break
            end
        end
        self.dummyOpts = nil
    end

    ACR:RegisterOptionsTable(self.AppName, mainOptions)
    self.opts = ACD:AddToBlizOptions(self.AppName, self.AppName)
    self.barOpts = registerSubOptions('bars', barOptions)
    self.pluginOpts = registerSubOptions('plugins', pluginOptions)
    self:updateBarOptions()
    for name, plugin in pairs(self.plugins) do
        addPluginOptions(plugin)
        pluginOptions[name] = plugin.opts
    end
    self.setupDBOptions = function(self)
        local profiles =  AceDBOptions:GetOptionsTable(self.db)
        LibStub("LibDualSpec-1.0"):EnhanceOptions(profiles, self.db)
        profiles.disabled = function()
            lastConfiguredOpts = self.profiles
            return false
        end
        self.profiles = registerSubOptions('profiles', profiles)
    end

    if self.db then -- trickery to make it work with a straight checkout
        self:setupDBOptions()
        self.setupDBOptions = nil
    end
end

-- FIXME:
--[[
 - setText() misbehaves with showLabel/showTitle/showText changes
 - color plugin names in list if disabled
 - separate launchers?
 - add bar/area selector ?
 - 
]]--
