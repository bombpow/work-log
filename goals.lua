local json = require("dkjson") -- JSON library for handling JSON
local meeting = require("meeting")

local goals = {}
local goalsFile = "goals.json"

-- Load goals from file
local function loadGoals()
    local file = io.open(goalsFile, "r")
    if file then
        local content = file:read("*a")
        file:close()
        return json.decode(content) or {}
    end
    return {}
end

-- Save goals to file
local function saveGoals(data)
    local file = io.open(goalsFile, "w")
    if file then
        file:write(json.encode(data, { indent = true }))
        file:close()
    end
end

-- Add a new goal
function goals.add(input)
    local description, tags = input:match("^(.-)%s*|%s*(.*)$")
    if not description then
        print("Error: Invalid goal format. Use 'goal <description> | <tags>'")
        return
    end

    local goal = {
        description = description,
        tags = tags and tags:split(",") or {},
        created = os.date("%Y-%m-%d %H:%M:%S"),
        meeting = meeting.getCurrentMeeting() or "Unknown",
    }

    local data = loadGoals()
    table.insert(data, goal)
    saveGoals(data)
    meeting.addEntry("Goal Added: " .. description)
    print("Added goal:", description)
end

-- List all goals
function goals.list(filters)
    local data = loadGoals()
    local filtered = {}

    -- Filter goals if tags are specified
    if filters and filters ~= "" then
        local filterTags = {}
        for tag in filters:gmatch("[^%s]+") do
            table.insert(filterTags, tag)
        end

        for _, goal in ipairs(data) do
            local match = true
            for _, tag in ipairs(filterTags) do
                if not table.concat(goal.tags, ", "):find(tag) then
                    match = false
                    break
                end
            end
            if match then table.insert(filtered, goal) end
        end
    else
        filtered = data
    end

    -- Print filtered or all goals
    if #filtered > 0 then
        for i, goal in ipairs(filtered) do
            print(i .. ". " .. goal.description .. " [" .. table.concat(goal.tags, ", ") .. "]")
        end
    else
        print("No matching goals found.")
    end
end

-- Complete a goal
function goals.complete(index)
    local data = loadGoals()
    index = tonumber(index)

    if index and data[index] then
        local goal = table.remove(data, index)
        saveGoals(data)
        meeting.addEntry("Goal Completed: " .. goal.description .. " at " .. os.date("%Y-%m-%d %H:%M:%S"))
        print("Completed goal:", goal.description)
    else
        print("Error: Invalid goal number.")
    end
end

-- Add a tag to a goal
function goals.addTag(index, tag)
    local data = loadGoals()
    index = tonumber(index)

    if index and data[index] then
        table.insert(data[index].tags, tag)
        saveGoals(data)
        print("Added tag '" .. tag .. "' to goal:", data[index].description)
    else
        print("Error: Invalid goal number.")
    end
end

-- Remove a tag from a goal
function goals.removeTag(index, tag)
    local data = loadGoals()
    index = tonumber(index)

    if index and data[index] then
        for i, t in ipairs(data[index].tags) do
            if t == tag then
                table.remove(data[index].tags, i)
                saveGoals(data)
                print("Removed tag '" .. tag .. "' from goal:", data[index].description)
                return
            end
        end
        print("Error: Tag '" .. tag .. "' not found in goal.")
    else
        print("Error: Invalid goal number.")
    end
end

return goals
