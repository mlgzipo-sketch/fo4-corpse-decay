Scriptname ObjectReference extends Form Native
Function Delete() native
Function Disable(bool abFadeOut = false) native
Function DisableNoWait(bool abFadeOut = false) native
Function Enable(bool abFadeIn = false) native
Form Function GetBaseObject() native
float Function GetDistance(ObjectReference akOther) native
Cell Function GetParentCell() native
float Function GetAngleZ() native
bool Function Is3DLoaded() native
bool Function IsDeleted() native
bool Function IsDisabled() native
Function MoveTo(ObjectReference akTarget, float afXOffset = 0.0, float afYOffset = 0.0, float afZOffset = 0.0, bool abMatchRotation = true) native
ObjectReference Function PlaceAtMe(Form akFormToPlace, int aiCount = 1, bool abForcePersist = false, bool abInitiallyDisabled = false, bool abDeleteWhenAble = true) native
Function RemoveAllItems(ObjectReference akTransferTo = None, bool abKeepOwnership = false) native
Function SetAngle(float afXAngle, float afYAngle, float afZAngle) native
Function SetScale(float afScale) native
ObjectReference[] Function FindAllReferencesWithKeyword(Form akKeywordOrList, float afRadius) native
