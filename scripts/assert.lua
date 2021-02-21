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

function isTrue(bActual)
    return equals(bActual, true)
end

function isFalse(bActual)
    return equals(bActual, false)
end

function count(expectedCount, t)
    local actualCount = 0
    for _,_ in pairs(t) do
        actualCount = actualCount + 1
    end
    return equals(expectedCount, actualCount)
end