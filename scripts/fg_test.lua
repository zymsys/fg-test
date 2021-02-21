-- Reach out to Superteddy57 at Smiteworks when you have this ready for beta testing.
-- Moon Wizard says he's working on automated API tests.
-- https://discord.com/channels/274582899045695488/275749854435868682/812773250731343882

-- Default to presenting only failures in chat
local bVerbose = false

-- Statistics
local nUnitSuccessCount = 0
local nUnitFailureCount = 0
local nBehaviouralSuccessCount = 0
local nBehaviouralFailureCount = 0

-- Other state
local aBehaviouralContexts = {}

function onInit()
    Comm.registerSlashHandler("test", startTests)
end

function startTests(_, sParams)
    initializeTestRun()
    parseParams(sParams)
    runUnitTests()
    if nUnitFailureCount == 0 then
        runBehaviouralTests()
    end
    showSummary()
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
end

function parseParams(sParams)
    local aParams = StringManager.split(sParams, ' ', true)
    for _, sParam in pairs(aParams) do
        if sParam == '-v' then
            bVerbose = true
        end
    end
end

function runUnitTests()
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
            invokeUnitTest(sTestName, invocation, fTest, aArguments)
        end
    end
end

function invokeUnitTest(sTestName, invocation, fTest, aArguments)
    sTestName = sTestName .. ' (' .. invocation .. ')'
    local bSuccess, err = pcall(fTest, unpack(aArguments))
    if bSuccess then
        if bVerbose then
            Comm.addChatMessage({text = sTestName, icon="vam_fgtest_success"})
        end
        nUnitSuccessCount = nUnitSuccessCount + 1
    else
        if type(invocation) == 'string' then
        end
        Comm.addChatMessage({text = sTestName .. ': ' .. err, icon="vam_fgtest_failure"})
        if #aArguments > 0 then
            Debug.chat(sTestName .. ' arguments:', aArguments)
        end
        nUnitFailureCount = nUnitFailureCount + 1
    end
end

function runBehaviouralTests()
    for _, nStory in pairs(DB.getChildren('encounter')) do
        local sStoryName = DB.getValue(nStory, 'name')
        if GherkinHelper.isFeature(sStoryName) then
            rGherkin = GherkinHelper.parse(nStory)
            runBehaviouralTest(rGherkin)
        end
    end
end

function invokeBehaviouralTest(rGherkin, sScenarioName, rBehavior, f)
    local bSuccess, err = pcall(f, unpack(rBehavior.aArgs))
    if bSuccess then
        nBehaviouralSuccessCount = nBehaviouralSuccessCount + 1
        if bVerbose then
            if bVerbose then
                Comm.addChatMessage({text = rBehavior.sText, icon="vam_fgtest_success"})
            end
        end
    else
        nBehaviouralFailureCount = nBehaviouralFailureCount + 1
        Comm.addChatMessage({
            text = 'In ' .. rGherkin.feature .. ' / ' .. sScenarioName .. ' - ' .. rBehavior.sText .. ': ' .. err,
            icon="vam_fgtest_failure",
        })
    end
end

function runBehaviouralTest(rGherkin)
    if bVerbose then
        Comm.addChatMessage({
            text = "FGTest feature: " .. rGherkin.feature,
        })
    end
    for nIndex, sScenarioName in ipairs(rGherkin.scenarioNames) do
        if bVerbose then
            Comm.addChatMessage({
                text = "Scenario: " .. sScenarioName,
            })
        end
        local aBehaviours = rGherkin.scenarios[nIndex]
        for _, rBehavior in ipairs(aBehaviours) do
            local f = findBehaviouralFunction(rBehavior.sFunctionName)
            if f then
                invokeBehaviouralTest(rGherkin, sScenarioName, rBehavior, f)
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
