_MTA_COMPAT = _MTA_COMPAT or {}

do
    local warned = {}

    function _MTA_COMPAT.warnOnce(subject, message)
        if warned[subject] then
            return
        end
        warned[subject] = true
        outputDebugString("[mta-compat] " .. subject .. ": " .. message, 2)
    end
end
