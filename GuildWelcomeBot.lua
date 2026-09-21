-- 初始化默认配置
local defaultSettings = {
    enabled = true,
    message = "热烈欢迎 [{name}] ！！",
    delay = 3
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_SYSTEM")

-- 12.1 动态获取游戏内置全球化系统文本
local joinPattern
local rawPattern = _G["ERR_GUILD_JOIN_S"] or (GetText and GetText("ERR_GUILD_JOIN_S")) or "%s加入了公会。"
joinPattern = rawPattern:gsub("%%s", "(.+)")

-- 【新增安全辅助函数】防止在面对受保护的 secret string 时导致整段逻辑崩溃
local function SafeMatch(text, pattern)
    if not text or type(text) ~= "string" then return nil end
    -- 如果该字符串变量是由系统加密受污染的，直接跳过处理
    if issecurevariable and issecurevariable("text") then return nil end
    
    -- 使用 pcall 模式进行保护性匹配
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
        end
    elseif event == "CHAT_MSG_SYSTEM" and GuildWelcomeBotDB and GuildWelcomeBotDB.enabled then
        local text = ...
        
        -- 【核心修复】调用安全匹配逻辑，如果返回 nil 则自动放弃后续解析（打BOSS时安全过滤）
        local name = SafeMatch(text, joinPattern)
        
        if name then
            local shortName = SafeMatch(name, "([^%-]+)") or name
            C_Timer.After(GuildWelcomeBotDB.delay, function()
                if IsInGuild() then
                    -- 再次使用更安全的全局替换
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

    -- =================== 第一组：延迟项 ===================
    -- 4. 文本框标签：延迟秒数
    local delayLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    delayLabel:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -25)
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
        tempDelay = GuildWelcomeBotDB.delay
        tempMessage = GuildWelcomeBotDB.message
        
        C_Timer.After(0.01, function()
            if delayBox then delayBox:SetText(tostring(GuildWelcomeBotDB.delay)) end
            if msgBox then msgBox:SetText(GuildWelcomeBotDB.message) end
        end)
    end)

    -- 挂载进系统菜单
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    end
end

-- 保留快捷命令通道
SLASH_GUILDWELCOMEBOT1 = "/gwb"
SlashCmdList["GUILDWELCOMEBOT"] = function()
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory("GuildWelcomeBot")
    else
        ToggleInterfaceOptions()
    end
end
