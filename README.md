# 8번 승강장 (Platform 8) - 통합 마스터 모드 (UE4SS)

[![Game](https://img.shields.io/badge/Game-Platform_8_(8번_승강장)-orange.svg)](https://store.steampowered.com/app/2903560/)
[![Engine](https://img.shields.io/badge/Engine-Unreal_Engine_5.2-313131.svg?logo=unrealengine)](https://www.unrealengine.com/)
[![Framework](https://img.shields.io/badge/Modding_Framework-UE4SS_v3.0+-blue.svg)](https://github.com/UE4SS-RE/RE-UE4SS)
[![Script](https://img.shields.io/badge/Language-Lua-000080.svg?logo=lua)](https://www.lua.org/)
[![Version](https://img.shields.io/badge/Mod_Version-v1.0-brightgreen.svg)]()

KOTAKE CREATE 의 기차 이상현상 찾기 게임 **《8번 승강장 (Platform 8)》** 용 UE4SS 통합 치트 및 세이브 관리 모드입니다.

[8번 출구 마스터 모드](https://github.com/magjangin/the-exit-8-mods-test)와 같은 구성(즉시 도착 치트 / 세이브 완전 초기화 / 이상현상 HUD / 이동 속도)을 8번 승강장의 열차 구조에 맞춰 새로 만들었고, 무서운 이상현상을 걸러 주는 **공포 수위 필터**를 더했습니다.

---

## 📌 주요 기능

### 1. 단 1회 입력으로 즉시 8번 승강장 도착
* **단축키**: **`F8`** 또는 키보드 숫자 **`8`**
* 역 진행을 八番(L8) 직전으로 맞춘 뒤 게임 자체의 "다음 역" 처리를 실행합니다. 열차가 **八番 승강장에 정차**하고, 문이 열리면 내려서 클리어하면 됩니다.
* 발동 시 현재 칸의 이상현상을 해제하고, 도착할 때까지 새 이상현상도 계속 해제합니다.
* 클리어·엔딩·도전과제는 게임이 원래대로 처리합니다.

### 2. 🧭 화면 좌측 상단 이상현상 실시간 HUD (대처법 안내)
* 게임을 시작한 **零山(L0)** 부터 **八番(L8)** 까지 다음 역 이름과 현재 칸의 상태를 상시 표시합니다.
* 8번 승강장은 8번 출구와 달리 **뒤로 돌아갈 수 없고**, 이상현상마다 대처법이 다릅니다. HUD 가 **이상현상 이름 + 대처법**을 알려줍니다.
  * 🔵 정상 칸: `[다음 역 一ヶ崎(L1)] 이상현상 없음 (정상 칸) >> 안전합니다. 다음 칸으로 계속 진행하세요!`
  * 🟠 찾기/행동: `[다음 역 零山(L0)] [★ 신규 이변 스폰! ★] [숨은 이변] 'ZONE' 큰 눈 광고 >> 대처법: 큰 눈 광고를 찾아 원래대로 돌아올 때까지 바라보세요`
  * 🔴 게임오버 위험: `... 문 앞의 소녀 (무궁화 꽃이 피었습니다) >> 대처법: 어두울 때만 움직이고 밝으면 멈추세요 (틀리면 게임오버)`
  * 🟡 무해함: `... 모든 출입문이 열림 >> 대처법: 무시하고 다음 칸 문으로 걸어가세요`
  * 🟢 도착: `[八番(L8) 도착] ★ 8번 승강장 도착 ★ >> 탈출 성공! 문이 열리면 열차에서 내리세요!`
* 이상현상은 칸을 옮기는 순간 추첨되므로, 게임이 이상현상을 켜기 약 2초 전부터 미리 표시됩니다.
* UMG 위젯으로 그려서 Shipping 빌드에서도 동작하고, 한글과 역 이름 한자가 모두 나옵니다.
* **HUD On/Off**: **`F9`**

### 3. 😌 공포 수위 필터 (무서운 이상현상 끄기)
* 31종 이상현상에 공포 수위(1~3)를 매기고, **`MaxScareLevel`** 보다 무서운 것은 아예 나오지 않게 합니다.

| `MaxScareLevel` | 나오는 이상현상 | 빠지는 것 |
| :---: | :---: | :--- |
| **3** | 31종 (원래 게임) | 없음 |
| **2** (기본) | 18종 | 쫓아오기·갑툭튀·게임오버 13종 (마네킹 2종, 무궁화 소녀, 유령, 투명 존재, 머리/얼굴 없는 아저씨, 뒤돌아보지 마라, '열어 주세요', 거인의 손, 군중, 침수, 정전) |
| **1** | 8종 | 위 13종 + 괴이한 모습 10종 (창밖의 사람·거인 얼굴, 핏자국, 마네킹 좌석, 붉은 조명 등) |

* 수위와 별개로 `ExcludedAnomalies` 에 태그를 적어 개별로 뺄 수도 있습니다.
* 제외한 이상현상은 게임 안에서 "이미 발견한 이상현상" 으로 취급됩니다 (엔딩의 발견 개수에 포함).

### 4. 세이브 및 해금 데이터 완전 초기화 (Clean Vanilla Reset)
* **자동 실행 (`AutoReset = true`)**: 게임을 켤 때마다 세이브를 순정 새 게임 상태로 되돌립니다.
  * `Clear`, `AllAno`, `AnomalyEncount` = `false`
  * 전체 이상현상 31종을 미발견 목록으로 복원, 하드 이상현상 12종 복원, 걸음 수 0
* **수동 초기화**: 플레이 도중 **`F7`**
* 발견 기록을 유지하고 싶으면 `AutoReset = false`.

### 5. 플레이어 이동 속도 배율
* `MoveSpeedMultiplier` (기본 설정 2.0배). 걷기/달리기/웅크리기에 모두 적용되고, 좌석에 앉아 있을 때는 건드리지 않습니다.

---

## ⌨️ 단축키 안내 (Default Hotkeys)

| 단축키 | 기능 명칭 | 설명 |
| :--- | :--- | :--- |
| **`F8`** 또는 **`8`** | **즉시 8번 승강장 도착** | 역 진행을 八番 직전으로 맞추고 다음 역 처리를 실행 → 열차가 八番에 정차 |
| **`F7`** | **수동 세이브 완전 초기화** | 발견 기록/클리어 상태를 새 게임(미발견 31종)으로 리셋 |
| **`F9`** | **이상현상 HUD 토글** | 좌측 상단 HUD (다음 역 / 이상현상 / 대처법) On/Off |

> 💡 단축키와 옵션은 [`Platform8_MasterMod/Scripts/config.lua`](Platform8_MasterMod/Scripts/config.lua) 에서 바꿀 수 있습니다.

---

## 🛠️ 설치 및 적용 방법 (Installation)

### 1. 사전 필수 요구사항
1. 스팀에서 **《8번 승강장 (Platform 8)》** 을 설치합니다.
2. [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/releases) 최신 릴리스(x64)를 게임 실행 파일 폴더에 설치합니다.
   * 설치 경로: `<게임설치경로>\Platform8\Binaries\Win64\`
   * (`dwmapi.dll`, `ue4ss\` 폴더 등이 위치해야 함. 게임 실행 파일 이름은 `Exit8-Win64-Shipping.exe` 입니다)

### 2. 모드 파일 배치
이 저장소의 `Platform8_MasterMod` 폴더를 통째로 UE4SS 모드 경로에 복사합니다.

```plaintext
<게임설치경로>\Platform8\Binaries\Win64\ue4ss\Mods\Platform8_MasterMod\
├── enabled.txt
├── README.md
└── Scripts/
    ├── config.lua
    ├── main.lua
    └── platform8/
        ├── anomaly_db.lua
        ├── game.lua
        ├── hud.lua
        ├── player.lua
        ├── tracker.lua
        └── util.lua
```

### 3. 모드 활성화 (mods.txt)
`<게임설치경로>\Platform8\Binaries\Win64\ue4ss\Mods\mods.txt` 의 `Keybinds : 1` 위에 아래 줄을 추가합니다.

```ini
Platform8_MasterMod : 1
```

---

## ⚙️ 상세 환경 설정 (`config.lua`)

```lua
local Config = {
    AutoReset = true,                    -- 게임 시작 시 세이브를 새 게임 상태로 초기화
    AutoPlatform8OnStart = false,        -- 시작하자마자 8번 승강장으로 보내기
    DisableAnomaliesAtPlatform8 = true,  -- F8 발동 후 도착까지 이상현상 차단

    ShowAnomalyHUD = true,               -- 좌측 상단 HUD
    HUD_Language = "KR",                 -- "KR": 한국어, "EN": 영어
    HUD_PositionX = 25,
    HUD_PositionY = 25,
    HUD_TitleFontSize = 20,
    HUD_AdviceFontSize = 15,
    HUD_FontHints = {},                  -- 비워 두면 엔진 기본 폰트(한글 포함)

    MoveSpeedMultiplier = 2.0,           -- 이동 속도 배율

    MaxScareLevel = 2,                   -- 공포 수위 필터 (1: 순한 8종 / 2: 18종 / 3: 전부)
    ExcludedAnomalies = {},              -- 개별로 뺄 이상현상 태그 (목록은 config.lua 주석 참고)

    Key_Platform8 = "F8",
    Key_Platform8_Alt = "EIGHT",
    Key_ManualReset = "F7",
    Key_ToggleHUD = "F9",

    TickIntervalMs = 150,                -- 가디언/HUD 갱신 주기 (밀리초)
    DebugLogging = true                  -- UE4SS.log 상세 로그
}
```

---

## 🚃 이상현상 31종 (태그 / 공포 수위 / 대처법)

| 수위 | 태그 | 이상현상 | 대처법 |
| :---: | :--- | :--- | :--- |
| 3 | `Human.ChaseDoor` | 문 앞의 머리 없는 아저씨 | 돌아보기 전에 재빨리 문을 연다 |
| 3 | `KeepEye` | 옆문 앞의 마네킹 ('눈을 떼지 마라') | 눈을 떼지 말고 걸어가 문을 연다 |
| 3 | `KeepEye.Light` | 안쪽 문 앞의 마네킹 (조명 깜빡임) | 밝을 때 달려서 통과 |
| 3 | `GirlDaruma` | 문 앞의 소녀 (무궁화 꽃이 피었습니다) | 어두울 때만 움직인다 |
| 3 | `GhostWalk` | 다음 칸 문이 열리지 않음 | 반대쪽 문을 보고 피한 뒤 다시 문 터치 |
| 3 | `Invisible` | 문이 저절로 열리고 숨소리 | 문이 저절로 닫힐 때까지 기다린다 |
| 3 | `LookBack` | 뒤에서 숨소리와 발소리 ('뒤돌아보지 마라') | 앞만 보고 진행 |
| 3 | `DonotLook` | 문 앞의 얼굴 없는 아저씨 ('보지 마라') | 시야에 넣지 않고 진행 |
| 3 | `DoorConnectVoice` | '열어 주세요' 목소리 | 문 앞에서 목소리가 사라질 때까지 기다린다 |
| 3 | `Arm` | 거인의 손 공격 | 옆문 앞을 피해서 달린다 |
| 3 | `Crowd` | 승객이 가득 참 | 부딪히지 않게 지나간다 |
| 3 | `Water` | 차량 침수 | 달려서 다음 칸으로 |
| 3 | `RoomDark` | 정전 + 앞문이 사라짐 | 아무것도 없는 옆쪽으로 간다 |
| 2 | `AnomalySeek.Ghost` | 창밖의 머리 없는 사람 (숨은 이변) | 찾아서 사라질 때까지 바라본다 |
| 2 | `AnomalySeek.AdEye` | 'ZONE' 큰 눈 광고 (숨은 이변) | 원래대로 돌아올 때까지 바라본다 |
| 2 | `AnomalySeek.AdTRPG` | 눈이 칠해진 TRPG 광고 (숨은 이변) | 찾아서 계속 바라본다 |
| 2 | `Girl` | 칸 한가운데 선 소녀 | 창밖을 둘러보며 찾는다 |
| 2 | `Sit` | 좌석을 가득 채운 마네킹 | 문을 한 번 터치한 뒤 빈자리에 앉는다 |
| 2 | `Face` | 창밖에서 거인이 들여다봄 | 무시하고 진행 |
| 2 | `Hand` | 붉은 손자국 | 무시하고 진행 |
| 2 | `Red` | 차량 전체가 붉어짐 | 무시하고 진행 |
| 2 | `Glass` | 유리창이 깨짐 | 무시하고 진행 |
| 2 | `FogStation` | 안개 낀 역 ('내리지 마라') | 내리지 말고 기다린다 |
| 1 | `AnomalySeek.AdKuuki` | '모두의 공기읽기' 광고 (숨은 이변) | 찾아서 계속 바라본다 |
| 1 | `AnomalySeek.AdNeko` | 네코아자라시 약국 광고 (숨은 이변) | 찾아서 계속 바라본다 |
| 1 | `DoorPassword` | 바닥의 '8→ 9← 4→' 표시 | 표시 순서대로 문을 터치 |
| 1 | `Tilte` | 차량 전체가 기울어짐 | 타이밍을 봐서 진행 |
| 1 | `Human.Photo` | 카메라를 들이대는 아저씨 | 아무것도 하지 말고 진행 |
| 1 | `DoorConnectMove` | 문이 살짝 열렸다 닫힘 | 아무것도 하지 말고 진행 |
| 1 | `Handrail` | 흔들리는 손잡이 | 무시하고 진행 |
| 1 | `DoorExitOpen` | 모든 출입문이 열림 | 무시하고 다음 칸 문으로 |

> 대처법은 [game8.jp 이상현상 목록](https://game8.jp/platform8/613017)을 게임 태그와 대응시킨 것입니다. `GhostWalk` 와 `Invisible` 은 이름과 효과음 에셋으로 추정해 대응시켰으니, 실제 화면과 다르면 [`anomaly_db.lua`](Platform8_MasterMod/Scripts/platform8/anomaly_db.lua) 에서 두 항목을 서로 바꾸면 됩니다.

---

## 🔍 기술 분석 (UE4SS 로 실측한 게임 구조)

| 대상 | 클래스 / 멤버 | 의미 |
| :--- | :--- | :--- |
| 역 진행 | `PlayerState_Platform8_C.CountNumber` / `Max = 9` | 0~8 = "다음 역 L0~L8", 9 = 八番 도착 |
| 진행 가산 | `PlayerState_Platform8_C.SetCount(Add)`, `Move 0 Station()` | 0~Max 로 제한되는 가산 / 0 으로 리셋 |
| 다음 역 | `BP_Train_C.MoveNextStation()` | 진행 +1, 역 표지판 갱신, Max 에 닿으면 `TrainStop(Clear)` + `Goal()` |
| 현재 칸 | `PlayerState_Platform8_C.CurrentTrain` | 열차 칸 3개(`BP_Train_C`)가 순환 배치됨 |
| 이상현상 | `BP_AnomalyManager_C` | 칸 이동 시 태그 추첨 → `CurrentAnomalyComp`/`CurrentAnomalyTag`, 약 2초 뒤 `Anomaly Active` |
| 이상현상 해제 | `BP_AnomalyManager_C."Deactive Current Anomaly"` | 칸을 옮길 때 게임도 호출 |
| 추첨 순서 | 세이브 `Not Found Anomaly` → `GameInstance.UseTag` / `UseTag_ChangeMana` | 못 본 이상현상부터 나옴. 필터는 네 목록(+`Hard Anomaly`)에서 모두 뺌 |
| 세이브 | `GameInstance_Platform8_C."Save Game"` (`Save_Game_C`) | `Clear`, `AllAno`, `AnomalyEncount`, `Not Found/Hard/All Anomaly` |
| 역 이름 | `ST_Station` 문자열 테이블 | 零山, 一ヶ崎, ニノ塚, 三挫, 四蝸川, 五ッ原, 六下, 七和多, 八番 |

### Q. 왜 8번 출구 모드를 그대로 쓸 수 없나?
1. 실행 파일 이름(`Exit8-Win64-Shipping.exe`)과 일부 에셋은 8번 출구 코드베이스를 그대로 쓰지만, 복도(`BP_PathBP1`) 대신 열차(`BP_Train`), 이변 관리자도 `BP_AnomalyManager` 로 바뀌었습니다.
2. 8번 출구는 "이상현상이면 U턴" 이지만, 8번 승강장은 **지나온 연결문이 잠겨** 뒤로 갈 수 없고 이상현상마다 대처법이 다릅니다.
3. 역 번호는 복도 번호 대신 `PlayerState.CountNumber` 로 관리되고, 최대값(9)에 닿는 순간 열차가 八番에 정차합니다.

### Q. HUD 는 왜 UMG 이고, 한글은 어떻게 나오나?
1. Shipping 빌드라 `PrintString` 화면 출력이 컴파일 제외되어 있고, HUD 클래스도 BP 에서 `ReceiveDrawHUD` 를 구현하지 않습니다.
2. 그래서 `UserWidget` + `WidgetTree` 를 런타임에 직접 만들어 뷰포트에 붙입니다.
3. 게임 폰트(NotoSansJP, Jupiteroid, Exo2 등)에는 한글이 없어서, 엔진 기본 Roboto 컴포지트 폰트의 DroidSansFallback 으로 한글을 그립니다.

---

## 📂 프로젝트 구조

```
Platform8-mods-test/
├── .gitignore
├── README.md                          # 저장소 종합 안내서 (본 파일)
└── Platform8_MasterMod/               # UE4SS 적용용 모드 패키지
    ├── enabled.txt                    # UE4SS 모드 활성화 플래그
    ├── README.md                      # 모드 상세 설명
    └── Scripts/
        ├── config.lua                 # 모드 설정 파일
        ├── main.lua                   # 진입점: 설정 로드, 단축키/훅/틱 루프 연결
        └── platform8/
            ├── util.lua               # 로그, 안전한 프로퍼티/함수 접근
            ├── game.lua               # 세이브 리셋, 8번 승강장 적용, 이상현상 제거/필터, 열차 상태 읽기
            ├── anomaly_db.lua         # 이상현상 태그 → 이름 / 대처법 / 공포 수위
            ├── tracker.lua            # 이상현상 감지 → HUD 문구/색상
            ├── hud.lua                # UMG 오버레이 위젯
            └── player.lua             # 플레이어 이동 속도 배율
```

---

## 📜 라이선스 및 주의사항

* 본 프로젝트는 개인 모딩 연구 및 테스트 목적으로 제작되었습니다.
* 게임 원본의 저작권은 원작자 **KOTAKE CREATE** 에 있습니다.
