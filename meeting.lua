local meeting = {}
local currentMeeting = nil
local meetingsFolder = "data/meetings/"

-- Ensure the folder exists
local function ensureMeetingsFolder()
    os.execute("mkdir -p " .. meetingsFolder)
end

-- Helper function to get timestamp
local function getTimestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

-- Helper function to check if a file exists
local function fileExists(fileName)
    local file = io.open(fileName, "r")
    if file then
        file:close()
        return true
    end
    return false
end

-- Get the full path of a meeting file
local function getMeetingFilePath(name)
    return meetingsFolder .. name
end

-- List all meetings or filter by text
local function openCurrentMeeting()
    if not currentMeeting then
        print("Error: No active meeting to open.")
        return
    end
    os.execute(string.format("vim + %s", currentMeeting))
end

-- Function to return the name of the current meeting
function meeting.whoami()
    if currentMeeting then
        print("Current meeting: " .. currentMeeting)
    else
        print("No active meeting.")
    end
end

-- Helper function to list existing meetings
local function listMeetings()
    local meetings = {}
    local handle = io.popen("ls " .. meetingsFolder .. "*.txt 2>/dev/null")
    if handle then
        for file in handle:lines() do
            local meetingName = file:match(meetingsFolder .. "(.*)%.txt$")
            if meetingName then
                table.insert(meetings, meetingName)
            end
        end
        handle:close()
    end
    return meetings
end

function meeting.list(query)
    ensureMeetingsFolder()
    if query == "." then
        openCurrentMeeting()
        return
    end

    local existingMeetings = listMeetings()
    local matchingMeetings = {}

    if query and query ~= "" then
        for _, meetingName in ipairs(existingMeetings) do
            if meetingName:find(query, 1, true) then
                table.insert(matchingMeetings, meetingName)
            end
        end
    else
        matchingMeetings = existingMeetings
    end

    if #matchingMeetings == 0 then
        print("No meetings found.")
        return
    end

    print("\nMatching Meetings:")
    for i, meetingName in ipairs(matchingMeetings) do
        print(i .. ". " .. meetingName)
    end

    io.write("\nEnter the number of the meeting to open or press Enter to cancel: ")
    local choice = io.read()
    local meetingIndex = tonumber(choice)
    if meetingIndex and meetingIndex >= 1 and meetingIndex <= #matchingMeetings then
        os.execute(string.format("vim + %s", getMeetingFilePath(matchingMeetings[meetingIndex] .. ".txt")))
    else
        print("No meeting opened.")
    end
end

function meeting.getCurrentMeeting()
    return currentMeeting
end

function meeting.start(name)
    ensureMeetingsFolder()
    if not name or name == "" then
        print("Error: Please provide a meeting name.")
        return
    end

    local existingMeetings = listMeetings()
    local matchingMeetings = {}
    for _, meetingName in ipairs(existingMeetings) do
        if meetingName:find(name, 1, true) then
            table.insert(matchingMeetings, meetingName)
        end
    end

    if #matchingMeetings > 0 then
        print("\nOptions for meeting '" .. name .. "':")
        print("1. Create a new meeting '" .. name .. "'")
        local index = 2
        for _, meetingName in ipairs(existingMeetings) do
            print(index .. ". Start existing meeting '" .. meetingName .. "'")
            index = index + 1
        end
        print(index .. ". Start a new meeting with a different name")
        print(index + 1 .. ". Cancel meeting creation")
        io.write("Enter your choice: ")
        local choice = tonumber(io.read())

        if choice == 1 then
            if currentMeeting then
                print("Ending current meeting:", currentMeeting)
                meeting.endMeeting()
            end
            meeting.createMeeting(name)
        elseif choice >= 2 and choice < index then
            local selectedMeeting = matchingMeetings[choice - 1]
            if currentMeeting then
                print("Ending current meeting:", currentMeeting)
                meeting.endMeeting()
            end
            meeting.resumeMeeting(selectedMeeting)
        elseif choice == index then
            io.write("Enter a unique meeting name: ")
            meeting.start(io.read())
        elseif choice == index + 1 then
            print("Meeting creation canceled.")
        else
            print("Invalid choice.")
        end
    else
        meeting.createMeeting(name)
    end
