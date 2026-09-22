local visible = false
local history = { }
local scrollOffset = 0
local debugCount = 0
local debugLevel = {
    [ 1 ] = 'erro',
    [ 2 ] = 'debug',
    [ 3 ] = 'success',
}


local colors = {
    erro = tocolor( 255, 0, 0 ),
    debug = tocolor( 255, 255, 255 ),
    success = tocolor( 0, 255, 0 ),
}


screenWidth, screenHeight = guiGetScreenSize( )

local fonts = { }

scale = 1

if ( screenHeight <= 480 ) then
     scale = 0.7
elseif ( screenHeight <= 576 ) then
     scale = 0.8
elseif ( screenHeight <= 600 ) then
     scale = 0.9
elseif ( screenHeight <= 720 ) or ( screenHeight <= 768 ) then
     scale = 1
elseif ( screenHeight <= 900 ) then
     scale = 1.1
elseif ( screenHeight <= 1050 ) then
     scale = 1.15
elseif ( screenHeight <= 1080 ) then
     scale = 1
else
     scale = math.min (math.max (0.75, (screenHeight / 768)), 1.2)
end

parentWidth, parentHeight = ( 778 * scale ), ( 175 * scale )
parentX, parentY = (screenWidth - parentWidth) / 2, (screenHeight - parentHeight) / 1.1


function respc (value)
     return value * scale
end


function reMap (parent, value)
     return (parent + (value * scale))
end;

getFont = function(font, size)
     if (not fonts[font]) then
          fonts[font] = { }
     end
     if (not fonts[font][size]) then
          fonts[font][size] = dxCreateFont('fonts/'..font, (size * scale) * (72 / 96), false, 'cleartype') or 'default-bold'
     end
     return fonts[font][size]
end

_dxDrawText = dxDrawText
function dxDrawText(parentX, parentY, text, x, y, w, h, ...)
     local x, y, w, h = reMap(parentX, x), reMap(parentY, y), respc(w), respc(h)
     return _dxDrawText(text, x, y, x + w, y + h, ...)
end


_dxDrawRectangle = dxDrawRectangle
function dxDrawRectangle(parentX, parentY, x, y, w, h, ...)
     local x, y, w, h = reMap(parentX, x), reMap(parentY, y), respc(w), respc(h)
     return _dxDrawRectangle(x, y, w, h, ...)
end

_dxDrawImage = dxDrawImage
function dxDrawImage(parentX, parentY, x, y, w, h, path, ...)
     local x, y, w, h = reMap(parentX, x), reMap(parentY, y), respc(w), respc(h)
     return _dxDrawImage(x, y, w, h, path, ...)
end


_dxCreateFont = dxCreateFont
function dxCreateFont( filePath, size, ... )
     return _dxCreateFont( filePath, ( size ), ... )
end


cursors = {0, 0}
Cursor = function( parentX, parentY, x, y, w, h )
     if parentX and parentY then
          local x, y, w, h = reMap(parentX, x), reMap(parentY, y), respc(w), respc(h)
          if isCursorShowing () then
               local cursor = {getCursorPosition ()}
               cursors = {
                    cursor[1] * screenWidth;
                    cursor[2] * screenHeight
               }
          end
          return (cursors[1] >= x and cursors[1] <= x + w and cursors[2] >= y and cursors[2] <= y + h)
     end
     return false
end


addToHistory = function( data )
    debugCount = debugCount + 1
    if debugCount >= 50 then
        debugCount = 0
        history = { }
        scrollOffset = 0
    end
    local last = history[ #history ]
    if last and last.text == data.text and last.level == data.level and last.side == data.side and last.file == data.file and last.line == data.line then
        last.count = ( last.count or 1 ) + 1
        return
    end
    data.count = 1
    table.insert( history, data )
    if #history > 7 then
        table.remove( history, 1 )
    end
end

Toggle = function( )
    visible = not visible
end

addCommandHandler( 'debug', function( )
    Server.isObjectInAcl( function( check )
        if check then
            Toggle( )
            Server.setDebugVisible( nil, visible )
        end
    end)
end)


addCommandHandler( 'cleardebug', function( )
    history = { }
end)


wrapText = function( text, font, maxWidth )
    local lines = { }
    local line = ''
    for word in string.gmatch( text, '%S+' ) do
        while dxGetTextWidth( word, 1.0, font ) > maxWidth and #word > 1 do
            local cut = #word
            while cut > 1 and dxGetTextWidth( string.sub( word, 1, cut ), 1.0, font ) > maxWidth do
                cut = cut - 1
            end
            if line ~= '' then
                table.insert( lines, line )
                line = ''
            end
            table.insert( lines, string.sub( word, 1, cut ) )
            word = string.sub( word, cut + 1 )
        end
        local test = line == '' and word or line .. ' ' .. word
        if dxGetTextWidth( test, 1.0, font ) <= maxWidth then
            line = test
        else
            if line ~= '' then
                table.insert( lines, line )
            end
            line = word
        end
    end
    if line ~= '' then
        table.insert( lines, line )
    end
    return lines
end

render_debug = function( )
    if not visible then
        return
    end
    local font = getFont( 'sf-bold.ttf', 14 )
    local lines = { }
    for i = 1, #history do
        local value = history[ #history - i + 1 ]
        local message = value.count and value.count > 1 and ( value.text .. ' x' .. value.count ) or value.text
        for _, text in ipairs( wrapText( message, font, respc( 865 ) ) ) do
            table.insert( lines, { text = text, level = value.level, side = value.side } )
        end
    end
    local maxOffset = math.max( 0, #lines - 7 )
    if scrollOffset > maxOffset then
        scrollOffset = maxOffset
    end
    for i = 1, 7 do
        local value = lines[ scrollOffset + i ]
        if value then
            dxDrawText( parentX, parentY, '['..value.side..'] - '..value.text, 6, 15 - 30 + i * 30, 765, 15, tocolor( 0, 0, 0 ), 1.0, font, 'left', 'center', false, false, true )
            dxDrawText( parentX, parentY, '['..value.side..'] - '..value.text, 6, 13 - 30 + i * 30, 765, 15, colors[value.level] or colors.info, 1.0, font, 'left', 'center', false, false, true )
        end
    end
end
addEventHandler( 'onClientRender', root, render_debug )

bindKey( 'pgdn', 'down', function( )
    scrollOffset = scrollOffset + 7
end)

bindKey( 'pgup', 'down', function( )
    scrollOffset = math.max( 0, scrollOffset - 7 )
end)



addEventHandler( 'onClientDebugMessage', root, function( message, level, file, line )
    addToHistory({ level = debugLevel[ tonumber( level ) ] or 'info', text = message, side = 'client', file = file, line = line })
end)

Client.onDebugMessage = function( messages )
    if type( messages ) ~= 'table' then
        return
    end
    for i = 1, #messages do
        local value = messages[ i ]
        addToHistory({ level = debugLevel[ tonumber( value[ 2 ] ) ] or 'info', text = value[ 1 ], side = 'server', file = value[ 3 ], line = value[ 4 ] })
    end
end
