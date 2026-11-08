Scriptname Actor extends ObjectReference Native
bool Function IsDead() native
bool Function IsEssential() native
bool Function IsChild() native
bool Function IsPlayerTeammate() native
ActorBase Function GetLeveledActorBase() native
Event OnDeath(Actor akKiller)
EndEvent
Event OnPlayerLoadGame()
EndEvent
Event OnKill(Actor akVictim)
EndEvent
