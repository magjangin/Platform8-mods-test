-- ===================================================================
-- Platform8 MasterMod - 이상현상(이변) GameplayTag → 이름 / 대처법
--
-- 8번 출구와 달리 8번 승강장은 지나온 문이 잠겨서 뒤로 갈 수 없다.
-- 이변마다 정해진 대처법을 지키고 다음 칸으로 넘어가면 역이 하나 진행된다.
--
-- 태그 목록은 게임 세이브의 "All Anomaly"(31종)에서 실측, 대처법은 공략 정리(game8.jp) 기준.
-- kind
--   "danger"   : 대처를 틀리면 게임오버(처음 역으로)       → HUD 빨간색
--   "seek"     : 숨은 이변. 노란 '異変発生中' 표지가 사라질 때까지 찾아서 바라봐야 문이 열림 → 주황색
--   "action"   : 특정 행동이 필요한 이변                    → 주황색
--   "harmless" : 무시하고 그냥 진행하면 되는 이변          → 노란색
-- ===================================================================

local AnomalyDB = {}

local Entries = {
    -- [1. 숨은 이변: 찾아서 계속 바라보기]
    ["AnomalySeek.AdKuuki"] = { kind = "seek",
        kr = "[숨은 이변] '모두의 공기읽기' 광고", en = "[Hidden] 'Kuuki Yomi' Ad",
        advice_kr = "이상한 광고를 찾아 계속 바라보세요", advice_en = "Find the odd ad and keep looking at it" },
    ["AnomalySeek.Ghost"] = { kind = "seek",
        kr = "[숨은 이변] 창밖의 머리 없는 사람", en = "[Hidden] Headless Figure Outside",
        advice_kr = "창밖의 사람을 찾아 사라질 때까지 바라보세요", advice_en = "Find the figure outside and watch it until it vanishes" },
    ["AnomalySeek.AdNeko"] = { kind = "seek",
        kr = "[숨은 이변] 네코아자라시 약국 광고", en = "[Hidden] Neko-Azarashi Pharmacy Ad",
        advice_kr = "천장 중간 광고를 찾아 계속 바라보세요", advice_en = "Find the hanging ceiling ad and keep looking at it" },
    ["AnomalySeek.AdEye"] = { kind = "seek",
        kr = "[숨은 이변] 'ZONE' 큰 눈 광고", en = "[Hidden] 'ZONE' Giant Eye Ad",
        advice_kr = "큰 눈 광고를 찾아 원래대로 돌아올 때까지 바라보세요", advice_en = "Find the giant eye ad and watch it until it returns to normal" },
    ["AnomalySeek.AdTRPG"] = { kind = "seek",
        kr = "[숨은 이변] 눈이 칠해진 TRPG 광고", en = "[Hidden] TRPG Ad with Blacked-out Eyes",
        advice_kr = "눈이 까맣게 칠해진 광고를 찾아 계속 바라보세요", advice_en = "Find the ad with blacked-out eyes and keep looking at it" },
    ["Girl"] = { kind = "seek",
        kr = "칸 한가운데 선 소녀", en = "Girl Standing in the Middle",
        advice_kr = "창밖을 둘러보며 소녀를 찾으세요", advice_en = "Look out the windows to find the girl" },

    -- [2. 대처를 틀리면 게임오버]
    ["DonotLook"] = { kind = "danger",
        kr = "문 앞의 얼굴 없는 아저씨 ('보지 마라')", en = "Faceless Man (\"Don't Look\")",
        advice_kr = "아저씨를 시야에 넣지 말고 진행하세요", advice_en = "Keep him out of your view and move on" },
    ["Human.ChaseDoor"] = { kind = "danger",
        kr = "문 앞의 머리 없는 아저씨", en = "Headless Man at the Door",
        advice_kr = "아저씨가 돌아보기 전에 재빨리 문을 여세요", advice_en = "Open the door before he turns around" },
    ["KeepEye"] = { kind = "danger",
        kr = "옆문 앞의 마네킹 ('눈을 떼지 마라')", en = "Mannequin (\"Don't Look Away\")",
        advice_kr = "마네킹에서 눈을 떼지 말고 걸어가 문을 여세요", advice_en = "Keep your eyes on it while walking and open the door" },
    ["KeepEye.Light"] = { kind = "danger",
        kr = "안쪽 문 앞의 마네킹 (조명 깜빡임)", en = "Mannequin by the Far Door (Flicker)",
        advice_kr = "밝을 때 달려서 통과하세요", advice_en = "Sprint through while the lights are on" },
    ["GirlDaruma"] = { kind = "danger",
        kr = "문 앞의 소녀 (무궁화 꽃이 피었습니다)", en = "Girl at the Door (Red Light, Green Light)",
        advice_kr = "어두울 때만 움직이고 밝으면 멈추세요", advice_en = "Move only in the dark, freeze when it's bright" },
    ["GhostWalk"] = { kind = "danger",
        kr = "다음 칸 문이 열리지 않음", en = "Next Door Won't Open",
        advice_kr = "반대쪽 문을 보고 피한 뒤 다시 문을 터치하세요", advice_en = "Look at the opposite door, evade, then touch the door again" },
    ["Invisible"] = { kind = "danger",
        kr = "문이 저절로 열리고 숨소리", en = "Door Opens by Itself, Breathing",
        advice_kr = "문이 저절로 닫힐 때까지 기다리세요", advice_en = "Wait until the door closes by itself" },
    ["DoorConnectVoice"] = { kind = "danger",
        kr = "'열어 주세요' 목소리", en = "\"Please Open\" Voice",
        advice_kr = "문에 다가가 목소리가 사라질 때까지 기다리세요 (열지 말 것)", advice_en = "Go near the door and wait until the voice stops (don't open)" },
    ["RoomDark"] = { kind = "danger",
        kr = "정전 + 앞문이 사라짐", en = "Blackout, Door Vanished",
        advice_kr = "옆쪽 중 아무것도 없는 방향으로 가세요", advice_en = "Take the side path with nothing in it" },
    ["LookBack"] = { kind = "danger",
        kr = "뒤에서 숨소리와 발소리 ('뒤돌아보지 마라')", en = "Breathing Behind You (\"Don't Look Back\")",
        advice_kr = "절대 뒤돌아보지 말고 앞만 보고 진행하세요", advice_en = "Never turn around, keep facing forward" },
    ["Water"] = { kind = "danger",
        kr = "★ 차량 침수 ★", en = "★ Flooding Car ★",
        advice_kr = "달려서 다음 칸으로 가세요!", advice_en = "Sprint to the next car!" },
    ["Crowd"] = { kind = "danger",
        kr = "승객이 가득 참", en = "Crowded Car",
        advice_kr = "승객에게 부딪히지 않게 지나가세요", advice_en = "Pass through without touching anyone" },
    ["Arm"] = { kind = "danger",
        kr = "거인의 손 공격", en = "Giant Hand Attack",
        advice_kr = "옆문 앞을 피해서 달려가세요", advice_en = "Avoid the side doors and sprint" },
    ["FogStation"] = { kind = "danger",
        kr = "바깥이 안개에 싸인 역 ('내리지 마라')", en = "Foggy Station (\"Don't Get Off\")",
        advice_kr = "절대 내리지 말고 열차 안에서 기다리세요", advice_en = "Never get off, wait on the train" },

    -- [3. 특정 행동이 필요한 이변]
    ["DoorPassword"] = { kind = "action",
        kr = "바닥의 '8→ 9← 4→' 표시", en = "'8→ 9← 4→' on the Floor",
        advice_kr = "바닥 표시 순서대로 문을 터치하세요 (8→ 9← 4→)", advice_en = "Touch the doors in the floor's order (8→ 9← 4→)" },
    ["Sit"] = { kind = "action",
        kr = "좌석을 가득 채운 마네킹", en = "Mannequins Filling the Seats",
        advice_kr = "문을 한 번 터치한 뒤 비어 있는 자리에 앉으세요", advice_en = "Touch the door once, then sit in the empty seat" },
    ["Tilte"] = { kind = "action",
        kr = "차량 전체가 기울어짐", en = "Tilted Car",
        advice_kr = "타이밍을 봐서 앞으로 진행하세요", advice_en = "Time your moves and keep going" },

    -- [4. 무시하고 진행하면 되는 이변]
    ["Human.Photo"] = { kind = "harmless",
        kr = "카메라를 들이대는 아저씨", en = "Man Filming You",
        advice_kr = "아무것도 하지 말고 다음 칸으로 가세요", advice_en = "Do nothing, go to the next car" },
    ["DoorConnectMove"] = { kind = "harmless",
        kr = "문이 살짝 열렸다 닫힘", en = "Door Slightly Opening/Closing",
        advice_kr = "아무것도 하지 말고 진행하세요", advice_en = "Do nothing, keep going" },
    ["Handrail"] = { kind = "harmless",
        kr = "흔들리는 손잡이", en = "Swinging Handrails",
        advice_kr = "무시하고 진행하세요", advice_en = "Ignore it and keep going" },
    ["Hand"] = { kind = "harmless",
        kr = "붉은 손자국 대량 발생", en = "Bloody Handprints",
        advice_kr = "무시하고 진행하세요", advice_en = "Ignore it and keep going" },
    ["Red"] = { kind = "harmless",
        kr = "차량 전체가 붉어짐", en = "Red Car",
        advice_kr = "무시하고 진행하세요", advice_en = "Ignore it and keep going" },
    ["DoorExitOpen"] = { kind = "harmless",
        kr = "모든 출입문이 열림", en = "All Doors Open",
        advice_kr = "무시하고 다음 칸 문으로 걸어가세요", advice_en = "Ignore it and walk to the next door" },
    ["Glass"] = { kind = "harmless",
        kr = "유리창이 깨짐", en = "Windows Shatter",
        advice_kr = "무시하고 진행하세요", advice_en = "Ignore it and keep going" },
    ["Face"] = { kind = "harmless",
        kr = "창밖에서 거인이 들여다봄", en = "Giant Faces Outside",
        advice_kr = "무시하고 진행하세요", advice_en = "Ignore it and keep going" },
}

