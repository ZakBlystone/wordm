module("wordm_deathcards", package.seeall)

local CardVerbs = {
	"killed",
	"destroyed",
	"decimated",
	"eliminated",
	"took out",
	"deconstructed",
	"iced",
	"ended",
	"put an end to",
	"dispatched",
	"terminated",
	"finished off",
	"assassinated",
	"murdered",
	"wrecked",
	"annihilated",
	"eradicated",
	"wasted",
	"devestated",
}

local DeathCard = nil --[[{
	time = CurTime(),
	word = ("Anti-intellectualism"):upper(),
	attacker = "Killer",
	victim = "Victim",
	damage = 100,
	where = "butt",
	verb = CardVerbs[math.random(1,#CardVerbs)],
}]]


function GM:DrawDeathCard( card )

	if card == nil then return end

	local dt = CurTime() - card.time
	local alpha = 1
	local burst = 1 - math.min(dt, 1)

	local duration = 10
	if dt > duration then alpha = math.max(1 - (dt - duration), 0) end
	if alpha == 0 then return end

	local screen = textfx.ScreenBox()
	screen.y = screen.y - (1 - math.pow(burst, 4)) * 100

	local ba = 20 + burst * 200
	local br,bg,bb = math.HSVToRGB(40,burst,255)

	local attacker = textfx.Builder(card.attacker, "WordAmmoFont"):Box(10,2):Color(190,255,100,alpha*255)
	local killed = textfx.Builder(card.verb, "CooldownWordFont"):Box(10,4):Color(255,120,120,alpha*255)
	:HAlignTo(attacker, "after")
	:VAlignTo(attacker, "center")

	local victim = textfx.Builder(card.victim, "WordAmmoFont"):Box(10,2):Color(190,255,100,alpha*255)
	:HAlignTo(killed, "after")
	:VAlignTo(killed, "center")

	local box = textfx.BuilderBox(attacker, killed, victim):Store():HAlignTo(screen, "center")
	textfx.BuilderShift(box, attacker, killed, victim)

	local with = textfx.Builder(("shot in the %s for %i damage with"):format(card.where, card.damage), "CooldownWordFont"):Box(10,2):Color(255,255,255,alpha*180)
	:HAlignTo(box, "center")
	:VAlignTo(attacker, "after")

	local word = textfx.Builder(card.word, "WordAmmoFont"):Box(10,2)
	:Color(255,255,255,alpha*255)
	:HAlignTo(box, "center")
	:VAlignTo(with, "after")

	local box = textfx.BuilderBox(attacker, killed, victim, with, word):Pad(40 - 30 * burst*burst, 10)
	:Store()
	:HAlignTo(screen, "center")
	:VAlignTo(screen, "bottom")
	:DrawRounded(br,bg,bb,ba*alpha*alpha,8):Pad(-5):DrawRounded(0,0,0,200*alpha,6):Pad(5)

	textfx.BuilderShift(box, attacker, killed, victim, with, word)

	attacker:Draw()
	killed:Draw()
	victim:Draw()
	with:Draw()
	word:Draw()

end

function GM:DrawDeathCards()

	self:DrawDeathCard(DeathCard)

end

function GM:AddDeathCard(card)

	DeathCard = card

end

local GroupNames = {
	[HITGROUP_GENERIC] = "body",
	[HITGROUP_HEAD] = "head",
	[HITGROUP_CHEST] = "chest",
	[HITGROUP_STOMACH] = "stomach",
	[HITGROUP_LEFTARM] = "left arm",
	[HITGROUP_RIGHTARM] = "right arm",
	[HITGROUP_LEFTLEG] = "left leg",
	[HITGROUP_RIGHTLEG] = "right leg",
	[HITGROUP_GEAR] = "stuff",
}

net.Receive("worddeath_msg", function()

	local str = net.ReadString()
	local attacker = net.ReadEntity()
	local victim = net.ReadEntity()
	local damage = net.ReadFloat()
	local hitbox = net.ReadUInt(16)

	local group = GroupNames[victim:GetHitBoxHitGroup(hitbox, 0) or 0]

	local card = {
		time = CurTime(),
		word = str:upper(),
		attacker = SanitizeToAscii(attacker:Nick()),
		victim = SanitizeToAscii(victim:Nick()),
		damage = tostring(damage),
		where = group,
		verb = CardVerbs[math.random(1,#CardVerbs)],
	}

	GAMEMODE:AddDeathCard( card )

end)