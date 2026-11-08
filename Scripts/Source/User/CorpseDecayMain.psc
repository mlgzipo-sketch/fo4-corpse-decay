Scriptname CorpseDecayMain extends Quest
{Corpse Decay: bodies rot over game time, then turn into remains and bones.
Scavengers (dogs, ghouls, mole rats...) sometimes gather at old corpses.
Pure Papyrus, so it runs in Fallout 4 and Fallout 4 VR alike.}

; ---------------------------------------------------------------- properties (filled by the ESP)
FormList Property CD_ActorTypes Auto Const      ; keywords of actors that decay
FormList Property CD_ScavengersExterior Auto Const
FormList Property CD_ScavengersInterior Auto Const
Keyword Property ActorTypeRobot Auto Const
Keyword Property ActorTypeHuman Auto Const
Keyword Property ActorTypeGhoul Auto Const
Keyword Property ActorTypeFeralGhoul Auto Const
Keyword Property ActorTypeSuperMutant Auto Const
Activator Property CD_Flies Auto Const          ; vanilla gnat swarm
EffectShader Property CD_PaleFXS Auto Const
EffectShader Property CD_RotFXS Auto Const
Container Property CD_RemainsFlesh Auto Const    ; skeleton with meat, lootable
Container Property CD_RemainsBones Auto Const    ; bare skeleton, lootable

GlobalVariable Property CD_Enabled Auto Const
GlobalVariable Property CD_Debug Auto Const
GlobalVariable Property CD_TimeScale Auto Const  ; 1 = normal, 24 = a day passes in an hour (testing)
GlobalVariable Property CD_HoursFlies Auto Const
GlobalVariable Property CD_HoursPale Auto Const
GlobalVariable Property CD_HoursRot Auto Const
GlobalVariable Property CD_HoursRemains Auto Const
GlobalVariable Property CD_HoursBones Auto Const
GlobalVariable Property CD_HoursCleanup Auto Const
GlobalVariable Property CD_ScavengerChance Auto Const ; percent per corpse per game day
GlobalVariable Property CD_IncludeOldCorpses Auto Const ; 1 = also bodies that were dead before we saw them die

; ---------------------------------------------------------------- stages
int Property STAGE_FRESH = 0 AutoReadOnly
int Property STAGE_FLIES = 1 AutoReadOnly
int Property STAGE_PALE = 2 AutoReadOnly
int Property STAGE_ROT = 3 AutoReadOnly
int Property STAGE_REMAINS = 4 AutoReadOnly
int Property STAGE_BONES = 5 AutoReadOnly
int Property STAGE_GONE = 6 AutoReadOnly

int Property MAX_TRACKED = 100 AutoReadOnly
int Property MAX_SCAVENGERS = 9 AutoReadOnly
int Property TIMER_SCAN = 1 AutoReadOnly
float Property SCAN_RADIUS = 8000.0 AutoReadOnly
float Property SCAN_INTERVAL = 4.0 AutoReadOnly

; ---------------------------------------------------------------- state (parallel arrays, one slot per corpse)
Actor[] Bodies
float[] DeathDay
int[] Stage
ObjectReference[] Remains
ObjectReference[] Flies
float[] NextScavengerDay
int[] SeenTick
ObjectReference[] Scavengers
int Tick = 0

; ================================================================ startup
Event OnQuestInit()
	Setup()
EndEvent

Event Actor.OnPlayerLoadGame(Actor akSender)
	Setup()
	; shaders are not saved: make every loaded corpse re-apply its look
	Tick += 2
EndEvent

Function Setup()
	if Bodies == None
		Bodies = new Actor[1]
		Bodies.Clear()
		DeathDay = new float[1]
		DeathDay.Clear()
		Stage = new int[1]
		Stage.Clear()
		Remains = new ObjectReference[1]
		Remains.Clear()
		Flies = new ObjectReference[1]
		Flies.Clear()
		NextScavengerDay = new float[1]
		NextScavengerDay.Clear()
		SeenTick = new int[1]
		SeenTick.Clear()
	endif
	if Scavengers == None
		Scavengers = new ObjectReference[1]
		Scavengers.Clear()
	endif
	RegisterForRemoteEvent(Game.GetPlayer(), "OnPlayerLoadGame")
	StartTimer(SCAN_INTERVAL, TIMER_SCAN)
	Log("started, tracking " + Bodies.Length + " corpses")
	Say("Corpse Decay is running (" + Bodies.Length + " bodies)")
EndFunction

Event OnTimer(int aiTimerID)
	if aiTimerID == TIMER_SCAN
		if CD_Enabled.GetValueInt() != 0
			Scan()
		endif
		StartTimer(SCAN_INTERVAL, TIMER_SCAN)
	endif
EndEvent

; ================================================================ finding bodies
Event Actor.OnDeath(Actor akSender, Actor akKiller)
	UnregisterForRemoteEvent(akSender, "OnDeath")
	Track(akSender, Utility.GetCurrentGameTime())
EndEvent

