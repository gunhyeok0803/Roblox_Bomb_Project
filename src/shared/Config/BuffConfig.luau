--!strict
local BuffConfig = {}
export type BuffKind = "duration" | "oneshot" | "meta" | "debuff"
export type BuffDef = {
	id: string, name: string, kind: BuffKind,
	rarity: string, weight: number, duration: number?, params: { [string]: any },
}
BuffConfig.List = {
	-- 지속형 버프
	{ id="swift",      name="신속",      kind="duration", rarity="common",    weight=100, params={ walkSpeedMult=1.18 } },
	{ id="strongArm",  name="강견",      kind="duration", rarity="common",    weight=100, params={ rangeMult=1.30 } },
	{ id="highJump",   name="도약",      kind="duration", rarity="common",    weight=100, params={ jumpMult=1.25 } },
	-- 일회성 / 트리거 버프
	{ id="blink",      name="순간이동",  kind="oneshot",  rarity="uncommon",  weight=50,  params={ dashStuds=8 } },
	{ id="reflect",    name="반사막",    kind="oneshot",  rarity="rare",      weight=18,  params={} },
	{ id="repel",      name="밀어내기",  kind="oneshot",  rarity="rare",      weight=18,  params={} },
	-- 메타 (추첨 조작)
	{ id="reroll",     name="재추첨",    kind="meta",     rarity="rare",      weight=15,  params={} },
	{ id="doubleDraw", name="이중 획득", kind="meta",     rarity="legendary", weight=6,   params={} },
	-- 디버프
	{ id="sluggish",   name="둔화",      kind="debuff",   rarity="uncommon",  weight=35,  params={ walkSpeedMult=0.85 } },
	{ id="weakArm",    name="약한 팔",   kind="debuff",   rarity="uncommon",  weight=35,  params={ rangeMult=0.80 } },
} :: { BuffDef }
table.freeze(BuffConfig)
return BuffConfig
