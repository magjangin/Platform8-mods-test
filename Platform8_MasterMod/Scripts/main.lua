-- ===================================================================
-- Platform8 MasterMod (v1.0 - UMG Anomaly HUD & Instant Platform 8)
-- 8번 승강장 (Platform 8) 세이브 완전 초기화 & 즉시 8번 승강장 치트 & 이상현상 HUD
--
-- 파일 구성
--   main.lua                  진입점: 설정 로드, 단축키/훅/틱 루프 연결
--   config.lua                사용자 설정
--   platform8/util.lua        로그, 안전한 프로퍼티/함수 접근
--   platform8/game.lua        세이브 리셋, 8번 승강장 적용, 이변 제거, 열차 상태 읽기
--   platform8/anomaly_db.lua  이변 태그 → 한글/영문 이름
--   platform8/tracker.lua     이변 감지 → HUD 문구/색상
--   platform8/hud.lua         UMG 오버레이 위젯
--   platform8/player.lua      플레이어 이동 속도 배율
-- ===================================================================

local MOD_VERSION = "1.0"

local DEFAULT_CONFIG = {
    AutoReset = true,
    AutoPlatform8OnStart = false,
    DisableAnomaliesAtPlatform8 = true,
    ShowAnomalyHUD = true,
    HUD_Language = "KR",
    HUD_PositionX = 25,
    HUD_PositionY = 25,
    HUD_TitleFontSize = 20,
    HUD_AdviceFontSize = 15,
    HUD_ZOrder = 100,
    HUD_FontHints = {},
    MoveSpeedMultiplier = 1.0,
    MaxScareLevel = 3,
    ExcludedAnomalies = {},
    Key_Platform8 = "F8",
    Key_Platform8_Alt = "EIGHT",
    Key_ManualReset = "F7",
    Key_ToggleHUD = "F9",
    TickIntervalMs = 150,
    DebugLogging = true,
}

-- config.lua 값으로 기본값을 덮어씀 (구버전 config 에 없는 키는 기본값 유지)
local function LoadConfig()
    local config = {}
    for key, value in pairs(DEFAULT_CONFIG) do config[key] = value end

    local ok, userConfig = pcall(require, "config")
    if ok and type(userConfig) == "table" then
        for key, value in pairs(userConfig) do config[key] = value end
        return config, true
    end
    return config, false
end

local Config, configLoaded = LoadConfig()

local Util = require("platform8.util")
Util.Init(Config)
local Game = require("platform8.game")
Game.Init(Config)
local Tracker = require("platform8.tracker")
Tracker.Init(Config, Game)
local Hud = require("platform8.hud")
Hud.Init(Config)
local Player = require("platform8.player")
Player.Init(Config)

Util.Log("Initializing Platform8 MasterMod v%s... (config.lua %s)", MOD_VERSION, configLoaded and "loaded" or "NOT found, using defaults")

local State = {
    AutoResetDone = false,
    AutoPlatform8Done = false,
    Platform8CheatActive = false, -- 8번 승강장 치트 발동 후 이변 차단 유지
}

-- ===================================================================
-- 1. 기능 동작
-- ===================================================================
local function ResetSave()
    if Game.ResetSaveData() then
        State.AutoResetDone = true
    end
end

-- 즉시 8번 승강장 도착 (단 1회 입력)
local function ActivatePlatform8()
    Util.Log("Triggering Instant Platform 8 Cheat...")
    local result = Game.ActivatePlatform8()
    if result == "applied" then
        State.Platform8CheatActive = true
        Util.Log(">>> INSTANT PLATFORM 8 ACTIVATED! The train is stopping at Hachiban. Get off when the doors open! <<<")
    elseif result == "already" then
        State.Platform8CheatActive = true
        Util.Log("Already at Platform 8.")
    else
        Util.Log("Train/PlayerState not ready yet. Try again once the game has started.")
    end
    return result ~= nil
end

local function ToggleHud()
    Config.ShowAnomalyHUD = not Config.ShowAnomalyHUD
    Hud.SetVisible(Config.ShowAnomalyHUD)
    Util.Log("Anomaly HUD toggled: %s", Config.ShowAnomalyHUD and "ON" or "OFF")
end

-- ===================================================================
-- 2. 단축키 등록 (F8/숫자8 치트, F7 수동 초기화, F9 HUD 토글)
-- ===================================================================
local function RegisterKeySafe(keyName, callback)
    if not keyName or keyName == "" then return end
    local keyValue = Key[keyName]
    if not keyValue then
        Util.Warn("Key '%s' not recognized in UE4SS Key enum.", keyName)
        return
    end
    local ok, err = pcall(RegisterKeyBind, keyValue, function()
        ExecuteInGameThread(callback)
    end)
    if ok then
        Util.Log("Registered hotkey: [%s]", keyName)
    else
        Util.Warn("Failed to register key [%s]: %s", keyName, tostring(err))
    end
