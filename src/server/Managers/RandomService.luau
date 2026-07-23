--!strict
-- 모든 랜덤을 단일 시드로 (재현/테스트 용이)
local RandomService = {}
local rng = Random.new()
function RandomService:reseed(seed: number) rng = Random.new(seed) end
function RandomService:number(a: number, b: number): number return rng:NextNumber(a, b) end
function RandomService:integer(a: number, b: number): number return rng:NextInteger(a, b) end
function RandomService:pick(list: { any }): any return list[rng:NextInteger(1, #list)] end
function RandomService:raw(): Random return rng end
return RandomService