-- 공포 수위 (Config.MaxScareLevel 보다 높은 이변은 나오지 않게 함)
--   3: 쫓아오거나 갑자기 튀어나옴 / 틀리면 게임오버 (게임의 Hard Anomaly 12종 + 정전)
--   2: 괴이한 모습이 보이지만 해치지 않음 (머리 없는 사람, 거인 얼굴, 핏자국, 마네킹 등)
--   1: 순한 편 (광고 이상, 퍼즐, 기울기, 문/손잡이 움직임 등)
local SCARE_LEVEL = {
    ["Human.ChaseDoor"] = 3, ["KeepEye"] = 3, ["KeepEye.Light"] = 3, ["GirlDaruma"] = 3,
    ["GhostWalk"] = 3, ["Invisible"] = 3, ["LookBack"] = 3, ["DonotLook"] = 3,
    ["DoorConnectVoice"] = 3, ["Arm"] = 3, ["Crowd"] = 3, ["Water"] = 3, ["RoomDark"] = 3,

    ["AnomalySeek.Ghost"] = 2, ["AnomalySeek.AdEye"] = 2, ["AnomalySeek.AdTRPG"] = 2,
    ["Girl"] = 2, ["Sit"] = 2, ["Face"] = 2, ["Hand"] = 2, ["Red"] = 2, ["Glass"] = 2, ["FogStation"] = 2,

    ["AnomalySeek.AdKuuki"] = 1, ["AnomalySeek.AdNeko"] = 1, ["DoorPassword"] = 1, ["Tilte"] = 1,
    ["Human.Photo"] = 1, ["DoorConnectMove"] = 1, ["Handrail"] = 1, ["DoorExitOpen"] = 1,
}

