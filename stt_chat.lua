-- Change this to the blue bridge URL shown in the desktop STT window.
local BRIDGE_URL = "https://ccstt.novaa.dev/next?token=ccstt-8e4f73b12a6d"
local CHAT_PREFIX = "Voice"
local POLL_SECONDS = 0.25
local TTS_URL = "https://music.madefor.cc/tts?text="
local WELCOME_SIDE = "top"
local MONITOR_NAME = "monitor_0"
local VALID_SIDES = {
    top = true, bottom = true, left = true,
    right = true, front = true, back = true
}

local activeSides = {}
local welcomeAlertUntil = 0

local function speak(text, description)
    print("Speaking " .. description)
    local url = TTS_URL .. textutils.urlEncode(text)
    if not shell.run("speaker", "play", url) then
        printError("Could not play " .. description)
    end
end

local function runCommand(event)
    if event.type ~= "command" or type(event.action) ~= "table" then
        return
    end

    if event.action.type == "speak" and type(event.action.text) == "string" then
        speak(event.action.text, "query response")
        return
    end

    if event.action.type ~= "redstone" or not VALID_SIDES[event.action.side] then
        printError("Unsupported action for command " .. tostring(event.command))
        return
    end

    local side = event.action.side
    local duration = math.max(tonumber(event.action.duration) or 1, 0)
    print("Command: " .. tostring(event.command) .. " -> " .. side)
    activeSides[side] = true
    redstone.setOutput(side, true)
    sleep(duration)
    redstone.setOutput(side, false)
    activeSides[side] = nil
end

local function announceWelcome()
    welcomeAlertUntil = os.clock() + 5
    local time = textutils.formatTime(os.time("ingame"), false)
    speak("Welcome aboard. The time is " .. time .. ".", "welcome announcement")
end

local function listenForWelcomeSignal()
    local wasPowered = redstone.getInput(WELCOME_SIDE)

    while true do
        os.pullEvent("redstone")
        local isPowered = redstone.getInput(WELCOME_SIDE)
        if isPowered and not wasPowered then
            announceWelcome()
        end
        wasPowered = isPowered
    end
end

