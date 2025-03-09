local RenderTargetWidgetBase = require "Framework.UI.RT.RenderTargetWidgetBase"
local CollectiblesBallRenderingWidget = DefineClass("CollectiblesBallRenderingWidget", RenderTargetWidgetBase)

function CollectiblesBallRenderingWidget:OnCreate()
    RenderTargetWidgetBase.OnCreate(self)
    self.MonsterLoadFinish = LuaMulticastDelegate.new()  -- luacheck: ignore
end

function CollectiblesBallRenderingWidget:ExtraOP()
	self:StartCapture()

	if self._SceneID then
		Game.SceneDisplayManager:ShowScene(self._SceneID)
	end
end

function CollectiblesBallRenderingWidget:StartCapture()
    if self.captureTimer then
        self:StopTimer(self.captureTimer)
    end

	self._Scene:BeginCapture()
	self.captureTimer = self:StartTickTimer("CaptureTick", function ()
		self._Scene:BeginCapture()
	end, -1)
end

function CollectiblesBallRenderingWidget:EndCapture()
    if not self.captureTimer then
        return
    end

    self:StopTimer(self.captureTimer)
	self.captureTimer = nil
end

function CollectiblesBallRenderingWidget:GetSceneName()
    return "UIRTCollectiblesBall"
end

function CollectiblesBallRenderingWidget:GetBall()
	return self._Scene:GetBall()
end

function CollectiblesBallRenderingWidget:GetBallRoot()
	return self._Scene:GetScene()
end

function CollectiblesBallRenderingWidget:GetScene()
	return self._Scene
end

return CollectiblesBallRenderingWidget
