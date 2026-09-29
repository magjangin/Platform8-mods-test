-- ===================================================================
-- Platform8 MasterMod - 게임 오브젝트 접근 & 치트/리셋 로직
--   * 세이브 완전 초기화
--   * 즉시 8번 승강장(八番) 도착 / 이변 제거
--   * HUD 용 현재 열차 상태 읽기
--
-- 게임 구조 (UE4SS 로 실측)
--   PlayerState_Platform8_C.CountNumber   정답 진행 수 = 역 번호. 0~8 은 "다음 역 L0~L8", 9(Max) 는 八番 도착
--   PlayerState_Platform8_C.SetCount(Add) 진행 수 가산 (0~Max 로 제한). "Move 0 Station" 은 0 으로 리셋
--   BP_Train_C.MoveNextStation()          진행 수 +1 과 역 표지판 갱신. Max 에 닿으면 Goal() (八番 정차)
--   BP_AnomalyManager_C                   칸을 옮길 때 이변 추첨 → CurrentAnomalyComp/Tag 설정 → 약 2초 뒤 "Anomaly Active"
--   "Deactive Current Anomaly"            현재 칸의 이변 해제 (칸을 옮길 때 게임도 이걸 부른다)
-- ===================================================================

local UEHelpers = require("UEHelpers")
local Util = require("platform8.util")
local AnomalyDB = require("platform8.anomaly_db")

local Game = {}
local Config

local CLASS_PLAYER_STATE = "PlayerState_Platform8_C"
local CLASS_ANOMALY_MANAGER = "BP_AnomalyManager_C"
local CLASS_GAME_INSTANCE = "GameInstance_Platform8_C"
local SAVE_GAME_CDO = "/Game/_Platform8/Core/Save/Save_Game.Default__Save_Game_C"

local GOAL_COUNT_FALLBACK = 9 -- PlayerState.Max 를 못 읽을 때: 9 = 八番(L8) 도착

function Game.Init(config)
    Config = config
end

-- ===================================================================
-- 오브젝트 캐시
-- FindAllOf 를 매 틱 부르지 않도록 찾은 오브젝트를 저장해 두고,
-- 일정 틱마다 또는 오브젝트가 무효화됐을 때(레벨 재시작 등)만 다시 찾는다.
-- ===================================================================
local CACHE_REFRESH_TICKS = 8
local cache = {}

local function FindInstance(className)
    for _, obj in ipairs(FindAllOf(className) or {}) do
        if obj:IsValid() and not obj:GetFullName():find("Default__", 1, true) then
            return obj
        end
    end
    return nil
end

local function GetInstance(className, forceRefresh)
    local entry = cache[className]
    if not forceRefresh and entry and entry.age < CACHE_REFRESH_TICKS and Util.IsValid(entry.obj) then
        return entry.obj
    end
    local obj = FindInstance(className)
    cache[className] = { obj = obj, age = 0 }
    return obj
end

-- 틱마다 한 번 호출 (캐시 나이 증가)
function Game.Tick()
    for _, entry in pairs(cache) do
        entry.age = entry.age + 1
    end
end

function Game.GetPlayerState(forceRefresh)
    return GetInstance(CLASS_PLAYER_STATE, forceRefresh)
end

function Game.GetAnomalyManager(forceRefresh)
    return GetInstance(CLASS_ANOMALY_MANAGER, forceRefresh)
end

local function GoalCount(ps)
    local max = Util.Get(ps, "Max")
    if type(max) == "number" and max > 0 then return max end
    return GOAL_COUNT_FALLBACK
end

-- ===================================================================
-- 1. [이변 제거] 현재 칸의 이상현상 해제
-- ===================================================================
local function HasAnomaly(mgr)
    return Util.Get(mgr, "Anomaly Active") == true or Util.IsValid(Util.Get(mgr, "CurrentAnomalyComp"))
end

