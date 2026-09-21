-- 默认配置
local defaultSettings = {
    enabled = true,
    delay = 3,
    message = "热烈欢迎 [{name}] ！！"
}

-- 创建控制框体
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_SYSTEM")

-- 安全匹配函数（防止遇到 secret string 时崩溃）
local function SafeMatch(text, pattern)
    if not text or type(text) ~= "string" then return nil end
    
    -- 使用 pcall (保护模式) 调用 string.match
    -- 即使暴雪传入了被污染/加密的字符串，也会被安全捕获而不引发插件报错
    local success, result = pcall(string.match, text, pattern)
    if success then
        return result
    else
        return nil -- 遇到加密字符串时，安全跳过
    end
end

frame:SetScript("OnEvent", function(self, event, text, ...)
    if not defaultSettings.enabled then return end

    if event == "CHAT_MSG_SYSTEM" then
        -- 暴雪官方的本地化公会加入文本格式（兼容各语言版本，更安全）
        -- 例如中文是 "%s加入了公会。"
        local guildJoinTemplate = ERR_GUILD_JOIN_S
        
        -- 将暴雪的模板转换为匹配模式 (将 %s 转换为 (.+))
        local pattern = guildJoinTemplate:gsub("%%s", "(.+)")
        
        -- 使用安全匹配函数提取名字
        local name = SafeMatch(text, pattern)
        
        -- 如果成功提取到了名字，说明确实是新人在加入公会
        if name and name ~= "" then
            -- 延迟发送欢迎语（避开瞬间卡顿）
            C_Timer.After(defaultSettings.delay, function()
                -- 再次检查，防止在战斗中或特殊情况下名字异常
                if type(name) == "string" then
                    local welcomeMsg = defaultSettings.message:gsub("{name}", name)
                    SendChatMessage(welcomeMsg, "GUILD")
                end
            end)
        end
    end
end)
