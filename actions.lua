local json = require("dkjson") -- For JSON handling
local meeting = require("meeting") -- Import the meeting module

local actions = {} -- Initialize actions table
local actionsFile = "data/actions.json"
actions.workingList = {} -- Store the current working list of actions

-- Helper function to trim whitespace
local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

-- Helper function to split a string by a delimiter
local function split(input, delimiter)
    local result = {}
    for match in (input .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, trim(match))
    end
    return result
end

-- Load actions from file
local function loadActions()
    local file = io.open(actionsFile, "r")
    if file then
        local content = file:read("*a")
        file:close()
        return json.decode(content) or {}
    end
    return {}
end

-- Save actions to file
local function saveActions(data)
    local file = io.open(actionsFile, "w")
    if file then
        file:write(json.encode(data, { indent = true }))
        file:close()
    end
end

-- Manage tags for a specific action
function actions.manageTags(index)
    local data = loadActions()

    -- Validate index
    index = tonumber(index)
    if not index or index < 1 or index > #data then
        print("Error: Invalid action number.")
        return
    end

    -- Get the selected action
    local action = data[index]

    -- Display the action and its tags
    print("\nAction:")
    print(index .. ". " .. action.description)
    print("Tags:")
    for i, tag in ipairs(action.tags) do
        print(i .. ". " .. tag)
    end

    -- Enter tag management mode
    while true do
        io.write("\nEnter a command (add <tags>, remove <indexes>, done): ")
        local input = io.read()
        local command, args = input:match("^(%S+)%s*(.*)$")

        if command == "add" then
            -- Add new tags
            local newTags = split(args, ",")
            for _, tag in ipairs(newTags) do
                table.insert(action.tags, tag)
            end
            print("Tags added. Updated tags:")
        elseif command == "remove" then
            -- Remove tags by index
            local indexesToRemove = split(args, ",")
            table.sort(indexesToRemove, function(a, b) return tonumber(b) > tonumber(a) end)
            for _, idx in ipairs(indexesToRemove) do
                idx = tonumber(idx)
                if idx and idx >= 1 and idx <= #action.tags then
                    table.remove(action.tags, idx)
                else
                    print("Error: Invalid tag index " .. idx)
                end
            end
            print("Tags removed. Updated tags:")
        elseif command == "done" then
            -- Save and exit tag management mode
            saveActions(data)
            print("Updated tags saved.")
            break
        else
            print("Error: Unknown command.")
        end

        -- Display updated tags after each command
        for i, tag in ipairs(action.tags) do
            print(i .. ". " .. tag)
        end
    end
end


function actions.add(input)
    local description, tags = input:match("^(.-)%s*|%s*(.*)$")
    
    -- If no tags delimiter is found, treat the whole input as the description
    if not description or description == "" then
        description = input
        tags = nil
    end

    if not description or description == "" then
        print("Error: Invalid action format. Use 'action <description> | <tags>'")
        return
    end

    local action = {
        description = description,
        tags = tags and split(tags, ",") or {},
        created = os.date("%Y-%m-%d %H:%M:%S"),
        location = nil, -- Placeholder for location
    }

    -- Trim tags during creation
    for i, tag in ipairs(action.tags) do
        action.tags[i] = trim(tag)
    end

    -- Add default tag if no tags are present
    if #action.tags == 0 then
        table.insert(action.tags, "normal")
    end

    -- Add action to JSON
    local data = loadActions()
    table.insert(data, action)
    saveActions(data)

    -- Write to meeting file and determine location
    local meetingFile = meeting.getCurrentMeeting()
    if meetingFile then
        -- Add the action to the meeting file
        meeting.addEntry("☐ Action: " .. description)

        -- Determine the line number of the new entry
        local file = io.open(meetingFile, "r")
        if file then
            local lines = 0
            for _ in file:lines() do
                lines = lines + 1
            end
            file:close()

            -- Update the location property
            action.location = {
                file = meetingFile,
                line = lines,
            }

            -- Save the updated actions with location
            saveActions(data)
        else
            print("Error: Could not open meeting file to determine location.")
        end
    else
        print("Error: No active meeting to associate the action with.")
    end

    print("Added action:", description)
