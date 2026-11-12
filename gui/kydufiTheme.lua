local Theme = {}

function Theme.header(text)
    return "=== " .. tostring(text or "kydufi") .. " ==="
end

function Theme.subheader(text)
    return "-- " .. tostring(text or "")
end

function Theme.section(text)
    return "\n[ " .. tostring(text or "") .. " ]"
end

function Theme.category(text)
    return "\n• " .. tostring(text or "")
end

function Theme.item(text)
    return "  - " .. tostring(text or "")
end

function Theme.muted(text)
    return "    " .. tostring(text or "")
end

function Theme.error(text)
    return "Chyba: " .. tostring(text or "")
end

return Theme
