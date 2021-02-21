-- Constants
local TEST_TYPE_UNIT = 'unit'
local TEST_TYPE_BEHAVIOURAL = 'behavioural'

-- Default to presenting only failures in chat
local bVerbose = false

-- Statistics
local nUnitSuccessCount = 0
local nUnitFailureCount = 0
local nBehaviouralSuccessCount = 0
local nBehaviouralFailureCount = 0

-- Other state
local aBehaviouralContexts = {}
local aTestQueue = {}

function onInit()
    Comm.registerSlashHandler("test", startTests)
end

function startTests(_, sParams)
    initializeTestRun()
    parseParams(sParams)
    queueUnitTests()
    queueBehaviouralTests()
    nextTest()
end

function registerBehaviouralContext(context)
    table.insert(aBehaviouralContexts, context)
end

function findBehaviouralFunction(sFunctionName)
    for _, context in ipairs(aBehaviouralContexts) do
        if context[sFunctionName] then
            return context[sFunctionName]
        end
    end
    return nil
end

function initializeTestRun()
    bPassing = true
    bVerbose = false
    nUnitSuccessCount = 0
    nUnitFailureCount = 0
    nBehaviouralSuccessCount = 0
    nBehaviouralFailureCount = 0
    aTestQueue = {}
end

function parseParams(sParams)
    local aParams = StringManager.split(sParams, ' ', true)
    for _, sParam in pairs(aParams) do
        if sParam == '-v' then
            bVerbose = true
        end
    end
end

function queueUnitTests()
    if not TestSuite.getTests then
        Comm.addChatMessage({text = "TestSuite must return a list of test functions in getTests()"})
    end
    local tests = TestSuite.getTests()
    for _, sTestName in ipairs(tests) do
        local fTest = TestSuite[sTestName]
        local fProvider = TestSuite[sTestName .. 'Provider']
        local aInvocationsAndArguments = { {} } -- One invocation with no parameters
        if fProvider then
            aInvocationsAndArguments = fProvider()
            if type(aInvocationsAndArguments) ~= 'table' then
                Comm.addChatMessage({text = "Provider for " .. sTestName .. " didn't return a table"})
            end
        end
        for invocation, aArguments in pairs(aInvocationsAndArguments) do
            table.insert(aTestQueue, {
                sType = TEST_TYPE_UNIT,
                sName = sTestName,
                invocation = invocation,
                fTest = fTest,
                aArguments = aArguments,
            })
        end
    end
end

function nextTest()
    rTest = aTestQueue[1]
    aTestQueue = { unpack(aTestQueue, 2) }
    if rTest then
        local result
        if rTest.aAnnounce then
            for _, sMessage in ipairs(rTest.aAnnounce) do
                Comm.addChatMessage({text = sMessage})
            end
        end
        if rTest.sType == TEST_TYPE_UNIT then
            result = invokeUnitTest(rTest.sName, rTest.invocation, rTest.fTest, rTest.aArguments)
        elseif rTest.sType == TEST_TYPE_BEHAVIOURAL then
            result = invokeBehaviouralTest(rTest.rGherkin, rTest.sScenarioName, rTest.rBehavior, rTest.fTest)
        else
            Comm.addChatMessage({text = "Unexpected test type: " .. rTest.sType})
        end
        if type(result) == 'table' and result._type and result._type == Promises.TYPE_PROMISE then
            -- Test returned a promise. Wait for it to complete before moving on.
            local successCallback = function()
                -- The Lua stack size will only allow so many of these.
                -- I don't know another way to go though without a nextTick() or heartbeat function.
                -- Tested stack size up to 16,000 ok. Crashed at 17,000. Unsigned 16 bit int?
                -- Anyway, with 16,000 we should be ok for practical purposes.
                nextTest()
            end
            local failureCallback = function(error)
                reportBehaviouralTestFailure(rTest.rGherkin, rTest.sScenarioName, rTest.rBehavior, error)
                showSummary()
            end
            result:done(successCallback, failureCallback)
        else
            -- Normal synchronous response, move on with tail recursion
            return nextTest()
        end
    else
        showSummary()
    end
end

