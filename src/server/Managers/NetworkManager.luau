--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)

local NetworkManager = {}
local events: { [string]: RemoteEvent } = {}

function NetworkManager.init()
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then existing:Destroy() end
	local folder = Instance.new("Folder"); folder.Name = "Remotes"; folder.Parent = ReplicatedStorage
	for _, name in RemoteNames do
		local ev = Instance.new("RemoteEvent"); ev.Name = name; ev.Parent = folder
		events[name] = ev
	end
end
function NetworkManager.broadcast(name: string, ...) events[name]:FireAllClients(...) end
function NetworkManager.fireTo(name: string, plr: Player, ...) events[name]:FireClient(plr, ...) end
function NetworkManager.onServerEvent(name: string, fn) events[name].OnServerEvent:Connect(fn) end
return NetworkManager
