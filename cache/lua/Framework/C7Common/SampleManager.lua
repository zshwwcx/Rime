SampleManager = DefineClass("SampleManager")  --or DefineSingletonClass


--基础数据结构在构造函数和析构函数里进行，过了这个时间点，不能再次增加表字段
function SampleManager:ctor()
    self.Logger = Logger.new()
    self.Logger:SetPrefix(string.format("[%s]", self.__cname))
end


function SampleManager:dtor()
    self.Logger:delete()
    self.Logger = nil
end


--可重复性初始化和逆初始逻辑在Init/UnInit里进行
function SampleManager:Init()
end

function SampleManager:UnInit()
end


--samples
function SampleManager:samplePrivateFunction()
    --self.Logger:Debug(" debug log ")
    --self.Logger:Warning(" warning log ")
    --self.Logger:Error(" error log ")

    --self.Logger:Release("abc %s", "edf")
    --self.Logger:ReleaseWarning("")
    --self.Logger:ReleaseError("")
end




return SampleManager