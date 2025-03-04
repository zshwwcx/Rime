#include "KGPyUnreal.h"

#include "KGLua.h"

PYBIND11_UNREAL_REGISTER_TYPE_NAME(FKGEditorLua);

void KGPyUnreal::Initialize_KGCore(py::module_& Module)
{
	py::unreal_class<FKGEditorLua, TSharedPtr<FKGEditorLua>>(Module, "KGEditorLua")
		.def(py::init([]()
		{
			return MakeShared<FKGEditorLua>();
		}))
		.def_auto_naming(FKGEditorLua, CreateLuaState)
		.def_auto_naming(FKGEditorLua, CloseLuaState)
		.def("call", [](FKGEditorLua& Self, const FString& Code)
		{
			Self.CreateLuaState(GEditor->GetEditorWorldContext().World(), nullptr);
			auto* L = Self.GetLuaState();
			luaL_loadstring(L, TCHAR_TO_UTF8(*Code));
			if (lua_pcall(L, 0, 0, 0) != 0)
			{
				FString Error = UTF8_TO_TCHAR(lua_tostring(L, -1));
				UE_LOG(LogTemp, Error, TEXT("%s"), *Error);
				lua_pop(L, 1);
			}
			Self.CloseLuaState();
		});
}