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

function andThen(self, callable)
    table.insert(self._chain, callable)
    return self
end

function done(self, resolveCallback, rejectCallback, result)
    local f = self._chain[1]
    self._chain = { unpack(self._chain, 2) }
    if f then
        if type(f) == 'function' then
            local callableWrapper = function (r)
                result = r -- Capture the result in the closure so we can provide it in the final resolveCallback
                return self:done(resolveCallback, rejectCallback, result)
            end
            bSuccess, pcallResult = pcall(f, callableWrapper, result)
            if not bSuccess then
                if rejectCallback then
                    rejectCallback(pcallResult)
                else
                    error(pcallResult) -- If no reject callback is provided just error out
                end
            end
        else
            return self:done(resolveCallback, rejectCallback, f)
        end
    else
        resolveCallback(result)
    end
end
