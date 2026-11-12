local Config = require("config.kydufiConfig")
local GUI = require("gui.kydufiGui")
local Categories = require("kydufiFishCategory")
local Search = require("network.duckduckgo")

local app = {
    config = Config.load(),
    ui = GUI.new(),
    categories = Categories.build(),
}

function app:run(query)
    local searchQuery = query or self.config.defaultQuery
    local results = Search.search(searchQuery, self.config.userAgent)

    self.ui:render({
        title = "kydufi",
        query = searchQuery,
        categories = self.categories,
        results = results,
    })
end

app:run("fish")
return app
