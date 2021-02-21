function equals(expected, actual)
    local sExpectedType = type(expected)
    local sActualType = type(actual)
    if sExpectedType ~= sActualType then
        error(sExpectedType .. " is not a " .. sActualType)
    end
    if expected ~= actual then
        error(tostring(expected) .. " is not equal to " .. tostring(actual))
    end
end

function greaterThanOrEqualTo(expected, actual)
    if actual < expected then
        error(tostring(actual) .. " is not greater than or equal to " .. tostring(expected))
    end
end

function lessThanOrEqualTo(expected, actual)
    if actual > expected then
        error(tostring(actual) .. " is not less than or equal to " .. tostring(expected))
    end
end

function isTrue(bActual)
    return equals(bActual, true)
end

function isFalse(bActual)
    return equals(bActual, false)
end

function isNil(bActual)
    return equals(bActual, nil)
end

function count(expectedCount, t)
    local actualCount = 0
    for _,_ in pairs(t) do
        actualCount = actualCount + 1
    end
    return equals(expectedCount, actualCount)
end