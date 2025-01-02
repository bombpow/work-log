local meeting = require("meeting")

local notes = {}

function notes.add(description)
    if not description or description == "" then
        print("Error: Note description cannot be empty.")
        return
    end

    meeting.addEntry("| " .. description)
    print("Added note:", description)
end

return notes
