# FG Test

Provides a way to run unit and behavioural tests in Fantasy Grounds. It has only been tested in Unity.

This extension is intended to be used by developers so that they can write automated tests for their  own extensions. There would be a test campaign and three extensions in play.

* The test campaign loads the extensions / rulesets. It contains any behavioural tests, written in the gherkin format.
* The fg-test extension provides a test harness to run your tests
* Your own extension is loaded as the "System Under Test" also known as SUT
* Your tests are loaded in a separate extension so that they don't become part of your distribution file

Let's go through it one step at a time by creating a simple extension that adds two numbers. Not a useful extension, but one we can use to go through the motions. This tutorial assumes that you're already familiar with the basics of creating extensions.

## Step 1: Preparation
Copy `fg-test.ext` into your extensions folder. Or clone the github repo into it.

Create a folder in the extensions folder for the new "add" extension. This will be our SUT (System Under Test). Create your `extension.xml` file:
```xml
<?xml version="1.0" encoding="iso-8859-1"?>
<root version="3.3" release="1">
  <properties>
    <name>Add Extension</name>
    <version>1</version>
    <author>Become famous - place your name here!</author>
    <description>Example SUT for the FG Test extension</description>
    <ruleset><name>CoreRPG</name></ruleset>
  </properties>
  <base>
      <script name="Add" file="add.lua" />
  </base>
</root>
```

Then create a stub for our `add.lua` script:

```lua
function onInit()
    Comm.registerSlashHandler("add", function(_, sParams)
        local aParams = StringManager.split(sParams, ' ', true)
        local nResult = add(tonumber(aParams[1]), tonumber(aParams[2]))
        Comm.addChatMessage({ text = tostring(result) })
    end)
end

function add(a, b)
end
```

Note that this doesn't do any input validation, and it doesn't yet add any numbers. For the demo we're not going to bother with input validation. The add method will be written as we go, following TDD practices.

## Step 2: Add a test
Create a folder in the extensions folder called `add_tests`. This will hold our actual tests. Create your `extension.xml` file:
```xml
<?xml version="1.0" encoding="iso-8859-1"?>
<root version="3.3" release="1">
  <properties>
    <name>Add Extension Tests</name>
    <version>1</version>
    <author>Become famous - place your name here!</author>
    <description>Example tests for the FG Test demo</description>
    <ruleset><name>CoreRPG</name></ruleset>
  </properties>
  <base>
      <script name="TestSuite" file="add_tests.lua" />
  </base>
</root>
```

Then create a stub for our `add_tests.lua` script:

```lua
function getTests()
    return {
        'testAdd',
    }
end

function testAdd()
    error("Write a test for our add function here")
end
```

## Step 3: Put it together and watch it fail
Now create a new campaign. 
* Make the campaign name "FG Test Demo"
* Select 'CoreRPG'
* From the extensions list, add:
  * `Vam's Fantasy Grounds Test Harness` to get the testing harness
  * `Add Extension`, your SUT
  * `Add Extension Tests`, your actual tests
* Click the start button

When it has loaded, type `/test` into the chat window to run the test suite. You should see the tests fail like so:

* testAdd (1): [string "add_tests.lua"]:8: Write a test for our add function here
* 0 / 1 unit tests passed

This is a good thing. It means that our test is getting called, but we need to write it.

## Step 4: Write our test
This may seem odd to anyone who isn't used to TDD. The idea is to write our tests first before we write our code. This forces us to think about how we would want to use the SUT before writing it. It also confirms that the functionality we're testing doesn't already exist if we're augmenting an existing function.

Open `add_tests.lua` and change `testAdd()` to contain a valid test of our code:
```lua
function testAdd()
    local EXPECTED_RESULT = 42
    local actual = Add.add(2, 40)
    Assert.equals(EXPECTED_RESULT, actual)
end
```

Reload Fantasy Grounds (if you've done any extension development, you've probably already mapped `/reload` to a hotkey) and rerun `/test`. It is probably a good idea to map that to a hotkey too. You should see a different error now:

* testAdd (1): [string "scripts/assert.lua"]:5: number is not a undefined

Good! This means that our test doesn't think the add function works. Which is correct.

## Step 5: Implement the SUT (System Under Test)
Finally, we get to add the feature! Open `add.lua` and fill in the `add()` function:
```lua
function add(a, b)
    return 42
end
```
Reload Fantasy Grounds with `/reload` and rerun your tests with `/test` and bask in the pure joy of a passing test!

* All unit tests passed (1 in total)

Now let's add some additional tests to ensure that we haven't missed any edge cases.

Alright, alright... Obviously this isn't a great add function for cases where the answer is not 42. One of the tenants of TDD is that your function should do the minimum possible in order to satisfy the tests. This helps us to make sure that we're not writing unneeded code, and that our tests are somewhat comprehensive. Let's fix this.

## Step 6: Add additional tests for edge cases
Sadly, I was not able to find a way to enumerate the functions in a script. They act like a Lua table, but they are not a Lua table. So until that feature is added (hint, hint) we need to provide a function that enumerates our tests. Update the `getTests()` function to include a new test:
```lua
function getTests()
    return {
        'testAdd',
        'testAddNegative',
    }
end
```
And the new test itself:
```lua
function testAddNegative()
    local EXPECTED_RESULT = 11
    local actual = Add.add(15, -4)
    Assert.equals(EXPECTED_RESULT, actual)
end
```
As you might have guessed, something is amiss with our `add()` function:
* testAddNegative (1): [string "scripts/assert.lua"]:8: 11 is not equal to 42

