addEvent( 'onPlayerLogin', false )

addEventHandler( 'onPlayerLogin', root, function( )
    local source = source
    setElementHealth(source, 100)
    fadeCamera(source, false, 0.3)

    setTimer(function(source)
        spawnPlayer(source, Config.Spawn.Pos, Config.Spawn.Rot, 0, 0, 0 )
        setCameraTarget(source)
        fadeCamera(source, true, 0.5)
        Client.SmoothCamera(false, source)
    end, 300, 1, source)
end)

addEventHandler('onPlayerJoin', root, function( )
    local source = source
    local Cam = Config.Cam[math.random(#Config.Cam)]
    setCameraMatrix(source, Cam.Pos.x, Cam.Pos.y, Cam.Pos.z, Cam.Look.x, Cam.Look.y, Cam.Look.z)
end)


addEventHandler('onPlayerWasted', root, function( )
    local source = source
    fadeCamera( source, false, 0.8 )

    setTimer(function(player)
        fadeCamera(player, true, 0.8)
        setElementHealth(player, 100)
        setCameraTarget(player, player)
        spawnPlayer(player, Config.Spawn.Pos, Config.Spawn.Rot)
    end, 800, 1, source)
end)