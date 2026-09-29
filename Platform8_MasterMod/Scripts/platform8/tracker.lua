-- ===================================================================
-- Platform8 MasterMod - 이상현상 실시간 감지 → HUD 표시 문구/색상 생성
-- ===================================================================

local Util = require("platform8.util")
local AnomalyDB = require("platform8.anomaly_db")

local Tracker = {}
local Config, Game

local COLOR = {
    Safe = { R = 0.2, G = 0.85, B = 1.0, A = 1.0 },      -- 하늘색: 정상 칸
    Goal = { R = 0.1, G = 1.0, B = 0.35, A = 1.0 },      -- 초록색: 8번 승강장 / 숨은 이변 발견
    Harmless = { R = 1.0, G = 0.9, B = 0.2, A = 1.0 },   -- 노란색: 무시해도 되는 이변
    Anomaly = { R = 1.0, G = 0.65, B = 0.05, A = 1.0 },  -- 주황색: 찾기/행동이 필요한 이변
    Critical = { R = 1.0, G = 0.15, B = 0.15, A = 1.0 }, -- 빨간색: 틀리면 게임오버
    Waiting = { R = 0.7, G = 0.7, B = 0.7, A = 1.0 },    -- 회색: 게임 로딩 대기
}

local KIND_COLOR = { danger = COLOR.Critical, seek = COLOR.Anomaly, action = COLOR.Anomaly, harmless = COLOR.Harmless }

-- 역 이름 (게임 문자열 테이블 ST_Station 실측)
local STATIONS = {
    [0] = { kr = "零山", en = "Reizen" },
    [1] = { kr = "一ヶ崎", en = "Ichigasaki" },
    [2] = { kr = "ニノ塚", en = "Ninozuka" },
    [3] = { kr = "三挫", en = "Sanza" },
    [4] = { kr = "四蝸川", en = "Shirakawa" },
    [5] = { kr = "五ッ原", en = "Itsuzuhara" },
    [6] = { kr = "六下", en = "Muge" },
    [7] = { kr = "七和多", en = "Nawata" },
    [8] = { kr = "八番", en = "Hachiban" },
}

local MSG = {
    NextLabel = { kr = "[다음 역 %s(L%d)] ", en = "[NEXT %s(L%d)] " },
    ArrivedLabel = { kr = "[八番(L8) 도착] ", en = "[HACHIBAN(L8)] " },
    Waiting = { kr = "열차 정보를 기다리는 중...", en = "Waiting for train..." },
    WaitingAdvice = { kr = "게임이 시작되면 자동으로 표시됩니다.", en = "HUD will appear once the game starts." },
    NormalTitle = { kr = "이상현상 없음 (정상 칸)", en = "No Anomaly (Normal Car)" },
    SafeAdvice = { kr = "안전합니다. 다음 칸으로 계속 진행하세요!", en = "Safe. Keep going to the next car!" },
    LastTitle = { kr = "이상현상 없음 ★ 다음은 8번 승강장 ★", en = "No Anomaly ★ Next Stop: Platform 8 ★" },
    LastAdvice = { kr = "그대로 다음 칸으로 가면 8번 승강장에 도착합니다!", en = "Go to the next car to reach Platform 8!" },
    GoalTitle = { kr = "★ 8번 승강장 도착 ★", en = "★ Arrived at Platform 8 ★" },
    GoalAdvice = { kr = "탈출 성공! 문이 열리면 열차에서 내리세요!", en = "Escape! Get off when the doors open!" },
    AnomalyPrefix = { kr = "[이상현상 감지] ", en = "[ANOMALY] " },
    NewSpawnPrefix = { kr = "[★ 신규 이변 스폰! ★] ", en = "[★ NEW SPAWN! ★] " },
    FoundPrefix = { kr = "[숨은 이변 발견 완료] ", en = "[HIDDEN ANOMALY FOUND] " },
    FoundAdvice = { kr = "문이 열립니다. 다음 칸으로 진행하세요!", en = "The door opens. Go to the next car!" },
    AdvicePrefix = { kr = "대처법: ", en = "How to handle: " },
    DangerSuffix = { kr = " (틀리면 게임오버)", en = " (mistake = game over)" },
    UnknownAdvice = { kr = "전광판/바닥의 지시를 확인하고 따르세요", en = "Check the LED board / floor and follow its instructions" },
}

