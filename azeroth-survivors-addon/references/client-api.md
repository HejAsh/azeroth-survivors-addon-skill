# The client's addon API

Everything an addon can reach in Azeroth Survivors. This is the surface
itself; `references/api.md` documents the run tables (`AZS_*`) in detail.

## The surface

What a 1.12 addon can actually reach in this client:

| | count |
|---|---|
| API globals (functions, plus strings, numbers and tables they expose) | 1128 |
| bound global functions | 1153 |
| widget methods across 24 templates | 2305 |
| events | 394 |
| CVars | 381 |
| chat message types | 465 |

A further 20427 names come from stock FrameXML. They are real, but they are the
game's own UI internals, not API to depend on.

**A name being listed does not promise the feature works.** This is a partial
1.12 implementation: where a name is absent it is simply `nil`, so feature-detect
before you call it. The missing names are listed under Globals.

## Writing an addon

Drop a folder in `benilla-config/AddOns/<Name>/` beside the executable; it
loads on the next world entry. Browser builds: Options -> AddOns -> install a
`.zip`. Saved variables are written on logout.

### TOC directives

The reader tests these literals in order and the first match claims the line;
**any other directive is silently dropped** — there is no `## Dependencies:`,
it is `## Dep:`, and `## LoadWith:` is its own directive, not a synonym.

```
## Interface: 11200          version gate; may list several: 11507, 11508
## Title: My Addon           metadata
## Notes: ...                metadata
## Author: ...               metadata
## Version: 1.0              metadata
## X-Anything: value         metadata (the X- prefix is the literal)
## Revision: 12345           stored as a number
## OptionalDep: Other        load order hint
## RequiredDep: Other
## Dep: Other                same list as RequiredDep
## LoadWith: Other
## SavedVariables: MyDB      account-wide file
## SavedVariablesPerCharacter: MyDB   loaded after the account file, so it wins
## DefaultState: disabled    enabled unless this says disabled
## LoadOnDemand: 1
## Secure: 1
```

Anything else on a `#` line is a comment; any other line is a file to load.
`## Interface:` takes a comma-separated list (`11200` or `11507, 11508`) and is
compared as numbers; the first is what the version gate compares.

### Saved variables

`## SavedVariables:` globals come from the account-wide file,
`## SavedVariablesPerCharacter:` from the per-character one, loaded **after**
so its values win. A frame position you save is in that frame's own scale
units — clamp or convert after a UI-scale change or it lands off-screen.

## Lua core

A Lua 5.0-era 1.12.1 VM. `table.getn`/`setn` are the length ops (there is no
`#`), `math.mod` is `fmod`, and a family of bare aliases is installed:

```
strlen strsub strupper strlower strrep strfind strbyte strchar gsub
tinsert tremove getn format
ceil floor abs max min sqrt mod random randomseed PI
sin cos tan asin acos atan atan2 rad deg exp log log10 frexp ldexp   (degrees)
getglobal setglobal
```

Deliberately **absent** — they are 2.0+ or 5.1, and an addon that reaches for
one gets `nil`:

```
strsplit strjoin strconcat strtrim wipe tostringall tContains
strmatch gmatch strrev securecall hooksecurefunc issecure issecurevariable hook
CopyTable Mixin table.pack table.unpack table.move
```

The `#` length operator and `goto` are also 5.1+/5.2+. Lua 5.0's parser
rejects `...` in a call's argument list, which is not obvious and fails at load.
Feature-detect anything you are unsure of (`if (GetActionCooldown) then ...`).

### Stubs

`debuginfo`, `debugload`, `debugprint`, `debugdump`, `debugbreak` and
`debugtimestamp` exist and do **nothing** — they are the reference client's own
no-ops. `debugprofilestart`/`debugprofilestop` are real. A call that returns
zero without side effects is not a working API.

## The run API

The game fills these before any addon loads and keeps them current; see
`references/api.md` for every field.

```
AZS_GetRunTime() AZS_GetPhase() AZS_GetRunLength() AZS_GetBosses()
AZS_GetUpcomingBosses() AZS_GetGuardians() AZS_GetMeter() AZS_UnitKind(unit)
AZS_SetHudShown(part, shown) AZS_IsHudShown(part)
```

Tables: `AZS_ZONE` `AZS_RUN` `AZS_SCHEDULE` `AZS_UNITS` `AZS_TARGET`
`AZS_SPELLS` `AZS_BUFFS` `AZS_METER` `AZS_TAKEN` `AZS_STATS`, each with a
matching `<name>_UPDATED` holding the `GetTime()` of its last change.

They arrive as `CHAT_MSG_ADDON` lines; the prefixes are
`AZSZONE` `AZSRUN` `AZSBOSSES` `AZSUNITS` `AZSTGT` `AZSSPELLS` `AZSBUFFS`
`AZSMETER` `AZSTAKEN`, plus `AZS` for the stats line. The game's own parser
registers before any addon, so the tables are already updated when your
handler runs.

```lua
local f = CreateFrame("Frame");
f:RegisterEvent("CHAT_MSG_ADDON");
f:SetScript("OnEvent", function()
    if (arg1 == "AZSMETER") then
        -- AZS_METER already holds the new list; arg2 is the raw line
    end
end);
```

**There is no gear feed.** `AZS_STATS.g*` are per-stat totals for the whole
worn set; nothing tells an addon which items you hold.

## Addon management verbs

All eight take an index or a name, and a bad index raises:

```
GetAddOnInfo  GetAddOnMetadata  GetAddOnDependencies  EnableAddOn  DisableAddOn
IsAddOnLoadOnDemand  IsAddOnLoaded  LoadAddOn
```

`LoadAddOn` and `IsAddOnLoaded` exist, so a `libs/`-style layout can load —
but see the note on libraries below before relying on it.

**Libraries: Ace2/Ace3 cannot run.** `strsplit`, `strtrim`, `wipe`,
`securecall`, `hooksecurefunc`, `CopyTable` and `Mixin` are all absent, on
this client and a real 1.12 — Ace targets 2.4/3.3.5. Use a small in-file
shim, the way that era's own libraries (Titan, IcedT) were single-file
drop-ins.

## Globals

1128 names are the client's own API. The other 20427 are FrameXML — real, but stock
UI internals; feature-detect before depending on them.


Of the 1128 API globals, **1074 are present** in the running VM and 53 are not.

(`this`, `event` and `arg1`-`arg10` are excluded from the count: they are
handler locals, set only while an event fires, so a top-level dump of
`_G` cannot see them.)

Missing — these resolve to `nil`, so do not call them:

```
AcceptSkillUps AddSkillUp AppendToFile BuyRandomPicks BuySkillTier CloseLottery DeleteFile
GMRequestPlayerInfo GMSurveyAnswerSubmit GMSurveyCommentSubmit GMSurveyQuestion GMSurveySubmit
GetActiveLevel GetAvailableLevel GetCraftSkillLine GetJackpotAmount GetLFGResults
GetLFGTypeEntries GetLFGTypes GetLastLotteryNumbers GetLotteryPrizeInfo GetMinigameState
GetMinigameType GetMoneyPrizes GetNextDrawTime GetNumLFGResults GetNumLotteryPrizes
GetNumPastDrawResults GetPastDrawResult GetTradeSkillItemStats GetTrainerServiceStepIncrease
GetTrainerSkillLineFilter GetTrainerSkillLines IsTrainerServiceSkillStep IsVendorActive
LFGQuery MakeMinigameMove OpenTrainer ReadFile RemoveSkillUp ReplaceTradeEnchant
ResetPerformanceValues SetTrainerSkillLineFilter SubmitNumbers ToggleCollision
ToggleCollisionDisplay TogglePerformanceDisplay TogglePerformanceValues TogglePlayerBounds
TogglePortals ToggleTris UnitCanAssist UnitIsTrivial
```

### API globals

```
AbandonQuest AbandonSkill AcceptAreaSpiritHeal AcceptBattlefieldPort AcceptDuel AcceptGroup
AcceptGuild AcceptQuest AcceptResurrect AcceptSkillUps AcceptTrade AcceptXPLoss ActionHasRange
AddChatWindowChannel AddChatWindowMessages AddFriend AddIgnore AddOrDelIgnore AddQuestWatch
AddSkillUp AddTradeMoney AppendToFile AssistByName AssistUnit AttackTarget AutoEquipCursorItem
BankButtonIDToInvSlotID BeginTrade BindEnchant BuyGuildCharter BuyMerchantItem BuyRandomPicks
BuySkillTier BuyStableSlot BuyTrainerService BuybackItem CalculateAuctionDeposit
CameraOrSelectOrMoveStart CameraOrSelectOrMoveStop CameraZoomIn CameraZoomOut CanEditGuildInfo
CanEditMOTD CanEditOfficerNote CanEditPublicNote CanGuildDemote CanGuildInvite CanGuildPromote
CanGuildRemove CanInspect CanJoinBattlefieldAsGroup CanMerchantRepair CanSendAuctionQuery
CanShowResetInstances CanSignPetition CanViewOfficerNote CancelAreaSpiritHeal CancelAuction
CancelDuel CancelLogout CancelMeetingStoneRequest CancelPendingEquip CancelPlayerBuff
CancelSkillUps CancelTrackingBuff CancelTrade CancelTradeAccept CastPetAction
CastShapeshiftForm CastSpell CastSpellByName ChangeActionBarPage ChangeChatColor ChannelBan
ChannelInvite ChannelKick ChannelModerate ChannelModerator ChannelMute
ChannelToggleAnnouncements ChannelUnban ChannelUnmoderator ChannelUnmute CheckBinderDist
CheckInbox CheckInteractDistance CheckPetUntrainerDist CheckReadyCheckTime
CheckSpiritHealerDist CheckTalentMasterDist ClearCursor ClearInspectPlayer ClearSendMail
ClearTarget ClearTutorials ClickAuctionSellItemButton ClickSendMailItemButton ClickStablePet
ClickTargetTradeButton ClickTradeButton CloseAuctionHouse CloseBankFrame CloseBattlefield
CloseCraft CloseGossip CloseGuildRegistrar CloseGuildRoster CloseItemText CloseLoot
CloseLottery CloseMail CloseMerchant ClosePetStables ClosePetition CloseQuest
CloseTabardCreation CloseTaxiMap CloseTrade CloseTradeSkill CloseTrainer CollapseCraftSkillLine
CollapseFactionHeader CollapseQuestHeader CollapseSkillHeader CollapseTradeSkillSubClass
CollapseTrainerSkillLine CompleteQuest ConfirmAcceptQuest ConfirmBindOnUse ConfirmBinder
ConfirmLootRoll ConfirmPetUnlearn ConfirmReadyCheck ConfirmSummon ConfirmTalentWipe ConsoleExec
ContainerIDToInventoryID ConvertToRaid CreateFont CreateFrame CreateMacro
CreateMiniWorldMapArrowFrame CreateWorldMapArrowFrame CursorCanGoInSlot CursorHasItem
CursorHasMoney CursorHasSpell DeclineGroup DeclineGuild DeclineQuest DeclineResurrect DelIgnore
DeleteCursorItem DeleteFile DeleteGMTicket DeleteInboxItem DeleteMacro DemoteAssistant
DisableAddOn DisableAllAddOns DisplayChannelOwner DoCraft DoEmote DoReadyCheck DoTradeSkill
DropCursorMoney DropItemOnUnit EditMacro EnableAddOn EnableAllAddOns EnumerateFrames
EnumerateServerChannels EquipCursorItem EquipPendingItem ExpandCraftSkillLine
ExpandFactionHeader ExpandQuestHeader ExpandSkillHeader ExpandTradeSkillSubClass
ExpandTrainerSkillLine FactionToggleAtWar FlagTutorial FlipCameraYaw FollowByName FollowUnit
ForceLogout ForceQuit FrameXML_Debug GMRequestPlayerInfo GMSurveyAnswerSubmit
GMSurveyCommentSubmit GMSurveyQuestion GMSurveySubmit GetAbandonQuestItems GetAbandonQuestName
GetActionAutocast GetActionBarToggles GetActionCooldown GetActionCount GetActionText
GetActionTexture GetActiveLevel GetActiveTitle GetAddOnDependencies GetAddOnInfo
GetAddOnMetadata GetAdjustedSkillPoints GetAreaSpiritHealerTime GetAuctionHouseDepositRate
GetAuctionInvTypes GetAuctionItemClasses GetAuctionItemInfo GetAuctionItemLink
GetAuctionItemSubClasses GetAuctionItemTimeLeft GetAuctionSellItemInfo GetAvailableLevel
GetAvailableTitle GetBagName GetBankSlotCost GetBaseMip GetBattlefieldEstimatedWaitTime
GetBattlefieldFlagPosition GetBattlefieldInfo GetBattlefieldInstanceExpiration
GetBattlefieldInstanceInfo GetBattlefieldInstanceRunTime GetBattlefieldMapIconScale
GetBattlefieldPortExpiration GetBattlefieldPosition GetBattlefieldScore GetBattlefieldStatData
GetBattlefieldStatInfo GetBattlefieldStatus GetBattlefieldTimeWaited GetBattlefieldWinner
GetBidderAuctionItems GetBillingTimeRested GetBindLocation GetBinding GetBindingAction
GetBindingKey GetBlockChance GetBonusBarOffset GetBuildInfo GetBuybackItemInfo GetCVar
GetCVarDefault GetChannelList GetChannelName GetChatTypeIndex GetChatWindowChannels
GetChatWindowInfo GetChatWindowMessages GetCoinIcon GetComboPoints GetContainerItemCooldown
GetContainerItemInfo GetContainerItemLink GetContainerNumSlots GetCorpseMapPosition
GetCorpseRecoveryDelay GetCraftButtonToken GetCraftDescription GetCraftDisplaySkillLine
GetCraftIcon GetCraftInfo GetCraftItemLink GetCraftName GetCraftNumReagents GetCraftReagentInfo
GetCraftReagentItemLink GetCraftSelectionIndex GetCraftSkillLine GetCraftSpellFocus
GetCurrentBindingSet GetCurrentMapContinent GetCurrentMapZone GetCurrentMultisampleFormat
GetCurrentResolution GetCursorMoney GetCursorPosition GetDamageBonusStat GetDebugStats
GetDefaultLanguage GetDodgeChance GetDoodadAnim GetFactionInfo GetFarclip GetFirstTradeSkill
GetFramerate GetFriendInfo GetGMStatus GetGMTicket GetGMTicketCategories GetGameTime GetGamma
GetGossipActiveQuests GetGossipAvailableQuests GetGossipOptions GetGossipText GetGreetingText
GetGuildCharterCost GetGuildInfo GetGuildInfoText GetGuildRecruitmentMode GetGuildRosterInfo
GetGuildRosterLastOnline GetGuildRosterMOTD GetGuildRosterSelection GetGuildRosterShowOffline
GetIgnoreName GetInboxHeaderInfo GetInboxInvoiceInfo GetInboxItem GetInboxNumItems GetInboxText
GetInspectHonorData GetInspectPVPRankProgress GetInstanceBootTimeRemaining
GetInventoryAlertStatus GetInventoryItemBroken GetInventoryItemCooldown GetInventoryItemCount
GetInventoryItemLink GetInventoryItemQuality GetInventoryItemTexture GetInventorySlotInfo
GetItemInfo GetItemQualityColor GetJackpotAmount GetLFGResults GetLFGTypeEntries GetLFGTypes
GetLanguageByIndex GetLastLotteryNumbers GetLocale GetLookingForGroup GetLootMethod
GetLootRollItemInfo GetLootRollItemLink GetLootRollTimeLeft GetLootSlotInfo GetLootSlotLink
GetLootThreshold GetLotteryPrizeInfo GetMacroIconInfo GetMacroIndexByName GetMacroInfo
GetMapContinents GetMapInfo GetMapLandmarkInfo GetMapOverlayInfo GetMapZones
GetMasterLootCandidate GetMeetingStoneStatusText GetMerchantItemInfo GetMerchantItemLink
GetMerchantItemMaxStack GetMerchantNumItems GetMinigameState GetMinigameType GetMinimapZoneText
GetMoney GetMoneyPrizes GetMouseFocus GetMultisampleFormats GetNetStats GetNextDrawTime
GetNextStableSlotCost GetNumActiveQuests GetNumAddOns GetNumAuctionItems GetNumAvailableQuests
GetNumBankSlots GetNumBattlefieldFlagPositions GetNumBattlefieldPositions
GetNumBattlefieldScores GetNumBattlefieldStats GetNumBattlefields GetNumBindings
GetNumBuybackItems GetNumCrafts GetNumFactions GetNumFrames GetNumFriends GetNumGuildMembers
GetNumIgnores GetNumLFGResults GetNumLaguages GetNumLootItems GetNumLotteryPrizes
GetNumMacroIcons GetNumMacros GetNumMapLandmarks GetNumMapOverlays GetNumPackages
GetNumPartyMembers GetNumPastDrawResults GetNumPetitionNames GetNumQuestChoices
GetNumQuestItems GetNumQuestLeaderBoards GetNumQuestLogChoices GetNumQuestLogEntries
GetNumQuestLogRewards GetNumQuestRewards GetNumQuestWatches GetNumRaidMembers GetNumRoutes
GetNumSavedInstances GetNumShapeshiftForms GetNumSkillLines GetNumSpellTabs GetNumStablePets
GetNumStableSlots GetNumStationeries GetNumTalentTabs GetNumTalents GetNumTradeSkills
GetNumTrainerServices GetNumWhoResults GetNumWorldStateUI GetObjectiveText GetOwnerAuctionItems
GetPVPLastWeekStats GetPVPLifetimeStats GetPVPRankInfo GetPVPRankProgress GetPVPSessionStats
GetPVPThisWeekStats GetPVPYesterdayStats GetPackageInfo GetParryChance GetPartyLeaderIndex
GetPartyMember GetPastDrawResult GetPetActionCooldown GetPetActionInfo GetPetActionsUsable
GetPetExperience GetPetFoodTypes GetPetHappiness GetPetIcon GetPetLoyalty GetPetTimeRemaining
GetPetTrainingPoints GetPetitionInfo GetPetitionNameInfo GetPlayerBuff
GetPlayerBuffApplications GetPlayerBuffDispelType GetPlayerBuffTexture GetPlayerBuffTimeLeft
GetPlayerMapPosition GetPlayerTradeMoney GetProgressText GetQuestBackgroundMaterial
GetQuestGreenRange GetQuestIndexForTimer GetQuestIndexForWatch GetQuestItemInfo
GetQuestItemLink GetQuestLogChoiceInfo GetQuestLogItemLink GetQuestLogLeaderBoard
GetQuestLogPushable GetQuestLogQuestText GetQuestLogRequiredMoney GetQuestLogRewardInfo
GetQuestLogRewardMoney GetQuestLogRewardSpell GetQuestLogSelection GetQuestLogTimeLeft
GetQuestLogTitle GetQuestMoneyToGet GetQuestReward GetQuestText GetQuestTimers
GetRaidRosterInfo GetRaidRosterSelection GetRaidTargetIndex GetRealZoneText GetRealmName
GetRefreshRates GetReleaseTimeRemaining GetRepairAllCost GetResSicknessDuration GetRestState
GetRewardMoney GetRewardSpell GetRewardText GetSavedInstanceInfo GetScreenHeight
GetScreenResolutions GetScreenWidth GetSelectedAuctionItem GetSelectedBattlefield
GetSelectedFaction GetSelectedFriend GetSelectedIgnore GetSelectedSkill GetSelectedStablePet
GetSelectedStationeryTexture GetSendMailCOD GetSendMailItem GetSendMailMoney GetSendMailPrice
GetShapeshiftFormCooldown GetShapeshiftFormInfo GetSkillLineInfo GetSpellAutocast
GetSpellCooldown GetSpellName GetSpellTabInfo GetSpellTexture GetStablePetFoodTypes
GetStablePetInfo GetStationeryInfo GetSubZoneText GetSummonConfirmAreaName
GetSummonConfirmSummoner GetSummonConfirmTimeLeft GetTabardCreationCost GetTabardInfo
GetTalentInfo GetTalentPrereqs GetTalentTabInfo GetTargetTradeMoney GetTerrainMip GetTexLodBias
GetTime GetTimeToWellRested GetTitleText GetTrackingTexture GetTradePlayerItemInfo
GetTradePlayerItemLink GetTradeSkillCooldown GetTradeSkillIcon GetTradeSkillInfo
GetTradeSkillInvSlotFilter GetTradeSkillInvSlots GetTradeSkillItemLink GetTradeSkillItemStats
GetTradeSkillLine GetTradeSkillNumMade GetTradeSkillNumReagents GetTradeSkillReagentInfo
GetTradeSkillReagentItemLink GetTradeSkillSelectionIndex GetTradeSkillSubClassFilter
GetTradeSkillSubClasses GetTradeSkillTools GetTradeTargetItemInfo GetTradeTargetItemLink
GetTradeskillRepeatCount GetTrainerGreetingText GetTrainerSelectionIndex
GetTrainerServiceAbilityReq GetTrainerServiceCost GetTrainerServiceDescription
GetTrainerServiceIcon GetTrainerServiceInfo GetTrainerServiceLevelReq
GetTrainerServiceNumAbilityReq GetTrainerServiceSkillLine GetTrainerServiceSkillReq
GetTrainerServiceStepIncrease GetTrainerServiceStepReq GetTrainerServiceTypeFilter
GetTrainerSkillLineFilter GetTrainerSkillLines GetVideoCaps GetWatchedFactionInfo
GetWaterDetail GetWeaponEnchantInfo GetWhoInfo GetWorldDetail GetWorldLocMapPosition
GetWorldStateUIInfo GetXPExhaustion GetZonePVPInfo GetZoneText GiveMasterLoot
GuildControlAddRank GuildControlDelRank GuildControlGetNumRanks GuildControlGetRankFlags
GuildControlGetRankName GuildControlSaveRank GuildControlSetRank GuildControlSetRankFlag
GuildDemoteByName GuildDisband GuildInfo GuildInviteByName GuildLeave GuildPromoteByName
GuildRoster GuildRosterSetOfficerNote GuildRosterSetPublicNote GuildSetLeaderByName
GuildSetMOTD GuildUninviteByName HasAction HasFullControl HasInspectHonorData HasKey HasNewMail
HasPetSpells HasPetUI HasSoulstone HasWandEquipped HideFriendNameplates HideNameplates
HideRepairCursor InCinematic InRepairMode InboxItemCanDelete InitiateTrade InviteByName
InviteToParty IsActionInRange IsAddOnLoadOnDemand IsAddOnLoaded IsAltKeyDown IsAttackAction
IsAuctionSortReversed IsAutoRepeatAction IsConsumableAction IsControlKeyDown IsCurrentAction
IsCurrentCast IsCurrentQuestFailed IsEquippedAction IsFactionInactive IsFishingLoot
IsGuildLeader IsInGuild IsInInstance IsInMeetingStoneQueue IsInventoryItemLocked IsLinuxClient
IsMacClient IsMouselooking IsPartyLeader IsPetAttackActive IsQuestCompletable IsQuestWatched
IsRaidLeader IsRaidOfficer IsResting IsShiftKeyDown IsSpellPassive IsTalentTrainer
IsTradeskillTrainer IsTrainerServiceLearnSpell IsTrainerServiceSkillStep
IsTrainerServiceTradeSkill IsUnitOnQuest IsUsableAction IsVendorActive IsWindowsClient
ItemTextGetCreator ItemTextGetItem ItemTextGetMaterial ItemTextGetPage ItemTextGetText
ItemTextHasNextPage ItemTextNextPage ItemTextPrevPage JoinBattlefield JoinChannelByName Jump
KeyRingButtonIDToInvSlotID LFGQuery LearnTalent LeaveBattlefield LeaveChannelByName LeaveParty
ListChannelByName ListChannels LoadAddOn LoadBindings LoggingChat LoggingCombat Logout LootSlot
LootSlotIsCoin LootSlotIsItem MakeMinigameMove MouselookStart MouselookStop MoveBackwardStart
MoveBackwardStop MoveForwardStart MoveForwardStop MoveViewDownStart MoveViewDownStop
MoveViewInStart MoveViewInStop MoveViewLeftStart MoveViewLeftStop MoveViewOutStart
MoveViewOutStop MoveViewRightStart MoveViewRightStop MoveViewUpStart MoveViewUpStop NewGMTicket
NextView NoPlayTime NotWhileDeadError NotifyInspect NumTaxiNodes OfferPetition OffhandHasWeapon
OpenTrainer OpeningCinematic PI PartialPlayTime PetAbandon PetAggressiveMode PetAttack
PetCanBeAbandoned PetCanBeRenamed PetDefensiveMode PetDismiss PetFollow PetHasActionBar
PetPassiveMode PetRename PetStopAttack PetWait PickupAction PickupBagFromSlot
PickupContainerItem PickupInventoryItem PickupMacro PickupMerchantItem PickupPetAction
PickupPlayerMoney PickupSpell PickupStablePet PickupTradeMoney PitchDownStart PitchDownStop
PitchUpStart PitchUpStop PlaceAction PlaceAuctionBid PlayMusic PlaySound PlaySoundFile
PlayerHasSpells PositionMiniWorldMapArrowFrame PositionWorldMapArrowFrame PrevView
ProcessMapClick PromoteByName PromoteToAssistant PromoteToPartyLeader PurchaseSlot
PutItemInBackpack PutItemInBag QueryAuctionItems QuestChooseRewardError QuestLogPushQuest Quit
RandomRoll ReadFile RegisterCVar RegisterForSave ReloadUI RemoveChatWindowChannel
RemoveChatWindowMessages RemoveFriend RemoveQuestWatch RemoveSkillUp RenamePetition
RepairAllItems ReplaceEnchant ReplaceTradeEnchant RepopMe RequestBattlefieldPositions
RequestBattlefieldScoreData RequestInspectHonorData RequestRaidInfo RequestTimePlayed
ResetChatColors ResetCursor ResetDisabledAddOns ResetInstances ResetPerformanceValues
ResetTutorials ResetView RestartGx RestoreVideoDefaults ResurrectHasSickness ResurrectHasTimer
RetrieveCorpse ReturnInboxItem RollOnLoot RunBinding RunScript SaveBindings SaveView Screenshot
SelectActiveQuest SelectAvailableQuest SelectCraft SelectGossipActiveQuest
SelectGossipAvailableQuest SelectGossipOption SelectPackage SelectQuestLogEntry
SelectStationery SelectTradeSkill SelectTrainerService SendAddonMessage SendChatMessage
SendMail SendWho SetAbandonQuest SetActionBarToggles SetBagPortaitTexture SetBaseMip
SetBattlefieldScoreFaction SetBinding SetCVar SetChannelOwner SetChannelPassword
SetChatWindowAlpha SetChatWindowColor SetChatWindowDocked SetChatWindowLocked SetChatWindowName
SetChatWindowShown SetChatWindowSize SetConsoleKey SetCursor SetDoodadAnim SetEuropeanNumbers
SetFactionActive SetFactionInactive SetFarclip SetGamma SetGuildInfoText
SetGuildRecruitmentMode SetGuildRosterSelection SetGuildRosterShowOffline
SetInventoryPortaitTexture SetLayoutMode SetLookingForGroup SetLootMethod SetLootPortrait
SetLootThreshold SetMapToCurrentZone SetMapZoom SetMultisampleFormat SetPetStablePaperdoll
SetPortraitTexture SetPortraitToTexture SetRaidRosterSelection SetRaidSubgroup SetRaidTarget
SetScreenResolution SetSelectedAuctionItem SetSelectedBattlefield SetSelectedFaction
SetSelectedFriend SetSelectedIgnore SetSelectedSkill SetSendMailCOD SetSendMailMoney SetTaxiMap
SetTerrainMip SetTexLodBias SetTradeMoney SetTradeSkillInvSlotFilter
SetTradeSkillSubClassFilter SetTrainerServiceTypeFilter SetTrainerSkillLineFilter SetView
SetWatchedFactionIndex SetWaterDetail SetWhoToUI SetWorldDetail SetupFullscreenScale
ShowBattlefieldList ShowBuybackSellCursor ShowCloak ShowContainerSellCursor
ShowFriendNameplates ShowFriends ShowHelm ShowInspectCursor ShowInventorySellCursor
ShowMerchantSellCursor ShowMiniWorldMapArrowFrame ShowNameplates ShowRepairCursor
ShowWorldMapArrowFrame ShowingCloak ShowingHelm SignPetition SitOrStand SortAuctionItems
SortGuildRoster SortWho SpellCanTargetUnit SpellIsTargeting SpellStopCasting SpellStopTargeting
SpellTargetUnit SplitContainerItem StablePet StartAuction StartDuel StartDuelUnit StopCinematic
StopMusic StrafeLeftStart StrafeLeftStop StrafeRightStart StrafeRightStop Stuck SubmitNumbers
SwapRaidSubgroup TakeInboxItem TakeInboxMoney TakeInboxTextItem TakeTaxiNode TargetByName
TargetLastEnemy TargetLastTarget TargetNearestEnemy TargetNearestFriend
TargetNearestPartyMember TargetNearestRaidMember TargetUnit TaxiGetDestX TaxiGetDestY
TaxiGetSrcX TaxiGetSrcY TaxiNodeCost TaxiNodeGetType TaxiNodeName TaxiNodePosition
TaxiNodeSetCurrent ToggleAutoRun ToggleCollision ToggleCollisionDisplay ToggleMouseMove
TogglePVP TogglePerformanceDisplay TogglePerformanceValues TogglePetAutocast TogglePlayerBounds
TogglePortals ToggleRun ToggleSheath ToggleSpellAutocast ToggleTris TurnInGuildCharter
TurnLeftStart TurnLeftStop TurnOrActionStart TurnOrActionStop TurnRightStart TurnRightStop
TutorialsEnabled UninviteByName UninviteFromParty UninviteFromRaid UnitAffectingCombat
UnitArmor UnitAttackBothHands UnitAttackPower UnitAttackSpeed UnitBuff UnitCanAssist
UnitCanAttack UnitCanCooperate UnitCharacterPoints UnitClass UnitClassification
UnitCreatureFamily UnitCreatureType UnitDamage UnitDebuff UnitDefense UnitExists
UnitFactionGroup UnitHasRelicSlot UnitHealth UnitHealthMax UnitInParty UnitInRaid UnitIsCharmed
UnitIsCivilian UnitIsConnected UnitIsCorpse UnitIsDead UnitIsDeadOrGhost UnitIsEnemy
UnitIsFriend UnitIsGhost UnitIsPVP UnitIsPVPFreeForAll UnitIsPartyLeader UnitIsPlayer
UnitIsPlusMob UnitIsTapped UnitIsTappedByPlayer UnitIsTrivial UnitIsUnit UnitIsVisible
UnitLevel UnitMana UnitManaMax UnitName UnitOnTaxi UnitPVPName UnitPVPRank UnitPlayerControlled
UnitPlayerOrPetInParty UnitPlayerOrPetInRaid UnitPowerType UnitRace UnitRangedAttack
UnitRangedAttackPower UnitRangedDamage UnitReaction UnitResistance UnitSex UnitStat UnitXP
UnitXPMax UnstablePet UpdateGMTicket UpdateInventoryAlertStatus UpdateMapHighlight UpdateSpells
UpdateWorldMapArrowFrames UseAction UseContainerItem UseInventoryItem UseSoulstone
__framescript_meta __pow abs acos asin assert atan atan2 bit ceil collectgarbage cos date
debugbreak debugdump debuginfo debugload debugprint debugprofilestart debugprofilestop
debugstack debugtimestamp deg error exp floor foreach foreachi format frexp gcinfo
geterrorhandler getfenv getglobal getmetatable getn gsub ipairs ldexp loadstring log log10 math
mod next pairs pcall rad random randomseed rawequal rawget rawset seterrorhandler setfenv
setglobal setmetatable sin sort sqrt strbyte strchar strfind string strlen strlower strrep
strsub strupper table tan this tinsert tonumber tostring tremove type unpack xpcall
```