Function Scan()
	Actor player = Game.GetPlayer()
	float now = Utility.GetCurrentGameTime()
	Tick += 1
	bool includeOld = CD_IncludeOldCorpses.GetValueInt() != 0

	ObjectReference[] found = player.FindAllReferencesWithKeyword(CD_ActorTypes, SCAN_RADIUS)
	int i = 0
	while i < found.Length
		Actor a = found[i] as Actor
		if a != None && a != player && !a.HasKeyword(ActorTypeRobot)
			if a.IsDead()
				int idx = Bodies.Find(a)
				if idx < 0 && includeOld
					idx = Track(a, now)
				endif
				if idx >= 0
					UpdateBody(idx, now, player)
				endif
			elseif !a.IsPlayerTeammate()
				; get told when this one dies, so we know the exact time of death
				RegisterForRemoteEvent(a, "OnDeath")
			endif
		endif
		i += 1
	endwhile

	; every ~30 seconds: age bodies that are not loaded, drop finished ones, tidy scavengers
	if Tick % 8 == 0
		Maintain(now, player)
	endif
EndFunction

int Function Track(Actor a, float now)
	if a == None || a.IsChild() || a.HasKeyword(ActorTypeRobot)
		return -1
	endif
	int idx = Bodies.Find(a)
	if idx >= 0
		return idx
	endif
	if Bodies.Length >= MAX_TRACKED
		Release(Oldest(), true)
	endif
	Bodies.Add(a)
	DeathDay.Add(now)
	Stage.Add(STAGE_FRESH)
	Remains.Add(None)
	Flies.Add(None)
	NextScavengerDay.Add(now + Utility.RandomFloat(0.2, 0.6))
	SeenTick.Add(-10)
	Log("tracking " + a + " (" + Bodies.Length + " total)")
	Say("Corpse Decay: body noted (" + Bodies.Length + ")")
	return Bodies.Length - 1
EndFunction

int Function Oldest()
	int best = 0
	int i = 1
	while i < Bodies.Length
		if DeathDay[i] < DeathDay[best]
			best = i
		endif
		i += 1
	endwhile
	return best
EndFunction

; ================================================================ stages
float Function HoursDead(int idx, float now)
	float scale = CD_TimeScale.GetValue()
	if scale <= 0.0
		scale = 1.0
	endif
	return (now - DeathDay[idx]) * 24.0 * scale
EndFunction

int Function StageFor(float hours)
	if hours >= CD_HoursCleanup.GetValue()
		return STAGE_GONE
	elseif hours >= CD_HoursBones.GetValue()
		return STAGE_BONES
	elseif hours >= CD_HoursRemains.GetValue()
		return STAGE_REMAINS
	elseif hours >= CD_HoursRot.GetValue()
		return STAGE_ROT
	elseif hours >= CD_HoursPale.GetValue()
		return STAGE_PALE
	elseif hours >= CD_HoursFlies.GetValue()
		return STAGE_FLIES
	endif
	return STAGE_FRESH
EndFunction

bool Function IsHumanoid(Actor a)
	return a.HasKeyword(ActorTypeHuman) || a.HasKeyword(ActorTypeGhoul) || a.HasKeyword(ActorTypeFeralGhoul) || a.HasKeyword(ActorTypeSuperMutant)
EndFunction

bool Function IsUnique(Actor a)
	ActorBase b = a.GetLeveledActorBase()
	return b != None && b.IsUnique()
EndFunction

; Called for a tracked body that is loaded near the player.
Function UpdateBody(int idx, float now, Actor player)
	Actor a = Bodies[idx]
	if a == None || a.IsDeleted() || !a.IsDead()
		; deleted, or the cell reset and the actor came back alive
		Release(idx, true)
		return
	endif

	int want = StageFor(HoursDead(idx, now))
	bool unique = IsUnique(a)
	if unique && want > STAGE_ROT
		; named characters keep their body, so quests that need it keep working
		want = STAGE_ROT
	endif
	bool reapply = SeenTick[idx] < Tick - 1
	SeenTick[idx] = Tick

	if want >= STAGE_REMAINS && Stage[idx] < STAGE_REMAINS && a.GetDistance(player) < 900.0
		; don't swap the body for bones right in front of the player
		want = STAGE_ROT
	endif

	if want != Stage[idx] || reapply
		ApplyStage(idx, a, want)
	endif

	if want >= STAGE_FLIES && want <= STAGE_REMAINS
		TryScavengers(idx, a, now, player)
	endif
EndFunction

