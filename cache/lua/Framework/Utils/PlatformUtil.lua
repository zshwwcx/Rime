PlatformUtil = PlatformUtil or {}

local UGameplayStatics = import("GameplayStatics")

PlatformUtil.PlatformName = UGameplayStatics.GetPlatformName()

---IsMobilePlatform 判断是否在移动平台
---@return boolean
function PlatformUtil.IsMobilePlatform()
    if not PlatformUtil.isMobilePlatform then
        local platform = UGameplayStatics.GetPlatformName()
        PlatformUtil.isMobilePlatform = platform == "Android" or platform == "IOS"
    end
    return PlatformUtil.isMobilePlatform
end

function PlatformUtil.GetPlatformName()
    return PlatformUtil.PlatformName
end

---IsAndroid 是否是Android平台
function PlatformUtil.IsAndroid()
    return UGameplayStatics.GetPlatformName() == 'Android'
end

---IsiOS 是否是iOS平台
function PlatformUtil.IsiOS()
    return UGameplayStatics.GetPlatformName() == 'IOS'
end

---IsWindows 是否是Windows平台
function PlatformUtil.IsWindows()
    return UGameplayStatics.GetPlatformName() == 'Windows'
end