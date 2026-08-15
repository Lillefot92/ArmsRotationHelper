-- ============================================================
-- Arms Rotation Helper - Settings.lua
-- In-game configuration panel for rotation, display, preview,
-- positioning, deterministic simulator, and diagnostic controls.
-- ============================================================

local ADDON_NAME, ns = ...

local PANEL_WIDTH = 720
local PANEL_HEIGHT = 730

local COLORS = {
    teal = { 0.20, 0.90, 0.80, 1.00 },
    muted = { 0.63, 0.69, 0.77, 1.00 },
    panel = { 0.035, 0.045, 0.065, 0.92 },
    border = { 0.16, 0.34, 0.39, 0.95 },
}

local function ApplyBox(frame, alpha)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(
        COLORS.panel[1],
        COLORS.panel[2],
        COLORS.panel[3],
        alpha or COLORS.panel[4]
    )
    frame:SetBackdropBorderColor(
        COLORS.border[1],
        COLORS.border[2],
        COLORS.border[3],
        COLORS.border[4]
    )
end

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
ApplyBox(panel, 0.94)
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

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
title:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -20)
title:SetText("Arms Rotation Helper")
title:SetTextColor(COLORS.teal[1], COLORS.teal[2], COLORS.teal[3], COLORS.teal[4])

local versionText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
versionText:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -42, -28)
versionText:SetText("Version " .. ns.VERSION)
versionText:SetTextColor(
    COLORS.muted[1],
    COLORS.muted[2],
    COLORS.muted[3],
    COLORS.muted[4]
)

local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 2, -7)
subtitle:SetWidth(PANEL_WIDTH - 48)
subtitle:SetJustifyH("LEFT")
subtitle:SetText("Two-handed Arms PvE advisor - settings save immediately")
subtitle:SetTextColor(
    COLORS.muted[1],
    COLORS.muted[2],
    COLORS.muted[3],
    COLORS.muted[4]
)

local statusBox = CreateFrame("Frame", nil, panel, "BackdropTemplate")
statusBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -82)
statusBox:SetSize(PANEL_WIDTH - 48, 66)
ApplyBox(statusBox, 0.78)

local statusText = statusBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
statusText:SetPoint("TOPLEFT", statusBox, "TOPLEFT", 12, -11)
statusText:SetWidth(PANEL_WIDTH - 72)
statusText:SetJustifyH("LEFT")

local trackingText = statusBox:CreateFontString(
    nil,
    "OVERLAY",
    "GameFontHighlightSmall"
)
trackingText:SetPoint("TOPLEFT", statusBox, "TOPLEFT", 12, -36)
trackingText:SetWidth(PANEL_WIDTH - 72)
trackingText:SetJustifyH("LEFT")
trackingText:SetTextColor(
    COLORS.muted[1],
    COLORS.muted[2],
    COLORS.muted[3],
    COLORS.muted[4]
)

local function CreateSectionHeader(text, x, y, width)
    local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
    header:SetText(text)
    header:SetTextColor(COLORS.teal[1], COLORS.teal[2], COLORS.teal[3], COLORS.teal[4])

    local line = panel:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(COLORS.border[1], COLORS.border[2], COLORS.border[3], 0.75)
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    line:SetSize(width, 1)
    return header
end

local rotationHeader = CreateSectionHeader("Rotation behavior", 24, -166, 320)
local displayHeader = CreateSectionHeader("Display", 376, -166, 320)
local toolsHeader = CreateSectionHeader(
    "Testing and feedback",
    24,
    -488,
    672
)

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
    -204,
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
    -269,
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
    -334,
    "stanceAdvice"
)

CreateCheckbox(
    "ArmsRotationHelperSunderCheckbox",
    "Maintain five Sunders",
    "Opt into maintaining five Sunder Armor stacks on durable targets. Leave this off when another player handles armor reduction.",
    24,
    -366,
    "maintainSunder"
)

CreateCheckbox(
    "ArmsRotationHelperLockedCheckbox",
    "Lock recommendation display",
    "When unlocked, drag the main recommendation display with the left mouse button.",
    372,
    -366,
    "locked"
)

local demoShoutCheckbox = CreateCheckbox(
    "ArmsRotationHelperDemoShoutCheckbox",
    "Maintain Improved Demo Shout",
    "Available only with at least one point in Improved Demoralizing Shout. Refreshes your talented debuff as a filler without replacing Slam, Mortal Strike, Whirlwind, or Execute.",
    24,
    -398,
    "maintainDemoShout"
)

CreateCheckbox(
    "ArmsRotationHelperMainIconCheckbox",
    "Main recommendation icon",
    "Shows the clean primary recommendation icon. Hover it for the ability name and reason.",
    372,
    -204,
    "showIcon"
)

CreateCheckbox(
    "ArmsRotationHelperSwingCheckbox",
    "Main-hand swing bar",
    "Shows the compact main-hand swing progress bar and changes color for a valid post-swing Slam.",
    372,
    -236,
    "showSwingBar"
)

CreateCheckbox(
    "ArmsRotationHelperQueueCheckbox",
    "Heroic Strike/Cleave queue",
    "Shows high-Rage next-swing advice separately from the primary global-cooldown recommendation.",
    372,
    -268,
    "showQueue"
)

CreateCheckbox(
    "ArmsRotationHelperGlowCheckbox",
    "Action-bar glow",
    "Highlights a matching visible spell or spell macro on Blizzard, Bartender4, or Dominos bars.",
    372,
    -300,
    "showGlow"
)