## Functions

1153 globals are bound as functions. The kind list is the argument types the
client reads (`?` optional, `|` alternatives).

```
AbandonQuest() AbandonSkill() AcceptAreaSpiritHeal() AcceptBattlefieldPort() AcceptContest()
AcceptDuel() AcceptEULA() AcceptGroup() AcceptGuild() AcceptQuest() AcceptResurrect()
AcceptScanning() AcceptSkillUps() AcceptTOS() AcceptTrade() AcceptXPLoss()
ActionHasRange(nil) | (number) AddChatWindowChannel() | (number) AddChatWindowMessages()
AddFriend() AddIgnore() AddOrDelIgnore() AddQuestWatch() AddSkillUp() AddTradeMoney() AppendToFile?
AssistByName() AssistUnit() AttackTarget() AutoEquipCursorItem() BankButtonIDToInvSlotID(number)
BeginTrade() BindEnchant() BuyGuildCharter(nil) | (number) BuyMerchantItem() BuyRandomPicks()
BuySkillTier() BuyStableSlot() BuyTrainerService() BuybackItem() CalculateAuctionDeposit(number)
CameraOrSelectOrMoveStart() CameraOrSelectOrMoveStop() CameraZoomIn() CameraZoomOut()
CanEditGuildInfo(nil) | (number) CanEditMOTD(nil) | (number) CanEditOfficerNote(nil) | (number)
CanEditPublicNote(nil) | (number) CanGuildDemote(nil) | (number) CanGuildInvite(nil) | (number)
CanGuildPromote(nil) | (number) CanGuildRemove(nil) | (number) CanInspect(nil) | (number)
CanJoinBattlefieldAsGroup(nil) | (number) CanMerchantRepair(nil) | (number)
CanSendAuctionQuery(nil) | (number) CanShowResetInstances(nil) | (number)
CanSignPetition(nil) | (number) CanViewOfficerNote(nil) | (number) CancelAreaSpiritHeal()
CancelAuction() CancelDuel() CancelLogout() CancelMeetingStoneRequest() CancelPendingEquip()
CancelPlayerBuff() CancelRealmListQuery() CancelSkillUps() CancelTrackingBuff() CancelTrade()
CancelTradeAccept() CastPetAction() CastShapeshiftForm() CastSpell() CastSpellByName()
ChangeActionBarPage() ChangeChatColor() ChangeRealm() ChannelBan() ChannelInvite() ChannelKick()
ChannelModerate() ChannelModerator() ChannelMute() ChannelToggleAnnouncements() ChannelUnban()
ChannelUnmoderator() ChannelUnmute() CheckBinderDist(nil) | (number) CheckInbox()
CheckInteractDistance(nil) | (number) CheckPetUntrainerDist(nil) | (number) CheckReadyCheckTime()
CheckSpiritHealerDist(nil) | (number) CheckTalentMasterDist(nil) | (number) ClearCursor()
ClearInspectPlayer() ClearSendMail() ClearTarget(nil) | (number) ClearTutorials()
ClickAuctionSellItemButton() ClickSendMailItemButton() ClickStablePet(nil) | (number)
ClickTargetTradeButton() ClickTradeButton() CloseAuctionHouse() CloseBankFrame() CloseBattlefield()
CloseCraft() CloseGossip() CloseGuildRegistrar() CloseGuildRoster() CloseItemText() CloseLoot()
CloseLottery() CloseMail() CloseMerchant() ClosePetStables() ClosePetition() CloseQuest()
CloseTabardCreation() CloseTaxiMap() CloseTrade() CloseTradeSkill() CloseTrainer()
CollapseCraftSkillLine() CollapseFactionHeader() CollapseQuestHeader() CollapseSkillHeader()
CollapseTradeSkillSubClass() CollapseTrainerSkillLine() CompleteQuest() ConfirmAcceptQuest()
ConfirmBindOnUse() ConfirmBinder() ConfirmLootRoll() ConfirmPetUnlearn() ConfirmReadyCheck()
ConfirmSummon() ConfirmTalentWipe() ConsoleExec() ContainerIDToInventoryID(number)
ContestAccepted(nil) | (number) ConvertToRaid() CreateCharacter() CreateFont(any) CreateFrame(any)
CreateMacro() | (number) CreateMiniWorldMapArrowFrame() CreateWorldMapArrowFrame()
CursorCanGoInSlot(nil) | (number) CursorHasItem(nil) | (number) CursorHasMoney(nil) | (number)
CursorHasSpell(nil) | (number) CycleCharCustomization() DeclineGroup() DeclineGuild()
DeclineQuest() DeclineResurrect() DefaultServerLogin() DelIgnore() DeleteCharacter()
DeleteCursorItem() DeleteFile? DeleteGMTicket() DeleteInboxItem() DeleteMacro() DemoteAssistant()
DisableAddOn() DisableAddOn() DisableAllAddOns() DisableAllAddOns() DisconnectFromServer()
DisplayChannelOwner() DoCraft() DoEmote() DoReadyCheck() DoTradeSkill() DropCursorMoney()
DropItemOnUnit() EULAAccepted(nil) | (number) EditMacro() | (number) EnableAddOn() EnableAddOn()
EnableAllAddOns() EnableAllAddOns() EnterWorld() EnumerateFrames(any) | (nil)
EnumerateServerChannels? EquipCursorItem() EquipPendingItem() ExpandCraftSkillLine()
ExpandFactionHeader() ExpandQuestHeader() ExpandSkillHeader() ExpandTradeSkillSubClass()
ExpandTrainerSkillLine() FactionToggleAtWar() FlagTutorial() FlipCameraYaw() FollowByName()
FollowUnit() ForceLogout() ForceQuit() FrameXML_Debug(number) GMRequestPlayerInfo?
GMSurveyAnswerSubmit() GMSurveyCommentSubmit() GMSurveyQuestion(nil) | (string?) GMSurveySubmit()
GetAbandonQuestItems? GetAbandonQuestName(nil) | (string?)
GetActionAutocast(nil,nil) | (nil,number) | (number,nil) | (number,number) GetActionBarToggles?
GetActionCooldown(number,number,number) GetActionCount(number) GetActionText(nil) | (string?)
GetActionTexture(nil) | (string?) GetActiveLevel(number) GetActiveTitle(string?)
GetAddOnDependencies? GetAddOnDependencies? GetAddOnEnableState(number) GetAddOnInfo? GetAddOnInfo?
GetAddOnMetadata(string?) GetAdjustedSkillPoints(number) GetAreaSpiritHealerTime(number)
GetAuctionHouseDepositRate(number) GetAuctionInvTypes? GetAuctionItemClasses? GetAuctionItemInfo?
GetAuctionItemLink() | (string?) GetAuctionItemSubClasses? GetAuctionItemTimeLeft(number)
GetAuctionSellItemInfo(nil,nil,number,number,nil,number) | (string?,string?,number,number,nil,number) | (string?,string?,number,number,number,number)
GetAvailableLevel(number) GetAvailableRaces? GetAvailableTitle(string?) GetBagName(nil) | (string?)
GetBankSlotCost(number) GetBaseMip(number) GetBattlefieldEstimatedWaitTime(number)
GetBattlefieldFlagPosition(number,number,nil) | (number,number,string?)
GetBattlefieldInfo() | (string?,number,number,number,number,number,number,number) | (string?,string?,number,number,number,number,number,number,number)
GetBattlefieldInstanceExpiration(number) GetBattlefieldInstanceInfo() | (number)
GetBattlefieldInstanceRunTime(number) GetBattlefieldMapIconScale(number)
GetBattlefieldPortExpiration(number)
GetBattlefieldPosition(number,number,nil) | (number,number,string?)
GetBattlefieldScore(nil,number,number,number,number,number,number,nil,nil) | (string?,number,number,number,number,number,number,nil,nil) | (string?,number,number,number,number,number,number,nil,string?) | (string?,number,number,number,number,number,number,string?,nil) | (string?,number,number,number,number,number,number,string?,string?)
GetBattlefieldStatData(number) GetBattlefieldStatInfo(nil,nil,nil) | (string?,string?,string?)
GetBattlefieldStatus(nil,nil,number,number,number) | (string,nil,number,number,number) | (string,string?,number,number,number)
GetBattlefieldTimeWaited(number) GetBattlefieldWinner(nil) | (number) GetBidderAuctionItems()
GetBillingPlan(number,number,number) GetBillingTimeRemaining(number) GetBillingTimeRested(number)
GetBillingTimeRested(number) GetBindLocation(string?) GetBinding? GetBindingAction(string?)
GetBindingKey? GetBlockChance(number) GetBonusBarOffset(number) GetBuildInfo(string,string,string)
GetBuildInfo(string?,string?,string,string,string)
GetBuybackItemInfo(nil,nil,number,number,number,number) | (string?,string?,number,number,number,nil) | (string?,string?,number,number,number,number)
GetCVar(string?) GetCVarDefault(nil) | (string?) GetChannelList?
GetChannelName(number,string?,number) GetCharacterCreateFacing(number)
GetCharacterInfo(nil,nil,nil,number,nil,nil,number,nil) | (string?,string?,string?,number,nil,string?,number,nil) | (string?,string?,string?,number,nil,string?,number,number) | (string?,string?,string?,number,string?,string?,number,nil) | (string?,string?,string?,number,string?,string?,number,number)
GetCharacterListUpdate() GetCharacterSelectFacing(number) GetChatTypeIndex(number)
GetChatWindowChannels?
GetChatWindowInfo() | (string?,number,number,number,number,number,nil,nil,nil) | (string?,number,number,number,number,number,nil,nil,number) | (string?,number,number,number,number,number,nil,number,nil) | (string?,number,number,number,number,number,nil,number,number) | (string?,number,number,number,number,number,number,nil,nil) | (string?,number,number,number,number,number,number,nil,number) | (string?,number,number,number,number,number,number,number,nil) | (string?,number,number,number,number,number,number,number,number)
GetChatWindowMessages? GetClassesForRace? GetCoinIcon(string?) GetComboPoints(number)
GetContainerItemCooldown(number,number,number)
GetContainerItemInfo() | (string?,number,nil,number,nil) | (string?,number,nil,number,number) | (string?,number,number,number,nil) | (string?,number,number,number,number)
GetContainerItemLink() | (string?) GetContainerNumSlots(number) GetCorpseMapPosition(number,number)
GetCorpseRecoveryDelay(number) GetCraftButtonToken(string?) GetCraftDescription(nil) | (string?)
GetCraftDisplaySkillLine(nil,number,number) | (string?,number,number) GetCraftIcon(nil) | (string?)
GetCraftInfo(nil,nil,nil,number,nil,number,number) | (string?,nil,string,number,nil,number,number) | (string?,nil,string,number,number,number,number) | (string?,string?,string?,number,nil,number,number)
GetCraftItemLink() | (string?) GetCraftName(nil) | (string?) GetCraftNumReagents(number)
GetCraftReagentInfo(nil,nil,nil,nil) | (nil,nil,number,number) | (string?,string?,number,number)
GetCraftReagentItemLink(nil) | (string?) GetCraftSelectionIndex(number)
GetCraftSkillLine(nil) | (string?) GetCraftSpellFocus? GetCurrentBindingSet(number)
GetCurrentMapContinent(number) GetCurrentMapZone(number) GetCurrentMultisampleFormat(number)
GetCurrentResolution(number) GetCursorMoney(number) GetCursorPosition(number,number)
GetCursorPosition(number,number) GetDamageBonusStat(number) GetDebugStats()
GetDefaultLanguage() | (string?) GetDodgeChance(number) GetDoodadAnim(number)
GetFacialHairCustomization(string) | (string?) GetFactionForRace(nil,nil) | (string?,string?)
GetFactionInfo? GetFarclip(number) GetFirstTradeSkill(number) GetFramerate(number)
GetFriendInfo(string?,number,string?,string?,nil,string?) | (string?,number,string?,string?,number,string?)
GetGMStatus() GetGMTicket() GetGMTicketCategories() GetGameTime(number,number) GetGamma(number)
GetGossipActiveQuests? GetGossipAvailableQuests? GetGossipOptions? GetGossipText(string?)
GetGreetingText(string?) GetGuildCharterCost(number)
GetGuildInfo(nil,nil,number) | (string?,string?,number) GetGuildInfoText(string?)
GetGuildRecruitmentMode(number) GetGuildRosterInfo?
GetGuildRosterLastOnline(nil,nil,nil,nil) | (number,number,number,number)
GetGuildRosterMOTD(string?) GetGuildRosterSelection(number)
GetGuildRosterShowOffline(nil) | (number) GetHairCustomization(string) | (string?)
GetIgnoreName(string?) GetInboxHeaderInfo?
GetInboxInvoiceInfo(nil,nil,nil,number,number,number,number) | (string,string?,string?,number,number,number,number)
GetInboxItem(nil,nil,number,number,nil) | (string?,string?,number,number,nil) | (string?,string?,number,number,number)
GetInboxNumItems(number) GetInboxText?
GetInspectHonorData(number,number,number,number,number,number,number,number,number,number,number,number)
GetInspectPVPRankProgress(number) GetInstanceBootTimeRemaining(number)
GetInventoryAlertStatus(number) GetInventoryItemBroken(nil) | (number)
GetInventoryItemCooldown(number,number,number) GetInventoryItemCount(number)
GetInventoryItemLink() | (string?) GetInventoryItemQuality(nil) | (number)
GetInventoryItemTexture(nil) | (string?)
GetInventorySlotInfo(number,string?,nil) | (number,string?,number)
GetItemInfo() | (string?,string?,number,number,string?,string?,number,string?,string?)
GetItemQualityColor(number,number,number,string?) GetJackpotAmount(number) GetLFGResults?
GetLFGTypeEntries? GetLFGTypes? GetLanguageByIndex() | (string?) GetLastLotteryNumbers()
GetLocale(string?) GetLocale(string?) GetLookingForGroup?
GetLootMethod(string,nil) | (string,number)
GetLootRollItemInfo(nil,nil,number,number,nil) | (string?,string?,number,number,nil) | (string?,string?,number,number,number)
GetLootRollItemLink() | (string?) GetLootRollTimeLeft(number)
GetLootSlotInfo(string?,string?,number,number) GetLootSlotLink(string?) GetLootThreshold(number)
GetLotteryPrizeInfo(string?,string?,number,number,nil) | (string?,string?,number,number,number)
GetMacroIconInfo(string?) GetMacroIndexByName(number)
GetMacroInfo(nil,nil,nil,nil) | (string?,nil,string?,nil) | (string?,nil,string?,number) | (string?,string?,string?,nil) | (string?,string?,string?,number)
GetMapContinents? GetMapInfo(string?,number,number)
GetMapLandmarkInfo(nil,nil,number,number,number) | (string?,nil,number,number,number) | (string?,string?,number,number,number)
GetMapOverlayInfo(nil,number,number,number,number,number,number) | (string?,number,number,number,number,number,number)
GetMapZones? GetMasterLootCandidate(nil) | (string?) GetMeetingStoneStatusText(string?)
GetMerchantItemInfo(nil,nil,number,number,number,number) | (nil,string?,number,number,number,nil) | (nil,string?,number,number,number,number) | (string?,string?,number,number,number,nil) | (string?,string?,number,number,number,number)
GetMerchantItemLink() | (string?) GetMerchantItemMaxStack(number) GetMerchantNumItems(number)
GetMinigameState() GetMinigameType(nil) | (string?) GetMinimapZoneText(string?) GetMoney(number)
GetMoneyPrizes(number,number,number) GetMouseFocus(any) | (nil) GetMovieResolution(number)
GetMovieSubtitles(nil) | (number) GetMultisampleFormats?
GetNameForRace(nil,nil) | (string?,string?) GetNetStats(number,number,number)
GetNextDrawTime(number) GetNextStableSlotCost(number) GetNumActiveQuests(number)
GetNumAddOns(number) GetNumAddOns(number) GetNumAuctionItems() | (number,number)
GetNumAvailableQuests(number) GetNumBankSlots(number,nil) | (number,number)
GetNumBattlefieldFlagPositions(number) GetNumBattlefieldPositions(number)
GetNumBattlefieldScores(number) GetNumBattlefieldStats(number) GetNumBattlefields(number)
GetNumBindings(number) GetNumBuybackItems(number) GetNumCharacters(number) GetNumCrafts(number)
GetNumFactions(number) GetNumFrames(number) GetNumFriends(number) GetNumGuildMembers(number)
GetNumIgnores(number) GetNumLFGResults(number,number) GetNumLaguages() | (number)
GetNumLootItems(number) GetNumLotteryPrizes(number) GetNumMacroIcons(number)
GetNumMacros(number,number) GetNumMapLandmarks(number) GetNumMapOverlays(number)
GetNumPackages(number) GetNumPartyMembers(number) GetNumPastDrawResults(number)
GetNumPetitionNames(number) GetNumQuestChoices(number) GetNumQuestItems(number)
GetNumQuestLeaderBoards(number) GetNumQuestLogChoices(number) GetNumQuestLogEntries(number,number)
GetNumQuestLogRewards(number) GetNumQuestRewards(number) GetNumQuestWatches(number)
GetNumRaidMembers(number) GetNumRealms(number) GetNumRoutes(number) GetNumSavedInstances(number)
GetNumShapeshiftForms(number) GetNumSkillLines(number) GetNumSpellTabs(number)
GetNumStablePets(number) GetNumStableSlots(number) GetNumStationeries(number)
GetNumTalentTabs(number) GetNumTalents(number) GetNumTradeSkills(number)
GetNumTrainerServices(number) GetNumWhoResults(number,number) GetNumWorldStateUI(number)
GetObjectiveText(string?) GetOwnerAuctionItems() GetPVPLastWeekStats(number,number,number,number)
GetPVPLifetimeStats(number,number,number) GetPVPRankInfo(nil,number) | (string?,number)
GetPVPRankProgress(number) GetPVPSessionStats(number,number) GetPVPThisWeekStats(number,number)
GetPVPYesterdayStats(number,number,number)
GetPackageInfo(nil,nil,number) | (string?,string?,number) GetParryChance(number)
GetPartyLeaderIndex(number) GetPartyMember(nil) | (number)
GetPastDrawResult(number,number,number,number,number) GetPetActionCooldown(number,number,number)
GetPetActionInfo? GetPetActionsUsable(nil) | (number) GetPetExperience(number,number)
GetPetFoodTypes? GetPetHappiness(nil,number,number) | (number,number,number)
GetPetIcon(nil) | (string?) GetPetLoyalty(nil) | (string?) GetPetTimeRemaining(nil) | (number)
GetPetTrainingPoints(number,number)
GetPetitionInfo(nil,nil,nil,number,nil,nil) | (string,string?,string?,number,nil,nil) | (string,string?,string?,number,nil,number) | (string,string?,string?,number,string?,nil) | (string,string?,string?,number,string?,number)
GetPetitionNameInfo(nil) | (string?) GetPlayerBuff(number,number) GetPlayerBuffApplications(number)
GetPlayerBuffDispelType(nil) | (string?) GetPlayerBuffTexture(nil) | (string?)
GetPlayerBuffTimeLeft(number) GetPlayerMapPosition(number,number) GetPlayerTradeMoney(number)
GetProgressText(string?) GetQuestBackgroundMaterial(nil) | (string?) GetQuestGreenRange(number)
GetQuestIndexForTimer(nil) | (number) GetQuestIndexForWatch(nil) | (number)
GetQuestItemInfo(string?,string?,number,number,nil) | (string?,string?,number,number,number)
GetQuestItemLink(nil) | (string?)
GetQuestLogChoiceInfo(nil,nil,number,number,nil) | (string?,string?,number,number,nil) | (string?,string?,number,number,number)
GetQuestLogItemLink(nil) | (string?)
GetQuestLogLeaderBoard(nil,nil,nil) | (string?,string,nil) | (string?,string,number)
GetQuestLogPushable(nil) | (number) GetQuestLogQuestText(nil,nil) | (string?,string?)
GetQuestLogRequiredMoney(number)
GetQuestLogRewardInfo(nil,nil,number,number,nil) | (string?,string?,number,number,nil) | (string?,string?,number,number,number)
GetQuestLogRewardMoney(number)
GetQuestLogRewardSpell(nil,nil,nil) | (nil,string?,nil) | (nil,string?,number) | (string?,string?,nil) | (string?,string?,number)
GetQuestLogSelection(number) GetQuestLogTimeLeft(nil) | (number)
GetQuestLogTitle(string?,number,string?,nil,nil,nil) | (string?,number,string?,nil,nil,number) | (string?,number,string?,number,nil,nil) | (string?,number,string?,number,nil,number) | (string?,number,string?,number,number,nil) | (string?,number,string?,number,number,number)
GetQuestMoneyToGet(number) GetQuestReward() GetQuestText(string?) GetQuestTimers?
GetRaidRosterInfo? GetRaidRosterSelection(number) GetRaidTargetIndex(nil) | (number)
GetRandomName(string?) GetRealZoneText(string?) GetRealmCategories? GetRealmInfo?
GetRealmName(string?) GetRefreshRates? GetReleaseTimeRemaining(number)
GetRepairAllCost(number) | (number,nil) | (number,number) GetResSicknessDuration(nil) | (string?)
GetRestState(nil,nil,nil) | (number,string?,number) GetRewardMoney(number)
GetRewardSpell(nil,nil,nil) | (nil,string?,nil) | (nil,string?,number) | (string?,string?,nil) | (string?,string?,number)
GetRewardText(string?) GetSavedAccountName(string?)
GetSavedInstanceInfo(nil,number,nil) | (string?,number,number) GetScreenHeight(number)
GetScreenHeight(number) GetScreenResolutions? GetScreenWidth(number) GetScreenWidth(number)
GetScriptMemory(number) GetSelectedAuctionItem(number) GetSelectedBattlefield(number)
GetSelectedCategory(number) GetSelectedClass(string?,string?) GetSelectedFaction(number)
GetSelectedFriend(number) GetSelectedIgnore(number) GetSelectedRace(number) GetSelectedSex(number)
GetSelectedSkill(number) GetSelectedStablePet(number) GetSelectedStationeryTexture(nil) | (string?)
GetSendMailCOD(number) GetSendMailItem(nil,nil,number,number) | (string?,string?,number,number)
GetSendMailMoney(number) GetSendMailPrice(number)
GetServerName(string?,nil,nil) | (string?,nil,number) | (string?,number,nil) | (string?,number,number)
GetShapeshiftFormCooldown(number,number,number)
GetShapeshiftFormInfo(nil,nil,nil,nil) | (nil,string?,nil,nil) | (nil,string?,nil,number) | (nil,string?,number,nil) | (nil,string?,number,number) | (string?,string?,nil,nil) | (string?,string?,nil,number) | (string?,string?,number,nil) | (string?,string?,number,number)
GetSkillLineInfo? GetSpellAutocast(nil,nil) | (nil,number) | (number,nil) | (number,number)
GetSpellCooldown(number,number,number) GetSpellName(nil,nil) | (string?,string?)
GetSpellTabInfo(nil,nil,number,number) | (string?,nil,number,number) | (string?,string,number,number) | (string?,string?,number,number)
GetSpellTexture(nil) | (string?) GetStablePetFoodTypes?
GetStablePetInfo(nil,nil,number,nil,nil) | (string?,string?,number,string?,nil) | (string?,string?,number,string?,string?)
GetStationeryInfo(nil,nil,nil) | (string?,string?,nil) | (string?,string?,number)
GetSubZoneText(string?) GetSummonConfirmAreaName(string?) GetSummonConfirmSummoner(string?)
GetSummonConfirmTimeLeft(number) GetTabardCreationCost(number) GetTabardInfo()
GetTalentInfo(nil,nil,number,number,number,number,nil,nil) | (string?,nil,number,number,number,number,nil,nil) | (string?,nil,number,number,number,number,nil,number) | (string?,nil,number,number,number,number,number,nil) | (string?,nil,number,number,number,number,number,number) | (string?,string?,number,number,number,number,nil,nil) | (string?,string?,number,number,number,number,nil,number) | (string?,string?,number,number,number,number,number,nil) | (string?,string?,number,number,number,number,number,number)
GetTalentPrereqs?
GetTalentTabInfo(nil,nil,number,nil) | (string?,nil,number,string?) | (string?,string?,number,string?)
GetTargetTradeMoney(number) GetTerrainMip(number) GetTexLodBias(number) GetTime(number)
GetTimeToWellRested(nil) GetTitleText(string?) GetTrackingTexture(nil) | (string?)
GetTradePlayerItemInfo(nil,nil,number,number,nil) | (string?,string?,number,number,nil) | (string?,string?,number,number,string?)
GetTradePlayerItemLink() | (string?) GetTradeSkillCooldown(nil) | (number)
GetTradeSkillIcon(nil) | (string?)
GetTradeSkillInfo(nil,nil,number,nil) | (string?,string,number,nil) | (string?,string,number,number) | (string?,string?,number,nil)
GetTradeSkillInvSlotFilter(nil) | (number) GetTradeSkillInvSlots?
GetTradeSkillItemLink() | (string?) GetTradeSkillItemStats?
GetTradeSkillLine(string,number,number) | (string?,number,number)
GetTradeSkillNumMade(number,number) GetTradeSkillNumReagents(number)
GetTradeSkillReagentInfo(nil,nil,nil,nil) | (nil,nil,number,number) | (string?,string?,number,number)
GetTradeSkillReagentItemLink(nil) | (string?) GetTradeSkillSelectionIndex(number)
GetTradeSkillSubClassFilter(nil) | (number) GetTradeSkillSubClasses? GetTradeSkillTools?
GetTradeTargetItemInfo(nil,nil,number,number,nil,nil) | (string?,string?,number,number,nil,nil) | (string?,string?,number,number,nil,string?) | (string?,string?,number,number,number,nil) | (string?,string?,number,number,number,string?)
GetTradeTargetItemLink() | (string?) GetTradeskillRepeatCount(number)
GetTrainerGreetingText(string?) GetTrainerSelectionIndex(number)
GetTrainerServiceAbilityReq(nil,nil) | (nil,number) | (string?,nil) | (string?,number)
GetTrainerServiceCost(number,number,number) GetTrainerServiceDescription(nil) | (string?)
GetTrainerServiceIcon(nil) | (string?)
GetTrainerServiceInfo(string?,string?,string?,nil) | (string?,string?,string?,number)
GetTrainerServiceLevelReq(number) GetTrainerServiceNumAbilityReq(number)
GetTrainerServiceSkillLine(nil) | (string?)
GetTrainerServiceSkillReq(nil,number,nil) | (nil,number,number) | (string?,number,nil) | (string?,number,number)
GetTrainerServiceStepIncrease(nil) | (string?)
GetTrainerServiceStepReq(nil,nil) | (nil,number) | (string?,nil) | (string?,number)
GetTrainerServiceTypeFilter(nil) | (number) GetTrainerSkillLineFilter(nil) | (number)
GetTrainerSkillLines? GetVideoCaps?
GetWatchedFactionInfo(nil,number,number,number,number) | (string?,number,number,number,number)
GetWaterDetail(number)
GetWeaponEnchantInfo(nil,nil,nil,nil,nil,nil) | (nil,nil,nil,number,nil,number) | (nil,nil,nil,number,number,number) | (number,nil,number,nil,nil,nil) | (number,nil,number,number,nil,number) | (number,nil,number,number,number,number) | (number,number,number,nil,nil,nil) | (number,number,number,number,nil,number) | (number,number,number,number,number,number)
GetWhoInfo(nil,nil,number,nil,nil,nil) | (string?,string?,number,string?,string?,string?)
GetWorldDetail(number) GetWorldLocMapPosition(number,number)
GetWorldStateUIInfo(number) | (number,string?,string?,string?,string?,string?,string?,number,number,number)
GetXPExhaustion(nil) | (number)
GetZonePVPInfo(nil,nil,nil) | (nil,nil,number) | (string,string?,nil) | (string,string?,number)
GetZoneText(string?) GiveMasterLoot() GuildControlAddRank() GuildControlDelRank()
GuildControlGetNumRanks(number) GuildControlGetRankFlags? GuildControlGetRankName(nil) | (string?)
GuildControlSaveRank() GuildControlSetRank() GuildControlSetRankFlag() GuildDemoteByName()
GuildDisband() GuildInfo() GuildInviteByName() GuildLeave() GuildPromoteByName() GuildRoster()
GuildRosterSetOfficerNote() GuildRosterSetPublicNote() GuildSetLeaderByName() GuildSetMOTD()
GuildUninviteByName() HasAction(nil) | (number) HasCharCustomization(nil) | (number)
HasFullControl(nil) | (number) HasInspectHonorData(nil) | (number) HasKey(nil) | (number)
HasNewMail(nil) | (number) HasPetSpells(nil,nil) | (number,string) | (number,string?)
HasPetUI(nil,nil) | (number,nil) | (number,number) HasSoulstone(nil) | (string) | (string?)
HasWandEquipped(nil) | (number) HideCursor() HideFriendNameplates() HideNameplates()
HideRepairCursor() InCinematic(nil) | (number) InRepairMode(nil) | (number)
InboxItemCanDelete(nil) | (number) InitiateTrade() InviteByName() InviteToParty()
IsActionInRange(nil) | (number) IsAddOnLoadOnDemand(nil) | (number) IsAddOnLoaded(nil) | (number)
IsAddonVersionCheckEnabled(nil) | (number) IsAltKeyDown(nil) | (number)
IsAttackAction(nil) | (number) IsAuctionSortReversed() | (nil) | (number)
IsAutoRepeatAction(nil) | (number) IsConnectedToServer(nil) | (number)
IsConsumableAction(nil) | (number) IsControlKeyDown(nil) | (number) IsCurrentAction(nil) | (number)
IsCurrentCast(nil) | (number) IsCurrentQuestFailed(nil) | (number) IsEquippedAction(nil) | (number)
IsFactionInactive(nil) | (number) IsFishingLoot(nil) | (number) IsGuildLeader(nil) | (number)
IsInGuild(nil) | (number) IsInInstance() | (nil,string?) | (number,string?)
IsInMeetingStoneQueue(nil) | (number) IsInventoryItemLocked(nil) | (number) IsLinuxClient(nil)
IsMacClient(nil) IsMouselooking(nil) | (number) IsPartyLeader(nil) | (number)
IsPetAttackActive(boolean) IsQuestCompletable(nil) | (number) IsQuestWatched(nil) | (number)
IsRaidLeader(nil) | (number) IsRaidOfficer(nil) | (number) IsResting(nil) | (number)
IsShiftKeyDown(nil) | (number) IsSpellPassive(nil) | (number) IsTalentTrainer(nil) | (number)
IsTradeskillTrainer(nil) | (number)
IsTrainerServiceLearnSpell(nil,nil) | (number,nil) | (number,number)
IsTrainerServiceSkillStep(nil) | (number) IsTrainerServiceTradeSkill(nil) | (number)
IsUnitOnQuest(nil) | (number)
IsUsableAction(nil,nil) | (nil,number) | (number,nil) | (number,number) IsVendorActive(number)
IsWindowsClient(number) ItemTextGetCreator(nil) | (string?) ItemTextGetItem(string?)
ItemTextGetMaterial(nil) | (string?) ItemTextGetPage(number) ItemTextGetText(string?)
ItemTextHasNextPage(nil) | (number) ItemTextNextPage() ItemTextPrevPage() JoinBattlefield()
JoinChannelByName() | (number,nil) | (number,string?) Jump() KeyRingButtonIDToInvSlotID(number)
LFGQuery() LaunchAddOnURL() LaunchURL() LearnTalent() LeaveBattlefield() LeaveChannelByName()
LeaveParty() ListChannelByName() ListChannels()
LoadAddOn(nil,string) | (nil,string?) | (number,nil) LoadBindings() LoggingChat? LoggingCombat?
Logout() LootSlot() LootSlotIsCoin(nil) | (number) LootSlotIsItem(nil) | (number)
MakeMinigameMove() MouselookStart() MouselookStop() MoveBackwardStart() MoveBackwardStop()
MoveForwardStart() MoveForwardStop() MoveViewDownStart? MoveViewDownStop? MoveViewInStart?
MoveViewInStop? MoveViewLeftStart? MoveViewLeftStop? MoveViewOutStart? MoveViewOutStop?
MoveViewRightStart? MoveViewRightStop? MoveViewUpStart? MoveViewUpStop? NewGMTicket() NextView()
NoPlayTime(nil) | (number) NotWhileDeadError() NotifyInspect() NumTaxiNodes(number) OfferPetition()
OffhandHasWeapon(nil) | (number) OpenTrainer() OpeningCinematic() PINEntered()
PartialPlayTime(nil) | (number) PatchDownloadApply() PatchDownloadCancel()
PatchDownloadProgress(number) PetAbandon() PetAggressiveMode() PetAttack()
PetCanBeAbandoned(nil) | (number) PetCanBeRenamed(nil) | (number) PetDefensiveMode() PetDismiss()
PetFollow() PetHasActionBar(nil) | (number) PetPassiveMode() PetRename() PetStopAttack() PetWait()
PickupAction() PickupBagFromSlot() PickupContainerItem() PickupInventoryItem() PickupMacro()
PickupMerchantItem() PickupPetAction() PickupPlayerMoney() PickupSpell() PickupStablePet()
PickupTradeMoney() PitchDownStart() PitchDownStop() PitchUpStart() PitchUpStop() PlaceAction()
PlaceAuctionBid() PlayCreditsMusic() PlayGlueMusic() PlayMusic() PlaySound()
PlaySoundFile(nil) | (number) PlayerHasSpells(number) PositionMiniWorldMapArrowFrame()
PositionWorldMapArrowFrame() PrevView() ProcessMapClick() PromoteByName() PromoteToAssistant()
PromoteToPartyLeader() PurchaseSlot() PutItemInBackpack(nil) | (number)
PutItemInBag(nil) | (number) QueryAuctionItems() QuestChooseRewardError() QuestLogPushQuest()
Quit() QuitGame() RandomRoll() RandomizeCharCustomization() ReadFile? RealmListDialogCancelled()
RegisterCVar() RegisterForSave() ReloadUI() RemoveChatWindowChannel() RemoveChatWindowMessages()
RemoveFriend() RemoveQuestWatch() RemoveSkillUp() RenameCharacter() | (nil) | (number)
RenamePetition() RepairAllItems() ReplaceEnchant() ReplaceTradeEnchant() RepopMe()
RequestBattlefieldPositions() RequestBattlefieldScoreData() RequestInspectHonorData()
RequestRaidInfo() RequestRealmList() RequestTimePlayed() ResetAddOns() ResetCharCustomize()
ResetChatColors() ResetCursor() ResetDisabledAddOns() ResetInstances() ResetPerformanceValues()
ResetTutorials() ResetView() RestartGx() RestoreVideoDefaults()
ResurrectHasSickness(nil) | (number) ResurrectHasTimer(nil) | (number) RetrieveCorpse()
ReturnInboxItem() RollOnLoot() RunBinding() RunScript() SaveAddOns() SaveBindings() SaveView()
ScanningAccepted(nil) | (number) Screenshot() Screenshot() SelectActiveQuest()
SelectAvailableQuest() SelectCharacter() SelectCraft() SelectGossipActiveQuest()
SelectGossipAvailableQuest() SelectGossipOption() SelectPackage() SelectQuestLogEntry()
SelectStationery() SelectTradeSkill() SelectTrainerService() SendAddonMessage() SendChatMessage()
SendMail() SendWho() SetAbandonQuest() SetActionBarToggles() SetAddonVersionCheck()
SetBagPortaitTexture() SetBaseMip() SetBattlefieldScoreFaction() SetBinding(nil) | (number)
SetCVar() SetChannelOwner() SetChannelPassword() SetCharCustomizeBackground()
SetCharCustomizeFrame() SetCharSelectBackground() SetCharSelectModelFrame()
SetCharacterCreateFacing() SetCharacterSelectFacing() SetChatWindowAlpha() SetChatWindowColor()
SetChatWindowDocked() SetChatWindowLocked() SetChatWindowName() SetChatWindowShown()
SetChatWindowSize() SetConsoleKey() SetCurrentScreen() SetCursor() | (nil) | (number)
SetDoodadAnim() SetEuropeanNumbers() SetFactionActive() SetFactionInactive() SetFarclip()
SetGamma() SetGuildInfoText() SetGuildRecruitmentMode() SetGuildRosterSelection()
SetGuildRosterShowOffline() SetInventoryPortaitTexture() SetLayoutMode() SetLookingForGroup()
SetLootMethod() SetLootPortrait(nil) | (number) SetLootThreshold() SetMapToCurrentZone()
SetMapZoom() SetMovieSubtitles() SetMultisampleFormat() SetPetStablePaperdoll()
SetPortraitTexture() SetPortraitToTexture() SetPreferredInfo() SetRaidRosterSelection()
SetRaidSubgroup() SetRaidTarget() SetSavedAccountName() SetScreenResolution() SetScriptMemory()
SetSelectedAuctionItem() SetSelectedBattlefield() SetSelectedClass() SetSelectedFaction()
SetSelectedFriend() SetSelectedIgnore() SetSelectedRace() SetSelectedSex() SetSelectedSkill()
SetSendMailCOD() SetSendMailMoney(nil) | (number) SetTaxiMap() SetTerrainMip() SetTexLodBias()
SetTradeMoney() SetTradeSkillInvSlotFilter() SetTradeSkillSubClassFilter()
SetTrainerServiceTypeFilter() SetTrainerSkillLineFilter() SetView() SetWatchedFactionIndex()
SetWaterDetail() SetWhoToUI() SetWorldDetail() SetupFullscreenScale() ShowBattlefieldList()
ShowBuybackSellCursor() ShowCloak() ShowContainerSellCursor() ShowContestNotice(nil) | (number)
ShowCursor() ShowEULANotice(nil) | (number) ShowFriendNameplates() ShowFriends() ShowHelm()
ShowInspectCursor() ShowInventorySellCursor() ShowMerchantSellCursor() ShowMiniWorldMapArrowFrame()
ShowNameplates() ShowRepairCursor() ShowScanningNotice(nil) | (number)
ShowTOSNotice(nil) | (number) ShowWorldMapArrowFrame() ShowingCloak(nil) | (number)
ShowingHelm(nil) | (number) SignPetition() SitOrStand() SortAuctionItems() SortGuildRoster()
SortRealms() SortWho() SpellCanTargetUnit(nil) | (number) SpellIsTargeting(nil) | (number)
SpellStopCasting(nil) | (number) SpellStopTargeting(nil) | (number) SpellTargetUnit()
SplitContainerItem() StablePet() StartAuction() StartDuel() StartDuelUnit() StatusDialogClick()
StopCinematic() StopGlueMusic() StopMusic() StrafeLeftStart() StrafeLeftStop() StrafeRightStart()
StrafeRightStop() Stuck() SubmitNumbers() SurveyNotificationDone() SwapRaidSubgroup()
TOSAccepted(nil) | (number) TakeInboxItem() TakeInboxMoney() TakeInboxTextItem() TakeTaxiNode()
TargetByName() TargetLastEnemy() TargetLastTarget() TargetNearestEnemy() TargetNearestFriend()
TargetNearestPartyMember() TargetNearestRaidMember() TargetUnit() TaxiGetDestX(number)
TaxiGetDestY(number) TaxiGetSrcX(number) TaxiGetSrcY(number) TaxiNodeCost(number)
TaxiNodeGetType(string?) TaxiNodeName(string?) TaxiNodePosition(number,number) TaxiNodeSetCurrent()
ToggleAutoRun() ToggleCollision() ToggleCollisionDisplay() ToggleMouseMove() TogglePVP()
TogglePerformanceDisplay() TogglePerformanceValues() TogglePetAutocast() TogglePlayerBounds()
TogglePortals() ToggleRun() ToggleSheath() ToggleSpellAutocast() ToggleTris() TurnInGuildCharter()
TurnLeftStart() TurnLeftStop() TurnOrActionStart() TurnOrActionStop() TurnRightStart()
TurnRightStop() TutorialsEnabled(nil) | (number) UninviteByName() UninviteFromParty()
UninviteFromRaid() UnitAffectingCombat(nil) | (number)
UnitArmor(number,number,number,number,number) UnitAttackBothHands?
UnitAttackPower(number,number,number) UnitAttackSpeed(number,nil) | (number,number)
UnitBuff(nil) | (nil,number) | (string?,number) UnitCanAssist(nil) | (number)
UnitCanAttack(nil) | (number) UnitCanCooperate(nil) | (number) UnitCharacterPoints?
UnitClass(nil,nil) | (string?,string?) UnitClassification(string?)
UnitCreatureFamily(nil) | (string?) UnitCreatureType(nil) | (string?)
UnitDamage(number,number,number,number,number,number,number)
UnitDebuff(nil) | (nil,number,nil) | (string?,number,nil) | (string?,number,string?)
UnitDefense(number,number) UnitExists(nil) | (number) UnitFactionGroup(nil,nil) | (string?,string?)
UnitHasRelicSlot(nil) | (number) UnitHealth(number) UnitHealthMax(number)
UnitInParty(nil) | (number) UnitInRaid(nil) | (number) UnitIsCharmed(nil) | (number)
UnitIsCivilian(nil) | (number) UnitIsConnected(nil) | (number) UnitIsCorpse(nil) | (number)
UnitIsDead(nil) | (number) UnitIsDeadOrGhost(nil) | (number) UnitIsEnemy(nil) | (number)
UnitIsFriend(nil) | (number) UnitIsGhost(nil) | (number) UnitIsPVP(nil) | (number)
UnitIsPVPFreeForAll(nil) | (number) UnitIsPartyLeader(nil) | (number) UnitIsPlayer(nil) | (number)
UnitIsPlusMob(nil) | (number) UnitIsTapped(nil) | (number) UnitIsTappedByPlayer(nil) | (number)
UnitIsTrivial(nil) | (number) UnitIsUnit(nil) | (number) UnitIsVisible(nil) | (number)
UnitLevel(number) UnitMana(number) UnitManaMax(number)
UnitName(nil,nil) | (string?,nil) | (string?,string?) UnitOnTaxi(nil) | (number)
UnitPVPName() | (nil) | (string?) UnitPVPRank(number) UnitPlayerControlled(nil) | (number)
UnitPlayerOrPetInParty(nil) | (number) UnitPlayerOrPetInRaid(nil) | (number) UnitPowerType(number)
UnitRace(nil,nil) | (string?,string?) UnitRangedAttack(number,number)
UnitRangedAttackPower(number,number,number)
UnitRangedDamage(number,number,number,number,number,number) UnitReaction(nil) | (number)
UnitResistance(number,number,number,number) UnitSex(number) UnitStat(number,number,number,number)
UnitXP(number) UnitXPMax(number) UnstablePet() UpdateCustomizationBackground()
UpdateCustomizationScene() UpdateGMTicket() UpdateInventoryAlertStatus()
UpdateMapHighlight(nil,nil,number,number,number,number,number,number) | (nil,string?,number,number,number,number,number,number) | (nil,string?,number,number,number,number,number,number,number,number) | (string?,nil,number,number,number,number,number,number) | (string?,string?,number,number,number,number,number,number) | (string?,string?,number,number,number,number,number,number,number,number)
UpdateSelectionCustomizationScene() UpdateSpells() UpdateWorldMapArrowFrames() UseAction()
UseContainerItem() UseInventoryItem() UseSoulstone()
```

