function isFeature(sLine)
    return caseInsensitiveStartsWith(sLine, 'feature:')
end

function isScenario(sLine)
    return caseInsensitiveStartsWith(sLine, 'scenario:')
end

function isGivenWhenThen(sLine)
    return caseInsensitiveStartsWith(sLine, 'given ') or
        caseInsensitiveStartsWith(sLine, 'and ') or
        caseInsensitiveStartsWith(sLine, 'but ') or
        caseInsensitiveStartsWith(sLine, 'when ') or
        caseInsensitiveStartsWith(sLine, 'then ')
end

function caseInsensitiveStartsWith(sString, sLeadingText)
    sString = StringManager.trim(sString:lower())
    return StringManager.startsWith(sString, sLeadingText)
end

function storyNodeToTextLines(nStory)
    local sText = DB.getValue(nStory, 'text')
    sText = sText:gsub('</p><p>', "\n")
    sText = sText:gsub('<p />', '\n')
    sText = sText:gsub('<p>', '')
    sText = sText:gsub('</p>', '')
    sText = sText:gsub('&#34;', '"')
    return StringManager.split(sText, "\n")
end

function parseName(sLine)
    local a = StringManager.split(StringManager.trim(sLine), ":")
    return a[2]
end

function endsWith(s, sCheck)
    return (s:sub(-1) == sCheck);
end

function parseGivenWhenThen(sLine)
    sLine = StringManager.trim(sLine)
    local a = StringManager.split(sLine, " ")
    a = { unpack(a, 2) }
    local out = {}
    local bQuoting = false
    local aQuoted = {}
    local aArgs = {}
    for _, sWord in ipairs(a) do
        if StringManager.startsWith(sWord, '"') then
            if bQuoting then
                error("Found a new quote when the first quote wasn't closed")
            end
            sWord = string.sub(sWord, 2)
            bQuoting = true
        end
        if bQuoting then
            local bEndQuote = false
            if endsWith(sWord, '"') then
                bQuoting = false
                sWord = string.sub(sWord, 1, -2)
                bEndQuote = true
            end
            table.insert(aQuoted, sWord)
            if bEndQuote then
                local sArg = table.concat(aQuoted, ' ')
                table.insert(aArgs, sArg)
            end
        elseif StringManager.isNumberString(sWord) then
            table.insert(aArgs, sWord)
        else
            sWord = sWord:gsub('[^a-zA-Z]','')
            sWord = StringManager.titleCase(sWord)
            table.insert(out, sWord)
        end
    end
    return {
        sFunctionName = table.concat(out),
        aArgs = aArgs,
        sText = sLine,
    }
end

function parse(nStory)
    local aLines = storyNodeToTextLines(nStory)
    local sName = DB.getValue(nStory, 'name')

    local gherkin = {
        story = {},
        scenarioNames = {},
        scenarios = {},
        feature = parseName(sName),
    }
    local scenarioIndex = 0
    local scenario = {}

    local function addAccumulatingScenario()
        if scenarioIndex > 0 then
            gherkin.scenarios[scenarioIndex] = scenario
        end
        scenario = {}
    end

    for _, sLine in ipairs(aLines) do
        if isFeature(sLine) then
            gherkin['feature'] = parseName(sLine)
        elseif isScenario(sLine) then
            addAccumulatingScenario()
            table.insert(gherkin.scenarioNames, parseName(sLine))
            scenarioIndex = #(gherkin.scenarioNames)
        elseif isGivenWhenThen(sLine) then
            table.insert(scenario, parseGivenWhenThen(sLine))
        else
            local trimmed = StringManager.trim(sLine)
            if trimmed ~= '' then
                table.insert(gherkin.story, trimmed)
            end
        end
    end

    addAccumulatingScenario()

    return gherkin
end
