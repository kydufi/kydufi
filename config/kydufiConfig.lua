local Config = {}

function Config.load()
    return {
        defaultQuery = "fish",
        userAgent = "kydufi/1.0 (+https://github.com/kydufi)",
        duckDuckGoBase = "https://duckduckgo.com/html/?q=",
        enableAuth = false,
        note = "This is a public search client; no direct login is performed.",
    }
end

return Config