### Widget methods

`CreateFrame("Type", ...)` accepts these 24 templates, and the VM was
asked for the methods each one actually has:

```
Button (119) CheckButton (125) ColorSelect (97) DressUpModel (116) EditBox (131) Font (22)
FontString (51) Frame (87) GameTooltip (133) LootButton (120) MessageFrame (113) Minimap (93)
Model (110) MovieFrame (87) PlayerModel (113) ScrollFrame (96) ScrollingMessageFrame (123)
SimpleHTML (106) Slider (97) StatusBar (97) TabardModel (123) Texture (40) TitleRegion (19)
WorldFrame (87)
```

`Frame` is the base: its methods are on every widget, so `CreateFrame`
with any template gives you `SetPoint`, `SetScript`, `CreateFontString`,
`Show`/`Hide` and the rest. Anything not listed for a type is not on it —
feature-detect (`if (frame.SetChecked) then ...`) rather than assume.

**GameTooltip** (133)

```
AddDoubleLine AddFontStrings AddLine AppendText ClearAllPoints ClearLines CreateFontString
CreateTexture CreateTitleRegion DisableDrawLayer EnableDrawLayer EnableKeyboard EnableMouse
EnableMouseWheel FadeOut GetAlpha GetAnchorType GetBackdrop GetBackdropBorderColor GetBackdropColor
GetBottom GetCenter GetChildren GetEffectiveScale GetFrameLevel GetFrameStrata GetFrameType
GetHeight GetHitRectInsets GetID GetLeft GetMaxResize GetMinResize GetName GetNumChildren
GetNumPoints GetNumRegions GetObjectType GetParent GetPoint GetRegions GetRight GetScale GetScript
GetTitleRegion GetTop GetWidth HasScript Hide IsClampedToScreen IsFrameType IsKeyboardEnabled
IsMouseEnabled IsMouseWheelEnabled IsMovable IsObjectType IsOwned IsResizable IsShown IsToplevel
IsUserPlaced IsVisible Lower NumLines Raise RegisterAllEvents RegisterEvent RegisterForDrag
SetAction SetAllPoints SetAlpha SetAuctionCompareItem SetAuctionItem SetAuctionSellItem SetBackdrop
SetBackdropBorderColor SetBackdropColor SetBagItem SetBuybackItem SetClampedToScreen SetCraftItem
SetCraftSpell SetFrameLevel SetFrameStrata SetHeight SetHitRectInsets SetHyperlink SetID
SetInboxItem SetInventoryItem SetLootItem SetLootRollItem SetMaxResize SetMerchantCompareItem
SetMerchantItem SetMinResize SetMinimumWidth SetMovable SetOwner SetPadding SetParent SetPetAction
SetPlayerBuff SetPoint SetQuestItem SetQuestLogItem SetQuestLogRewardSpell SetQuestRewardSpell
SetResizable SetScale SetScript SetSendMailItem SetShapeshift SetSpell SetTalent SetText
SetToplevel SetTrackingSpell SetTradePlayerItem SetTradeSkillItem SetTradeTargetItem
SetTrainerService SetUnit SetUnitBuff SetUnitDebuff SetUserPlaced SetWidth Show StartMoving
StartSizing StopMovingOrSizing UnregisterAllEvents UnregisterEvent
```

