local Categories = {}

-- Keep category data separate from GUI and network code.
function Categories.build()
    return {
        {
            id = "autofish",
            name = "AutoFish",
            items = { "Fry", "Baitfish", "Predator", "Schooling" },
        },
        {
            id = "freshwater",
            name = "Freshwater",
            items = { "Carp", "Perch", "Trout", "Catfish" },
        },
        {
            id = "saltwater",
            name = "Saltwater",
            items = { "Tuna", "Sardine", "Snapper", "Cod" },
        },
        {
            id = "rare-special",
            name = "Rare / Special",
            items = { "Sturgeon", "Mackerel", "Salmon", "Shark" },
        },
    }
end

return Categories
