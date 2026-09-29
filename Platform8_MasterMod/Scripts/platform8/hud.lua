-- ===================================================================
-- Platform8 MasterMod - 화면 좌측 상단 오버레이 HUD (UMG 위젯)
--
-- 이 게임은 Shipping 빌드라서
--   * KismetSystemLibrary:PrintString 이 엔진에서 컴파일 제외되어 아무것도 안 그리고
--   * AHUD:ReceiveDrawHUD 는 게임 HUD 가 BP 에서 구현하지 않아 호출 자체가 되지 않는다.
-- 그래서 UserWidget + WidgetTree 를 런타임에 직접 만들어 뷰포트에 붙인다.
--
-- 폰트: 게임 폰트(NotoSansJP 등)에는 한글이 없다. 기본값(HUD_FontHints 비움)이면
-- 엔진 기본 폰트(Roboto + DroidSansFallback)를 써서 한글/한자가 모두 나온다.
-- ===================================================================

local UEHelpers = require("UEHelpers")
local Util = require("platform8.util")

local Hud = {}
local Config

-- ESlateVisibility
local VISIBILITY_COLLAPSED = 1
local VISIBILITY_HIT_TEST_INVISIBLE = 3 -- 보이지만 마우스 입력은 가로채지 않음

local BACKGROUND_COLOR = { R = 0.03, G = 0.03, B = 0.06, A = 0.82 }
local ADVICE_COLOR = { R = 1.0, G = 1.0, B = 1.0, A = 0.95 }
local SHADOW_COLOR = { R = 0.0, G = 0.0, B = 0.0, A = 0.85 }

local RETRY_TICKS = 10 -- 위젯 생성/부착 실패 시 재시도 간격

local ui = nil          -- { widget, accent, title, advice }
local shown = { title = nil, advice = nil, color = nil }
local retryTicks = 0
local nameCounter = 0
local hudFont = nil
local hudFontName = nil -- nil: 아직 탐색 전, false: 맞는 폰트 없음(엔진 기본), 문자열: 고른 폰트의 GetFullName()

function Hud.Init(config)
    Config = config
end

local function ToText(str)
    if FText then
        return FText(str)
    end
    return UEHelpers.GetKismetTextLibrary():Conv_StringToText(str)
end

local function Construct(classPath, outer, baseName)
    local class = StaticFindObject(classPath)
    if not Util.IsValid(class) then
        error("class not found: " .. classPath)
    end
    -- 재생성 시 이름 충돌(기존 객체 덮어쓰기)을 막기 위해 매번 고유 이름 사용
    nameCounter = nameCounter + 1
    local name = FName(string.format("P8Mod_%s_%d", baseName, nameCounter), EFindName.FNAME_Add)
    local obj = StaticConstructObject(class, outer, name)
    if not Util.IsValid(obj) then
        error("failed to construct " .. classPath)
    end
    return obj
end