**EditBox** (131)

```
AddHistoryLine ClearAllPoints ClearFocus CreateFontString CreateTexture CreateTitleRegion
DisableDrawLayer EnableDrawLayer EnableKeyboard EnableMouse EnableMouseWheel GetAlpha
GetAltArrowKeyMode GetBackdrop GetBackdropBorderColor GetBackdropColor GetBlinkSpeed GetBottom
GetCenter GetChildren GetEffectiveScale GetFont GetFontObject GetFrameLevel GetFrameStrata
GetFrameType GetHeight GetHistoryLines GetHitRectInsets GetID GetInputLanguage GetJustifyH
GetJustifyV GetLeft GetMaxBytes GetMaxLetters GetMaxResize GetMinResize GetName GetNumChildren
GetNumLetters GetNumPoints GetNumRegions GetNumber GetObjectType GetParent GetPoint GetRegions
GetRight GetScale GetScript GetShadowColor GetShadowOffset GetSpacing GetText GetTextColor
GetTextInsets GetTitleRegion GetTop GetWidth HasScript Hide HighlightText Insert IsClampedToScreen
IsFrameType IsKeyboardEnabled IsMouseEnabled IsMouseWheelEnabled IsMovable IsObjectType IsResizable
IsShown IsToplevel IsUserPlaced IsVisible Lower Raise RegisterAllEvents RegisterEvent
RegisterForDrag SetAllPoints SetAlpha SetAltArrowKeyMode SetAutoFocus SetBackdrop
SetBackdropBorderColor SetBackdropColor SetBlinkSpeed SetClampedToScreen SetFocus SetFont
SetFontObject SetFrameLevel SetFrameStrata SetHeight SetHistoryLines SetHitRectInsets SetID
SetJustifyH SetJustifyV SetMaxBytes SetMaxLetters SetMaxResize SetMinResize SetMovable SetMultiLine
SetNumber SetNumeric SetParent SetPassword SetPoint SetResizable SetScale SetScript SetShadowColor
SetShadowOffset SetSpacing SetText SetTextColor SetTextInsets SetToplevel SetUserPlaced SetWidth
Show StartMoving StartSizing StopMovingOrSizing ToggleInputLanguage UnregisterAllEvents
UnregisterEvent
```

**CheckButton** (125)

```
ClearAllPoints Click CreateFontString CreateTexture CreateTitleRegion Disable DisableDrawLayer
Enable EnableDrawLayer EnableKeyboard EnableMouse EnableMouseWheel GetAlpha GetBackdrop
GetBackdropBorderColor GetBackdropColor GetBottom GetButtonState GetCenter GetChecked
GetCheckedTexture GetChildren GetDisabledCheckedTexture GetDisabledTexture GetEffectiveScale
GetFont GetFontString GetFrameLevel GetFrameStrata GetFrameType GetHeight GetHighlightTexture
GetHitRectInsets GetID GetLeft GetMaxResize GetMinResize GetName GetNormalTexture GetNumChildren
GetNumPoints GetNumRegions GetObjectType GetParent GetPoint GetPushedTexture GetRegions GetRight
GetScale GetScript GetText GetTextColor GetTextHeight GetTextWidth GetTitleRegion GetTop GetWidth
HasScript Hide IsClampedToScreen IsEnabled IsFrameType IsKeyboardEnabled IsMouseEnabled
IsMouseWheelEnabled IsMovable IsObjectType IsResizable IsShown IsToplevel IsUserPlaced IsVisible
LockHighlight Lower Raise RegisterAllEvents RegisterEvent RegisterForClicks RegisterForDrag
SetAllPoints SetAlpha SetBackdrop SetBackdropBorderColor SetBackdropColor SetButtonState SetChecked
SetCheckedTexture SetClampedToScreen SetDisabledCheckedTexture SetDisabledFontObject
SetDisabledTextColor SetDisabledTexture SetFont SetFontString SetFrameLevel SetFrameStrata
SetHeight SetHighlightFontObject SetHighlightTextColor SetHighlightTexture SetHitRectInsets SetID
SetMaxResize SetMinResize SetMovable SetNormalTexture SetParent SetPoint SetPushedTexture
SetResizable SetScale SetScript SetText SetTextColor SetTextFontObject SetToplevel SetUserPlaced
SetWidth Show StartMoving StartSizing StopMovingOrSizing UnlockHighlight UnregisterAllEvents
UnregisterEvent
```

**ScrollingMessageFrame** (123)

```
AddMessage AtBottom AtTop Clear ClearAllPoints CreateFontString CreateTexture CreateTitleRegion
DisableDrawLayer EnableDrawLayer EnableKeyboard EnableMouse EnableMouseWheel GetAlpha GetBackdrop
GetBackdropBorderColor GetBackdropColor GetBottom GetCenter GetChildren GetEffectiveScale
GetFadeDuration GetFading GetFont GetFontObject GetFrameLevel GetFrameStrata GetFrameType GetHeight
GetHitRectInsets GetID GetJustifyH GetJustifyV GetLeft GetMaxLines GetMaxResize GetMinResize
GetName GetNumChildren GetNumMessages GetNumPoints GetNumRegions GetObjectType GetParent GetPoint
GetRegions GetRight GetScale GetScript GetShadowColor GetShadowOffset GetSpacing GetTextColor
GetTimeVisible GetTitleRegion GetTop GetWidth HasScript Hide IsClampedToScreen IsFrameType
IsKeyboardEnabled IsMouseEnabled IsMouseWheelEnabled IsMovable IsObjectType IsResizable IsShown
IsToplevel IsUserPlaced IsVisible Lower PageDown PageUp Raise RegisterAllEvents RegisterEvent
RegisterForDrag ScrollDown ScrollToBottom ScrollToTop ScrollUp SetAllPoints SetAlpha SetBackdrop
SetBackdropBorderColor SetBackdropColor SetClampedToScreen SetFadeDuration SetFading SetFont
SetFontObject SetFrameLevel SetFrameStrata SetHeight SetHitRectInsets SetID SetJustifyH SetJustifyV
SetMaxLines SetMaxResize SetMinResize SetMovable SetParent SetPoint SetResizable SetScale SetScript
SetShadowColor SetShadowOffset SetSpacing SetTextColor SetTimeVisible SetToplevel SetUserPlaced
SetWidth Show StartMoving StartSizing StopMovingOrSizing UnregisterAllEvents UnregisterEvent
UpdateColorByID
```

**TabardModel** (123)

```
AdvanceTime CanSaveTabardNow ClearAllPoints ClearFog ClearModel CreateFontString CreateTexture
CreateTitleRegion CycleVariation DisableDrawLayer EnableDrawLayer EnableKeyboard EnableMouse
EnableMouseWheel GetAlpha GetBackdrop GetBackdropBorderColor GetBackdropColor GetBottom GetCenter
GetChildren GetEffectiveScale GetFacing GetFogColor GetFogFar GetFogNear GetFrameLevel
GetFrameStrata GetFrameType GetHeight GetHitRectInsets GetID GetLeft GetLight
GetLowerBackgroundFileName GetLowerEmblemFileName GetLowerEmblemTexture GetMaxResize GetMinResize
GetModel GetModelScale GetName GetNumChildren GetNumPoints GetNumRegions GetObjectType GetParent
GetPoint GetPosition GetRegions GetRight GetScale GetScript GetTitleRegion GetTop
GetUpperBackgroundFileName GetUpperEmblemFileName GetUpperEmblemTexture GetWidth HasScript Hide
InitializeTabardColors IsClampedToScreen IsFrameType IsKeyboardEnabled IsMouseEnabled
IsMouseWheelEnabled IsMovable IsObjectType IsResizable IsShown IsToplevel IsUserPlaced IsVisible
Lower Raise RefreshUnit RegisterAllEvents RegisterEvent RegisterForDrag ReplaceIconTexture Save
SetAllPoints SetAlpha SetBackdrop SetBackdropBorderColor SetBackdropColor SetCamera
SetClampedToScreen SetFacing SetFogColor SetFogFar SetFogNear SetFrameLevel SetFrameStrata
SetHeight SetHitRectInsets SetID SetLight SetMaxResize SetMinResize SetModel SetModelScale
SetMovable SetParent SetPoint SetPosition SetResizable SetRotation SetScale SetScript SetSequence
SetSequenceTime SetToplevel SetUnit SetUserPlaced SetWidth Show StartMoving StartSizing
StopMovingOrSizing UnregisterAllEvents UnregisterEvent
```

**LootButton** (120)

```
ClearAllPoints Click CreateFontString CreateTexture CreateTitleRegion Disable DisableDrawLayer
Enable EnableDrawLayer EnableKeyboard EnableMouse EnableMouseWheel GetAlpha GetBackdrop
GetBackdropBorderColor GetBackdropColor GetBottom GetButtonState GetCenter GetChildren
GetDisabledTexture GetEffectiveScale GetFont GetFontString GetFrameLevel GetFrameStrata
GetFrameType GetHeight GetHighlightTexture GetHitRectInsets GetID GetLeft GetMaxResize GetMinResize
GetName GetNormalTexture GetNumChildren GetNumPoints GetNumRegions GetObjectType GetParent GetPoint
GetPushedTexture GetRegions GetRight GetScale GetScript GetText GetTextColor GetTextHeight
GetTextWidth GetTitleRegion GetTop GetWidth HasScript Hide IsClampedToScreen IsEnabled IsFrameType
IsKeyboardEnabled IsMouseEnabled IsMouseWheelEnabled IsMovable IsObjectType IsResizable IsShown
IsToplevel IsUserPlaced IsVisible LockHighlight Lower Raise RegisterAllEvents RegisterEvent
RegisterForClicks RegisterForDrag SetAllPoints SetAlpha SetBackdrop SetBackdropBorderColor
SetBackdropColor SetButtonState SetClampedToScreen SetDisabledFontObject SetDisabledTextColor
SetDisabledTexture SetFont SetFontString SetFrameLevel SetFrameStrata SetHeight
SetHighlightFontObject SetHighlightTextColor SetHighlightTexture SetHitRectInsets SetID
SetMaxResize SetMinResize SetMovable SetNormalTexture SetParent SetPoint SetPushedTexture
SetResizable SetScale SetScript SetSlot SetText SetTextColor SetTextFontObject SetToplevel
SetUserPlaced SetWidth Show StartMoving StartSizing StopMovingOrSizing UnlockHighlight
UnregisterAllEvents UnregisterEvent
```

**Button** (119)

```
ClearAllPoints Click CreateFontString CreateTexture CreateTitleRegion Disable DisableDrawLayer
Enable EnableDrawLayer EnableKeyboard EnableMouse EnableMouseWheel GetAlpha GetBackdrop
GetBackdropBorderColor GetBackdropColor GetBottom GetButtonState GetCenter GetChildren
GetDisabledTexture GetEffectiveScale GetFont GetFontString GetFrameLevel GetFrameStrata
GetFrameType GetHeight GetHighlightTexture GetHitRectInsets GetID GetLeft GetMaxResize GetMinResize
GetName GetNormalTexture GetNumChildren GetNumPoints GetNumRegions GetObjectType GetParent GetPoint
GetPushedTexture GetRegions GetRight GetScale GetScript GetText GetTextColor GetTextHeight
GetTextWidth GetTitleRegion GetTop GetWidth HasScript Hide IsClampedToScreen IsEnabled IsFrameType
IsKeyboardEnabled IsMouseEnabled IsMouseWheelEnabled IsMovable IsObjectType IsResizable IsShown
IsToplevel IsUserPlaced IsVisible LockHighlight Lower Raise RegisterAllEvents RegisterEvent
RegisterForClicks RegisterForDrag SetAllPoints SetAlpha SetBackdrop SetBackdropBorderColor
SetBackdropColor SetButtonState SetClampedToScreen SetDisabledFontObject SetDisabledTextColor
SetDisabledTexture SetFont SetFontString SetFrameLevel SetFrameStrata SetHeight
SetHighlightFontObject SetHighlightTextColor SetHighlightTexture SetHitRectInsets SetID
SetMaxResize SetMinResize SetMovable SetNormalTexture SetParent SetPoint SetPushedTexture
SetResizable SetScale SetScript SetText SetTextColor SetTextFontObject SetToplevel SetUserPlaced
SetWidth Show StartMoving StartSizing StopMovingOrSizing UnlockHighlight UnregisterAllEvents
UnregisterEvent
```

**DressUpModel** (116)

```
AdvanceTime ClearAllPoints ClearFog ClearModel CreateFontString CreateTexture CreateTitleRegion
DisableDrawLayer Dress EnableDrawLayer EnableKeyboard EnableMouse EnableMouseWheel GetAlpha
GetBackdrop GetBackdropBorderColor GetBackdropColor GetBottom GetCenter GetChildren
GetEffectiveScale GetFacing GetFogColor GetFogFar GetFogNear GetFrameLevel GetFrameStrata
GetFrameType GetHeight GetHitRectInsets GetID GetLeft GetLight GetMaxResize GetMinResize GetModel
GetModelScale GetName GetNumChildren GetNumPoints GetNumRegions GetObjectType GetParent GetPoint
GetPosition GetRegions GetRight GetScale GetScript GetTitleRegion GetTop GetWidth HasScript Hide
IsClampedToScreen IsFrameType IsKeyboardEnabled IsMouseEnabled IsMouseWheelEnabled IsMovable
IsObjectType IsResizable IsShown IsToplevel IsUserPlaced IsVisible Lower Raise RefreshUnit
RegisterAllEvents RegisterEvent RegisterForDrag ReplaceIconTexture SetAllPoints SetAlpha
SetBackdrop SetBackdropBorderColor SetBackdropColor SetCamera SetClampedToScreen SetFacing
SetFogColor SetFogFar SetFogNear SetFrameLevel SetFrameStrata SetHeight SetHitRectInsets SetID
SetLight SetMaxResize SetMinResize SetModel SetModelScale SetMovable SetParent SetPoint SetPosition
SetResizable SetRotation SetScale SetScript SetSequence SetSequenceTime SetToplevel SetUnit
SetUserPlaced SetWidth Show StartMoving StartSizing StopMovingOrSizing TryOn Undress
UnregisterAllEvents UnregisterEvent
```