local function runMonitor()
    local monitor = peripheral.wrap(MONITOR_NAME)
    if not monitor or peripheral.getType(MONITOR_NAME) ~= "monitor" then
        print("Monitor " .. MONITOR_NAME .. " not connected; dashboard disabled")
        return
    end

    monitor.setTextScale(0.5)
    monitor.setCursorBlink(false)

    local function writeAt(x, y, text, foreground, background)
        monitor.setCursorPos(x, y)
        monitor.setTextColor(foreground or colors.white)
        monitor.setBackgroundColor(background or colors.black)
        monitor.write(text)
    end

    local function fill(x, y, width, height, color)
        monitor.setBackgroundColor(color)
        for row = y, y + height - 1 do
            monitor.setCursorPos(x, row)
            monitor.write(string.rep(" ", width))
        end
    end

    local function centered(y, text, foreground, background)
        local width = monitor.getSize()
        writeAt(math.max(1, math.floor((width - #text) / 2) + 1), y,
            text, foreground, background)
    end

    local frame = 0
    while true do
        local width, height = monitor.getSize()
        local alert = os.clock() < welcomeAlertUntil
        local accent = alert and colors.orange or colors.red
        local radarWidth = math.min(27, math.floor(width * 0.52))
        local panelX = radarWidth + 2
        local radarTop = 6
        local radarBottom = math.max(radarTop + 8, height - 5)
        local centerX = math.max(6, math.floor(radarWidth / 2))
        local centerY = math.floor((radarTop + radarBottom) / 2)
        local radiusX = math.max(4, centerX - 3)
        local radiusY = math.max(3, math.floor((radarBottom - radarTop) / 2) - 1)
        local angle = (frame % 32) * math.pi / 16

        monitor.setBackgroundColor(colors.black)
        monitor.clear()
        fill(1, 1, width, 1, accent)
        centered(2, "A E G I S   N E X U S", colors.white, colors.black)
        centered(3, alert and "// DOCKING SIGNAL DETECTED //" or
            "// RESTRICTED OPERATIONS GRID //", accent, colors.black)
        fill(1, 4, width, 1, colors.gray)

        -- Animated tactical radar grid and sweep.
        for y = radarTop, radarBottom do
            for x = 2, radarWidth do
                local dx = (x - centerX) / radiusX
                local dy = (y - centerY) / radiusY
                local distance = math.sqrt(dx * dx + dy * dy)
                local char, color = " ", colors.green
                if math.abs(distance - 1) < 0.09 or
                    math.abs(distance - 0.55) < 0.07 then
                    char, color = ".", colors.green
                end
                if x == centerX or y == centerY then
                    char, color = "+", colors.gray
                end

                local sweepDistance = math.abs(dx * math.sin(angle) -
                    dy * math.cos(angle))
                local forward = dx * math.cos(angle) + dy * math.sin(angle)
                if distance <= 1 and sweepDistance < 0.08 and forward >= 0 then
                    char, color = "#", colors.lime
                end
                if char ~= " " then
                    writeAt(x, y, char, color, colors.black)
                end
            end
        end

        local contacts = {
            { -0.55, -0.30 }, { 0.42, 0.52 }, { 0.68, -0.48 }
        }
        for index, contact in ipairs(contacts) do
            local x = centerX + math.floor(contact[1] * radiusX)
            local y = centerY + math.floor(contact[2] * radiusY)
            local visible = (frame + index * 3) % 8 < 6
            writeAt(x, y, visible and "X" or ".",
                visible and colors.orange or colors.red, colors.black)
        end

        if panelX + 12 <= width then
            writeAt(panelX, 6, "SYSTEM STATUS", accent)
            writeAt(panelX, 8, "CORE", colors.lightGray)
            writeAt(panelX + 9, 8, "ONLINE", colors.lime)
            writeAt(panelX, 10, "VOICE", colors.lightGray)
            writeAt(panelX + 9, 10, "LINKED", colors.lime)
            writeAt(panelX, 12, "SECURITY", colors.lightGray)
            writeAt(panelX + 9, 12, alert and "VERIFY" or "ARMED",
                alert and colors.orange or colors.red)
            writeAt(panelX, 15, "LOCAL TIME", colors.gray)
            writeAt(panelX, 16, textutils.formatTime(os.time("ingame"), false),
                colors.white)
            writeAt(panelX, 19, "CLEARANCE", colors.gray)
            writeAt(panelX, 20, "TOP SECRET", colors.red)
            writeAt(panelX, 23, "TRACKED", colors.gray)
            writeAt(panelX, 24, "03 CONTACTS", colors.orange)
        end

        local scanWidth = math.max(1, width - 18)
        local scan = (frame % scanWidth) + 1
        writeAt(1, height - 2, string.rep("-", width), colors.gray)
        writeAt(2, height - 1, "ENCRYPTED UPLINK", colors.lightGray)
        writeAt(math.min(width, 18 + scan), height - 1, ">", colors.lime)
        centered(height, "PROPERTY OF AEGIS // EYES ONLY", colors.red,
            colors.black)

        frame = frame + 1
        sleep(0.15)
    end
end

local chatBox = peripheral.find("chatBox")
if not chatBox then
    error("No Advanced Peripherals Chat Box is connected", 0)
end

local function sendStatus(message)
    local sent, problem = chatBox.sendMessage(message, CHAT_PREFIX)
    if not sent then
        sleep(1)
        sent, problem = chatBox.sendMessage(message, CHAT_PREFIX)
    end
    if not sent then
        printError("Chat Box: " .. tostring(problem))
    end
end

local function listen()
    sendStatus("Voice commands online")
    print("Voice command bridge online")

    while true do
        local response, problem = http.get(BRIDGE_URL, nil, true)
        if response then
            local raw = response.readAll()
            response.close()
            local data = textutils.unserialiseJSON(raw)

            if data then
                runCommand(data)
            end
        else
            printError("STT bridge: " .. tostring(problem))
            sleep(2)
        end
        sleep(POLL_SECONDS)
    end
end

local ok, problem = pcall(function()
    parallel.waitForAll(listen, listenForWelcomeSignal, runMonitor)
end)

-- Do not leave a command output powered if the program is terminated mid-pulse.
for side in pairs(activeSides) do
    redstone.setOutput(side, false)
end

sendStatus("Voice commands offline")
print("Voice command bridge offline")
if not ok and tostring(problem) ~= "Terminated" then
    printError(problem)
end
