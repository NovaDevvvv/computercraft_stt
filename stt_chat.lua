-- Change this to the blue bridge URL shown in the desktop STT window.
local BRIDGE_URL = "https://ccstt.novaa.dev/next?token=ccstt-8e4f73b12a6d"
local CHAT_PREFIX = "Voice"
local POLL_SECONDS = 0.25
local TTS_URL = "https://music.madefor.cc/tts?text="
local WELCOME_SIDE = "top"
local VALID_SIDES = {
    top = true, bottom = true, left = true,
    right = true, front = true, back = true
}

local activeSides = {}

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
    parallel.waitForAll(listen, listenForWelcomeSignal)
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
