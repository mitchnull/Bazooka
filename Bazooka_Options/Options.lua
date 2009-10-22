local Bazooka = Bazooka
local Bar = Bazooka.Bar
local Plugin = Bazooka.Plugin
local Defaults = Bazooka.Defaults

local ACR = LibStub("AceConfigRegistry-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(Bazooka.OptionsAppName)
local LibDualSpec = LibStub:GetLibrary("LibDualSpec-1.0", true)

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

local BarNames = {
    [1] = Bazooka:getBarName(1),
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
    frameWidth = {
        type = 'range',
        name = L["Width"],
        disabled = "isFrameWidthDisabled",
        min = Defaults.minFrameWidth,
        max = Defaults.maxFrameWidth,
        step = 1,
        order = 55,
    },
    frameHeight = {
        type = 'range',
        name = L["Height"],
        min = Defaults.minFrameHeight,
        max = Defaults.maxFrameHeight,
        step = 1,
        order = 56,
    },
    fitToContentWidth = {
        type = 'toggle',
        name = L["Fit to content width"],
        disabled = "isFrameWidthDisabled",
        order = 57,
        width = 'full',
    },

    leftSpacing = {
        type = 'range',
        name = L["Left spacing"],
        min = 0,
        max = 50,
        step = 1,
        order = 60,
    },
    rightSpacing = {
        type = 'range',
        name = L["Right spacing"],
        min = 0,
        max = 50,
        step = 1,
        order = 61,
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

    pluginStyleHeader = {
        type = 'header',
        name = L["Plugin display settings"],
        order = 89,
    },
    font = {
        type = "select", dialogControl = 'LSM30_Font',
        name = L["Font"],
        values = AceGUIWidgetLSMlists.font,
        order = 90,
    },
    fontSize = {
        type = 'range',
        name = L["Font size"],
        min = MinFontSize,
        max = MaxFontSize,
        step = 1,
        order = 100,
    },
    fontOutline = {
        type = 'select',
        name = L["Font outline"],
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
        order = 130,
        get = "getColorOption",
        set = "setColorOption",
    },
    textColor = {
        type = 'color',
        name = L["Text color"],
        order = 140,
        get = "getColorOption",
        set = "setColorOption",
    },
    suffixColor = {
        type = 'color',
        name = L["Suffix color"],
        order = 150,
        get = "getColorOption",
        set = "setColorOption",
    },
    pluginOpacity = {
        type = 'range',
        name = L["Opacity"],
        order = 155,
        min = 0,
        max = 1.0,
        isPercent = true,
        step = 0.01,
    },

    bgHeader = {
        type = 'header',
        name = L["Background settings"],
        order = 199,
    },
    bg = {
        type = 'group',
        name = "",
        disabled = "isBGDisabled",
        inline = true,
        order = 200,
        args = {
            bgEnabled = {
                type = 'toggle',
                order = 1,
                name = L["Enable background"],
                disabled = false,
            },
            bgTexture = {
                type = "select", dialogControl = 'LSM30_Background',
                order = 11,
                name = L["Background texture"],
                values = AceGUIWidgetLSMlists.background,
            },
            bgBorderTexture = {
                type = "select", dialogControl = 'LSM30_Border',
                order = 12,
                name = L["Border texture"],
                values = AceGUIWidgetLSMlists.border,
            },
            bgColor = {
                type = "color",
                order = 13,
                name = L["Background color"],
                hasAlpha = true,
                get = "getColorOption",
                set = "setColorOption",
            },
            bgBorderColor = {
                type = "color",
                order = 14,
                name = L["Border color"],
                hasAlpha = true,
                get = "getColorOption",
                set = "setColorOption",
            },
            bgTile = {
                type = "toggle",
                order = 2,
                name = L["Tile background"],
            },
            bgTileSize = {
                type = "range",
                order = 16,
                name = L["Background tile size"],
                desc = L["The size used to tile the background texture"],
                min = 16, max = 256, step = 1,
                disabled = "isTileSizeDisabled",
            },
            bgEdgeSize = {
                type = "range",
                order = 17,
                name = L["Border thickness"],
                min = 1, max = 16, step = 1,
            },
        },
    },
    tweaksHeader = {
        type = 'header',
        name = L["Tweak anchor positions"],
        order = 209,
    },
    tweakLeft = {
        type = 'input',
        name = L["Left"],
        validate = "isTweakValid",
        disabled = "isTweakDisabled",
        order = 210,
    },
    tweakRight = {
        type = 'input',
        name = L["Right"],
        validate = "isTweakValid",
        disabled = "isTweakDisabled",
        order = 211,
    },
    tweakTop = {
        type = 'input',
        name = L["Top"],
        validate = "isTweakValid",
        disabled = "isTweakDisabled",
        order = 212,
    },
    tweakBottom = {
        type = 'input',
        name = L["Bottom"],
        validate = "isTweakValid",
        disabled = "isTweakDisabled",
        order = 213,
    },
    removeBar = {
        type = 'execute',
        name = L["Remove bar"],
        confirm = function(info)
            return L["Remove %s?"]:format(info.handler.name)
        end,
        width = 'full',
        func = function(info)
            Bazooka:removeBar(info.handler)
            Bazooka:updateBarOptions()
            Bazooka:updatePluginOptions()
        end,
        disabled = function()
            return Bazooka.numBars <= 1
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

function Bar:isTweakDisabled(info)
    if self.db.attach == 'none' then
        return true
    elseif self.db.attach == 'top' then
        return info[#info] == 'tweakBottom'
    elseif self.db.attach == 'bottom' then
        return info[#info] == 'tweakTop'
    end
end

function Bar:isTweakValid(info, value)
    return tonumber(value) ~= nil
end

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
    local name = info[#info]
    self.db[name] = value
    if name == 'leftSpacing' or name == 'rightSpacing' or name == 'centerSpacing' or name == 'fitToContentWidth' then
        self:updateLayout()
    else
        self:applySettings()
    end
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

function Bar:addOptions()
    if not self.opts then
        self.opts = {
            type = 'group',
            inline = false,
            handler = self,
            args = barOptionArgs,
        }
    end
    self.opts.order = self.id
    self.opts.name = self.name
end

function Bazooka:updateBarOptions()
    while #BarNames > self.numBars do
        BarNames[#BarNames] = nil
    end
    wipe(barOptions.args)
    for i = 1, self.numBars do
        local bar = self.bars[i]
        bar:addOptions()
        barOptions.args["bar" .. bar.id] = bar.opts
        BarNames[i] = bar.name
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
    showIcon = {
        type = 'toggle',
        name = L["Show icon"],
        disabled = "isDisabled",
        order = 120,
    },
    showLabel = {
        type = 'toggle',
        name = L["Show label"],
        disabled = "isDisabled",
        order = 130,
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
        disabled = "isDisabled",
        order = 150,
    },
    hideTipOnClick = {
        type = 'toggle',
        name = L["Hide tooltip on click"],
        disabled = "isDisabled",
        order = 200,
    },
    disableTooltip = {
        type = 'toggle',
        name = L["Disable tooltip"],
        disabled = "isDisabled",
        order = 200,
    },
    disableTooltipInCombat = {
        type = 'toggle',
        name = L["Disable tooltip in combat"],
        disabled = "isDisabled",
        order = 210,
    },
    disableMouseInCombat = {
        type = 'toggle',
        name = L["Disable mouse in combat"],
        disabled = "isDisabled",
        order = 220,
    },
    disableMouseOutOfCombat = {
        type = 'toggle',
        name = L["Disable mouse out of combat"],
        disabled = "isDisabled",
        order = 230,
    },
    shrinkThreshold = {
        type = 'range',
        name = L["Shrink threshold"],
        disabled = "isDisabled",
        min = 0,
        max = 100,
        step = 1,
        order = 300,
    },
    bar = {
        type = 'select',
        name = L["Bar"],
        disabled = "isDisabled",
        values = BarNames,
        set = function(info, value)
            local plugin = info.handler
            plugin:detach()
            plugin.db.bar = value
            Bazooka:attachPlugin(plugin)
        end,
        order = 310,
    },
    area = {
        type = 'select',
        name = L["Area"],
        disabled = "isDisabled",
        values = Bazooka.AreaNames,
        set = function(info, value)
            local plugin = info.handler
            plugin:detach()
            plugin.db.area = value
            Bazooka:attachPlugin(plugin)
        end,
        order = 320,
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
        self.opts.name = self:getColoredTitle()
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

function Plugin:addOptions()
    if not self.opts then
        self.opts = {
            type = 'group',
            inline = false,
            handler = self,
            args = pluginOptionArgs,
        }
    end
    self.opts.name = self:getColoredTitle()
end

function Bazooka:updatePluginOptions()
    wipe(pluginOptions.args)
    for name, plugin in pairs(self.plugins) do
        plugin:addOptions()
        pluginOptions.args[name] = plugin.opts
    end
    ACR:NotifyChange(self.AppName .. ".plugins")
end

-- END Plugin stuff

function Bazooka:updateMainOptions()
    ACR:NotifyChange(self.AppName)
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
                name = L["Enable simple tooltips"],
                order = 20,
            },
            adjustFrames = {
                type = 'toggle',
                name = L["Adjust frames"],
                order = 30,
            },
            enableHL = {
                type = 'toggle',
                name = L["Enable highlight"],
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
                name = L["Create new bar"],
                width = 'full',
                func = function()
                    Bazooka:createBar()
                    Bazooka:updateBarOptions()
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
    self:updatePluginOptions()
    self.setupDBOptions = function(self)
        local profiles =  AceDBOptions:GetOptionsTable(self.db)
        if LibDualSpec then
            LibDualSpec:EnhanceOptions(profiles, self.db)
        end
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