**MessageFrame** (113)

```
AddMessage Clear ClearAllPoints CreateFontString CreateTexture CreateTitleRegion DisableDrawLayer
EnableDrawLayer EnableKeyboard EnableMouse EnableMouseWheel GetAlpha GetBackdrop
GetBackdropBorderColor GetBackdropColor GetBottom GetCenter GetChildren GetEffectiveScale
GetFadeDuration GetFading GetFont GetFontObject GetFrameLevel GetFrameStrata GetFrameType GetHeight
GetHitRectInsets GetID GetInsertMode GetJustifyH GetJustifyV GetLeft GetMaxResize GetMinResize
GetName GetNumChildren GetNumPoints GetNumRegions GetObjectType GetParent GetPoint GetRegions
GetRight GetScale GetScript GetShadowColor GetShadowOffset GetSpacing GetTextColor GetTimeVisible
GetTitleRegion GetTop GetWidth HasScript Hide IsClampedToScreen IsFrameType IsKeyboardEnabled
IsMouseEnabled IsMouseWheelEnabled IsMovable IsObjectType IsResizable IsShown IsToplevel
IsUserPlaced IsVisible Lower Raise RegisterAllEvents RegisterEvent RegisterForDrag SetAllPoints
SetAlpha SetBackdrop SetBackdropBorderColor SetBackdropColor SetClampedToScreen SetFadeDuration
SetFading SetFont SetFontObject SetFrameLevel SetFrameStrata SetHeight SetHitRectInsets SetID
SetInsertMode SetJustifyH SetJustifyV SetMaxResize SetMinResize SetMovable SetParent SetPoint
SetResizable SetScale SetScript SetShadowColor SetShadowOffset SetSpacing SetTextColor
SetTimeVisible SetToplevel SetUserPlaced SetWidth Show StartMoving StartSizing StopMovingOrSizing
UnregisterAllEvents UnregisterEvent
```

**PlayerModel** (113)

```
AdvanceTime ClearAllPoints ClearFog ClearModel CreateFontString CreateTexture CreateTitleRegion
DisableDrawLayer EnableDrawLayer EnableKeyboard EnableMouse EnableMouseWheel GetAlpha GetBackdrop
GetBackdropBorderColor GetBackdropColor GetBottom GetCenter GetChildren GetEffectiveScale GetFacing
GetFogColor GetFogFar GetFogNear GetFrameLevel GetFrameStrata GetFrameType GetHeight
GetHitRectInsets GetID GetLeft GetLight GetMaxResize GetMinResize GetModel GetModelScale GetName
GetNumChildren GetNumPoints GetNumRegions GetObjectType GetParent GetPoint GetPosition GetRegions
GetRight GetScale GetScript GetTitleRegion GetTop GetWidth HasScript Hide IsClampedToScreen
IsFrameType IsKeyboardEnabled IsMouseEnabled IsMouseWheelEnabled IsMovable IsObjectType IsResizable
IsShown IsToplevel IsUserPlaced IsVisible Lower Raise RefreshUnit RegisterAllEvents RegisterEvent
RegisterForDrag ReplaceIconTexture SetAllPoints SetAlpha SetBackdrop SetBackdropBorderColor
SetBackdropColor SetCamera SetClampedToScreen SetFacing SetFogColor SetFogFar SetFogNear
SetFrameLevel SetFrameStrata SetHeight SetHitRectInsets SetID SetLight SetMaxResize SetMinResize
SetModel SetModelScale SetMovable SetParent SetPoint SetPosition SetResizable SetRotation SetScale
SetScript SetSequence SetSequenceTime SetToplevel SetUnit SetUserPlaced SetWidth Show StartMoving
StartSizing StopMovingOrSizing UnregisterAllEvents UnregisterEvent
```

**Model** (110)

```
AdvanceTime ClearAllPoints ClearFog ClearModel CreateFontString CreateTexture CreateTitleRegion
DisableDrawLayer EnableDrawLayer EnableKeyboard EnableMouse EnableMouseWheel GetAlpha GetBackdrop
GetBackdropBorderColor GetBackdropColor GetBottom GetCenter GetChildren GetEffectiveScale GetFacing
GetFogColor GetFogFar GetFogNear GetFrameLevel GetFrameStrata GetFrameType GetHeight
GetHitRectInsets GetID GetLeft GetLight GetMaxResize GetMinResize GetModel GetModelScale GetName
GetNumChildren GetNumPoints GetNumRegions GetObjectType GetParent GetPoint GetPosition GetRegions
GetRight GetScale GetScript GetTitleRegion GetTop GetWidth HasScript Hide IsClampedToScreen
IsFrameType IsKeyboardEnabled IsMouseEnabled IsMouseWheelEnabled IsMovable IsObjectType IsResizable
IsShown IsToplevel IsUserPlaced IsVisible Lower Raise RegisterAllEvents RegisterEvent
RegisterForDrag ReplaceIconTexture SetAllPoints SetAlpha SetBackdrop SetBackdropBorderColor
SetBackdropColor SetCamera SetClampedToScreen SetFacing SetFogColor SetFogFar SetFogNear
SetFrameLevel SetFrameStrata SetHeight SetHitRectInsets SetID SetLight SetMaxResize SetMinResize
SetModel SetModelScale SetMovable SetParent SetPoint SetPosition SetResizable SetScale SetScript
SetSequence SetSequenceTime SetToplevel SetUserPlaced SetWidth Show StartMoving StartSizing
StopMovingOrSizing UnregisterAllEvents UnregisterEvent
```

**SimpleHTML** (106)

```
ClearAllPoints CreateFontString CreateTexture CreateTitleRegion DisableDrawLayer EnableDrawLayer
EnableKeyboard EnableMouse EnableMouseWheel GetAlpha GetBackdrop GetBackdropBorderColor
GetBackdropColor GetBottom GetCenter GetChildren GetEffectiveScale GetFont GetFontObject
GetFrameLevel GetFrameStrata GetFrameType GetHeight GetHitRectInsets GetHyperlinkFormat GetID
GetJustifyH GetJustifyV GetLeft GetMaxResize GetMinResize GetName GetNumChildren GetNumPoints
GetNumRegions GetObjectType GetParent GetPoint GetRegions GetRight GetScale GetScript
GetShadowColor GetShadowOffset GetSpacing GetTextColor GetTitleRegion GetTop GetWidth HasScript
Hide IsClampedToScreen IsFrameType IsKeyboardEnabled IsMouseEnabled IsMouseWheelEnabled IsMovable
IsObjectType IsResizable IsShown IsToplevel IsUserPlaced IsVisible Lower Raise RegisterAllEvents
RegisterEvent RegisterForDrag SetAllPoints SetAlpha SetBackdrop SetBackdropBorderColor
SetBackdropColor SetClampedToScreen SetFont SetFontObject SetFrameLevel SetFrameStrata SetHeight
SetHitRectInsets SetHyperlinkFormat SetID SetJustifyH SetJustifyV SetMaxResize SetMinResize
SetMovable SetParent SetPoint SetResizable SetScale SetScript SetShadowColor SetShadowOffset
SetSpacing SetText SetTextColor SetToplevel SetUserPlaced SetWidth Show StartMoving StartSizing
StopMovingOrSizing UnregisterAllEvents UnregisterEvent
```

**ColorSelect** (97)

```
ClearAllPoints CreateFontString CreateTexture CreateTitleRegion DisableDrawLayer EnableDrawLayer
EnableKeyboard EnableMouse EnableMouseWheel GetAlpha GetBackdrop GetBackdropBorderColor
GetBackdropColor GetBottom GetCenter GetChildren GetColorRGB GetColorValueTexture
GetColorValueThumbTexture GetColorWheelTexture GetColorWheelThumbTexture GetEffectiveScale
GetFrameLevel GetFrameStrata GetFrameType GetHeight GetHitRectInsets GetID GetLeft GetMaxResize
GetMinResize GetName GetNumChildren GetNumPoints GetNumRegions GetObjectType GetParent GetPoint
GetRegions GetRight GetScale GetScript GetTitleRegion GetTop GetWidth HasScript Hide
IsClampedToScreen IsFrameType IsKeyboardEnabled IsMouseEnabled IsMouseWheelEnabled IsMovable
IsObjectType IsResizable IsShown IsToplevel IsUserPlaced IsVisible Lower Raise RegisterAllEvents
RegisterEvent RegisterForDrag SetAllPoints SetAlpha SetBackdrop SetBackdropBorderColor
SetBackdropColor SetClampedToScreen SetColorRGB SetColorValueTexture SetColorValueThumbTexture
SetColorWheelTexture SetColorWheelThumbTexture SetFrameLevel SetFrameStrata SetHeight
SetHitRectInsets SetID SetMaxResize SetMinResize SetMovable SetParent SetPoint SetResizable
SetScale SetScript SetToplevel SetUserPlaced SetWidth Show StartMoving StartSizing
StopMovingOrSizing UnregisterAllEvents UnregisterEvent
```

**Slider** (97)

```
ClearAllPoints CreateFontString CreateTexture CreateTitleRegion DisableDrawLayer EnableDrawLayer
EnableKeyboard EnableMouse EnableMouseWheel GetAlpha GetBackdrop GetBackdropBorderColor
GetBackdropColor GetBottom GetCenter GetChildren GetEffectiveScale GetFrameLevel GetFrameStrata
GetFrameType GetHeight GetHitRectInsets GetID GetLeft GetMaxResize GetMinMaxValues GetMinResize
GetName GetNumChildren GetNumPoints GetNumRegions GetObjectType GetOrientation GetParent GetPoint
GetRegions GetRight GetScale GetScript GetThumbTexture GetTitleRegion GetTop GetValue GetValueStep
GetWidth HasScript Hide IsClampedToScreen IsFrameType IsKeyboardEnabled IsMouseEnabled
IsMouseWheelEnabled IsMovable IsObjectType IsResizable IsShown IsToplevel IsUserPlaced IsVisible
Lower Raise RegisterAllEvents RegisterEvent RegisterForDrag SetAllPoints SetAlpha SetBackdrop
SetBackdropBorderColor SetBackdropColor SetClampedToScreen SetFrameLevel SetFrameStrata SetHeight
SetHitRectInsets SetID SetMaxResize SetMinMaxValues SetMinResize SetMovable SetOrientation
SetParent SetPoint SetResizable SetScale SetScript SetThumbTexture SetToplevel SetUserPlaced
SetValue SetValueStep SetWidth Show StartMoving StartSizing StopMovingOrSizing UnregisterAllEvents
UnregisterEvent
```

**StatusBar** (97)

```
ClearAllPoints CreateFontString CreateTexture CreateTitleRegion DisableDrawLayer EnableDrawLayer
EnableKeyboard EnableMouse EnableMouseWheel GetAlpha GetBackdrop GetBackdropBorderColor
GetBackdropColor GetBottom GetCenter GetChildren GetEffectiveScale GetFrameLevel GetFrameStrata
GetFrameType GetHeight GetHitRectInsets GetID GetLeft GetMaxResize GetMinMaxValues GetMinResize
GetName GetNumChildren GetNumPoints GetNumRegions GetObjectType GetOrientation GetParent GetPoint
GetRegions GetRight GetScale GetScript GetStatusBarColor GetStatusBarTexture GetTitleRegion GetTop
GetValue GetWidth HasScript Hide IsClampedToScreen IsFrameType IsKeyboardEnabled IsMouseEnabled
IsMouseWheelEnabled IsMovable IsObjectType IsResizable IsShown IsToplevel IsUserPlaced IsVisible
Lower Raise RegisterAllEvents RegisterEvent RegisterForDrag SetAllPoints SetAlpha SetBackdrop
SetBackdropBorderColor SetBackdropColor SetClampedToScreen SetFrameLevel SetFrameStrata SetHeight
SetHitRectInsets SetID SetMaxResize SetMinMaxValues SetMinResize SetMovable SetOrientation
SetParent SetPoint SetResizable SetScale SetScript SetStatusBarColor SetStatusBarTexture
SetToplevel SetUserPlaced SetValue SetWidth Show StartMoving StartSizing StopMovingOrSizing
UnregisterAllEvents UnregisterEvent
```

**ScrollFrame** (96)

```
ClearAllPoints CreateFontString CreateTexture CreateTitleRegion DisableDrawLayer EnableDrawLayer
EnableKeyboard EnableMouse EnableMouseWheel GetAlpha GetBackdrop GetBackdropBorderColor
GetBackdropColor GetBottom GetCenter GetChildren GetEffectiveScale GetFrameLevel GetFrameStrata
GetFrameType GetHeight GetHitRectInsets GetHorizontalScroll GetHorizontalScrollRange GetID GetLeft
GetMaxResize GetMinResize GetName GetNumChildren GetNumPoints GetNumRegions GetObjectType GetParent
GetPoint GetRegions GetRight GetScale GetScript GetScrollChild GetTitleRegion GetTop
GetVerticalScroll GetVerticalScrollRange GetWidth HasScript Hide IsClampedToScreen IsFrameType
IsKeyboardEnabled IsMouseEnabled IsMouseWheelEnabled IsMovable IsObjectType IsResizable IsShown
IsToplevel IsUserPlaced IsVisible Lower Raise RegisterAllEvents RegisterEvent RegisterForDrag
SetAllPoints SetAlpha SetBackdrop SetBackdropBorderColor SetBackdropColor SetClampedToScreen
SetFrameLevel SetFrameStrata SetHeight SetHitRectInsets SetHorizontalScroll SetID SetMaxResize
SetMinResize SetMovable SetParent SetPoint SetResizable SetScale SetScript SetScrollChild
SetToplevel SetUserPlaced SetVerticalScroll SetWidth Show StartMoving StartSizing
StopMovingOrSizing UnregisterAllEvents UnregisterEvent UpdateScrollChildRect
```

**Minimap** (93)

```
ClearAllPoints CreateFontString CreateTexture CreateTitleRegion DisableDrawLayer EnableDrawLayer
EnableKeyboard EnableMouse EnableMouseWheel GetAlpha GetBackdrop GetBackdropBorderColor
GetBackdropColor GetBottom GetCenter GetChildren GetEffectiveScale GetFrameLevel GetFrameStrata
GetFrameType GetHeight GetHitRectInsets GetID GetLeft GetMaxResize GetMinResize GetName
GetNumChildren GetNumPoints GetNumRegions GetObjectType GetParent GetPingPosition GetPoint
GetRegions GetRight GetScale GetScript GetTitleRegion GetTop GetWidth GetZoom GetZoomLevels
HasScript Hide IsClampedToScreen IsFrameType IsKeyboardEnabled IsMouseEnabled IsMouseWheelEnabled
IsMovable IsObjectType IsResizable IsShown IsToplevel IsUserPlaced IsVisible Lower PingLocation
Raise RegisterAllEvents RegisterEvent RegisterForDrag SetAllPoints SetAlpha SetBackdrop
SetBackdropBorderColor SetBackdropColor SetClampedToScreen SetFrameLevel SetFrameStrata SetHeight
SetHitRectInsets SetID SetMaskTexture SetMaxResize SetMinResize SetMovable SetParent SetPoint
SetResizable SetScale SetScript SetToplevel SetUserPlaced SetWidth SetZoom Show StartMoving
StartSizing StopMovingOrSizing UnregisterAllEvents UnregisterEvent
```

**Frame** (87)

```
ClearAllPoints CreateFontString CreateTexture CreateTitleRegion DisableDrawLayer EnableDrawLayer
EnableKeyboard EnableMouse EnableMouseWheel GetAlpha GetBackdrop GetBackdropBorderColor
GetBackdropColor GetBottom GetCenter GetChildren GetEffectiveScale GetFrameLevel GetFrameStrata
GetFrameType GetHeight GetHitRectInsets GetID GetLeft GetMaxResize GetMinResize GetName
GetNumChildren GetNumPoints GetNumRegions GetObjectType GetParent GetPoint GetRegions GetRight
GetScale GetScript GetTitleRegion GetTop GetWidth HasScript Hide IsClampedToScreen IsFrameType
IsKeyboardEnabled IsMouseEnabled IsMouseWheelEnabled IsMovable IsObjectType IsResizable IsShown
IsToplevel IsUserPlaced IsVisible Lower Raise RegisterAllEvents RegisterEvent RegisterForDrag
SetAllPoints SetAlpha SetBackdrop SetBackdropBorderColor SetBackdropColor SetClampedToScreen
SetFrameLevel SetFrameStrata SetHeight SetHitRectInsets SetID SetMaxResize SetMinResize SetMovable
SetParent SetPoint SetResizable SetScale SetScript SetToplevel SetUserPlaced SetWidth Show
StartMoving StartSizing StopMovingOrSizing UnregisterAllEvents UnregisterEvent
```

**MovieFrame** (87)

```
ClearAllPoints CreateFontString CreateTexture CreateTitleRegion DisableDrawLayer EnableDrawLayer
EnableKeyboard EnableMouse EnableMouseWheel GetAlpha GetBackdrop GetBackdropBorderColor
GetBackdropColor GetBottom GetCenter GetChildren GetEffectiveScale GetFrameLevel GetFrameStrata
GetFrameType GetHeight GetHitRectInsets GetID GetLeft GetMaxResize GetMinResize GetName
GetNumChildren GetNumPoints GetNumRegions GetObjectType GetParent GetPoint GetRegions GetRight
GetScale GetScript GetTitleRegion GetTop GetWidth HasScript Hide IsClampedToScreen IsFrameType
IsKeyboardEnabled IsMouseEnabled IsMouseWheelEnabled IsMovable IsObjectType IsResizable IsShown
IsToplevel IsUserPlaced IsVisible Lower Raise RegisterAllEvents RegisterEvent RegisterForDrag
SetAllPoints SetAlpha SetBackdrop SetBackdropBorderColor SetBackdropColor SetClampedToScreen
SetFrameLevel SetFrameStrata SetHeight SetHitRectInsets SetID SetMaxResize SetMinResize SetMovable
SetParent SetPoint SetResizable SetScale SetScript SetToplevel SetUserPlaced SetWidth Show
StartMoving StartSizing StopMovingOrSizing UnregisterAllEvents UnregisterEvent
```

**WorldFrame** (87)

```
ClearAllPoints CreateFontString CreateTexture CreateTitleRegion DisableDrawLayer EnableDrawLayer
EnableKeyboard EnableMouse EnableMouseWheel GetAlpha GetBackdrop GetBackdropBorderColor
GetBackdropColor GetBottom GetCenter GetChildren GetEffectiveScale GetFrameLevel GetFrameStrata
GetFrameType GetHeight GetHitRectInsets GetID GetLeft GetMaxResize GetMinResize GetName
GetNumChildren GetNumPoints GetNumRegions GetObjectType GetParent GetPoint GetRegions GetRight
GetScale GetScript GetTitleRegion GetTop GetWidth HasScript Hide IsClampedToScreen IsFrameType
IsKeyboardEnabled IsMouseEnabled IsMouseWheelEnabled IsMovable IsObjectType IsResizable IsShown
IsToplevel IsUserPlaced IsVisible Lower Raise RegisterAllEvents RegisterEvent RegisterForDrag
SetAllPoints SetAlpha SetBackdrop SetBackdropBorderColor SetBackdropColor SetClampedToScreen
SetFrameLevel SetFrameStrata SetHeight SetHitRectInsets SetID SetMaxResize SetMinResize SetMovable
SetParent SetPoint SetResizable SetScale SetScript SetToplevel SetUserPlaced SetWidth Show
StartMoving StartSizing StopMovingOrSizing UnregisterAllEvents UnregisterEvent
```

**FontString** (51)

```
CanNonSpaceWrap ClearAllPoints GetAlpha GetBottom GetCenter GetDrawLayer GetFont GetFontObject
GetHeight GetJustifyH GetJustifyV GetLeft GetName GetNumPoints GetObjectType GetParent GetPoint
GetRight GetShadowColor GetShadowOffset GetSpacing GetStringWidth GetText GetTextColor GetTop
GetWidth Hide IsObjectType IsShown IsVisible SetAllPoints SetAlpha SetAlphaGradient SetDrawLayer
SetFont SetFontObject SetHeight SetJustifyH SetJustifyV SetNonSpaceWrap SetParent SetPoint
SetShadowColor SetShadowOffset SetSpacing SetText SetTextColor SetTextHeight SetVertexColor
SetWidth Show
```

**Texture** (40)

```
ClearAllPoints GetAlpha GetBlendMode GetBottom GetCenter GetDrawLayer GetHeight GetLeft GetName
GetNumPoints GetObjectType GetParent GetPoint GetRight GetTexCoord GetTexCoordModifiesRect
GetTexture GetTop GetVertexColor GetWidth Hide IsObjectType IsShown IsVisible SetAllPoints SetAlpha
SetBlendMode SetDesaturated SetDrawLayer SetGradient SetGradientAlpha SetHeight SetParent SetPoint
SetTexCoord SetTexCoordModifiesRect SetTexture SetVertexColor SetWidth Show
```

**Font** (22)

```
CopyFontObject GetAlpha GetFont GetFontObject GetJustifyH GetJustifyV GetName GetObjectType
GetShadowColor GetShadowOffset GetSpacing GetTextColor IsObjectType SetAlpha SetFont SetFontObject
SetJustifyH SetJustifyV SetShadowColor SetShadowOffset SetSpacing SetTextColor
```

**TitleRegion** (19)

```
ClearAllPoints GetBottom GetCenter GetHeight GetLeft GetName GetNumPoints GetObjectType GetParent
GetPoint GetRight GetTop GetWidth IsObjectType SetAllPoints SetHeight SetParent SetPoint SetWidth
```

### Standard library bindings

```
abs(number) acos(number) arshift(number) asin(number) assert? atan(number) atan2(number)
band(number) bnot(number) bor(number) bxor(number) byte() | (number) ceil(number) char()
collectgarbage() concat? cos(number) date(nil) | (string?) | (table) debugbreak() debugdump()
debuginfo() debugload() debugprint() debugprofilestart() debugprofilestop(number) debugstack?
debugtimestamp() deg(number) dump() error? exp(number) find(nil) | (number,number) floor(number)
foreach? foreachi? format? frexp(number,number) gcinfo(number,number) geterrorhandler(any) getfenv?
getglobal(any) getmetatable? getn(number) gfind? gsub(number) insert()
ipairs(any,value,number) | (number,any) ldexp(number) len(number) loadstring? log(number)
log10(number) lower() lshift(number) max(number) min(number) mod(number) mod(number) next?
pairs(any,value,nil) pcall? pow(number) rad(number) random(number) randomseed() rawequal(boolean)
rawget? rawset? remove() | (any) rep() rshift(number) seterrorhandler() setfenv? setglobal?
setmetatable? setn() sin(number) sort? sqrt(number) sub(string) tan(number) time?
tonumber(nil) | (number) tostring() | (string) | (string?) | (value) type(string?) unpack? upper()
xpcall?
```

