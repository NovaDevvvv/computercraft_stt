-- Change this to the blue bridge URL shown in the desktop STT window.
local BRIDGE_URL = "https://ccstt.novaa.dev/next?token=ccstt-8e4f73b12a6d"
local CHAT_PREFIX = "Voice"
local POLL_SECONDS = 0.25

local chatBox = peripheral.find("chatBox")
if not chatBox then
    error("No Advanced Peripherals Chat Box is connected", 0)
end

print("Voice chat bridge started")
print("Reading from " .. BRIDGE_URL)

while true do
    local response, problem = http.get(BRIDGE_URL, nil, true)
    if response then
        local raw = response.readAll()
        response.close()
        local data = textutils.unserialiseJSON(raw)

        if data and type(data.message) == "string" and data.message ~= "" then
            local sent, sendError = chatBox.sendMessage(data.message, CHAT_PREFIX)
            if sent then
                print(data.message)
                print("DONE")
            else
                printError("Chat Box: " .. tostring(sendError))
                sleep(1)
            end
        end
    else
        printError("STT bridge: " .. tostring(problem))
        sleep(2)
    end
    sleep(POLL_SECONDS)
end
