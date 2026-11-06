-- Paměť oken: poslední poloha a velikost podle aplikace a počátečního titulku, uložená v souboru, takže přežije restart.
-- Uplatňuje se pravidlem už při vzniku okna, aby nepřeskakovalo. Počáteční titulek odděluje dialogy od hlavního okna.
local memory = {}

local config = require("config")

local is_floating_on_desk = require("geometry").is_floating_on_desk

-- Běhový stav, proto mimo konfiguraci a git. Jeden řádek na okno, hodnoty oddělené tabulátorem.
local path = config.state_dir .. "/window-geometry.tsv"
local line_pattern = "^([^\t]*)\t([^\t]*)\t([^\t]*)\t(-?%d+)\t(-?%d+)\t(%d+)\t(%d+)$"
local excluded_classes = { [config.classes.toolbox] = true }
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

local function load_entries()
    local file = io.open(path, "r")
    if not file then return {} end

    local loaded = {}
    for line in file:lines() do
        local class, title, monitor, x, y, w, h = line:match(line_pattern)
        if class then
            loaded[class .. "\n" .. title] = {
                class = class,
                title = title,
                monitor = monitor,
                x = tonumber(x),
                y = tonumber(y),
                w = tonumber(w),
                h = tonumber(h),
            }
        end
    end
    file:close()
    return loaded
end

-- Zápis přes dočasný soubor, aby výpadek uprostřed nepoškodil uložená data
local function save_entries()
    local temporary = path .. ".tmp"
    local file = io.open(temporary, "w")
    if not file then return end

    for _, e in pairs(entries) do
        -- Titulek s tabulátorem nebo novým řádkem by rozbil formát; takové okno se prostě neuloží
        if not e.title:find("[\t\n]") then
            file:write(table.concat({ e.class, e.title, e.monitor, e.x, e.y, e.w, e.h }, "\t"), "\n")
        end
    end
    file:close()
    os.rename(temporary, path)
end

-- Novější pravidlo přebíjí starší, to staré se proto vypne
local function apply_rule(key, e)
    if rules[key] then rules[key]:set_enabled(false) end

    local match = { class = config.exact_match(e.class) }
    if e.title ~= "" then match.initial_title = config.exact_match(e.title) end

    rules[key] = hl.window_rule({
        match = match,
        monitor = e.monitor,
        size = e.w .. " " .. e.h,
        move = e.x .. " " .. e.y,
    })
end

local function geometry_of(win)
    local mon = win.monitor
    if not is_floating_on_desk(win) or not win.mapped then return nil end
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

-- Přepočítá uložené polohy na monitoru; fit dostává a vrací { x, y, w, h } relativně k monitoru
function memory.refit(monitor, fit)
    local changed = false
    for key, e in pairs(entries) do
        if e.monitor == monitor then
            local rect = fit(e)
            changed = remember(key, {
                class = e.class,
                title = e.title,
                monitor = e.monitor,
                -- Monitor hlásí polohu jako desetinné číslo, formát souboru bere jen celá
                x = math.floor(rect.x),
                y = math.floor(rect.y),
                w = math.floor(rect.w),
                h = math.floor(rect.h),
            }) or changed
        end
    end
    if changed then save_entries() end
end

function memory.has(win)
    return entries[key_of(win)] ~= nil
end

-- Volá se až po ostatních pravidlech oken, aby je zapamatované hodnoty přebily
function memory.start()
    os.execute("mkdir -p '" .. config.state_dir .. "'")
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