## Step 7: Fix our SUT
We'll go ahead and provide a real add function now.
```lua
function add(a, b)
    return a + b
end
```
Reload, re-test, and hopefully you scored a critical hit!
* All unit tests passed (2 in total)

## Step 8: Clean up our tests with a data provider
Adding a lot of tests to account for different inputs isn't fun, so the test harness looks for a data provider for each test. Data providers return a table of tables. The first table is a list of test inputs, and each test input is a list of parameters that will be passed to our test function.

Open `add_tests.lua` and replace `testAddNegative()` with `testAddProvider()`. Don't forget to remove `testAddNegative()` from the `getTests()` function.
```lua
function testAddProvider()
    local addTestData = {}
    addTestData['noraml'] = {42, 2, 40}
    addTestData['with a negative'] = {11, 15, -4}
    return addTestData
end
```
You could also have just returned a simple table of tables, but the key names help identify what went wrong when a test fails...
```lua
-- Example of what not to do (even though you can if you like)
function testAddProvider()
    return {
        {42, 2, 40},
        {11, 15, -4},
    }
end
```
Of course our test function has to be updated to use those parameters:
```lua
function testAdd(expected, a, b)
    local actual = Add.add(a, b)
    Assert.equals(expected, actual)
end
```
Do another reload and retest, and you should still see two passing tests.

# Behavioural Testing
Behavioural tests are designed to test larger amounts of code, and are a great way to write integration or vertical tests. For now, we'll just write a simple behavioural test to illustrate the point. I expect this part of FG Test to become more fleshed out in the coming months.

Here's what our test looks like:
```gherkin
Feature: Add items to my inventory

As an intrepid adventurer, I want to have more rations in my pack when I've purchased them.

Scenario: Rations purchased
Given I have 4 rations
When I purchase 10 more rations
Then I have 14 rations in my pack
```
It might look like magic, but what happens is that you need to write functions to execute behind each Given / When and Then. You can also write And or But for times when that reads better. You can use And or But to add as many things as you want to the Given and Then blocks, but it is considered bad form to have more than one When. Each scenario should have clear pre-conditions defined in the 'Given' section, a single action that causes the change under 'When', and then any number of tests under 'Then' for the expected post-condition.

Let's add the gherkin and code to our TDD tutorial to see how it works.

## Step 1: Add the feature
In the "FG Test Demo" campaign, open the Story dialog and add a story titled `Feature: Add items to my inventory`. In the body, put the text from the above example gherkin. You don't need to repeat the "Feature" line.

FG Test scans all the campaign stories and looks for those that start with "Feature:". Those get parsed as gherkins. The parser is very simple, so please avoid using any special formatting in the story for now.

## Step 2: Define the behaviour context
In your `add_tests` extension, add a context script to `extension.xml`:
```xml
        <script name="DemoContext" file="context.lua" />
```
Create `context.lua`, and set it up with an init function that registers it with FG Test.
```lua
function onInit()
    FGTest.registerBehaviouralContext(DemoContext)
end
```
The reason for the context registration is that we can create re-usable contexts with special features for things like rolling, the combat tracker, or different rulesets. Then we can register as many of them as we want for our specific gherkins.

Go ahead and give it another reload/retest cycle. You'll see failed behavioural tests because we haven't yet written the code that will run behind our Given / When / Thens.
* No context found with function: IHaveRations
* No context found with function: IPurchaseMoreRations
* No context found with function: IHaveRationsInMyPack

Take a look at these function names. Notice that:
* They don't include the Given / When / Then wording. This allows them to be re-used with different wording. Sometimes this will be using a When as a Given, or a Then as an And, etc.
* The specific parameters were stripped out. All numeric words or quoted text is stripped out and converted into a parameter that is passed to the test function. That way the same function can be used for any specific details like number of rations.

We can use these names to create the functions required to really run the gherkin:
```lua
local nRationsInMyInventory = 0

function IHaveRations(sCount)
    nRationsInMyInventory = tonumber(sCount)
end

function IPurchaseMoreRations(sCount)
    nRationsInMyInventory = Add.add(nRationsInMyInventory, tonumber(sCount))
end

function IHaveRationsInMyPack(sCount)
    Assert.equals(tonumber(sCount), nRationsInMyInventory)
end
```
Give it another reload/retest cycle and it should now show you behavioural tests passing. It counds all given / when / then lines as tests, so it will say that three tests passed for now.

## Step 3: Tinker
Change a number in the gherkin to invalidate the test, and run `/test` and it should fail. There's no nead to reload now because it re-parses the story as a gherkin for each run.

# That's all for now
This is just one weekend's work so far, including this readme / tutorial. I've also this weekend started a "promises" library which should make writing tests for async code such as dice rolls pretty straight forward if it goes to plan.

Other than that, I'd like to:
* Add more assertions to the assertion library
* Add some library contexts for things like the combat tracker, dice rolling, and the 5e ruleset
* I'd like to include library contexts for other rulesets, but I'll leave those up to developers who use those rulesets

I also expect to do a lot of bug fixing and further improvements just from using it to add automated tests to my own ChatBat extension.

I hope you find it helpful for your own extension or ruleset development. Let me know how it goes!
