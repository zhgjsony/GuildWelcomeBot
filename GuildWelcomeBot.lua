-- 初始化默认配置
local defaultSettings = {
    enabled = true,
    message = "热烈欢迎 [{name}] ！！",
    delay = 3,
    enableRightClickInvite = true
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_SYSTEM")

-- 存储新版设置面板生成的分类对象
local addonSettingsCategory = nil

-- =================== 12.1 正式服安全过滤与延时队列发话核心 ===================
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "GuildWelcomeBot" then
            if not GuildWelcomeBotDB then GuildWelcomeBotDB = {} end
            for k, v in pairs(defaultSettings) do
                if GuildWelcomeBotDB[k] == nil then GuildWelcomeBotDB[k] = v end
            end
            frame:CreateOptionsPanel()
            frame:InitRightClickMenu()
        end
    elseif event == "CHAT_MSG_SYSTEM" and GuildWelcomeBotDB and GuildWelcomeBotDB.enabled then
        local text = ...
        if not text or type(text) ~= "string" then return end -- 拦截 12.1 secret string 异常类型

        -- 获取加入公会的系统文本模版
        local guildJoinTarget = _G["ERR_GUILD_JOIN_S"] or "%s加入了公会。"
        local pattern = guildJoinTarget:gsub("%%s", "(.+)")
        
        -- 【安全沙盒匹配】：避免直接面向对象索引造成 Taint 熔断
        local success, name = pcall(function(t, p)
            local matchedName = string.match(t, p)
            if not matchedName then
                -- 使用全局安全函数进行清洗，不破坏原始 secret 栈
                local cleanText = string.gsub(t, "|c%x%x%x%x%x%x%x%x", "")
                cleanText = string.gsub(cleanText, "|r", "")
                matchedName = string.match(cleanText, p)
            end
            return matchedName
        end, text, pattern)

        if not success or not name then return end
        
        if name then
            local shortName = string.match(name, "([^%-]+)") or name
            local gsubSuccess, welcomeMsg = pcall(string.gsub, GuildWelcomeBotDB.message, "{name}", shortName)
            if not gsubSuccess or not welcomeMsg then return end

            local currentDelay = tonumber(GuildWelcomeBotDB.delay) or 3

            if IsInGuild() then
                -- 剥离异步闭包，安全发话
                C_Timer.After(currentDelay, function()
                    if IsInGuild() and GuildWelcomeBotDB.enabled then
                        if C_ChatInfo and C_ChatInfo.SendChatMessage then
                            C_ChatInfo.SendChatMessage(welcomeMsg, "GUILD")
                        else
                            SendChatMessage(welcomeMsg, "GUILD")
                        end
                    end
                end)
            end
        end
    end
end)

-- =================== 12.1 Menu API 右键菜单管理 ===================
function frame:InitRightClickMenu()
    if not Menu or not Menu.ModifyMenu then return end

    local function AppendInviteButton(ownerRegion, rootDescription, contextData)
        if not GuildWelcomeBotDB or not GuildWelcomeBotDB.enableRightClickInvite then return end

        local name = contextData and contextData.name
        if not name or name == "" then return end

        rootDescription:CreateDivider()
        
        -- 【12.1 规范重构】：使用规范的菜单回调，并进行安全隔离，防止全队头像右键在战斗中瘫痪
        rootDescription:CreateButton("邀请入会", function()
            -- 将受保护的安全行为包裹在最外层，降低污染扩散概率
            if IsInGuild() then
                GuildInvite(name)
                print("|cFF00FF00[GuildWelcomeBot]|r 正在邀请 " .. name .. " 加入公会...")
            else
                if UIErrorsFrame then
                    UIErrorsFrame:AddMessage("你当前不在公会中，无法邀请其他人。", 1.0, 0.1, 0.1, 1.0)
                end
            end
        end)
    end

    Menu.ModifyMenu("MENU_UNIT_PLAYER", AppendInviteButton)
    Menu.ModifyMenu("MENU_UNIT_CHAT_PLAYER", AppendInviteButton)
    Menu.ModifyMenu("MENU_UNIT_FRIEND", AppendInviteButton)
end

