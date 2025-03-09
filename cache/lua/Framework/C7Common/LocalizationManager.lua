local LocalizationManager = {}

function LocalizationManager:Init()
    self:NativeInit()
end

function LocalizationManager:UnInit()
    self:NativeUninit()
end

return Class(nil, nil, LocalizationManager)