## Events

394 events. `arg1`, `arg2`, ... carry these when it fires.

```
ACTIONBAR_HIDEGRID                       no arguments
ACTIONBAR_PAGE_CHANGED                   no arguments
ACTIONBAR_SHOWGRID                       no arguments
ACTIONBAR_SLOT_CHANGED                   string
ACTIONBAR_UPDATE_COOLDOWN                no arguments
ACTIONBAR_UPDATE_STATE                   no arguments
ACTIONBAR_UPDATE_USABLE                  no arguments
ADDON_ACTION_FORBIDDEN                   string ADDON_LOADED                             string
AREA_SPIRIT_HEALER_IN_RANGE              no arguments
AREA_SPIRIT_HEALER_OUT_OF_RANGE          no arguments
AUCTION_BIDDER_LIST_UPDATE               no arguments
AUCTION_HOUSE_CLOSED                     no arguments
AUCTION_HOUSE_SHOW                       no arguments
AUCTION_ITEM_LIST_UPDATE                 no arguments
AUCTION_OWNED_LIST_UPDATE                no arguments
AUTOEQUIP_BIND_CONFIRM                   string AUTOFOLLOW_BEGIN                         string
AUTOFOLLOW_END                           no arguments
BAG_CLOSED                               string BAG_OPEN                                 string
BAG_UPDATE                               string
BAG_UPDATE_COOLDOWN                      no arguments
BANKFRAME_CLOSED                         no arguments
BANKFRAME_OPENED                         no arguments
BATTLEFIELDS_CLOSED                      no arguments
BATTLEFIELDS_SHOW                        no arguments
BILLING_NAG_DIALOG                       string
BIND_ENCHANT                             no arguments
CANCEL_LOOT_ROLL                         string
CHARACTER_POINTS_CHANGED                 string, string
CHAT_MSG_ADDON                           string, string, string, string
CHAT_MSG_AFK                              CHAT_MSG_BATTLEGROUND
CHAT_MSG_BATTLEGROUND_LEADER              CHAT_MSG_BG_SYSTEM_ALLIANCE
CHAT_MSG_BG_SYSTEM_HORDE                  CHAT_MSG_BG_SYSTEM_NEUTRAL
CHAT_MSG_CHANNEL                          CHAT_MSG_CHANNEL_JOIN
CHAT_MSG_CHANNEL_LEAVE                    CHAT_MSG_CHANNEL_LIST
CHAT_MSG_CHANNEL_NOTICE                   CHAT_MSG_CHANNEL_NOTICE_USER
CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_HITS  CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_MISSES
CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS    CHAT_MSG_COMBAT_CREATURE_VS_PARTY_MISSES
CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS     CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES
CHAT_MSG_COMBAT_FACTION_CHANGE            CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS
CHAT_MSG_COMBAT_FRIENDLYPLAYER_MISSES     CHAT_MSG_COMBAT_FRIENDLY_DEATH
CHAT_MSG_COMBAT_HONOR_GAIN                CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS
CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES      CHAT_MSG_COMBAT_HOSTILE_DEATH
CHAT_MSG_COMBAT_LOG                       CHAT_MSG_COMBAT_MISC_INFO
CHAT_MSG_COMBAT_PARTY_HITS                CHAT_MSG_COMBAT_PARTY_MISSES
CHAT_MSG_COMBAT_PET_HITS                  CHAT_MSG_COMBAT_PET_MISSES
CHAT_MSG_COMBAT_SELF_HITS                 CHAT_MSG_COMBAT_SELF_MISSES
CHAT_MSG_COMBAT_XP_GAIN                   CHAT_MSG_DND
CHAT_MSG_EMOTE                            CHAT_MSG_FILTERED
CHAT_MSG_GUILD                            CHAT_MSG_IGNORED
CHAT_MSG_LOOT                             CHAT_MSG_MONEY
CHAT_MSG_MONSTER_EMOTE                    CHAT_MSG_MONSTER_SAY
CHAT_MSG_MONSTER_WHISPER                  CHAT_MSG_MONSTER_YELL
CHAT_MSG_OFFICER                          CHAT_MSG_PARTY
CHAT_MSG_RAID                             CHAT_MSG_RAID_BOSS_EMOTE
CHAT_MSG_RAID_LEADER                      CHAT_MSG_RAID_WARNING
CHAT_MSG_SAY                              CHAT_MSG_SKILL
CHAT_MSG_SPELL_AURA_GONE_OTHER            CHAT_MSG_SPELL_AURA_GONE_PARTY
CHAT_MSG_SPELL_AURA_GONE_SELF             CHAT_MSG_SPELL_BREAK_AURA
CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF  CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE
CHAT_MSG_SPELL_CREATURE_VS_PARTY_BUFF     CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE
CHAT_MSG_SPELL_CREATURE_VS_SELF_BUFF      CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE
CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS    CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF
CHAT_MSG_SPELL_FAILED_LOCALPLAYER         CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF
CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE      CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF
CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE       CHAT_MSG_SPELL_ITEM_ENCHANTMENTS
CHAT_MSG_SPELL_PARTY_BUFF                 CHAT_MSG_SPELL_PARTY_DAMAGE
CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS    CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE
CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS  CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE
CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS  CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE
CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS       CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE
CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS        CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE
CHAT_MSG_SPELL_PET_BUFF                   CHAT_MSG_SPELL_PET_DAMAGE
CHAT_MSG_SPELL_SELF_BUFF                  CHAT_MSG_SPELL_SELF_DAMAGE
CHAT_MSG_SPELL_TRADESKILLS                CHAT_MSG_SYSTEM
CHAT_MSG_TEXT_EMOTE                       CHAT_MSG_WHISPER
CHAT_MSG_WHISPER_INFORM                   CHAT_MSG_YELL
CINEMATIC_START                          no arguments
CINEMATIC_STOP                           no arguments
CLOSE_INBOX_ITEM                         string
CLOSE_TABARD_FRAME                       no arguments
CLOSE_WORLD_MAP                          no arguments
COMBAT_TEXT_UPDATE                       string, string, string, string, string, string
CONFIRM_BINDER                           string
CONFIRM_LOOT_ROLL                        string, string
CONFIRM_PET_UNLEARN                      string
CONFIRM_SUMMON                           no arguments
CONFIRM_TALENT_WIPE                      string CONFIRM_XP_LOSS                          string
CORPSE_IN_INSTANCE                       no arguments
CORPSE_IN_RANGE                          no arguments
CORPSE_OUT_OF_RANGE                      no arguments
CRAFT_CLOSE                              no arguments
CRAFT_SHOW                               no arguments
CRAFT_UPDATE                             no arguments
CURRENT_SPELL_CAST_CHANGED               no arguments
CURSOR_UPDATE                            no arguments
CVAR_UPDATE                              string, string
DELETE_ITEM_CONFIRM                      string, string
DISPLAY_SIZE_CHANGED                     no arguments
DUEL_FINISHED                            no arguments
DUEL_INBOUNDS                            no arguments
DUEL_OUTOFBOUNDS                         no arguments
DUEL_REQUESTED                           string EQUIP_BIND_CONFIRM                       string
EXECUTE_CHAT_LINE                        string
FRIENDLIST_UPDATE                        no arguments
GMSURVEY_DISPLAY                         no arguments GM_PLAYER_INFO
GOSSIP_CLOSED                            no arguments
GOSSIP_ENTER_CODE                        string
GOSSIP_SHOW                              no arguments
GUILD_INVITE_CANCEL                      no arguments
GUILD_INVITE_REQUEST                     string, string
GUILD_MOTD                               string
GUILD_REGISTRAR_CLOSED                   no arguments
GUILD_REGISTRAR_SHOW                     no arguments
GUILD_ROSTER_UPDATE                      string
IGNORELIST_UPDATE                        no arguments
IGR_BILLING_NAG_DIALOG                   no arguments
INSPECT_HONOR_UPDATE                     no arguments
INSTANCE_BOOT_START                      no arguments
INSTANCE_BOOT_STOP                       no arguments
ITEM_LOCK_CHANGED                        no arguments
ITEM_PUSH                                string, string
ITEM_TEXT_BEGIN                          no arguments
ITEM_TEXT_CLOSED                         no arguments
ITEM_TEXT_READY                          no arguments
ITEM_TEXT_TRANSLATION                    number
LANGUAGE_LIST_CHANGED                    no arguments
LEARNED_SPELL_IN_TAB                     string
LOCALPLAYER_PET_RENAMED                  no arguments
LOGOUT_CANCEL                            no arguments LOOT_BIND_CONFIRM                        u
LOOT_CLOSED                              no arguments
LOOT_OPENED                              no arguments
LOOT_SLOT_CLEARED                        string
LOTTERY_ITEM_UPDATE                      no arguments
LOTTERY_SHOW                             no arguments
MACRO_ACTION_FORBIDDEN                   no arguments
MAIL_CLOSED                              no arguments
MAIL_FAILED                              no arguments
MAIL_INBOX_UPDATE                        no arguments
MAIL_SEND_INFO_UPDATE                    no arguments
MAIL_SEND_SUCCESS                        no arguments
MAIL_SHOW                                no arguments
MEETINGSTONE_CHANGED                     no arguments
MEMORY_EXHAUSTED                         string
MEMORY_RECOVERED                         no arguments
MERCHANT_CLOSED                          no arguments
MERCHANT_SHOW                            no arguments
MERCHANT_UPDATE                          no arguments
MINIGAME_UPDATE                          no arguments
MINIMAP_PING                             string, number, number
MINIMAP_UPDATE_ZOOM                      no arguments
MINIMAP_ZONE_CHANGED                     no arguments
MIRROR_TIMER_PAUSE                       string, string
MIRROR_TIMER_START                       string, string, string, string, string, string
MIRROR_TIMER_STOP                        string
NEW_AUCTION_UPDATE                       no arguments
OPEN_MASTER_LOOT_LIST                    no arguments
OPEN_TABARD_FRAME                        no arguments
PARTY_INVITE_CANCEL                      no arguments
PARTY_INVITE_REQUEST                     string
PARTY_LEADER_CHANGED                     no arguments
PARTY_LOOT_METHOD_CHANGED                no arguments
PARTY_MEMBERS_CHANGED                    no arguments
PARTY_MEMBER_DISABLE                     string PARTY_MEMBER_ENABLE                      string
PETITION_CLOSED                          no arguments
PETITION_SHOW                            no arguments
PET_ATTACK_START                         no arguments
PET_ATTACK_STOP                          no arguments
PET_BAR_HIDEGRID                         no arguments
PET_BAR_SHOWGRID                         no arguments
PET_BAR_UPDATE                           no arguments
PET_BAR_UPDATE_COOLDOWN                  no arguments
PET_DISMISS_START                        string
PET_STABLE_CLOSED                        no arguments
PET_STABLE_SHOW                          no arguments
PET_STABLE_UPDATE                        no arguments
PET_STABLE_UPDATE_PAPERDOLL              no arguments
PET_UI_CLOSE                             no arguments
PET_UI_UPDATE                            no arguments
PLAYERBANKBAGSLOTS_CHANGED               no arguments
PLAYERBANKSLOTS_CHANGED                  string
PLAYER_ALIVE                             no arguments
PLAYER_AURAS_CHANGED                     no arguments
PLAYER_CAMPING                           no arguments
PLAYER_COMBO_POINTS                      no arguments
PLAYER_CONTROL_GAINED                    no arguments
PLAYER_CONTROL_LOST                      no arguments PLAYER_DAMAGE_DONE_MODS
PLAYER_DEAD                              no arguments
PLAYER_ENTERING_WORLD                    no arguments
PLAYER_ENTER_COMBAT                      no arguments
PLAYER_FARSIGHT_FOCUS_CHANGED            no arguments
PLAYER_FLAGS_CHANGED                     string PLAYER_GUILD_UPDATE                      string
PLAYER_LEAVE_COMBAT                      no arguments
PLAYER_LEAVING_WORLD                     no arguments
PLAYER_LEVEL_UP                          string, string, string, string, string, string, string, string, string
PLAYER_LOGIN                             no arguments
PLAYER_LOGOUT                            no arguments
PLAYER_MONEY                             no arguments PLAYER_PVP_KILLS_CHANGED
PLAYER_PVP_RANK_CHANGED                   PLAYER_QUITING                           no arguments
PLAYER_REGEN_DISABLED                    no arguments
PLAYER_REGEN_ENABLED                     no arguments
PLAYER_SKINNED                           string
PLAYER_TARGET_CHANGED                    no arguments
PLAYER_TRADE_MONEY                       no arguments
PLAYER_UNGHOST                           no arguments
PLAYER_UPDATE_RESTING                    no arguments PLAYER_XP_UPDATE
PLAYTIME_CHANGED                         no arguments
QUEST_ACCEPT_CONFIRM                     string, string
QUEST_COMPLETE                           no arguments
QUEST_DETAIL                             no arguments
QUEST_FINISHED                           no arguments
QUEST_GREETING                           no arguments
QUEST_ITEM_UPDATE                        no arguments
QUEST_LOG_UPDATE                         no arguments
QUEST_PROGRESS                           no arguments
QUEST_WATCH_UPDATE                       string
RAID_ROSTER_UPDATE                       no arguments
RAID_TARGET_UPDATE                       no arguments
READY_CHECK                              no arguments
REPLACE_ENCHANT                          string, string
RESURRECT_REQUEST                        string
SCREENSHOT_FAILED                        no arguments
SCREENSHOT_SUCCEEDED                     no arguments
SEND_MAIL_COD_CHANGED                    no arguments
SEND_MAIL_MONEY_CHANGED                  no arguments SHOW_COMPARE_TOOLTIP
SKILL_LINES_CHANGED                      no arguments
SPELLCAST_CHANNEL_START                  string, string
SPELLCAST_CHANNEL_STOP                   no arguments
SPELLCAST_CHANNEL_UPDATE                 string SPELLCAST_DELAYED                        string
SPELLCAST_FAILED                         no arguments
SPELLCAST_INTERRUPTED                    no arguments
SPELLCAST_START                          string, string
SPELLCAST_STOP                           no arguments
SPELLS_CHANGED                           no arguments
SPELL_UPDATE_COOLDOWN                    no arguments
SPELL_UPDATE_USABLE                      no arguments
START_AUTOREPEAT_SPELL                   no arguments
START_LOOT_ROLL                          string, string
START_MINIGAME                           no arguments
STOP_AUTOREPEAT_SPELL                    no arguments SYSMSG
TABARD_CANSAVE_CHANGED                   no arguments
TABARD_SAVE_PENDING                      no arguments
TAXIMAP_CLOSED                           no arguments
TAXIMAP_OPENED                           no arguments
TIME_PLAYED_MSG                          string, string
TRADE_ACCEPT_UPDATE                      string, string
TRADE_CLOSED                             no arguments
TRADE_MONEY_CHANGED                      no arguments
TRADE_PLAYER_ITEM_CHANGED                string
TRADE_REPLACE_ENCHANT                    string, string, string
TRADE_REQUEST                             TRADE_REQUEST_CANCEL                     no arguments
TRADE_SHOW                               no arguments
TRADE_SKILL_CLOSE                        no arguments
TRADE_SKILL_SHOW                         no arguments
TRADE_SKILL_UPDATE                       no arguments
TRADE_TARGET_ITEM_CHANGED                string
TRADE_UPDATE                             no arguments
TRAINER_CLOSED                           no arguments
TRAINER_SHOW                             no arguments
TRAINER_UPDATE                           no arguments
TUTORIAL_TRIGGER                         string UI_ERROR_MESSAGE                         string
UI_INFO_MESSAGE                          string UNIT_ATTACK                              string
UNIT_ATTACK_POWER                        string UNIT_ATTACK_SPEED                        string
UNIT_AURA                                string UNIT_CLASSIFICATION_CHANGED              string
UNIT_COMBAT                              string, string, string, string, string
UNIT_DAMAGE                              string UNIT_DEFENSE                             string
UNIT_DISPLAYPOWER                        string UNIT_DYNAMIC_FLAGS                       string
UNIT_ENERGY                              string UNIT_FACTION                             string
UNIT_FLAGS                               string UNIT_FOCUS                               string
UNIT_HAPPINESS                           string UNIT_HEALTH                              string
UNIT_INVENTORY_CHANGED                   string UNIT_LEVEL                               string
UNIT_LOYALTY                             string UNIT_MANA                                string
UNIT_MAXENERGY                           string UNIT_MAXFOCUS                            string
UNIT_MAXHAPPINESS                        string UNIT_MAXHEALTH                           string
UNIT_MAXMANA                             string UNIT_MAXRAGE                             string
UNIT_MODEL_CHANGED                       string UNIT_NAME_UPDATE                         string
UNIT_PET                                 string UNIT_PET_EXPERIENCE                      string
UNIT_PET_TRAINING_POINTS                 string UNIT_PORTRAIT_UPDATE                     string
UNIT_QUEST_LOG_CHANGED                   string UNIT_RAGE                                string
UNIT_RANGEDDAMAGE                        string UNIT_RANGED_ATTACK_POWER                 string
UNIT_RESISTANCES                         string UNIT_STATS                               string
UPDATE_BATTLEFIELD_SCORE                 no arguments
UPDATE_BATTLEFIELD_STATUS                no arguments
UPDATE_BINDINGS                          no arguments
UPDATE_BONUS_ACTIONBAR                   no arguments
UPDATE_CHAT_COLOR                        string, number, number, number
UPDATE_CHAT_WINDOWS                      no arguments
UPDATE_EXHAUSTION                        no arguments
UPDATE_FACTION                           no arguments
UPDATE_GM_STATUS                         string
UPDATE_INSTANCE_INFO                     no arguments
UPDATE_INVENTORY_ALERTS                  no arguments UPDATE_LFG
UPDATE_LFG_LIST                          no arguments
UPDATE_LFG_TYPES                         no arguments
UPDATE_MACROS                            no arguments
UPDATE_MASTER_LOOT_LIST                  no arguments
UPDATE_MOUSEOVER_UNIT                    no arguments
UPDATE_PENDING_MAIL                      no arguments
UPDATE_SHAPESHIFT_FORMS                  no arguments
UPDATE_TICKET                            string, string, string, string, number, number, number, string, string
UPDATE_TRADESKILL_RECAST                 no arguments
UPDATE_WORLD_STATES                      no arguments
USE_BIND_CONFIRM                         no arguments
VARIABLES_LOADED                         no arguments
WHO_LIST_UPDATE                          no arguments
WORLD_MAP_NAME_UPDATE                    no arguments
WORLD_MAP_UPDATE                         no arguments
ZONE_CHANGED                             no arguments
ZONE_CHANGED_INDOORS                     no arguments
ZONE_CHANGED_NEW_AREA                    no arguments
```

## CVars

381, with their default and the client's own help text. The `hud*` and
`meter*` ones are the run's own display settings and are the ones an addon
usually wants to read or mirror.