-- =================== 现代设置面板重构 ===================
function frame:CreateOptionsPanel()
    local panel = CreateFrame("Frame", "GuildWelcomeBotOptionsPanel", UIParent)
    panel.name = "GuildWelcomeBot"
    
    local tempDelay = nil
    local tempMessage = nil
    
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("GuildWelcomeBot 公会迎新设置")

    -- 使用目前依然稳妥的标准次级 CheckButton 模板
    local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    cb.Text:SetText(" 启用自动迎新功能")
    cb:SetScript("OnClick", function(self)
        GuildWelcomeBotDB.enabled = self:GetChecked()
    end)

    local cbInvite = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cbInvite:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -10)
    cbInvite.Text:SetText(" 开启聊天栏右击“邀请入会”功能")
    cbInvite:SetScript("OnClick", function(self)
        GuildWelcomeBotDB.enableRightClickInvite = self:GetChecked()
    end)

    -- 延迟项
    local delayLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    delayLabel:SetPoint("TOPLEFT", cbInvite, "BOTTOMLEFT", 0, -25)
    delayLabel:SetText("发话延迟时间（秒）:")

    -- 替换过时的 InputBoxTemplate，直接动态构建基础文本框，彻底免疫模板丢弃带来的空白
    local delayBox = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
    delayBox:SetSize(60, 20)
    delayBox:SetPoint("LEFT", delayLabel, "RIGHT", 10, 0)
    delayBox:SetAutoFocus(false)
    delayBox:SetMaxLetters(3)
    delayBox:SetFontObject("GameFontHighlight")
    -- 简易背景绘制
    delayBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    delayBox:SetBackdropColor(0, 0, 0, 0.5)
    delayBox:SetTextInsets(5, 5, 0, 0)
    delayBox:SetScript("OnTextChanged", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 0 then tempDelay = val end
    end)

    local delayConfirmBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    delayConfirmBtn:SetSize(60, 22)
    delayConfirmBtn:SetPoint("LEFT", delayBox, "RIGHT", 15, 0)
    delayConfirmBtn:SetText("确认")
    delayConfirmBtn:SetScript("OnClick", function()
        if tempDelay ~= nil then 
            GuildWelcomeBotDB.delay = tempDelay 
            if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            end
            print("|cFF00FF00[GuildWelcomeBot]|r 延迟秒数已成功保存并应用！")
        end
    end)

    -- 欢迎语项
    local msgLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    msgLabel:SetPoint("TOPLEFT", delayLabel, "BOTTOMLEFT", 0, -30)
    msgLabel:SetText("自定义欢迎语内容（支持占位符 {name}）:")

    local msgBox = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
    msgBox:SetSize(350, 20)
    msgBox:SetPoint("TOPLEFT", msgLabel, "BOTTOMLEFT", 0, -8)
    msgBox:SetAutoFocus(false)
    msgBox:SetFontObject("GameFontHighlight")
    msgBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    msgBox:SetBackdropColor(0, 0, 0, 0.5)
    msgBox:SetTextInsets(5, 5, 0, 0)
    msgBox:SetScript("OnTextChanged", function(self)
        tempMessage = self:GetText()
    end)
    
    local msgConfirmBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    msgConfirmBtn:SetSize(60, 22)
    msgConfirmBtn:SetPoint("LEFT", msgBox, "RIGHT", 15, 0)
    msgConfirmBtn:SetText("确认")
    msgConfirmBtn:SetScript("OnClick", function()
        if tempMessage ~= nil and tempMessage ~= "" then 
            GuildWelcomeBotDB.message = tempMessage 
            if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            end
            print("|cFF00FF00[GuildWelcomeBot]|r 欢迎语内容已成功保存并应用！")
        end
    end)
    
    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    hint:SetPoint("TOPLEFT", msgBox, "BOTTOMLEFT", 0, -15)
    hint:SetText("提示：修改后需点击对应的【确认】按钮。发话时 {name} 会被自动替换为新人名字。")

    local authorText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    authorText:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -10)
    authorText:SetText("作者：StewadY")

    local versionText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    versionText:SetPoint("TOPLEFT", authorText, "BOTTOMLEFT", 0, -6)
    
    local currentVersion = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("GuildWelcomeBot", "Version") or "1.3.6"
    versionText:SetText("版本：" .. currentVersion)

    panel:SetScript("OnShow", function()
        cb:SetChecked(GuildWelcomeBotDB.enabled)
        cbInvite:SetChecked(GuildWelcomeBotDB.enableRightClickInvite)
        tempDelay = GuildWelcomeBotDB.delay
        tempMessage = GuildWelcomeBotDB.message
        
        C_Timer.After(0.01, function()
            if delayBox then delayBox:SetText(tostring(GuildWelcomeBotDB.delay)) end
            if msgBox then msgBox:SetText(GuildWelcomeBotDB.message) end
        end)
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        addonSettingsCategory = category
    end
end

-- 保留快捷命令通道并移除过时全局函数
SLASH_GUILDWELCOMEBOT1 = "/gwb"
SlashCmdList["GUILDWELCOMEBOT"] = function()
    if Settings and Settings.OpenToCategory and addonSettingsCategory then
        Settings.OpenToCategory(addonSettingsCategory:GetID())
    else
        -- 洗白：移除已彻底被暴雪删除的 ToggleInterfaceOptions()，换成现代 print 引导
        print("|cFF00FF00[GuildWelcomeBot]|r 请按 Esc -> 选项 -> 插件 找到本插件进行配置。")
    end
end
