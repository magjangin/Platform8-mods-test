-- ===================================================================
-- Platform8 MasterMod - 플레이어 이동 속도 배율
--
-- 플레이어(BP_FPHorrorCharacter_C)는 WalkSpeed / SprintSpeed / CrouchSpeed 변수를 갖고 있고,
-- 실제 이동 속도는 CharacterMovement.MaxWalkSpeed 가 결정한다.
--   * BP 변수에 배율을 곱해 두면, 달리기 시작/멈춤 때 BP 가 배율이 적용된 값을 넣는다.
--   * 폰 생성 시(BeginPlay) 이미 들어간 원래 값이나, BP 가 변수 대신 고정값을 넣는 경우에 대비해
--     MaxWalkSpeed 도 틱마다 현재 상태(걷기/달리기/웅크리기)에 맞춰 준다.
-- 원래 값은 클래스 기본 객체(CDO)에서 읽으므로 핫 리로드로 다시 적용돼도 배율이 겹치지 않는다.
-- 좌석에 앉아 있을 때처럼 게임이 0 등 다른 값으로 묶어 둔 경우는 건드리지 않는다.
-- ===================================================================

local UEHelpers = require("UEHelpers")
local Util = require("platform8.util")

local Player = {}
local Config

local SPEED_VARS = { "WalkSpeed", "SprintSpeed", "CrouchSpeed" }

local base = nil        -- 원래 속도 { WalkSpeed, SprintSpeed, CrouchSpeed }
local loggedPawn = nil  -- 적용 로그를 남긴 폰 주소

function Player.Init(config)
    Config = config
end

local function Near(a, b)
    return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.5
end

-- 클래스 기본 객체(CDO)에서 원래 속도를 읽음 (CDO 를 못 얻으면 지금 폰의 값)
local function ReadBaseSpeeds(pawn)
    local source, sourceName = pawn, "pawn"
    local ok, cdo = pcall(function() return pawn:GetClass():GetCDO() end)
    if ok and Util.IsValid(cdo) then
        source, sourceName = cdo, "CDO"
    end

    local speeds = {}
    for _, name in ipairs(SPEED_VARS) do
        speeds[name] = Util.Get(source, name)
    end
    if speeds.WalkSpeed == nil then return nil end

    Util.Log("Base move speeds from %s: Walk=%s Sprint=%s Crouch=%s", sourceName,
        tostring(speeds.WalkSpeed), tostring(speeds.SprintSpeed), tostring(speeds.CrouchSpeed))
    return speeds
end

-- 게임이 쓰는 걷기/달리기/웅크리기 속도(원래 값 또는 배율 적용 값) 중 하나인지
-- (0 은 게임이 이동을 멈출 때 쓰는 값일 수 있으므로 속도로 치지 않음)
local function IsKnownSpeed(value, multiplier)
    for _, name in ipairs(SPEED_VARS) do
        local speed = base[name]
        if type(speed) == "number" and speed > 0
            and (Near(value, speed) or Near(value, speed * multiplier)) then
            return true
        end
    end
    return false
end

local function DesiredSpeed(pawn, multiplier)
    local state = "WalkSpeed"
    if Util.Get(pawn, "IsCrouching") == true then
        state = "CrouchSpeed"
    elseif Util.Get(pawn, "IsSprinting") == true then
        state = "SprintSpeed"
    end
    return (base[state] or base.WalkSpeed) * multiplier
end

function Player.Tick()
    local multiplier = Config.MoveSpeedMultiplier
    if type(multiplier) ~= "number" or multiplier == 1 then return end

    local pawn = UEHelpers.GetPlayer()
    if not Util.IsValid(pawn) then return end

    base = base or ReadBaseSpeeds(pawn)
    if not base then return end

    -- 1) BP 속도 변수: 아직 원래 값이면 배율 적용
    for _, name in ipairs(SPEED_VARS) do
        if Near(Util.Get(pawn, name), base[name]) then
            Util.Set(pawn, name, base[name] * multiplier)
        end
    end

    -- 2) 실제 이동 속도: 알려진 속도 값일 때만 현재 상태에 맞춤
    local movement = Util.Get(pawn, "CharacterMovement")
    if not Util.IsValid(movement) then return end
    local current = Util.Get(movement, "MaxWalkSpeed")
    local desired = DesiredSpeed(pawn, multiplier)
    local known = IsKnownSpeed(current, multiplier)
    if known and not Near(current, desired) then
        Util.Set(movement, "MaxWalkSpeed", desired)
    end

    local address = pawn:GetAddress()
    if address ~= loggedPawn then
        loggedPawn = address
        Util.Log("Move speed x%s on %s: MaxWalkSpeed %s -> %s", tostring(multiplier), Util.ClassName(pawn),
            tostring(current), known and tostring(desired) or "(unknown value, left as is)")
    end
end

return Player
