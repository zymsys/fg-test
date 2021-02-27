function getTests()
    return {
        'testIsFeature',
        'testIsScenario',
        'testIsGivenWhenThen',
        'testParseGivenWhenThen',
        'testPromiseChaining',
        --'testPromiseRoll',
    }
end

-- Really testing a lot of cases for caseInsensitiveStartsWith through isFeature
function testIsFeatureProvider()
    local testCases = {}
    testCases['normal'] = {true, "Feature: This is a feature"}
    testCases['all lower'] = {true, "feature: This is still a feature even without an upper case f"}
    testCases['all caps'] = {true, "FEATURE: This is still a feature even when YELLING"}
    testCases['mixed case'] = {true, "fEatUrE: This is still a feature even in CraZy case"}
    testCases['no space'] = {true, "Feature:This is a feature even without a space after the :"}
    testCases['leading white'] = {true, " Feature: This is a feature with leading whitespace"}
    testCases['trailing white'] = {true, "Feature: This is a feature with trailing whitespace "}
    testCases['both white'] = {true, " Feature: This is a feature with leading and trailing whitespace "}
    testCases['not a feature'] = {false, "This is just a story, not a feature"}
    return testCases
end

function testIsFeature(bExpectedIsFeature, sStoryName)
    local bActualIsFeature = GherkinHelper.isFeature(sStoryName)
    Assert.equals(bExpectedIsFeature, bActualIsFeature)
end

function testIsScenario()
    Assert.isTrue(GherkinHelper.isScenario('Scenario:'))
    Assert.isFalse(GherkinHelper.isScenario('Not a Scenario'))
end

function testIsGivenWhenThenProvider()
    local testCases = {}
    testCases['given'] = {true, "Given is a given/when/then"}
    testCases['given white'] = {true, " Given is a given/when/then with leading whitespace"}
    testCases['given case'] = {true, "given is a given/when/then with leading whitespace"}
    testCases['and'] = {true, "And is a given/when/then"}
    testCases['but'] = {true, "but is a given/when/then"}
    testCases['when'] = {true, "when is a given/when/then"}
    testCases['then'] = {true, "then is a given/when/then"}
    testCases['story'] = {false, "As a x I want to y so I can z"}
    return testCases
end

function testIsGivenWhenThen(bExpected, sLine)
    local bActualIsGivenWhenThen = GherkinHelper.isGivenWhenThen(sLine)
    Assert.equals(bExpected, bActualIsGivenWhenThen)
end

function testParseGivenWhenThen()
    local p = GherkinHelper.parseGivenWhenThen('Given a clean slate')
    Assert.equals('ACleanSlate', p.sFunctionName)
    Assert.count(0, p.aArgs)
    p = GherkinHelper.parseGivenWhenThen('And we add a PC named "Dorarsot Stormhead"')
    Assert.equals('WeAddAPcNamed', p.sFunctionName)
    Assert.count(1, p.aArgs)
    Assert.equals('Dorarsot Stormhead', p.aArgs[1])
    p = GherkinHelper.parseGivenWhenThen('And "Dorarsot Stormhead" has 5 rations')
    Assert.equals('HasRations', p.sFunctionName)
    Assert.count(2, p.aArgs)
    Assert.equals('Dorarsot Stormhead', p.aArgs[1])
    Assert.equals('5', p.aArgs[2])
end

function testPromiseChaining()
    local promiseToAddTwentyTwo = Promises.promise(function (resolve, n)
        Assert.equals(42, n)
        resolve(n + 22)
    end)
    Promises.promise(42
    ):andThen(promiseToAddTwentyTwo
    ):andThen(function(resolve, n)
        Assert.equals(64, n)
        resolve(math.sqrt(n))
    end):done(function(actual)
        Assert.equals(8, actual)
    end)
end

function testPromiseRoll()
    local sTestRollType = 'fgtest'

    return Promises.promise(function (resolve)
        -- Initiate async action
        ActionsManager.performAction(nil, nil, {
            aDice = { { type = 'd4' } },
            nMod = 0,
            sType = sTestRollType,
            sDesc = '',
            bSecret = false,
        });
        resolve()
    end):andThen(function (resolve)
        -- Detect resolution of async action
        ActionsManager.registerPostRollHandler(sTestRollType, function(_, rRoll)
            resolve(rRoll)
        end)
    end):andThen(function(resolve, rRoll)
        -- Clean up and test result
        ActionsManager.unregisterPostRollHandler(sTestRollType)
        local result = rRoll.aDice[1].value
        Assert.greaterThanOrEqualTo(1, result)
        Assert.lessThanOrEqualTo(4, result)
        resolve()
    end)
end