function invokeUnitTest(sTestName, invocation, fTest, aArguments)
    sTestName = sTestName .. ' (' .. invocation .. ')'
    local bSuccess, result = pcall(fTest, unpack(aArguments))
    if bSuccess then
        if bVerbose then
            Comm.addChatMessage({text = sTestName, icon="vam_fgtest_success"})
        end
        nUnitSuccessCount = nUnitSuccessCount + 1
    else
        if type(invocation) == 'string' then
            sTestName = sTestName .. ' (' .. invocation .. ')'
        end
        Comm.addChatMessage({ text = sTestName .. ': ' .. result, icon="vam_fgtest_failure"})
        if #aArguments > 0 then
            Debug.chat(sTestName .. ' arguments:', aArguments)
        end
        nUnitFailureCount = nUnitFailureCount + 1
    end
    return result
end

function queueBehaviouralTests()
    for _, nStory in pairs(DB.getChildren('encounter')) do
        local sStoryName = DB.getValue(nStory, 'name')
        if GherkinHelper.isFeature(sStoryName) then
            rGherkin = GherkinHelper.parse(nStory)
            queueBehaviouralTest(rGherkin)
        end
    end
end

function invokeBehaviouralTest(rGherkin, sScenarioName, rBehavior, f)
    local bSuccess, result = pcall(f, unpack(rBehavior.aArgs))
    if bSuccess then
        nBehaviouralSuccessCount = nBehaviouralSuccessCount + 1
        if bVerbose then
            if bVerbose then
                Comm.addChatMessage({text = rBehavior.sText, icon="vam_fgtest_success"})
            end
        end
    else
        reportBehaviouralTestFailure(rGherkin, sScenarioName, rBehavior, result)
    end
    return result
end

function reportBehaviouralTestFailure(rGherkin, sScenarioName, rBehavior, result)
    nBehaviouralFailureCount = nBehaviouralFailureCount + 1
    Comm.addChatMessage({
        text = 'In ' .. rGherkin.feature .. ' / ' .. sScenarioName .. ' - ' .. rBehavior.sText .. ': ' .. result,
        icon="vam_fgtest_failure",
    })
end

function queueBehaviouralTest(rGherkin)
    for nScenarioIndex, sScenarioName in ipairs(rGherkin.scenarioNames) do
        local aBehaviours = rGherkin.scenarios[nScenarioIndex]
        for nBehaviourIndex, rBehavior in ipairs(aBehaviours) do
            local rTest = {
                sType = TEST_TYPE_BEHAVIOURAL,
                aAnnounce = {},
            }
            if bVerbose then
                if nScenarioIndex == 1 then
                    table.insert(rTest.aAnnounce, "FGTest feature: " .. rGherkin.feature)
                end
                if nBehaviourIndex == 1 then
                    table.insert(rTest.aAnnounce, "Scenario: " .. sScenarioName)
                end
            end
            local f = findBehaviouralFunction(rBehavior.sFunctionName)
            if f then
                rTest['rGherkin'] = rGherkin
                rTest['sScenarioName'] = sScenarioName
                rTest['rBehavior'] = rBehavior
                rTest['fTest'] = f
                table.insert(aTestQueue, rTest)
            else
                Comm.addChatMessage({
                    text = "No context found with function: " .. rBehavior.sFunctionName,
                    icon="vam_fgtest_failure",
                })
            end
        end
    end
end

function showSummaryUnit()
    local nTotal = nUnitSuccessCount + nUnitFailureCount
    if nTotal == nUnitSuccessCount then
        Comm.addChatMessage({
            text = "All unit tests passed (" .. tostring(nTotal) .. " in total)",
            icon="vam_fgtest_success",
        })
        return
    end
    Comm.addChatMessage({
        text = tostring(nUnitSuccessCount) .. ' / ' .. tostring(nTotal) .. ' unit tests passed',
        icon="vam_fgtest_failure",
    })
end

function showSummaryBehavioural()
    local nTotal = nBehaviouralSuccessCount + nBehaviouralFailureCount
    if nTotal == 0 then
        return
    end
    if nTotal == nBehaviouralSuccessCount then
        Comm.addChatMessage({
            text = "All behavioural tests passed (" .. tostring(nTotal) .. " in total)",
            icon="vam_fgtest_success",
        })
        return
    end
    Comm.addChatMessage({
        text = tostring(nBehaviouralSuccessCount) .. ' / ' .. tostring(nTotal) .. ' behavioural tests passed',
        icon="vam_fgtest_failure",
    })
end

function showSummary()
    local nTotal = nUnitSuccessCount + nUnitFailureCount + nBehaviouralSuccessCount + nBehaviouralFailureCount
    if nTotal == 0 then
        Comm.addChatMessage({text = "No tests ran!", icon="vam_fgtest_failure"})
        return
    end
    showSummaryUnit()
    showSummaryBehavioural()
end
