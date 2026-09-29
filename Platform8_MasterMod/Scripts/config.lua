-- ===================================================================
-- Platform8 MasterMod Configuration (v1.0)
-- 8번 승강장 (Platform 8) - 세이브 완전 초기화 & 8번 승강장 치트 & 이상현상 HUD 설정
-- (여기에 없는 항목은 main.lua 의 기본값이 사용됩니다)
-- ===================================================================

local Config = {
    -- [기능 1] 키 입력 없는 자동 세이브/해금 완전 초기화 여부
    -- true: 게임 시작 시 발견한 이변/클리어 기록을 모두 지우고 순정(새 게임) 상태로 복원
    AutoReset = true,

    -- [기능 2] 게임 시작 시 바로 8번 승강장으로 보낼지 여부
    -- false: 기본값. 원할 때 F8 또는 숫자 8 키를 눌러 8번 승강장으로 이동
    AutoPlatform8OnStart = false,

    -- [기능 3] 8번 승강장 치트 발동 후 이상현상(이변) 차단 여부
    -- true: 치트 발동 시 현재 이변을 해제하고, 八番 도착까지 새 이변도 계속 해제
    DisableAnomaliesAtPlatform8 = true,

    -- [기능 4] 화면 왼쪽 상단에 현재 이상현상 실시간 HUD 표시 여부
    ShowAnomalyHUD = true,

    -- [기능 4-1] HUD 언어 ("KR": 한국어, "EN": 영어)
    HUD_Language = "KR",

    -- [기능 4-2] HUD 위치(화면 왼쪽 위 기준)와 글자 크기
    HUD_PositionX = 25,
    HUD_PositionY = 25,
    HUD_TitleFontSize = 20,
    HUD_AdviceFontSize = 15,

    -- [기능 4-3] HUD 폰트 선택 키워드 (게임에 로드된 폰트 이름에서 앞에서부터 찾음)
    -- 비워 두면 엔진 기본 폰트(한글 포함)를 씁니다. 게임 폰트(NotoSansJP)에는 한글이 없으니 넣지 마세요.
    HUD_FontHints = {},

    -- [기능 5] 플레이어 이동 속도 배율 (1.0: 원래 속도, 2.0: 두 배)
    -- 걷기/달리기 모두에 적용됩니다.
    MoveSpeedMultiplier = 2.0,

    -- [기능 6] 공포 수위 필터: 이 수위보다 무서운 이상현상은 나오지 않음
    --   3: 전부 나옴 (원래 게임)
    --   2: 쫓아오기/갑툭튀/게임오버 이변(수위 3, 13종) 제외 → 18종만 나옴
    --   1: 괴이한 모습 이변(수위 2, 10종)까지 제외 → 순한 8종만 나옴
    -- 제외한 이변은 게임 안에서 "이미 발견한 이변" 으로 취급됩니다 (엔딩의 발견 개수에 포함).
    MaxScareLevel = 2,

    -- [기능 6-1] 수위와 상관없이 추가로 빼고 싶은 이상현상 (태그 이름을 따옴표로 적고 쉼표로 구분)
    -- 태그 목록 [공포 수위]:
    --   "Human.ChaseDoor"      [3] 문 앞의 머리 없는 아저씨 (쫓아옴)
    --   "KeepEye"              [3] 옆문 앞의 마네킹 ('눈을 떼지 마라')
    --   "KeepEye.Light"        [3] 안쪽 문 앞의 마네킹 (조명 깜빡임)
    --   "GirlDaruma"           [3] 문 앞의 소녀 (무궁화 꽃이 피었습니다)
    --   "GhostWalk"            [3] 다음 칸 문이 열리지 않음 (유령)
    --   "Invisible"            [3] 문이 저절로 열리고 숨소리
    --   "LookBack"             [3] 뒤에서 숨소리와 발소리 ('뒤돌아보지 마라')
    --   "DonotLook"            [3] 문 앞의 얼굴 없는 아저씨 ('보지 마라')
    --   "DoorConnectVoice"     [3] '열어 주세요' 목소리
    --   "Arm"                  [3] 거인의 손 공격
    --   "Crowd"                [3] 승객이 가득 참
    --   "Water"                [3] 차량 침수
    --   "RoomDark"             [3] 정전 + 앞문이 사라짐
    --   "AnomalySeek.Ghost"    [2] 숨은 이변 - 창밖의 머리 없는 사람
    --   "AnomalySeek.AdEye"    [2] 숨은 이변 - 'ZONE' 큰 눈 광고
    --   "AnomalySeek.AdTRPG"   [2] 숨은 이변 - 눈이 칠해진 TRPG 광고
    --   "Girl"                 [2] 칸 한가운데 선 소녀 (창밖에서 찾기)
    --   "Sit"                  [2] 좌석을 가득 채운 마네킹
    --   "Face"                 [2] 창밖에서 거인이 들여다봄
    --   "Hand"                 [2] 붉은 손자국
    --   "Red"                  [2] 차량 전체가 붉어짐
    --   "Glass"                [2] 유리창이 깨짐
    --   "FogStation"           [2] 안개 낀 역 ('내리지 마라')
    --   "AnomalySeek.AdKuuki"  [1] 숨은 이변 - '모두의 공기읽기' 광고
    --   "AnomalySeek.AdNeko"   [1] 숨은 이변 - 네코아자라시 약국 광고
    --   "DoorPassword"         [1] 바닥의 '8→ 9← 4→' 표시
    --   "Tilte"                [1] 차량 전체가 기울어짐
    --   "Human.Photo"          [1] 카메라를 들이대는 아저씨
    --   "DoorConnectMove"      [1] 문이 살짝 열렸다 닫힘
    --   "Handrail"             [1] 흔들리는 손잡이
    --   "DoorExitOpen"         [1] 모든 출입문이 열림
    -- 예) ExcludedAnomalies = { "Face", "Hand" },
    ExcludedAnomalies = {},

    -- [단축키 설정] (UE4SS Key enum 이름)
    -- 즉시 8번 승강장 치트 키
    Key_Platform8 = "F8",
    Key_Platform8_Alt = "EIGHT",   -- 키보드 숫자 8 키도 지원

    -- 수동 세이브 완전 초기화 키 (언제든 누르면 새 게임 상태로 완전 리셋)
    Key_ManualReset = "F7",

    -- 화면 좌측 상단 이상현상 실시간 HUD On/Off 토글 키
    Key_ToggleHUD = "F9",

    -- 가디언/HUD 갱신 주기 (밀리초)
    TickIntervalMs = 150,

    -- UE4SS 콘솔 상세 디버그 로그 출력 여부
    DebugLogging = true
}

return Config
