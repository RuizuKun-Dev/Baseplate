local PlayersService = game:GetService('Players')
local clientChatModules = script.Parent
local ChatConstants = require(clientChatModules:WaitForChild('ChatConstants'))
local module = {}

module.WindowDraggable = false
module.WindowResizable = false
module.ShowChannelsBar = false
module.GamepadNavigationEnabled = false
module.AllowMeCommand = false
module.ShowUserOwnFilteredMessage = true
module.ChatOnWithTopBarOff = false
module.ScreenGuiDisplayOrder = 6
module.ShowFriendJoinNotification = true
module.BubbleChatEnabled = PlayersService.BubbleChat
module.ClassicChatEnabled = PlayersService.ClassicChat
module.ChatWindowTextSize = 18
module.ChatChannelsTabTextSize = 18
module.ChatBarTextSize = 18
module.ChatWindowTextSizePhone = 14
module.ChatChannelsTabTextSizePhone = 18
module.ChatBarTextSizePhone = 14
module.DefaultFont = Enum.Font.SourceSansBold
module.ChatBarFont = Enum.Font.SourceSansBold
module.BackGroundColor = Color3.new(0, 0, 0)
module.DefaultMessageColor = Color3.new(1, 1, 1)
module.DefaultNameColor = Color3.new(1, 1, 1)
module.ChatBarBackGroundColor = Color3.new(0, 0, 0)
module.ChatBarBoxColor = Color3.new(1, 1, 1)
module.ChatBarTextColor = Color3.new(0, 0, 0)
module.ChannelsTabUnselectedColor = Color3.new(0, 0, 0)
module.ChannelsTabSelectedColor = Color3.new(0.11764705882352941, 0.11764705882352941, 0.11764705882352941)
module.DefaultChannelNameColor = Color3.fromRGB(35, 76, 142)
module.WhisperChannelNameColor = Color3.fromRGB(102, 14, 102)
module.ErrorMessageTextColor = Color3.fromRGB(245, 50, 50)
module.MinimumWindowSize = UDim2.new(0.3, 0, 0.25, 0)
module.MaximumWindowSize = UDim2.new(1, 0, 1, 0)
module.DefaultWindowPosition = UDim2.new(0, 0, 0, 0)

local extraOffset = 24

module.DefaultWindowSizePhone = UDim2.new(0.5, 0, 0.5, extraOffset)
module.DefaultWindowSizeTablet = UDim2.new(0.4, 0, 0.3, extraOffset)
module.DefaultWindowSizeDesktop = UDim2.new(0.3, 0, 0.25, extraOffset)
module.ChatWindowBackgroundFadeOutTime = 3.5
module.ChatWindowTextFadeOutTime = 30
module.ChatDefaultFadeDuration = 0.8
module.ChatShouldFadeInFromNewInformation = false
module.ChatAnimationFPS = 20
module.GeneralChannelName = 'All'
module.EchoMessagesInGeneralChannel = true
module.ChannelsBarFullTabSize = 4
module.MaxChannelNameLength = 12
module.MaxChannelNameCheckLength = 50
module.RightClickToLeaveChannelEnabled = false
module.MessageHistoryLengthPerChannel = 50
module.ShowJoinAndLeaveHelpText = false
module.MaximumMessageLength = 200
module.DisallowedWhiteSpace = {
    '\n',
    '\r',
    '\t',
    '\v',
    '\f',
}
module.ClickOnPlayerNameToWhisper = true
module.ClickOnChannelNameToSetMainChannel = true
module.BubbleChatMessageTypes = {
    ChatConstants.MessageTypeDefault,
    ChatConstants.MessageTypeWhisper,
}
module.WhisperCommandAutoCompletePlayerNames = true
module.PlayerDisplayNamesEnabled = true
module.WhisperByDisplayName = true

local ChangedEvent = Instance.new('BindableEvent')
local proxyTable = setmetatable({}, {
    __index = function(tbl, index)
        return module[index]
    end,
    __newindex = function(tbl, index, value)
        module[index] = value

        ChangedEvent:Fire(index, value)
    end,
})

rawset(proxyTable, 'SettingsChanged', ChangedEvent.Event)

return proxyTable
