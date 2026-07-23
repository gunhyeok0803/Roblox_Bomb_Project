--!strict
local BombConfig = {}
BombConfig.THROW_RANGE = 45
BombConfig.THROW_COOLDOWN = 1.0
BombConfig.HIT_RADIUS = 3
BombConfig.PROJECTILE_SPEED = 80
BombConfig.ATTACH_OFFSET = Vector3.new(0, 2.5, 0)
table.freeze(BombConfig)
return BombConfig