-- 태그의 공포 수위 (모르는 태그는 nil)
function AnomalyDB.ScareLevel(tagName)
    return SCARE_LEVEL[tagName]
end

-- 공포 수위가 maxLevel 보다 높은 태그 목록 (정렬됨)
function AnomalyDB.TagsAboveScare(maxLevel)
    local tags = {}
    for tag, level in pairs(SCARE_LEVEL) do
        if level > maxLevel then tags[#tags + 1] = tag end
    end
    table.sort(tags)
    return tags
end

-- 이변 액터 클래스 이름으로도 찾을 수 있게: "BP_Ano_Girl_Daruma_C" → "GirlDaruma" 등
local ClassAliases = {
    BP_Ano_AnomalySeek_AdEye_C = "AnomalySeek.AdEye",
    BP_Ano_AnomalySeek_AdKuuki_C = "AnomalySeek.AdKuuki",
    BP_Ano_AnomalySeek_AdNeko_C = "AnomalySeek.AdNeko",
    BP_Ano_AnomalySeek_AdTRPG_C = "AnomalySeek.AdTRPG",
    BP_Ano_AnomalySeek_Ghost_C = "AnomalySeek.Ghost",
    BP_Ano_Human_DoorChase_C = "Human.ChaseDoor",
    BP_Ano_Human_Photo_C = "Human.Photo",
    BP_Ano_Girl_Daruma_C = "GirlDaruma",
    BP_Ano_DonotLookBack_C = "LookBack",
    BP_Ano_KeepEye_Light_C = "KeepEye.Light",
}

-- GameplayTag 이름(우선) 또는 이변 액터 클래스 이름으로 이변 정보 조회
function AnomalyDB.Lookup(tagName, className)
    if tagName and tagName ~= "" then
        local entry = Entries[tagName]
        if entry then return entry end
        -- "A.B.C" 처럼 더 세분화된 태그는 상위 태그로 다시 찾음
        local parent = tagName:match("^(.*)%.[^%.]+$")
        while parent do
            if Entries[parent] then return Entries[parent] end
            parent = parent:match("^(.*)%.[^%.]+$")
        end
    end
    if className and className ~= "" then
        local alias = ClassAliases[className]
        if alias then return Entries[alias] end
        local base = className:gsub("^BP_Ano_", ""):gsub("_C$", "")
        return Entries[base]
    end
    return nil
end

-- 표시용 이름 (DB 에 없을 때)
function AnomalyDB.ShortName(tagName, className)
    if tagName and tagName ~= "" then return tagName end
    if className and className ~= "" then
        return (className:gsub("^BP_Ano_", ""):gsub("_C$", ""))
    end
    return "Unknown"
end

return AnomalyDB
