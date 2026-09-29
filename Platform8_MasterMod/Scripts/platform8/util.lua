-- ===================================================================
-- Platform8 MasterMod - 공용 유틸리티 (로그 / 안전한 프로퍼티·함수 접근)
-- ===================================================================

local Util = {}

local Config = { DebugLogging = true }

function Util.Init(config)
    Config = config
end

local function Format(fmt, ...)
    if select("#", ...) > 0 then
        return string.format(fmt, ...)
    end
    return tostring(fmt)
end

-- 디버그 로그 (Config.DebugLogging 이 켜져 있을 때만 출력)
function Util.Log(fmt, ...)
    if Config.DebugLogging then
        print(string.format("[Platform8_MasterMod] %s\n", Format(fmt, ...)))
    end
end

-- 경고/오류 로그 (항상 출력)
function Util.Warn(fmt, ...)
    print(string.format("[Platform8_MasterMod][WARN] %s\n", Format(fmt, ...)))
end

-- 같은 메시지가 연속으로 반복될 때는 한 번만 출력 (틱 루프 오류 스팸 방지)
local lastWarnOnce = nil
function Util.WarnOnce(fmt, ...)
    local msg = Format(fmt, ...)
    if msg ~= lastWarnOnce then
        lastWarnOnce = msg
        Util.Warn("%s", msg)
    end
end

function Util.IsValid(obj)
    if obj == nil then return false end
    local ok, valid = pcall(function() return obj:IsValid() end)
    return ok and valid == true
end

-- 이름 후보들 중 처음으로 존재하는 멤버(프로퍼티/함수)를 반환
-- (블루프린트 멤버는 "Save Game" 처럼 공백이 들어간 이름과 "Save_Game" 이 섞여 있음)
function Util.Get(obj, ...)
    if obj == nil then return nil end
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        local ok, value = pcall(function() return obj[name] end)
        if ok and value ~= nil then
            return value
        end
    end
    return nil
end

function Util.Set(obj, name, value)
    if obj == nil then return false end
    return (pcall(function() obj[name] = value end))
end

-- UFunction 호출. names 는 문자열 또는 이름 후보 목록.
-- 출력(out) 파라미터가 있는 BP 함수는 그 자리에 빈 테이블을 넘겨야 한다. 예) Util.Call(ps, "SetCount", 1, {})
-- 반환값: 함수를 찾아 정상 호출했으면 true
function Util.Call(obj, names, ...)
    if obj == nil then return false end
    if type(names) ~= "table" then names = { names } end
    local args = table.pack(...)
    for _, name in ipairs(names) do
        local fn = Util.Get(obj, name)
        if fn then
            local ok, err = pcall(fn, obj, table.unpack(args, 1, args.n))
            if not ok then
                Util.Log("Call %s() failed: %s", name, tostring(err))
            end
            return ok
        end
    end
    return false
end

function Util.ClassName(obj)
    local ok, name = pcall(function() return obj:GetClass():GetFName():ToString() end)
    return ok and name or ""
end

-- FGameplayTag 구조체 → "A.B.C" 문자열
function Util.TagName(tag)
    if tag == nil then return "" end
    local ok, name = pcall(function() return tag.TagName:ToString() end)
    if ok and name and name ~= "None" then return name end
    return ""
end

return Util
