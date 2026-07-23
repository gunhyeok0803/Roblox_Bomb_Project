--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)

local InputController = {}
local network

-- 능동 버프 키 바인딩
local ACTIVE_BUFF_KEYS = {
	[Enum.KeyCode.Q] = "blink",  -- 순간이동
	[Enum.KeyCode.E] = "repel",  -- 밀어내기
}

function InputController.init(net)
	network = net
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		-- 투척: 좌클릭 / 터치
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			local cam = workspace.CurrentCamera
			if not cam then return end
			local mouse = Players.LocalPlayer:GetMouse()
			local aimDir = (mouse.Hit.Position - cam.CFrame.Position)
			network.send(RemoteNames.RequestThrowBomb, aimDir) -- 방향만 전송, 판정은 서버
			return
		end
		-- 능동 버프 사용
		local buffId = ACTIVE_BUFF_KEYS[input.KeyCode]
		if buffId then
			network.send(RemoteNames.RequestUseBuff, buffId)
		end
	end)
end
return InputController