end

RegisterKeySafe(Config.Key_Platform8, ActivatePlatform8)
if Config.Key_Platform8_Alt ~= Config.Key_Platform8 then
    RegisterKeySafe(Config.Key_Platform8_Alt, ActivatePlatform8)
end
RegisterKeySafe(Config.Key_ManualReset, ResetSave)
RegisterKeySafe(Config.Key_ToggleHUD, ToggleHud)

-- ===================================================================
-- 3. 키 입력 없는 자동 실행 (세이브 초기화 / 시작 시 8번 승강장)
-- ===================================================================
local AUTO_RUN_INTERVAL_MS = 2000
local AUTO_RUN_MAX_ATTEMPTS = 5
local autoRunAttempts = 0

local function TryAutoRun()
    if Config.AutoReset and not State.AutoResetDone then
        ResetSave()
    end
    if Config.AutoPlatform8OnStart and not State.AutoPlatform8Done then
        State.AutoPlatform8Done = ActivatePlatform8()
    end
end

local function IsAutoRunFinished()
    return (not Config.AutoReset or State.AutoResetDone)
        and (not Config.AutoPlatform8OnStart or State.AutoPlatform8Done)
end

-- 플레이어 폰 생성 시점 (게임 시작 또는 게임오버 후 재시작)
RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
    ExecuteInGameThread(function()
        State.Platform8CheatActive = false -- 새 맵/재시작 시 이전 치트 상태 리셋
        State.AutoPlatform8Done = false
        TryAutoRun()
    end)
end)

-- ===================================================================
-- 4. 메인 틱 (가디언 + HUD)
-- ===================================================================
local tickCount = 0
local autoRunEveryTicks = math.max(1, math.floor(AUTO_RUN_INTERVAL_MS / Config.TickIntervalMs))
local EXCLUDE_INTERVAL_MS = 1000
local excludeEveryTicks = math.max(1, math.floor(EXCLUDE_INTERVAL_MS / Config.TickIntervalMs))

-- 제외한 이변이 그래도 나오면 로그로 알림 (후보 목록 외의 경로로 뽑히는지 확인용)
local lastExcludedWarn = nil
local function CheckExcludedSpawn()
    local state = Game.ReadTrainState()
    if state.anomaly and Game.IsExcluded(state.anomalyTag) then
        local key = state.anomalyTag .. "|" .. tostring(state.carKey)
        if key ~= lastExcludedWarn then
            lastExcludedWarn = key
            Util.Warn("Excluded anomaly '%s' spawned anyway! Please report this log line.", state.anomalyTag)
        end
    end
end

local function OnTick()
    tickCount = tickCount + 1
    Game.Tick()
    Player.Tick()

    -- 제외한 이변을 후보 목록에서 계속 빼 둠 (게임이 목록을 다시 채우는 경우 대비)
    if tickCount % excludeEveryTicks == 0 and Game.HasExclusions() then
        Game.ApplyAnomalyExclusions()
        CheckExcludedSpawn()
    end

    -- 게임 레벨 로드 대기 백업 폴링 (최대 5회)
    if autoRunAttempts < AUTO_RUN_MAX_ATTEMPTS and not IsAutoRunFinished()
        and tickCount % autoRunEveryTicks == 0 then
        autoRunAttempts = autoRunAttempts + 1
        TryAutoRun()
    end

    -- 8번 승강장 치트 발동 후: 八番 도착까지 새로 생기는 이변도 계속 차단
    if State.Platform8CheatActive and Config.DisableAnomaliesAtPlatform8 then
        Game.ClearAnomaly()
    end

    if Config.ShowAnomalyHUD then
        Hud.Render(Tracker.Update())
    end
end

-- LoopAsync 는 별도 스레드에서 돌기 때문에 실제 작업은 게임 스레드로 넘긴다.
-- 게임 스레드가 로딩 등으로 멈춰 있을 때 작업이 쌓이지 않도록 한 번에 하나만 예약.
local tickQueued = false
LoopAsync(Config.TickIntervalMs, function()
    if not tickQueued then
        tickQueued = true
        ExecuteInGameThread(function()
            local ok, err = pcall(OnTick)
            if not ok then
                Util.WarnOnce("Tick error: %s", tostring(err))
            end
            tickQueued = false
        end)
    end
    return false
end)

Util.Log("Platform8 MasterMod v%s loaded successfully! Ready.", MOD_VERSION)