-- 반환값: 해제할 이변이 있어서 해제했으면 true
function Game.ClearAnomaly(forceRefresh)
    local mgr = Game.GetAnomalyManager(forceRefresh)
    if not mgr or not HasAnomaly(mgr) then return false end

    Util.Call(mgr, { "Deactive Current Anomaly", "Deactive_Current_Anomaly" })
    -- "Deactive Current Anomaly" 는 이변 액터만 끄고 이 플래그는 남겨 두므로 직접 내린다
    -- (안 내리면 가디언이 매 틱 해제를 반복한다)
    Util.Set(mgr, "Anomaly Active", false)
    Util.Set(mgr, "Change", false)
    Util.Log("Cleared current anomaly (%s).", Util.TagName(Util.Get(mgr, "CurrentAnomalyTag")))
    return true
end

-- ===================================================================
-- 2. [기능 1] 즉시 8번 승강장(八番) 도착
-- 진행 수를 八番 직전(Max-1)으로 맞춘 뒤, 현재 칸의 열차에서 게임 자체의 MoveNextStation() 을 호출한다.
-- 진행 수가 Max 에 닿으면 게임이 직접 Goal() 을 실행해 八番 승강장에 정차하고 문을 연다.
-- 반환값: "applied" (적용), "already" (이미 도착), nil (열차가 아직 준비 안 됨)
-- ===================================================================
function Game.ActivatePlatform8()
    local ps = Game.GetPlayerState(true)
    if not ps then return nil end

    local goal = GoalCount(ps)
    local count = Util.Get(ps, "CountNumber") or 0
    if count >= goal then
        return "already"
    end

    local train = Util.Get(ps, "CurrentTrain")
    if not Util.IsValid(train) then return nil end

    if Config.DisableAnomaliesAtPlatform8 then
        Game.ClearAnomaly(true)
    end

    if count < goal - 1 then
        Util.Call(ps, "SetCount", (goal - 1) - count, {})
    end
    if not Util.Call(train, "MoveNextStation") then
        return nil
    end

    Util.Log("Station count %d -> %s (goal %d). Train %s heading to Platform 8.",
        count, tostring(Util.Get(ps, "CountNumber")), goal, train:GetFName():ToString())
    return "applied"
end

-- ===================================================================
-- 3. [기능 2] 세이브 및 해금 데이터 완전 초기화 (Clean Vanilla Reset)
-- ===================================================================
local function GetGameInstance()
    local gi = UEHelpers.GetGameInstance()
    if Util.IsValid(gi) and Util.ClassName(gi) == CLASS_GAME_INSTANCE then return gi end
    gi = FindInstance(CLASS_GAME_INSTANCE)
    if Util.IsValid(gi) then return gi end
    return nil
end

local function GetSaveGame(gi)
    local save = Util.Get(gi, "Save Game", "Save_Game")
    if Util.IsValid(save) then return save end
    return nil
end