end

-- List actions
function actions.list(filters)
    local data = loadActions()
    local filterTags = filters and split(filters, "|") or {}

    -- Function to match tags
    local function matchesTags(actionTags)
        if #filterTags == 0 then
            return true -- No filter, show all actions
        end

        for _, filter in ipairs(filterTags) do
            local found = false
            for _, tag in ipairs(actionTags) do
                if tag:lower():find(filter:lower(), 1, true) then -- Case-insensitive partial match
                    found = true
                    break
                end
            end
            if not found then
                return false -- Filter not found in tags
            end
        end
        return true -- All filters matched
    end

    -- Clear the working list and populate it with matching actions
    actions.workingList = {}
    for _, action in ipairs(data) do
        if matchesTags(action.tags) then
            table.insert(actions.workingList, action)
        end
    end

    -- Display the updated working list
    if #actions.workingList > 0 then
        for i, action in ipairs(actions.workingList) do
            print(i .. ". " .. action.description .. " [" .. table.concat(action.tags, ", ") .. "]")
        end
    else
        print("No actions match the specified tags.")
    end
end

-- Mark an action as done
function actions.done(index)
    index = tonumber(index)
    if not index or index < 1 or index > #actions.workingList then
        print("Error: Invalid action number.")
        return
    end

    -- Retrieve the action from the working list
    local actionToRemove = actions.workingList[index]

    -- Load the complete list of actions from the JSON file
    local data = loadActions()

    -- Remove the action from the full list
    for i, action in ipairs(data) do
        if action == actionToRemove then
            table.remove(data, i)
            break
        end
    end

    -- Save the updated list to the JSON file
    saveActions(data)

    -- Add a note to the current meeting
    local currentMeeting = meeting.getCurrentMeeting()
    if currentMeeting then
        local note = "✓ Action: " .. actionToRemove.description .. " [Tags: " .. table.concat(actionToRemove.tags, ", ") .. "] at " .. os.date("%Y-%m-%d %H:%M:%S")
        meeting.addEntry(note)
    else
        print("Error: No active meeting.")
    end

    -- Print confirmation
    print("Marked action as completed:", actionToRemove.description)

    -- Update the working list to reflect the new state
    actions.workingList = {}
    for _, action in ipairs(data) do
        table.insert(actions.workingList, action)
    end
end

-- Open meeting notes in an editor
function actions.info(index)
    index = tonumber(index)
    if not index or index < 1 or index > #actions.workingList then
        print("Error: Invalid action number.")
        return
    end

    local action = actions.workingList[index]
    if not action.location or not action.location.file or not action.location.line then
        print("Error: Action does not have valid location information.")
        return
    end

    -- Use Neovim to open the file at the specific line
    local command = string.format("vim +%d %s", action.location.line, action.location.file)
    os.execute(command)
end

-- Update an action description
function actions.update(input)
    local index, newDescription = input:match("^(%d+)%s+(.+)$")
    if not index or not newDescription then
        print("Error: Invalid update format. Use 'update <number> <new description>'")
        return
    end

    index = tonumber(index)
    if index < 1 or index > #actions.workingList then
        print("Error: Invalid action number.")
        return
    end

    local actionToUpdate = actions.workingList[index]
    local data = loadActions()

    for _, action in ipairs(data) do
        if action == actionToUpdate then
            action.description = newDescription
            saveActions(data)
            meeting.addEntry("Updated Action: [" .. actionToUpdate.description .. "] to [" .. newDescription .. "]")
            print("Updated action " .. index .. " to: " .. newDescription)
            return
        end
    end
end

return actions
