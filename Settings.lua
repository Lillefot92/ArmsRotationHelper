-- ============================================================
-- Arms Rotation Helper - Settings.lua
-- In-game configuration panel for rotation, display, preview,
-- positioning, and deterministic simulator controls.
-- ============================================================

local ADDON_NAME, ns = ...

local PANEL_WIDTH = 620
local PANEL_HEIGHT = 610

local panel = CreateFrame(
    "Frame",
    "ArmsRotationHelperSettingsPanel",
    UIParent,
    "BackdropTemplate"
)
panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
panel:SetPoint("CENTER")
panel:SetFrameStrata("DIALOG")
panel:SetClampedToScreen(true)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 10, right = 10, top = 10, bottom = 10 },
})
panel:Hide()

panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

local closeButton = CreateFrame(
    "Button",
    nil,
    panel,
    "UIPanelCloseButton"
)
closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -22)
title:SetText("Arms Rotation Helper")

local versionText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
versionText:SetPoint("LEFT", title, "RIGHT", 10, -1)
versionText:SetText(ns.VERSION)

local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -7)
subtitle:SetWidth(PANEL_WIDTH - 48)
subtitle:SetJustifyH("LEFT")
subtitle:SetText(
    "Configure the advisor here. Changes apply immediately and all existing slash commands still work."
)

local function CreateSectionHeader(text, x, y, width)
    local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
    header:SetText(text)

    local line = panel:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.35, 0.55, 0.90, 0.55)
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    line:SetSize(width, 1)
    return header
end

local rotationHeader = CreateSectionHeader("Rotation", 24, -78, 270)
local displayHeader = CreateSectionHeader("Display", 326, -78, 270)
local toolsHeader = CreateSectionHeader("Preview and simulator", 24, -382, 572)

local controls = {}
local refreshing = false

local function ApplyDisplaySettings()
    if ns.Display_ApplySettings then ns.Display_ApplySettings() end
end

local function CreateCheckbox(name, label, description, x, y, setting)
    local checkbox = CreateFrame(
        "CheckButton",
        name,
        panel,
        "UICheckButtonTemplate"
    )
    checkbox:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)

    local checkboxText = _G[name .. "Text"]
    checkboxText:SetText(label)
    checkboxText:SetWidth(230)
    checkboxText:SetJustifyH("LEFT")

    checkbox.description = description
    checkbox:SetScript("OnEnter", function(self)
        if not self.description then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label, 1, 0.82, 0)
        GameTooltip:AddLine(self.description, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)

    checkbox:SetScript("OnClick", function(self)
        if refreshing or not ns.db then return end
        ns.db[setting] = self:GetChecked() == true
        ApplyDisplaySettings()
        ns.Settings_Refresh()
    end)

    controls[setting] = checkbox
    return checkbox
end

