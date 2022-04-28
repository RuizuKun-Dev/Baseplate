local module = {}

module.MessageTypeDefault = 'Message'
module.MessageTypeSystem = 'System'
module.MessageTypeMeCommand = 'MeCommand'
module.MessageTypeWelcome = 'Welcome'
module.MessageTypeSetCore = 'SetCore'
module.MessageTypeWhisper = 'Whisper'
module.MajorVersion = 0
module.MinorVersion = 8
module.BuildVersion = '2018.05.16'
module.VeryLowPriority = -5
module.LowPriority = 0
module.StandardPriority = 10
module.HighPriority = 20
module.VeryHighPriority = 25
module.WhisperChannelPrefix = 'To '

return module