CreateCheckbox(
    "ArmsRotationHelperCooldownsCheckbox",
    "Compact cooldown icons",
    "Shows Death Wish, Recklessness, and usable equipped trinkets without permanent text labels.",
    372,
    -332,
    "showCooldowns"
)

CreateCheckbox(
    "ArmsRotationHelperDebugCheckbox",
    "Diagnostic panel",
    "Shows the live combat values used by the recommendation engine. Useful for testing and bug reports.",
    372,
    -398,
    "debugMode"
)

local scaleLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
scaleLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 382, -421)
scaleLabel:SetText("Display scale")

local scaleSlider = CreateFrame(
    "Slider",
    "ArmsRotationHelperScaleSlider",
    panel,
    "OptionsSliderTemplate"
)
scaleSlider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 8, -12)
scaleSlider:SetWidth(220)
scaleSlider:SetMinMaxValues(0.3, 3.0)
scaleSlider:SetValueStep(0.05)
if scaleSlider.SetObeyStepOnDrag then scaleSlider:SetObeyStepOnDrag(true) end

_G[scaleSlider:GetName() .. "Low"]:SetText("0.3")
_G[scaleSlider:GetName() .. "High"]:SetText("3.0")
_G[scaleSlider:GetName() .. "Text"]:SetText("100%")

scaleSlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value * 20 + 0.5) / 20
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
    -526,
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

local statusOverride

local previewButton
previewButton = CreateButton("Start display preview", 180, 376, -526, function()
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
    376,
    -559,
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
    376,
    -592,
    function()
        if ns.Simulator_Next then ns.Simulator_Next() end
        statusOverride = nil
        ns.Settings_Refresh()
    end
)

local stopSimulatorButton = CreateButton(
    "Stop",
    87,
    469,
    -592,
    function()
        if ns.Simulator_Stop then ns.Simulator_Stop() end
        statusOverride = nil
        ns.Settings_Refresh()
    end
)

local checkSimulatorButton = CreateButton(
    "Run priority checks",
    180,
    376,
    -625,
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

local recordButton
recordButton = CreateButton(
    "Start 60-second recording",
    220,
    28,
    -592,
    function()
        if not ns.Diagnostics_Start then return end
        if ns.Diagnostics_IsActive and ns.Diagnostics_IsActive() then
            ns.Diagnostics_Stop()
            statusOverride = "Diagnostic recording stopped. Open the report to copy it."
        else
            local ok, err = ns.Diagnostics_Start()
            if ok then
                statusOverride = nil
            else
                statusOverride = "|cffff6640" .. tostring(err) .. "|r"
            end
        end
        ns.Settings_Refresh()
    end
)

local openReportButton = CreateButton(
    "Open report",
    106,
    28,
    -625,
    function()
        if ns.Diagnostics_OpenReport then ns.Diagnostics_OpenReport() end
    end
)

local clearReportButton = CreateButton(
    "Clear report",
    106,
    142,
    -625,
    function()
        if ns.Diagnostics_Clear then ns.Diagnostics_Clear() end
        statusOverride = "The in-memory diagnostic report was cleared."
        ns.Settings_Refresh()
    end
)

local resetButton = CreateButton(
    "Reset position and scale",
    220,
    28,
    -658,
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
helpText:SetPoint("TOPLEFT", panel, "TOPLEFT", 28, -696)
helpText:SetWidth(PANEL_WIDTH - 56)
helpText:SetJustifyH("LEFT")
helpText:SetText(
    "Hover over the main icon for live details; right-click it to cycle target mode. "
        .. "Diagnostic reports stay in memory and never include player, realm, or target names."
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

    local diagnosticStatus = ns.Diagnostics_GetStatus
        and ns.Diagnostics_GetStatus() or nil
    local recordingActive = diagnosticStatus and diagnosticStatus.active
    recordButton:SetText(
        recordingActive and "Stop recording" or "Start 60-second recording"
    )
    openReportButton:SetEnabled(
        diagnosticStatus == nil or diagnosticStatus.hasReport
    )
    clearReportButton:SetEnabled(
        diagnosticStatus ~= nil
            and (diagnosticStatus.hasReport or diagnosticStatus.active)
    )

    local playerLevel = UnitLevel and UnitLevel("player") or 0
    local modeLabel = ns.db.mode == "aoe" and "AoE"
        or ns.db.mode == "single" and "Single"
        or "Automatic"
    local shoutLabel = ns.db.assignedShout == "commanding"
        and "Commanding Shout" or "Battle Shout"
    trackingText:SetText(string.format(
        "Level %d Warrior  |  Rage %d/%d  |  %d tracked target%s  |  %s  |  %s",
        playerLevel,
        ns.state.rage or 0,
        ns.state.maxRage or 100,
        ns.state.enemyCount or 0,
        (ns.state.enemyCount or 0) == 1 and "" or "s",
        modeLabel,
        shoutLabel
    ))

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
    elseif recordingActive then
        statusText:SetText(string.format(
            "|cff55ccffRecording live decisions: %.0fs remaining "
                .. "(%d entries).|r",
            diagnosticStatus.remaining,
            diagnosticStatus.entryCount
        ))
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
    if (ns.Simulator_IsActive and ns.Simulator_IsActive())
        or (ns.Diagnostics_IsActive and ns.Diagnostics_IsActive()) then
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
