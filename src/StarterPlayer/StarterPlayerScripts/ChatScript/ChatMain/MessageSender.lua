local module = {}
local modulesFolder = script.Parent
local methods = {}

methods.__index = methods

function methods:SendMessage(message, toChannel)
    self.SayMessageRequest:FireServer(message, toChannel)
end
function methods:RegisterSayMessageFunction(func)
    self.SayMessageRequest = func
end
function module.new()
    local obj = setmetatable({}, methods)

    obj.SayMessageRequest = nil

    return obj
end

return module.new()