local function CreateDropdown(name, label, x, y, width, options, getValue, setValue)
    local labelText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelText:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
    labelText:SetText(label)

    local dropdown = CreateFrame(
        "Frame",
        name,
        panel,
        "UIDropDownMenuTemplate"
    )
    dropdown:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", -16, -3)
    UIDropDownMenu_SetWidth(dropdown, width)

    dropdown.options = options
    dropdown.getValue = getValue
    dropdown.setValue = setValue

    UIDropDownMenu_Initialize(dropdown, function(_, level)
        for _, option in ipairs(dropdown.options) do
            local optionValue = option.value
            local optionLabel = option.label
            local info = UIDropDownMenu_CreateInfo()
            info.text = optionLabel
            info.value = optionValue
            info.checked = dropdown.getValue() == optionValue
            info.func = function()
                dropdown.setValue(optionValue)
                ns.Settings_Refresh()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    return dropdown
end

local modeDropdown = CreateDropdown(
    "ArmsRotationHelperModeDropdown",
    "Target mode",
    28,
    -112,
    220,
    {
        { value = "auto", label = "Automatic target count" },
        { value = "single", label = "Force single target" },
        { value = "aoe", label = "Force multi-target" },
    },
    function() return ns.db and ns.db.mode or "auto" end,
    function(value)
        if not ns.db then return end
        ns.db.mode = value
        ApplyDisplaySettings()
    end
)

local shoutDropdown = CreateDropdown(
    "ArmsRotationHelperShoutDropdown",
    "Assigned shout",
    28,
    -177,
    220,
    {
        { value = "battle", label = "Battle Shout" },
        { value = "commanding", label = "Commanding Shout" },
    },
    function() return ns.db and ns.db.assignedShout or "battle" end,
    function(value)
        if not ns.db then return end
        ns.db.assignedShout = value
        ApplyDisplaySettings()
    end
)

CreateCheckbox(
    "ArmsRotationHelperStanceCheckbox",
    "Show stance advice",
    "Shows a separate stance icon only when the recommended ability needs a different stance.",
    24,
    -244,
    "stanceAdvice"
)

CreateCheckbox(
    "ArmsRotationHelperSunderCheckbox",
    "Maintain five Sunders",
    "Opt into maintaining five Sunder Armor stacks on durable targets. Leave this off when another player handles armor reduction.",
    24,
    -276,
    "maintainSunder"
)

CreateCheckbox(
    "ArmsRotationHelperLockedCheckbox",
    "Lock recommendation display",
    "When unlocked, drag the main recommendation display with the left mouse button.",
    24,
    -308,
    "locked"
)

local demoShoutCheckbox = CreateCheckbox(
    "ArmsRotationHelperDemoShoutCheckbox",
    "Maintain Improved Demo Shout",
    "Available only with at least one point in Improved Demoralizing Shout. Refreshes your talented debuff as a filler without replacing Slam, Mortal Strike, Whirlwind, or Execute.",
    24,
    -340,
    "maintainDemoShout"
)

CreateCheckbox(
    "ArmsRotationHelperMainIconCheckbox",
    "Main recommendation icon",
    "Shows the primary ability recommendation and its reason.",
    322,
    -112,
    "showIcon"
)

CreateCheckbox(
    "ArmsRotationHelperSwingCheckbox",
    "Main-hand swing bar",
    "Shows the predicted main-hand swing and highlights a valid post-swing Slam.",
    322,
    -144,
    "showSwingBar"
)

CreateCheckbox(
    "ArmsRotationHelperQueueCheckbox",
    "Heroic Strike/Cleave queue",
    "Shows high-Rage next-swing advice separately from the primary global-cooldown recommendation.",
    322,
    -176,
    "showQueue"
)

CreateCheckbox(
    "ArmsRotationHelperGlowCheckbox",
    "Action-bar glow",
    "Highlights a matching visible spell or spell macro on Blizzard, Bartender4, or Dominos bars.",
    322,
    -208,
    "showGlow"
)

CreateCheckbox(
    "ArmsRotationHelperCooldownsCheckbox",
    "Cooldown and trinket row",
    "Shows Death Wish, Recklessness, and usable equipped trinkets.",
    322,
    -240,
    "showCooldowns"
)

CreateCheckbox(
    "ArmsRotationHelperDebugCheckbox",
    "Diagnostic panel",
    "Shows the live combat values used by the recommendation engine. Useful for testing and bug reports.",
    322,
    -272,
    "debugMode"
)

local scaleLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
scaleLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 332, -321)
scaleLabel:SetText("Display scale")

local scaleSlider = CreateFrame(
    "Slider",
    "ArmsRotationHelperScaleSlider",
    panel,
    "OptionsSliderTemplate"
)
scaleSlider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 8, -12)
scaleSlider:SetWidth(230)
scaleSlider:SetMinMaxValues(0.3, 3.0)
scaleSlider:SetValueStep(0.1)

_G[scaleSlider:GetName() .. "Low"]:SetText("0.3")
_G[scaleSlider:GetName() .. "High"]:SetText("3.0")
_G[scaleSlider:GetName() .. "Text"]:SetText("100%")

scaleSlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value * 10 + 0.5) / 10
    _G[self:GetName() .. "Text"]:SetText(
        string.format("%d%%", math.floor(value * 100 + 0.5))
    )
    if refreshing or not ns.db then return end
    ns.db.scale = value
    ApplyDisplaySettings()
end)

local function CreateButton(text, width, x, y, onClick)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local selectedScenario = "all"
local scenarioDropdown = CreateDropdown(
    "ArmsRotationHelperScenarioDropdown",
    "Scenario",
    28,
    -416,
    220,
    {
        { value = "all", label = "Complete suite" },
        { value = "leveling", label = "Leveling" },
        { value = "slam", label = "Slam rhythm" },
        { value = "rage", label = "Rage protection" },
        { value = "execute", label = "Execute phase" },
        { value = "overpower", label = "Overpower stance" },
        { value = "demoralizing", label = "Improved Demo Shout" },
        { value = "aoe", label = "AoE priority" },
        { value = "cleave", label = "Cleave and pooling" },
    },
    function() return selectedScenario end,
    function(value) selectedScenario = value end
)

