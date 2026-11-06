-- Paměť oken: poslední poloha a velikost podle aplikace a počátečního titulku, uložená v souboru, takže přežije restart.
-- Uplatňuje se pravidlem už při vzniku okna, aby nepřeskakovalo. Počáteční titulek odděluje dialogy od hlavního okna.
local memory = {}

local path = os.getenv("HOME") .. "/.config/desk/window-geometry.lua"
local excluded_classes = { ["jetbrains-toolbox"] = true }
local excluded_titles = { splash = true }
local min_size = 100
local check_interval_ms = 1000

local entries = {}
local rules = {}
local candidates = {}

-- Aplikace, jejichž první titulek se mění podle obsahu, se poznají jen podle třídy
local class_only = { ferdium = true }

local function title_of(win)
    return class_only[win.class] and "" or win.initial_title
end

local function key_of(win)
    return win.class .. "\n" .. title_of(win)
end

local function regex_escape(text)
    return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?{}|\\]", "\\%0"))
end

local function load_entries()
    local chunk = loadfile(path)
    local ok, saved = pcall(chunk or error)
    return ok and type(saved) == "table" and saved or {}
end

-- Zápis přes dočasný soubor, aby výpadek uprostřed nepoškodil uložená data
local function save_entries()
    local temporary = path .. ".tmp"
    local file = io.open(temporary, "w")
    if not file then return end

    file:write("return {\n")
    for key, e in pairs(entries) do
        file:write(string.format("  [%q] = { class = %q, title = %q, monitor = %q, x = %d, y = %d, w = %d, h = %d },\n",
            key, e.class, e.title, e.monitor, e.x, e.y, e.w, e.h))
    end
    file:write("}\n")
    file:close()
    os.rename(temporary, path)
end

-- Novější pravidlo přebíjí starší, to staré se proto vypne
local function apply_rule(key, e)
    if rules[key] then rules[key]:set_enabled(false) end

    local match = { class = "^" .. regex_escape(e.class) .. "$" }
    if e.title ~= "" then match.initial_title = "^" .. regex_escape(e.title) .. "$" end

    rules[key] = hl.window_rule({
        match = match,
        monitor = e.monitor,
        size = e.w .. " " .. e.h,
        move = e.x .. " " .. e.y,
    })
end

local function geometry_of(win)
    local mon = win.monitor
    local on_special = win.workspace and win.workspace.name:find("special", 1, true)
    local fullscreen = win.fullscreen and win.fullscreen ~= 0
    if not mon or on_special or fullscreen or win.hidden or not win.mapped or not win.floating then return nil end
    if excluded_classes[win.class] or excluded_titles[win.title] or win.class == "" then return nil end
    if win.size.x < min_size or win.size.y < min_size then return nil end

    return {
        class = win.class,
        title = title_of(win),
        monitor = mon.name,
        x = win.at.x - mon.x,
        y = win.at.y - mon.y,
        w = win.size.x,
        h = win.size.y,
    }
end

local function same(a, b)
    return a and b and a.monitor == b.monitor and a.x == b.x and a.y == b.y and a.w == b.w and a.h == b.h
end

local function remember(key, geometry)
    if same(entries[key], geometry) then return false end
    entries[key] = geometry
    apply_rule(key, geometry)
    return true
end

-- Ukládá se až poloha stabilní mezi dvěma kontrolami, ne každý krok tažení.
-- Když má aplikace víc oken se stejným klíčem, platí to aktivní.
local function check_windows()
    local active = hl.get_active_window()
    local counts = {}
    for _, win in ipairs(hl.get_windows()) do
        local key = key_of(win)
        counts[key] = (counts[key] or 0) + 1
    end

    local changed = false
    for _, win in ipairs(hl.get_windows()) do
        local key = key_of(win)
        local geometry = geometry_of(win)
        local allowed = counts[key] == 1 or (active and active.address == win.address)
        if geometry and allowed then
            if same(candidates[key], geometry) then
                changed = remember(key, geometry) or changed
            end
            candidates[key] = geometry
        end
    end

    if changed then save_entries() end
end

function memory.has(win)
    return entries[key_of(win)] ~= nil
end

-- Volá se až po ostatních pravidlech oken, aby je zapamatované hodnoty přebily
function memory.start()
    entries = load_entries()
    for key, e in pairs(entries) do
        apply_rule(key, e)
    end

    -- Okno zavřené krátce po přesunu by jinak o poslední polohu přišlo
    hl.on("window.close", function(win)
        local geometry = geometry_of(win)
        if geometry and remember(key_of(win), geometry) then save_entries() end
    end)

    window_memory_timer = hl.timer(check_windows, { timeout = check_interval_ms, type = "repeat" })
end

return memory
