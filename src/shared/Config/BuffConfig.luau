--!strict
local BuffConfig = {}
export type BuffKind = "duration" | "oneshot" | "meta" | "debuff"
export type BuffDef = {
	id: string, name: string, kind: BuffKind, rarity: string, weight: number,
	desc: string, icon: string, duration: number?, params: { [string]: any },
}
BuffConfig.List = {
	{ id="swift",      name="신속",      kind="duration", rarity="common",    weight=100, desc="이동 속도 증가",   icon="⚡", params={ walkSpeedMult=1.30 } },
	{ id="strongArm",  name="강견",      kind="duration", rarity="common",    weight=100, desc="투척 거리 증가",   icon="🎯", params={ rangeMult=1.45 } },
	{ id="highJump",   name="도약",      kind="duration", rarity="common",    weight=100, desc="점프력 증가",     icon="⏫", params={ jumpMult=1.40 } },
	{ id="blink",      name="순간이동",  kind="oneshot",  rarity="uncommon",  weight=50,  desc="[Q] 짧은 순간이동", icon="✨", params={ dashStuds=14 } },
	{ id="reflect",    name="반사막",    kind="oneshot",  rarity="rare",      weight=18,  desc="다음 폭탄 반사",   icon="🛡️", params={} },
	{ id="repel",      name="밀어내기",  kind="oneshot",  rarity="rare",      weight=18,  desc="[E] 폭탄 즉시 넘김", icon="✋", params={} },
	{ id="reroll",     name="재추첨",    kind="meta",     rarity="rare",      weight=15,  desc="버프 다시 뽑기",   icon="🎲", params={} },
	{ id="doubleDraw", name="이중 획득", kind="meta",     rarity="legendary", weight=6,   desc="버프 2개 획득",   icon="✖️", params={} },
	{ id="sluggish",   name="둔화",      kind="debuff",   rarity="uncommon",  weight=35,  desc="이동 속도 감소",   icon="🐌", params={ walkSpeedMult=0.80 } },
	{ id="weakArm",    name="약한 팔",   kind="debuff",   rarity="uncommon",  weight=35,  desc="투척 거리 감소",   icon="🔻", params={ rangeMult=0.72 } },
} :: { BuffDef }
table.freeze(BuffConfig)
return BuffConfig