```
?                                    = 0          ?                                    = ?
AmbienceVolume                       = 0.6       Ambience Volume (0.0 to 1.0)
AutoInteract                         = 1|0       Toggles auto-move to interact target
BlockTrades                          = 0
ChatBubbles                          = 1         Toggles showing in-game chat bubbles
ChatBubblesParty                     = 0
CombatDamage                         = 1         Toggles all damage numbers over a creature
CombatDeathLogRange                  = 60         CombatLogPeriodicSpells              = 1
CombatLogRangeCreature               = 30         CombatLogRangeFriendlyPlayers        = 50
CombatLogRangeFriendlyPlayersPets    = 50         CombatLogRangeHostilePlayers         = 50
CombatLogRangeHostilePlayersPets     = 50         CombatLogRangeParty                  = 50
CombatLogRangePartyPet               = 50
CombatModeMaxDistance                = 30.0f     Specifies the range outside of which combat mode is impossible
DesktopGamma                         = 0
DistCull                             = 500       Object distance culling
EmoteSounds                          = 1
EnableAmbience                       = 1         Enable Ambience
EnableErrorSpeech                    = 1         error speech
EnableGroupSpeech                    = 1         voice macros
EnableMusic                          = 1         Enables music
ErrorFilter                          = all        ErrorLevelMax                        = 3
ErrorLevelMin                        = 1          Errors                               = 0
FootstepSounds                       = 1          Gamma                                = 1.0
Joystick                             = 0         enable joystick control
M2BatchDoodads                       = 1         combine doodads to reduce batch count
M2Faster                             = 1         end user control of scene optimization mode - (0-3)
M2FasterDebug                        = 0         programmer control of scene optimization mode
M2UseClipPlanes                      = 1         use clip planes for sorting transparent objects
M2UsePixelShaders                    = 0         light models using pixel shaders
M2UseShaders                         = 1         skin models using vertex shaders
M2UseThreads                         = 1         multithread model animations
M2UseZFill                           = 1         z-fill transparent objects
MapWaterSounds                       = 1          MasterSoundEffects                   = 1
MasterVolume                         = 1.0       master volume (0.0 to 1.0)
MaxLights                            = 4         Max number of hardware lights
MusicVolume                          = 0.4       music volume (0.0 to 1.0)
ObjectSelectionCircle                = 1
PetMeleeDamage                       = 1         Toggle display of in-world pet melee damage feedback
PetSpellDamage                       = 1         Toggle display of in-world pet spell damage feedback
PlayerAnim                           = 0         Toggle display of player anims in the debug window
PlayerFadeInRate                     = 4096      fade in rate for player mouseover
PlayerFadeOutAlpha                   = 128       min fade out alpha for player mouseover
PlayerFadeOutRate                    = 4096      fade out rate for player mouseover
ShowErrors                           = 1          SkyCloudLOD                          = 0
SmallCull                            = 0.04      Object size culling
SoundBufferSize                      = ?         sound buffer size (milliseconds)
SoundDriver                          = -1        sound driver
SoundInitFlags                       = 128       sound initialization flags
SoundListenerAtCharacter             = 1         lock listener at character
SoundMaxHardwareChannels             = 12        sound maximum hardware channels
SoundMemoryCache                     = 4         sound cache memory size (MB)
SoundMinHardwareChannels             = -1        sound minimum hardware channels
SoundMixRate                         = 44100     sound mix rate (Hz)
SoundMixer                           = -1        sound mixer
SoundOutputSystem                    = -1        sound output system
SoundReverb                          = 1
SoundRolloffFactor                   = 4         sound rolloff factor
SoundSoftwareChannels                = 12        sound software channels
SoundVolume                          = 1.0       sound volume (0.0 to 1.0)
SoundZoneMusicNoDelay                = 0
TargetAnim                           = 0         Toggle display of player's target anims in the debug window
UberTooltips                         = 1         Toggles ubertips
UnitNameNPC                          = 0          UnitNameOwn                          = 0
UnitNamePlayer                       = 1          UnitNamePlayerGuild                  = 1
UnitNamePlayerPVPTitle               = 1
UnitNameRenderMode                   = 2         sets unitname mode (0=none,1=lockedunits/lockedplayers, 2=player
accountName                          =           Saved account name
anisotropic                          = 1         Anisotropic texture filtering
assistAttack                         = 0
autoClearAFK                         = 1         Automatically clear AFK when moving or chatting
autoSelfCast                         = 0          automoveturnspeednarrow              = 800
automoveturnspeedwide                = 1200
baseMip                              = 0         base mipmap level
bspcache                             = 1         BSP node caching
cameraBobbing                        = 0          cameraBobbingFrequency               = 0.8
cameraBobbingLRAmplitude             = 2.0        cameraBobbingSmoothSpeed             = 0.8
cameraBobbingUDAmplitude             = 2.0        cameraCustomViewSmoothing            = 0
cameraDistance                       = 0.0        cameraDistanceA                      = 5.55
cameraDistanceB                      = 5.55       cameraDistanceC                      = 13.88
cameraDistanceD                      = 13.88      cameraDistanceMax                    = 15.0
cameraDistanceMaxFactor              = 1.0        cameraDistanceMoveSpeed              = 8.33
cameraDistanceSmoothSpeed            = 8.33       cameraDive                           = 1
cameraFoVSmoothSpeed                 = 0.5        cameraGroundSmoothSpeed              = 7.5
cameraHeightIgnoreStandState         = 0          cameraHeightSmoothSpeed              = 1.2
cameraPitch                          = 0.0        cameraPitchA                         = 10.0
cameraPitchB                         = 20.0       cameraPitchC                         = 30.0
cameraPitchD                         = 10.0       cameraPitchMoveSpeed                 = 90.0
cameraPitchSmoothMax                 = 30.0       cameraPitchSmoothMin                 = 0.0
cameraPitchSmoothSpeed               = 45.0       cameraPivot                          = 1
cameraPivotDXMax                     = 0.05       cameraPivotDYMin                     = 0.00
cameraSmoothAlwaysFearDelay          = 0.0        cameraSmoothAlwaysFearFactor         = 1.0
cameraSmoothAlwaysIdleDelay          = 0.0        cameraSmoothAlwaysIdleFactor         = 1.0
cameraSmoothAlwaysMoveDelay          = 0.0        cameraSmoothAlwaysMoveFactor         = 1.0
cameraSmoothAlwaysStopDelay          = 0.0        cameraSmoothAlwaysStopFactor         = 1.0
cameraSmoothAlwaysStrafeDelay        = 0.0        cameraSmoothAlwaysStrafeFactor       = 1.0
cameraSmoothAlwaysTrackDelay         = 0.0        cameraSmoothAlwaysTrackFactor        = 1.0
cameraSmoothAlwaysTurnDelay          = 0.0        cameraSmoothAlwaysTurnFactor         = 1.0
cameraSmoothNeverFearDelay           = 0.0        cameraSmoothNeverFearFactor          = 0.0
cameraSmoothNeverIdleDelay           = 0.0        cameraSmoothNeverIdleFactor          = 0.0
cameraSmoothNeverMoveDelay           = 0.0        cameraSmoothNeverMoveFactor          = 0.0
cameraSmoothNeverStopDelay           = 0.0        cameraSmoothNeverStopFactor          = 0.0
cameraSmoothNeverStrafeDelay         = 0.0        cameraSmoothNeverStrafeFactor        = 0.0
cameraSmoothNeverTrackDelay          = 0.0        cameraSmoothNeverTrackFactor         = 0.0
cameraSmoothNeverTurnDelay           = 0.0        cameraSmoothNeverTurnFactor          = 0.0
cameraSmoothPitch                    = 0          cameraSmoothSmartFearDelay           = 0.4
cameraSmoothSmartFearFactor          = 10.0       cameraSmoothSmartIdleDelay           = 0.0
cameraSmoothSmartIdleFactor          = 0.0        cameraSmoothSmartMoveDelay           = 0.0
cameraSmoothSmartMoveFactor          = 1.0        cameraSmoothSmartStopDelay           = 0.0
cameraSmoothSmartStopFactor          = 0.0        cameraSmoothSmartStrafeDelay         = 0.0
cameraSmoothSmartStrafeFactor        = 1.0        cameraSmoothSmartTrackDelay          = 0.4
cameraSmoothSmartTrackFactor         = 10.0       cameraSmoothSmartTurnDelay           = 0.0
cameraSmoothSmartTurnFactor          = 1.0        cameraSmoothStyle                    = 1
cameraSmoothTimeMax                  = 2.0        cameraSmoothTimeMin                  = 0.1
cameraSmoothTrackingStyle            = 1
cameraSmoothViewDataAlwaysDistanceDelay = 0.0
cameraSmoothViewDataAlwaysDistanceFactor = 0.0
cameraSmoothViewDataAlwaysPitchDelay = 0.0
cameraSmoothViewDataAlwaysPitchFactor = 0.0
cameraSmoothViewDataAlwaysYawDelay   = 0.0        cameraSmoothViewDataAlwaysYawFactor  = 1.0
cameraSmoothViewDataNeverDistanceDelay = 0.0
cameraSmoothViewDataNeverDistanceFactor = 0.0
cameraSmoothViewDataNeverPitchDelay  = 0.0        cameraSmoothViewDataNeverPitchFactor = 0.0
cameraSmoothViewDataNeverYawDelay    = 0.0        cameraSmoothViewDataNeverYawFactor   = 0.0
cameraSmoothViewDataSmartDistanceDelay = 0.0
cameraSmoothViewDataSmartDistanceFactor = 0.0
cameraSmoothViewDataSmartPitchDelay  = 0.0        cameraSmoothViewDataSmartPitchFactor = 1.0
cameraSmoothViewDataSmartYawDelay    = 0.0        cameraSmoothViewDataSmartYawFactor   = 1.0
cameraSmoothYaw                      = 1          cameraSubmergeFinalPitch             = 5.0
cameraSubmergePitch                  = 18.0       cameraSurfaceFinalPitch              = 5.0
cameraSurfacePitch                   = 0.0        cameraTargetSmoothSpeed              = 90.0
cameraTerrainTilt                    = 0          cameraTerrainTiltAlwaysFallAbsorb    = 1.0
cameraTerrainTiltAlwaysFallDelay     = 0.0        cameraTerrainTiltAlwaysFallFactor    = 0.75
cameraTerrainTiltAlwaysFearAbsorb    = 1.0        cameraTerrainTiltAlwaysFearDelay     = 0.0
cameraTerrainTiltAlwaysFearFactor    = 1.0        cameraTerrainTiltAlwaysIdleAbsorb    = 1.0
cameraTerrainTiltAlwaysIdleDelay     = 0.0        cameraTerrainTiltAlwaysIdleFactor    = 1.0
cameraTerrainTiltAlwaysJumpAbsorb    = 0.0        cameraTerrainTiltAlwaysJumpDelay     = 0.0
cameraTerrainTiltAlwaysJumpFactor    = -1.0       cameraTerrainTiltAlwaysMoveAbsorb    = 1.0
cameraTerrainTiltAlwaysMoveDelay     = 0.0        cameraTerrainTiltAlwaysMoveFactor    = 1.0
cameraTerrainTiltAlwaysStrafeAbsorb  = 1.0        cameraTerrainTiltAlwaysStrafeDelay   = 0.0
cameraTerrainTiltAlwaysStrafeFactor  = 1.0        cameraTerrainTiltAlwaysSwimAbsorb    = 0.0
cameraTerrainTiltAlwaysSwimDelay     = 0.0        cameraTerrainTiltAlwaysSwimFactor    = 1.0
cameraTerrainTiltAlwaysTaxiAbsorb    = 0.0        cameraTerrainTiltAlwaysTaxiDelay     = 0.0
cameraTerrainTiltAlwaysTaxiFactor    = 1.0        cameraTerrainTiltAlwaysTrackAbsorb   = 1.0
cameraTerrainTiltAlwaysTrackDelay    = 0.0        cameraTerrainTiltAlwaysTrackFactor   = 1.0
cameraTerrainTiltAlwaysTurnAbsorb    = 1.0        cameraTerrainTiltAlwaysTurnDelay     = 0.0
cameraTerrainTiltAlwaysTurnFactor    = 1.0        cameraTerrainTiltNeverFallAbsorb     = 0.0
cameraTerrainTiltNeverFallDelay      = 0.0        cameraTerrainTiltNeverFallFactor     = -1.0
cameraTerrainTiltNeverFearAbsorb     = 0.0        cameraTerrainTiltNeverFearDelay      = 0.0
cameraTerrainTiltNeverFearFactor     = -1.0       cameraTerrainTiltNeverIdleAbsorb     = 0.0
cameraTerrainTiltNeverIdleDelay      = 0.0        cameraTerrainTiltNeverIdleFactor     = -1.0
cameraTerrainTiltNeverJumpAbsorb     = 0.0        cameraTerrainTiltNeverJumpDelay      = 0.0
cameraTerrainTiltNeverJumpFactor     = -1.0       cameraTerrainTiltNeverMoveAbsorb     = 0.0
cameraTerrainTiltNeverMoveDelay      = 0.0        cameraTerrainTiltNeverMoveFactor     = -1.0
cameraTerrainTiltNeverStrafeAbsorb   = 0.0        cameraTerrainTiltNeverStrafeDelay    = 0.0
cameraTerrainTiltNeverStrafeFactor   = -1.0       cameraTerrainTiltNeverSwimAbsorb     = 0.0
cameraTerrainTiltNeverSwimDelay      = 0.0        cameraTerrainTiltNeverSwimFactor     = -1.0
cameraTerrainTiltNeverTaxiAbsorb     = 0.0        cameraTerrainTiltNeverTaxiDelay      = 0.0
cameraTerrainTiltNeverTaxiFactor     = -1.0       cameraTerrainTiltNeverTrackAbsorb    = 0.0
cameraTerrainTiltNeverTrackDelay     = 0.0        cameraTerrainTiltNeverTrackFactor    = -1.0
cameraTerrainTiltNeverTurnAbsorb     = 0.0        cameraTerrainTiltNeverTurnDelay      = 0.0
cameraTerrainTiltNeverTurnFactor     = -1.0       cameraTerrainTiltSmartFallAbsorb     = 1.0
cameraTerrainTiltSmartFallDelay      = 0.0        cameraTerrainTiltSmartFallFactor     = 0.75
cameraTerrainTiltSmartFearAbsorb     = 1.0        cameraTerrainTiltSmartFearDelay      = 0.0
cameraTerrainTiltSmartFearFactor     = 1.0        cameraTerrainTiltSmartIdleAbsorb     = 0.0
cameraTerrainTiltSmartIdleDelay      = 0.0        cameraTerrainTiltSmartIdleFactor     = -1.0
cameraTerrainTiltSmartJumpAbsorb     = 0.0        cameraTerrainTiltSmartJumpDelay      = 0.0
cameraTerrainTiltSmartJumpFactor     = -1.0       cameraTerrainTiltSmartMoveAbsorb     = 1.0
cameraTerrainTiltSmartMoveDelay      = 0.0        cameraTerrainTiltSmartMoveFactor     = 1.0
cameraTerrainTiltSmartStrafeAbsorb   = 1.0        cameraTerrainTiltSmartStrafeDelay    = 0.0
cameraTerrainTiltSmartStrafeFactor   = 1.0        cameraTerrainTiltSmartSwimAbsorb     = 0.0
cameraTerrainTiltSmartSwimDelay      = 0.0        cameraTerrainTiltSmartSwimFactor     = 1.0
cameraTerrainTiltSmartTaxiAbsorb     = 0.0        cameraTerrainTiltSmartTaxiDelay      = 0.0
cameraTerrainTiltSmartTaxiFactor     = 1.0        cameraTerrainTiltSmartTrackAbsorb    = 1.0
cameraTerrainTiltSmartTrackDelay     = 0.0        cameraTerrainTiltSmartTrackFactor    = 1.0
cameraTerrainTiltSmartTurnAbsorb     = 1.0        cameraTerrainTiltSmartTurnDelay      = 0.0
cameraTerrainTiltSmartTurnFactor     = 1.0        cameraTerrainTiltTimeMax             = 10.0
cameraTerrainTiltTimeMin             = 3.0        cameraView                           = 1
cameraViewBlendStyle                 = 1          cameraWaterCollision                 = 1
cameraYaw                            = 0.0        cameraYawA                           = 0.0
cameraYawB                           = 0.0        cameraYawC                           = 0.0
cameraYawD                           = 0.0        cameraYawMoveSpeed                   = 180.0
cameraYawSmoothMax                   = 0.0        cameraYawSmoothMin                   = 0.0
cameraYawSmoothSpeed                 = 180.0      camerasmooth                         = 1
checkAddonVersion                    = 1         Check interface addon version number
combatLogOn                          = 1          debugTaint                           = 0
deselectOnClick                      = 1
disableOptionalSpeech                = 0         Disables the optional speech packs (forces use of primary speech
doodadAnim                           = 1         Video option: Toggle doodad anim
farclip                              = 350       Far clip plane distance
ffx                                  = 1         full screen effects
ffxDeath                             = 1         full screen death effect
ffxGlow                              = 1         full screen glow effect
ffxRectangle                         = 1         use rectangle texture for full screen effects
footstepBias                         = 0.125     Unit footstep depth bias
frillDensity                         = 16        Terrain frill density
fullAlpha                            = 0         Video option: Toggle full alpha
gameTip                              = 0
guildMemberNotify                    = 0         Receive notification when guild members log on/off
gxApi                                = direct3d  graphics api
gxAspect                             = 1         constrain window aspect ratio
gxColorBits                          = 16        color bits
gxCursor                             = 1         toggle hardware cursor
gxDepthBits                          = 16        depth bits
gxFixLag                             = ?         prevent cursor lag
gxMaximize                           = 1|0       maximize game window
gxMultisample                        = ?         multisample antialiasing
gxMultisampleQuality                 = 0.0       multisample antialiasing quality
gxOverride                           =           gx overrides
gxRefresh                            = 75        refresh rate
gxResolution                         = 640x480   resolution
gxTripleBuffer                       = 0         triple buffer
gxVSync                              = 1         vsync on or off
gxWindow                             = 1|0       toggle fullscreen/window
horizonfarclip                       = 2112      Far clip plane distance for horizon
hwDetect                             = 1         do hardware detection
lastCharacterIndex                   = 0         Last character selected
lod                                  = 1         Video option: Toggle Lod
lodDist                              = 100.0     Video option: Set Lod distance
mapObjLightLOD                       = 0         Map object light LOD
mapObjOverbright                     = 1         Map object overbright
mapShadows                           = 1         Video option: Toggle map shadows
minimapInsideZoom                    = 3          minimapZoom                          = 3
mouseInvertPitch                     = 0          mouseInvertYaw                       = 0
mouseSpeed                           = ?
movie                                = 1         Show movie on startup
movieSubtitle                        = 0         Show movie subtitles
nearclip                             = 0.1       Near clip plane distance
occlusion                            = 1         Use hardware occlusion test
particleDensity                      = 1.0       Video option: Particle density
pixelShaders                         = 0         Use pixel shaders
profanityFilter                      = 1         Toggle profanity filter
readContest                          = 0         Status of the Contest notice
readEULA                             = 0         Status of the EULA
readScanning                         = 0         Status of the Scanning notice
readTOS                              = 0         Status of the TOS
realmList                            = us.logon.worldofwarcraft.com:3724 Address of realm list server
realmName                            =           Last realm connected to
scriptMemory                         = 49152     Memory used by the scripting system (in Kb)
shadowBias                           = 0.1       Unit shadow depth bias
shadowLOD                            = 1         Unit shadow LOD
shadowLevel                          = 1         Terrain shadow map mip level
showGameTips                         = 1          showLootSpam                         = 1
showfootprintparticles               = 1         toggles rendering of footprint particles
showfootprints                       = 1         toggles rendering of footprints
showsmartrects                       = 0         Toggle display of SmartScreenRects
spamFilter                           = 1         Toggle spam filter
specular                             = 0         Specularity
spellEffectLevel                     = 2         Video Option: Spell Effects
statusBarText                        = 0          targetNearestDistance                = ?
targetNearestDistanceRadius          = ?
texLodBias                           = 0.0       Texture LOD Bias
textureLodDist                       = 777.0     Video option: texture detail
timingModeOverride                   = 0         Select a specific timing mode (0=default 1=GetTickCount 2=RDTSC
triangleStrips                       = 1         Use triangle strips to render
trilinear                            = 0         Enable Trilinear texture filtering
uiScale                              = 1.0
unitDrawDist                         = 300.0     Unit draw distance
useUiScale                           = 0          useWeatherShaders                    = 1
violenceLevel                        = ?         Sets the violence level of the game
waterLOD                             = 0         Water geometry LOD
weatherDensity                       = 2
widescreen                           = 1         Allow widescreen support
```

## Chat message types

465 keys, with the chat type each routes to. This game talks over
`CHAT_MSG_ADDON`; the list is here so you know what else can arrive.

