
local config = {
    image_identifier = "pixel_logo",
    image_address = "https://i.imgur.com/sd37Q2z.png",
    image_width = 13,
    image_height = 19,
    black_is_transparent = true,
    draw_offset_x = 500,
    draw_offset_y = 500,
    draw_pixel_size = 10
}

file.CreateDir("web_images")
local function download_image(address, callback) --Downloads an image from a web address
    local id = config.image_identifier

    if file.Exists("web_images/" .. id .. ".png", "DATA") then
        callback(Material("../data/web_images/" .. id .. ".png"))
        return
    end

    http.Fetch(address, function(body, len, headers, code)
        file.Write("web_images/" .. id .. ".png", body)
        callback(Material("../data/web_images/" .. id .. ".png"))
    end)
end

local function get_material_map_and_palette(material) --Returns a map of pixels and a colour palette the image uses
    local width, height = config.image_width, config.image_height
    local render_target = GetRenderTarget("image_converter_" .. config.image_identifier .. "_" .. width .. "x" .. height, width, height)

    render.PushRenderTarget(render_target) --We have to draw the image in an RT to get individual pixel data
    cam.Start2D()

    render.OverrideDepthEnable(true, true)
    render.OverrideAlphaWriteEnable(true, true)

    render.ClearDepth()
    render.Clear(0, 0, 0, 0)

    render.OverrideDepthEnable(false)
    render.OverrideAlphaWriteEnable(false)

    surface.SetMaterial(material)
    surface.SetDrawColor(255, 255, 255)
    surface.DrawTexturedRect(0, 0, width, height)

    render.CapturePixels()

    local pixel_map = {}
    local color_palette = {}

    for y = 1, height do
        pixel_map[y] = {}

        for x = 1, width do
            local r, g, b = render.ReadPixel(x - 1, y - 1)
            local color_id = r .. "." .. g .. "." .. b

            if not color_palette[color_id] then
                color_palette[color_id] = Color(r, g, b)
            end

            pixel_map[y][x] = color_id
        end
    end

    cam.End2D()
    render.PopRenderTarget()

    return pixel_map, color_palette
end

local function print_image_in_console(pixel_map, color_palette) --Prints a pixel map + colour palette image to the console
    for y = 1, config.image_height do
        local row = pixel_map[y]

        for x = 1, config.image_width do
            MsgC(color_palette[row[x]], "▉▉")
        end

        Msg("\n")
    end
end

local function get_sequential_color_palette(color_palette) --Returns a sequential version of the colour palette and a key to id LUT
    local key_to_id = {}
    local new_color_palette = {}

    local id = 1
    for key, color in pairs(color_palette) do
        key_to_id[key] = id
        new_color_palette[id] = color
        id = id + 1
    end

    return new_color_palette, key_to_id
end

local function print_color_palette(color_palette, tab_chars) --Prints a colour palette in Lua table form
    tab_chars = tab_chars or "    "

    local table_string = "local color_palette = {\n"

    for id, color in ipairs(color_palette[1] and color_palette or get_sequential_color_palette(color_palette)) do --Converts the colour palette to sequential if not already
        table_string = table_string .. tab_chars .. ("[%i] = Color(%i, %i, %i),\n"):format(id, color.r, color.g, color.b)
    end

    print(table_string:sub(1, #table_string - 2) .. "\n}")
end

local function print_pixel_map(pixel_map, sequential_palette, key_to_id, tab_chars) --Prints a map of pixels in Lua table form
    tab_chars = tab_chars or "    "

    local table_string = "local pixel_map = {\n"

    for y = 1, config.image_height do
        local row = pixel_map[y]
        table_string = table_string .. tab_chars .. "{"

        for x = 1, config.image_width do
            local color_key = row[x]
            if not color_key then goto skip end

            table_string = table_string .. key_to_id[color_key] .. ", "
            ::skip::
        end

        table_string = table_string:sub(1, #table_string - 2) .. "},\n"
    end

    print(table_string:sub(1, #table_string - 2) .. "\n}")
end

local function draw_pixel_map(pixel_map, color_palette) --Draws the pixel map on the player's HUD
    local pixel_size = math.floor(config.draw_pixel_size)
    local offset_x, offset_y = config.draw_offset_x, config.draw_offset_y
    local image_width, image_height = config.image_width, config.image_height

    local set_draw_color = surface.SetDrawColor
    local draw_rect = surface.DrawRect

    hook.Add("HUDPaint", "image_converter_draw_" .. config.image_identifier, function()
        for y = 1, image_height do
            local row = pixel_map[y]

            for x = 1, image_width do
                local pixel = row[x]
                if not pixel then goto skip end

                set_draw_color(color_palette[pixel])
                draw_rect(offset_x + (x * pixel_size), offset_y + (y * pixel_size), pixel_size, pixel_size)

                ::skip::
            end
        end
    end)
end

download_image(config.image_address, function(material)
    local pixel_map, color_palette = get_material_map_and_palette(material)

    if config.black_is_transparent and color_palette["0.0.0"] then --Convert black to transparent
        color_palette["0.0.0"] = color_transparent
    end

    print_image_in_console(pixel_map, color_palette)
    draw_pixel_map(pixel_map, color_palette)

    local sequential_palette, key_to_id = get_sequential_color_palette(color_palette) --Get the sequential version of the palette so we only calculate it once
    print_color_palette(sequential_palette)
    print_pixel_map(pixel_map, sequential_palette, key_to_id)
end)