Function ApplyStage(int idx, Actor a, int want)
	if want == STAGE_GONE
		Log("clean up " + a)
		Release(idx, true)
		return
	endif

	; ---- the body itself (stages up to rot)
	if want <= STAGE_ROT
		CD_PaleFXS.Stop(a)
		CD_RotFXS.Stop(a)
		if want == STAGE_PALE
			CD_PaleFXS.Play(a, -1.0)
		elseif want == STAGE_ROT
			CD_RotFXS.Play(a, -1.0)
		endif
	endif

	; ---- flies from the first stage until only bones are left
	if want >= STAGE_FLIES && want < STAGE_BONES
		if Flies[idx] == None
			ObjectReference f = a.PlaceAtMe(CD_Flies, 1, false, false, false)
			f.MoveTo(a, 0.0, 0.0, 30.0, false)
			Flies[idx] = f
		endif
	else
		DeleteRef(Flies[idx])
		Flies[idx] = None
	endif

	; ---- remains and bones
	if want >= STAGE_REMAINS
		if IsHumanoid(a)
			Container base = CD_RemainsFlesh
			if want >= STAGE_BONES
				base = CD_RemainsBones
			endif
			ObjectReference old = Remains[idx]
			if old == None || old.GetBaseObject() != base
				ObjectReference r = a.PlaceAtMe(base, 1, false, false, false)
				r.SetAngle(0.0, 0.0, a.GetAngleZ())
				if a.HasKeyword(ActorTypeSuperMutant)
					r.SetScale(1.3)
				endif
				if old != None
					old.RemoveAllItems(r)
					DeleteRef(old)
				else
					a.RemoveAllItems(r)
				endif
				Remains[idx] = r
				Log(a + " -> " + base)
			endif
		endif
		if !a.IsDisabled()
			CD_PaleFXS.Stop(a)
			CD_RotFXS.Stop(a)
			a.Disable()
		endif
	endif

	if want != Stage[idx]
		Say("Corpse Decay: stage " + want)
	endif
	Stage[idx] = want
EndFunction

; ================================================================ scavengers
Function TryScavengers(int idx, Actor a, float now, Actor player)
	if now < NextScavengerDay[idx]
		return
	endif
	NextScavengerDay[idx] = now + 1.0 / ScaleOrOne()
	float dist = a.GetDistance(player)
	if dist < 2500.0
		return
	endif
	if Scavengers.Length >= MAX_SCAVENGERS
		return
	endif
	if Utility.RandomInt(1, 100) > CD_ScavengerChance.GetValueInt()
		return
	endif

	FormList pool = CD_ScavengersExterior
	Cell c = a.GetParentCell()
	if c != None && c.IsInterior()
		pool = CD_ScavengersInterior
	endif
	if pool.GetSize() <= 0
		return
	endif
	Form what = pool.GetAt(Utility.RandomInt(0, pool.GetSize() - 1))
	int count = Utility.RandomInt(1, 3)
	ObjectReference anchor = a
	if Remains[idx] != None
		anchor = Remains[idx]
	endif
	int n = 0
	while n < count && Scavengers.Length < MAX_SCAVENGERS
		ObjectReference s = anchor.PlaceAtMe(what, 1, false, false, true)
		if s != None
			s.MoveTo(anchor, Utility.RandomFloat(-200.0, 200.0), Utility.RandomFloat(-200.0, 200.0), 10.0, false)
			Scavengers.Add(s)
		endif
		n += 1
	endwhile
	Log("scavengers " + what + " x" + count + " at " + a)
EndFunction

float Function ScaleOrOne()
	float scale = CD_TimeScale.GetValue()
	if scale <= 0.0
		return 1.0
	endif
	return scale
EndFunction

; ================================================================ upkeep
Function Maintain(float now, Actor player)
	; bodies far away still age; finished ones are released even if never seen again
	int i = Bodies.Length - 1
	while i >= 0
		Actor a = Bodies[i]
		if a == None || a.IsDeleted()
			Release(i, true)
		elseif StageFor(HoursDead(i, now)) == STAGE_GONE && !a.Is3DLoaded()
			Release(i, true)
		endif
		i -= 1
	endwhile

	; scavengers: drop the ones that died or that the player left behind
	i = Scavengers.Length - 1
	while i >= 0
		ObjectReference s = Scavengers[i]
		Actor sa = s as Actor
		if s == None || s.IsDeleted()
			Scavengers.Remove(i)
		elseif !s.Is3DLoaded() || (sa != None && sa.IsDead())
			if !s.Is3DLoaded()
				DeleteRef(s)
			endif
			Scavengers.Remove(i)
		endif
		i -= 1
	endwhile
EndFunction

; Forget a body. With cleanup, also remove its flies and remains.
Function Release(int idx, bool cleanup)
	if idx < 0 || idx >= Bodies.Length
		return
	endif
	DeleteRef(Flies[idx])
	if cleanup
		DeleteRef(Remains[idx])
	endif
	Actor a = Bodies[idx]
	if a != None && !a.IsDeleted()
		CD_PaleFXS.Stop(a)
		CD_RotFXS.Stop(a)
	endif
	Bodies.Remove(idx)
	DeathDay.Remove(idx)
	Stage.Remove(idx)
	Remains.Remove(idx)
	Flies.Remove(idx)
	NextScavengerDay.Remove(idx)
	SeenTick.Remove(idx)
EndFunction

Function DeleteRef(ObjectReference r)
	if r != None && !r.IsDeleted()
		r.Disable()
		r.Delete()
	endif
EndFunction

; On-screen message, only in debug mode (works in VR too, no console needed)
Function Say(string msg)
	if CD_Debug.GetValueInt() != 0
		Debug.Notification(msg)
	endif
EndFunction

Function Log(string msg)
	if CD_Debug.GetValueInt() != 0
		Debug.Trace("[CorpseDecay] " + msg)
	endif
EndFunction