```
ERR_2HANDED_EQUIPPED                       chat=10
ERR_2HSKILLNOTFOUND                        chat=10
ERR_ABILITY_COOLDOWN                       chat=10
ERR_ALREADY_INVITED_TO_GUILD_S             chat=10
ERR_ALREADY_IN_GROUP_S                     chat=10
ERR_ALREADY_IN_GUILD                       chat=10
ERR_ALREADY_IN_GUILD_S                     chat=10
ERR_ALREADY_TRADING                        chat=10
ERR_AMMO_ONLY                              chat=10
ERR_APPROACHING_NO_PLAY_TIME               chat=10
ERR_APPROACHING_PARTIAL_PLAY_TIME          chat=10
ERR_ATTACK_CHARMED                         chat=10
ERR_ATTACK_CONFUSED                        chat=10
ERR_ATTACK_DEAD                            chat=10
ERR_ATTACK_FLEEING                         chat=10
ERR_ATTACK_MOUNTED                         chat=10
ERR_ATTACK_PACIFIED                        chat=10
ERR_ATTACK_PREVENTED_BY_MECHANIC_S         chat=10
ERR_ATTACK_STUNNED                         chat=10
ERR_AUCTION_BAG                            chat=10
ERR_AUCTION_BID_INCREMENT                  chat=10
ERR_AUCTION_BID_OWN                        chat=10
ERR_AUCTION_BID_PLACED                     chat=10
ERR_AUCTION_BOUND_ITEM                     chat=10
ERR_AUCTION_CONJURED_ITEM                  chat=10
ERR_AUCTION_DATABASE_ERROR                 chat=10
ERR_AUCTION_EXPIRED_S                      chat=10
ERR_AUCTION_HIGHER_BID                     chat=10
ERR_AUCTION_LOOT_ITEM                      chat=10
ERR_AUCTION_MIN_BID                        chat=10
ERR_AUCTION_OUTBID_S                       chat=10
ERR_AUCTION_QUEST_ITEM                     chat=10
ERR_AUCTION_REMOVED                        chat=10
ERR_AUCTION_REMOVED_S                      chat=10
ERR_AUCTION_REPAIR_ITEM                    chat=10
ERR_AUCTION_SOLD_S                         chat=10
ERR_AUCTION_STARTED                        chat=10
ERR_AUCTION_WON_S                          chat=10
ERR_AUCTION_WRAPPED_ITEM                   chat=10
ERR_AUTOFOLLOW_TOO_FAR                     chat=10
ERR_AUTOLOOT_MONEY_S                       chat=10
ERR_BADATTACKFACING                        chat=10
ERR_BADATTACKPOS                           chat=10
ERR_BAD_PLAYER_NAME_S                      chat=10
ERR_BAG_FULL                               chat=10
ERR_BAG_IN_BAG                             chat=10
ERR_BANKSLOT_FAILED_TOO_MANY               chat=10
ERR_BANKSLOT_INSUFFICIENT_FUNDS            chat=10
ERR_BANKSLOT_NOTBANKER                     chat=10
ERR_BANK_FULL                              chat=10
ERR_BG_PLAYER_JOINED_SS                    chat=10
ERR_BG_PLAYER_LEFT_S                       chat=10
ERR_BUTTON_LOCKED                          chat=10
ERR_CANNOTCREATEDIRECTORY                  chat=10
ERR_CANNOTCREATEFILE                       chat=10
ERR_CANT_BE_DISENCHANTED                   chat=10
ERR_CANT_EQUIP_EVER                        chat=10
ERR_CANT_EQUIP_LEVEL_I                     chat=10
ERR_CANT_EQUIP_RANK                        chat=10
ERR_CANT_EQUIP_REPUTATION                  chat=10
ERR_CANT_EQUIP_SKILL                       chat=10
ERR_CANT_INTERACT_SHAPESHIFTED             chat=10
ERR_CANT_STACK                             chat=10
ERR_CANT_SWAP                              chat=10
ERR_CANT_USE_DISARMED                      chat=10
ERR_CANT_USE_ITEM                          chat=10
ERR_CANT_WRAP_BAGS                         chat=10
ERR_CANT_WRAP_BOUND                        chat=10
ERR_CANT_WRAP_EQUIPPED                     chat=10
ERR_CANT_WRAP_STACKABLE                    chat=10
ERR_CANT_WRAP_UNIQUE                       chat=10
ERR_CANT_WRAP_WRAPPED                      chat=10
ERR_CHAT_PLAYER_AMBIGUOUS_S                chat=10
ERR_CHAT_PLAYER_NOT_FOUND_S                chat=10
ERR_CHAT_RESTRICTED                        chat=10
ERR_CHAT_WHILE_DEAD                        chat=10
ERR_CHAT_WRONG_FACTION                     chat=10
ERR_CHEST_IN_USE                           chat=10
ERR_CLICK_ON_ITEM_TO_FEED                  chat=10
ERR_CLIENT_LOCKED_OUT                      chat=10
ERR_COMBAT_DAMAGE_SSI                      chat=10
ERR_COMMAND_NEEDS_TARGET                   chat=10
ERR_DEATHBINDALREADYBOUND                  chat=10
ERR_DEATHBIND_SUCCESS_S                    chat=10
ERR_DECLINE_GROUP_S                        chat=10
ERR_DESTROY_NONEMPTY_BAG                   chat=10
ERR_DISMOUNT_NOPET                         chat=10
ERR_DISMOUNT_NOTMOUNTED                    chat=10
ERR_DISMOUNT_NOTYOURPET                    chat=10
ERR_DOOR_LOCKED                            chat=10
ERR_DROP_BOUND_ITEM                        chat=10
ERR_DUEL_CANCELLED                         chat=10
ERR_DUEL_REQUESTED                         chat=10
ERR_DUNGEON_DIFFICULTY_CHANGED_S           chat=10
ERR_DUNGEON_DIFFICULTY_FAILED              chat=10
ERR_EMBLEMERROR_NOTABARDGEOSET             chat=10
ERR_EQUIP_TRADE_ITEM                       chat=10
ERR_EXHAUSTION_EXHAUSTED                   chat=10
ERR_EXHAUSTION_NORMAL                      chat=10
ERR_EXHAUSTION_RESTED                      chat=10
ERR_EXHAUSTION_TIRED                       chat=10
ERR_EXHAUSTION_WELLRESTED                  chat=10
ERR_FEIGN_DEATH_RESISTED                   chat=10
ERR_FILTERING_YOU_S                        chat=10
ERR_FISH_ESCAPED                           chat=10
ERR_FISH_NOT_HOOKED                        chat=10
ERR_FOOD_COOLDOWN                          chat=10
ERR_FRIEND_ADDED_S                         chat=10
ERR_FRIEND_ALREADY_S                       chat=10
ERR_FRIEND_DB_ERROR                        chat=10
ERR_FRIEND_ERROR                           chat=10
ERR_FRIEND_LIST_FULL                       chat=10
ERR_FRIEND_NOT_FOUND                       chat=10
ERR_FRIEND_OFFLINE_S                       chat=10
ERR_FRIEND_ONLINE_SS                       chat=10
ERR_FRIEND_REMOVED_S                       chat=10
ERR_FRIEND_SELF                            chat=10
ERR_FRIEND_WRONG_FACTION                   chat=10
ERR_GENERIC_NO_TARGET                      chat=10
ERR_GENERIC_STUNNED                        chat=10
ERR_GROUP_DISBANDED                        chat=10
ERR_GROUP_FULL                             chat=10
ERR_GROUP_JOIN_BATTLEGROUND_DESERTERS      chat=10
ERR_GROUP_JOIN_BATTLEGROUND_FAIL           chat=10
ERR_GROUP_JOIN_BATTLEGROUND_S              chat=10
ERR_GROUP_JOIN_BATTLEGROUND_TOO_MANY       chat=10
ERR_GUILDEMBLEM_INVALIDVENDOR              chat=10
ERR_GUILDEMBLEM_INVALID_TABARD_COLORS      chat=10
ERR_GUILDEMBLEM_NOGUILD                    chat=10
ERR_GUILDEMBLEM_NOTENOUGHMONEY             chat=10
ERR_GUILDEMBLEM_NOTGUILDMASTER             chat=10
ERR_GUILDEMBLEM_SAME                       chat=10
ERR_GUILDEMBLEM_SUCCESS                    chat=10
ERR_GUILD_ACCEPT                           chat=10
ERR_GUILD_CANT_DEMOTE_S                    chat=10
ERR_GUILD_CANT_PROMOTE_S                   chat=10
ERR_GUILD_CREATE_S                         chat=10
ERR_GUILD_DECLINE_S                        chat=10
ERR_GUILD_DEMOTE_SSS                       chat=10
ERR_GUILD_DISBANDED                        chat=10
ERR_GUILD_DISBAND_S                        chat=10
ERR_GUILD_DISBAND_SELF                     chat=10
ERR_GUILD_ENTER_NAME                       chat=10
ERR_GUILD_FOUNDER_S                        chat=10
ERR_GUILD_INTERNAL                         chat=10
ERR_GUILD_INVITE_S                         chat=10
ERR_GUILD_JOIN_S                           chat=10
ERR_GUILD_LEADER_CHANGED_SS                chat=10
ERR_GUILD_LEADER_IS_S                      chat=10
ERR_GUILD_LEADER_LEAVE                     chat=10
ERR_GUILD_LEADER_S                         chat=10
ERR_GUILD_LEADER_SELF                      chat=10
ERR_GUILD_LEAVE_S                          chat=10
ERR_GUILD_NAME_EXISTS_S                    chat=10
ERR_GUILD_NAME_INVALID                     chat=10
ERR_GUILD_NAME_INVALID_SPACE               chat=10
ERR_GUILD_NAME_MIXED_LANGUAGES             chat=10
ERR_GUILD_NAME_NAME_CONSECUTIVE_SPACES     chat=10
ERR_GUILD_NAME_PROFANE                     chat=10
ERR_GUILD_NAME_RESERVED                    chat=10
ERR_GUILD_NAME_TOO_SHORT                   chat=10
ERR_GUILD_NOT_ALLIED                       chat=10
ERR_GUILD_NOT_IN_A_GUILD                   chat=10
ERR_GUILD_PERMISSIONS                      chat=10
ERR_GUILD_PLAYER_NOT_FOUND_S               chat=10
ERR_GUILD_PLAYER_NOT_IN_GUILD              chat=10
ERR_GUILD_PLAYER_NOT_IN_GUILD_S            chat=10
ERR_GUILD_PROMOTE_SSS                      chat=10
ERR_GUILD_QUIT_S                           chat=10
ERR_GUILD_RANKS_LOCKED                     chat=10
ERR_GUILD_RANK_IN_USE                      chat=10
ERR_GUILD_RANK_TOO_HIGH_S                  chat=10
ERR_GUILD_RANK_TOO_LOW_S                   chat=10
ERR_GUILD_REMOVE_SELF                      chat=10
ERR_GUILD_REMOVE_SS                        chat=10
ERR_IGNORE_ADDED_S                         chat=10
ERR_IGNORE_ALREADY_S                       chat=10
ERR_IGNORE_AMBIGUOUS                       chat=10
ERR_IGNORE_FULL                            chat=10
ERR_IGNORE_NOT_FOUND                       chat=10
ERR_IGNORE_REMOVED_S                       chat=10
ERR_IGNORE_SELF                            chat=10
ERR_IGNORING_YOU_S                         chat=10
ERR_INITIATE_TRADE_S                       chat=10
ERR_INSPECT_S                              chat=10
ERR_INTERNAL_BAG_ERROR                     chat=10
ERR_INVALID_ATTACK_TARGET                  chat=10
ERR_INVALID_FOLLOW_TARGET                  chat=10
ERR_INVALID_INSPECT_TARGET                 chat=10
ERR_INVALID_ITEM_TARGET                    chat=10
ERR_INVALID_PETNAME                        chat=10
ERR_INVALID_PROMOTION_CODE                 chat=10
ERR_INVALID_RAID_TARGET                    chat=10
ERR_INVITED_TO_GROUP_S                     chat=10
ERR_INVITED_TO_GUILD                       chat=10
ERR_INVITED_TO_GUILD_SS                    chat=10
ERR_INVITE_PLAYER_S                        chat=10
ERR_INVITE_SELF                            chat=10
ERR_INV_FULL                               chat=10
ERR_ITEM_CANT_BE_DESTROYED                 chat=10
ERR_ITEM_COOLDOWN                          chat=10
ERR_ITEM_LOCKED                            chat=10
ERR_ITEM_MAX_COUNT                         chat=10
ERR_ITEM_NOT_FOUND                         chat=10
ERR_JOINED_GROUP_S                         chat=10
ERR_KILLED_BY_S                            chat=10
ERR_LEARN_ABILITY_S                        chat=10
ERR_LEARN_RECIPE_S                         chat=10
ERR_LEARN_SPELL_S                          chat=10
ERR_LEFT_GROUP_S                           chat=10
ERR_LEFT_GROUP_YOU                         chat=10
ERR_LOGGING_OUT                            chat=10
ERR_LOGOUT_FAILED                          chat=10
ERR_LOOT_BAD_FACING                        chat=10
ERR_LOOT_CANT_LOOT_THAT_NOW                chat=10
ERR_LOOT_DIDNT_KILL                        chat=10
ERR_LOOT_GONE                              chat=10
ERR_LOOT_LOCKED                            chat=10
ERR_LOOT_MASTER_INV_FULL                   chat=10
ERR_LOOT_MASTER_OTHER                      chat=10
ERR_LOOT_MASTER_UNIQUE_ITEM                chat=10
ERR_LOOT_NOTSTANDING                       chat=10
ERR_LOOT_NO_UI                             chat=10
ERR_LOOT_PLAYER_NOT_FOUND                  chat=10
ERR_LOOT_ROLL_PENDING                      chat=10
ERR_LOOT_STUNNED                           chat=10
ERR_LOOT_TOO_FAR                           chat=10
ERR_LOOT_WHILE_INVULNERABLE                chat=10
ERR_MAIL_BAG                               chat=10
ERR_MAIL_BOUND_ITEM                        chat=10
ERR_MAIL_CONJURED_ITEM                     chat=10
ERR_MAIL_DATABASE_ERROR                    chat=10
ERR_MAIL_QUEST_ITEM                        chat=10
ERR_MAIL_REACHED_CAP                       chat=10
ERR_MAIL_SENT                              chat=10
ERR_MAIL_TARGET_NOT_FOUND                  chat=10
ERR_MAIL_TO_SELF                           chat=10
ERR_MEETING_STONE_GROUP_FULL               chat=10
ERR_MEETING_STONE_INVALID_LEVEL            chat=10
ERR_MEETING_STONE_IN_PROGRESS              chat=10
ERR_MEETING_STONE_IN_QUEUE_S               chat=10
ERR_MEETING_STONE_LEFT_QUEUE_S             chat=10
ERR_MEETING_STONE_MEMBER_ADDED_S           chat=10
ERR_MEETING_STONE_MEMBER_STILL_IN_QUEUE    chat=10
ERR_MEETING_STONE_MUST_BE_LEADER           chat=10
ERR_MEETING_STONE_NOT_LEADER               chat=10
ERR_MEETING_STONE_NO_RAID_GROUP            chat=10
ERR_MEETING_STONE_OTHER_MEMBER_LEFT        chat=10
ERR_MEETING_STONE_PARTY_KICKED_FROM_QUEUE  chat=10
ERR_MEETING_STONE_SUCCESS                  chat=10
ERR_MOUNT_ALREADYMOUNTED                   chat=10
ERR_MOUNT_FORCEDDISMOUNT                   chat=10
ERR_MOUNT_INVALIDMOUNTEE                   chat=10
ERR_MOUNT_LOOTING                          chat=10
ERR_MOUNT_NOTMOUNTABLE                     chat=10
ERR_MOUNT_NOTYOURPET                       chat=10
ERR_MOUNT_OTHER                            chat=10
ERR_MOUNT_RACECANTMOUNT                    chat=10
ERR_MOUNT_SHAPESHIFTED                     chat=10
ERR_MOUNT_TOOFARAWAY                       chat=10
ERR_MUST_EQUIP_ITEM                        chat=10
ERR_MUST_REPAIR_DURABILITY                 chat=10
ERR_NEWTAXIPATH                            chat=10
ERR_NEW_LEADER_S                           chat=10
ERR_NEW_LEADER_YOU                         chat=10
ERR_NEW_LOOT_MASTER_S                      chat=10
ERR_NOAMMO_S                               chat=10
ERR_NOEMOTEWHILERUNNING                    chat=10
ERR_NOTYOURPET                             chat=10
ERR_NOT_A_BAG                              chat=10
ERR_NOT_ENOUGH_MONEY                       chat=10
ERR_NOT_EQUIPPABLE                         chat=10
ERR_NOT_HAPPY_ENOUGH                       chat=10
ERR_NOT_IN_COMBAT                          chat=10
ERR_NOT_IN_GROUP                           chat=10
ERR_NOT_IN_RAID                            chat=10
ERR_NOT_LEADER                             chat=10
ERR_NOT_OWNER                              chat=10
ERR_NOT_WHILE_DISARMED                     chat=10
ERR_NOT_WHILE_MOUNTED                      chat=10
ERR_NOT_WHILE_SHAPESHIFTED                 chat=10
ERR_NO_ATTACK_TARGET                       chat=10
ERR_NO_BANK_HERE                           chat=10
ERR_NO_BANK_SLOT                           chat=10
ERR_NO_GUILD_CHARTER                       chat=10
ERR_NO_ITEMS_WHILE_SHAPESHIFTED            chat=10
ERR_NO_PET                                 chat=10
ERR_NO_REPLY_TARGET                        chat=10
ERR_NO_SLOT_AVAILABLE                      chat=10
ERR_NULL_PETNAME                           chat=10
ERR_OBJECT_IS_BUSY                         chat=10
ERR_ONLY_ONE_AMMO                          chat=10
ERR_ONLY_ONE_BOLT                          chat=10
ERR_ONLY_ONE_QUIVER                        chat=10
ERR_OUT_OF_ENERGY                          chat=10
ERR_OUT_OF_FOCUS                           chat=10
ERR_OUT_OF_HEALTH                          chat=10
ERR_OUT_OF_MANA                            chat=10
ERR_OUT_OF_RAGE                            chat=10
ERR_OUT_OF_RANGE                           chat=10
ERR_PASSIVE_ABILITY                        chat=10
ERR_PETITION_ALREADY_SIGNED                chat=10
ERR_PETITION_CREATOR                       chat=10
ERR_PETITION_DECLINED_S                    chat=10
ERR_PETITION_IN_GUILD                      chat=10
ERR_PETITION_NOT_ENOUGH_SIGNATURES         chat=10
ERR_PETITION_NOT_SAME_SERVER               chat=10
ERR_PETITION_OFFERED_S                     chat=10
ERR_PETITION_SIGNED                        chat=10
ERR_PETITION_SIGNED_S                      chat=10
ERR_PET_BROKEN                             chat=10
ERR_PET_NOT_RENAMEABLE                     chat=10
ERR_PET_SPELL_AFFECTING_COMBAT             chat=10
ERR_PET_SPELL_ALREADY_KNOWN_S              chat=10
ERR_PET_SPELL_DEAD                         chat=10
ERR_PET_SPELL_NOPATH                       chat=10
ERR_PET_SPELL_NOT_BEHIND                   chat=10
ERR_PET_SPELL_OUT_OF_RANGE                 chat=10
ERR_PET_SPELL_ROOTED                       chat=10
ERR_PET_SPELL_TARGETS_DEAD                 chat=10
ERR_PLAYER_BUSY_S                          chat=10
ERR_PLAYER_DEAD                            chat=10
ERR_PLAYER_DIED_S                          chat=10
ERR_PLAYER_WRONG_FACTION                   chat=10
ERR_PLAY_TIME_EXCEEDED                     chat=10
ERR_POTION_COOLDOWN                        chat=10
ERR_PROFICIENCY_GAINED_S                   chat=23
ERR_PROFICIENCY_NEEDED                     chat=10
ERR_PVP_KILL_DISHONORABLE                  chat=10
ERR_PVP_KILL_HONORABLE                     chat=10
ERR_PVP_TOGGLE_OFF                         chat=10
ERR_PVP_TOGGLE_ON                          chat=10
ERR_QUEST_ACCEPTED_S                       chat=10
ERR_QUEST_ADD_FOUND_SII                    chat=10
ERR_QUEST_ADD_ITEM_SII                     chat=10
ERR_QUEST_ADD_KILL_SII                     chat=10
ERR_QUEST_ALREADY_ON                       chat=10
ERR_QUEST_COMPLETE_S                       chat=10
ERR_QUEST_FAILED_BAG_FULL_S                chat=10
ERR_QUEST_FAILED_LOW_LEVEL                 chat=10
ERR_QUEST_FAILED_MAX_COUNT_S               chat=10
ERR_QUEST_FAILED_MISSING_ITEMS             chat=10
ERR_QUEST_FAILED_NOT_ENOUGH_MONEY          chat=10
ERR_QUEST_FAILED_S                         chat=10
ERR_QUEST_FAILED_WRONG_RACE                chat=10
ERR_QUEST_LOG_FULL                         chat=10
ERR_QUEST_MUST_CHOOSE                      chat=10
ERR_QUEST_NEED_PREREQS                     chat=10
ERR_QUEST_OBJECTIVE_COMPLETE_S             chat=10
ERR_QUEST_ONLY_ONE_TIMED                   chat=10
ERR_QUEST_PUSH_ACCEPTED_S                  chat=10
ERR_QUEST_PUSH_ALREADY_DONE_S              chat=10
ERR_QUEST_PUSH_BUSY_S                      chat=10
ERR_QUEST_PUSH_DECLINED_S                  chat=10
ERR_QUEST_PUSH_INVALID_S                   chat=10
ERR_QUEST_PUSH_LOG_FULL_S                  chat=10
ERR_QUEST_PUSH_ONQUEST_S                   chat=10
ERR_QUEST_PUSH_SUCCESS_S                   chat=10
ERR_QUEST_PUSH_TOO_FAR_S                   chat=10
ERR_QUEST_REWARD_EXP_I                     chat=10
ERR_QUEST_REWARD_ITEM_S                    chat=10
ERR_QUEST_REWARD_MONEY_S                   chat=10
ERR_QUEST_UNKNOWN_COMPLETE                 chat=10
ERR_RAID_GROUP_FULL                        chat=10
ERR_RAID_GROUP_ONLY                        chat=10
ERR_RAID_LEADER_READY_CHECK_START_S        chat=10
ERR_RAID_MEMBER_ADDED_S                    chat=10
ERR_RAID_MEMBER_REMOVED_S                  chat=10
ERR_RAID_YOU_JOINED                        chat=10
ERR_RAID_YOU_LEFT                          chat=10
ERR_READY_CHECK_IN_PROGRESS                chat=10
ERR_RECEIVE_ITEM_S                         chat=10
ERR_RESTRICTED_ACCOUNT                     chat=10
ERR_SET_LOOT_FREEFORALL                    chat=10
ERR_SET_LOOT_GROUP                         chat=10
ERR_SET_LOOT_MASTER                        chat=10
ERR_SET_LOOT_NBG                           chat=10
ERR_SET_LOOT_ROUNDROBIN                    chat=10
ERR_SET_LOOT_THRESHOLD_S                   chat=10
ERR_SKILL_GAINED_S                         chat=23
ERR_SKILL_UP_SI                            chat=23
ERR_SLOT_EMPTY                             chat=10
ERR_SPECIFY_MASTER_LOOTER                  chat=10
ERR_SPELL_ALREADY_KNOWN_S                  chat=10
ERR_SPELL_COOLDOWN                         chat=10
ERR_SPELL_FAILED_ALREADY_AT_FULL_HEALTH    chat=10
ERR_SPELL_FAILED_ALREADY_AT_FULL_POWER_S   chat=10
ERR_SPELL_FAILED_EQUIPPED_ITEM             chat=10
ERR_SPELL_FAILED_EQUIPPED_ITEM_CLASS_S     chat=10
ERR_SPELL_FAILED_EQUIPPED_SPECIFIC_ITEM    chat=10
ERR_SPELL_FAILED_NOTUNSHEATHED             chat=10
ERR_SPELL_FAILED_REAGENTS                  chat=10
ERR_SPELL_FAILED_REAGENTS_GENERIC          chat=10
ERR_SPELL_FAILED_S                         chat=10
ERR_SPELL_FAILED_SHAPESHIFT_FORM_S         chat=10
ERR_SPELL_FAILED_TOTEMS                    chat=10
ERR_SPELL_OUT_OF_RANGE                     chat=10
ERR_SPELL_UNLEARNED_S                      chat=10
ERR_SPLIT_FAILED                           chat=10
ERR_TALENT_WIPE_ERROR                      chat=10
ERR_TAME_FAILED                            chat=10
ERR_TARGET_LOGGING_OUT                     chat=10
ERR_TARGET_NOT_IN_GROUP_S                  chat=10
ERR_TARGET_STUNNED                         chat=10
ERR_TAXINOPATHS                            chat=10
ERR_TAXINOSUCHPATH                         chat=10
ERR_TAXINOTENOUGHMONEY                     chat=10
ERR_TAXINOTSTANDING                        chat=10
ERR_TAXINOTVISITED                         chat=10
ERR_TAXINOVENDORNEARBY                     chat=10
ERR_TAXIPLAYERALREADYMOUNTED               chat=10
ERR_TAXIPLAYERBUSY                         chat=10
ERR_TAXIPLAYERMOVING                       chat=10
ERR_TAXIPLAYERSHAPESHIFTED                 chat=10
ERR_TAXISAMENODE                           chat=10
ERR_TAXITOOFARAWAY                         chat=10
ERR_TAXIUNSPECIFIEDSERVERERROR             chat=10
ERR_TICKET_ALREADY_EXISTS                  chat=10
ERR_TICKET_CREATE_ERROR                    chat=10
ERR_TICKET_DB_ERROR                        chat=10
ERR_TICKET_NO_TEXT                         chat=10
ERR_TICKET_UPDATE_ERROR                    chat=10
ERR_TOOBUSYTOFOLLOW                        chat=10
ERR_TOO_FEW_TO_SPLIT                       chat=10
ERR_TOO_MANY_CHAT_CHANNELS                 chat=10
ERR_TOO_MANY_SPECIAL_BAGS                  chat=10
ERR_TRADE_BAG                              chat=10
ERR_TRADE_BAG_FULL                         chat=10
ERR_TRADE_BLOCKED_S                        chat=10
ERR_TRADE_BOUND_ITEM                       chat=10
ERR_TRADE_CANCELLED                        chat=10
ERR_TRADE_COMPLETE                         chat=10
ERR_TRADE_EQUIPPED_BAG                     chat=10
ERR_TRADE_GROUND_ITEM                      chat=10
ERR_TRADE_MAX_COUNT_EXCEEDED               chat=10
ERR_TRADE_QUEST_ITEM                       chat=10
ERR_TRADE_REQUEST_S                        chat=10
ERR_TRADE_TARGET_BAG_FULL                  chat=10
ERR_TRADE_TARGET_DEAD                      chat=10
ERR_TRADE_TARGET_MAX_COUNT_EXCEEDED        chat=10
ERR_TRADE_TOO_FAR                          chat=10
ERR_TRADE_WRONG_REALM                      chat=10
ERR_UNHEALTHY_TIME                         chat=10
ERR_UNINVITE_YOU                           chat=10
ERR_UNIT_NOT_FOUND                         chat=10
ERR_USE_BAD_ANGLE                          chat=10
ERR_USE_CANT_IMMUNE                        chat=10
ERR_USE_CANT_OPEN                          chat=10
ERR_USE_DESTROYED                          chat=10
ERR_USE_LOCKED                             chat=10
ERR_USE_LOCKED_WITH_ITEM_S                 chat=10
ERR_USE_LOCKED_WITH_SPELL_KNOWN_SI         chat=10
ERR_USE_LOCKED_WITH_SPELL_S                chat=10
ERR_USE_OBJECT_MOVING                      chat=10
ERR_USE_SPELL_FOCUS                        chat=10
ERR_USE_TOO_FAR                            chat=10
ERR_VENDOR_HATES_YOU                       chat=10
ERR_VENDOR_NOT_INTERESTED                  chat=10
ERR_VENDOR_SOLD_OUT                        chat=10
ERR_VENDOR_TOO_FAR                         chat=10
ERR_WRONG_BAG_TYPE                         chat=10
ERR_WRONG_BAG_TYPE_SUBCLASS                chat=10
ERR_WRONG_SLOT                             chat=10
ERR_ZONE_EXPLORED                          chat=10
ERR_ZONE_EXPLORED_XP                       chat=10
```

## Gotchas that cost an afternoon

- `Interface:` is compared as a number, so write `## Interface: 11200` exactly;
  a comma-separated list of versions is accepted.
- Saved coordinates are in the frame's own scale units — convert or clamp after
  a UI-scale change or the frame lands off-screen.
- `GameTooltip_SetDefaultAnchor` parks the tooltip bottom-right, which matters
  if you draw anything in that corner.
- `debuginfo`, `debugload`, `debugprint`, `debugdump`, `debugbreak` and
  `debugtimestamp` exist and do nothing; only `debugprofilestart/stop` are real.
- Nothing registers `hooksecurefunc`/`securecall`, so no addon can take a
  secure action hook. Build your own frames rather than driving Blizzard's.
- An unknown TOC directive is dropped silently — there is no `## Dependencies:`.
