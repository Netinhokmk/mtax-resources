config = {
     ['gerais'] = {
          ['show:panel'] = {
               ['command'] = 'cpu';
               ['permission'] = { 'Everyone', 'Admin' };
          };
          ['get:status'] = {
               function( percent )
                    local floor = tofloor( percent )
                    if floor >= 8 and floor < 15 then
                         return 'color:warning'
                    elseif floor >= 15 then
                         return 'color:error'
                    end
                    return 'color:success'
               end;
          };
          ['colors'] = {
               ['hex:server'] = '#18A8F2';
               ['color:server'] = { 24, 168, 242 };
               ['color:success'] = { 0, 255, 26 };
               ['color:warning'] = { 255, 214, 0 };
               ['color:error'] = { 255, 0, 0 };
          };
     };
}