local function ArrayLength(arr)
    local ok, n = pcall(function() return #arr end)
    return ok and n or 0
end

-- dst 배열 내용을 src 배열 내용으로 교체 (FGameplayTag 배열)
local function CopyTagArray(dst, src)
    local items = {}
    for i = 1, ArrayLength(src) do items[#items + 1] = src[i] end
    dst:Empty()
    for _, item in ipairs(items) do
        dst[#dst + 1] = item
    end
    return #items
end

local function ResetSaveGameObject(save)
    Util.Log("Resetting Save_Game [0x%X] to fresh vanilla state...", save:GetAddress())

    -- 클리어 / 모든 이변 발견 / 이변 조우 플래그 해제
    Util.Set(save, "Clear", false)
    Util.Set(save, "AllAno", false)
    Util.Set(save, "AnomalyEncount", false)

    local cdo = StaticFindObject(SAVE_GAME_CDO)
    if not Util.IsValid(cdo) then cdo = nil end

    -- 전체 이변 목록을 미발견 이변 목록으로 100% 복원
    local ok, err = pcall(function()
        local allAno = save["All Anomaly"]
        if ArrayLength(allAno) == 0 and cdo then allAno = cdo["All Anomaly"] end
        local count = CopyTagArray(save["Not Found Anomaly"], allAno)
        Util.Log("Restored all %d anomalies back into 'Not Found Anomaly'!", count)
    end)
    if not ok then Util.Log("Failed to restore anomaly list: %s", tostring(err)) end

    -- 하드 이변 목록(새 게임에서도 12개)은 GameInstance:Reset AnomalyArray() 가 되돌린다 (실측).
    -- CDO 에 기본값이 들어 있는 빌드라면 그 값으로도 한 번 더 맞춘다.
    ok, err = pcall(function()
        local defaults = cdo and cdo["Hard Anomaly"]
        if ArrayLength(defaults) == 0 then
            Util.Log("'Hard Anomaly' now has %d entries (restored by Reset AnomalyArray).", ArrayLength(save["Hard Anomaly"]))
            return
        end
        local count = CopyTagArray(save["Hard Anomaly"], defaults)
        Util.Log("Restored 'Hard Anomaly' to %d default entries.", count)
    end)
    if not ok then Util.Log("Failed to restore hard anomaly list: %s", tostring(err)) end
end

-- 반환값: GameInstance 와 세이브 객체를 찾아 초기화를 수행했으면 true
function Game.ResetSaveData()
    Util.Log("Executing FULL RESET of all save data and unlock progress...")

    local gi = GetGameInstance()
    if not gi then
        Util.Log("GameInstance not available yet. Waiting for game load...")
        return false
    end
    local save = GetSaveGame(gi)
    if not save then
        Util.Log("Save_Game object not loaded yet. Waiting for game load...")
        return false
    end
    Util.Log("Found GameInstance: %s", gi:GetFullName())

    -- 1) 걸음 수 / 튜토리얼 초기화
    Util.Set(gi, "WalkCount", 0)
    Util.Set(gi, "EndTutorial", false)

    -- 2) GameInstance 이변 배열 초기화 (UseTag ← UseTag_Initial)
    if Util.Call(gi, { "Reset AnomalyArray", "Reset_AnomalyArray" }) then
        Util.Log("Called GameInstance:Reset AnomalyArray()")
    end

    -- 3) 세이브 데이터 객체(Save_Game_C) 순정 상태로 리셋
    ResetSaveGameObject(save)

    -- 4) Save.sav 슬롯에 저장
    if Util.Call(gi, "SaveGameParam") then
        Util.Log("Saved clean pristine state to Save.sav!")
    end

    Util.Log(">>> [SUCCESS] Completely reset all save data and unlocks to fresh vanilla state! <<<")
    return true
end

-- ===================================================================
-- 4. HUD 용 현재 열차 상태 읽기
-- 반환: { found, count, goal, anomaly, seekFound, anomalyTag, anomalyClass, carKey }
-- ===================================================================
function Game.ReadTrainState()
    local state = { found = false, count = 0, goal = GOAL_COUNT_FALLBACK, anomaly = false, seekFound = false,
        anomalyTag = "", anomalyClass = "", carKey = nil }

    local ps = Game.GetPlayerState()
    if ps then
        state.found = true
        state.count = Util.Get(ps, "CountNumber") or 0
        state.goal = GoalCount(ps)
        local train = Util.Get(ps, "CurrentTrain")
        if Util.IsValid(train) then state.carKey = train:GetAddress() end
    end

    local mgr = Game.GetAnomalyManager()
    if mgr then
        state.found = true
        -- CurrentAnomalyComp 는 이변이 뽑히는 순간 설정되고 "Anomaly Active" 는 약 2초 뒤 켜진다.
        -- 칸을 옮기면 게임이 "Deactive Current Anomaly" 로 둘 다 해제한다.
        state.anomaly = HasAnomaly(mgr)
        if state.anomaly then
            state.seekFound = Util.Get(mgr, "AnomalySeek_Find") == true
            state.anomalyTag = Util.TagName(Util.Get(mgr, "CurrentAnomalyTag"))
            local comp = Util.Get(mgr, "CurrentAnomalyComp")
            if Util.IsValid(comp) then
                local ok, owner = pcall(function() return comp:GetOwner() end)
                if ok and Util.IsValid(owner) then state.anomalyClass = Util.ClassName(owner) end
            end
        end
    end

    return state
end

