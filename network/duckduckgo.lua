local Search = {}

function Search.search(query, userAgent)
    local q = query or "fish"
    local ua = userAgent or "kydufi/1.0 (+https://github.com/kydufi)"
    local url = "https://duckduckgo.com/html/?q=" .. q:gsub(" ", "+")

    local command = string.format('curl -A "%s" -L --silent "%s"', ua, url)
    local handle = assert(io.popen(command, "r"))
    local content = handle:read("*a")
    handle:close()

    local results = {}
    for href, title in string.gmatch(content, '<a rel="nofollow" class="result-link" href="(.-)">(.-)</a>') do
        table.insert(results, {
            title = title:gsub("<.->", ""),
            url = href,
        })
    end

    if #results == 0 then
        return {
            { title = "DuckDuckGo query: " .. q, url = url },
        }
    end

    return results
end

return Search
