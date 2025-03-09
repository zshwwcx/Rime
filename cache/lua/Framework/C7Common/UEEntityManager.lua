local CppManagerBase = kg_require("Framework/C7Common/CppManagerBase")

---@class UEEntityManager
UEEntityManager = DefineClass("UEEntityManager", CppManagerBase)

function UEEntityManager:ctor()
end

function UEEntityManager:dtor()
end

function UEEntityManager:Init()
    self:CreateCppManager("KGLuaEntityManager")
end

function UEEntityManager:UnInit()
    self:DestroyCppManager()
end

return UEEntityManager