local statusText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
statusText:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 24, 22)
statusText:SetWidth(PANEL_WIDTH - 48)
statusText:SetJustifyH("LEFT")
statusText:SetTextColor(0.75, 0.82, 0.95, 1)

local statusOverride

local previewButton
previewButton = CreateButton("Start display preview", 180, 326, -416, function()
    if not ns.db then return end
    if ns.Simulator_IsActive and ns.Simulator_IsActive() then
        ns.Simulator_Stop()
    end
    if ns.Display_SetTestMode then
        ns.Display_SetTestMode(not ns.db.testMode)
    end
    statusOverride = nil
    ns.Settings_Refresh()
end)

local startSimulatorButton = CreateButton(
    "Start selected scenario",
    180,
    326,
    -449,
    function()
        if not ns.Simulator_Start then return end
        local ok, err = ns.Simulator_Start(selectedScenario)
        if not ok then
            statusOverride = "|cffff6640" .. tostring(err) .. "|r"
        else
            statusOverride = nil
        end
        ns.Settings_Refresh()
    end
)

local nextSimulatorButton = CreateButton(
    "Next step",
    87,
    326,
    -482,
    function()
        if ns.Simulator_Next then ns.Simulator_Next() end
        statusOverride = nil
        ns.Settings_Refresh()
    end
)

local stopSimulatorButton = CreateButton(
    "Stop",
    87,
    419,
    -482,
    function()
        if ns.Simulator_Stop then ns.Simulator_Stop() end
        statusOverride = nil
        ns.Settings_Refresh()
    end
)

local checkSimulatorButton = CreateButton(
    "Run priority checks",
    180,
    326,
    -515,
    function()
        if not ns.Simulator_RunSelfCheck then return end
        local passed, total, failures = ns.Simulator_RunSelfCheck()
        if passed == total then
            statusOverride = "|cff40ff40" .. passed .. "/" .. total
                .. " rotation checks passed.|r"
        else
            statusOverride = "|cffff4040" .. passed .. "/" .. total
                .. " rotation checks passed. See chat for failures.|r"
            for _, failure in ipairs(failures) do
                print("|cffff6640Arms Rotation Helper simulator:|r " .. failure)
            end
        end
        ns.Settings_Refresh()
    end
)

local resetButton = CreateButton(
    "Reset position and scale",
    220,
    28,
    -515,
    function()
        if not ns.db then return end
        ns.db.point, ns.db.x, ns.db.y, ns.db.scale =
            "CENTER", 0, 250, 1.0
        ApplyDisplaySettings()
        statusOverride = "Display position and scale reset."
        ns.Settings_Refresh()
    end
)

local helpText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
helpText:SetPoint("TOPLEFT", panel, "TOPLEFT", 28, -557)
helpText:SetWidth(PANEL_WIDTH - 56)
helpText:SetJustifyH("LEFT")
helpText:SetText(
    "Tip: unlock the recommendation display, drag it into place, then lock it again. Simulation never changes live combat state."
)

local function UpdateDropdown(dropdown)
    local value = dropdown.getValue()
    local selectedLabel = value
    for _, option in ipairs(dropdown.options) do
        if option.value == value then
            selectedLabel = option.label
            break
        end
    end
    UIDropDownMenu_SetSelectedValue(dropdown, value)
    UIDropDownMenu_SetText(dropdown, selectedLabel)
end

