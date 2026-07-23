--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)

local NetworkController = {}
local remotes: Folder
local handlers: { [string]: { (any) -> () } } = {}

function NetworkController.init()
	remotes = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in RemoteNames do
		local ev = remotes:FindFirstChild(name)
		if ev and ev:IsA("RemoteEvent") then
			ev.OnClientEvent:Connect(function(...)
				local list = handlers[name]
				if list then
					for _, fn in list do fn(...) end
				end
			end)
		end
	end
end

-- 서버 이벤트 구독
function NetworkController.on(name: string, fn: (...any) -> ())
	handlers[name] = handlers[name] or {}
	table.insert(handlers[name], fn)
end
-- 서버로 요청 전송
function NetworkController.send(name: string, ...)
	local ev = remotes:FindFirstChild(name)
	if ev then ev:FireServer(...) end
end
return NetworkController
