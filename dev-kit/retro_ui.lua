
local RetroUI = {}
RetroUI.VERSION = "0.1.2-devkit"     -- 0.1.1 plus window:Resize (Dev Kit's drop log only; not in the Retro UI Kit yet)
RetroUI.P = 3                        -- one art pixel, in interface units

local P = RetroUI.P

RetroUI.COLOURS = {
    INK = 0x141010FF,
    WOOD = 0x7E3F22FF, WOOD_LIGHT = 0xA05A30FF, WOOD_DARK = 0x4F2412FF, WOOD_GRAIN = 0x6E361CFF,
    CHROME = 0xB9C4CCFF, CHROME_LIGHT = 0xF2F6F8FF, CHROME_DARK = 0x6F7C86FF,
    GOLD = 0xE8B23CFF, GOLD_LIGHT = 0xFFE08AFF, GOLD_DARK = 0x9C6B1EFF,
    TUBE = 0x2A140CFF, GLASS = 0x0E1A26FF, GLASS_LIGHT = 0x23384CFF, LCD = 0x10150EFF, CLOTH = 0x3A1414FF,
    CREAM = 0xFFF1C9FF, DARK = 0x2B1608FF, NUMBER = 0xF2C14EFF, FADED = 0x9FB3C8FF,
    GREEN = 0x5EE07AFF, RED = 0xFF6A5AFF, PARCHMENT = 0xFFF1C9FF, PARCHMENT_DARK = 0xE2CC96FF,
    BULBS = { 0xFF4D4DFF, 0xFFB03BFF, 0xFFE45CFF, 0x5EE07AFF, 0x45B5FFFF, 0xC77DFFFF },
}
local C = RetroUI.COLOURS

RetroUI.SPRITES = {
    BOTTLE = {
        "....kck....", "....kCk....", "...kkkkk...", "....kgk....", "....kgk....", "...kgggk...", "..kgggggk..",
        ".kgLLLLLgk.", "kLwlLLLLLLk", "kLwLLLLLLLk", "kLlLLLLLLdk", "kLLLLLLLLdk", "kLLLLLLLddk", ".kdddddddk.",
        "..kkkkkkk..",
    },
    SMALL_BOTTLE = { ".kck.", ".kgk.", "kgggk", "kLLLk", "kLwLk", "kLLdk", ".kkk." },
    STAR = { "..k..", ".kyk.", "kyyyk", ".kyk.", "k.k.k" },
    NOTE = { "..kkk", "..k.k", "..k..", "..k..", "kkk..", "kkk.." },
    COIN = { ".kkk.", "kyyyk", "kyYyk", "kyyyk", ".kkk." },
    HEART = { "kk.kk", "krkrk", "krrrk", ".krk.", "..k.." },
}

function RetroUI.Shade(hex, towards, amount)
    local alpha = hex % 256
    local value = math.floor(hex / 256)
    local blue = value % 256
    value = math.floor(value / 256)
    local green = value % 256
    local red = math.floor(value / 256)
    local function mix(v)
        return math.floor(v + (towards - v) * amount + 0.5)
    end
    return ((mix(red) * 256 + mix(green)) * 256 + mix(blue)) * 256 + alpha
end

function RetroUI.BottlePalette(liquid)
    return { k = C.INK, c = C.WOOD_LIGHT, C = C.WOOD, g = 0xCFE3EAFF, L = liquid,
             l = RetroUI.Shade(liquid, 255, 0.45), d = RetroUI.Shade(liquid, 0, 0.45), w = 0xFFFFFFFF }
end

local function rgba(hex)
    local alpha = hex % 256
    hex = math.floor(hex / 256)
    local blue = hex % 256
    hex = math.floor(hex / 256)
    local green = hex % 256
    local red = math.floor(hex / 256)
    return Vector4.new(red / 255, green / 255, blue / 255, alpha / 255)
end

local function font(name)
    local ok, result = pcall(function()
        local candidate = id.Font[name]
        local description = config.Font.FromID(candidate)
        if description and description:GetStringWidth("Retro") > 0 then
            return candidate
        end
    end)
    if ok and result then
        return result
    end
    return id.Font.MUSEO_SANS_15PT_REGULAR
end

local function clean(value)
    local text = tostring(value or "")
    text = text:gsub("<[^>]*>", "")
    text = text:gsub("%c", " ")
    return text
end


function RetroUI.Painter(canvas)
    local paint = { canvas = canvas }
    local fonts = { normal = font("P12_FULL"), bold = font("B12_FULL") }
    local widths = {}

    local function measure(text, selected)
        if widths[selected] == nil then
            local ok, info = pcall(function() return config.Font.FromID(selected) end)
            widths[selected] = ok and info or false
        end
        local info = widths[selected]
        local ok, width = pcall(function() return info:GetStringWidth(text) end)
        return ok and width or #text * 7
    end

    function paint:Clear()
        canvas:Clear()
    end

    function paint:Measure(text, bold)
        return measure(clean(text), bold and fonts.bold or fonts.normal)
    end

    function paint:Rect(x, y, width, height, colour)
        if width > 0 and height > 0 then
            canvas:AddRectangle(math.floor(x), math.floor(y), math.floor(width), math.floor(height), colour)
        end
    end

    function paint:Block(x, y, width, height, face, light, dark)
        self:Rect(x, y, width, height, C.INK)
        self:Rect(x + P, y + P, width - 2 * P, height - 2 * P, face)
        if light then
            self:Rect(x + P, y + P, width - 2 * P, P, light)
            self:Rect(x + P, y + P, P, height - 2 * P, light)
        end
        if dark then
            self:Rect(x + P, y + height - 2 * P, width - 2 * P, P, dark)
            self:Rect(x + width - 2 * P, y + P, P, height - 2 * P, dark)
        end
    end

    function paint:Chrome(x, y, width, height)
        self:Block(x, y, width, height, C.CHROME, C.CHROME_LIGHT, C.CHROME_DARK)
    end

    function paint:Gold(x, y, width, height)
        self:Block(x, y, width, height, C.GOLD, C.GOLD_LIGHT, C.GOLD_DARK)
    end

    function paint:Glass(x, y, width, height)
        self:Block(x, y, width, height, C.GLASS, C.GLASS_LIGHT)
    end

    function paint:LCD(x, y, width, height)
        self:Block(x, y, width, height, C.LCD)
    end

    function paint:Card(x, y, width, height)
        self:Block(x, y, width, height, C.PARCHMENT, 0xFFFFFFFF, C.PARCHMENT_DARK)
    end

    function paint:Text(x, y, width, height, value, colour, options)
        options = options or {}
        local selected = options.bold and fonts.bold or fonts.normal
        local content = clean(value)
        if measure(content, selected) > width then
            while #content > 0 and measure(content .. "...", selected) > width do
                content = content:sub(1, -2)
            end
            content = content .. "..."
        end
        local style = ui.TextDataConfig.new()
        style.font = selected
        style.colour = rgba(colour or C.CREAM)
        style.alignHorizontal = options.align == "centre" and ui.AlignMode.CENTRE
            or options.align == "right" and (ui.AlignMode.BOTTOMRIGHT or ui.AlignMode.TOPLEFT)
            or ui.AlignMode.TOPLEFT
        style.alignVertical = ui.AlignMode.CENTRE
        canvas:AddText(math.floor(x), math.floor(y), math.floor(width), math.floor(height), content, style)
    end

    function paint:Button(x, y, width, height, label, on, pressed)
        local face = on and C.GOLD or C.CHROME
        local light = on and C.GOLD_LIGHT or C.CHROME_LIGHT
        local dark = on and C.GOLD_DARK or C.CHROME_DARK
        if pressed then
            self:Block(x, y, width, height, dark)
        else
            self:Block(x, y, width, height, face, light, dark)
        end
        if label and label ~= "" then
            local shift = pressed and P or 0
            self:Text(x + 3 + shift, y + shift, width - 6, height, label, C.DARK, { align = "centre" })
        end
    end

    function paint:Arrow(cx, cy, dir, colour, step)
        local unit = step or P
        for i = 0, 3 do
            local size = ((dir == "down" or dir == "right") and (2 * (3 - i) + 1) or (2 * i + 1)) * unit
            local half = math.floor(size / 2)
            if dir == "up" or dir == "down" then
                self:Rect(cx - half, cy - 2 * unit + i * unit, size, unit, colour or C.INK)
            else
                self:Rect(cx - 2 * unit + i * unit, cy - half, unit, size, colour or C.INK)
            end
        end
    end

    function paint:Sprite(x, y, rows, palette, size)
        local s = size or P
        for j, row in ipairs(rows) do
            for i = 1, #row do
                local colour = palette[row:sub(i, i)]
                if colour then
                    self:Rect(x + (i - 1) * s, y + (j - 1) * s, s, s, colour)
                end
            end
        end
    end

    function paint:Magnifier(x, y)
        self:Rect(x + P, y, 3 * P, P, C.INK)
        self:Rect(x + P, y + 4 * P, 3 * P, P, C.INK)
        self:Rect(x, y + P, P, 3 * P, C.INK)
        self:Rect(x + 4 * P, y + P, P, 3 * P, C.INK)
        self:Rect(x + 4 * P, y + 4 * P, P, P, C.INK)
        self:Rect(x + 5 * P, y + 5 * P, P, P, C.INK)
    end

    function paint:Nameplate(cx, y, width, title)
        self:Gold(cx - math.floor(width / 2), y, width, 36)
        self:Text(cx - math.floor(width / 2), y, width, 36, title, C.DARK, { bold = true, align = "centre" })
    end

    function paint:Row(x, y, width, height, name, number, lit)
        if lit then
            self:Rect(x, y, width, height, C.GOLD)
        end
        local numberWidth = number and 48 or 0
        self:Text(x + 6, y, width - 12 - numberWidth, height, name, lit and C.DARK or C.CREAM)
        if number then
            self:Text(x + width - 6 - numberWidth, y, numberWidth, height, tostring(number), lit and C.DARK or C.NUMBER,
                      { align = "right" })
        end
    end

    function paint:Cabinet(width, height, crown)
        crown = crown or 84
        local base = height - 36
        local cx = math.floor(width / 2)
        local function half(y, inset)
            return RetroUI.CrownHalf(width, crown, y, inset)
        end
        local rings = { { 0, C.INK }, { P, C.CHROME_DARK }, { 2 * P, C.CHROME }, { 4 * P, C.INK }, { 5 * P, C.TUBE },
                        { 8 * P, C.INK }, { 9 * P, C.WOOD } }
        for y = 0, crown - 1, P do
            for _, ring in ipairs(rings) do
                local h = half(y + P, ring[1])
                self:Rect(cx - h, y, h * 2, P, ring[2])
            end
        end
        for _, ring in ipairs(rings) do
            local inset = ring[1]
            self:Rect(inset, crown, width - 2 * inset, base - inset - crown, ring[2])
        end
        self:Rect(2 * P, crown, P, base - 4 * P - crown, C.CHROME_LIGHT)
        self:Rect(9 * P, crown, P, base - 10 * P - crown, C.WOOD_LIGHT)
        self:Rect(width - 10 * P, crown, P, base - 10 * P - crown, C.WOOD_DARK)
        for x = 9 * P + 18, width - 9 * P - 18, 27 do
            self:Rect(x, crown + 6, P, base - 10 * P - crown - 12, C.WOOD_GRAIN)
        end
        self:Block(6, base, width - 12, 24, C.WOOD_DARK, C.WOOD, C.INK)
        self:Chrome(21, height - 15, 39, 15)
        self:Chrome(width - 60, height - 15, 39, 15)
    end

    function paint:Bulbs(spots, phase)
        for i, spot in ipairs(spots) do
            self:Rect(spot[1], spot[2], 2 * P, 2 * P, C.BULBS[(i + (phase or 0)) % #C.BULBS + 1])
            self:Rect(spot[1], spot[2], P, P, 0xFFFFFFB0)
        end
    end

    return paint
end

function RetroUI.BulbSpots(width, height, crown)
    crown = crown or 84
    local base = height - 36
    local cx = math.floor(width / 2)
    local spots = {}
    local a, b = cx - 19, crown - 19
    local count = math.max(12, math.floor(width / 15))
    for i = 0, count do
        local angle = math.pi * i / count
        spots[#spots + 1] = { math.floor((cx - a * math.cos(angle) - 3) / P) * P,
                              math.floor((crown - b * math.sin(angle) - 3) / P) * P }
    end
    for y = crown + 9, base - 33, 12 do
        table.insert(spots, 1, { 15, y })
        spots[#spots + 1] = { width - 21, y }
    end
    return spots
end

function RetroUI.CrownHalf(width, crown, y, inset)
    local a, b = math.floor(width / 2) - inset, crown - inset
    local dy = crown - y
    if b <= 0 or dy > b then
        return 0
    end
    return math.floor(a * math.sqrt(1 - (dy / b) ^ 2) / P) * P
end


local windowCount = 0                -- gives each window its own menu-event name

local function mouse()
    local okX, x = pcall(Mouse.GetX)
    local okY, y = pcall(Mouse.GetY)
    if okX and okY and type(x) == "number" and type(y) == "number" then
        return x, y
    end
end

function RetroUI.Window(parent, options)
    options = options or {}
    local width = math.floor(options.width or 384)
    local height = math.floor(options.height or 300)
    local crown = math.floor(options.crown or 84)
    local window = { width = width, height = height, crown = crown, areas = {}, spots = {} }
    local pos = { x = math.floor(options.x or 0), y = math.floor(options.y or 0) }

    local layer = ui.Layer.new(parent)
    layer:SetPos(pos.x, pos.y)
    layer:SetSize(width, height)
    layer.clickthrough = false
    window.layer = layer

    local function catcher(container, x, y, w, h)
        local area = ui.Rectangle.new(container)
        area:SetPos(math.floor(x), math.floor(y))
        area:SetSize(math.floor(w), math.floor(h))
        area.fill = true
        area.colour = Vector4.new(0, 0, 0, 0.004)
        area.clickthrough = false
        area:Subscribe(ui.Hook.ONSCROLLWHEEL, function() return false end)
        return area
    end
    local back = catcher(layer, 0, 0, width, height)
    back:Subscribe(ui.Hook.ONCLICK, function() return false end)

    local function canvas(container, w, h)
        local c = ui.Canvas.new(container)
        c:SetSize(w, h)
        c.clickthrough = true
        return c
    end
    window.art = RetroUI.Painter(canvas(layer, width, height))
    local lights = RetroUI.Painter(canvas(layer, width, height))

    local top = math.max(crown, 33)
    if crown > 0 and options.title then
        local plateWidth = math.max(120, math.min(204, width - 96, window.art:Measure(options.title, true) + 48))
        local plateY = 30
        while plateY < crown and 2 * RetroUI.CrownHalf(width, crown, plateY, 9 * P) - 24 < plateWidth do
            plateY = plateY + P
        end
        window.plate = { x = math.floor((width - plateWidth) / 2), y = plateY, width = plateWidth }
        top = math.max(top, plateY + 36 + 6)
    end
    window.inner = { x = 30, y = top, width = width - 60, height = height - 36 - 27 - top }
    local spots = (options.lights ~= false and crown > 0) and RetroUI.BulbSpots(width, height, crown) or {}
    local phase, ticks = 0, 0

    local drag, handle = nil, nil
    local function endDrag()
        if not drag then
            return
        end
        drag = nil
        if options.onMove then
            pcall(options.onMove, pos.x, pos.y)
        end
    end
    if options.draggable ~= false then
        handle = catcher(layer, 0, 0, width, math.max(24, top - 3))
        handle:Subscribe(ui.Hook.ONCLICK, function()
            local mx, my = mouse()
            if mx then
                drag = { mx, my, pos.x, pos.y, 0 }
            end
            return false
        end)
        handle:Subscribe(ui.Hook.ONRELEASE, function()
            endDrag()
            return false
        end)
    end
    local function followDrag()
        if not drag then
            return
        end
        local mx, my = mouse()
        if not mx then
            return
        end
        local okW, parentWidth = pcall(function() return parent.width end)
        local okH, parentHeight = pcall(function() return parent.height end)
        parentWidth = okW and type(parentWidth) == "number" and parentWidth or 4000
        parentHeight = okH and type(parentHeight) == "number" and parentHeight or 4000
        pos.x = math.floor(math.max(60 - width, math.min(parentWidth - 60, drag[3] + mx - drag[1])))
        pos.y = math.floor(math.max(0, math.min(parentHeight - 40, drag[4] + my - drag[2])))
        layer:SetPos(pos.x, pos.y)
        local okOver, over = pcall(function() return handle.isMouseOver end)
        if okOver and over == false then
            drag[5] = drag[5] + 1
            if drag[5] > 15 then
                endDrag()
            end
        else
            drag[5] = 0
        end
    end

    function window:Area(x, y, w, h, onClick, onWheel)
        local area = ui.Rectangle.new(layer)
        area:SetPos(math.floor(x), math.floor(y))
        area:SetSize(math.floor(w), math.floor(h))
        area.fill = true
        area.colour = Vector4.new(0, 0, 0, 0.004)
        area.clickthrough = false
        area:Subscribe(ui.Hook.ONCLICK, function()
            if not area.hidden and onClick then
                onClick()
            end
            return false
        end)
        area:Subscribe(ui.Hook.ONSCROLLWHEEL, function(_, delta)
            if onWheel then
                onWheel(delta)
            end
            return false
        end)
        self.areas[#self.areas + 1] = area
        self.spots[#self.spots + 1] = { math.floor(x), math.floor(y), math.floor(w), math.floor(h), area }
        return area
    end

    function window:Field(x, y, w, value, onChange)
        local input = ui.InputField.new(layer)
        input:SetPos(math.floor(x), math.floor(y))
        input:SetSize(math.floor(w), 25)
        input.stylesheetID = id.StyleSheet.INPUT_DEFAULT
        input.content = value or ""
        input.clickthrough = false
        if onChange then
            input:Subscribe(ui.Hook.ONCONTENTCHANGED, function(_, reason, contents)
                onChange(tostring(contents or ""), reason)
            end)
        end
        input:Subscribe(ui.Hook.ONSCROLLWHEEL, function() return false end)
        return input
    end

    local hideSpot = crown > 0 and { width - 75, height - 33, 60, 18 } or { width - 66, 6, 60, 18 }
    local reopen, tabWidth, tabHandle = nil, 0, nil
    local tabAt, tabDrag = { x = 0, y = 0 }, nil
    local function placeTab(x, y)
        local okW, parentWidth = pcall(function() return parent.width end)
        local okH, parentHeight = pcall(function() return parent.height end)
        parentWidth = okW and type(parentWidth) == "number" and parentWidth or 4000
        parentHeight = okH and type(parentHeight) == "number" and parentHeight or 4000
        tabAt.x = math.floor(math.max(0, math.min(parentWidth - tabWidth, x)))
        tabAt.y = math.floor(math.max(0, math.min(parentHeight - 30, y)))
        reopen:SetPos(tabAt.x, tabAt.y)
    end
    local function endTabDrag(clicked)
        local press = tabDrag
        if not press then
            return
        end
        tabDrag = nil
        if press.moved then
            if options.onMove then
                pcall(options.onMove, pos.x, pos.y)
            end
        elseif clicked then
            window:Show()
        end
    end
    local hideArea, hideEntry = nil, nil
    if options.hideButton ~= false then
        hideArea = window:Area(hideSpot[1], hideSpot[2], hideSpot[3], hideSpot[4], function() window:Hide() end)
        hideEntry = window.spots[#window.spots]
        tabWidth = math.max(90, math.min(204, window.art:Measure(options.title or "OPEN", true) + 36))
        reopen = ui.Layer.new(parent)
        reopen:SetSize(tabWidth, 30)
        reopen.hidden = true
        reopen.clickthrough = false
        local tab = RetroUI.Painter(canvas(reopen, tabWidth, 30))
        tab:Gold(0, 0, tabWidth, 30)
        tab:Text(0, 0, tabWidth, 30, options.title or "OPEN", C.DARK, { bold = true, align = "centre" })
        tabHandle = catcher(reopen, 0, 0, tabWidth, 30)
        tabHandle:Subscribe(ui.Hook.ONCLICK, function()
            local mx, my = mouse()
            if mx then
                tabDrag = { mx = mx, my = my, x = tabAt.x, y = tabAt.y, off = 0, held = 0, moved = false }
            else
                window:Show()
            end
            return false
        end)
        tabHandle:Subscribe(ui.Hook.ONRELEASE, function()
            endTabDrag(true)
            return false
        end)
    end
    local function followTabDrag()
        local press = tabDrag
        if not press then
            return
        end
        local mx, my = mouse()
        if not mx then
            return
        end
        local dx, dy = mx - press.mx, my - press.my
        if not press.moved and math.abs(dx) + math.abs(dy) >= 3 then
            press.moved = true
        end
        if press.moved then
            placeTab(press.x + dx, press.y + dy)
            pos.x, pos.y = tabAt.x - math.floor((width - tabWidth) / 2), tabAt.y
            layer:SetPos(pos.x, pos.y)
        end
        local okOver, over = pcall(function() return tabHandle.isMouseOver end)
        if okOver and over == false then
            press.off = press.off + 1
            if press.off > 15 then
                endTabDrag(false)
                return
            end
        else
            press.off = 0
        end
        press.held = press.held + 1
        if not press.moved and press.held > 25 then
            endTabDrag(true)
        end
    end

    local function relative(component, fallbackX, fallbackY)
        local mx, my = mouse()
        if not mx then
            return nil
        end
        local okXY, origin = pcall(function() return component.xyGlobal end)
        local ox = okXY and type(origin) ~= "nil" and origin.x or fallbackX
        local oy = okXY and type(origin) ~= "nil" and origin.y or fallbackY
        return mx - ox, my - oy
    end
    local function overWindow()
        if layer.hidden then
            return nil
        end
        local x, y = relative(layer, pos.x, pos.y)
        if not x or x < 0 or y < 0 or x >= width or y >= height then
            return nil
        end
        if crown > 0 and y < crown and math.abs(x - math.floor(width / 2)) > RetroUI.CrownHalf(width, crown, math.min(crown, y + P), 0) then
            return nil
        end
        return x, y
    end
    local function overTab()
        if not reopen or reopen.hidden then
            return false
        end
        local x, y = relative(reopen, pos.x + math.floor((width - tabWidth) / 2), pos.y)
        return x ~= nil and x >= 0 and y >= 0 and x < tabWidth and y < 30
    end
    local menuLabel = options.title or "Window"
    local function entryText(entry)
        local okOverride, override = pcall(function() return entry.overrideText end)
        if okOverride and override and override ~= "" then
            return override
        end
        local okFull, full = pcall(function() return entry.fullText end)
        return okFull and full or ""
    end
    local function guardMenu(event)
        local x, y = overWindow()
        local onTab = x == nil and overTab()
        if x == nil and not onTab then
            return
        end
        local menu = event.miniMenu
        local count, cancel = menu.entryCount, nil
        for i = 1, count do
            if menu.entries[i].actionType == MiniMenuActionType.CANCEL then
                cancel = i
            end
        end
        local leftClickIsLast = cancel ~= count
        local overArea = onTab
        if x then
            if handle and y < math.max(24, top - 3) then
                overArea = true
            end
            for _, spot in ipairs(window.spots) do
                if not spot[5].hidden and x >= spot[1] and y >= spot[2] and x < spot[1] + spot[3] and y < spot[2] + spot[4] then
                    overArea = true
                end
            end
        end
        if not overArea then
            local leftClick = leftClickIsLast and count or 1
            if cancel and cancel ~= leftClick then
                menu:Swap(cancel, leftClick)
            end
            return
        end
        menu:Add(menuLabel, function() end)
        local total, entries, ours = menu.entryCount, menu.entries, nil
        for i = 1, total do
            if entries[i].actionEntryType == MiniMenuEntryType.PLUGIN and entryText(entries[i]) == menuLabel then
                ours = i
            end
        end
        local leftClick = leftClickIsLast and total or 1
        if ours and ours ~= leftClick then
            menu:Swap(ours, leftClick)
        end
    end
    windowCount = windowCount + 1
    local menuKey = "retroUIWindowMenu" .. windowCount
    if options.guardMenu ~= false then
        local lastProblem = nil
        pcall(function()
            Event.MiniMenuReady.Subscribe(menuKey, function(event)
                local ok, problem = pcall(guardMenu, event)
                if not ok and problem ~= lastProblem then
                    log("Retro UI window menu: " .. tostring(problem))
                end
                lastProblem = not ok and problem or nil
            end)
        end)
    end

    function window:Hide()
        drag = nil
        layer.hidden = true
        if reopen then
            placeTab(pos.x + math.floor((width - tabWidth) / 2), pos.y)
            reopen.hidden = false
            pcall(function() reopen:MoveToFront() end)
        end
        if options.onHide then
            pcall(options.onHide, true)
        end
    end

    function window:Show()
        tabDrag = nil
        layer.hidden = false
        if reopen then
            reopen.hidden = true
        end
        if options.onHide then
            pcall(options.onHide, false)
        end
    end

    function window:IsHidden()
        return layer.hidden == true
    end

    local function drawLights()
        lights:Clear()
        lights:Bulbs(spots, phase)
    end

    function window:Redraw(drawContent)
        self.art:Clear()
        if crown > 0 then
            self.art:Cabinet(width, height, crown)
            if self.plate then
                self.art:Nameplate(math.floor(width / 2), self.plate.y, self.plate.width, options.title)
            end
        else
            self.art:Block(0, 0, width, height, C.WOOD, C.WOOD_LIGHT, C.WOOD_DARK)
        end
        if options.hideButton ~= false then
            self.art:Button(hideSpot[1], hideSpot[2], hideSpot[3], hideSpot[4], "HIDE", false)
        end
        if drawContent then
            drawContent(self.art, self)
        end
        drawLights()
    end

    function window:Animate()
        followDrag()
        followTabDrag()
        if layer.hidden or #spots == 0 then
            return
        end
        ticks = ticks + 1
        if ticks % 12 == 0 then
            phase = phase + 1
            drawLights()
        end
    end

    function window:SetPos(x, y)
        pos.x, pos.y = math.floor(x), math.floor(y)
        layer:SetPos(pos.x, pos.y)
    end

    local made = { width = width, height = height }
    function window:Resize(newWidth, newHeight)
        width = math.max(made.width, math.floor(newWidth))
        height = math.max(made.height, math.floor(newHeight))
        self.width, self.height = width, height
        layer:SetSize(width, height)
        back:SetSize(width, height)
        self.art.canvas:SetSize(width, height)
        lights.canvas:SetSize(width, height)
        if handle then handle:SetSize(width, math.max(24, top - 3)) end
        if self.plate then
            local plateY = 30
            while plateY < crown and 2 * RetroUI.CrownHalf(width, crown, plateY, 9 * P) - 24 < self.plate.width do
                plateY = plateY + P
            end
            self.plate.x, self.plate.y = math.floor((width - self.plate.width) / 2), plateY
        end
        self.inner.width, self.inner.height = width - 60, height - 36 - 27 - top
        spots = (options.lights ~= false and crown > 0) and RetroUI.BulbSpots(width, height, crown) or {}
        hideSpot[1], hideSpot[2] = crown > 0 and width - 75 or width - 66, crown > 0 and height - 33 or 6
        if hideArea then
            hideArea:SetPos(hideSpot[1], hideSpot[2])
            hideEntry[1], hideEntry[2] = hideSpot[1], hideSpot[2]
        end
    end

    function window:GetPos()
        return pos.x, pos.y
    end

    function window:SetHidden(hidden)
        if hidden then
            self:Hide()
        else
            self:Show()
        end
    end

    function window:Destroy()
        pcall(function() Event.MiniMenuReady.Unsubscribe(menuKey) end)
        layer.hidden = true
        pcall(function() layer:Destroy() end)
        if reopen then
            reopen.hidden = true
            pcall(function() reopen:Destroy() end)
        end
    end

    window:Redraw(nil)
    return window
end

return RetroUI