function ns.Settings_Refresh()
    if refreshing or not ns.db then return end
    refreshing = true

    for setting, checkbox in pairs(controls) do
        checkbox:SetChecked(ns.db[setting] == true)
    end

    local demoRank = ns.state.improvedDemoShoutRank or 0
    local demoMaxRank = ns.state.improvedDemoShoutMaxRank or 5
    local demoAvailable = demoRank > 0
    demoShoutCheckbox:SetEnabled(demoAvailable)

    local demoLabel = _G[demoShoutCheckbox:GetName() .. "Text"]
    demoLabel:SetText(string.format(
        "Maintain Demo Shout (talent %d/%d)",
        demoRank,
        demoMaxRank
    ))
    if demoAvailable then
        demoLabel:SetTextColor(1, 0.82, 0, 1)
        demoShoutCheckbox.description =
            "Refreshes your Improved Demoralizing Shout as a filler without "
            .. "replacing Slam, Mortal Strike, Whirlwind, or Execute."
    else
        demoLabel:SetTextColor(0.50, 0.50, 0.50, 1)
        demoShoutCheckbox.description =
            "Requires at least one point in Improved Demoralizing Shout."
    end

    UpdateDropdown(modeDropdown)
    UpdateDropdown(shoutDropdown)
    UpdateDropdown(scenarioDropdown)
    scaleSlider:SetValue(ns.db.scale or 1.0)

    previewButton:SetText(
        ns.db.testMode and "Stop display preview" or "Start display preview"
    )

    local simulatorActive = ns.Simulator_IsActive
        and ns.Simulator_IsActive()
    nextSimulatorButton:SetEnabled(simulatorActive)
    stopSimulatorButton:SetEnabled(simulatorActive)

    if simulatorActive and ns.Simulator_GetStatus then
        local status = ns.Simulator_GetStatus()
        if status then
            statusText:SetText(string.format(
                "|cff55ccffSimulation: %s - step %d/%d: %s|r",
                status.label,
                status.stepIndex,
                status.stepTotal,
                status.stepLabel or ""
            ))
        end
    elseif ns.db.testMode then
        statusText:SetText("|cffff6640Display preview is active.|r")
    elseif statusOverride then
        statusText:SetText(statusOverride)
    else
        statusText:SetText("Live recommendations are active.")
    end

    refreshing = false
end

function ns.Settings_Open()
    if not ns.db then return end
    panel:Show()
    ns.Settings_Refresh()
end

function ns.Settings_Close()
    panel:Hide()
end

function ns.Settings_Toggle()
    if panel:IsShown() then
        panel:Hide()
    else
        ns.Settings_Open()
    end
end

panel:SetScript("OnShow", function()
    ns.Settings_Refresh()
end)

local statusElapsed = 0
panel:SetScript("OnUpdate", function(_, elapsed)
    statusElapsed = statusElapsed + elapsed
    if statusElapsed < 0.25 then return end
    statusElapsed = 0
    if ns.Simulator_IsActive and ns.Simulator_IsActive() then
        ns.Settings_Refresh()
    end
end)

if UISpecialFrames then
    table.insert(UISpecialFrames, panel:GetName())
end

-- Anniversary clients use the modern Settings API, while older TBC clients
-- expose InterfaceOptions_AddCategory. Register the same lightweight launcher
-- with either API; /arh remains available on every client.
local hasModernSettings = Settings
    and Settings.RegisterCanvasLayoutCategory
    and Settings.RegisterAddOnCategory

if hasModernSettings or InterfaceOptions_AddCategory then
    local category = CreateFrame(
        "Frame",
        "ArmsRotationHelperInterfaceOptionsCategory"
    )
    category.name = "Arms Rotation Helper"

    local categoryTitle = category:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalLarge"
    )
    categoryTitle:SetPoint("TOPLEFT", category, "TOPLEFT", 16, -16)
    categoryTitle:SetText("Arms Rotation Helper")

    local categoryDescription = category:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlight"
    )
    categoryDescription:SetPoint("TOPLEFT", categoryTitle, "BOTTOMLEFT", 0, -12)
    categoryDescription:SetWidth(560)
    categoryDescription:SetJustifyH("LEFT")
    categoryDescription:SetText(
        "Open the complete settings panel to configure rotation priorities, display options, and the simulator."
    )

    local openButton = CreateFrame(
        "Button",
        nil,
        category,
        "UIPanelButtonTemplate"
    )
    openButton:SetSize(180, 24)
    openButton:SetPoint("TOPLEFT", categoryDescription, "BOTTOMLEFT", 0, -18)
    openButton:SetText("Open settings")
    openButton:SetScript("OnClick", function()
        if SettingsPanel then SettingsPanel:Hide() end
        if InterfaceOptionsFrame then InterfaceOptionsFrame:Hide() end
        ns.Settings_Open()
    end)

    if hasModernSettings then
        local settingsCategory = Settings.RegisterCanvasLayoutCategory(
            category,
            category.name
        )
        Settings.RegisterAddOnCategory(settingsCategory)
        ns.settingsCategory = settingsCategory
    else
        InterfaceOptions_AddCategory(category)
    end
end
