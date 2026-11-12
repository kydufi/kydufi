local Theme = require("gui.kydufiTheme")

local GUI = {}
GUI.__index = GUI

-- The renderer is kept replaceable: pass an adapter with :render(text, data)
-- to connect a real GUI framework without coupling it to app/data logic.
function GUI.new(adapter)
    return setmetatable({ adapter = adapter }, GUI)
end

function GUI:render(data)
    data = data or {}
    local lines = {
        Theme.header(data.title or "kydufi"),
        Theme.subheader("Query: " .. tostring(data.query or "")),
    }

    if data.error then
        lines[#lines + 1] = Theme.error(data.error)
    end

    lines[#lines + 1] = Theme.section("Categories")
    for _, category in ipairs(data.categories or {}) do
        lines[#lines + 1] = Theme.category(category.name or "Unnamed")
        for _, item in ipairs(category.items or {}) do
            lines[#lines + 1] = Theme.item(item)
        end
    end

    lines[#lines + 1] = Theme.section("DuckDuckGo results")
    for index, result in ipairs(data.results or {}) do
        lines[#lines + 1] = Theme.item(string.format("%d. %s", index, result.title or "Untitled"))
        if result.url then
            lines[#lines + 1] = Theme.muted(result.url)
        end
    end

    local output = table.concat(lines, "\n")
    if self.adapter and self.adapter.render then
        self.adapter:render(output, data)
    else
        -- Default renderer keeps this module runnable in plain Lua.
        print(output)
    end
    return output
end

return GUI
