TYPE_PROMISE = 'vam_promise'

STATE_CREATED = 'vam_created'
STATE_RESOLVED = 'vam_resolved'
STATE_REJECTED = 'vam_rejected'

function promise(callable)
    return {
        _type = TYPE_PROMISE,
        _chain = { callable },
        andThen = andThen,
        done = done,
    }
end

function isPromise(candidate)
    return type(candidate) == 'table' and candidate._type and candidate._type == Promises.TYPE_PROMISE
end

function andThen(self, callable)
    table.insert(self._chain, callable)
    return self
end

function done(self, resolveCallback, rejectCallback, result)
    local callable = self._chain[1]
    self._chain = { unpack(self._chain, 2) }
    if callable then
        local resolveFunction
        local f = callable
        if isPromise(callable) then
            f = function ()
                callable:done(function(successResult)
                    result = successResult
                    return self:done(resolveCallback, rejectCallback, result)
                end, nil, result)
            end
        elseif type(callable) == 'function' then
            resolveFunction = function (r)
                result = r -- Capture the result in the closure so we can provide it in the final resolveCallback
                return self:done(resolveCallback, rejectCallback, result)
            end
        else
            return self:done(resolveCallback, rejectCallback, callable)
        end
        bSuccess, pcallResult = pcall(f, resolveFunction, result)
        if not bSuccess then
            if rejectCallback then
                rejectCallback(pcallResult)
            else
                error(pcallResult) -- If no reject callback is provided just error out
            end
        end
    else
        resolveCallback(result)
    end
end
