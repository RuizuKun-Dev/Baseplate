local UserFlagRemoveMessageFromMessageLog

do
    local success, value = pcall(function()
        return UserSettings():IsUserFeatureEnabled('UserFlagRemoveMessageFromMessageLog')
    end)

    UserFlagRemoveMessageFromMessageLog = success and value
end

local module = {}
local Chat = game:GetService('Chat')
local clientChatModules = Chat:WaitForChild('ClientChatModules')
local modulesFolder = script.Parent
local ChatSettings = require(clientChatModules:WaitForChild('ChatSettings'))
local methods = {}

methods.__index = methods

function methods:Destroy()
    self.Destroyed = true
end
function methods:SetActive(active)
    if active == self.Active then
        return
    end
    if active == false then
        self.MessageLogDisplay:Clear()
    else
        self.MessageLogDisplay:SetCurrentChannelName(self.Name)

        for i=1, #self.MessageLog do
            self.MessageLogDisplay:AddMessage(self.MessageLog[i])
        end
    end

    self.Active = active
end
function methods:UpdateMessageFiltered(messageData)
    local searchIndex = 1
    local searchTable = self.MessageLog
    local messageObj = nil

    while(#searchTable >= searchIndex) do
        local obj = searchTable[searchIndex]

        if (obj.ID == messageData.ID) then
            messageObj = obj

            break
        end

        searchIndex = searchIndex + 1
    end

    if messageObj then
        messageObj.Message = messageData.Message
        messageObj.IsFiltered = true

        if self.Active then
            if UserFlagRemoveMessageFromMessageLog then
                if messageObj.Message == '' then
                    table.remove(self.MessageLog, searchIndex)
                end
            end

            self.MessageLogDisplay:UpdateMessageFiltered(messageObj)
        end
    else
        self:AddMessageToChannelByTimeStamp(messageData)
    end
end
function methods:AddMessageToChannel(messageData)
    table.insert(self.MessageLog, messageData)

    if self.Active then
        self.MessageLogDisplay:AddMessage(messageData)
    end
    if #self.MessageLog > ChatSettings.MessageHistoryLengthPerChannel then
        self:RemoveLastMessageFromChannel()
    end
end
function methods:InternalAddMessageAtTimeStamp(messageData)
    for i=1, #self.MessageLog do
        if messageData.Time < self.MessageLog[i].Time then
            table.insert(self.MessageLog, i, messageData)

            return
        end
    end

    table.insert(self.MessageLog, messageData)
end
function methods:AddMessagesToChannelByTimeStamp(messageLog, startIndex)
    for i=startIndex, #messageLog do
        self:InternalAddMessageAtTimeStamp(messageLog[i])
    end

    while#self.MessageLog > ChatSettings.MessageHistoryLengthPerChannel do
        table.remove(self.MessageLog, 1)
    end

    if self.Active then
        self.MessageLogDisplay:Clear()

        for i=1, #self.MessageLog do
            self.MessageLogDisplay:AddMessage(self.MessageLog[i])
        end
    end
end
function methods:AddMessageToChannelByTimeStamp(messageData)
    if #self.MessageLog >= 1 then
        if self.MessageLog[1].Time > messageData.Time then
            return
        elseif messageData.Time >= self.MessageLog[#self.MessageLog].Time then
            self:AddMessageToChannel(messageData)

            return
        end

        for i=1, #self.MessageLog do
            if messageData.Time < self.MessageLog[i].Time then
                table.insert(self.MessageLog, i, messageData)

                if #self.MessageLog > ChatSettings.MessageHistoryLengthPerChannel then
                    self:RemoveLastMessageFromChannel()
                end
                if self.Active then
                    self.MessageLogDisplay:AddMessageAtIndex(messageData, i)
                end

                return
            end
        end
    else
        self:AddMessageToChannel(messageData)
    end
end
function methods:RemoveLastMessageFromChannel()
    table.remove(self.MessageLog, 1)

    if self.Active then
        self.MessageLogDisplay:RemoveLastMessage()
    end
end
function methods:ClearMessageLog()
    self.MessageLog = {}

    if self.Active then
        self.MessageLogDisplay:Clear()
    end
end
function methods:RegisterChannelTab(tab)
    self.ChannelTab = tab
end
function module.new(channelName, messageLogDisplay)
    local obj = setmetatable({}, methods)

    obj.Destroyed = false
    obj.Active = false
    obj.MessageLog = {}
    obj.MessageLogDisplay = messageLogDisplay
    obj.ChannelTab = nil
    obj.Name = channelName

    return obj
end

return module