end

function meeting.createMeeting(name)
    local fileName = getMeetingFilePath(name .. ".txt")
    local file = io.open(fileName, "a")
    if file then
        currentMeeting = fileName
        file:write("Meeting Created: " .. getTimestamp() .. "\n")
        file:close()
        print("Started new meeting:", name)
    else
        print("Error: Could not create meeting.")
    end
end

function meeting.resumeMeeting(name)
    local fileName = getMeetingFilePath(name .. ".txt")
    if fileExists(fileName) then
        currentMeeting = fileName
        local file = io.open(fileName, "a")
        if file then
            file:write("Meeting Resumed: " .. getTimestamp() .. "\n")
            file:close()
        end
        print("Resumed meeting:", name)
    else
        print("Error: Meeting not found.")
    end
end

function meeting.endMeeting()
    if not currentMeeting then
        print("No active meeting to end.")
        return
    end

    local file = io.open(currentMeeting, "a")
    if file then
        file:write("Meeting Ended: " .. getTimestamp() .. "\n")
        file:close()
        print("Ended meeting:", currentMeeting)
        currentMeeting = nil
    end
end

function meeting.addEntry(entry)
    if not currentMeeting then
        print("Error: No active meeting.")
        return
    end

    local file = io.open(currentMeeting, "a")
    if file then
        file:write(entry .. "\n")
        file:close()
    else
        print("Error: Could not write to meeting.")
    end
end

local function searchFileOnce(fileName, searchText)
    local file = io.open(fileName, "r")
    if file then
        for line in file:lines() do
            if line:find(searchText, 1, true) then
                file:close()
                return true
            end
        end
        file:close()
    end
    return false
end

local function searchFileDeep(fileName, searchText)
    local matches = {}
    local lineNum = 1
    local file = io.open(fileName, "r")
    if file then
        for line in file:lines() do
            if line:find(searchText, 1, true) then
                table.insert(matches, { line = lineNum, content = line })
            end
            lineNum = lineNum + 1
        end
        file:close()
    end
    return matches
end

function meeting.find(searchText)
    ensureMeetingsFolder()
    if not searchText or searchText == "" then
        print("Error: Provide text to search.")
        return
    end

    local matchingFiles = {}
    local handle = io.popen("ls " .. meetingsFolder .. "*.txt 2>/dev/null")
    if handle then
        for file in handle:lines() do
            if searchFileOnce(file, searchText) then
                table.insert(matchingFiles, file)
            end
        end
        handle:close()
    end

    if #matchingFiles == 0 then
        print("No matches found.")
        return
    end

    print("\nMeetings with \"" .. searchText .. "\":")
    for i, file in ipairs(matchingFiles) do
        print(i .. ". " .. file)
    end

    io.write("\nChoose a meeting to search in detail: ")
    local choice = tonumber(io.read())
    if not choice or choice < 1 or choice > #matchingFiles then
        print("Invalid choice.")
        return
    end

    local selectedFile = matchingFiles[choice]
    local matches = searchFileDeep(selectedFile, searchText)
    if #matches == 0 then
        print("No detailed matches found.")
        return
    end

    print("\nDetailed matches in " .. selectedFile .. ":")
    for i, match in ipairs(matches) do
        print(i .. ". Line " .. match.line .. ": " .. match.content)
    end

    io.write("\nChoose a match to open in vim: ")
    local matchChoice = tonumber(io.read())
    if not matchChoice or matchChoice < 1 or matchChoice > #matches then
        print("Invalid match choice.")
        return
    end

    local selectedMatch = matches[matchChoice]
    os.execute(string.format("vim +%d %s", selectedMatch.line, selectedFile))
end

return meeting
