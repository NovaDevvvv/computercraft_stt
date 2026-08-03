-- Change this to the blue bridge URL shown in the desktop STT window.
local BRIDGE_URL = "https://ccstt.novaa.dev/next?token=ccstt-8e4f73b12a6d"
local COMMANDS_URL = "https://raw.githubusercontent.com/NovaDevvvv/computercraft_stt/refs/heads/main/commands.json"
local CHAT_PREFIX = "Voice"
local POLL_SECONDS = 0.25
local VALID_SIDES = {
    top = true, bottom = true, left = true,
    right = true, front = true, back = true
}

local function loadCommands()
    local response, problem = http.get(COMMANDS_URL, nil, true)
    if not response then
        error("Could not download commands.json: " .. tostring(problem), 0)
    end

    local data = textutils.unserialiseJSON(response.readAll())
    response.close()
    if not data or type(data.commands) ~= "table" then
        error("commands.json must contain a commands array", 0)
    end
    return data.commands
end

local function normalizedWords(value)
    return string.lower(value):gsub("[^%w]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function runJarvisCommand(message, commands)
    local request = normalizedWords(message):match("^jarvis%s+(.+)$")
    if not request then
        return
    end

    for _, command in ipairs(commands) do
        if type(command.command) == "string" and normalizedWords(command.command) == request then
            local side = command.side
            local duration = math.max(tonumber(command.duration) or 1, 0)
            if not VALID_SIDES[side] then
                printError("Invalid command configuration for " .. request)
                return
            end

            print("Jarvis command: " .. request .. " -> " .. side)
            redstone.setOutput(side, true)
            sleep(duration)
            redstone.setOutput(side, false)
            return
        end
    end
end

local chatBox = peripheral.find("chatBox")
if not chatBox then
    error("No Advanced Peripherals Chat Box is connected", 0)
end

local commands = loadCommands()

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
    print("Loaded " .. #commands .. " Jarvis command(s)")

    while true do
        local response, problem = http.get(BRIDGE_URL, nil, true)
        if response then
            local raw = response.readAll()
            response.close()
            local data = textutils.unserialiseJSON(raw)

            if data and type(data.message) == "string" and data.message ~= "" then
                runJarvisCommand(data.message, commands)
            end
        else
            printError("STT bridge: " .. tostring(problem))
            sleep(2)
        end
        sleep(POLL_SECONDS)
    end
end

local ok, problem = pcall(listen)

-- Do not leave a command output powered if the program is terminated mid-pulse.
for _, command in ipairs(commands) do
    if VALID_SIDES[command.side] then
        redstone.setOutput(command.side, false)
    end
end

sendStatus("Voice commands offline")
print("Voice command bridge offline")
if not ok and tostring(problem) ~= "Terminated" then
    printError(problem)
end