-- HUD_FontHints 키워드로 게임에 로드된 폰트를 탐색 (없으면 nil → 엔진 기본 폰트 사용)
local function SearchHudFont()
    local hints = Config.HUD_FontHints or {}
    if #hints == 0 then
        Util.Log("HUD_FontHints empty. Using engine default font (Roboto + DroidSansFallback).")
        return nil
    end

    local fonts = {}
    for _, font in ipairs(FindAllOf("Font") or {}) do
        if font:IsValid() then
            local fullName = font:GetFullName()
            if not fullName:find("Default__", 1, true) then
                fonts[#fonts + 1] = { obj = font, name = fullName }
            end
        end
    end
    local names = {}
    for _, f in ipairs(fonts) do names[#names + 1] = f.name end
    Util.Log("Loaded fonts (%d): %s", #fonts, table.concat(names, " | "))

    for _, hint in ipairs(hints) do
        local needle = hint:lower()
        for _, f in ipairs(fonts) do
            if f.name:lower():find(needle, 1, true) then
                Util.Log("HUD font selected by hint '%s': %s", hint, f.name)
                return f.obj
            end
        end
    end
    Util.Log("No font matched HUD_FontHints. Using engine default font.")
    return nil
end

local function IsFont(obj, fullName)
    return Util.IsValid(obj) and obj:GetFullName() == fullName
end

-- 전에 고른 폰트를 경로로 다시 찾는다 (메모리에서 빠졌으면 디스크에서 다시 로드)
local function ReloadFont(fullName)
    local path = fullName:match("^%S+%s+(.+)$") -- "Font /Game/..." → "/Game/..."
    if not path then return nil end

    local font = StaticFindObject(path)
    if not IsFont(font, fullName) then
        local ok, loaded = pcall(LoadAsset, path)
        font = ok and loaded or nil
    end
    return IsFont(font, fullName) and font or nil
end

-- 레벨 전환 때 이전 HUD 가 사라지면 폰트도 GC 로 해제될 수 있다.
-- 해제된 폰트를 새 HUD 에 넣으면 글자가 0 크기로 그려지므로 캐시한 폰트가 살아 있는지 매번 확인한다.
local function GetHudFont()
    if hudFontName == nil then
        hudFont = SearchHudFont()
        hudFontName = hudFont and hudFont:GetFullName() or false
        return hudFont
    end
    if not hudFontName then return nil end
    if IsFont(hudFont, hudFontName) then return hudFont end

    hudFont = ReloadFont(hudFontName)
    if hudFont then
        Util.Log("HUD font was unloaded, reloaded: %s", hudFontName)
    else
        Util.Log("HUD font was unloaded and could not be reloaded: %s. Searching again.", hudFontName)
        hudFont = SearchHudFont()
        hudFontName = hudFont and hudFont:GetFullName() or false
    end
    return hudFont
end

local function MakeText(tree, baseName, fontSize, font)
    local text = Construct("/Script/UMG.TextBlock", tree, baseName)
    -- 뷰포트에 붙이기 전(Slate 위젯 생성 전)에 값을 바꿔야 적용된다
    local ok, err = pcall(function()
        if font then text.Font.FontObject = font end
        text.Font.Size = fontSize
    end)
    if not ok then Util.Log("Failed to set HUD font: %s", tostring(err)) end
    pcall(function()
        text:SetShadowOffset({ X = 1.5, Y = 1.5 })
        text:SetShadowColorAndOpacity(SHADOW_COLOR)
    end)
    return text
end

local function Build()
    local gi = UEHelpers.GetGameInstance()
    if not Util.IsValid(gi) then return nil end
    -- 월드/플레이어가 준비되기 전에는 AddToViewport 가 무시되므로 기다린다
    if not Util.IsValid(UEHelpers.GetPlayerController()) then return nil end

    local font = GetHudFont()

    local widget = Construct("/Script/UMG.UserWidget", gi, "HUD")
    local tree = Construct("/Script/UMG.WidgetTree", widget, "Tree")
    widget.WidgetTree = tree

    local canvas = Construct("/Script/UMG.CanvasPanel", tree, "Canvas")
    tree.RootWidget = canvas

    -- 반투명 배경 박스: [상태 색상 바] 아래에 [제목 / 안내] 두 줄
    local panel = Construct("/Script/UMG.Border", tree, "Panel")
    panel:SetBrushColor(BACKGROUND_COLOR)
    panel:SetPadding({ Left = 0, Top = 0, Right = 0, Bottom = 0 })

    local layout = Construct("/Script/UMG.VerticalBox", tree, "Layout")
    panel:SetContent(layout)

    local accent = Construct("/Script/UMG.Border", tree, "Accent")
    accent:SetPadding({ Left = 0, Top = 0, Right = 0, Bottom = 0 })
    local accentHeight = Construct("/Script/UMG.Spacer", tree, "AccentHeight")
    accentHeight:SetSize({ X = 1, Y = 4 })
    accent:SetContent(accentHeight)
    layout:AddChildToVerticalBox(accent)

    local rows = Construct("/Script/UMG.VerticalBox", tree, "Rows")
    local rowsSlot = layout:AddChildToVerticalBox(rows)
    rowsSlot:SetPadding({ Left = 16, Top = 10, Right = 16, Bottom = 12 })

    local title = MakeText(tree, "Title", Config.HUD_TitleFontSize, font)
    rows:AddChildToVerticalBox(title)

    local advice = MakeText(tree, "Advice", Config.HUD_AdviceFontSize, font)
    local adviceSlot = rows:AddChildToVerticalBox(advice)
    adviceSlot:SetPadding({ Left = 0, Top = 6, Right = 0, Bottom = 0 })
    pcall(function() advice:SetColorAndOpacity({ SpecifiedColor = ADVICE_COLOR, ColorUseRule = 0 }) end)

    local panelSlot = canvas:AddChildToCanvas(panel)
    panelSlot:SetAutoSize(true)
    panelSlot:SetPosition({ X = Config.HUD_PositionX, Y = Config.HUD_PositionY })

    widget:SetVisibility(VISIBILITY_HIT_TEST_INVISIBLE)
    widget:AddToViewport(Config.HUD_ZOrder)

    shown = { title = nil, advice = nil, color = nil }
    Util.Log("Anomaly HUD widget created (%s)", widget:GetFullName())
    return { widget = widget, accent = accent, title = title, advice = advice }
end

local function IsAlive()
    if not ui or not Util.IsValid(ui.widget) then return false end
    local ok, inViewport = pcall(function() return ui.widget:IsInViewport() end)
    return ok and inViewport == true
end

-- 위젯이 없거나 레벨 전환 등으로 뷰포트에서 빠졌으면 새로 만든다
local function EnsureWidget()
    if IsAlive() then return true end

    if retryTicks > 0 then
        retryTicks = retryTicks - 1
        return false
    end
    retryTicks = RETRY_TICKS

    local ok, result = pcall(Build)
    if not ok then
        Util.WarnOnce("Failed to create HUD widget: %s", tostring(result))
        ui = nil
        return false
    end
    ui = result
    return IsAlive()
end

local function SameColor(a, b)
    return a and b and a.R == b.R and a.G == b.G and a.B == b.B and a.A == b.A
end

-- view: { title, advice, color }
function Hud.Render(view)
    if not EnsureWidget() then return end

    if view.title ~= shown.title then
        ui.title:SetText(ToText(view.title))
        shown.title = view.title
    end
    if view.advice ~= shown.advice then
        ui.advice:SetText(ToText(view.advice))
        shown.advice = view.advice
    end
    if not SameColor(view.color, shown.color) then
        ui.accent:SetBrushColor(view.color)
        pcall(function() ui.title:SetColorAndOpacity({ SpecifiedColor = view.color, ColorUseRule = 0 }) end)
        shown.color = view.color
    end
end

function Hud.SetVisible(visible)
    if not ui or not Util.IsValid(ui.widget) then return end
    pcall(function()
        ui.widget:SetVisibility(visible and VISIBILITY_HIT_TEST_INVISIBLE or VISIBILITY_COLLAPSED)
    end)
end

return Hud