local NEW_SPAWN_BANNER_MS = 2000

local lastAnomalyKey = ""
local newSpawnTicksLeft = 0
local lastDebugSignature = ""

function Tracker.Init(config, game)
    Config = config
    Game = game
end

local function IsEnglish()
    return Config.HUD_Language == "EN"
end

local function Text(msg)
    return IsEnglish() and msg.en or msg.kr
end

local function Label(count, goal)
    if count >= goal then return Text(MSG.ArrivedLabel) end
    local station = STATIONS[count]
    local name = station and (IsEnglish() and station.en or station.kr) or ""
    return string.format(Text(MSG.NextLabel), name, count)
end

-- 게임 내부 값이 바뀔 때만 한 줄 로그 (실제 게임에서 감지 동작 검증용)
local function DebugState(state)
    local signature = string.format("count=%d/%d anomaly=%s found=%s tag=%s actor=%s car=%s",
        state.count, state.goal, tostring(state.anomaly), tostring(state.seekFound), state.anomalyTag, state.anomalyClass,
        state.carKey and string.format("0x%X", state.carKey) or "nil")
    if signature ~= lastDebugSignature then
        lastDebugSignature = signature
        Util.Log("[Tracker] %s", signature)
    end
end

-- 반환: { title, advice, color } (HUD 모듈이 그대로 그림)
function Tracker.Update()
    local state = Game.ReadTrainState()
    DebugState(state)

    if not state.found then
        lastAnomalyKey = ""
        return { title = Text(MSG.Waiting), advice = Text(MSG.WaitingAdvice), color = COLOR.Waiting }
    end

    local label = Label(state.count, state.goal)

    if state.count >= state.goal then
        lastAnomalyKey = ""
        newSpawnTicksLeft = 0
        return { title = label .. Text(MSG.GoalTitle), advice = ">> " .. Text(MSG.GoalAdvice), color = COLOR.Goal }
    end

    if state.anomaly then
        local info = AnomalyDB.Lookup(state.anomalyTag, state.anomalyClass)
        local name = info and (IsEnglish() and info.en or info.kr) or AnomalyDB.ShortName(state.anomalyTag, state.anomalyClass)

        -- 신규 스폰 순간 감지 → 일정 시간 강조 배너 (같은 이변이라도 칸이 바뀌면 새 스폰)
        local key = state.anomalyTag .. "|" .. tostring(state.carKey)
        if key ~= lastAnomalyKey then
            lastAnomalyKey = key
            newSpawnTicksLeft = math.ceil(NEW_SPAWN_BANNER_MS / Config.TickIntervalMs)
            Util.Log(">>> [ANOMALY SPAWN DETECTED] Next L%d: %s (%s / %s) <<<",
                state.count, info and info.kr or name, state.anomalyTag, state.anomalyClass)
        end

        local isNew = newSpawnTicksLeft > 0
        if isNew then newSpawnTicksLeft = newSpawnTicksLeft - 1 end

        -- 숨은 이변을 찾아서 문이 열린 상태
        if info and info.kind == "seek" and state.seekFound then
            return { title = label .. Text(MSG.FoundPrefix) .. name, advice = ">> " .. Text(MSG.FoundAdvice), color = COLOR.Goal }
        end

        local advice = Text(MSG.UnknownAdvice)
        if info then
            advice = IsEnglish() and info.advice_en or info.advice_kr
            if info.kind == "danger" then advice = advice .. Text(MSG.DangerSuffix) end
        end
        local color = info and KIND_COLOR[info.kind] or COLOR.Anomaly

        local prefix = Text(isNew and MSG.NewSpawnPrefix or MSG.AnomalyPrefix)
        return { title = label .. prefix .. name, advice = ">> " .. Text(MSG.AdvicePrefix) .. advice, color = color }
    end

    lastAnomalyKey = ""
    newSpawnTicksLeft = 0

    if state.count == state.goal - 1 then
        return { title = label .. Text(MSG.LastTitle), advice = ">> " .. Text(MSG.LastAdvice), color = COLOR.Goal }
    end
    return { title = label .. Text(MSG.NormalTitle), advice = ">> " .. Text(MSG.SafeAdvice), color = COLOR.Safe }
end

return Tracker
