-- 初始化默认配置
local defaultSettings = {
    enabled = true,
    message = "热烈欢迎 [{name}] ！！",
    delay = 3,
    enableRightClickInvite = true -- 默认开启右键邀请功能开关
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_SYSTEM")

-- 12.1 动态获取游戏内置全球化系统文本
local joinPattern
local rawPattern = _G["ERR_GUILD_JOIN_S"] or (GetText and GetText("ERR_GUILD_JOIN_S")) or "%s加入了公会。"
joinPattern = rawPattern:gsub("%%s", "(.+)")

-- 存储新版设置面板生成的分类对象
local addonSettingsCategory = nil

-- 安全匹配辅助函数
local function SafeMatch(text, pattern)
    if not text or type(text) ~= "string" then return nil end
    if issecurevariable and issecurevariable("text") then return nil end
    
    local success, result = pcall(string.match, text, pattern)
    if success then
        return result
    else
        return nil
    end
end

-- 迎新核心逻辑
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "GuildWelcomeBot" then
            if not GuildWelcomeBotDB then GuildWelcomeBotDB = {} end
            for k, v in pairs(defaultSettings) do
                if GuildWelcomeBotDB[k] == nil then GuildWelcomeBotDB[k] = v end
            end
            -- 注册原生系统菜单面板
            frame:CreateOptionsPanel()
            -- 初始化右键菜单修改
            frame:InitRightClickMenu()
        end
    elseif event == "CHAT_MSG_SYSTEM" and GuildWelcomeBotDB and GuildWelcomeBotDB.enabled then
        local text = ...
        local name = SafeMatch(text, joinPattern)
        
        if name then
            local shortName = SafeMatch(name, "([^%-]+)") or name
            C_Timer.After(GuildWelcomeBotDB.delay, function()
                if IsInGuild() then
                    local success, welcomeMsg = pcall(string.gsub, GuildWelcomeBotDB.message, "{name}", shortName)
                    if success and welcomeMsg then
                        if C_ChatInfo and C_ChatInfo.SendChatMessage then
                            C_ChatInfo.SendChatMessage(welcomeMsg, "GUILD")
                        else
                            SendChatMessage(welcomeMsg, "GUILD")
                        end
                    end
                end
            end)
        end
    end
end)

-- =================== 12.1 Menu API 右键菜单管理 ===================
function frame:InitRightClickMenu()
    if not Menu or not Menu.ModifyMenu then return end

    -- 定义菜单渲染的通用回调函数
    local function AppendInviteButton(ownerRegion, rootDescription, contextData)
        -- 如果玩家在设置里关闭了此功能，则不往菜单里注入按钮
        if not GuildWelcomeBotDB or not GuildWelcomeBotDB.enableRightClickInvite then
            return 
        end

        -- 安全获取右键目标的玩家名字
        local name = contextData and contextData.name
        if not name or name == "" then return end

        -- 在菜单中插入一条分割线
        rootDescription:CreateDivider()
        
        -- 创建“邀请入会”按钮（已移除有风险的 SetIcon 接口，确保不再报错）
        rootDescription:CreateButton("邀请入会", function()
            if IsInGuild() then
                GuildInvite(name)
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GuildWelcomeBot]|r 正在邀请 " .. name .. " 加入公会...")
            else
                UIErrorsFrame:AddMessage("你当前不在公会中，无法邀请其他人。", 1.0, 0.1, 0.1, 1.0)
            end
        end)
    end

    -- 同时挂钩正式服右键菜单的三个关键标签
    Menu.ModifyMenu("MENU_UNIT_PLAYER", AppendInviteButton)        -- 标准玩家目标菜单
    Menu.ModifyMenu("MENU_UNIT_CHAT_PLAYER", AppendInviteButton)   -- 聊天栏专属玩家菜单
    Menu.ModifyMenu("MENU_UNIT_FRIEND", AppendInviteButton)        -- 好友列表玩家菜单
end

