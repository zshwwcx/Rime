local SAFE_ZONE = {
    ["Android"] = {

    },
    ["IOS"] = {
        ["iPhone8"] = {
            BaseProfileName = "iPhone8",
            SafeArea = {left = 120, right = 120, top = 10, bottom = 20}
        }
    },
    ["Windows"] = {
        ["Default"] = {
            BaseProfileName = "Default",
            SafeArea = {left = 50, right = 40, top = 10, bottom = 0}
        }
    },
    --固定格式
    ["Default"] = {
        ["Default"] = {
            BaseProfileName = "Default",
            SafeArea = {left = 100, right = 100, top = 10, bottom = 0}
        }
    }
}

return SAFE_ZONE