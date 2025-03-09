local CppManagerBase = kg_require("Framework/C7Common/CppManagerBase")

CppManagerBase = DefineClass("CppManagerBase")

function CppManagerBase:CreateCppManager(name)
    self.cppMgr = import(name)(Game.WorldContext)
    Game.GameInstance:CacheManager(self.cppMgr)
    self.cppMgr:NativeInit()
    self.cppMgr:BindLuaObject(self)
end

function CppManagerBase:DestroyCppManager()
    if self.cppMgr then
        self.cppMgr:NativeUninit()
        self.cppMgr = nil
    end
end