-- ===================================================================
-- 5. [기능 6] 특정 이변이 나오지 않게 하기 (Config.MaxScareLevel + Config.ExcludedAnomalies)
-- 게임은 아직 못 본 이변(세이브 "Not Found Anomaly")에서 먼저 뽑고, 다 보면
-- GameInstance.UseTag / AnomalyManager.UseTag_ChangeMana 에서 뽑는다 (실측).
-- 네 목록(+ "Hard Anomaly") 모두에서 제외 태그를 빼고, 게임이 목록을 다시 채우면
-- (세이브 리셋, 31종 모두 본 뒤 등) 주기적으로 다시 빼 준다.
-- 그래서 제외한 이변은 게임 안에서 "이미 발견한 이변" 으로 취급된다.
-- ===================================================================
local excludedSet = nil

-- 제외할 태그 집합: 공포 수위가 MaxScareLevel 보다 높은 것 + ExcludedAnomalies 에 적은 것
local function ExcludedSet()
    if excludedSet == nil then
        excludedSet = {}
        local maxLevel = tonumber(Config.MaxScareLevel)
        if maxLevel and maxLevel < 3 then
            for _, tag in ipairs(AnomalyDB.TagsAboveScare(maxLevel)) do excludedSet[tag] = true end
        end
        for _, tag in ipairs(Config.ExcludedAnomalies or {}) do excludedSet[tag] = true end

        local names = {}
        for tag in pairs(excludedSet) do names[#names + 1] = tag end
        table.sort(names)
        if #names > 0 then
            Util.Log("Excluded anomalies (MaxScareLevel=%s, %d): %s", tostring(Config.MaxScareLevel), #names, table.concat(names, ", "))
        end
    end
    return excludedSet
end

function Game.IsExcluded(tagName)
    return ExcludedSet()[tagName] == true
end

function Game.HasExclusions()
    return next(ExcludedSet()) ~= nil
end

-- 태그 배열에서 제외 태그를 뺀다. 반환: 뺀 개수
-- allowEmpty: 세이브의 미발견 목록은 비어도 되지만(= 모두 발견), 뽑기 후보 목록은 비우면 안 된다
local function RemoveExcludedTags(arr, allowEmpty)
    local keep, removed = {}, 0
    for i = 1, ArrayLength(arr) do
        local name = Util.TagName(arr[i])
        if Game.IsExcluded(name) then removed = removed + 1 else keep[#keep + 1] = name end
    end
    if removed == 0 then return 0 end
    if #keep == 0 and not allowEmpty then
        Util.WarnOnce("ExcludedAnomalies would empty the anomaly pool. Leaving it as is.")
        return 0
    end

    -- 요소는 배열 메모리를 가리키므로 태그 이름만 복사해 두고 비운 뒤 다시 채운다
    arr:Empty()
    for _, name in ipairs(keep) do
        arr[#arr + 1] = { TagName = FName(name) }
    end
    return removed
end

local function GetCurrentSaveGame()
    local gi = GetGameInstance()
    return gi and GetSaveGame(gi)
end

local EXCLUDE_TARGETS = {
    { get = GetCurrentSaveGame, prop = "Not Found Anomaly", allowEmpty = true },
    { get = GetCurrentSaveGame, prop = "Hard Anomaly", allowEmpty = true },
    { get = function() return GetGameInstance() end, prop = "UseTag" },
    { get = function() return Game.GetAnomalyManager() end, prop = "UseTag_ChangeMana" },
}

function Game.ApplyAnomalyExclusions()
    if not Game.HasExclusions() then return end
    for _, target in ipairs(EXCLUDE_TARGETS) do
        local obj = target.get()
        local arr = obj and Util.Get(obj, target.prop)
        if arr then
            local ok, removed = pcall(RemoveExcludedTags, arr, target.allowEmpty)
            if not ok then
                Util.WarnOnce("Failed to apply ExcludedAnomalies to %s: %s", target.prop, tostring(removed))
            elseif removed > 0 then
                Util.Log("Excluded %d anomaly tag(s) from %s.%s (pool now %d).",
                    removed, Util.ClassName(obj), target.prop, ArrayLength(arr))
            end
        end
    end
end

return Game
