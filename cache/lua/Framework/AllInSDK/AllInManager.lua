local AllInManager = {}

function AllInManager:Init()
    self.MessageChannel = require "Framework.AllInSDK.MessageChannel"
end

function AllInManager:ReceiveAllInSDKMessage(Message)
    self.MessageChannel:ReceiveAllInSDKMessage(Message)
end

return Class(nil,nil,AllInManager)