-- 创建原生系统菜单嵌合面板
function frame:CreateOptionsPanel()
    -- 1. 创建主面板画布容器
    local panel = CreateFrame("Frame", "GuildWelcomeBotOptionsPanel", UIParent)
    panel.name = "GuildWelcomeBot"
    
    -- 用于存储未点击确认前的临时变量
    local tempDelay = nil
    local tempMessage = nil
    
    -- 2. 标题
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("GuildWelcomeBot 公会迎新设置")

    -- 3. 复选框：开启/关闭自动欢迎
    local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    cb.Text:SetText(" 启用自动迎新功能")
    cb:SetScript("OnClick", function(self)
        GuildWelcomeBotDB.enabled = self:GetChecked()
    end)

    -- =================== 复选框：开启/关闭右键邀请 ===================
    local cbInvite = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cbInvite:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -10)
    cbInvite.Text:SetText(" 开启聊天栏右击“邀请入会”功能")
    cbInvite:SetScript("OnClick", function(self)
        GuildWelcomeBotDB.enableRightClickInvite = self:GetChecked()
    end)

    -- =================== 第一组：延迟项 ===================
    -- 4. 文本框标签：延迟秒数
    local delayLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    delayLabel:SetPoint("TOPLEFT", cbInvite, "BOTTOMLEFT", 0, -25)
    delayLabel:SetText("发话延迟时间（秒）:")

    -- 5. 文本框：延迟秒数输入
    local delayBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    delayBox:SetSize(60, 20)
    delayBox:SetPoint("LEFT", delayLabel, "RIGHT", 10, 0)
    delayBox:SetAutoFocus(false)
    delayBox:SetMaxLetters(3)
    delayBox:SetScript("OnTextChanged", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 0 then tempDelay = val end
    end)

    -- 5b. 延迟项专用的“确认”按钮
    local delayConfirmBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    delayConfirmBtn:SetSize(60, 22)
    delayConfirmBtn:SetPoint("LEFT", delayBox, "RIGHT", 15, 0)
    delayConfirmBtn:SetText("确认")
    delayConfirmBtn:SetScript("OnClick", function()
        if tempDelay ~= nil then 
            GuildWelcomeBotDB.delay = tempDelay 
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            print("|cFF00FF00[GuildWelcomeBot]|r 延迟秒数已成功保存并应用！")
        end
    end)

    -- =================== 第二组：欢迎语项 ===================
    -- 6. 文本框标签：欢迎语内容
    local msgLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    msgLabel:SetPoint("TOPLEFT", delayLabel, "BOTTOMLEFT", 0, -30)
    msgLabel:SetText("自定义欢迎语内容（支持占位符 {name}）:")

    -- 7. 文本框：欢迎语输入
    local msgBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    msgBox:SetSize(350, 20)
    msgBox:SetPoint("TOPLEFT", msgLabel, "BOTTOMLEFT", 0, -8)
    msgBox:SetAutoFocus(false)
    msgBox:SetScript("OnTextChanged", function(self)
        tempMessage = self:GetText()
    end)
    
    -- 7b. 欢迎语专用的“确认”按钮
    local msgConfirmBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    msgConfirmBtn:SetSize(60, 22)
    msgConfirmBtn:SetPoint("LEFT", msgBox, "RIGHT", 15, 0)
    msgConfirmBtn:SetText("确认")
    msgConfirmBtn:SetScript("OnClick", function()
        if tempMessage ~= nil and tempMessage ~= "" then 
            GuildWelcomeBotDB.message = tempMessage 
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            print("|cFF00FF00[GuildWelcomeBot]|r 欢迎语内容已成功保存并应用！")
        end
    end)
    
    -- =================== 说明与署名区域 ===================
    -- 8. 提示说明文本
    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    hint:SetPoint("TOPLEFT", msgBox, "BOTTOMLEFT", 0, -15)
    hint:SetText("提示：修改后需点击对应的【确认】按钮。发话时 {name} 会被自动替换为新人名字。")

    -- 9. 作者署名
    local authorText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    authorText:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -10)
    authorText:SetText("作者：StewadY")

    -- 10. 版本号
    local versionText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    versionText:SetPoint("TOPLEFT", authorText, "BOTTOMLEFT", 0, -6)
    
    local currentVersion = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("GuildWelcomeBot", "Version") or "1.3.6"
    versionText:SetText("版本：" .. currentVersion)

    -- 打开面板时微延迟注入默认值
    panel:SetScript("OnShow", function()
        cb:SetChecked(GuildWelcomeBotDB.enabled)
        cbInvite:SetChecked(GuildWelcomeBotDB.enableRightClickInvite) -- 同步右键开关勾选状态
        tempDelay = GuildWelcomeBotDB.delay
        tempMessage = GuildWelcomeBotDB.message
        
        C_Timer.After(0.01, function()
            if delayBox then delayBox:SetText(tostring(GuildWelcomeBotDB.delay)) end
            if msgBox then msgBox:SetText(GuildWelcomeBotDB.message) end
        end)
    end)

    -- 正确挂载进新版系统菜单并保存生成的 Category 对象
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        addonSettingsCategory = category -- 记录该对象用于快捷命令打开
    end
end

-- 保留快捷命令通道
SLASH_GUILDWELCOMEBOT1 = "/gwb"
SlashCmdList["GUILDWELCOMEBOT"] = function()
    -- 使用暴雪推荐的最新 API 传递 Category 对象或利用新参数打开
    if Settings and Settings.OpenToCategory and addonSettingsCategory then
        Settings.OpenToCategory(addonSettingsCategory:GetID())
    else
        ToggleInterfaceOptions()
    end
end
