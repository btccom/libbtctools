-- log to file

local log = io.open('./btctools.log', 'ab')

print = function(...)
    log:write(table.concat({...}, " "))
    log:write("\n")
end
