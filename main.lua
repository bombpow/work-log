local meeting = require("meeting")
local actions = require("actions")
local goals = require("goals")
local notes = require("notes")

local function main()
    print("Welcome to the Note-Taking App")
    while true do
        io.write("> ")
        local input = io.read()
        local command, args = input:match("^(%S+)%s*(.*)$")

        -- Commands that don't require an active meeting
        if command == "start" then
            meeting.start(args)
        elseif command == "open" then
            meeting.list(args)
        elseif command == "find" then
            meeting.find(args)
        elseif command == "quit" then
            meeting.endMeeting()
            print("Exiting. Goodbye!")
            break

        -- Commands that require an active meeting
        else
            if not meeting.getCurrentMeeting() then
                print("Error: No active meeting. Please start a meeting to proceed.")
            else
                if command == "end" then
                    meeting.endMeeting()
                elseif command == "action" then
                    actions.add(args)
                elseif command == "whoami" then
                    meeting.whoami()
                elseif command == "tag" then
                    actions.manageTags(args)
                elseif command == "list" then
                    actions.list(args)
                elseif command == "update" then
                    actions.update(args)
                elseif command == "info" then
                    actions.info(args)
                elseif command == "done" then
                    actions.done(args)
                elseif command == "goal" then
                    goals.add(args)
                elseif command == "goal-list" then
                    goals.list()
                elseif command == "note" then
                    notes.add(args)
                else
                    print("Unknown command. Try again.")
                end
            end
        end
    end
end

main()
