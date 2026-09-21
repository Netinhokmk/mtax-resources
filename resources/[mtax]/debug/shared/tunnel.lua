_TUNNEL = {
     Delays = {},
     Identifier = getResourceName(getThisResource()),
     Resource = getResourceRootElement()
}

_TUNNEL.AddEvent = function(event, func)
     addEvent(event, true)
     addEventHandler(event, _TUNNEL.Resource, func)
end

_TUNNEL.GenerateID = function()
     local IDGenerator = {
         max = 1,
         ids = {}
     }
 
     IDGenerator.gen = function()
         if #IDGenerator.ids > 0 then
             table.remove(IDGenerator.ids)
         end
 
         local r = IDGenerator.max
         IDGenerator.max = IDGenerator.max+1
         return tostring( r )
     end
 
     IDGenerator.free = function(id)
         table.insert(IDGenerator.ids, id)
     end
 
     return setmetatable({}, { __index = IDGenerator })
 end

_TUNNEL.BindInterface = function(name, interface)
     _TUNNEL.AddEvent(name..":".._TUNNEL.Identifier..":_mtax_tunnel", function(fname, args, rid, playerSource)
          local f = interface[fname]
          local rets = {}
          
          if type(f) == "function" then
               rets = {f(unpack(args, 1, table.maxn(args)))}
          end
          
          if tonumber( rid ) >= 0 then
               if triggerClientEvent then
                    triggerClientEvent(playerSource, name..":".._TUNNEL.Identifier..":b_mtax_tunnel", _TUNNEL.Resource, rid, rets)
               else
                    triggerServerEvent(name..":".._TUNNEL.Identifier..":b_mtax_tunnel", _TUNNEL.Resource, rid, rets)
               end
          end
     end)
end


_TUNNEL.TunnelResolve = function(TableValue, key)
     local MTable = getmetatable(TableValue)
     local Tname = MTable.Name
     local Tid = MTable.IDG
     local Tcallback = MTable.Callbacks
     local Fname = key
     
     local fcall = function(callback, ...)
          local Args = {...}
          rID = Tid:gen()
          Tcallback[tostring(rID)] = function(...)
               if callback then
                    callback(...)
               end
          end
          
          if triggerClientEvent then
               player = Args[1]
               Args = {unpack(Args, 2, table.maxn(Args))}
               triggerClientEvent(player, Tname..":".._TUNNEL.Identifier..":_mtax_tunnel", _TUNNEL.Resource, Fname, Args, rID)
          else
               triggerServerEvent(Tname..":".._TUNNEL.Identifier..":_mtax_tunnel", _TUNNEL.Resource, Fname, Args, rID, localPlayer)
          end
     end
     
     TableValue[Fname] = fcall
     return fcall
end

function _TUNNEL.GetInterface(name)
     local Callbacks = {}
     local IDG = _TUNNEL.GenerateID()
     
     local r = setmetatable({}, {
          __index = _TUNNEL.TunnelResolve,
          Name = name,
          IDG = IDG,
          Callbacks = Callbacks
     })
     
     _TUNNEL.AddEvent(name..":".._TUNNEL.Identifier..":b_mtax_tunnel", function(rID, args)
          local callback = Callbacks[tostring(rID)]
          
          if callback then
               IDG:free(rID)
               Callbacks[tostring(rID)] = nil
               callback(unpack(args, 1, table.maxn(args)))
          end
     end)
     
     return r
end


if triggerClientEvent then
     Server = { }
     Client = _TUNNEL.GetInterface( _TUNNEL.Identifier )
     _TUNNEL.BindInterface( _TUNNEL.Identifier, Server )
else
     Client = { }
     Server = _TUNNEL.GetInterface( _TUNNEL.Identifier )
     _TUNNEL.BindInterface( _TUNNEL.Identifier, Client )
end