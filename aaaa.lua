--[[
    BSU v1.4.1 — Bee Swarm Unleashed
    Reescrito do zero:
      * fila de tarefas por prioridade (cada tarefa diz SE quer rodar e POR QUÊ)
      * interrupção padronizada (token raro, colmeia, etc. param o que estiver rodando)
      * módulos separados (Move, Tok, Bub, Mark, Sprout, Hive, Mob, Fight, Quest, Hook, UI)
      * GUI estilo Atlas (abas + seções expansíveis), busca, config salva sozinha
      * webhook do Discord
    RightShift = mostrar/esconder. Executar de novo fecha o anterior e abre o novo.
]]

------------------------------------------------------------------
-- EXECUTAR DE NOVO: fecha a versão anterior (nova e antiga)
------------------------------------------------------------------
if _G.BSU2 and _G.BSU2.Destroy then pcall(_G.BSU2.Destroy) end
if _G.BSU and _G.BSU.Destroy then pcall(_G.BSU.Destroy) end
task.wait(0.15)

local VERSION = "1.4.1"
local Env = { Running = true, Conns = {} }
_G.BSU2 = Env

------------------------------------------------------------------
-- SERVIÇOS / REFERÊNCIAS
------------------------------------------------------------------
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local RS           = game:GetService("ReplicatedStorage")
local VirtualUser  = game:GetService("VirtualUser")
local Http         = game:GetService("HttpService")

local LP       = Players.LocalPlayer
local PD       = LP:WaitForChild("PlayerData")
local Events   = RS:WaitForChild("Events")
local ServerEv = Events:FindFirstChild("Server")
local Fields   = workspace:WaitForChild("Fields")
local Hives    = workspace:WaitForChild("Hives")
local TokensF  = workspace:WaitForChild("Tokens")
local MobsF    = workspace:WaitForChild("Mobs")
local Spawners = workspace:WaitForChild("MobSpawners")
local FXF      = workspace:WaitForChild("FX", 10)
local BeesF    = workspace:WaitForChild("Bees", 10)
local NPCF     = workspace:FindFirstChild("NPCs")

local function conn(c) table.insert(Env.Conns, c) return c end
local function running() return Env.Running end
local function remote(name)
    return Events:FindFirstChild(name) or (ServerEv and ServerEv:FindFirstChild(name))
end

------------------------------------------------------------------
-- ARQUIVOS
------------------------------------------------------------------
local FILES = {
    cfg    = "BSU2_Config.json",
    owners = "BSU2_QuestOwners.json",
    mobs   = "BSU2_MobData.json",
}
local function readJSON(f)
    local ok, t = pcall(function()
        if isfile and readfile and isfile(f) then return Http:JSONDecode(readfile(f)) end
    end)
    if ok and type(t) == "table" then return t end
    return nil
end
local function writeJSON(f, t)
    pcall(function() if writefile then writefile(f, Http:JSONEncode(t)) end end)
end

------------------------------------------------------------------
-- CONFIG (padrões). Toda opção nova entra aqui + uma linha na GUI.
------------------------------------------------------------------
local UNIQUE_ITEMS = {   -- ordem = prioridade (Egg pega todos os ovos)
    "Egg", "Star Jelly",
    "Medal", "Micro Converter", "Matter", "Field Dice", "Red Extract", "Blue Extract", "Oil", "Enzyme", "Magic Bean",
    "Royal Jelly",
}

local Defaults = {
    -- Farming
    AutoFarm = false, Field = "SunflowerField", AutoTool = true, ToolDelay = 0.15,
    AutoSprinkler = false, Sprinkler = "Basic Sprinkler",
    ToolRange = 10, EdgeMargin = 5, FieldRandom = 30, MinPointDist = 12,
    -- Converter / colmeia
    AutoConvert = true, ConvertPercent = 100, ConvertSettle = 4, ConvertTimeout = 180,
    HiveEdgeMargin = 2.5, AutoClaimHive = true,
    -- Tokens
    AutoTokens = true, OnlyMyTokens = true, IgnoreBomb = false, IgnoreBoost = false,
    TokenPriority = { "Link" }, TokenBlacklist = {},
    AbilityTokens = { "Boost", "Bomb", "Link", "Haste", "Focus", "Melody", "Rage", "Frenzy", "Inspire",
                      "Mark", "Pulse", "Flame", "Glitter", "Tornado", "Scratch", "Bubble" },
    TweenToRare = true, RareTeleport = true, RareTweenSpeed = 300, RareHold = 0.5, RareDuringConvert = true,
    RareTokens = { "Egg", "Star Jelly", "Royal Jelly", "Medal", "Micro Converter", "Matter", "Field Dice",
                   "Red Extract", "Blue Extract", "Oil", "Enzyme", "Magic Bean" },
    -- Bolhas
    AutoBubbles = true, BubblesFirst = true, OnlyMyBubbles = true,
    FarmFlames = true, FlameHeatMax = 80,   -- Dark Flames (padrão, sem opção)
    -- Marks
    StayInMarks = true, MarkPrefer = "HoneyMark+",
    -- Sprout
    AutoSprout = true, SproutLootTime = 90,
    BeanOn = false, BeanField = "", BeanCount = 5, BeanDelay = 10, SproutAllTokens = false, SproutTokenDelay = 0.25,   -- plantar sprouts com Magic Bean
    SproutRarities = {}, SproutRaritiesSeen = {}, SproutRarePlus = false,   -- Rare+: ignora Basic
    -- Combate
    AutoKill = false, KillMobs = {}, KillOnlyAfterConvert = true, FieldMobDodge = true,
    KillTimeout = 150, MobSpawnWait = 8, FightFar = 32, FightSafeExtra = 4, KiteStep = 16, JiggleStep = 3.5, StepDelay = 0.9, StepSize = 6, RetreatHP = 40,
    FightJump = false, LootRadius = 35,
    -- Quests
    AutoQuest = false, QuestNPCs = {}, QuestClaim = {}, QuestField = false, QuestMobs = true, QuestAfterConvert = false,
    TalkDelay = 0.1, QuestInterval = 120, QuestKillBoss = false, FeedForQuests = false,
    BestBlue = "", BestRed = "", BestWhite = "",   -- "" = automático (melhor liberado)
    -- Movimento / geral
    TweenSpeed = 250, Noclip = true, WalkSpeedOn = true, WalkSpeed = 76, AntiAFK = true,
    Unlocked = {},
    -- Webhook
    WebhookOn = false, WebhookURL = "", WebhookPing = "", WebhookInterval = 30,
    WebhookItems = true, WebhookQuests = true, WebhookDeath = true, WebhookDisconnect = true, StatsOn = false, StatsURL = "", StatsSecret = "", GraphWebhookURL = "",
    -- GUI
    UIOpen = {},
    AutoBooster = false, Boosters = {}, BoostFields = {},   -- field boosters (tudo desligado)
    RequireBooster = true, StaggerBoosters = false, UseGlitter = false, UseDice = false, ExtendOnce = false,
    MinBoostFarm = 1, WantedBoost = 2, RenewTime = 70, MaxDicePerRenew = 15,
    AutoMaterials = false, Mats = {}, UseTicketConverters = false, ConverterCD = 5, UseMicroConverters = false, MicroCD = 0, MicroKeep = 0,   -- [item] = { on = bool, interval = n }
    StopEverything = false,   -- pausa tudo que mexe o personagem (jogar na mão)
    -- Hive (ovos, Royal Jelly, level)
    HiveSlot = "", AutoGiftedBasic = false, BuyBasicEggs = false, EggBuyAmount = 10,
    AutoRJ = false, RJStopGifted = false, RJBeeTypes = {}, RJStopRarity = {},
    FeedGifted = false, FeedAmount = 50, FeedLimit = 1000,
    AutoLevelHive = false, TargetLevel = 10,
    CfgVer = 2,
}

local function deepcopy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = deepcopy(x) end
    return t
end

-- ajustes internos da luta: sem opção na GUI, sempre o padrão
local HIDDEN = {
    FightFar = true, FightSafeExtra = true, KiteStep = true, RetreatHP = true, FightJump = true,
    LootRadius = true, KillTimeout = true, MobSpawnWait = true, JiggleStep = true, StepDelay = true, StepSize = true,
    StopEverything = true,   -- sempre começa desligado
    AutoGiftedBasic = true, AutoRJ = true, FeedGifted = true,   -- gastam item: sempre começam desligados
}
local Cfg = {}
for k, v in pairs(Defaults) do Cfg[k] = deepcopy(v) end
do
    local t = readJSON(FILES.cfg)
    if t then
        for k, v in pairs(t) do
            if Defaults[k] ~= nil and type(v) == type(Defaults[k]) and not HIDDEN[k] then Cfg[k] = v end
        end
        -- migração: versão 1 vinha ignorando Bomb por padrão
        if (tonumber(t.CfgVer) or 1) < 2 then Cfg.IgnoreBomb = false end
        Cfg.CfgVer = Defaults.CfgVer
    end
    -- padrão, sem opção: coleta remota de tokens e farm das Dark Flames sempre ligados
    Cfg.AutoTokens, Cfg.FarmFlames, Cfg.SproutAllTokens = true, true, true
    Cfg.SproutLootTime = 120   -- loot da sprout é automático (3s sem "From Sprout"); isso é só o limite interno
end

local CfgListeners = {}
local function onCfg(k, f)
    CfgListeners[k] = CfgListeners[k] or {}
    table.insert(CfgListeners[k], f)
end
local function setCfg(k, v)
    Cfg[k] = v
    local l = CfgListeners[k]
    if l then for _, f in ipairs(l) do pcall(f, v) end end
end

local LastSaved = ""
local function saveCfg()
    pcall(function()
        local json = Http:JSONEncode(Cfg)
        if json ~= LastSaved and writefile then writefile(FILES.cfg, json) LastSaved = json end
    end)
end

------------------------------------------------------------------
-- UTILITÁRIOS
------------------------------------------------------------------
local U = {}
function U.char() return LP.Character end
function U.hrp() local c = LP.Character return c and c:FindFirstChild("HumanoidRootPart") end
function U.hum() local c = LP.Character return c and c:FindFirstChildOfClass("Humanoid") end
function U.alive()
    local h = U.hum()
    return h ~= nil and h.Health > 0 and U.hrp() ~= nil
end
function U.pos(inst)
    if not inst or not inst.Parent then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Model") then
        local ok, cf = pcall(inst.GetPivot, inst)
        if ok then return cf.Position end
    end
    local p = inst:FindFirstChildWhichIsA("BasePart", true)
    return p and p.Position
end
function U.flat(v) return Vector3.new(v.X, 0, v.Z) end
function U.fdist(a, b) return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude end
function U.serverNow() return workspace:GetServerTimeNow() end
function U.key(s) return (tostring(s):lower():gsub("[^%a]", "")) end
-- nome bate com algum item da lista (ignora espaço/maiúscula)?  devolve o índice
function U.match(list, name)
    local n = U.key(name)
    for i, k in ipairs(list) do
        local kk = U.key(k)
        if kk ~= "" and n:find(kk, 1, true) then return i end
    end
    return nil
end
-- distância de p até o segmento a-b (no plano XZ)
function U.segDist(p, a, b)
    local P, A, B = U.flat(p), U.flat(a), U.flat(b)
    local AB = B - A
    local L = AB.Magnitude
    if L < 0.01 then return (P - A).Magnitude end
    local t = math.clamp((P - A):Dot(AB) / (L * L), 0, 1)
    return (P - (A + AB * t)).Magnitude
end
function U.fmtNum(n)
    local s = tostring(math.floor((tonumber(n) or 0) + 0.5))
    local neg = s:sub(1, 1) == "-"
    if neg then s = s:sub(2) end
    s = s:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
    return (neg and "-" or "") .. s
end
function U.short(n)
    n = tonumber(n) or 0
    local a = math.abs(n)
    if a >= 1e12 then return string.format("%.2fT", n / 1e12) end
    if a >= 1e9 then return string.format("%.2fB", n / 1e9) end
    if a >= 1e6 then return string.format("%.2fM", n / 1e6) end
    if a >= 1e3 then return string.format("%.1fK", n / 1e3) end
    return tostring(math.floor(n))
end
function U.fmtTime(s)
    s = math.max(0, math.floor(s))
    local h, m, sec = math.floor(s / 3600), math.floor(s % 3600 / 60), s % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, sec) end
    return string.format("%02d:%02d", m, sec)
end
function U.fname(name) return (tostring(name or "-"):gsub("Field$", "")) end
function U.pollen() return PD.Pollen.Value end
function U.cap() return math.max(PD.Capacity.Value, 1) end
function U.honey() return PD.Honey.Value end
function U.bagPct() return U.pollen() / U.cap() end
function U.bagEmpty() return U.pollen() <= U.cap() * 0.1 end

------------------------------------------------------------------
-- STATUS (o que aparece na Home: tarefa atual e o porquê)
------------------------------------------------------------------
local St = {
    task = "Parado", reason = "", action = "", useTool = false,
    lastBlack = "-", startT = tick(), startHoney = 0, hits = 0, kills = 0, quests = 0,
}
-- CONSOLE: histórico do que o script fez (aba Home + vai no webhook quando desconecta)
local Con = { lines = {}, last = "", lastT = 0 }
function Con.log(kind, text)
    text = tostring(text):gsub("\n", " ")
    if text == Con.last and tick() - Con.lastT < 5 then return end
    Con.last, Con.lastT = text, tick()
    table.insert(Con.lines, string.format("[%s] [%s] %s", os.date("%H:%M:%S"), kind, text))
    if #Con.lines > 300 then table.remove(Con.lines, 1) end
end
function Con.tail(n)
    local t = {}
    for i = math.max(1, #Con.lines - n + 1), #Con.lines do table.insert(t, Con.lines[i]) end
    return t
end
-- ações repetitivas que não vão pro console (senão enche)
local CON_SKIP = { "^Token:", "^Estourando bolha", "^Farmando em", "^Loot da sprout em", "^Lutando", "^Desviando",
    "^Passo %(", "^Finalizando conversão", "mob%(s%)", "^Esquivando", "^Esperando o mob", "^Mobs mortos, conferindo" }
local function act(s)
    St.action = s
    for _, p in ipairs(CON_SKIP) do if tostring(s):find(p) then return end end
    Con.log("Info", s)
end
local Hook = {}   -- webhook (preenchido lá embaixo)
local Boost, TConv       -- field boosters (definido lá embaixo; declarado aqui pra quests usarem)
pcall(function() St.startHoney = U.honey() end)

------------------------------------------------------------------
-- CAMPOS
------------------------------------------------------------------
local F = {}
function F.names()
    local t = {}
    for _, f in ipairs(Fields:GetChildren()) do
        if f:FindFirstChild("Hitbox") then table.insert(t, f.Name) end
    end
    table.sort(t)
    return t
end
function F.hb(name)
    if not name then return nil end
    local f = Fields:FindFirstChild(name) or Fields:FindFirstChild(name .. "Field")
    return f and f:FindFirstChild("Hitbox")
end
function F.inside(hb, pos, pad)
    if not hb or not pos then return false end
    pad = pad or 0
    local p = hb.CFrame:PointToObjectSpace(pos)
    return math.abs(p.X) <= hb.Size.X / 2 + pad and math.abs(p.Z) <= hb.Size.Z / 2 + pad and math.abs(p.Y) <= 25 + pad
end
function F.groundY(hb) return hb.Position.Y - hb.Size.Y / 2 + 3 end
-- margem extra fixa (interna, sem opção) pras fields com borda dentro da parede/decoração
F.EDGE = { rose = 12 }
function F.extra(hb)
    local n = hb and hb.Parent and U.key(hb.Parent.Name) or ""
    for k, v in pairs(F.EDGE) do if n:sub(1, #k) == k then return v end end
    return 0
end
-- dentro da field e longe da borda proibida
function F.safe(hb, p, pad) return F.inside(hb, p, (pad or 0) - F.extra(hb)) end
function F.toWorld(hb, x, z)
    local w = hb.CFrame:PointToWorldSpace(Vector3.new(x, 0, z))
    return Vector3.new(w.X, F.groundY(hb), w.Z)
end
function F.center(hb) return F.toWorld(hb, 0, 0) end
function F.clamp(hb, p, margin)
    local lp = hb.CFrame:PointToObjectSpace(p)
    local mx = math.max(hb.Size.X / 2 - margin, 0.5)
    local mz = math.max(hb.Size.Z / 2 - margin, 0.5)
    return F.toWorld(hb, math.clamp(lp.X, -mx, mx), math.clamp(lp.Z, -mz, mz))
end
function F.edgeDist(hb, p)
    local lp = hb.CFrame:PointToObjectSpace(p)
    return math.min(hb.Size.X / 2 - math.abs(lp.X), hb.Size.Z / 2 - math.abs(lp.Z))
end
function F.of(pos)
    for _, f in ipairs(Fields:GetChildren()) do
        local hb = f:FindFirstChild("Hitbox")
        if hb and F.inside(hb, pos) then return f.Name, hb end
    end
    return nil
end
-- Entrar em campo de zona bloqueada = kick. Só vai em campo marcado (aba Campos).
function F.unlocked(name)
    if not name then return false end
    return Cfg.Unlocked[name] == true or Cfg.Unlocked[name .. "Field"] == true
end

------------------------------------------------------------------
-- AGENDADOR (fila de tarefas). As tarefas são registradas lá embaixo.
------------------------------------------------------------------
local Tasks = {}
local Sched = { cur = nil, abort = false, t = 0 }
function Sched.blocked(t) return false end   -- tarefa bloqueada agora? (preenchido lá embaixo)
-- Chamado dentro de qualquer espera/movimento: true = pare o que está fazendo.
function Sched.check()
    if not running() or not U.alive() then return true end
    if Cfg.StopEverything then return true end
    if Sched.abort then return true end
    if tick() - Sched.t < 0.2 then return false end
    Sched.t = tick()
    local cur = Sched.cur
    if not cur then return false end
    for _, t in ipairs(Tasks) do
        if t == cur then break end
        if (t.all or (t.over and t.over[cur.name])) and not Sched.blocked(t) then
            local ok, r = pcall(t.want)
            if ok and r then
                Sched.abort = true
                act("Interrompido: " .. tostring(r))
                return true
            end
        end
    end
    return false
end

------------------------------------------------------------------
-- MOVIMENTO
------------------------------------------------------------------
local Move = { tweening = false, tw = nil }
function Move.cancel()
    if Move.tw then pcall(function() Move.tw:Cancel() end) end
    Move.tw = nil
    Move.tweening = false
end

-- Tween até pos. abortFn() opcional (true = para no meio).
function Move.tween(pos, speed, abortFn)
    local hrp = U.hrp()
    if not hrp or not U.alive() then return false end
    speed = speed or Cfg.TweenSpeed
    local dist = (hrp.Position - pos).Magnitude
    if dist < 0.5 then return true end
    if dist > 40 then
        local fa, fb = F.of(hrp.Position), F.of(pos)
        Con.log("Info", string.format("Tween %s -> %s (%d studs)", fa and U.fname(fa) or "fora de field", fb and U.fname(fb) or "fora de field", math.floor(dist)))
    end
    local rot = hrp.CFrame - hrp.CFrame.Position
    local tw = TweenService:Create(hrp, TweenInfo.new(math.max(dist / speed, 0.05), Enum.EasingStyle.Linear),
        { CFrame = CFrame.new(pos) * rot })
    Move.cancel()
    Move.tw, Move.tweening = tw, true
    local done = false
    local c = tw.Completed:Connect(function(st)
        if st == Enum.PlaybackState.Completed then done = true end
        Move.tweening = false
    end)
    tw:Play()
    while Move.tweening and running() and U.alive() and hrp.Parent do
        hrp.AssemblyLinearVelocity = Vector3.zero
        if abortFn and abortFn() then break end
        task.wait()
    end
    c:Disconnect()
    if Move.tweening then Move.cancel() end
    Move.tweening = false
    return done
end

function Move.tp(pos)
    local h = U.hrp()
    if not h then return end
    Move.cancel()
    h.AssemblyLinearVelocity = Vector3.zero
    h.CFrame = CFrame.new(pos) * (h.CFrame - h.CFrame.Position)
end

-- Anda (Humanoid:MoveTo). opt: reach, stop(), timeout, onTick(pos), noCheck, pass/passR (ponto de passagem)
-- true = chegou | false = parou antes (stop/interrupção/timeout)
function Move.walk(pos, opt)
    opt = opt or {}
    local hum, hrp = U.hum(), U.hrp()
    if not (hum and hrp) then return false end
    local reach = opt.reach or 2.5
    local dist = U.fdist(pos, hrp.Position)
    local timeout = opt.timeout or (dist / math.max(hum.WalkSpeed, 8) + 1.5)
    local t0, lastRe, lastChk = tick(), tick(), 0
    hum:MoveTo(pos)
    while running() and U.alive() and tick() - t0 < timeout do
        local hp = hrp.Position
        if U.fdist(pos, hp) < reach then return true end
        if opt.pass and U.fdist(opt.pass, hp) < (opt.passR or 2.5) then return true end   -- passou por cima: segue sem parar
        if tick() - lastChk > 0.12 then
            lastChk = tick()
            if opt.stop and opt.stop() then return false end
            if not opt.noCheck and Sched.check() then return false end
            if opt.onTick then opt.onTick(hp) end
        end
        if tick() - lastRe > 2 then hum:MoveTo(pos) lastRe = tick() end
        task.wait(0.03)
    end
    return false
end

-- Vai até um ponto: anda se estiver no mesmo campo e perto, senão tween.
function Move.go(pos, opt)
    local hrp = U.hrp()
    if not hrp then return false end
    local a = F.of(hrp.Position)
    if a and a == F.of(pos) and U.fdist(pos, hrp.Position) < 90 then
        return Move.walk(pos, opt)
    end
    return Move.tween(pos, nil, function() return Sched.check() end)
end

-- Noclip só durante o tween (e restaura a colisão depois)
do
    local changed = {}
    conn(RunService.Stepped:Connect(function()
        if Move.tweening and Cfg.Noclip then
            local c = U.char()
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false changed[p] = true end
                end
            end
        elseif next(changed) then
            for p in pairs(changed) do if p.Parent then p.CanCollide = true end end
            table.clear(changed)
        end
    end))
end
conn(LP.CharacterAdded:Connect(function() Move.cancel() end))

-- Chão perto de um ponto (raycast curto: nunca acha chão lá embaixo do mapa)
function Move.ground(pos, up, down)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { U.char(), TokensF, BeesF, NPCF, MobsF }
    params.RespectCanCollide = true
    local hit = workspace:Raycast(pos + Vector3.new(0, up or 8, 0), Vector3.new(0, -(down or 25), 0), params)
    if hit then return Vector3.new(pos.X, hit.Position.Y + 3, pos.Z) end
    return pos
end

------------------------------------------------------------------
-- FERRAMENTA (Auto Tool: bate o tempo todo)
------------------------------------------------------------------
local Tool = {}
function Tool.get()
    local char = U.char()
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") and t:FindFirstChild("ToolUseEvent") then return t end
        end
    end
    local bp, hum = LP:FindFirstChild("Backpack"), U.hum()
    if bp and hum then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and t:FindFirstChild("ToolUseEvent") then
                hum:EquipTool(t)
                task.wait(0.1)
                return t
            end
        end
    end
end
task.spawn(function()
    while running() do
        task.wait(Cfg.ToolDelay)
        -- bate SEMPRE que possível (farm, luta, andando, convertendo...)
        if Cfg.AutoTool and U.alive() then
            local t = Tool.get()
            if t then pcall(function() t.ToolUseEvent:FireServer() end) end
        end
    end
end)

------------------------------------------------------------------
-- ALEATÓRIO INTELIGENTE: grade do tamanho do alcance da ferramenta.
-- Vai sempre para um dos quadrados visitados há mais tempo, sem ir pra
-- borda (margem) e sem ficar indo e voltando (distância mínima).
------------------------------------------------------------------
local Grid = { g = {} }
function Grid.get(name, hb)
    local cs = math.max(Cfg.ToolRange, 4)
    local mx = math.max(hb.Size.X / 2 - Cfg.EdgeMargin - F.extra(hb), 1)
    local mz = math.max(hb.Size.Z / 2 - Cfg.EdgeMargin - F.extra(hb), 1)
    local g = Grid.g[name]
    if not g or g.cs ~= cs or g.mx ~= mx or g.mz ~= mz then
        g = { cs = cs, mx = mx, mz = mz,
              nx = math.max(1, math.floor(2 * mx / cs + 0.5)),
              nz = math.max(1, math.floor(2 * mz / cs + 0.5)), t = {} }
        Grid.g[name] = g
    end
    return g
end
function Grid.cell(g, lx, lz)
    local ix = math.clamp(math.floor((lx + g.mx) / (2 * g.mx) * g.nx) + 1, 1, g.nx)
    local iz = math.clamp(math.floor((lz + g.mz) / (2 * g.mz) * g.nz) + 1, 1, g.nz)
    return ix, iz
end
function Grid.cellCenter(g, ix, iz)
    return -g.mx + (ix - 0.5) * (2 * g.mx / g.nx), -g.mz + (iz - 0.5) * (2 * g.mz / g.nz)
end
-- marca como visitado o quadrado onde o personagem está
function Grid.touch(name, hb, pos)
    if not (name and hb and pos) then return end
    local g = Grid.get(name, hb)
    local lp = hb.CFrame:PointToObjectSpace(pos)
    if math.abs(lp.X) > hb.Size.X / 2 or math.abs(lp.Z) > hb.Size.Z / 2 then return end
    local ix, iz = Grid.cell(g, lp.X, lp.Z)
    g.t[(iz - 1) * g.nx + ix] = tick()
end
function Grid.next(name, hb)
    local g = Grid.get(name, hb)
    local hrp = U.hrp()
    local me = hrp and hb.CFrame:PointToObjectSpace(hrp.Position) or Vector3.zero
    local cands, now = {}, tick()
    local minD = (g.nx * g.nz <= 2) and 0 or Cfg.MinPointDist
    for ix = 1, g.nx do
        for iz = 1, g.nz do
            local cx, cz = Grid.cellCenter(g, ix, iz)
            local d = Vector3.new(cx - me.X, 0, cz - me.Z).Magnitude
            if d >= minD then
                local age = math.min(now - (g.t[(iz - 1) * g.nx + ix] or 0), 300)
                table.insert(cands, { x = cx, z = cz, s = age - d * 0.35 })
            end
        end
    end
    if #cands == 0 then
        local cx, cz = Grid.cellCenter(g, math.random(1, g.nx), math.random(1, g.nz))
        return F.toWorld(hb, cx, cz)
    end
    table.sort(cands, function(a, b) return a.s > b.s end)
    local k = math.clamp(math.floor(#cands * Cfg.FieldRandom / 100), 1, #cands)
    local p = cands[math.random(1, k)]
    local j = g.cs * 0.25
    local x = math.clamp(p.x + (math.random() * 2 - 1) * j, -g.mx, g.mx)
    local z = math.clamp(p.z + (math.random() * 2 - 1) * j, -g.mz, g.mz)
    return F.toWorld(hb, x, z)
end

------------------------------------------------------------------
-- SPROUT (workspace.Map.Sprouts + remote SproutFX)
------------------------------------------------------------------
local Sprout = { cur = nil, field = nil, lootField = nil, lootUntil = 0, lastCheck = 0, known = {}, planted = {} }
-- raridades (as que o jogo mostrar vão sendo adicionadas na lista sozinhas)
Sprout.BASE_RARITIES = { "Basic", "Rare", "Epic" }   -- confirmadas no jogo; novas entram sozinhas
function Sprout.rarity(s) return tostring(s:GetAttribute("Rarity") or "?") end
function Sprout.rarityOptions()
    local seen, out = {}, {}
    for _, r in ipairs(Sprout.BASE_RARITIES) do if not seen[r] then seen[r] = true table.insert(out, r) end end
    for r in pairs(Cfg.SproutRaritiesSeen) do if not seen[r] then seen[r] = true table.insert(out, r) end end
    return out
end
-- vale a pena ir? (plantada por nós = sempre; senão, raridade marcada ou lista vazia)
function Sprout.wanted(s)
    if Sprout.planted[s] then return true end                 -- plantadas por nós: sempre
    if Cfg.SproutRarePlus and Sprout.rarity(s) == "Basic" then return false end
    return true
end

-- LOG de sprouts (Debug → Copiar log de sprouts)
Sprout.log = {}
function Sprout.addLog(line)
    table.insert(Sprout.log, os.date("[%H:%M:%S] ") .. line)
    if #Sprout.log > 300 then table.remove(Sprout.log, 1) end
end
do
    local map = workspace:FindFirstChild("Map")
    local folder = map and map:FindFirstChild("Sprouts")
    local function onSprout(s)
        task.wait(0.3)
        if not s.Parent then return end
        local at = {}
        for k, v in pairs(s:GetAttributes()) do
            if k ~= "LastTouched" then table.insert(at, k .. "=" .. tostring(v)) end
        end
        table.sort(at)
        Sprout.addLog("SPROUT " .. table.concat(at, " "))
    end
    if folder then conn(folder.ChildAdded:Connect(onSprout)) end
    local nt = remote("NotificationSent")
    if nt then
        conn(nt.OnClientEvent:Connect(function(_, text)
            -- "+X item (From Sprout)" = pegou loot da sprout: o loot ainda está rolando
            if type(text) == "string" and text:lower():find("from sprout", 1, true) then Sprout.lastLootTok = tick() end
            if type(text) == "string" and text:lower():find("sprout", 1, true) and not text:find("From Sprout", 1, true) then
                Sprout.addLog("NOTIF " .. text)
            end
        end))
    end
end
do
    local fx = remote("SproutFX")
    if fx then
        conn(fx.OnClientEvent:Connect(function(s)
            if typeof(s) == "Instance" then Sprout.known[s] = true end
        end))
    end
end
function Sprout.list()
    local list, seen = {}, {}
    local map = workspace:FindFirstChild("Map")
    local folder = map and map:FindFirstChild("Sprouts")
    if folder then
        for _, s in ipairs(folder:GetChildren()) do seen[s] = true table.insert(list, s) end
    end
    for s in pairs(Sprout.known) do
        if not s.Parent then Sprout.known[s] = nil
        elseif not seen[s] then table.insert(list, s) end
    end
    return list
end
function Sprout.alive(s)
    local hp = s:GetAttribute("HP")
    return s.Parent ~= nil and (hp == nil or hp > 0)
end
function Sprout.fieldOf(s)
    local a = s:GetAttribute("Field")
    if type(a) == "string" then
        if Fields:FindFirstChild(a) then return a end
        local f = F.find and F.find((a:gsub("Field$", "")))   -- "Pine TreeField" -> PineTreeForest
        if f then return f end
    end
    local p = U.pos(s)
    return p and F.of(p)
end
-- Loot acaba sozinho: 3s sem pegar loot novo ("... (From Sprout)" na notificação) (cada sprout tem um tempo de loot diferente).
-- "Tempo máximo de loot" (slider) é só o limite de segurança.
Sprout.LOOT_IDLE = 3
function Sprout.looting()
    if Sprout.lootField == nil or tick() >= Sprout.lootUntil then return false end
    local start = Sprout.lootStart or 0
    if tick() - start > Sprout.LOOT_IDLE and tick() - math.max(start, Sprout.lastLootTok or 0) > Sprout.LOOT_IDLE then
        Con.log("Info", string.format("Sprout: loot acabou (%ds sem loot From Sprout, durou %.0fs)", Sprout.LOOT_IDLE, tick() - start))
        Sprout.lootUntil = 0
        return false
    end
    return true
end
function Sprout.update()
    if not Cfg.AutoSprout then Sprout.cur, Sprout.lootField = nil, nil return end
    if Sprout.lootField and tick() >= Sprout.lootUntil then Sprout.lootField = nil end
    if tick() - Sprout.lastCheck < 0.4 then return end
    Sprout.lastCheck = tick()
    -- sprout plantada por nós que quebrou (mesmo no meio do loot de outra): loot dela também
    for s, pf in pairs(Sprout.planted) do
        if not Sprout.alive(s) then
            Sprout.planted[s] = nil
            if s ~= Sprout.cur then
                Sprout.lootField, Sprout.lootUntil, Sprout.lootStart = pf, tick() + Cfg.SproutLootTime, tick()
            end
        end
    end
    local cur = Sprout.cur
    if cur and not Sprout.alive(cur) then
        -- a sprout que estávamos quebrando acabou: loot no campo dela (mesmo se nascer outra)
        Sprout.lootField, Sprout.lootUntil = Sprout.field, tick() + Cfg.SproutLootTime
        Sprout.lootStart = tick()
        Sprout.cur = nil
        return
    end
    if not cur and not Sprout.looting() then
        Sprout.field = nil
        -- plantadas por nós primeiro, depois as outras com raridade marcada
        local pick, pickF
        for _, s in ipairs(Sprout.list()) do
            local r = s:GetAttribute("Rarity")
            if r and not Cfg.SproutRaritiesSeen[tostring(r)] then Cfg.SproutRaritiesSeen[tostring(r)] = true end
            local f = Sprout.alive(s) and Sprout.fieldOf(s)
            if f and F.unlocked(f) and Sprout.wanted(s) then
                if Sprout.planted[s] then pick, pickF = s, f break end
                if not pick then pick, pickF = s, f end
            end
        end
        if pick then Sprout.cur, Sprout.field = pick, pickF end
    end
end
-- campo onde o farm deve acontecer por causa da sprout (loot primeiro)
function Sprout.farmField()
    Sprout.update()
    if Sprout.looting() then return Sprout.lootField end
    if Sprout.cur then return Sprout.field end
    return nil
end
function Sprout.statusText()
    local parts = {}
    for _, s in ipairs(Sprout.list()) do
        local f = Sprout.alive(s) and Sprout.fieldOf(s)
        if f then
            local info = U.fname(f)
            local r = s:GetAttribute("Rarity")
            if r then info ..= " (" .. tostring(r) .. ")" end
            local hp, mx = s:GetAttribute("HP"), s:GetAttribute("MaxHP")
            if type(hp) == "number" and type(mx) == "number" and mx > 0 then
                info ..= string.format(" %d%%", math.floor(hp / mx * 100))
            end
            if not F.unlocked(f) then info ..= " [bloqueado]" end
            table.insert(parts, info)
        end
    end
    local s = #parts > 0 and table.concat(parts, ", ") or "nenhuma"
    if Sprout.looting() then
        return string.format("Loot em %s (%ds) | sprouts: %s", U.fname(Sprout.lootField), math.ceil(Sprout.lootUntil - tick()), s)
    end
    return "Sprouts: " .. s
end

------------------------------------------------------------------
-- MARKS (workspace.FX.Marks.Mark)
--  * atributos: Radius, Type (PollenMark / PollenMarkPlus / HoneyMark...), OwnerID, Deleting
--    (Active só pisca liga/desliga: NÃO serve pra saber se a mark vale)
--  * tamanho real: Outline (Size.X = diâmetro, já com os buffs de raio)
--  * duração: MarkClient.LT (segundos) contada de quando a mark nasceu
--  * NETWORK: marks ligadas pelo tracejado = Beams "MarkConnection" em Bulb.Connection
------------------------------------------------------------------
local Mark = { list = {}, born = {}, order = { "HoneyMark+", "PollenMark+", "PollenMark" }, cache = nil, cacheHb = nil, cacheT = 0, folder = nil }
do
    local function bind(folder)
        Mark.folder = folder
        for _, m in ipairs(folder:GetChildren()) do Mark.list[m] = true Mark.born[m] = Mark.born[m] or tick() end
        conn(folder.ChildAdded:Connect(function(m) Mark.list[m] = true Mark.born[m] = tick() Mark.cacheT = 0 end))
        conn(folder.ChildRemoved:Connect(function(m) Mark.list[m], Mark.born[m] = nil, nil Mark.cacheT = 0 end))
    end
    if FXF then
        local mf = FXF:FindFirstChild("Marks")
        if mf then bind(mf) else
            conn(FXF.ChildAdded:Connect(function(c) if c.Name == "Marks" then bind(c) end end))
        end
    end
end
function Mark.kind(m)
    local t = tostring(m:GetAttribute("Type") or m.Name):lower()
    if t:find("honey", 1, true) then return "HoneyMark+" end
    if t:find("plus", 1, true) or t:find("+", 1, true) then return "PollenMark+" end
    return "PollenMark"
end
function Mark.pos(m)
    local c = m:FindFirstChild("Outline") or m:FindFirstChild("Cylinder")
    if c and c:IsA("BasePart") then return c.Position end
    return U.pos(m)
end
function Mark.radius(m)
    local o = m:FindFirstChild("Outline")
    if o and o:IsA("BasePart") and o.Size.X > 1 then return o.Size.X / 2 end
    return tonumber(m:GetAttribute("Radius")) or 12
end
-- segundos que faltam pra mark sumir (nil = não sei)
function Mark.left(m)
    local mc = m:FindFirstChild("MarkClient")
    local lt = mc and tonumber(mc:GetAttribute("LT"))
    if not lt then return nil end
    return lt - (tick() - (Mark.born[m] or tick()))
end
function Mark.mine(m)
    local id = tonumber(m:GetAttribute("OwnerID"))
    if not id then return nil end
    return id == LP.UserId
end
function Mark.valid(m)
    if m.Parent == nil or m:GetAttribute("Deleting") == true then return false end
    local l = Mark.left(m)
    return not l or l > 0.6
end
function Mark.inField(hb)
    if Mark.cacheHb == hb and tick() - Mark.cacheT < 0.3 then return Mark.cache end
    local t = {}
    for m in pairs(Mark.list) do
        if not m.Parent then Mark.list[m] = nil
        elseif Mark.valid(m) then
            local mine = Mark.mine(m)
            local p = Mark.pos(m)
            if p and F.inside(hb, p) and mine ~= false then   -- só as suas marks
                table.insert(t, { inst = m, pos = p, r = Mark.radius(m), kind = Mark.kind(m), mine = mine, left = Mark.left(m) })
            end
        end
    end
    Mark.cache, Mark.cacheHb, Mark.cacheT = t, hb, tick()
    return t
end
-- mark (Model dentro da pasta Marks) dona de um objeto
local function markOf(inst)
    local cur = inst
    while cur and cur.Parent ~= Mark.folder do cur = cur.Parent end
    return cur
end
-- networks: grupos de marks ligadas pelo tracejado (Beam MarkConnection). Mark solta = network de 1.
function Mark.networks(hb)
    local marks = Mark.inField(hb)
    local idx, parent = {}, {}
    for i, e in ipairs(marks) do idx[e.inst] = i parent[i] = i end
    local function find(i) while parent[i] ~= i do parent[i] = parent[parent[i]] i = parent[i] end return i end
    for i, e in ipairs(marks) do
        for _, d in ipairs(e.inst:GetDescendants()) do
            if d:IsA("Beam") then
                local a = d.Attachment0 and idx[markOf(d.Attachment0)]
                local b = d.Attachment1 and idx[markOf(d.Attachment1)]
                if a and b then parent[find(a)] = find(b) end
            end
        end
    end
    local groups = {}
    for i, e in ipairs(marks) do
        local r = find(i)
        groups[r] = groups[r] or { marks = {}, pref = 0, left = 0 }
        local g = groups[r]
        table.insert(g.marks, e)
        if e.kind == Cfg.MarkPrefer then g.pref += 1 end
        g.left += (e.left or 5)
    end
    local out = {}
    for _, g in pairs(groups) do
        g.count = #g.marks
        g.left = g.left / g.count
        table.insert(out, g)
    end
    -- mais marks primeiro; empate: mais marks do tipo preferido; depois a que dura mais
    table.sort(out, function(x, y)
        if x.count ~= y.count then return x.count > y.count end
        if x.pref ~= y.pref then return x.pref > y.pref end
        return x.left > y.left
    end)
    return out
end
function Mark.bestNet(hb)
    local nets = Mark.networks(hb)
    local best = nets[1]
    -- network quase acabando (< 1.5s) perde pra próxima se tiver
    if best and best.left < 1.5 and nets[2] then best = nets[2] end
    return best
end
-- ponto aleatório dentro da maior network (marks maiores têm mais chance)
function Mark.walkPoint(hb)
    local net = Mark.bestNet(hb)
    if not net then return nil end
    local total = 0
    for _, m in ipairs(net.marks) do total += m.r * m.r end
    local pick, acc, roll = net.marks[1], 0, math.random() * total
    for _, m in ipairs(net.marks) do
        acc += m.r * m.r
        if roll <= acc then pick = m break end
    end
    -- ponto dentro da mark E dentro da field (mark no canto: parte dela fica pra fora)
    for _ = 1, 12 do
        local a = math.random() * math.pi * 2
        local rr = pick.r * 0.7 * math.sqrt(math.random())
        local p = pick.pos + Vector3.new(math.cos(a) * rr, 0, math.sin(a) * rr)
        p = Vector3.new(p.X, F.groundY(hb), p.Z)
        if F.safe(hb, p, -3) then return p end
    end
    -- não achou: puxa o centro da mark pra dentro da field
    local lp = hb.CFrame:PointToObjectSpace(pick.pos)
    local hx, hz = hb.Size.X / 2 - 3 - F.extra(hb), hb.Size.Z / 2 - 3 - F.extra(hb)
    local w = hb.CFrame:PointToWorldSpace(Vector3.new(math.clamp(lp.X, -hx, hx), 0, math.clamp(lp.Z, -hz, hz)))
    return Vector3.new(w.X, F.groundY(hb), w.Z)
end
-- TENTA passar por dentro de uma mark da network no caminho a -> b.
-- Se o desvio ficar muito mais longo (> 35%), vai direto: sai da network sem hesitar.
function Mark.via(hb, a, b)
    local net = Mark.bestNet(hb)
    local marks = net and net.marks or {}
    if #marks == 0 then return nil end
    local A, B = U.flat(a), U.flat(b)
    local AB = B - A
    local direct = AB.Magnitude
    if direct < 4 then return nil end
    local best, bestLen = nil, direct * 1.35
    for _, m in ipairs(marks) do
        local C = U.flat(m.pos)
        local t = math.clamp((C - A):Dot(AB) / (direct * direct), 0, 1)
        local off = (A + AB * t) - C
        if off.Magnitude <= m.r * 0.85 then return nil end   -- o caminho reto já passa dentro
        if off.Magnitude > 0.01 then
            local W = C + off.Unit * (m.r * 0.6)
            local len = (W - A).Magnitude + (B - W).Magnitude
            if len < bestLen then best, bestLen = W, len end
        end
    end
    if not best then return nil end
    local w = Vector3.new(best.X, b.Y, best.Z)
    if not F.safe(hb, w, -3) then return nil end   -- desvio cairia fora da field: vai direto
    return w
end
function Mark.statusText(hb)
    if not hb then return "Marks: -" end
    local nets = Mark.networks(hb)
    if #nets == 0 then return "Marks no campo: nenhuma" end
    local best = Mark.bestNet(hb)
    local cnt, parts = {}, {}
    for _, m in ipairs(best.marks) do cnt[m.kind] = (cnt[m.kind] or 0) + 1 end
    for k, v in pairs(cnt) do table.insert(parts, v .. "x " .. k) end
    table.sort(parts)
    local total = 0
    for _, n in ipairs(nets) do total += n.count end
    return string.format("Network: %d mark(s) [%s] ~%.0fs | %d network(s), %d marks no campo",
        best.count, table.concat(parts, ", "), best.left, #nets, total)
end

------------------------------------------------------------------
-- TOKENS (workspace.Tokens: atributos Owner e Collected)
------------------------------------------------------------------
local Tok = { list = {}, born = {}, expire = {}, touched = {}, tries = {}, black = {}, seen = {}, cache = {} }
local function tokAdd(t)
    Tok.list[t] = true
    Tok.born[t] = tick()
    Tok.seen[t.Name] = true
end
for _, t in ipairs(TokensF:GetChildren()) do tokAdd(t) end
conn(TokensF.ChildAdded:Connect(tokAdd))
conn(TokensF.ChildRemoved:Connect(function(t)
    Tok.list[t], Tok.born[t], Tok.expire[t], Tok.touched[t], Tok.tries[t], Tok.black[t] = nil, nil, nil, nil, nil, nil
end))
do
    local r = remote("Token")
    if r then
        conn(r.OnClientEvent:Connect(function(tok, life)
            if typeof(tok) == "Instance" and type(life) == "number" then Tok.expire[tok] = tick() + life end
        end))
    end
end
function Tok.ownerOk(t)
    if not Cfg.OnlyMyTokens then return true end
    local o = tonumber(t:GetAttribute("Owner"))
    return o == nil or o <= 0 or o == LP.UserId
end
function Tok.isAbility(t) return U.match(Cfg.AbilityTokens, t.Name) ~= nil end
function Tok.nameBlocked(t)
    local n = t.Name:lower()
    if Cfg.IgnoreBomb and n:find("bomb", 1, true) then return true end
    if Cfg.IgnoreBoost and n:find("boost", 1, true) then return true end
    return U.match(Cfg.TokenBlacklist, t.Name) ~= nil
end
function Tok.usable(t)
    if not t.Parent then return false end
    if t:GetAttribute("Collected") == true then return false end
    local now = tick()
    if (Tok.black[t] or 0) > now or (Tok.touched[t] or 0) > now then return false end
    if not Tok.ownerOk(t) or Tok.nameBlocked(t) then return false end
    if Sprout.looting() and Tok.isAbility(t) then return false end
    return true
end
-- por que o token está sendo ignorado? (diagnóstico)
function Tok.why(t)
    if not t.Parent then return "sumiu" end
    if t:GetAttribute("Collected") == true then return "Collected" end
    local now = tick()
    if (Tok.black[t] or 0) > now then return "lista negra" end
    if (Tok.touched[t] or 0) > now then return "acabou de encostar" end
    if not Tok.ownerOk(t) then return "de outro player (Owner=" .. tostring(t:GetAttribute("Owner")) .. ")" end
    if Tok.nameBlocked(t) then return "nome bloqueado (Ignorar Bomb/Boost ou lista)" end
    if Sprout.looting() and Tok.isAbility(t) then return "habilidade no loot da sprout" end
    local exp = Tok.expire[t]
    if exp and exp - now < 0.3 then return "vai sumir" end
    return "ok"
end
-- menor = mais importante
function Tok.prio(t)
    local i = U.match(UNIQUE_ITEMS, t.Name)
    if i then return -100 + i end
    local n = U.key(t.Name)
    -- honey token é o de menor valor; treat logo acima dele
    if n:find("honey", 1, true) then return 1000 end
    if n:find("treat", 1, true) then return 900 end
    local j = U.match(Cfg.TokenPriority, t.Name)
    if j then return j end
    return 500
end
function Tok.blacklist(t, why)
    Tok.black[t] = tick() + 60
    St.lastBlack = t.Name .. " (" .. why .. ")"
end
-- lista de tokens usáveis dentro do campo (ordenada por prioridade e distância)
function Tok.inField(hb, filter)
    local hrp = U.hrp()
    if not hrp or not hb then return {} end
    local out = {}
    for t in pairs(Tok.list) do
        if Tok.usable(t) then
            local p = U.pos(t)
            if p and F.safe(hb, p) and (not filter or filter(t, p)) then
                local d = (p - hrp.Position).Magnitude
                local exp = Tok.expire[t]
                if not exp or exp - tick() > d / math.max(Cfg.WalkSpeed, 16) * 0.8 then
                    table.insert(out, { inst = t, pos = p, dist = d, prio = Tok.prio(t) })
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.prio ~= b.prio then return a.prio < b.prio end
        return a.dist < b.dist
    end)
    return out
end
function Tok.best(hb)
    local c = Tok.cache
    if c.hb == hb and tick() - (c.t or 0) < 0.15 then return c.v end
    local l = Tok.inField(hb)
    c.hb, c.t, c.v = hb, tick(), l[1]
    return c.v
end
function Tok.touch(t)
    local hrp = U.hrp()
    if hrp and firetouchinterest and t:IsA("BasePart") then
        pcall(firetouchinterest, hrp, t, 0)
        pcall(firetouchinterest, hrp, t, 1)
    end
end
-- PASSA POR CIMA: não para no token, encosta e já segue. Se não sumir, na 2ª vez vai pra lista negra.
function Tok.collect(e, hb, useMarks)
    local t = e.inst
    Tok.cache.t = 0
    act("Token: " .. t.Name)
    local gone = function() return not t.Parent or t:GetAttribute("Collected") == true end
    if useMarks and Cfg.StayInMarks and hb then
        local w = Mark.via(hb, U.hrp().Position, e.pos)
        if w then Move.walk(w, { reach = 3, stop = gone }) end
    end
    -- não para em cima do token: mira um pouco além dele e segue direto pro próximo
    local hrp0 = U.hrp()
    local aim = e.pos
    if hrp0 then
        local d = Vector3.new(e.pos.X - hrp0.Position.X, 0, e.pos.Z - hrp0.Position.Z)
        if d.Magnitude > 0.5 then
            local over = e.pos + d.Unit * 6
            if not hb or F.inside(hb, over) then aim = over end
        end
    end
    local ok = Move.walk(aim, { reach = 1.8, stop = gone, pass = e.pos, passR = 2.5 })
    if gone() then return true end
    local hrp = U.hrp()
    if not ok and hrp and U.fdist(e.pos, hrp.Position) > 4 then
        if Sched.abort then return false end
        Tok.tries[t] = (Tok.tries[t] or 0) + 1
        if Tok.tries[t] >= 2 then Tok.blacklist(t, "inalcançável") else Tok.touched[t] = tick() + 1 end
        return false
    end
    Tok.touch(t)
    Tok.tries[t] = (Tok.tries[t] or 0) + 1
    if Tok.tries[t] >= 2 then Tok.blacklist(t, "não sumiu") else Tok.touched[t] = tick() + 3 end
    return true
end

------------------------------------------------------------------
-- TWEEN/TP TO RARE
------------------------------------------------------------------
local Rare = { t = 0, v = nil }
-- dono do script (kirito_Asu): pra ele funciona sempre; pros outros, só quando ele não está no server
Rare.OWNER = 353882995
function Rare.allowed()
    if LP.UserId == Rare.OWNER then return true end
    return Players:GetPlayerByUserId(Rare.OWNER) == nil
end
-- field onde os tokens já estão sendo pegos à distância (não precisa ir buscar o raro lá)
function Rare.remoteField()
    local hrp = U.hrp()
    if not hrp then return nil end
    local here = F.of(hrp.Position)
    if not here then return nil end
    if Cfg.AutoTokens and firetouchinterest then return here end   -- coleta de tokens é remota
    if Cfg.SproutAllTokens and firetouchinterest then
        local sf = (Sprout.looting() and Sprout.lootField) or (Sprout.cur and Sprout.field) or nil
        if sf == here then return here end
    end
    return nil
end
function Rare.find()
    if not Cfg.TweenToRare or not Rare.allowed() then return nil end
    if tick() - Rare.t < 0.25 then return Rare.v end
    Rare.t, Rare.v = tick(), nil
    local hrp = U.hrp()
    if not hrp or #Cfg.RareTokens == 0 then return nil end
    local best, bd
    local skipF = Rare.remoteField()
    for t in pairs(Tok.list) do
        if U.match(Cfg.RareTokens, t.Name) and Tok.usable(t) then
            local p = U.pos(t)
            local f = p and F.of(p)
            local skipHb = skipF and F.hb(skipF)
            if f and F.unlocked(f) and f ~= skipF and not (skipHb and F.inside(skipHb, p, 15)) then
                local d = (p - hrp.Position).Magnitude
                if not bd or d < bd then best, bd = { inst = t, pos = p }, d end
            end
        end
    end
    Rare.v = best
    return best
end
function Rare.grab(r)
    act((Cfg.RareTeleport and "TP to Rare: " or "Tween to Rare: ") .. r.inst.Name)
    if Cfg.RareTeleport then Move.tp(r.pos) else Move.tween(r.pos, Cfg.RareTweenSpeed) end
    Tok.touch(r.inst)
    local t0 = tick()
    while tick() - t0 < Cfg.RareHold and r.inst.Parent and running() do
        local p, h = U.pos(r.inst), U.hrp()
        if p and h then
            h.AssemblyLinearVelocity = Vector3.zero
            h.CFrame = CFrame.new(p) * (h.CFrame - h.CFrame.Position)
        end
        task.wait()
    end
    Tok.touched[r.inst] = tick() + 4
    Rare.t = 0
end

------------------------------------------------------------------
-- BOLHAS (workspace.FX.Bubble). Dono = OwnerID da abelha que soltou.
-- Fontes de bolha: tabela fácil de crescer. method:
--   beeAtSpawn  bolha nasce em cima da abelha (PopBee)
--   nearBee     bolha nasce perto da abelha (raio maior)
--   nearOwner   bolha nasce em volta do player dono da abelha
--   attribute   a própria bolha traz o dono num atributo
------------------------------------------------------------------
local BubbleSources = {
    PopBee = { bee = "PopBee", method = "beeAtSpawn", radius = 1 },
}
local Abyss   -- (preenchido mais abaixo, seção ABYSS)
local Bub = { list = {}, owner = {}, touched = {}, bees = {}, cache = {} }
local function beePos(b)
    local p = b:FindFirstChild("Bee")
    if p and p:IsA("BasePart") then return p.Position end
    return U.pos(b)
end
local function isSourceBee(name)
    for _, s in pairs(BubbleSources) do if s.bee == name then return true end end
    return false
end
if BeesF then
    for _, b in ipairs(BeesF:GetChildren()) do if isSourceBee(b.Name) then Bub.bees[b] = true end end
    conn(BeesF.ChildAdded:Connect(function(b) if isSourceBee(b.Name) then Bub.bees[b] = true end end))
    conn(BeesF.ChildRemoved:Connect(function(b) Bub.bees[b] = nil end))
end
local function nearestBee(pos, beeName, radius, all)
    local best, bd = nil, radius
    local pool = Bub.bees
    if all and BeesF then pool = {} for _, b in ipairs(BeesF:GetChildren()) do pool[b] = true end end
    for b in pairs(pool) do
        if b.Parent and (not beeName or b.Name == beeName) then
            local p = beePos(b)
            if p then
                local d = (p - pos).Magnitude
                if d <= bd then best, bd = b, d end
            end
        end
    end
    return best
end
local OwnerMethods = {
    beeAtSpawn = function(bub, src)
        local b = nearestBee(bub.Position, src.bee, src.radius)
        return b and tonumber(b:GetAttribute("OwnerID"))
    end,
    nearBee = function(bub, src)
        local b = nearestBee(bub.Position, src.bee, src.radius or 6)
        return b and tonumber(b:GetAttribute("OwnerID"))
    end,
    nearOwner = function(bub, src)
        local best, bd = nil, src.radius or 20
        for _, pl in ipairs(Players:GetPlayers()) do
            local r = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
            if r then
                local d = U.fdist(r.Position, bub.Position)
                if d <= bd then best, bd = pl, d end
            end
        end
        return best and best.UserId
    end,
    attribute = function(bub, src) return tonumber(bub:GetAttribute(src.attr or "OwnerID")) end,
}
function Bub.resolve(b)
    for _, src in pairs(BubbleSources) do
        local f = OwnerMethods[src.method]
        local id = f and f(b, src)
        if id then return id end
    end
    -- tolerância: abelha da lista um pouco mais longe, depois qualquer abelha colada
    local nb = nearestBee(b.Position, nil, 4) or nearestBee(b.Position, nil, 2, true)
    return nb and tonumber(nb:GetAttribute("OwnerID"))
end
local function bubAdd(c)
    if c.Name ~= "Bubble" or not c:IsA("BasePart") then return end
    Bub.list[c] = true
    task.defer(function()
        if not c.Parent then return end
        Bub.owner[c] = Bub.resolve(c)
        if Bub.owner[c] == nil then
            task.wait(0.1)
            if c.Parent then Bub.owner[c] = Bub.resolve(c) end
        end
    end)
end
if FXF then
    for _, c in ipairs(FXF:GetChildren()) do bubAdd(c) end
    conn(FXF.ChildAdded:Connect(bubAdd))
    conn(FXF.ChildRemoved:Connect(function(c) Bub.list[c], Bub.owner[c], Bub.touched[c] = nil, nil, nil end))
end
function Bub.alive(b) return b.Parent ~= nil and b:GetAttribute("Pop") ~= true end
function Bub.mine(b)
    if not Cfg.OnlyMyBubbles then return true end
    if Bub.owner[b] == LP.UserId then return true end
    -- bolha Gold do seu Abyss vem com Owner=-1
    return tostring(b:GetAttribute("Type") or "") == "Gold" and Abyss and Abyss.nearMine(b.Position)
end
function Bub.inField(hb)
    local hrp = U.hrp()
    if not hrp or not hb then return {} end
    local out = {}
    for b in pairs(Bub.list) do
        if Bub.alive(b) and (Bub.touched[b] or 0) < tick() and Bub.mine(b) and F.safe(hb, b.Position) then
            local special = tostring(b:GetAttribute("Type") or "Basic") ~= "Basic"
            table.insert(out, { inst = b, pos = b.Position, dist = (b.Position - hrp.Position).Magnitude, special = special })
        end
    end
    table.sort(out, function(a, b)
        if a.special ~= b.special then return a.special end
        return a.dist < b.dist
    end)
    return out
end
function Bub.best(hb)
    local c = Bub.cache
    if c.hb == hb and tick() - (c.t or 0) < 0.15 then return c.v end
    local l = Bub.inField(hb)
    c.hb, c.t, c.v = hb, tick(), l[1]
    return c.v
end
function Bub.pop(e)
    local b = e.inst
    Bub.cache.t = 0
    act("Estourando bolha" .. (e.special and (" (" .. tostring(b:GetAttribute("Type")) .. ")") or ""))
    -- igual aos tokens: passa por cima sem parar e já segue
    local hrp0 = U.hrp()
    local aim = e.pos
    local r = math.max(2.5, math.min(b.Size.X, b.Size.Z) / 2)
    if hrp0 then
        local d = Vector3.new(e.pos.X - hrp0.Position.X, 0, e.pos.Z - hrp0.Position.Z)
        if d.Magnitude > 0.5 then
            local over = e.pos + d.Unit * 6
            if F.inside(e.hb or select(2, F.of(e.pos)), over) then aim = over end
        end
    end
    Move.walk(aim, { reach = 2, stop = function() return not Bub.alive(b) end, pass = e.pos, passR = r })
    local hrp = U.hrp()
    if hrp and firetouchinterest and Bub.alive(b) and U.fdist(e.pos, hrp.Position) < r + 1 then
        pcall(firetouchinterest, hrp, b, 0)
        pcall(firetouchinterest, hrp, b, 1)
    end
    Bub.touched[b] = tick() + 3
end
------------------------------------------------------------------
-- FLAMES (workspace.FX.Flame): Part 5x8x5, atributos Type ("Dark" = Dark Flame) e Owner (UserId).
-- Duram ~4s. Ficar em cima dá Flame Heat (buff em PlayerGui.Main.Buffs, stack x1..). Dark enche mais rápido.
------------------------------------------------------------------
local Flame = { list = {}, born = {}, cache = {}, LIFE = 4 }
local function flameAdd(c)
    if c.Name ~= "Flame" or not c:IsA("BasePart") then return end
    Flame.list[c] = true
    Flame.born[c] = tick()
end
if FXF then
    for _, c in ipairs(FXF:GetChildren()) do flameAdd(c) end
    conn(FXF.ChildAdded:Connect(flameAdd))
    conn(FXF.ChildRemoved:Connect(function(c) Flame.list[c], Flame.born[c] = nil, nil end))
end
function Flame.isDark(f) return tostring(f:GetAttribute("Type") or ""):lower() == "dark" end
function Flame.mine(f) return tonumber(f:GetAttribute("Owner")) == LP.UserId end
function Flame.left(f) return Flame.LIFE - (tick() - (Flame.born[f] or tick())) end
-- stack atual do Flame Heat (0 = sem o buff)
function Flame.heat()
    local pg = LP:FindFirstChild("PlayerGui")
    local main = pg and pg:FindFirstChild("Main")
    local buffs = main and main:FindFirstChild("Buffs")
    if not buffs then return 0 end
    for _, b in ipairs(buffs:GetChildren()) do
        if U.key(b.Name) == "flameheat" then
            local st = b:FindFirstChild("Stack")
            local n = st and st:IsA("TextLabel") and tonumber(st.Text:match("x(%d+)"))
            if not n then
                local hd = b:FindFirstChild("Info") and b.Info:FindFirstChild("Header")
                n = hd and hd:IsA("TextLabel") and tonumber(hd.Text:match("%(x(%d+)%)"))
            end
            return n or 1
        end
    end
    return 0
end
-- Ponto do token Plasma Lightning: as 6 Dark Flames nascem em volta de onde ele estava.
-- Guarda a última posição de cada token "Plasma Lightning" e, quando ele some (pego), vira o centro.
Flame.anchor = nil   -- { pos, t }
do
    local seen = {}   -- [token] = última posição (sai da tabela quando o token some)
    task.spawn(function()
        while running() do
            task.wait(0.05)
            for t in pairs(Tok.list) do
                if not seen[t] and U.key(t.Name):find("plasmalightning", 1, true) then seen[t] = U.pos(t) end
            end
            for t, p in pairs(seen) do
                if not t.Parent or t:GetAttribute("Collected") == true then
                    Flame.anchor = { pos = p, t = tick() }
                    seen[t] = nil
                else
                    seen[t] = U.pos(t) or p
                end
            end
        end
    end)
end
-- Só as DARK FLAMES (as 6 do Plasma Lightning): fica NO MEIO delas, pega o heat de todas ao mesmo tempo.
-- Agrupa as suas Dark Flames da field que estão perto umas das outras e devolve o centro do maior grupo.
Flame.GROUP_R = 20
function Flame.cluster(hb)
    local hrp = U.hrp()
    if not hrp or not hb then return nil end
    local darks = {}
    for f in pairs(Flame.list) do
        if f.Parent and Flame.isDark(f) and Flame.mine(f) and Flame.left(f) > 0.3 and F.inside(hb, f.Position) then
            table.insert(darks, f)
        end
    end
    if #darks == 0 then return nil end
    local best, bestN
    for _, f in ipairs(darks) do
        local grp = {}
        for _, g in ipairs(darks) do
            if U.fdist(f.Position, g.Position) <= Flame.GROUP_R then table.insert(grp, g) end
        end
        if not bestN or #grp > bestN then best, bestN = grp, #grp end
    end
    local sum, left = Vector3.zero, 0
    for _, f in ipairs(best) do
        sum += f.Position
        left = math.max(left, Flame.left(f))
    end
    local c = sum / #best
    local pos = Vector3.new(c.X, best[1].Position.Y, c.Z)
    -- tinha um Plasma Lightning ali agorinha: o centro é onde o token estava
    local an = Flame.anchor
    if an and tick() - an.t < 6 and U.fdist(an.pos, c) <= Flame.GROUP_R then
        pos = Vector3.new(an.pos.X, best[1].Position.Y, an.pos.Z)
    end
    if not F.safe(hb, pos) then pos = best[1].Position end   -- centro fora da área segura: fica na flame
    local d = U.fdist(pos, hrp.Position)
    if left <= d / math.max(Cfg.WalkSpeed, 16) + 0.4 then return nil end   -- não dá tempo de chegar
    return { pos = pos, flames = best, n = #best, dist = d, left = left }
end
function Flame.best(hb)
    local c = Flame.cache
    if c.hb == hb and tick() - (c.t or 0) < 0.15 then return c.v end
    c.hb, c.t, c.v = hb, tick(), Flame.cluster(hb)
    return c.v
end
-- vai pro meio das Dark Flames. stay = fica lá enquanto alguma existir (ou stop() mandar sair)
function Flame.go(e, stay, stop)
    Flame.cache.t = 0
    act(string.format("Dark Flames (%d) | Flame Heat x%d", e.n, Flame.heat()))
    local function alive()
        for _, f in ipairs(e.flames) do if f.Parent and Flame.left(f) > 0 then return true end end
        return false
    end
    Move.walk(e.pos, { reach = 1.5, stop = function() return not alive() or (stop and stop()) end })
    if not stay then return end
    while alive() and running() and not (stop and stop()) do task.wait(0.1) end
end

------------------------------------------------------------------
-- ABYSS (abelha mítica): pegar o token "Abyss" cria um rift em workspace.FX.Abyss
-- (Part cilindro 12x24x24, atributo OwnerID; existe uma cópia visual com OwnerID=-1).
-- Dentro dele: a cada 0,1s converte 2% da bolsa (Honey at Hive) e as bolhas perto viram Gold.
------------------------------------------------------------------
Abyss = { list = {}, born = {} }
local function abyssAdd(c)
    if c.Name ~= "Abyss" or not c:IsA("BasePart") then return end
    task.defer(function()
        if c.Parent and tonumber(c:GetAttribute("OwnerID")) == LP.UserId then
            Abyss.list[c] = true
            Abyss.born[c] = tick()
            Con.log("Info", "Abyss rift seu apareceu")
        end
    end)
end
if FXF then
    for _, c in ipairs(FXF:GetChildren()) do abyssAdd(c) end
    conn(FXF.ChildAdded:Connect(abyssAdd))
    conn(FXF.ChildRemoved:Connect(function(c)
        if Abyss.list[c] then Con.log("Info", string.format("Abyss rift durou %.1fs", tick() - (Abyss.born[c] or tick()))) end
        Abyss.list[c], Abyss.born[c] = nil, nil
    end))
end
function Abyss.radius(a) return math.max(4, math.min(a.Size.Y, a.Size.Z) / 2) end
-- rift seu dentro da field (o mais perto)
function Abyss.best(hb)
    local hrp = U.hrp()
    if not hrp or not hb then return nil end
    local best, bd
    for a in pairs(Abyss.list) do
        if a.Parent and F.inside(hb, a.Position) then
            local d = U.fdist(a.Position, hrp.Position)
            if not bd or d < bd then best, bd = a, d end
        end
    end
    return best and { inst = best, pos = best.Position, r = Abyss.radius(best), dist = bd } or nil
end
-- tem rift seu vivo (ele converte a bolsa: não precisa ir pra colmeia nem gastar converter)
function Abyss.any()
    for a in pairs(Abyss.list) do if a.Parent then return true end end
    return false
end
function Abyss.inside(e, p) return U.fdist(e.pos, p) <= e.r - 1.5 end
-- bolha Gold perto do seu rift é sua (vem com Owner=-1)
function Abyss.nearMine(p)
    for a in pairs(Abyss.list) do
        if a.Parent and U.fdist(a.Position, p) <= Abyss.radius(a) + 12 then return true end
    end
    return false
end

------------------------------------------------------------------
-- SPROUT: COLETAR TODOS OS TOKENS DA FIELD (enquanto quebra/lootea a sprout)
-- Cada token é encostado quando chega na idade escolhida (ex.: 0,25s de vida), um por vez
-- conforme vão nascendo: não pega tudo de uma vez. Leve: só olha os tokens que existem.
------------------------------------------------------------------
local SproutTok = { done = setmetatable({}, { __mode = "k" }), count = 0 }
task.spawn(function()
    while running() do
        task.wait(0.05)
        if Cfg.SproutAllTokens and firetouchinterest and U.alive() then
            local field = (Sprout.looting() and Sprout.lootField) or (Sprout.cur and Sprout.field) or nil
            local hb = field and F.hb(field)
            local hrp = U.hrp()
            if hb and hrp and F.inside(hb, hrp.Position, 20) then
                local now, delay = tick(), tonumber(Cfg.SproutTokenDelay) or 0.25
                for t in pairs(Tok.list) do
                    local born = Tok.born[t]
                    local last = SproutTok.done[t]
                    if born and now - born >= delay and (not last or now - last > 1)
                       and t:IsA("BasePart") and t.Parent and t:GetAttribute("Collected") ~= true
                       and Tok.ownerOk(t) and not Tok.nameBlocked(t) and F.inside(hb, t.Position, 12) then
                        SproutTok.done[t] = now
                        pcall(firetouchinterest, hrp, t, 0)
                        pcall(firetouchinterest, hrp, t, 1)
                        if not last then SproutTok.count += 1 end
                    end
                end
            end
        end
    end
end)

------------------------------------------------------------------
-- COLETA DE TOKENS 100% REMOTA (padrão): encosta (firetouchinterest) em todos os tokens do campo
-- onde você está, sem andar. O personagem só anda pra flames, bolhas e marks.
-- Sem firetouchinterest no executor: volta a andar até os tokens como antes.
------------------------------------------------------------------
local Remote = { touches = 0, last = "", done = setmetatable({}, { __mode = "k" }) }
function Remote.on() return Cfg.AutoTokens and firetouchinterest ~= nil end
Remote.PAD = 12   -- pega também o que cai um pouco pra fora da field (loot da sprout espalha)
task.spawn(function()
    while running() do
        task.wait(0.1)
        if Remote.on() and U.alive() then
            local hrp = U.hrp()
            local fname, hb = F.of(hrp.Position)
            -- sprout com "Collect every token" ligado: deixa ele cuidar (tem o delay por idade)
            local sf = Cfg.SproutAllTokens and ((Sprout.looting() and Sprout.lootField) or (Sprout.cur and Sprout.field)) or nil
            -- saiu um pouco da field durante o loot da sprout: continua valendo a field da sprout
            if not hb and sf and F.inside(F.hb(sf), hrp.Position, 20) then fname, hb = sf, F.hb(sf) end
            if hb then
                local now, n = tick(), 0
                for t in pairs(sf ~= fname and Tok.list or {}) do   -- na field da sprout os tokens são do loop da sprout
                    local last = Remote.done[t]
                    if (not last or now - last > 0.5) and t:IsA("BasePart") and t.Parent and t:GetAttribute("Collected") ~= true
                       and Tok.ownerOk(t) and not Tok.nameBlocked(t) and F.inside(hb, t.Position, Remote.PAD) then
                        Remote.done[t] = now
                        pcall(firetouchinterest, hrp, t, 0)
                        pcall(firetouchinterest, hrp, t, 1)
                        n += 1
                    end
                end
                -- bolhas também (as suas, incluindo as Gold do Abyss): estoura sem andar
                if Cfg.AutoBubbles then
                    for b in pairs(Bub.list) do
                        local last = Remote.done[b]
                        if (not last or now - last > 0.5) and Bub.alive(b) and Bub.mine(b) and F.inside(hb, b.Position, Remote.PAD) then
                            Remote.done[b] = now
                            pcall(firetouchinterest, hrp, b, 0)
                            pcall(firetouchinterest, hrp, b, 1)
                            n += 1
                        end
                    end
                end
                Remote.touches += n
                Remote.last = U.fname(fname)
            end
        end
    end
end)

function Bub.statusText(hb)
    local mine, other = 0, 0
    for b in pairs(Bub.list) do
        if Bub.alive(b) and (not hb or F.inside(hb, b.Position)) then
            if Bub.owner[b] == LP.UserId then mine += 1 else other += 1 end
        end
    end
    return string.format("Bolhas no campo: %d minhas, %d de outros", mine, other)
end

------------------------------------------------------------------
-- COLMEIA: claim + conversão
------------------------------------------------------------------
local Hive = { busy = false, status = "" }
function Hive.mine()
    for _, h in ipairs(Hives:GetChildren()) do
        if tonumber(h:GetAttribute("OwnerID")) == LP.UserId then return h end
    end
    return nil
end
function Hive.platform(h)
    local p = h and h:FindFirstChild("Platform")
    return p and p:FindFirstChild("Platform")
end
local function hiveFree(h)
    local id = tonumber(h:GetAttribute("OwnerID"))
    if not id or id <= 0 then return true end
    return Players:GetPlayerByUserId(id) == nil
end
function Hive.claim()
    if Hive.mine() or Hive.busy then return Hive.mine() end
    Hive.busy = true
    local ok, err = pcall(function()
        local list = {}
        for _, h in ipairs(Hives:GetChildren()) do if hiveFree(h) then table.insert(list, h) end end
        -- prefere a Hive 3 e a 4, depois a ordem normal
        local function rank(h)
            local n = tonumber(h.Name:match("%d+")) or 99
            if n == 3 then return 0 elseif n == 4 then return 1 end
            return 10 + n
        end
        table.sort(list, function(a, b) return rank(a) < rank(b) end)
        for _, h in ipairs(list) do
            if not running() or Hive.mine() then break end
            if hiveFree(h) then
                act("Pegando colmeia " .. h.Name)
                -- o claim é o ProximityPrompt "Claim Hive" (Platform.Platform.Interactions.HiveActions, alcance 12)
                -- (o remote ClaimHive é só o aviso do servidor depois)
                local pp
                for _, d in ipairs(h:GetDescendants()) do
                    if d:IsA("ProximityPrompt") and d.ActionText:lower():find("claim", 1, true) then pp = d break end
                end
                local part = pp and pp.Parent
                local plat = Hive.platform(h)
                local target = (part and part:IsA("BasePart") and part.Position) or (plat and plat.Position) or U.pos(h)
                if target then Move.tween(Move.ground(target, 10, 40)) end
                for _ = 1, 3 do
                    if Hive.mine() or not hiveFree(h) or not pp then break end
                    if fireproximityprompt then
                        pcall(fireproximityprompt, pp, 1, true)
                        local t0 = tick()
                        while tick() - t0 < 0.6 and not Hive.mine() do task.wait(0.05) end
                    end
                    -- sem fireproximityprompt (ou não pegou): aperta o prompt como o jogador
                    if not Hive.mine() and pp.ActionText:lower():find("claim", 1, true) then
                        pcall(function() pp:InputHoldBegin() task.wait(pp.HoldDuration + 0.05) pp:InputHoldEnd() end)
                    end
                    local t = tick()
                    while tick() - t < 1.5 and not Hive.mine() do task.wait(0.1) end
                end
            end
        end
        if Hive.mine() then
            Hive.status = ""
        else
            local info = {}
            for _, h in ipairs(Hives:GetChildren()) do table.insert(info, h.Name .. "=" .. tostring(h:GetAttribute("OwnerID"))) end
            Hive.status = (#list == 0 and "nenhuma livre: " or "falhou: ") .. table.concat(info, " ")
            print("[BSU] ClaimHive:", Hive.status, "| meu UserId:", LP.UserId)
        end
    end)
    Hive.busy = false
    if not ok then warn("[BSU] claim:", err) end
    return Hive.mine()
end

-- ponto na borda do círculo, do lado da colmeia
function Hive.convertPos(h, plat)
    local center = plat.Position
    local ref = h:FindFirstChild("Back") or h:FindFirstChild("Display") or h:FindFirstChild("LightHolder")
    local refPos = ref and ref.Position or h:GetPivot().Position
    local dir = Vector3.new(refPos.X - center.X, 0, refPos.Z - center.Z)
    if dir.Magnitude < 0.1 then return center + Vector3.new(0, 3, 0) end
    dir = dir.Unit
    local circle = h.Platform:FindFirstChild("Circle")
    local sz = (circle or plat).Size
    local dims = { sz.X, sz.Y, sz.Z }
    table.sort(dims)
    local radius = dims[2] / 2
    return center + dir * math.max(radius - Cfg.HiveEdgeMargin, 0) + Vector3.new(0, 3, 0)
end

-- MakeHoney(hive) é LIGA/DESLIGA. Pra não desligar sem querer:
--  * se o botão da colmeia diz "Stop..." = já está convertendo -> não dispara
--  * só tenta de novo se o pólen ficar 15s parado (as abelhas demoram a começar)
function Hive.prompt(h)
    if Hive.pp and Hive.pp.Parent and Hive.ppHive == h then return Hive.pp end
    Hive.pp, Hive.ppHive = nil, h
    for _, d in ipairs(h:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.ActionText:lower():find("honey", 1, true) then Hive.pp = d break end
    end
    return Hive.pp
end
function Hive.converting(h)
    local pp = Hive.prompt(h)
    if pp then
        local t = pp.ActionText:lower()
        if t:find("stop", 1, true) or t:find("parar", 1, true) then return true end
        if t:find("make honey", 1, true) then return false end
    end
    return nil   -- não dá pra saber pelo botão
end
function Hive.toggle(h)
    local mk = remote("MakeHoney")
    if mk then pcall(function() mk:FireServer(h) end) return end
    local pp = Hive.prompt(h)
    if pp and fireproximityprompt then pcall(fireproximityprompt, pp) end
end

function Hive.convert()
    local h = Hive.mine()
    local plat = Hive.platform(h)
    if not plat then act("Sem colmeia") task.wait(1) return end
    St.useTool = false
    act("Indo para a colmeia")
    local cp = Hive.convertPos(h, plat)
    Move.tween(cp, nil, function() return Sched.check() end)
    if Sched.check() then return end
    task.wait(0.3)
    -- já está convertendo? (botão "Stop" ou pólen caindo)
    local state = Hive.converting(h)
    if state == nil then
        local p0 = U.pollen()
        task.wait(1)
        state = U.pollen() < p0
    end
    if not state then Hive.toggle(h) end
    act("Convertendo")
    local lastP, lastChange, retries, t0 = U.pollen(), tick(), 0, tick()
    while running() and Cfg.AutoConvert and U.pollen() > 0 and tick() - t0 < Cfg.ConvertTimeout do
        if Sched.check() then return end
        task.wait(0.4)
        local p = U.pollen()
        if p < lastP then lastP, lastChange = p, tick() end
        if tick() - lastChange > 15 and retries < 2 then
            -- só religa se tiver certeza que está desligado (botão) ou sem jeito de saber
            if Hive.converting(h) ~= true then
                retries += 1
                act("Conversão parada, ligando de novo (" .. retries .. "/2)")
                Hive.toggle(h)
            end
            lastChange = tick()
        end
        local hrp = U.hrp()
        if hrp and (hrp.Position - cp).Magnitude > 4 then Move.tween(cp) end
    end
    -- a bolsa zera antes do mel terminar de entrar: espera o mel parar de subir
    local lastH, stable, t1 = U.honey(), tick(), tick()
    while running() and Cfg.AutoConvert and tick() - t1 < Cfg.ConvertTimeout do
        if Sched.check() then return end
        task.wait(0.25)
        local hv = U.honey()
        if hv ~= lastH then lastH, stable = hv, tick() end
        if U.pollen() > 0 then stable = tick() end
        local left = Cfg.ConvertSettle - (tick() - stable)
        if left <= 0 then break end
        act(string.format("Finalizando conversão (%.1fs)", left))
        local hrp = U.hrp()
        if hrp and (hrp.Position - cp).Magnitude > 4 then Move.tween(cp) end
    end
end

------------------------------------------------------------------
-- MOBS: spawners + timers (PlayerData.Mobs.<campo>.<n> = hora da morte em ms)
------------------------------------------------------------------
local Mob = { entries = {}, skip = {}, names = {} }
do
    local seen = {}
    for _, folder in ipairs(Spawners:GetChildren()) do
        for _, part in ipairs(folder:GetChildren()) do
            if part:IsA("BasePart") then
                local name = part:GetAttribute("Mob") or "?"
                table.insert(Mob.entries, {
                    key = folder.Name .. "#" .. part.Name, field = folder.Name, part = part, mob = name,
                    respawn = part:GetAttribute("Respawn") or 0,
                })
                if not seen[name] then seen[name] = true table.insert(Mob.names, name) end
            end
        end
    end
    table.sort(Mob.names)
    table.sort(Mob.entries, function(a, b) return a.respawn < b.respawn end)
end
function Mob.value(e)
    local m = PD:FindFirstChild("Mobs")
    local f = m and m:FindFirstChild(e.field)
    return f and f:FindFirstChild(e.part.Name)
end
function Mob.remaining(e)
    local v = Mob.value(e)
    if not v or v.Value <= 0 then return 0 end
    return math.max(0, v.Value / 1000 + e.respawn - U.serverNow())
end
-- Área de luta: o campo do spawner. Mobs fora de campo (Royal Beetle, Shadow Bear...)
-- ganham uma área virtual em volta do spawner e contam sempre como liberados.
Mob.virtual = {}
function Mob.area(field)
    local hb = F.hb(field)
    if hb then return hb end
    local v = Mob.virtual[field]
    if v then return v end
    local sum, n = Vector3.zero, 0
    for _, e in ipairs(Mob.entries) do
        if e.field == field then sum += e.part.Position n += 1 end
    end
    if n == 0 then return nil end
    local c = sum / n
    local stand = Move.ground(c, 15, 80)
    local size = 50
    v = { CFrame = CFrame.new(c.X, stand.Y - 2, c.Z), Size = Vector3.new(size, 2, size),
          Position = Vector3.new(c.X, stand.Y - 2, c.Z), Name = field, virtual = true }
    Mob.virtual[field] = v
    return v
end
function Mob.areaUnlocked(field)
    local fname = Mob.fieldName(field)
    if not F.hb(fname) then return true end   -- não fica em campo: sempre liberado
    return F.unlocked(fname)
end
function Mob.fieldHB(field) return Mob.area(field) end
function Mob.fieldName(field)
    local hb = F.hb(field)
    return hb and hb.Parent.Name or field
end
-- boss = mob que não fica em field (Royal Beetle, Shadow Bear...)
Mob.BOSSES = { "Royal Beetle", "Shadow Bear" }
function Mob.isBoss(e)
    return U.match(Mob.BOSSES, e.mob) ~= nil or F.hb(Mob.fieldName(e.field)) == nil
end
function Mob.ready(e)
    return Mob.areaUnlocked(e.field) and Mob.remaining(e) <= 0 and (Mob.skip[e.key] or 0) < tick()
end
-- spawner pronto mais perto que satisfaz filtro(e)
function Mob.nearest(filter)
    local hrp = U.hrp()
    local best, bd
    for _, e in ipairs(Mob.entries) do
        if filter(e) and Mob.ready(e) then
            local d = hrp and (e.part.Position - hrp.Position).Magnitude or 0
            if not bd or d < bd then best, bd = e, d end
        end
    end
    return best
end
-- DONO DO MOB: mob de outro player não dá dano em você, então o script ignora.
--  1) atributo OwnerID (UserId do dono) — confirmado pelo espião
--  2) ObjectValue TargetPlayer (player alvo)
--  3) último recurso: pra onde o mob anda (MMSent)
Mob.owner = setmetatable({}, { __mode = "k" })     -- [mob] = true (meu) / false (de outro)
Mob.chase = setmetatable({}, { __mode = "k" })     -- [mob] = { me = n, other = n }
function Mob.ownerId(m)
    return tonumber(m:GetAttribute("OwnerID"))
end
function Mob.targetPlayer(m)
    local tp = m:FindFirstChild("TargetPlayer")
    if tp and tp:IsA("ObjectValue") and tp.Value and tp.Value:IsA("Player") then return tp.Value end
    return nil
end
function Mob.noteTarget(mob, pos)
    local hrp = U.hrp()
    local c = Mob.chase[mob] or { me = 0, other = 0 }
    Mob.chase[mob] = c
    local dMe = hrp and U.fdist(pos, hrp.Position) or math.huge
    local dOther = math.huge
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LP then
            local r = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
            if r then dOther = math.min(dOther, U.fdist(pos, r.Position)) end
        end
    end
    if dMe < 12 and dMe <= dOther then c.me += 1
    elseif dOther < 12 and dOther < dMe then c.other += 1 end
end
function Mob.isMine(m)
    local known = Mob.owner[m]
    if known ~= nil then return known end
    local id = Mob.ownerId(m)
    if id then
        Mob.owner[m] = (id == LP.UserId)
        return Mob.owner[m]
    end
    local tp = Mob.targetPlayer(m)
    if tp then return tp == LP end
    local c = Mob.chase[m]
    if c and c.other >= 2 and c.me == 0 then return false end   -- só persegue outro player
    return true
end

function Mob.isDead(m)
    if not m or not m.Parent then return true end
    local h = m:FindFirstChildOfClass("Humanoid")
    if h and h.Health <= 0 then return true end
    local hp = m:GetAttribute("HP") or m:GetAttribute("Health")
    return type(hp) == "number" and hp <= 0
end

------------------------------------------------------------------
-- LUTA (sistema novo)
--  * decide 10x por segundo entre 33 pontos (2 anéis x 16 direções + ficar)
--  * TODOS os mobs contam; previsão pelo MMSent e pela velocidade
--  * mob parado na sua frente = vai pular: o corredor do pulo é proibido -> esquiva LATERAL
--  * aprende alcance e tempo de preparação de cada mob a cada dano levado
------------------------------------------------------------------
local Fight = { st = {}, mm = {}, active = false, data = readJSON(FILES.mobs) or {}, dirty = false, log = "" }
function Fight.info(kind)
    local d = Fight.data[kind]
    if type(d) ~= "table" then d = { range = 14, windup = 0.6, hits = 0 } Fight.data[kind] = d end
    return d
end
do
    local mm = remote("MMSent")
    if mm and mm:IsA("RemoteEvent") then
        conn(mm.OnClientEvent:Connect(function(mob, cf, dur)
            if typeof(mob) == "Instance" and typeof(cf) == "CFrame" then
                local d = tonumber(dur) or 1
                Fight.mm[mob] = { pos = cf.Position, t0 = tick(), dur = d, untilT = tick() + d + 0.2 }
                Mob.noteTarget(mob, cf.Position)
            end
        end))
    end
end
conn(MobsF.ChildRemoved:Connect(function(m) Fight.mm[m] = nil Fight.st[m] = nil end))

-- mobs vivos dentro do campo (+pad)
function Fight.mobsIn(hb, pad)
    local out = {}
    if not hb then return out end
    for _, m in ipairs(MobsF:GetChildren()) do
        if not Mob.isDead(m) and Mob.isMine(m) then
            local p = U.pos(m)
            if p and F.inside(hb, p, pad or 10) then table.insert(out, m) end
        end
    end
    return out
end

local RING = {}
for k = 0, 15 do local a = k * math.pi / 8 table.insert(RING, Vector3.new(math.cos(a), 0, math.sin(a))) end

-- atualiza posição/velocidade/estado de um mob
-- Estados: andando (chegando perto) -> PARADO na sua frente (preparando) -> PULO.
-- Só o pulo é perigo de verdade: o resto do tempo o personagem fica PARADO pras abelhas baterem.
function Fight.track(m, me, now)
    local st = Fight.st[m]
    local p = U.pos(m)
    if not p then return nil end
    if not st then
        st = { pos = p, t = now, vel = Vector3.zero, kind = m.Name }
        Fight.st[m] = st
    else
        local dt = now - st.t
        if dt > 0.03 then
            local v = (U.flat(p) - U.flat(st.pos)) / dt
            st.vel = st.vel:Lerp(v, 0.6)
            st.pos, st.t = p, now
        end
    end
    local info = Fight.info(st.kind)
    st.d = U.fdist(p, me)
    st.speed = st.vel.Magnitude
    -- parado perto de você = preparando o pulo
    if st.d < info.range + 6 and st.speed < 2.5 then
        st.stopped = st.stopped or now
        st.lastStop = now
    else
        st.stopped = nil
    end
    st.threat = 0
    st.aimFrom, st.aimTo = nil, nil
    local toMe = st.d > 0.2 and (U.flat(me) - U.flat(p)).Unit or nil
    local recentStop = st.lastStop and now - st.lastStop < 1
    -- pulo: MMSent logo depois de parar, com destino em cima de você
    local mv = Fight.mm[m]
    if mv and now < mv.untilT and recentStop and mv.t0 >= (st.lastStop or 0) - 0.3
       and U.fdist(mv.pos, me) < 6 and st.d < info.range + 8 then
        st.threat = 1
        local dir = U.flat(mv.pos) - U.flat(p)
        st.aimFrom, st.aimTo = p, mv.pos + (dir.Magnitude > 0.1 and dir.Unit * 5 or Vector3.zero)
    end
    -- pulo: arrancada rápida na sua direção logo depois de parar
    if toMe and st.speed > 14 and st.vel.Unit:Dot(toMe) > 0.7 and (recentStop or st.speed > 30) and st.d < info.range + 10 then
        st.threat = 1
        st.aimFrom, st.aimTo = p, p + st.vel.Unit * (info.range + 8)
    end
    return st
end

-- um passo de luta: FICA PARADO (pulando) e só se mexe pra
--   1) esquivar de lado quando um mob vai pular  2) sair de cima de mob colado
--   3) fugir com vida baixa  4) chegar mais perto se ficou longe demais pras abelhas
function Fight.step(hb, mobs, ctx)
    local hum, hrp = U.hum(), U.hrp()
    if not (hum and hrp) then return end
    local now = tick()
    local me = hrp.Position
    local sts = {}
    for _, m in ipairs(mobs) do
        local s = Fight.track(m, me, now)
        if s then table.insert(sts, s) end
    end
    if #sts == 0 then return end
    if Cfg.FightJump then hum.Jump = true end

    -- esquiva em andamento: termina antes de decidir de novo
    if ctx.dodgeUntil and now < ctx.dodgeUntil and ctx.dodgeTo then
        if U.fdist(ctx.dodgeTo, me) > 1.5 then hum:MoveTo(ctx.dodgeTo) return end
    end
    ctx.dodgeUntil = nil

    -- nota de um ponto: fora dos corredores de pulo, longe de mob colado, dentro do campo
    local function clearance(p)
        local s = 0
        for _, m in ipairs(sts) do
            if m.aimFrom then
                local dc = U.segDist(p, m.aimFrom, m.aimTo)
                if dc < 7 then s -= (7 - dc) * 50 end
            end
            local d = U.fdist(p, m.pos)
            if d < 6 then s -= (6 - d) * 15 end
        end
        local e = F.edgeDist(hb, p)
        if e < 5 then s -= (5 - e) * 8 end
        return s
    end
    local function bestAround(dirs, dists)
        local best, bs = nil, -math.huge
        for _, d in ipairs(dirs) do
            for _, r in ipairs(dists) do
                local p = F.clamp(hb, me + d * r, 3)
                local sc = clearance(p) - r * 0.2
                if sc > bs then best, bs = p, sc end
            end
        end
        return best, bs
    end

    local nearest, threat = nil, nil
    for _, m in ipairs(sts) do
        if not nearest or m.d < nearest.d then nearest = m end
        if m.threat >= 1 and m.aimFrom and U.segDist(me, m.aimFrom, m.aimTo) < 7 then threat = m end
    end

    -- 1) mob vai pular em você: passo LATERAL (perpendicular ao pulo)
    if threat then
        local dir = U.flat(threat.aimTo - threat.aimFrom)
        dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
        local perp = Vector3.new(-dir.Z, 0, dir.X)
        local dirs = { perp, -perp, (perp - dir * 0.4).Unit, (-perp - dir * 0.4).Unit }
        local p = bestAround(dirs, { 9, 13 })
        ctx.dodgeTo, ctx.dodgeUntil = p, now + 0.45
        ctx.kiteTo = nil
        Fight.dodges = (Fight.dodges or 0) + 1
        act("Esquivando de " .. threat.kind)
        hum:MoveTo(p)
        return
    end
    local low = hum.MaxHealth > 0 and hum.Health / hum.MaxHealth * 100 < Cfg.RetreatHP
    -- 2) vida baixa: se afasta do mob mais perto e fica longe
    if low and nearest.d < Cfg.FightFar then
        local away = U.flat(me - nearest.pos)
        away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
        local p = F.clamp(hb, me + away * 12, 4)
        if U.fdist(p, me) < 4 then p = bestAround(RING, { 14 }) end
        hum:MoveTo(p)
        return
    end
    -- 3) mob PAROU na sua frente: espera o tempo de passo (0.9s, aprende por mob) e dá um
    --    passo de lado. O mob anda pra te alcançar, o cooldown do ataque dele reseta,
    --    e ele fica quase parado o resto do tempo pras abelhas baterem.
    if ctx.stepTo then
        if now < ctx.stepUntil and U.fdist(ctx.stepTo, me) > 1 then hum:MoveTo(ctx.stepTo) return end
        ctx.stepTo = nil
    end
    local who, stoppedFor = nil, 0
    for _, m in ipairs(sts) do
        if m.stopped and m.d < Fight.info(m.kind).range + 6 and now - m.stopped > stoppedFor then
            who, stoppedFor = m, now - m.stopped
        end
    end
    if who and stoppedFor >= (Fight.info(who.kind).stepDelay or Cfg.StepDelay) and now - (ctx.lastStep or 0) > 0.3 then
        ctx.lastStep = now
        local dir = U.flat(who.pos - me)
        dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
        local perp = Vector3.new(-dir.Z, 0, dir.X)
        ctx.side = -(ctx.side or 1)
        local function cand(sign) return F.clamp(hb, me + perp * sign * Cfg.StepSize, 4) end
        local p = cand(ctx.side)
        local q = cand(-ctx.side)
        -- prefere o lado de dentro do campo e longe de outros mobs
        local function sc(x) return clearance(x) + math.min(F.edgeDist(hb, x), 12) end
        if sc(q) > sc(p) + 3 then p, ctx.side = q, -ctx.side end
        ctx.stepTo, ctx.stepUntil = p, now + 0.6
        act(string.format("Passo (%s parado %.1fs)", who.kind, stoppedFor))
        hum:MoveTo(p)
        return
    end
    -- 4) longe demais pras abelhas: chega um pouco mais perto
    if nearest.d > Cfg.FightFar then
        local to = U.flat(nearest.pos - me)
        hum:MoveTo(F.clamp(hb, me + to.Unit * math.min(10, nearest.d - Cfg.FightFar + 4), 3))
        return
    end
    -- seguro: pega loot seguro (se tiver) ou FICA PARADO
    local anyStopped = false
    for _, m in ipairs(sts) do if m.stopped then anyStopped = true end end
    if ctx.loot and not anyStopped then hum:MoveTo(ctx.loot) return end
    hum:MoveTo(me)
end

-- aprendizado: cada dano levado ajusta o alcance/tempo do mob mais perto
do
    local lastHP
    local function bind(char)
        local hum = char:WaitForChild("Humanoid", 10)
        if not hum then return end
        lastHP = hum.Health
        conn(hum.HealthChanged:Connect(function(h)
            if lastHP and h < lastHP - 0.5 then
                St.hits += 1
                if Fight.active then
                    local hrp = U.hrp()
                    local best, bd
                    for m, s in pairs(Fight.st) do
                        if m.Parent and s.pos and hrp then
                            local d = U.fdist(s.pos, hrp.Position)
                            if d < 45 and (not bd or d < bd) then best, bd = s, d end
                        end
                    end
                    if best then
                        local info = Fight.info(best.kind)
                        local target = bd + 3
                        if target > info.range then info.range += (target - info.range) * 0.5
                        else info.range += (target - info.range) * 0.03 end   -- hit colado quase não diminui
                        info.range = math.clamp(info.range, 10, 45)
                        if best.stopped then
                            local t = tick() - best.stopped
                            info.windup = math.clamp(info.windup + (t - info.windup) * 0.3, 0.15, 3)
                            -- apanhou antes de dar o passo: esse mob precisa de passo mais cedo
                            local sd = info.stepDelay or Cfg.StepDelay
                            if t < sd then info.stepDelay = math.clamp(t - 0.1, 0.3, Cfg.StepDelay) end
                        end
                        info.hits = (info.hits or 0) + 1
                        Fight.dirty = true
                        Fight.log = string.format("%s acertou a %.1f studs (alcance agora %.1f)", best.kind, bd, info.range)
                    end
                end
            end
            lastHP = h
        end))
    end
    if LP.Character then task.spawn(bind, LP.Character) end
    conn(LP.CharacterAdded:Connect(bind))
    task.spawn(function()
        while running() do
            task.wait(10)
            if Fight.dirty then Fight.dirty = false writeJSON(FILES.mobs, Fight.data) end
        end
    end)
end

-- ponto de chegada: dentro do campo, longe dos spawners e mobs
function Fight.arrivePoint(hb, field)
    if type(hb) == "table" and hb.virtual then   -- (Part de verdade não tem .virtual: daria erro)
        -- área virtual (fora de campo): chega a ~18 studs do spawner, do lado de onde você vem
        local c = hb.Position
        local hrp = U.hrp()
        local dir = hrp and U.flat(hrp.Position - c) or Vector3.new(1, 0, 0)
        dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
        return Move.ground(c + dir * 18 + Vector3.new(0, 3, 0), 15, 60)
    end
    local danger = {}
    for _, e in ipairs(Mob.entries) do if Mob.fieldName(e.field) == field then table.insert(danger, e.part.Position) end end
    for _, m in ipairs(Fight.mobsIn(hb, 10)) do local p = U.pos(m) if p then table.insert(danger, p) end end
    local best, bs
    local mx, mz = hb.Size.X / 2 - 8, hb.Size.Z / 2 - 8
    for i = -2, 2 do
        for j = -2, 2 do
            local p = F.toWorld(hb, mx * i / 2, mz * j / 2)
            local md = 45
            for _, q in ipairs(danger) do md = math.min(md, U.fdist(p, q)) end
            local s = md - (math.abs(i) + math.abs(j)) * 0.5
            if not bs or s > bs then best, bs = p, s end
        end
    end
    return best or F.center(hb)
end

-- token de loot perto de onde algum mob morreu (nascido depois da morte)
function Fight.lootTokens(hb, deaths)
    return Tok.inField(hb, function(t, p)
        for _, d in ipairs(deaths) do
            if U.fdist(p, d.pos) < Cfg.LootRadius and (Tok.born[t] or 0) >= d.t - 2 then return true end
        end
        return false
    end)
end

-- LOOP DE LUTA no campo. Fica até todos os mobs do campo morrerem.
-- devolve: "ok" | "noshow" | "timeout" | "abort"
function Fight.run(hb, label)
    Fight.active = true
    Fight.curHb = hb   -- raro que cair aqui durante a luta é pego pelo loot (não interrompe)
    St.useTool = true
    local ctx = { lastDir = nil }
    local deaths, alive = {}, {}
    local t0, lastSeen, seen = tick(), tick(), false
    local result = "ok"
    while true do
        if not running() or not U.alive() then result = "abort" break end
        if Sched.check() then result = "abort" break end
        local now = tick()
        local mobs = Fight.mobsIn(hb, 12)
        local cur = {}
        for _, m in ipairs(mobs) do cur[m] = true alive[m] = U.pos(m) or alive[m] end
        for m, p in pairs(alive) do
            if not cur[m] and Mob.isDead(m) then
                table.insert(deaths, { pos = p, t = now, kind = m.Name })
                St.kills += 1
                Fight.lootHb = hb   -- já tem loot no chão: raro aqui não interrompe a luta
                alive[m] = nil
            elseif not cur[m] then
                alive[m] = nil
            end
        end
        if #mobs > 0 then
            seen, lastSeen = true, now
            act(string.format("%s: %d mob(s) vivo(s), %d morto(s)", label or "Luta", #mobs, #deaths))
            -- loot seguro no meio da luta: token longe de todos os mobs
            ctx.loot = nil
            if #deaths > 0 then
                local l = Fight.lootTokens(hb, deaths)
                for _, e in ipairs(l) do
                    local ok = true
                    for _, m in ipairs(mobs) do
                        local p = U.pos(m)
                        if p and U.fdist(p, e.pos) < Fight.info(m.Name).range + Cfg.FightSafeExtra + 6 then ok = false break end
                    end
                    if ok then ctx.loot = e.pos break end
                end
            end
            Fight.step(hb, mobs, ctx)
        else
            if not seen and now - t0 > Cfg.MobSpawnWait then result = "noshow" break end
            if seen and now - lastSeen > 0.4 then break end   -- todos mortos: loot na hora
            act(seen and "Mobs mortos, conferindo..." or "Esperando o mob nascer...")
            local hum = U.hum()
            if hum and U.hrp() then hum:MoveTo(U.hrp().Position) end
        end
        if now - t0 > Cfg.KillTimeout then result = "timeout" break end
        task.wait(0.1)
    end
    Fight.active = false
    if #deaths > 0 and result ~= "abort" then Fight.loot(hb, deaths) end
    Fight.lootHb = nil
    Fight.curHb = nil
    return result, deaths
end

function Fight.loot(hb, deaths)
    if Remote.on() then
        -- coleta remota: não anda atrás do loot, só espera os drops caírem (são pegos sem andar)
        act("Loot dos mobs (remoto)")
        local lastDeath = 0
        for _, d in ipairs(deaths) do lastDeath = math.max(lastDeath, d.t) end
        while running() and tick() - lastDeath < 1.5 do task.wait(0.1) end
        return
    end
    act("Pegando loot dos mobs")
    Fight.lootHb = hb   -- token raro no meio do loot é pego pelo próprio loot (sem largar o resto)
    local lastDeath = 0
    for _, d in ipairs(deaths) do lastDeath = math.max(lastDeath, d.t) end
    local tEnd, lastFound = tick() + 12, tick()
    -- termina quando não tem loot há 1s (e já passou 1.5s da última morte, tempo dos drops caírem)
    while running() and U.alive() and tick() < tEnd and (tick() - lastFound < 1 or tick() - lastDeath < 1.5) do
        if Sched.check() then Fight.lootHb = nil return end
        local e = Fight.lootTokens(hb, deaths)[1]
        if e then
            lastFound = tick()
            Tok.collect(e, hb, false)
        else
            task.wait(0.1)
        end
    end
    Fight.lootHb = nil
end

-- vai até o campo e mata TODOS os mobs dele (só desse campo)
function Fight.clearField(field, label)
    local fname = Mob.fieldName(field)
    local hb = Mob.area(field)
    if not hb or not Mob.areaUnlocked(field) then return end
    St.useTool = false
    act("Indo para " .. U.fname(fname) .. " (" .. label .. ")")
    local hrp = U.hrp()
    if not (hrp and F.inside(hb, hrp.Position)) then
        Move.tween(Fight.arrivePoint(hb, fname), nil, function() return Sched.check() end)
        if Sched.check() then return end
    end
    local res, deaths = Fight.run(hb, label)
    if res == "ok" and #deaths > 0 then
        -- o timer do jogo demora um pouco pra atualizar: não volta pro mesmo campo à toa
        for _, e in ipairs(Mob.entries) do
            if Mob.fieldName(e.field) == fname then Mob.skip[e.key] = tick() + 25 end
        end
    elseif res == "noshow" or res == "timeout" then
        for _, e in ipairs(Mob.entries) do
            if Mob.fieldName(e.field) == fname and Mob.remaining(e) <= 0 then
                Mob.skip[e.key] = tick() + (res == "noshow" and 60 or 120)
            end
        end
    end
end

function Fight.timersText()
    local groups, order = {}, {}
    for _, e in ipairs(Mob.entries) do
        local g = groups[e.field]
        if not g then g = { field = e.field, list = {} } groups[e.field] = g table.insert(order, g) end
        table.insert(g.list, e)
    end
    local lines = {}
    for _, g in ipairs(order) do
        local parts = {}
        for _, e in ipairs(g.list) do
            local r = Mob.remaining(e)
            table.insert(parts, e.mob .. " " .. (r <= 0 and "pronto" or U.fmtTime(r)))
        end
        local lock = Mob.areaUnlocked(g.field) and "" or " [bloqueado]"
        table.insert(lines, U.fname(g.field) .. lock .. ": " .. table.concat(parts, ", "))
    end
    return table.concat(lines, "\n")
end
function Fight.learnText()
    local names = {}
    for k in pairs(Fight.data) do table.insert(names, k) end
    table.sort(names)
    local lines = {}
    for _, k in ipairs(names) do
        local d = Fight.data[k]
        table.insert(lines, string.format("%s: passo após %.2fs parado | alcance %.1f | %d hits", k, d.stepDelay or Cfg.StepDelay, d.range or 0, d.hits or 0))
    end
    if Fight.log ~= "" then table.insert(lines, "Último: " .. Fight.log) end
    return #lines > 0 and table.concat(lines, "\n") or "Nada aprendido ainda (aprende a cada dano levado)."
end

------------------------------------------------------------------
-- QUESTS
--  * lê o painel PlayerGui.Main.Quests.Container em tempo real (UpdateQuests = reserva)
--  * dono: quest nova que aparece no painel logo depois de falar com um urso = desse urso
--    (vale pro script falando E pra você falando na mão). Salvo pra sempre.
--  * regra da Mother (raise/feed) e WarnEvent (urso com quest pra pegar)
------------------------------------------------------------------
local Quest = {
    upd = {}, avail = {}, cooldown = {}, lastTalk = nil, dialog = { npc = nil, text = "", t = 0 },
    cache = nil, cacheT = 0, forced = {}, wantCache = nil, wantT = 0,
}
local MOTHER = "Mother Bear"
local QRemote = remote("QuestAction")
do
    local t = readJSON(FILES.owners) or {}
    Quest.owner = type(t.names) == "table" and t.names or {}
    Quest.base  = type(t.bases) == "table" and t.bases or {}
end
function Quest.save() writeJSON(FILES.owners, { names = Quest.owner, bases = Quest.base }) end
function Quest.baseName(n) return (n:gsub("%s*#%d+$", ""):gsub("%s+%d+$", "")) end
function Quest.npcNames()
    local t = {}
    if NPCF then for _, n in ipairs(NPCF:GetChildren()) do table.insert(t, n.Name) end end
    table.sort(t)
    return t
end

-- objetivo: "Collect 42,500 pollen from the Dandelion Field. 41,325/42,500" | "... Complete!"
function Quest.parseObj(txt)
    local clean = txt:gsub("<[^>]->", "")
    local done = clean:find("Complete!", 1, true) ~= nil
    local a, b = clean:match("([%d,%.]+)%s*/%s*([%d,%.]+)%s*$")
    local p = 0
    if a then
        local na, nb = tonumber((a:gsub(",", ""))), tonumber((b:gsub(",", "")))
        if na and nb and nb > 0 then p = na / nb end
    end
    if done then p = 1 end
    return { text = clean, p = p, done = done or p >= 0.999 }
end

function Quest.container()
    local pg = LP:FindFirstChild("PlayerGui")
    local m = pg and pg:FindFirstChild("Main")
    local q = m and m:FindFirstChild("Quests")
    return q and q:FindFirstChild("Container")
end

local function frameObjs(f)
    local title = f:FindFirstChild("Title")
    local objs = {}
    for _, d in ipairs(f:GetDescendants()) do
        if d:IsA("TextLabel") and not (title and d:IsDescendantOf(title)) then
            local tx = d.Text
            if #tx > 3 and tx ~= f.Name then table.insert(objs, Quest.parseObj(tx)) end
        end
    end
    return objs
end

-- { [nome] = { objs = {...}, complete = bool } }
-- Junta o painel (PlayerGui) com o UpdateQuests (vem do servidor, não depende do menu aberto).
-- Por objetivo fica o maior progresso das duas fontes (progresso só sobe).
-- Menu fechado e painel vazio sem UpdateQuests: usa a última foto conhecida.
Quest.seen, Quest.updT, Quest.lastKnown = {}, 0, {}
Quest.gotT, Quest.doneT, Quest.readyAt, Quest.pending = {}, {}, {}, nil
Quest.claimCD = {}
local function isTemplate(n) n = n:lower() return n:find("template", 1, true) or n:find("example", 1, true) end
function Quest.read()
    if Quest.cache and tick() - Quest.cacheT < 0.5 then return Quest.cache end
    local out = {}
    local function put(name, objs)
        local cur = out[name]
        if not cur then
            cur = { objs = {} }
            out[name] = cur
        end
        for i, o in ipairs(objs) do
            local e = cur.objs[i]
            if not e or (o.p or 0) > (e.p or 0) or (o.done and not e.done) then cur.objs[i] = o end
        end
    end
    local panelN = 0
    local c = Quest.container()
    if c then
        for _, f in ipairs(c:GetChildren()) do
            if f:IsA("GuiObject") and not isTemplate(f.Name) then
                local objs = frameObjs(f)
                if #objs > 0 then put(f.Name, objs) panelN += 1 end
            end
        end
    end
    if Quest.updT > 0 then
        -- o servidor já mandou a lista: ela manda (o painel atrasa e às vezes mostra quest já entregue)
        out = {}
        for n, q in pairs(Quest.upd) do put(n, q.objs) end
    end
    local talked = Quest.lastTalk and tick() - Quest.lastTalk.t < 10
    if not next(out) and next(Quest.lastKnown) and not talked and Quest.updT == 0 then
        out = Quest.lastKnown   -- painel sumiu (menu fechado?) e não tem outra fonte: mantém o que sabia
    end
    for _, q in pairs(out) do
        local complete = #q.objs > 0
        for _, o in ipairs(q.objs) do if not o.done then complete = false break end end
        q.complete = complete
    end
    Quest.lastKnown = out
    Quest.panelN = panelN
    Quest.cache, Quest.cacheT = out, tick()
    return out
end
function Quest.isMother(q)
    for _, o in ipairs(q.objs) do
        local t = o.text:lower()
        if t:find("feed", 1, true) or (t:find("raise", 1, true) and t:find("level", 1, true)) then return true end
    end
    return false
end

function Quest.setOwner(name, npc, why)
    if not name or not npc then return end
    if Quest.owner[name] == npc then return end
    Quest.owner[name] = npc
    Quest.base[Quest.baseName(name)] = npc
    Quest.save()
    act(string.format("Quest \"%s\" = %s (%s)", name, npc, why))
end

-- quest sem dono: regra da Mother, depois herança pelo nome base
function Quest.infer(name, q)
    if Quest.owner[name] then return end
    q = q or Quest.read()[name]
    if q and #q.objs > 0 and Quest.isMother(q) then Quest.setOwner(name, MOTHER, "raise/feed = Mother") return end
    local b = Quest.base[Quest.baseName(name)]
    if b and b ~= MOTHER then Quest.setOwner(name, b, "mesma série") end
end

-- quest apareceu no painel: se acabou de falar com um urso, é dele
function Quest.onAdded(name)
    Quest.cacheT = 0
    task.wait(0.15)
    local q = Quest.read()[name]
    if not Quest.owner[name] then
        local pre = name:match("^(.-)%s*|")
        if pre and pre ~= "" and NPCF and NPCF:FindFirstChild(pre) then
            Quest.setOwner(name, pre, "nome da quest")
            return
        end
        local pd = Quest.pending
        if pd and tick() - pd.t < 90 and not (pd.npc ~= MOTHER and q and #q.objs > 0 and Quest.isMother(q)) then
            Quest.pending = nil
            Quest.setOwner(name, pd.npc, "aceitou no diálogo")
            return
        end
    end
    local lt = Quest.lastTalk
    if lt and tick() - lt.t < 8 then
        local npc = lt.npc
        if q and #q.objs > 0 and Quest.isMother(q) then npc = MOTHER end
        if npc == MOTHER and q and #q.objs > 0 and not Quest.isMother(q) then
            Quest.infer(name, q)   -- Mother sempre tem raise/feed: não é dela
        else
            Quest.setOwner(name, npc, "conversa")
        end
    else
        Quest.infer(name, q)
    end
end
function Quest.onRemoved(name)
    Quest.cacheT = 0
    Quest.seen[name] = nil
    Quest.upd[name] = nil
    local owner = Quest.owner[name]
    St.quests += 1
    if owner then Quest.cooldown[owner] = nil end
    if Hook.questDone then Hook.questDone(name, owner) end
end

-- O servidor só manda o UpdateQuests enquanto o menu de quests está "aberto":
-- o jogo avisa com Events.StateSet("Quests") ao abrir e StateSet("") ao fechar.
-- Com o menu fechado, o BSU manda StateSet("Quests") a cada 3s pra continuar recebendo o progresso.
do
    local stateR = remote("StateSet")
    local function menuOpen()
        local c = Quest.container()
        local q = c and c.Parent
        return q and q:IsA("GuiObject") and q.Visible and q.Position.X.Scale > -0.05
    end
    if stateR then
        task.spawn(function()
            while running() do
                if (Cfg.AutoQuest or next(Cfg.QuestClaim)) and not menuOpen() then
                    pcall(function() stateR:FireServer("Quests") end)
                end
                task.wait(3)
            end
        end)
    end
end

-- acompanha as quests (painel + UpdateQuests) a cada 1s: quest nova -> dono; sumiu de verdade -> entregue
Quest.goneT = {}
task.spawn(function()
    task.wait(1)
    for n in pairs(Quest.read()) do Quest.seen[n] = true end
    for n, q in pairs(Quest.read()) do Quest.infer(n, q) end
    while running() do
        Quest.cacheT = 0
        local qs = Quest.read()
        for n in pairs(qs) do
            Quest.goneT[n] = nil
            if not Quest.seen[n] then
                Quest.seen[n] = true
                task.spawn(Quest.onAdded, n)
            end
        end
        for n in pairs(Quest.seen) do
            if not qs[n] then
                Quest.goneT[n] = Quest.goneT[n] or tick()
                -- sumiu por 2s seguidos e dá pra confiar: o servidor confirmou, ou o painel ainda mostra outras,
                -- ou acabou de falar com um urso
                local talked = Quest.lastTalk and tick() - Quest.lastTalk.t < 15
                local sure = (Quest.updT > Quest.goneT[n]) or (Quest.panelN or 0) > 0 or talked
                if tick() - Quest.goneT[n] > 2 and sure then
                    Quest.goneT[n] = nil
                    Quest.onRemoved(n)
                end
            end
        end
        task.wait(1)
    end
end)

-- remotes
if QRemote then
    conn(QRemote.OnClientEvent:Connect(function(npc, text, more)
        if type(npc) == "string" then
            Quest.dialog = { npc = npc, text = tostring(text or ""), t = tick(), more = more }
            local low = Quest.dialog.text:lower()
            -- "I haven't quite finished preparing the next quest for you." = ainda sem quest nova
            if low:find("preparing", 1, true) or low:find("haven't quite", 1, true) or low:find("havent quite", 1, true) then
                Quest.notReady = Quest.notReady or {}
                Quest.notReady[npc] = tick()
            end
            -- "Come back to me in 03:44" = tempo exato até a próxima quest
            local mm, ss = low:match("come back[^%d]*(%d+):(%d+)")
            if mm then
                Quest.readyAt[npc] = tick() + tonumber(mm) * 60 + tonumber(ss) + 3
                Quest.notReady[npc] = tick()
            end
            -- aceitou quest nova: a quest só chega no painel/UpdateQuests no próximo progresso (pode levar ~20s)
            if low:find("check your quest menu", 1, true) or low:find("complete it and", 1, true) then
                Quest.gotT[npc] = tick()
                Quest.pending = { npc = npc, t = tick() }
            end
            -- entregou
            if low:find("great job", 1, true) or low:find("here's some", 1, true) or low:find("heres some", 1, true)
                or low:find("well done", 1, true) then
                Quest.doneT[npc] = tick()
            end
            Quest.lastTalk = { npc = npc, t = tick() }
        end
    end))
end
do
    local r = remote("UpdateQuests")
    if r then
        conn(r.OnClientEvent:Connect(function(list)
            if type(list) ~= "table" then return end
            Quest.upd = {}
            Quest.updT = tick()
            for _, q in pairs(list) do
                if type(q) == "table" and type(q[1]) == "string" then
                    local objs = {}
                    for _, o in pairs(type(q[2]) == "table" and q[2] or {}) do
                        if type(o) == "table" then
                            local p = tonumber(o[2]) or 0
                            local txt = tostring(o[1] or "")
                            table.insert(objs, { text = txt, p = p, done = p >= 0.999 or txt:find("Complete!", 1, true) ~= nil })
                        end
                    end
                    local complete = #objs > 0
                    for _, o in ipairs(objs) do if not o.done then complete = false end end
                    Quest.upd[q[1]] = { objs = objs, complete = complete }
                end
            end
            Quest.cacheT = 0
        end))
    end
    local w = remote("WarnEvent")
    if w then
        conn(w.OnClientEvent:Connect(function(npc, avail)
            if type(npc) == "string" and type(avail) == "boolean" then
                if avail and not Quest.avail[npc] then Quest.cooldown[npc] = nil end
                Quest.avail[npc] = avail
                Quest.wantT = 0
            end
        end))
    end
end

-- (tem quest ativa, tem quest pronta) desse urso
function Quest.npcState(npc, qs)
    qs = qs or Quest.read()
    local active, complete = false, false
    for n, q in pairs(qs) do
        if Quest.owner[n] == npc then
            active = true
            if q.complete then complete = true end
        end
    end
    return active, complete
end
function Quest.unknown(qs)
    local t = {}
    for n, q in pairs(qs or Quest.read()) do if not Quest.owner[n] then t[n] = q end end
    return t
end

-- ursos com tempo entre quests (Gray Bear: 5 min): só pega quando o aviso do jogo (WarnEvent) diz que tem quest
Quest.WARN_ONLY = { ["Gray Bear"] = true }
Quest.REPEAT_CD = { ["Gray Bear"] = 5 * 60 + 5 }   -- tempo entre quests (contado de quando pegou)
Quest.notReady, Quest.blockUntil, Quest.pickT = Quest.notReady or {}, {}, {}
-- urso que o script FAZ as quests (Auto Complete + toggle do urso)
function Quest.doing(npc) return Cfg.AutoQuest and Cfg.QuestNPCs[npc] == true end
-- urso que o script só ENTREGA quando fica pronta (Auto Claim)
function Quest.claims(npc) return Cfg.QuestClaim[npc] == true end
function Quest.active(npc) return Quest.doing(npc) or Quest.claims(npc) end
-- ligar o urso pra fazer também liga o Auto Claim dele
function Quest.setDoing(npc, v)
    Cfg.QuestNPCs[npc] = v or nil
    if v and not Cfg.QuestClaim[npc] then
        local c = deepcopy(Cfg.QuestClaim)
        c[npc] = true
        setCfg("QuestClaim", c)
    end
    Quest.wantT = 0
end
for n, v in pairs(Cfg.QuestNPCs) do if v then Cfg.QuestClaim[n] = true end end
-- ursos de quest repetível (o resto é Main Quest)
Quest.REPEATABLE = { "Polar Bear", "Gray Bear" }
function Quest.npcGroup(repeatable)
    local t = {}
    for _, n in ipairs(Quest.npcNames()) do
        if (table.find(Quest.REPEATABLE, n) ~= nil) == repeatable then table.insert(t, n) end
    end
    return t
end

-- precisa visitar? devolve (motivo, urgente)
function Quest.needs(npc, qs)
    if not (NPCF and NPCF:FindFirstChild(npc)) then return nil end
    local doing = Quest.doing(npc)
    if not (doing or Quest.claims(npc)) then return nil end
    if Quest.forced[npc] and doing then return "visita manual", true end
    -- quest pronta passa por cima do intervalo normal (só espera 45s se a última entrega falhou)
    local active, complete = Quest.npcState(npc, qs)
    if complete and tick() >= (Quest.claimCD[npc] or 0) then return "entregar quest de " .. npc, true end
    if tick() < (Quest.cooldown[npc] or 0) then return nil end
    if not doing then return nil end   -- só Auto Claim: não pega nem faz quest
    -- urso disse que ainda não tem quest nova: não volta antes do tempo (mesmo com o aviso do jogo)
    if not active and tick() < (Quest.blockUntil[npc] or 0) then return nil end
    if Quest.avail[npc] == true and not active then return "pegar quest de " .. npc, true end
    if Quest.retry and (Quest.retry[npc] or 0) > 0 and not active then return "pegar quest nova de " .. npc, true end
    if active then return nil end
    -- quest pronta sem dono: tenta nos ursos sem quest conhecida
    for n, q in pairs(Quest.unknown(qs)) do
        if q.complete and (npc ~= MOTHER or Quest.isMother(q)) then return "tentar entregar \"" .. n .. "\" em " .. npc, true end
    end
    if Quest.avail[npc] == false then return nil end
    return "ver se " .. npc .. " tem quest", false
end
function Quest.next()
    local qs = Quest.read()
    local best, why, urg
    for _, npc in ipairs(Quest.npcNames()) do
        local r, u = Quest.needs(npc, qs)
        if r and (not best or (u and not urg)) then best, why, urg = npc, r, u end
    end
    return best, why, urg
end
function Quest.want()
    if not ((Cfg.AutoQuest or next(Cfg.QuestClaim)) and QRemote and NPCF) or Sprout.looting() then return nil end
    if Quest.bgBusy then return nil end
    if tick() - Quest.wantT < 0.5 then return Quest.wantCache end
    Quest.wantT = tick()
    local npc, why, urg = Quest.next()
    local r = nil
    if npc and Quest.remoteOk[npc] and tick() - (Quest.remoteFail[npc] or 0) > 600 then
        -- de longe: não precisa esvaziar a bolsa nem sair do field, já dispara
        Quest.wantCache = nil
        Quest.run()
        return nil
    end
    if npc then
        if urg and not Cfg.QuestAfterConvert then r = why
        elseif U.bagEmpty() then r = why end
    end
    Quest.wantCache = r
    return r
end

-- ponto em pé na frente do urso
function Quest.standPos(npc)
    local cf = npc:GetPivot()
    local root = npc:FindFirstChild("HumanoidRootPart")
    local refY = root and root.Position.Y or cf.Position.Y
    local p = (cf + cf.LookVector * 6).Position
    return Move.ground(Vector3.new(p.X, refY, p.Z), 8, 25)
end

-- uma conversa: Start uma vez, depois Continue até acabar
function Quest.talk(npc)
    local before = Quest.dialog.t
    pcall(function() QRemote:FireServer(npc, "Start") end)
    local t0 = tick()
    while tick() - t0 < 2.5 and Quest.dialog.t == before do task.wait(0.03) end
    if Quest.dialog.t == before then
        pcall(function() QRemote:FireServer(npc, "Continue") end)
        local t1 = tick()
        while tick() - t1 < 1 and Quest.dialog.t == before do task.wait(0.03) end
        if Quest.dialog.t == before then return false end
    end
    local noReply = 0
    for _ = 1, 40 do
        if not (running() and Quest.active(npc)) then break end
        local last = Quest.dialog.t
        act(npc .. ": " .. (Quest.dialog.text ~= "" and Quest.dialog.text or "..."))
        task.wait(Cfg.TalkDelay)
        pcall(function() QRemote:FireServer(npc, "Continue") end)
        local t1 = tick()
        while tick() - t1 < 0.5 and Quest.dialog.t == last do task.wait(0.03) end
        if Quest.dialog.t == last then
            noReply += 1
            if noReply >= 2 then break end
        else
            noReply = 0
        end
    end
    return true
end

local function nameSet(qs) local s = {} for n in pairs(qs) do s[n] = true end return s end

Quest.remoteFail = {}   -- npc -> hora em que falar de longe falhou (aí vai andando por 10 min)
Quest.remoteOk = {}     -- npc -> já respondeu de longe (aí a conversa roda em segundo plano, sem parar o farm)
Quest.bgBusy = false    -- conversa em segundo plano rolando (uma por vez: o diálogo é um só)
-- bg = true: só de longe, em segundo plano (não para o farm nem a ferramenta)
function Quest.visit(npc, bg)
    local model = NPCF and NPCF:FindFirstChild(npc)
    if not model then return end
    if not bg then St.useTool = false end
    local tryingUnknown = {}
    for n, q in pairs(Quest.unknown()) do if q.complete then tryingUnknown[n] = true end end
    local turnedIn = false
    local visitT = tick()
    -- conversa inteira (pega/entrega até 5 vezes); devolve false se o urso não respondeu na 1ª
    local function session(remote)
        for i = 1, 5 do
            if not (running() and Quest.active(npc)) then break end
            Quest.cacheT = 0
            local before = nameSet(Quest.read())
            local tTalk = tick()
            if not Quest.talk(npc) then
                if i == 1 and not turnedIn then
                    if not remote then act(npc .. ": não respondeu") end
                    return false
                end
                -- logo depois de entregar o urso às vezes demora pra responder: tenta mais uma vez
                task.wait(1)
                if not Quest.talk(npc) then act(npc .. ": não respondeu") break end
            end
            task.wait(0.6)
            Quest.cacheT = 0
            local now = Quest.read()
            local changed = false
            if (Quest.gotT[npc] or 0) >= tTalk then changed = true Quest.pickT[npc] = Quest.gotT[npc] end
            if (Quest.doneT[npc] or 0) >= tTalk then changed = true turnedIn = true end
            for n in pairs(now) do
                if not before[n] then
                    changed = true
                    Quest.pickT[npc] = tick()
                    -- sem painel (só UpdateQuests): o diff aqui decide o dono
                    -- quest atrasada de outro urso (aceita antes) não é desse
                    local pd = Quest.pending
                    if not Quest.owner[n] and not (pd and pd.npc ~= npc and tick() - pd.t < 90) then
                        Quest.setOwner(n, npc, "conversa")
                    end
                end
            end
            for n in pairs(before) do
                if not now[n] then
                    changed = true
                    turnedIn = true
                    if tryingUnknown[n] then Quest.setOwner(n, npc, "aceitou a entrega") end
                end
            end
            if not changed then break end
            if not Quest.doing(npc) then break end   -- só Auto Claim: entregou, sai
            task.wait(0.3)
        end
        return true
    end
    local hrp
    local ok, err = pcall(function()
        -- 1º: fala de longe pelo remote, sem sair do lugar
        if tick() - (Quest.remoteFail[npc] or 0) > 600 then
            if not bg then act("Falando com " .. npc .. " de longe") end
            if session(true) then
                if not Quest.remoteOk[npc] then Con.log("Info", "Quest " .. npc .. ": falou de longe (próximas em segundo plano)") end
                Quest.remoteOk[npc] = true
                return
            end
            Quest.remoteFail[npc] = tick()
            Quest.remoteOk[npc] = nil
            Con.log("Info", "Quest " .. npc .. ": não respondeu de longe, indo até ele")
        end
        if bg then
            -- em segundo plano não anda: a próxima visita (normal) vai até o urso
            Quest.cooldown[npc] = nil
            return
        end
        if not (running() and Quest.active(npc)) then return end
        -- fallback: vai até o urso
        act("Indo até " .. npc)
        Move.tween(Quest.standPos(model))
        hrp = U.hrp()
        if hrp then hrp.AssemblyLinearVelocity = Vector3.zero hrp.Anchored = true end
        session(false)
    end)
    if hrp and hrp.Parent then hrp.Anchored = false end
    if not ok then warn("[BSU] quest:", err) end
    local active, complete = Quest.npcState(npc)
    if not active and (Quest.gotT[npc] or 0) >= visitT then active = true end
    Quest.retry = Quest.retry or {}
    if active then Quest.retry[npc] = 0 end
    if not active and (Quest.notReady[npc] or 0) > visitT then
        -- "ainda preparando a próxima quest": espera até completar o tempo do urso (ou 60s se não souber)
        local cd, pt = Quest.REPEAT_CD[npc], Quest.pickT[npc]
        local untilT = (cd and pt and pt + cd > tick()) and (pt + cd) or (tick() + 60)
        if (Quest.readyAt[npc] or 0) > tick() then untilT = Quest.readyAt[npc] end
        Quest.blockUntil[npc] = untilT
        Quest.retry[npc] = 0
        Quest.avail[npc] = false
        Quest.cooldown[npc] = untilT
    elseif Quest.WARN_ONLY[npc] and not active then
        -- entregou/visitou e não veio quest: espera o WarnEvent dizer que tem de novo
        Quest.retry[npc] = 0
        Quest.avail[npc] = false
        Quest.cooldown[npc] = nil
    elseif (turnedIn or (Quest.retry[npc] or 0) > 0) and Quest.doing(npc) and not active and not complete then
        -- entregou e não veio quest nova: volta logo pra pegar (até 3 vezes), depois o intervalo normal
        Quest.retry[npc] = (Quest.retry[npc] or 0) + 1
        Quest.avail[npc] = nil   -- o aviso (WarnEvent) pode não ter atualizado ainda
        if Quest.retry[npc] <= 3 then Quest.cooldown[npc] = tick() + 5
        else Quest.retry[npc] = 0 Quest.cooldown[npc] = tick() + Cfg.QuestInterval end
    elseif complete or next(tryingUnknown) then
        Quest.cooldown[npc] = tick() + 45
        Quest.claimCD[npc] = tick() + 45
    elseif not active and Quest.avail[npc] ~= true then
        Quest.cooldown[npc] = tick() + Cfg.QuestInterval
    end
    Quest.wantT = 0
end
function Quest.run()
    if Quest.bgBusy then return end
    local npc = Quest.next()
    if not npc then return end
    Quest.forced[npc] = nil
    if Quest.remoteOk[npc] and tick() - (Quest.remoteFail[npc] or 0) > 600 then
        -- urso que já respondeu de longe: conversa em segundo plano e o farm continua
        Quest.bgBusy = true
        task.spawn(function()
            local ok, err = pcall(Quest.visit, npc, true)
            if not ok then warn("[BSU] quest bg:", err) end
            Quest.bgBusy = false
            Quest.wantT = 0
        end)
        return
    end
    Quest.visit(npc)
end

-- mobs que as quests pedem ("Defeat 3 Ladybugs"), só de urso ligado
local function normMob(n) return (n:lower():gsub("[^%a]", ""):gsub("s$", "")) end
function Quest.mobTargets()
    local t = {}
    if not (Cfg.AutoQuest and Cfg.QuestMobs) then return t end
    for n, q in pairs(Quest.read()) do
        local owner = Quest.owner[n]
        if not q.complete and owner and Cfg.QuestNPCs[owner] then
            for _, o in ipairs(q.objs) do
                if not o.done then
                    local name = o.text:match("[Dd]efeat%s+[%d,]+%s+([%a%s]+)") or o.text:match("[Kk]ill%s+[%d,]+%s+([%a%s]+)")
                    if name then t[normMob(name)] = n end
                end
            end
        end
    end
    return t
end
function Quest.mobEntry()
    local want = Quest.mobTargets()
    if next(want) == nil then return nil end
    local e = Mob.nearest(function(x)
        if not Cfg.QuestKillBoss and Mob.isBoss(x) then return false end   -- "Matar boss" desligado
        return want[normMob(x.mob)] ~= nil
    end)
    return e, e and want[normMob(e.mob)]
end
-- campo que a quest pede ("Collect X pollen from the Dandelion Field")
do
    local qf = { t = 0, v = nil }
    -- campo pedido por um objetivo de pólen (nil se não for de field específica)
    local function namedField(o)
        local txt = o.text:lower():gsub("%s", "")
        local named = o.text:match("[Ff]rom the ([%a%s]-) [Ff]ield") or o.text:match("([%a]+[%a%s]-) [Ff]ield")
        local nf = named and F.find(named)
        if nf then return nf end
        for _, f in ipairs(F.names()) do
            local short = f:gsub("Field$", ""):lower()
            if short ~= "" and txt:find(short, 1, true) then return f end
        end
        return nil
    end
    -- Ursos cujo pólen vem primeiro (Polar Bear: pouco pólen + matar mobs — deixa o pólen pronto)
    Quest.POLLEN_FIRST = { "Polar Bear", "Gray Bear" }
    -- Ordem: quests do Polar Bear primeiro, depois as outras. Dentro de cada quest:
    -- 1º objetivos de FIELD específica, depois pólen por COR (na Best <cor> Field).
    function Quest.field()
        if not (Cfg.AutoQuest and Cfg.QuestField) then return nil end
        if tick() - qf.t < 1 then return qf.v end
        qf.t, qf.v = tick(), nil
        local list = {}
        for n, q in pairs(Quest.read()) do
            local owner = Quest.owner[n]
            if not q.complete and owner and Cfg.QuestNPCs[owner] then
                local rank = table.find(Quest.POLLEN_FIRST, owner) or 99
                table.insert(list, { name = n, q = q, rank = rank })
            end
        end
        table.sort(list, function(x, y)
            if x.rank ~= y.rank then return x.rank < y.rank end
            return x.name < y.name
        end)
        -- 0) field que alguma quest pede e que está BOOSTADA agora (qualquer boost, mesmo fora
        --    do Allowed Fields): faz ela antes das outras. Maior x primeiro.
        local boosted = (Boost and Boost.details) and Boost.details() or {}
        local bestB, bestS
        for _, e in ipairs(list) do
            for _, o in ipairs(e.q.objs) do
                if not o.done and o.text:lower():find("pollen", 1, true) then
                    local f = namedField(o)
                    local d = f and boosted[f]
                    if d and F.unlocked(f) and (not bestS or d.stack > bestS) then bestB, bestS = f, d.stack end
                end
            end
        end
        if bestB then qf.v = bestB return bestB end
        for _, e in ipairs(list) do
            local colorObjs = {}
            for _, o in ipairs(e.q.objs) do
                if not o.done and o.text:lower():find("pollen", 1, true) then
                    local f = namedField(o)
                    if f then
                        if F.unlocked(f) then qf.v = f return f end
                    else
                        table.insert(colorObjs, o)
                    end
                end
            end
            for _, o in ipairs(colorObjs) do
                local txt = o.text:lower():gsub("%s", "")
                for _, c in ipairs({ "blue", "red", "white" }) do
                    if txt:find(c .. "pollen", 1, true) then
                        local f = Quest.colorField(c)
                        if f then qf.v = f return f end
                    end
                end
            end
        end
        return nil
    end
end
-- campos de cada cor (ordem = do pior pro melhor; automático usa o último liberado)
Quest.COLORS = {
    blue  = { cfg = "BestBlue",  fields = { "Cornflower", "Bamboo", "Pine" } },
    red   = { cfg = "BestRed",   fields = { "Mushroom", "Strawberry", "Rose", "Pitaya" } },
    white = { cfg = "BestWhite", fields = { "Dandelion", "Spider", "Pineapple", "Pumpkin", "Coconut" } },
}
-- nomes reais dos campos de uma cor (ex.: "Pine" acha PineTreeForest, sem pegar Pineapple)
function Quest.colorOptions(color)
    local out = {}
    for _, kw in ipairs(Quest.COLORS[color].fields) do
        local k = U.key(kw)
        local found
        for _, f in ipairs(F.names()) do
            local fk = U.key(f)
            if fk:sub(1, #k) == k and not (k == "pine" and fk:find("pineapple", 1, true)) then found = f break end
        end
        -- "Spider" = o campo onde nasce o mob Spider (nome do campo não tem "spider")
        if not found and k == "spider" then
            for _, e in ipairs(Mob.entries) do
                if U.key(e.mob) == "spider" then found = Mob.fieldName(e.field) break end
            end
        end
        if found and not table.find(out, found) then table.insert(out, found) end
    end
    return out
end
function Quest.colorField(color)
    local def = Quest.COLORS[color]
    local chosen = Cfg[def.cfg]
    if chosen ~= "" and chosen ~= "Automático" then
        return F.unlocked(chosen) and chosen or nil
    end
    local opts = Quest.colorOptions(color)
    for i = #opts, 1, -1 do if F.unlocked(opts[i]) then return opts[i] end end
    return nil
end

function Quest.statusText()
    local qs = Quest.read()
    local names = {}
    for n in pairs(qs) do table.insert(names, n) end
    table.sort(names)
    local lines = {}
    if not Quest.container() then table.insert(lines, "(painel de quests não encontrado: usando UpdateQuests)") end
    for _, n in ipairs(names) do
        local q, ow = qs[n], Quest.owner[n]
        table.insert(lines, string.format("%s %s  [%s]%s%s", q.complete and "✔" or "•", n, ow or "dono ?",
            q.complete and " PRONTA" or "", (ow and not Quest.doing(ow)) and (Quest.claims(ow) and " (só entrega)" or " (urso desligado)") or ""))
        for _, o in ipairs(q.objs) do
            table.insert(lines, string.format("     %s %d%%", (o.text:gsub("%s*Complete!%s*$", "")), math.floor(math.clamp(o.p, 0, 1) * 100)))
        end
    end
    if #names == 0 then table.insert(lines, "Nenhuma quest ativa") end
    local av = {}
    for n, v in pairs(Quest.avail) do if v then table.insert(av, n) end end
    table.sort(av)
    if #av > 0 then table.insert(lines, "Com quest pra pegar: " .. table.concat(av, ", ")) end
    return table.concat(lines, "\n")
end

------------------------------------------------------------------
-- FIELD BOOSTERS
--  * usar: ProximityPrompt "Use the Field Booster" -> fireproximityprompt
--  * resultado: NotificationSent("Basic", 'Activated "Cornflower Field Boost" x3!')
--  * boost ativo: PlayerGui.Main.Buffs."<Campo> Field Boost" (Info.Header = "... (x3)")
------------------------------------------------------------------
Boost = { prompts = {}, nextTry = {}, lastActivated = nil, status = "-", origin = {}, tries = {}, renewing = {}, extended = {} }

-- acha o campo pelo começo do nome ("Cornflower" -> CornflowerField, "Pine Tree" -> PineTreeForest)
function F.find(prefix)
    local k = U.key(prefix)
    if k == "" then return nil end
    for _, f in ipairs(F.names()) do
        local fk = U.key(f)
        if fk:sub(1, #k) == k and not (k == "pine" and fk:find("pineapple", 1, true)) then return f end
    end
    return nil
end

-- nome amigável de cada booster (modelo onde o prompt está) + campo mais perto pra ajudar a identificar
local function boosterName(pp)
    local cur, name = pp.Parent, nil
    while cur and cur ~= workspace do
        if cur:IsA("Model") then name = cur.Name break end
        cur = cur.Parent
    end
    return name or (pp.Parent and pp.Parent.Name) or "Booster"
end
-- boosters conhecidos (nome do remote UseMachine -> nome na lista)
Boost.KNOWN = {
    { key = "BlueFieldBooster",  name = "Blue Field Booster",  color = "blue" },
    { key = "RedFieldBooster",   name = "Red Field Booster",   color = "red" },
    { key = "WhiteFieldBooster", name = "White Field Booster", color = "white" },
}
-- acha o prompt de cada booster no mapa (pelo nome do modelo ou pela cor)
function Boost.scan()
    local all = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and (d.ActionText .. " " .. d.ObjectText):lower():find("booster", 1, true) then
            local path = {}
            local cur = d.Parent
            while cur and cur ~= workspace do table.insert(path, U.key(cur.Name)) cur = cur.Parent end
            table.insert(all, { pp = d, path = table.concat(path, "/") })
            if not Boost.hooked then Boost.hooked = {} end
            if not Boost.hooked[d] then
                Boost.hooked[d] = true
                -- você usou o booster na mão: o boost que vier também conta como "de booster"
                conn(d.Triggered:Connect(function() Boost.manualAt = tick() end))
            end
        end
    end
    local found, used = {}, {}
    for _, k in ipairs(Boost.KNOWN) do
        local kk = U.key(k.key)
        for _, e in ipairs(all) do
            if not used[e] and e.path:find(kk, 1, true) then found[k.name] = e.pp used[e] = true break end
        end
        if not found[k.name] then
            for _, e in ipairs(all) do
                if not used[e] and e.path:find(k.color, 1, true) then found[k.name] = e.pp used[e] = true break end
            end
        end
    end
    -- não achou pelo prompt? procura um objeto com o nome da máquina ("BlueFieldBooster")
    Boost.where = {}
    for _, k in ipairs(Boost.KNOWN) do
        local inst = workspace:FindFirstChild(k.key, true)
        if not inst then
            local kk = U.key(k.key)
            for _, d in ipairs(workspace:GetDescendants()) do
                if U.key(d.Name) == kk then inst = d break end
            end
        end
        if inst then Boost.where[k.name] = U.pos(inst) end
        -- prompt mais perto desse objeto, se o nome não bateu antes
        if inst and not found[k.name] and Boost.where[k.name] then
            local best, bd
            for _, e in ipairs(all) do
                local p = Boost.pos(e.pp)
                local d = p and (p - Boost.where[k.name]).Magnitude
                if d and d < 40 and (not bd or d < bd) then best, bd = e.pp, d end
            end
            found[k.name] = best
        end
    end
    Boost.prompts = found
    return found
end
task.spawn(function() task.wait(3) pcall(Boost.scan) end)
do  -- seleções antigas (nomes de antes) saem da config
    local valid = {}
    for _, k in ipairs(Boost.KNOWN) do valid[k.name] = true end
    for n in pairs(Cfg.Boosters) do if not valid[n] then Cfg.Boosters[n] = nil end end
end
function Boost.names()
    local t = {}
    for _, k in ipairs(Boost.KNOWN) do table.insert(t, k.name) end
    return t
end
function Boost.pos(pp)
    local p = pp.Parent
    if p and p:IsA("Attachment") then return p.WorldPosition end
    return U.pos(p)
end

-- notificações: ativou (sucesso) ou cooldown ("... 12:34")
do
    local r = remote("NotificationSent")
    if r then
        conn(r.OnClientEvent:Connect(function(_, text)
            if type(text) ~= "string" then return end
            local field = text:match('Activated "(.-) Field Boost"')
            if field then
                Boost.lastActivated = { field = field, t = tick(), text = text }
                if Boost.manualAt and tick() - Boost.manualAt < 4 then
                    local f = F.find(field)
                    if f then Boost.origin[f] = tick() end
                    Boost.manualAt = nil
                end
                return
            end
            local low = text:lower()
            if low:find("boost", 1, true) then
                local h, m, s = text:match("(%d+):(%d+):(%d+)")
                if not h then m, s = text:match("(%d+):(%d+)") end
                if m then Boost.lastCooldown = { secs = (tonumber(h) or 0) * 3600 + tonumber(m) * 60 + tonumber(s), t = tick() } end
            end
        end))
    end
end

-- tempo restante escrito em algum texto do buff ("12:34", "1:02:03", "14m 5s", "45s")
local function parseTime(s)
    s = tostring(s)
    if s:find("Permanent", 1, true) then return math.huge end
    local h, m, sec = s:match("(%d+):(%d+):(%d+)")
    if h then return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(sec) end
    m, sec = s:match("^%s*(%d+):(%d%d)%s*$")
    if m then return tonumber(m) * 60 + tonumber(sec) end
    -- "16h 22m 17s" / "9m 38s" / "45s"
    local hh, mm, ss = s:match("(%d+)%s*h"), s:match("(%d+)%s*m"), s:match("(%d+)%s*s")
    if hh or mm or ss then return (tonumber(hh) or 0) * 3600 + (tonumber(mm) or 0) * 60 + (tonumber(ss) or 0) end
    return nil
end
function Boost.buffFolder()
    local pg = LP:FindFirstChild("PlayerGui")
    local main = pg and pg:FindFirstChild("Main")
    return main and main:FindFirstChild("Buffs")
end
-- detalhes de cada field boost ativo: { [campo] = { stack, left (s ou nil) } }
Boost.seenAt = {}
function Boost.details()
    local out = {}
    local buffs = Boost.buffFolder()
    if not buffs then return out end
    for _, b in ipairs(buffs:GetChildren()) do
        local prefix = b.Name:match("^(.-) Field Boost$")
        local f = prefix and F.find(prefix)
        if f then
            -- Main.Buffs."<Campo> Field Boost": Stack = "x4", Info.Time = "9m 38s"
            local stack, left = 1, nil
            local st = b:FindFirstChild("Stack")
            if st and st:IsA("TextLabel") then stack = tonumber(st.Text:match("x(%d+)")) or 1 end
            local info = b:FindFirstChild("Info")
            local tm = info and info:FindFirstChild("Time")
            if tm and tm:IsA("TextLabel") then left = parseTime(tm.Text) end
            if stack == 1 then
                local hd = info and info:FindFirstChild("Header")
                if hd and hd:IsA("TextLabel") then stack = tonumber(hd.Text:match("%(x(%d+)%)")) or stack end
            end
            Boost.seenAt[f] = Boost.seenAt[f] or tick()
            out[f] = { stack = stack, left = left }
        end
    end
    for f in pairs(Boost.seenAt) do if not out[f] then Boost.seenAt[f] = nil end end
    return out
end

-- boosts ativos: { [campo real] = stack }
function Boost.active()
    local out = {}
    local pg = LP:FindFirstChild("PlayerGui")
    local main = pg and pg:FindFirstChild("Main")
    local buffs = main and main:FindFirstChild("Buffs")
    if not buffs then return out end
    for _, b in ipairs(buffs:GetChildren()) do
        local prefix = b.Name:match("^(.-) Field Boost$")
        if prefix then
            local f = F.find(prefix)
            if f then
                local stack = 1
                local ok, hdr = pcall(function() return b.Info.Header.Text end)
                if ok and type(hdr) == "string" then stack = tonumber(hdr:match("%(x(%d+)%)")) or 1 end
                out[f] = math.max(out[f] or 0, stack)
            end
        end
    end
    return out
end
-- campo boostado que está na lista do usuário (maior stack)
function Boost.field()
    if not next(Cfg.BoostFields) then return nil end
    local best, bs
    for f, stack in pairs(Boost.active()) do
        if Cfg.BoostFields[f] and F.unlocked(f) and stack >= Cfg.MinBoostFarm and (not bs or stack > bs) then best, bs = f, stack end
    end
    return best, bs
end

-- booster pronto pra usar (ligado e fora do tempo de espera)
-- nome da máquina pro remote: "RedFieldBooster", "BlueFieldBooster"...
function Boost.machineKey(n)
    for _, k in ipairs(Boost.KNOWN) do if k.name == n or k.key == n then return k.key end end
    return (n:gsub("%s+%d+$", ""):gsub("%s", ""))
end
local BOOST_CD = 30 * 60   -- cooldown dos field boosters: 30 min
-- PlayerData.Cooldowns.<Máquina> (se existir): hora do último uso em ms
function Boost.cdLeft(n)
    local f = PD:FindFirstChild("Cooldowns")
    local v = f and f:FindFirstChild(Boost.machineKey(n))
    local val = v and tonumber(v.Value)
    if val and val > 1e11 then return math.max(0, val / 1000 + BOOST_CD - U.serverNow()) end
    return nil
end
-- Stagger Boosters: depois de um booster que boostou uma Allowed Field, espera 15 min pro próximo.
-- Se o boost caiu fora das Allowed Fields, o próximo pode ser usado na hora.
Boost.STAGGER = 15 * 60
Boost.staggerUntil = 0
function Boost.ready()
    if not Cfg.AutoBooster then return nil end
    if Cfg.StaggerBoosters and tick() < Boost.staggerUntil then return nil end
    for _, n in ipairs(Boost.names()) do
        local pp = Boost.prompts[n]
        if Cfg.Boosters[n] and tick() >= (Boost.nextTry[n] or 0) then
            local cd = Boost.cdLeft(n)
            if cd and cd > 0 then
                Boost.nextTry[n] = tick() + cd + 2
            else
                return n, pp
            end
        end
    end
    return nil
end
Boost.remoteFail = {}   -- booster -> hora em que usar de longe falhou (aí vai até ele por 10 min)
function Boost.use(n, pp)
    St.useTool = false
    local before = Boost.lastActivated and Boost.lastActivated.t or 0
    local cdBefore = Boost.lastCooldown and Boost.lastCooldown.t or 0
    local function answered()
        return (Boost.lastActivated and Boost.lastActivated.t > before) or (Boost.lastCooldown and Boost.lastCooldown.t > cdBefore)
    end
    -- igual ao jogo: Events.UseMachine:FireServer("RedFieldBooster")
    local function fire()
        local um = remote("UseMachine")
        if um then pcall(function() um:FireServer(Boost.machineKey(n)) end) end
        local t0 = tick()
        while tick() - t0 < 2.5 and not answered() do task.wait(0.1) end
        return answered()
    end
    -- 1º: de longe pelo remote, sem sair do lugar (igual quest e ticket converter)
    local remoteOk = false
    if tick() - (Boost.remoteFail[n] or 0) > 600 then
        act("Usando " .. n .. " de longe")
        remoteOk = fire()
        if remoteOk then
            Con.log("Info", "Booster " .. n .. ": usado de longe")
        else
            Boost.remoteFail[n] = tick()
            Con.log("Info", "Booster " .. n .. ": não respondeu de longe, indo até ele")
        end
    end
    if not remoteOk then
        -- fallback: vai até o booster
        if not pp or not pp.Parent then pcall(Boost.scan) pp = Boost.prompts[n] end
        local pos = (pp and Boost.pos(pp)) or (Boost.where and Boost.where[n])
        if not pos then
            Boost.nextTry[n] = tick() + 60
            Boost.status = n .. ": não achei no mapa (Debug → Copiar boosters)"
            return
        end
        act("Indo usar " .. n)
        Move.tween(Move.ground(pos + Vector3.new(0, 3, 0), 10, 30), nil, function() return Sched.check() end)
        if Sched.check() then return end
        task.wait(0.3)
        if not fire() and pp and fireproximityprompt then   -- plano B: o próprio prompt (E)
            pcall(fireproximityprompt, pp)
            local t0 = tick()
            while tick() - t0 < 2.5 and not answered() do task.wait(0.1) end
        end
    end
    if Boost.lastActivated and Boost.lastActivated.t > before then
        local f = Boost.lastActivated.field
        local mine = F.find(f)
        Boost.status = string.format("%s: boostou %s", n, f) .. ((mine and Cfg.BoostFields[mine]) and " (na sua lista: indo farmar)" or " (fora da lista)")
        if mine then Boost.origin[mine] = tick() end   -- boost que veio de booster (pode renovar com dado/glitter)
        Boost.nextTry[n] = tick() + BOOST_CD + 5
        if mine and Cfg.BoostFields[mine] then Boost.staggerUntil = tick() + Boost.STAGGER end
    elseif Boost.lastCooldown and Boost.lastCooldown.t > cdBefore then
        Boost.nextTry[n] = tick() + Boost.lastCooldown.secs + 5
        Boost.status = string.format("%s: em espera (%s)", n, U.fmtTime(Boost.lastCooldown.secs))
    else
        Boost.nextTry[n] = tick() + 3 * 60      -- não respondeu: tenta de novo em 3 min
        Boost.status = n .. " (" .. Boost.machineKey(n) .. "): sem resposta, tentando de novo em 3 min"
    end
end
function Boost.statusText()
    local parts = {}
    for f, d in pairs(Boost.details()) do
        local t = d.left and (" " .. U.fmtTime(d.left))
            or (Boost.seenAt[f] and (" (ativo há " .. U.fmtTime(tick() - Boost.seenAt[f]) .. ")") or "")
        table.insert(parts, U.fname(f) .. " x" .. d.stack .. t .. (Cfg.BoostFields[f] and " ★" or ""))
    end
    table.sort(parts)
    local cds = {}
    for _, n in ipairs(Boost.names()) do
        if Cfg.Boosters[n] then
            local left = (Boost.nextTry[n] or 0) - tick()
            table.insert(cds, n .. ": " .. (left > 0 and U.fmtTime(left) or "pronto"))
        end
    end
    return "Boosts ativos: " .. (#parts > 0 and table.concat(parts, ", ") or "nenhum")
        .. "\nBoosters: " .. (#cds > 0 and table.concat(cds, " | ") or "nenhum ligado")
        .. "\nÚltimo: " .. Boost.status
end

------------------------------------------------------------------
-- INVENTÁRIO (PlayerData.Inventory.<Item>: valor = quantidade,
--   atributos Name, Cooldown (ms), LastUse (ms)). Usar: Events.ItemUse:FireServer("<Item>")
------------------------------------------------------------------
local Inv = {}
function Inv.find(name)
    local f = PD:FindFirstChild("Inventory")
    if not f then return nil end
    local k = U.key(name)
    for _, c in ipairs(f:GetChildren()) do
        if U.key(c.Name) == k or U.key(c:GetAttribute("Name") or "") == k then return c end
    end
    for _, c in ipairs(f:GetChildren()) do   -- Enzyme / Enzymes
        local ck = U.key(c.Name)
        if #ck >= 3 and (ck:find(k, 1, true) or k:find(ck, 1, true)) then return c end
    end
    return nil
end
function Inv.count(name) local c = Inv.find(name) return c and c.Value or 0 end
function Inv.ready(name)
    local c = Inv.find(name)
    if not c or c.Value <= 0 then return false end
    local last = tonumber(c:GetAttribute("LastUse")) or 0
    local cd = tonumber(c:GetAttribute("Cooldown")) or 0
    return U.serverNow() * 1000 >= last + cd
end
function Inv.use(name)
    local c = Inv.find(name)
    local r = remote("ItemUse")
    if not (c and r) or not Inv.ready(name) then return false end
    -- o jogo manda o nome bonito ("Field Dice", "Glitter", "Matter")
    local arg = c:GetAttribute("Name")
    if type(arg) ~= "string" or arg == "" then arg = c.Name end
    pcall(function() r:FireServer(arg) end)
    return true
end

------------------------------------------------------------------
-- RENOVAR O BOOST com Glitter / Field Dice
-- Só quando o boost QUE VEIO DO BOOSTER está acabando (Min Time Left).
-- Glitter boosta a field onde você está (garantido); o dado cai numa field aleatória.
------------------------------------------------------------------
function Boost.renewTarget()
    if not Cfg.AutoBooster or not (Cfg.UseGlitter or Cfg.UseDice) then return nil end
    local det = Boost.details()
    -- boost que acabou: limpa o estado (senão a próxima renovação fica travada)
    for rf in pairs(Boost.renewing) do if not det[rf] then Boost.renewing[rf] = nil Boost.tries[rf] = 0 end end
    for of in pairs(Boost.origin) do if not det[of] then Boost.origin[of] = nil Boost.extended[of] = nil end end
    local f = Boost.field()
    if not f then return nil end
    local d = det[f]
    if not d or not d.left then return nil end
    if Cfg.RequireBooster and not Boost.origin[f] then return nil end
    -- "Estender só uma vez": já renovou esse boost (desde o último booster)? então para
    if Cfg.ExtendOnce and Boost.extended[f] and Boost.extended[f] == (Boost.origin[f] or 0) then
        Boost.renewing[f] = nil
        return nil
    end
    if d.left > Cfg.RenewTime and not Boost.renewing[f] then Boost.tries[f] = 0 return nil end
    -- renovando: continua até cair na field E chegar no x desejado
    if Boost.renewing[f] and d.left > Cfg.RenewTime and d.stack >= Cfg.WantedBoost then
        Boost.renewing[f] = nil
        Boost.tries[f] = 0
        return nil
    end
    local glitter = Cfg.UseGlitter and Inv.ready("Glitter")
    local dice = Cfg.UseDice and Inv.count("FieldDice") > 0 and (Boost.tries[f] or 0) < Cfg.MaxDicePerRenew
    if not (glitter or dice) then return nil end
    return f, d, glitter
end
function Boost.renew()
    local f, d, glitter = Boost.renewTarget()
    if not f then return end
    Boost.renewing[f] = true
    local before = Boost.lastActivated and Boost.lastActivated.t or 0
    if glitter then
        local hb = F.hb(f)
        local hrp = U.hrp()
        if hb and hrp and not F.inside(hb, hrp.Position) then
            act("Indo pra " .. U.fname(f) .. " usar Glitter")
            Move.tween(F.center(hb), nil, function() return Sched.check() end)
            if Sched.check() then return end
        end
        act("Glitter em " .. U.fname(f) .. string.format(" (faltavam %ds)", math.floor(d.left)))
        Inv.use("Glitter")
    else
        if not Inv.ready("FieldDice") then task.wait(0.3) return end
        Boost.tries[f] = (Boost.tries[f] or 0) + 1
        act(string.format("Field Dice %d/%d pra renovar %s", Boost.tries[f], Cfg.MaxDicePerRenew, U.fname(f)))
        Inv.use("FieldDice")
    end
    local t0 = tick()
    while tick() - t0 < 3 do
        if Boost.lastActivated and Boost.lastActivated.t > before then break end
        task.wait(0.1)
    end
    local la = Boost.lastActivated
    if la and la.t > before then
        local hit = F.find(la.field)
        Boost.status = (glitter and "Glitter" or "Field Dice") .. ": " .. la.field .. (hit == f and " (renovou!)" or "")
        if hit == f then
            Boost.extended[f] = Boost.origin[f] or 0
            if Cfg.ExtendOnce then Boost.renewing[f] = nil Boost.tries[f] = 0 end
        end
    end
end

------------------------------------------------------------------
-- AUTO MATERIALS: usa cada item a cada X (Matter só dentro de uma field)
------------------------------------------------------------------
local Mat = { last = {}, status = "-" }
Mat.LIST = {
    { name = "Red Extract", unit = 60, def = 10 },
    { name = "Blue Extract", unit = 60, def = 10 },
    { name = "Enzyme", unit = 60, def = 10 },
    { name = "Oil", unit = 60, def = 10 },
    { name = "Glue", unit = 60, def = 10 },
    { name = "Matter", unit = 1, def = 2, field = true },
}
function Mat.cfg(name)
    if type(Cfg.Mats) ~= "table" then Cfg.Mats = {} end
    local c = Cfg.Mats[name]
    if type(c) ~= "table" then c = {} Cfg.Mats[name] = c end
    if type(c.on) ~= "boolean" then c.on = false end
    if type(c.interval) ~= "number" then
        for _, m in ipairs(Mat.LIST) do if m.name == name then c.interval = m.def end end
        c.interval = c.interval or 10
    end
    return c
end
for _, m in ipairs(Mat.LIST) do Mat.cfg(m.name) end
task.spawn(function()
    while running() do
        task.wait(1)
        if Cfg.AutoMaterials and U.alive() then
            for _, m in ipairs(Mat.LIST) do
                local c = Mat.cfg(m.name)
                if c.on and tick() - (Mat.last[m.name] or -1e9) >= c.interval * m.unit and Inv.ready(m.name) then
                    local okHere = true
                    if m.field then
                        local hrp = U.hrp()
                        okHere = hrp ~= nil and F.of(hrp.Position) ~= nil and not Fight.active
                    end
                    if okHere and Inv.use(m.name) then
                        Mat.last[m.name] = tick()
                        Mat.status = m.name .. " usado " .. os.date("%H:%M:%S")
                    end
                end
            end
        end
    end
end)
function Mat.statusText()
    local t = {}
    for _, m in ipairs(Mat.LIST) do
        local c = Mat.cfg(m.name)
        local left = c.on and math.max(0, c.interval * m.unit - (tick() - (Mat.last[m.name] or -1e9))) or nil
        table.insert(t, string.format("%s: %d%s", m.name, Inv.count(m.name),
            c.on and (" | próximo " .. (left > 0 and U.fmtTime(left) or "agora")) or ""))
    end
    return table.concat(t, "\n") .. "\nÚltimo: " .. Mat.status
end

------------------------------------------------------------------
-- TICKET CONVERTERS (Workspace.Machines.InstantConverter1..3): gasta 1 Medal e converte a bolsa inteira.
--  * usar: Events.UseMachine:FireServer("InstantConverter1") perto da plataforma (prompt alcance 14)
--  * confirmação: NotificationSent "... Honey (From Instant Converter)"
--  * cooldown: 5 min, PlayerData.Cooldowns.InstantConverterN = hora do último uso (ms)
------------------------------------------------------------------
TConv = { status = "-", nextTry = {}, okT = 0 }
TConv.CD = 5 * 60
do
    local r = remote("NotificationSent")
    if r then conn(r.OnClientEvent:Connect(function(_, text)
        if type(text) == "string" and text:lower():find("instant converter", 1, true) then TConv.okT = tick() end
    end)) end
end
function TConv.list()
    local out = {}
    local m = workspace:FindFirstChild("Machines")
    if not m then return out end
    for _, c in ipairs(m:GetChildren()) do
        if c.Name:match("^InstantConverter%d*$") then
            local pp = c:FindFirstChildWhichIsA("ProximityPrompt", true)
            local part = pp and pp.Parent
            local pos = (part and part:IsA("BasePart") and part.Position) or (part and part:IsA("Attachment") and part.WorldPosition) or c:GetPivot().Position
            table.insert(out, { name = c.Name, pp = pp, pos = pos })
        end
    end
    return out
end
function TConv.cdLeft(name)
    local f = PD:FindFirstChild("Cooldowns")
    local v = f and f:FindFirstChild(name)
    local val = v and tonumber(v.Value)
    -- cooldown custom (mín. 5 min do jogo): espaça os usos pra gastar menos Medal
    local cd = math.max(TConv.CD, (tonumber(Cfg.ConverterCD) or 5) * 60)
    if val and val > 1e11 then return math.max(0, val / 1000 + cd - U.serverNow()) end
    return 0
end
-- converter pronto mais perto (com Medal)
function TConv.ready()
    if not Cfg.UseTicketConverters or Inv.count("Medal") < 1 then return nil end
    if Abyss.any() then return nil end   -- rift do Abyss já converte
    local hrp = U.hrp()
    if not hrp then return nil end
    local best, bd
    for _, c in ipairs(TConv.list()) do
        if TConv.cdLeft(c.name) <= 0 and tick() >= (TConv.nextTry[c.name] or 0) then
            local d = (c.pos - hrp.Position).Magnitude
            if not bd or d < bd then best, bd = c, d end
        end
    end
    return best
end
-- remoteOnly: só tenta de longe (Stop Everything ligado: não mexe o personagem)
function TConv.use(c, remoteOnly)
    if not remoteOnly then St.useTool = false end
    -- funciona DE LONGE (testado): dispara daqui e confere pelo Medal/notificação. Só viaja se não der.
    local um = remote("UseMachine")
    local medal0 = Inv.count("Medal")
    local t = tick()
    act("Usando " .. c.name .. " de longe")
    if um then pcall(function() um:FireServer(c.name) end) end
    while tick() - t < 2.5 and TConv.okT < t and Inv.count("Medal") >= medal0 do task.wait(0.1) end
    if TConv.okT >= t or Inv.count("Medal") < medal0 then
        TConv.status = c.name .. " usado de longe " .. os.date("%H:%M:%S") .. " | Medal: " .. Inv.count("Medal")
        TConv.nextTry[c.name] = tick() + math.max(TConv.CD, (tonumber(Cfg.ConverterCD) or 5) * 60) + 2
        return true
    end
    if remoteOnly then
        TConv.nextTry[c.name] = tick() + 30
        TConv.status = c.name .. ": não converteu de longe"
        return false
    end
    act("Indo pro " .. c.name)
    Move.tween(Move.ground(c.pos + Vector3.new(0, 3, 0), 10, 30), nil, function() return Sched.check() end)
    if Sched.check() then return false end
    task.wait(0.3)
    local t = tick()
    local um = remote("UseMachine")
    if um then pcall(function() um:FireServer(c.name) end) end
    while tick() - t < 2.5 and TConv.okT < t do task.wait(0.1) end
    if TConv.okT < t and c.pp and fireproximityprompt then   -- plano B: o prompt
        pcall(fireproximityprompt, c.pp)
        local t2 = tick()
        while tick() - t2 < 2.5 and TConv.okT < t do task.wait(0.1) end
    end
    if TConv.okT >= t then
        TConv.status = c.name .. " usado " .. os.date("%H:%M:%S") .. " | Medal: " .. Inv.count("Medal")
        TConv.nextTry[c.name] = tick() + math.max(TConv.CD, (tonumber(Cfg.ConverterCD) or 5) * 60) + 2
        return true
    end
    TConv.status = c.name .. ": não converteu, tento de novo em 1 min"
    TConv.nextTry[c.name] = tick() + 60
    return false
end
function TConv.statusText()
    local t = {}
    for _, c in ipairs(TConv.list()) do
        local l = TConv.cdLeft(c.name)
        table.insert(t, c.name:gsub("InstantConverter", "Converter ") .. ": " .. (l > 0 and U.fmtTime(l) or "pronto"))
    end
    return (#t > 0 and table.concat(t, " | ") or "Nenhum converter achado") .. "\nMedal: " .. Inv.count("Medal") .. " | " .. TConv.status
end

-- MICRO CONVERTER (item): Events.ItemUse:FireServer("Micro Converter") converte a bolsa na hora
-- cooldown do jogo: 3s (Inv.ready). Cooldown custom em minutos + quantos guardar no inventário.
local Micro = { status = "-", last = -1e9 }
function Micro.cdLeft()
    return math.max(0, (tonumber(Cfg.MicroCD) or 0) * 60 - (tick() - Micro.last))
end
function Micro.ready()
    if not Cfg.UseMicroConverters then return false end
    if Abyss.any() then return false end   -- rift do Abyss já converte
    if Inv.count("Micro Converter") <= math.max(0, math.floor(tonumber(Cfg.MicroKeep) or 0)) then return false end
    if Micro.cdLeft() > 0 then return false end
    return Inv.ready("Micro Converter")
end
function Micro.use()
    local before = U.pollen()
    if not Inv.use("Micro Converter") then Micro.status = "não consegui usar" return false end
    local t = tick()
    while tick() - t < 2.5 and U.pollen() > before * 0.5 do task.wait(0.1) end
    if U.pollen() <= before * 0.5 then
        Micro.last = tick()
        Micro.status = "usado " .. os.date("%H:%M:%S") .. " | restam " .. Inv.count("Micro Converter")
        return true
    end
    Micro.status = "usei mas a bolsa não esvaziou"
    return false
end
function Micro.statusText()
    local n, keep = Inv.count("Micro Converter"), math.floor(tonumber(Cfg.MicroKeep) or 0)
    local extra = ""
    if n <= keep then extra = " | guardando (limite " .. keep .. ")"
    elseif Micro.cdLeft() > 0 then extra = " | próximo em " .. U.fmtTime(Micro.cdLeft()) end
    return "Micro Converter: " .. n .. extra .. "\n" .. Micro.status
end

-- STOP EVERYTHING ligado: Ticket Converter (de longe) e Micro Converter continuam funcionando
task.spawn(function()
    while running() do
        task.wait(1)
        if Cfg.StopEverything and Cfg.AutoConvert and U.alive() and U.bagPct() * 100 >= Cfg.ConvertPercent then
            pcall(function()
                local c = TConv.ready()
                if c and TConv.use(c, true) then return end
                if Micro.ready() then Micro.use() end
            end)
        end
    end
end)

------------------------------------------------------------------
-- WEBHOOK (Discord)
------------------------------------------------------------------
Hook.queue, Hook.items, Hook.status = {}, {}, "parado"
Hook.req = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
function Hook.push(title, desc, color, fields, ping)
    if not Cfg.WebhookOn or Cfg.WebhookURL == "" then return end
    local content = nil
    if ping and Cfg.WebhookPing ~= "" then content = "<@" .. Cfg.WebhookPing .. ">" end
    table.insert(Hook.queue, {
        content = content,
        embeds = { {
            title = title, description = desc, color = color or 0x2F5AA0, fields = fields,
            footer = { text = "BSU v" .. VERSION .. " • " .. LP.Name },
            timestamp = DateTime.now():ToIsoDate(),
        } },
    })
end
-- url opcional: manda pra outro webhook (ex.: o dos gráficos)
function Hook.post(payload, url)
    url = (url and url ~= "") and url or Cfg.WebhookURL
    if not Hook.req then Hook.status = "executor sem função request" return false end
    if url == "" then Hook.status = "sem URL" return false end
    local ok, res = pcall(Hook.req, {
        Url = url, Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = Http:JSONEncode(payload),
    })
    if ok and type(res) == "table" and res.StatusCode and res.StatusCode >= 300 then
        Hook.status = "erro HTTP " .. tostring(res.StatusCode)
        return false
    end
    Hook.status = ok and ("enviado " .. os.date("%H:%M:%S")) or ("erro: " .. tostring(res))
    return ok
end
-- nome do item normalizado (Medals = Medal, Enzymes = Enzyme)
function Hook.itemName(n)
    n = tostring(n):gsub("^%s+", ""):gsub("%s+$", "")
    if #n > 3 and n:sub(-1) == "s" and n:sub(-2) ~= "ss" then n = n:sub(1, -2) end
    return n
end
-- categorias iguais ao Atlas
Hook.CATS = {
    { "Eggs",   function(k) return k:find("egg") or k:find("royaljelly") or k:find("starjelly") end },
    { "Treats", function(k)
        return k:find("treat") or k:find("berr") or k:find("pineapple") or k:find("strawberr")
            or k:find("sunflowerseed") or k:find("seed")
      end },
    { "Waxes",  function(k) return k:find("wax") end },
    { "Rares",  function(k)
        return k:find("extract") or k:find("enzyme") or k:find("oil") or k:find("glitter") or k:find("magicbean")
            or k:find("glue") or k:find("matter") or k:find("microconverter") or k:find("tropicaldrink")
      end },
}
-- itens da sessão: se o jogo manda o inventário (UpdateInventory), usa a diferença
-- (mostra negativo = gasto, igual ao Atlas); senão soma as notificações "+N item"
Hook.inv, Hook.invStart = {}, {}
function Hook.sessionItems()
    local out = {}
    if Hook.invFull then
        for k, v in pairs(Hook.inv) do
            local d = v - (Hook.invStart[k] or v)
            if d ~= 0 then out[k] = d end
        end
    else
        for k, v in pairs(Hook.items) do out[k] = v end
    end
    return out
end
-- últimas N linhas do console (bloco de código, cabe no limite do Discord)
function Hook.consoleText(n)
    local t = {}
    for _, l in ipairs(Con.tail(n)) do table.insert(t, #l > 110 and (l:sub(1, 107) .. "...") or l) end
    if #t == 0 then return "" end
    local body = table.concat(t, "\n"):gsub("`", "'")
    if #body > 1900 then body = body:sub(-1900) end
    return "\n\n__Console (últimas " .. #t .. ")__\n```\n" .. body .. "\n```"
end
function Hook.itemsText()
    local groups = {}
    for _, c in ipairs(Hook.CATS) do groups[c[1]] = {} end
    groups.Others = {}
    for name, v in pairs(Hook.sessionItems()) do
        local k = U.key(name)
        local cat = "Others"
        for _, c in ipairs(Hook.CATS) do if c[2](k) then cat = c[1] break end end
        table.insert(groups[cat], { name, v })
    end
    local parts = {}
    for _, cat in ipairs({ "Eggs", "Treats", "Waxes", "Rares", "Others" }) do
        local g = groups[cat]
        if #g > 0 then
            table.sort(g, function(x, y) return x[1] < y[1] end)
            local lines = { "**" .. cat .. ":**" }
            for _, it in ipairs(g) do table.insert(lines, it[1] .. ": " .. U.fmtNum(it[2])) end
            table.insert(parts, table.concat(lines, "\n"))
        end
    end
    local txt = #parts > 0 and table.concat(parts, "\n\n") or "nenhum item ainda"
    if #txt > 3900 then txt = txt:sub(1, 3900) .. "\n..." end
    return txt
end
function Hook.statsFields()
    local gained = U.honey() - St.startHoney
    local hours = math.max(tick() - St.startT, 1) / 3600
    return {
        { name = "Mel", value = U.short(U.honey()), inline = true },
        { name = "Ganho na sessão", value = U.short(gained), inline = true },
        { name = "Honey Per Hour", value = U.short(gained / hours), inline = true },
        { name = "Tempo", value = U.fmtTime(tick() - St.startT), inline = true },
        { name = "Pólen", value = string.format("%s / %s", U.short(U.pollen()), U.short(U.cap())), inline = true },
        { name = "Quests entregues", value = tostring(St.quests), inline = true },
        { name = "Mobs mortos", value = tostring(St.kills), inline = true },
        { name = "Tarefa", value = St.task .. (St.reason ~= "" and (" — " .. St.reason) or ""), inline = false },
    }
end
function Hook.stats() Hook.push("📊 Status", "__Itens na sessão__\n" .. Hook.itemsText(), 0x2F5AA0, Hook.statsFields()) end
function Hook.questDone(name, owner)
    if Cfg.WebhookQuests then Hook.push("✅ Quest entregue", string.format("**%s** (%s)", name, owner or "urso ?"), 0x3BA55C) end
end
function Hook.test()
    return Hook.post({ content = "Teste do BSU v" .. VERSION .. " (" .. LP.Name .. ")" })
end
task.spawn(function()   -- envia a fila (1 a cada 1.5s, respeita o limite do Discord)
    while running() do
        task.wait(1.5)
        local p = table.remove(Hook.queue, 1)
        if p then Hook.post(p) end
    end
end)
-- BUFF UPTIME: lê os buffs da tela a cada 10s (leve) e manda um gráfico da última hora pro webhook.
-- O gráfico é gerado pelo QuickChart (um POST por envio, fora do jogo).
local Uptime = { samples = {}, status = "-" }
Uptime.BUFFS = {
    { name = "Calmness",    color = "#b8b8c8" },
    { name = "Focus",       color = "#39d353" },
    { name = "Motivation",  color = "#c792ea" },
    { name = "Blue Boost",  color = "#4f8ef7" },
    { name = "Red Boost",   color = "#f25f5c" },
    { name = "White Boost", color = "#f0f0f0" },
    { name = "Bomb Combo",  color = "#cfcfcf" },
}
Uptime.icons = {}   -- [buff] = id da imagem (pro painel do BSU Stats)
function Uptime.read()
    local out = {}
    local folder = Boost.buffFolder()
    if not folder then return out end
    for _, b in ipairs(folder:GetChildren()) do
        for _, d in ipairs(Uptime.BUFFS) do
            if U.key(b.Name) == U.key(d.name) then
                local stack = 1
                local st = b:FindFirstChild("Stack")
                if st and st:IsA("TextLabel") then stack = tonumber(st.Text:match("x(%d+)")) or 1 end
                if not Uptime.icons[d.name] then
                    local img = (b:IsA("ImageLabel") or b:IsA("ImageButton")) and b.Image or nil
                    if not img or img == "" then
                        for _, c in ipairs(b:GetDescendants()) do
                            if (c:IsA("ImageLabel") or c:IsA("ImageButton")) and c.Image ~= "" and not c:FindFirstAncestor("Info") then img = c.Image break end
                        end
                    end
                    local id = img and tostring(img):match("%d+")
                    if id then Uptime.icons[d.name] = id end
                end
                local hd = b:FindFirstChild("Info") and b.Info:FindFirstChild("Header")
                if stack == 1 and hd and hd:IsA("TextLabel") then stack = tonumber(hd.Text:match("%(x(%d+)%)")) or 1 end
                out[d.name] = math.max(out[d.name] or 0, stack)
            end
        end
    end
    return out
end
-- o que o script está fazendo agora (pro relatório): gather / convert / other
Uptime.cats = { gather = 0, convert = 0, other = 0 }
-- gather = farmando DENTRO da field (viagem, sprout e o resto contam como other)
function Uptime.cat()
    local cur = Sched.cur and Sched.cur.name
    if cur == "Convert" then return "convert" end
    if cur ~= "Farm" then return "other" end
    local hrp = U.hrp()
    local f = hrp and F.of(hrp.Position)
    if not f then return "other" end
    if Sprout.looting() and f == Sprout.lootField then return "other" end
    if Sprout.cur and f == Sprout.field then return "other" end
    return "gather"
end
task.spawn(function()
    while running() do
        local ok, v = pcall(Uptime.read)
        local cat = Uptime.cat()
        Uptime.cats[cat] += 10
        local okP, pol, cap = pcall(function() return U.pollen(), U.cap() end)
        table.insert(Uptime.samples, { t = os.time(), v = ok and v or {}, honey = U.honey(), pollen = okP and pol or 0, cap = okP and cap or 0, cat = cat })
        while #Uptime.samples > 0 and os.time() - Uptime.samples[1].t > 3600 do table.remove(Uptime.samples, 1) end
        task.wait(10)
    end
end)
-- RELATÓRIO COMPLETO (BSU Stats no Render): manda a última hora pro servidor, que desenha o painel e posta no webhook
local Stats = { status = "-" }
function Stats.send()
    if not Hook.req then Stats.status = "executor sem request" return end
    local base = (Cfg.StatsURL or ""):gsub("/+$", "")
    if base == "" then Stats.status = "sem URL do servidor" return end
    if #Uptime.samples < 3 then Stats.status = "poucos dados ainda (espere 1 min)" return end
    Stats.status = "acordando o servidor..."
    -- o Render grátis dorme: um GET acorda (pode levar ~1 min)
    for _ = 1, 4 do
        local ok, r = pcall(Hook.req, { Url = base .. "/", Method = "GET" })
        if ok and type(r) == "table" and r.StatusCode == 200 then break end
        task.wait(15)
    end
    local samples, buffs = {}, {}
    for _, d in ipairs(Uptime.BUFFS) do table.insert(buffs, d.name) end
    for _, x in ipairs(Uptime.samples) do
        table.insert(samples, { t = x.t, honey = x.honey or 0, pollen = x.pollen or 0, cap = x.cap or 0, cat = x.cat or "other", buffs = x.v })
    end
    local body = {
        secret = Cfg.StatsSecret, webhook = (Cfg.GraphWebhookURL ~= "" and Cfg.GraphWebhookURL or Cfg.WebhookURL), player = LP.Name, version = VERSION, ping = Cfg.WebhookPing ~= "" and Cfg.WebhookPing or nil,
        buffs = buffs, samples = samples, icons = Uptime.icons,
        session = { honey = U.honey() - St.startHoney, time = tick() - St.startT, cats = Uptime.cats },
        stats = { kills = St.kills, quests = St.quests, hits = St.hits },
    }
    Stats.status = "enviando..."
    local ok, r = pcall(Hook.req, { Url = base .. "/report", Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = Http:JSONEncode(body) })
    if ok and type(r) == "table" and r.StatusCode == 200 then Stats.status = "enviado " .. os.date("%H:%M:%S")
    else Stats.status = "erro: " .. (ok and type(r) == "table" and (tostring(r.StatusCode) .. " " .. tostring(r.Body)) or tostring(r)) end
end

task.spawn(function()   -- status periódico
    local last = tick()
    while running() do
        task.wait(5)
        if Cfg.WebhookOn and tick() - last >= Cfg.WebhookInterval * 60 then
            last = tick()
            Hook.stats()
            if Cfg.StatsOn then task.spawn(Stats.send) end
        end
    end
end)
do  -- itens ganhos: NotificationSent("+2 Enzyme (From Spider)")
    local r = remote("NotificationSent")
    if r then
        conn(r.OnClientEvent:Connect(function(_, text)
            if type(text) ~= "string" then return end
            local n, item = text:match("^%+%s*([%d,]+)%s+(.-)%s*%(")
            if not n then n, item = text:match("^%+%s*([%d,]+)%s+(.+)$") end
            if not item then return end
            item = Hook.itemName(item)
            local k = U.key(item)
            if k == "" or k == "honey" or k == "pollen" then return end
            local cnt = tonumber((n:gsub(",", ""))) or 1
            Hook.items[item] = (Hook.items[item] or 0) + cnt
            if U.match(UNIQUE_ITEMS, item) and Cfg.WebhookItems then Hook.push("🎁 Item", text, 0xF1C40F, nil, false) end   -- sem menção
        end))
    end
    -- inventário completo (se o jogo mandar como tabela nome -> quantidade)
    local inv = remote("UpdateInventory")
    if inv then
        local function scan(t, depth)
            if type(t) ~= "table" or depth > 3 then return end
            for k, v in pairs(t) do
                if type(k) == "string" and type(v) == "number" then
                    local name = Hook.itemName(k)
                    Hook.inv[name] = v
                    if Hook.invStart[name] == nil then Hook.invStart[name] = v end
                elseif type(v) == "table" then
                    scan(v, depth + 1)
                end
            end
        end
        local function count(t, depth)
            if type(t) ~= "table" or depth > 3 then return 0 end
            local n = 0
            for k, v in pairs(t) do
                if type(k) == "string" and type(v) == "number" then n += 1 elseif type(v) == "table" then n += count(v, depth + 1) end
            end
            return n
        end
        conn(inv.OnClientEvent:Connect(function(...)
            for _, a in ipairs({ ... }) do
                -- só confia na diferença se já chegou um inventário completo (10+ itens)
                if not Hook.invFull and count(a, 0) >= 10 then
                    Hook.invFull = true
                    Hook.inv, Hook.invStart = {}, {}
                end
                pcall(scan, a, 0)
            end
        end))
    end
end
-- DESCONECTOU / KICK: manda na hora (sem fila, o jogo vai fechar)
do
    local sent = false
    local function onDisconnect(msg)
        if sent or not (Cfg.WebhookOn and Cfg.WebhookDisconnect) then return end
        sent = true
        local fields = Hook.statsFields()
        local content = Cfg.WebhookPing ~= "" and ("<@" .. Cfg.WebhookPing .. ">") or nil
        task.spawn(Hook.post, {
            content = content,
            embeds = { {
                title = "🔌 Desconectado", color = 0x992D22,
                description = (msg and msg ~= "" and ("**Motivo:** " .. msg .. "\n\n") or "")
                    .. "__Itens na sessão__\n" .. Hook.itemsText() .. Hook.consoleText(15),
                fields = fields,
                footer = { text = "BSU v" .. VERSION .. " • " .. LP.Name },
                timestamp = DateTime.now():ToIsoDate(),
            } },
        })
    end
    local GuiService = game:GetService("GuiService")
    pcall(function()
        conn(GuiService.ErrorMessageChanged:Connect(function(m) if m and m ~= "" then onDisconnect(m) end end))
    end)
    task.spawn(pcall, function()
        local overlay = game:GetService("CoreGui"):WaitForChild("RobloxPromptGui", 5)
        overlay = overlay and overlay:WaitForChild("promptOverlay", 5)
        if overlay then
            conn(overlay.ChildAdded:Connect(function(c)
                if c.Name == "ErrorPrompt" then
                    task.wait(0.3)
                    local txt = ""
                    pcall(function()
                        for _, d in ipairs(c:GetDescendants()) do
                            if d:IsA("TextLabel") and #d.Text > #txt then txt = d.Text end
                        end
                    end)
                    onDisconnect(txt)
                end
            end))
        end
    end)
    conn(Players.PlayerRemoving:Connect(function(p) if p == LP then onDisconnect("saiu do servidor") end end))
end

local function bindDeath(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if hum then
        conn(hum.Died:Connect(function()
            if Cfg.WebhookDeath then Hook.push("💀 Morreu", "Tarefa: " .. St.task .. " | " .. St.action, 0xE74C3C, nil, true) end
        end))
    end
end
if LP.Character then task.spawn(bindDeath, LP.Character) end
conn(LP.CharacterAdded:Connect(bindDeath))

------------------------------------------------------------------
-- WALKSPEED / ANTI-AFK
------------------------------------------------------------------
local DefaultWS = nil
conn(RunService.Heartbeat:Connect(function()
    local hum = U.hum()
    if not hum then return end
    -- durante a luta usa a velocidade normal do jogo (com WalkSpeed alto o mob ataca mais)
    if Cfg.WalkSpeedOn and not Fight.active then
        if not DefaultWS then DefaultWS = hum.WalkSpeed end
        if hum.WalkSpeed ~= Cfg.WalkSpeed then hum.WalkSpeed = Cfg.WalkSpeed end
    elseif DefaultWS then
        hum.WalkSpeed = DefaultWS
        DefaultWS = nil
    end
end))
conn(LP.CharacterAdded:Connect(function() DefaultWS = nil end))
conn(LP.Idled:Connect(function()
    if Cfg.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end))

------------------------------------------------------------------
-- AUTO SPRINKLER: Events.SetupSprinkler:FireServer(Vector3 no chão)
--  Basic / Star Saturator: 1 no centro | Silver (2) / Golden (3): linha reta centralizada
--  Diamond (4): quadrado em volta do centro
------------------------------------------------------------------
local Spr = { field = nil, status = "-" }
Spr.TYPES = {
    ["Basic Sprinkler"]    = { count = 1, radius = 7,  setup = 6, shape = "center" },
    ["Silver Soakers"]     = { count = 2, radius = 7,  setup = 5, shape = "line" },
    ["Golden Gushers"]     = { count = 3, radius = 8,  setup = 5, shape = "line" },
    ["Diamond Drenchers"]  = { count = 4, radius = 8,  setup = 4, shape = "square" },
    ["Star Saturator"]     = { count = 1, radius = 16, setup = 3, shape = "center" },
}
Spr.ORDER = { "Basic Sprinkler", "Silver Soakers", "Golden Gushers", "Diamond Drenchers", "Star Saturator" }
if not Spr.TYPES[Cfg.Sprinkler] then Cfg.Sprinkler = "Basic Sprinkler" end   -- config antiga ("Automático")
function Spr.current()
    if Spr.TYPES[Cfg.Sprinkler] then return Cfg.Sprinkler end
    return "Basic Sprinkler"
end
-- posições (no chão) conforme o tipo
function Spr.points(hb, name)
    local t = Spr.TYPES[name]
    local gap = t.radius * 2.3   -- distância entre os sprinklers
    local long = hb.Size.X >= hb.Size.Z   -- linha no eixo mais comprido do campo
    local offs = {}
    if t.shape == "center" then
        offs = { { 0, 0 } }
    elseif t.shape == "line" then
        for i = 1, t.count do
            local o = (i - (t.count + 1) / 2) * gap
            table.insert(offs, long and { o, 0 } or { 0, o })
        end
    else
        local h = gap / 2
        offs = { { -h, -h }, { h, -h }, { -h, h }, { h, h } }
    end
    local pts = {}
    local ex = F.extra(hb)
    for _, o in ipairs(offs) do
        if ex > 0 then   -- borda proibida (ex.: Rose): puxa pra dentro
            local hx, hz = hb.Size.X / 2 - ex, hb.Size.Z / 2 - ex
            o = { math.clamp(o[1], -hx, hx), math.clamp(o[2], -hz, hz) }
        end
        local w = F.toWorld(hb, o[1], o[2])
        local g = Move.ground(w, 6, 20)
        table.insert(pts, Vector3.new(w.X, g.Y - 3, w.Z))   -- Move.ground devolve chão + 3
    end
    return pts
end
function Spr.place(field, hb)
    local r = remote("SetupSprinkler")
    if not r then Spr.status = "remote SetupSprinkler não encontrado" Spr.field = field return end
    local name = Spr.current()
    local t = Spr.TYPES[name]
    for i, p in ipairs(Spr.points(hb, name)) do
        if Sched.check() then return end
        act(string.format("Colocando %s (%d/%d) em %s", name, i, t.count, U.fname(field)))
        -- fica perto do ponto enquanto coloca
        Move.walk(Vector3.new(p.X, F.groundY(hb), p.Z), { reach = 4 })
        pcall(function() r:FireServer(p) end)
        task.wait(0.3)   -- o setup é só o tempo pra começar a regar: não precisa esperar
    end
    Spr.field = field
    Spr.status = string.format("%s colocado em %s (%s)", name, U.fname(field), os.date("%H:%M:%S"))
end

------------------------------------------------------------------
-- MAGIC BEAN: planta 1 sprout na field escolhida, quebra, e depois de 10s de loot
-- planta a próxima, até chegar no número escolhido. Events.ItemUse:FireServer("Magic Bean")
------------------------------------------------------------------
local Bean = { planted = 0, status = "-", lastTry = 0 }
local function sproutIn(field)
    for _, s in ipairs(Sprout.list()) do
        if Sprout.alive(s) and Sprout.fieldOf(s) == field then return s end
    end
    return nil
end
function Bean.want()
    if not (Cfg.BeanOn and Cfg.AutoSprout) or Cfg.BeanField == "" then return nil end
    if Bean.planted >= Cfg.BeanCount then return nil end
    if U.bagPct() > 0.85 then return nil end   -- bolsa acima de 85%: não planta (converte antes)
    if not F.unlocked(Cfg.BeanField) then return nil end
    if tick() - Bean.lastTry < 5 then return nil end
    if Inv.count("Magic Bean") <= 0 or not Inv.ready("Magic Bean") then return nil end
    Sprout.update()
    if Sprout.cur then return nil end                       -- ainda quebrando uma
    if sproutIn(Cfg.BeanField) then return nil end           -- já tem sprout viva lá
    if Sprout.looting() and tick() - (Sprout.lootStart or 0) < (tonumber(Cfg.BeanDelay) or 10) then return nil end   -- espera X s de loot antes
    return string.format("plantar sprout %d/%d em %s", Bean.planted + 1, Cfg.BeanCount, U.fname(Cfg.BeanField))
end
-- plantando sprouts (sessão do Magic Bean): enquanto tiver sprout pra plantar/quebrar/lootear,
-- não sai pra matar mob, quest, booster etc. Só colmeia, conversão e token raro DENTRO da field.
function Bean.active()
    if not (Cfg.BeanOn and Cfg.AutoSprout) or Cfg.BeanField == "" then return false end
    if Bean.planted < Cfg.BeanCount and Inv.count("Magic Bean") > 0 then return true end
    if Sprout.looting() and Sprout.lootField == Cfg.BeanField then return true end
    if Sprout.cur and Sprout.field == Cfg.BeanField then return true end
    return false
end
Sched.beanActive = Bean.active
local BEAN_BLOCK = { Quest = true, Booster = true, Renew = true, QuestMob = true, Kill = true }
function Sched.blocked(t)
    if not Bean.active() then return false end
    if BEAN_BLOCK[t.name] then return true end
    if t.name == "Rare" then   -- raro só se for na field das sprouts
        local r = Rare.find()
        local hb = F.hb(Cfg.BeanField)
        return not (r and hb and F.inside(hb, r.pos, 5))
    end
    return false
end
function Bean.plant()
    local field = Cfg.BeanField
    local hb = F.hb(field)
    if not hb then Bean.status = "field não encontrada" Bean.lastTry = tick() return end
    local hrp = U.hrp()
    if not F.inside(hb, hrp.Position) then
        act("Indo plantar Magic Bean em " .. U.fname(field))
        Move.tween(F.center(hb), nil, function() return Sched.check() end)
        if Sched.check() then return end
        task.wait(0.3)
    end
    -- mob seu na field: mata antes de plantar (depois que a sprout nasce, o script só desvia)
    if Cfg.FieldMobDodge then
        task.wait(0.8)   -- tempo dos mobs nascerem quando você entra
        if #Fight.mobsIn(hb, 6) > 0 then
            Bean.status = "matando os mobs antes de plantar"
            local res = Fight.run(hb, "Mob antes de plantar")
            if res == "timeout" then Bean.lastTry = tick() end
            return   -- volta e planta na próxima passada
        end
    end
    Bean.lastTry = tick()
    act("Plantando Magic Bean")
    if not Inv.use("Magic Bean") then Bean.status = "não consegui usar o Magic Bean" return end
    local t0 = tick()
    while tick() - t0 < 5 and not sproutIn(field) do task.wait(0.2) end
    if sproutIn(field) then
        Sprout.planted[sproutIn(field)] = field   -- plantada por nós: farma sempre (qualquer raridade)
        Bean.planted += 1
        Sprout.lastCheck = 0   -- já vai atrás dela
        Bean.status = string.format("plantada %d/%d (%s)", Bean.planted, Cfg.BeanCount, os.date("%H:%M:%S"))
    else
        Bean.status = "usei o Magic Bean mas não vi a sprout nascer"
    end
end

------------------------------------------------------------------
-- FARM (um passo por vez; o agendador chama de novo)
------------------------------------------------------------------
local Farm = {}
function Farm.field()
    -- plantando sprouts: a sprout vem antes da field boostada
    if Sched.beanActive and Sched.beanActive() then
        local sf = Sprout.farmField()
        if sf and F.unlocked(sf) then return sf, "sprout em " .. U.fname(sf) .. " (plantando)" end
    end
    local bf, stack = Boost.field()
    if bf then return bf, string.format("field boost x%d em %s", stack, U.fname(bf)) end
    local sf = Sprout.farmField()
    if sf and F.unlocked(sf) then return sf, "sprout em " .. U.fname(sf) end
    local qf = Quest.field()
    if qf then return qf, "quest pede " .. U.fname(qf) end
    return Cfg.Field, "farm normal em " .. U.fname(Cfg.Field)
end
-- loot = loot da sprout: ignora marks, bolhas e tokens de habilidade
-- SPROUT COM MOB NO CAMPO: não entra em combate. Velocidade normal, farma/looteia
-- desviando do mob. Token de prioridade pode passar perto do mob; com menos de 50% de
-- vida evita 100% (nada perto do mob e foge se ele chegar perto).
Farm.AVOID_R = 14
function Farm.avoidCtx(mobs)
    local hum = U.hum()
    local low = hum and hum.MaxHealth > 0 and hum.Health / hum.MaxHealth < 0.5
    local ctx = { mobs = mobs, low = low }
    function ctx.dist(p)
        local d = math.huge
        for _, m in ipairs(ctx.mobs) do
            local mp = m.Parent and U.pos(m)
            if mp then d = math.min(d, U.fdist(p, mp)) end
        end
        return d
    end
    -- caminho de a até b passa perto do mob?
    function ctx.pathDist(a, b)
        local d = math.huge
        local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
        local len2 = ab:Dot(ab)
        for _, m in ipairs(ctx.mobs) do
            local mp = m.Parent and U.pos(m)
            if mp then
                local am = Vector3.new(mp.X - a.X, 0, mp.Z - a.Z)
                local t = len2 > 0 and math.clamp(am:Dot(ab) / len2, 0, 1) or 0
                d = math.min(d, (am - ab * t).Magnitude)
            end
        end
        return d
    end
    -- ponto pode? (prio = token de prioridade)
    function ctx.ok(p, prio)
        if prio and not ctx.low then return true end
        local hrp = U.hrp()
        local r = Farm.AVOID_R
        if ctx.dist(p) < r then return false end
        if hrp and ctx.pathDist(hrp.Position, p) < r * 0.6 then return false end
        return true
    end
    return ctx
end
-- token de prioridade = loot da sprout (itens), menos Treat e Honey token. Token de habilidade das abelhas não conta.
function Farm.isPrio(t)
    if Tok.isAbility(t) then return false end
    local n = U.key(t.Name)
    return not (n:find("honey", 1, true) or n:find("treat", 1, true))
end
-- ponto do campo mais longe dos mobs (sem ir longe demais de você)
function Farm.safePoint(hb, ctx)
    local hrp = U.hrp()
    local best, bs
    for i = -2, 2 do
        for j = -2, 2 do
            local p = (hb.CFrame * CFrame.new(i * hb.Size.X / 5.5, 0, j * hb.Size.Z / 5.5)).Position
            p = Vector3.new(p.X, hrp and hrp.Position.Y or p.Y, p.Z)
            local sc = math.min(ctx.dist(p), Farm.AVOID_R * 2.5) - (hrp and U.fdist(p, hrp.Position) * 0.05 or 0)
            if not bs or sc > bs then best, bs = p, sc end
        end
    end
    return best
end

function Farm.step(field, loot)
    -- loot da sprout: com a coleta remota os tokens são pegos sozinhos, então farma normal
    -- (marks, bolhas, flames, abyss). Sem coleta remota: só tokens, como antes.
    local skipFx = loot and not Remote.on()
    local hb = F.hb(field)
    if not hb then act("Campo não encontrado: " .. tostring(field)) task.wait(1) return end
    if not F.unlocked(field) then act(U.fname(field) .. " não está liberado (aba Campos)") task.wait(1) return end
    local hrp = U.hrp()
    if not F.inside(hb, hrp.Position) then
        act("Indo para " .. U.fname(field))
        Move.tween(F.center(hb), nil, function() return Sched.check() end)
        return
    end
    Grid.touch(field, hb, hrp.Position)
    -- sprinklers: coloca quando chega numa field nova (não no loot da sprout)
    if Cfg.AutoSprinkler and not loot and Spr.field ~= field then
        Spr.place(field, hb)
        return
    end
    -- mob no campo: luta/desvia até morrer (exceto farmando/looteando sprout: só desvia)
    local avoid
    if Cfg.FieldMobDodge and tick() > (Farm.mobSkip or 0) then
        local mobs = Fight.mobsIn(hb, 6)
        if #mobs > 0 then
            -- sprout: sem coleta remota só desvia (pra não largar os tokens); com coleta remota luta normal
            local sproutMode = (loot or (Sprout.cur ~= nil and Sprout.field == field)) and not Remote.on()
            if sproutMode then
                avoid = Farm.avoidCtx(mobs)
            else
                local res = Fight.run(hb, "Mob no campo")
                if res == "timeout" then Farm.mobSkip = tick() + 60 end   -- mob que não morre: ignora um tempo
                return
            end
        end
    end
    if avoid then
        -- vida baixa e mob perto: foge pro ponto mais seguro do campo
        if avoid.low and avoid.dist(hrp.Position) < Farm.AVOID_R then
            act("Sprout: fugindo do mob (vida < 50%)")
            local sp = Farm.safePoint(hb, avoid)
            if sp then Move.walk(sp, { reach = 3, timeout = 2.5 }) end
            return
        end
    end
    local function tryBubble()
        if skipFx or not Cfg.AutoBubbles or Remote.on() then return false end   -- remoto: bolhas estouram sem andar
        local b
        if avoid then
            for _, e in ipairs(Bub.inField(hb)) do
                if avoid.ok(e.pos, false) then b = e break end
            end
        else
            b = Bub.best(hb)
        end
        if not b then return false end
        Bub.pop(b)
        return true
    end
    local function tryToken()
        if not Cfg.AutoTokens or Remote.on() then return false end   -- remoto: tokens são pegos sem andar
        local t
        if avoid then
            t = Tok.inField(hb, function(tk, p) return avoid.ok(p, Farm.isPrio(tk)) end)[1]
        else
            t = Tok.best(hb)
        end
        if not t then return false end
        Tok.collect(t, hb, not loot)
        return true
    end
    -- FLAMES: Flame Heat abaixo do limite = flame antes dos tokens (menos os da lista de prioridade);
    -- acima = mesma prioridade das bolhas (passa por cima e segue)
    local function flameOk(e) return not avoid or avoid.ok(e.pos, false) end
    local function tryFlame(stay)
        if skipFx or not Cfg.FarmFlames then return false end
        local e = Flame.best(hb)
        if not e or not flameOk(e) then return false end
        Flame.go(e, stay, function()
            -- token da prioridade aparece: sai da flame e vai pegar (só sem a coleta remota)
            if Cfg.AutoTokens and not Remote.on() then
                local t = Tok.best(hb)
                if t and t.prio < 500 then return true end
            end
            return stay and Flame.heat() >= Cfg.FlameHeatMax   -- encheu: para de esperar em cima
        end)
        return true
    end
    local function tryPrioToken()
        if not Cfg.AutoTokens or Remote.on() then return false end
        local t = Tok.best(hb)
        if not t or t.prio >= 500 or (avoid and not avoid.ok(t.pos, true)) then return false end
        Tok.collect(t, hb, not loot)
        return true
    end
    -- ABYSS: rift seu na field = prioridade máxima. Fica dentro dele enquanto existir
    -- (converte a bolsa e deixa as bolhas Gold); dentro, estoura as bolhas Gold que estão no rift.
    if not skipFx then
        local ab = Abyss.best(hb)
        if ab and not (avoid and avoid.low and avoid.dist(ab.pos) < Farm.AVOID_R) then
            local a = ab.inst
            act(string.format("Abyss rift | bolsa %d%%", math.floor(U.bagPct() * 100)))
            if not Abyss.inside(ab, hrp.Position) then
                Move.walk(ab.pos, { reach = 2, stop = function() return not a.Parent end })
                return
            end
            -- bolha dentro do rift (Gold primeiro): estoura sem sair
            if Cfg.AutoBubbles and not Remote.on() then
                for _, e in ipairs(Bub.inField(hb)) do
                    if Abyss.inside(ab, e.pos) then Bub.pop(e) return end
                end
            end
            -- fica parado dentro do rift (a ferramenta continua coletando) até ele sumir ou outra tarefa chamar
            local hum = U.hum and U.hum()
            if hum then hum:MoveTo(hrp.Position) end
            local t0 = tick()
            while a.Parent and running() and tick() - t0 < 1 and not Sched.check() do task.wait(0.1) end
            return
        end
    end
    local lowHeat = Cfg.FarmFlames and not skipFx and Flame.heat() < Cfg.FlameHeatMax
    if lowHeat then
        if tryPrioToken() or tryFlame(true) then return end
    end
    if Cfg.BubblesFirst then
        if tryBubble() or (not lowHeat and tryFlame(false)) or tryToken() then return end
    else
        if tryToken() or tryBubble() or (not lowHeat and tryFlame(false)) then return end
    end
    local target
    if Cfg.StayInMarks and not skipFx then target = Mark.walkPoint(hb) end
    target = target or Grid.next(field, hb)
    if avoid and target and not avoid.ok(target, false) then target = Farm.safePoint(hb, avoid) or target end
    act((loot and "Loot da sprout em " or "Farmando em ") .. U.fname(field))
    Move.walk(target, {
        stop = function()
            if avoid then
                local hp = U.hrp()
                if avoid.low and hp and avoid.dist(hp.Position) < Farm.AVOID_R then return true end   -- mob chegou: foge
                if Cfg.AutoTokens and not Remote.on() and Tok.inField(hb, function(tk, p) return avoid.ok(p, Farm.isPrio(tk)) end)[1] then return true end
                if not skipFx and Cfg.AutoBubbles and not Remote.on() then
                    for _, e in ipairs(Bub.inField(hb)) do if avoid.ok(e.pos, false) then return true end end
                end
                return false
            end
            return (Cfg.AutoTokens and not Remote.on() and Tok.best(hb) ~= nil) or (not skipFx and Cfg.AutoBubbles and not Remote.on() and Bub.best(hb) ~= nil)
                or (not skipFx and Cfg.FarmFlames and Flame.best(hb) ~= nil)
                or (not skipFx and Abyss.best(hb) ~= nil)
        end,
        onTick = function(p) Grid.touch(field, hb, p) end,
    })
end

------------------------------------------------------------------
-- TAREFAS (ordem = prioridade). Para adicionar uma função nova:
-- { name, label, all = interrompe tudo | over = {tarefas que ela interrompe},
--   want = function() return "motivo" ou nil end, run = function() ... end }
------------------------------------------------------------------
-- ERROS: guarda o último, salva em BSU2_Errors.txt e pula a tarefa que errar 3x seguidas
local Err = { last = "-", count = {}, skip = {} }
function Err.log(where, msg)
    local line = os.date("%d/%m %H:%M:%S") .. " [" .. where .. "] " .. tostring(msg)
    Err.last = line
    Con.log("Error", "[" .. where .. "] " .. tostring(msg):match("^[^\n]*"))
    warn("[BSU] " .. line)
    pcall(function()
        if appendfile and isfile and isfile("BSU2_Errors.txt") then appendfile("BSU2_Errors.txt", line .. "\n")
        elseif writefile then
            local old = (isfile and readfile and isfile("BSU2_Errors.txt")) and readfile("BSU2_Errors.txt") or ""
            writefile("BSU2_Errors.txt", old .. line .. "\n")
        end
    end)
end
St.err = Err
local function anyMob(filter)
    return Mob.nearest(filter)
end
Tasks = {
    { name = "Hive", label = "Colmeia", all = true,
      want = function()
          if Hive.mine() then return nil end
          return Cfg.AutoClaimHive and "sem colmeia: pegando uma" or "sem colmeia (ligue Auto Claim)"
      end,
      run = function()
          if Cfg.AutoClaimHive then Hive.claim() end
          if not Hive.mine() then task.wait(3) end
      end },
    { name = "Rare", label = "Token raro", all = true,
      want = function()
          if Sched.cur and Sched.cur.name == "Convert" and not Cfg.RareDuringConvert then return nil end
          local r = Rare.find()
          -- raro no loot do mob que estamos pegando: o loot pega ele primeiro (prioridade máxima)
          -- (inclui o instante em que o mob morre: o raro cai junto, antes do script registrar a morte)
          if r and Fight.lootHb and F.inside(Fight.lootHb, r.pos, 10) then return nil end
          if r and Fight.curHb and F.inside(Fight.curHb, r.pos, 10) then return nil end
          return r and ("token raro: " .. r.inst.Name)
      end,
      run = function() local r = Rare.find() if r then Rare.grab(r) end end },
    { name = "Bean", label = "Magic Bean", over = { Farm = true, Convert = true, SproutLoot = true },
      want = function() return Bean.want() end,
      run = function() Bean.plant() end },
    { name = "SproutLoot", label = "Loot da sprout", over = { Farm = true, Convert = true },
      want = function()
          Sprout.update()
          if Sprout.looting() and F.unlocked(Sprout.lootField) then return "loot em " .. U.fname(Sprout.lootField) end
      end,
      run = function() Farm.step(Sprout.lootField, true) end },
    { name = "Quest", label = "Quests", over = { Farm = true },
      want = function() return Quest.want() end,
      run = function() Quest.run() end },
    { name = "Booster", label = "Field Booster", over = { Farm = true, QuestMob = true, Kill = true },
      want = function()
          if Sprout.looting() or not U.bagEmpty() then return nil end   -- vai depois de converter
          local n = Boost.ready()
          return n and ("usar " .. n)
      end,
      run = function() local n, pp = Boost.ready() if n then Boost.use(n, pp) end end },
    { name = "Renew", label = "Renovar boost", over = { Farm = true, QuestMob = true, Kill = true, Convert = true },
      want = function()
          local f, d, glitter = Boost.renewTarget()
          return f and string.format("boost de %s acabando (%ds): %s", U.fname(f), math.floor(d.left), glitter and "Glitter" or "Field Dice")
      end,
      run = function() Boost.renew() end },
    { name = "QuestMob", label = "Mob de quest", over = { Farm = true },
      want = function()
          if Sprout.looting() or not (Cfg.AutoQuest and Cfg.QuestMobs) then return nil end
          if Boost.field() then return nil end   -- field boost da sua lista ativo: farma lá primeiro
          if Cfg.KillOnlyAfterConvert and not U.bagEmpty() then return nil end
          local e, q = Quest.mobEntry()
          return e and string.format("quest \"%s\": %s em %s", q, e.mob, U.fname(e.field))
      end,
      run = function()
          local e = Quest.mobEntry()
          if e then Fight.clearField(e.field, "Quest: " .. e.mob) end
      end },
    { name = "Kill", label = "Auto Kill", over = { Farm = true },
      want = function()
          if not Cfg.AutoKill or Sprout.looting() then return nil end
          if Boost.field() then return nil end   -- field boost da sua lista ativo: farma lá primeiro
          if Cfg.KillOnlyAfterConvert and not U.bagEmpty() then return nil end
          local e = anyMob(function(x) return Cfg.KillMobs[x.mob] == true end)
          return e and ("matar " .. e.mob .. " em " .. U.fname(e.field))
      end,
      run = function()
          local e = anyMob(function(x) return Cfg.KillMobs[x.mob] == true end)
          if e then Fight.clearField(e.field, "Auto Kill: " .. e.mob) end
      end },
    { name = "Convert", label = "Convertendo", over = { Farm = true },
      want = function()
          if not Cfg.AutoConvert or Sprout.looting() then return nil end
          if Abyss.any() then return nil end   -- rift do Abyss converte a bolsa: fica nele
          local pct = U.bagPct() * 100
          if pct >= Cfg.ConvertPercent then return string.format("bolsa em %d%%", math.floor(pct)) end
      end,
      run = function()
          -- Ticket Converter pronto (e com Medal): converte na hora lá; senão, na colmeia
          local c = TConv.ready()
          if c and TConv.use(c) then return end
          if Micro.ready() and Micro.use() then return end
          if Sched.check() then return end
          Hive.convert()
      end },
    { name = "Farm", label = "Farm",
      want = function()
          if not Cfg.AutoFarm then return nil end
          local _, why = Farm.field()
          return why
      end,
      run = function() Farm.step(Farm.field(), false) end },
}

------------------------------------------------------------------
-- LOOP PRINCIPAL
------------------------------------------------------------------
task.spawn(function()
    while running() do
        local ok, err = pcall(function()
            if not U.alive() then
                St.task, St.reason = "Esperando", "personagem morto/carregando"
                Move.cancel()
                task.wait(1)
                return
            end
            if Cfg.StopEverything then
                Sched.cur = nil
                St.task, St.reason = "Pausado", "Stop Everything ligado (jogando na mão)"
                task.wait(0.3)
                return
            end
            local pick, why
            for _, t in ipairs(Tasks) do
                if (Err.skip[t.name] or 0) < tick() and not Sched.blocked(t) then
                    local okW, r = pcall(t.want)
                    if okW and r then pick, why = t, r break end
                end
            end
            if not pick then
                Sched.cur = nil
                St.task, St.reason = "Parado", "nada ligado"
                task.wait(0.3)
                return
            end
            Sched.cur, Sched.abort, Sched.t = pick, false, 0
            if Sched.lastPick ~= pick then
                Con.log("Info", "Doing " .. pick.label .. ": " .. tostring(why))
                Sched.lastPick, Sched.lastWhy = pick, why
            end
            St.task, St.reason = pick.label, why
            local okR, e = xpcall(pick.run, function(m) return tostring(m) .. "\n" .. debug.traceback() end)
            if okR then
                Err.count[pick.name] = 0
            else
                Err.log(pick.name, e)
                Err.count[pick.name] = (Err.count[pick.name] or 0) + 1
                if Err.count[pick.name] >= 3 then
                    Err.count[pick.name] = 0
                    Err.skip[pick.name] = tick() + 60
                    act("Tarefa " .. pick.label .. " deu erro 3x: pulando por 60s")
                end
                task.wait(1)
            end
        end)
        if not ok then Err.log("loop", err) act("Erro: " .. tostring(err)) task.wait(1) end
        Sched.abort = false
        Fight.curHb, Fight.lootHb, Fight.active = nil, nil, false   -- garante que não fica preso se der erro
        local hrp = U.hrp()
        if hrp and hrp.Anchored then hrp.Anchored = false end
        task.wait()
    end
end)

------------------------------------------------------------------
-- ABA HIVE: ovos, Royal Jelly e level das abelhas
--  * slot = "coluna,linha" (coluna 1-5 da esquerda, linha de baixo pra cima) = Cells."C3,6"
--  * chocar/RJ:  Events.UseItem:FireServer("Basic Egg" | "Royal Jelly", { "3,6" })
--    resposta:   GetRolled { abelha, item, desc, raridade, abelha antiga, slot, gifted }
--  * comprar:    Events.BuyItem:FireServer("Basic Egg", n)
--  * alimentar:  Events.FeedEvent:FireServer("3,6", "Treat") -> FeedEvent(quantos faltam pro level, quantos tem, ama?)
--                Events.UseItem:FireServer("Treat", { "3,6", n })
------------------------------------------------------------------
local Bees = { status = "-", rjStatus = "-", lvlStatus = "-", picking = false, rolled = nil, feedAns = nil }
Bees.RARITIES = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Exclusive", "Event" }
Bees.RJ_RARITIES = { "Rare", "Epic", "Legendary", "Mythic" }   -- o que o Royal Jelly pode dar
Bees.NO_RJ = { Exclusive = true, Event = true }                 -- nunca usa RJ nelas (não dá pra pegar de volta)
-- raridade por tipo (completa com o UpdateCollection/GetRolled)
Bees.rarity = {}
for r, list in pairs({
    Common = { "Basic Bee" },
    Rare = { "Joyful Bee", "Curious Bee", "Hasty Bee", "Brave Bee", "Observer Bee", "Willful Bee" },
    Epic = { "Honey Bee", "Explosive Bee", "Pop Bee", "Molten Bee", "Scared Bee", "Furious Bee", "Ice Bee", "Blow Bee", "Rough Bee" },
    Legendary = { "Calm Bee", "Blushy Bee", "Aquamarine Bee", "Shadow Bee", "Inspired Bee", "Devil Bee" },
    Mythic = { "Abyssal Bee", "Fractal Bee", "Plasma Bee" },
    Exclusive = { "Giroy Bee" }, Event = { "Laser Bee" },
}) do for _, n in ipairs(list) do Bees.rarity[U.key(n)] = r end end
Bees.lvCache = setmetatable({}, { __mode = "k" })   -- [modelo da abelha] = level (do GetBeeStats, quando a plaquinha não tem)
function Bees.rarityOf(name) return name and Bees.rarity[U.key(name)] or nil end
-- raridade desconhecida: pergunta pro jogo (GetBeeStats(abelha) -> { nome, level, raridade, ... })
local StatsR = remote("GetBeeStats")
Bees.statsAns = nil
if StatsR then conn(StatsR.OnClientEvent:Connect(function(t)
    if type(t) == "table" and t[1] and type(t[3]) == "string" then
        Bees.rarity[U.key(t[1])] = t[3]
        Bees.statsAns = { name = t[1], rarity = t[3], level = tonumber(t[2]), bond = tonumber(t[4]), max = tonumber(t[5]), t = tick() }
    end
end)) end
function Bees.askRarity(info)
    local r = Bees.rarityOf(info.name)
    if r or not (StatsR and info.bee) then return r end
    local t = tick()
    pcall(function() StatsR:FireServer(info.bee) end)
    while tick() - t < 2.5 and running() do
        local a = Bees.statsAns
        if a and a.t > t then break end
        task.wait(0.05)
    end
    return Bees.rarityOf(info.name)
end
-- level pelo servidor (GetBeeStats) quando a plaquinha da célula não mostra (células mais altas da colmeia)
function Bees.askLevel(info)
    if not (StatsR and info.bee) then return 0 end
    local t = tick()
    pcall(function() StatsR:FireServer(info.bee) end)
    while tick() - t < 2 and running() do
        local a = Bees.statsAns
        if a and a.t > t then
            if a.level then Bees.lvCache[info.bee] = a.level end
            return a.level or 0
        end
        task.wait(0.05)
    end
    return 0
end
-- lista inicial (completa sozinha com o UpdateCollection do jogo)
Bees.TYPES = { "Basic Bee", "Joyful Bee", "Curious Bee", "Hasty Bee", "Honey Bee", "Calm Bee", "Giroy Bee", "Blushy Bee",
    "Brave Bee", "Explosive Bee", "Aquamarine Bee", "Pop Bee", "Molten Bee", "Scared Bee", "Observer Bee", "Shadow Bee",
    "Inspired Bee", "Devil Bee", "Furious Bee", "Ice Bee", "Blow Bee", "Rough Bee", "Abyssal Bee", "Fractal Bee",
    "Plasma Bee", "Laser Bee", "Willful Bee", "Sleepy Bee", "Matter Bee", "Leader Bee", "Sticker Bee" }
local function prettyBee(n) return (tostring(n):gsub("(%l)(%u)", "%1 %2")) end   -- "CalmBee" -> "Calm Bee"
function Bees.addType(n)
    n = prettyBee(n)
    for _, t in ipairs(Bees.TYPES) do if U.key(t) == U.key(n) then return end end
    table.insert(Bees.TYPES, n)
    table.sort(Bees.TYPES)
end
table.sort(Bees.TYPES)

local UseItemR, BuyR, FeedR = remote("UseItem"), remote("BuyItem"), remote("FeedEvent")
do
    local r = remote("GetRolled")
    if r then conn(r.OnClientEvent:Connect(function(t)
        if type(t) ~= "table" then return end
        Bees.rolled = { bee = tostring(t[1] or ""), item = t[2], rarity = tostring(t[4] or ""), slot = tostring(t[6] or ""),
            gifted = t[7] == true, t = tick() }
        Bees.addType(Bees.rolled.bee)
        if Bees.rolled.rarity ~= "" then Bees.rarity[U.key(Bees.rolled.bee)] = Bees.rolled.rarity end
    end)) end
    local c = remote("UpdateCollection")
    if c then conn(c.OnClientEvent:Connect(function(t)
        if type(t) ~= "table" then return end
        for _, e in pairs(t) do
            if type(e) == "table" and e[1] then
                Bees.addType(e[1])
                if type(e[5]) == "string" then Bees.rarity[U.key(e[1])] = e[5] end
            end
        end
    end)) end
    if FeedR then conn(FeedR.OnClientEvent:Connect(function(need, have, loves)
        Bees.feedAns = { need = tonumber(need) or 0, have = tonumber(have) or 0, loves = loves == true, t = tick() }
    end)) end
end

-- slots da colmeia
function Bees.cells()
    local h = Hive.mine()
    return h and h:FindFirstChild("Cells")
end
function Bees.cellInfo(c)
    local bv = c:FindFirstChild("Bee")
    local bee = bv and bv.Value
    local lp = c:FindFirstChild("LevelPart")
    local lbl = lp and lp:FindFirstChildWhichIsA("TextLabel", true)
    local gc = c:FindFirstChild("GiftedCell")
    return {
        slot = c.Name:gsub("^C", ""), cell = c, bee = bee, name = bee and prettyBee(bee.Name) or nil,
        lvLabel = lbl ~= nil and tonumber((tostring(lbl.Text):match("(%d+)"))) ~= nil,
        level = (lbl and tonumber((tostring(lbl.Text):match("(%d+)")))) or (bee and Bees.lvCache[bee]) or 0, gifted = gc ~= nil and gc:IsA("BasePart") and gc.Transparency < 0.5,
        owned = c:FindFirstChild("Cell") ~= nil,   -- slot comprado (tem o modelo da célula)
    }
end
function Bees.slot(slot)
    local cs = Bees.cells()
    local c = cs and cs:FindFirstChild("C" .. tostring(slot))
    return c and Bees.cellInfo(c)
end
function Bees.list()
    local out = {}
    local cs = Bees.cells()
    if not cs then return out end
    for _, c in ipairs(cs:GetChildren()) do
        local i = Bees.cellInfo(c)
        if i.bee then table.insert(out, i) end
    end
    table.sort(out, function(a, b)
        local ax, ay = a.slot:match("(%d+),(%d+)")
        local bx, by = b.slot:match("(%d+),(%d+)")
        ax, ay, bx, by = tonumber(ax) or 0, tonumber(ay) or 0, tonumber(bx) or 0, tonumber(by) or 0
        if ax ~= bx then return ax < bx end
        return ay > by
    end)
    return out
end
function Bees.slotOptions()
    local t = {}
    for _, i in ipairs(Bees.list()) do table.insert(t, i.slot) end
    return t
end
function Bees.slotText(slot)
    if not slot or slot == "" then return "nenhum" end
    local i = Bees.slot(slot)
    if not i then return slot end
    return string.format("%s  %s Lv%d%s", slot, i.name or "vazio", i.level, i.gifted and " ★" or "")
end

-- Select Position: clica no botão e depois num slot da colmeia
conn(UIS.InputBegan:Connect(function(inp, gp)
    if not Bees.picking or inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local cam = workspace.CurrentCamera
    local m = UIS:GetMouseLocation()
    local ray = cam:ViewportPointToRay(m.X, m.Y)
    local cs = Bees.cells()
    if not cs then return end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { cs }
    local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
    local cur = hit and hit.Instance
    while cur and cur.Parent ~= cs do cur = cur.Parent end
    if cur then
        Bees.picking = false
        setCfg("HiveSlot", (cur.Name:gsub("^C", "")))
        Bees.status = "Slot escolhido: " .. Cfg.HiveSlot
    end
end))

-- espera o GetRolled desse slot (depois de chocar/RJ)
local function waitRoll(slot, since)
    local t0 = tick()
    while tick() - t0 < 4 and running() do
        local r = Bees.rolled
        if r and r.t > since and r.slot == slot then return r end
        task.wait(0.05)
    end
    return nil
end
-- item com nome EXATO no inventário (sem o "parecido" do Inv.find: um nome errado no UseItem dá kick)
local function invExact(name)
    local f = PD:FindFirstChild("Inventory")
    if not f then return nil end
    local k = U.key(name)
    for _, c in ipairs(f:GetChildren()) do
        if c:IsA("ValueBase") and (U.key(c.Name) == k or U.key(c:GetAttribute("Name") or "") == k) then return c end
    end
    return nil
end
local function invHave(name) local c = invExact(name) return c and tonumber(c.Value) or 0 end
local function useOn(item, slot, n)
    if not UseItemR then return false end
    -- só dispara se o item existe de verdade e tem quantidade
    if invHave(item) < (n or 1) then Con.log("Info", "Hive: sem " .. item .. " no inventário, não usei") return false end
    local si = Bees.slot(slot)
    if not (si and si.owned) then Con.log("Info", "Hive: slot " .. tostring(slot) .. " não existe/não comprado, não usei") return false end
    -- espera o inventário sincronizar entre um uso e outro (usar um egg que o servidor já gastou = kick)
    Bees.useT = Bees.useT or {}
    local gap = tick() - (Bees.useT[item] or 0)
    if gap < 1.2 then task.wait(1.2 - gap) end
    local before = invHave(item)
    if before < (n or 1) then return false end
    local args = n and { slot, n } or { slot }
    local ok = pcall(function() UseItemR:FireServer(item, args) end)
    Bees.useT[item] = tick()
    local t0 = tick()
    while tick() - t0 < 4 and invHave(item) >= before do task.wait(0.05) end
    if invHave(item) >= before then
        Con.log("Info", "Hive: usei " .. item .. " no " .. tostring(slot) .. " mas o inventário não mudou (" .. before .. ")")
        task.wait(2)
    end
    return ok
end

-- AUTO GIFTED BASIC BEE: choca Basic Egg no slot até vir uma Basic Bee gifted
function Bees.giftedStep()
    local slot = Cfg.HiveSlot
    local info = slot ~= "" and Bees.slot(slot)
    if not info then Bees.status = "Escolha o slot (Select Position)" return end
    if not info.owned then Bees.status = "Slot " .. slot .. " não comprado: desliguei" setCfg("AutoGiftedBasic", false) return end
    if info.gifted and U.key(info.name or "") == "basicbee" then
        Bees.status = "Pronto: Basic Bee gifted no " .. slot
        setCfg("AutoGiftedBasic", false)
        return
    end
    -- contador próprio: o número do inventário pode ficar atrasado/travado, então conta cada choco confirmado
    if tick() - (Bees.eggSeen or 0) > 30 then Bees.eggLeft = nil end
    Bees.eggSeen = tick()
    local eggs = invHave("Basic Egg")
    if Bees.eggLeft then eggs = math.min(eggs, Bees.eggLeft) else Bees.eggLeft = eggs end
    if eggs <= 0 then
        if Cfg.BuyBasicEggs and BuyR then
            local before = invHave("Basic Egg")
            local amt = math.max(1, math.floor(Cfg.EggBuyAmount))
            -- guarda o que o jogo responder (pra saber por que não comprou)
            local note
            local nr = remote("NotificationSent")
            local nc = nr and nr.OnClientEvent:Connect(function(...)
                for _, v in ipairs({ ... }) do if type(v) == "string" and v ~= "" then note = v end end
            end)
            pcall(function() BuyR:FireServer("Basic Egg", amt) end)
            Bees.status = "Comprando " .. amt .. " Basic Egg"
            Con.log("Info", "Hive: BuyItem(\"Basic Egg\", " .. amt .. ")")
            local t0 = tick()
            while tick() - t0 < 5 and invHave("Basic Egg") <= before do task.wait(0.1) end
            if nc then nc:Disconnect() end
            if invHave("Basic Egg") <= before then
                Bees.status = "Não consegui comprar Basic Egg: desliguei" .. (note and (" (jogo: " .. note .. ")") or "")
                Con.log("Info", "Hive: compra falhou" .. (note and (": " .. note) or " (sem resposta do jogo)"))
                setCfg("AutoGiftedBasic", false)
            else
                Bees.eggLeft = invHave("Basic Egg") - before
                Con.log("Info", "Hive: comprou " .. Bees.eggLeft .. " Basic Egg")
                task.wait(1)   -- deixa o servidor terminar a compra antes de chocar
            end
        else
            Bees.status = "Acabou o Basic Egg: desliguei"
            setCfg("AutoGiftedBasic", false)
        end
        return
    end
    local t = tick()
    if not useOn("Basic Egg", slot) then Bees.status = "Não achei o Basic Egg certo no inventário: desliguei" setCfg("AutoGiftedBasic", false) return end
    local r = waitRoll(slot, t)
    if r then
        Bees.eggLeft = math.max(0, (Bees.eggLeft or 1) - 1)
        Bees.status = string.format("Chocou %s%s no %s | eggs: %d", r.bee, r.gifted and " (GIFTED)" or "", slot, Bees.eggLeft)
        if r.gifted and U.key(r.bee) == "basicbee" then
            setCfg("AutoGiftedBasic", false)
            Bees.status = "Pronto: Basic Bee gifted no " .. slot
            if Hook and Hook.post and Cfg.WebhookOn then Hook.post({ content = "🐝 Basic Bee **gifted** no slot " .. slot }) end
        end
    else
        -- sem resposta = não chocou (acabou o egg?): NUNCA tenta de novo, desliga
        Bees.eggLeft = 0
        Bees.status = "O jogo não respondeu ao egg (acabou?): desliguei"
        Con.log("Info", "Hive: egg sem resposta, desliguei o Auto Gifted Basic")
        setCfg("AutoGiftedBasic", false)
    end
    task.wait(0.4)
end

-- AUTO ROYAL JELLY: usa RJ no slot até vir o tipo/raridade/gifted escolhido
function Bees.rjWanted(r)
    if Cfg.RJStopGifted and r.gifted then return true end
    if Cfg.RJBeeTypes[prettyBee(r.bee)] or Cfg.RJBeeTypes[r.bee] then return true end
    for k, on in pairs(Cfg.RJBeeTypes) do if on and U.key(k) == U.key(r.bee) then return true end end
    if Cfg.RJStopRarity[r.rarity] then return true end
    return false
end
-- tipos que o RJ pode dar (sem Common/Exclusive/Event)
function Bees.rjTypes()
    local t = {}
    for _, n in ipairs(Bees.TYPES) do
        local r = Bees.rarityOf(n)
        if not r or table.find(Bees.RJ_RARITIES, r) then table.insert(t, n) end
    end
    return t
end
function Bees.rjHasTarget()
    return Cfg.RJStopGifted or next(Cfg.RJBeeTypes) ~= nil or next(Cfg.RJStopRarity) ~= nil
end
function Bees.rjStep()
    local slot = Cfg.HiveSlot
    local info = slot ~= "" and Bees.slot(slot)
    if not info or not info.bee then Bees.rjStatus = "Escolha um slot com abelha (Select Position)" return end
    if not Bees.rjHasTarget() then Bees.rjStatus = "Escolha Bee Types, raridade ou Stop On Any Gifted" setCfg("AutoRJ", false) return end
    -- abelha atual: Exclusive/Event nunca recebe RJ; se já é o que procura, não gasta
    local curR = Bees.askRarity(info)
    if curR and Bees.NO_RJ[curR] then
        Bees.rjStatus = string.format("%s é %s: não uso Royal Jelly nela (escolha outro slot)", info.name, curR)
        setCfg("AutoRJ", false)
        return
    end
    if Bees.rjWanted({ bee = info.name or "", rarity = curR or "", gifted = info.gifted }) then
        Bees.rjStatus = string.format("%s (%s)%s já é o que você procura: não usei RJ", info.name, curR or "?", info.gifted and " GIFTED" or "")
        setCfg("AutoRJ", false)
        return
    end
    if invHave("Royal Jelly") <= 0 then Bees.rjStatus = "Acabou o Royal Jelly" setCfg("AutoRJ", false) return end
    local t = tick()
    if not useOn("Royal Jelly", slot) then Bees.rjStatus = "Não achei o Royal Jelly no inventário: desliguei" setCfg("AutoRJ", false) return end
    local r = waitRoll(slot, t)
    if r then
        Bees.rjStatus = string.format("%s → %s (%s)%s | RJ: %d", slot, r.bee, r.rarity, r.gifted and " GIFTED" or "", invHave("Royal Jelly"))
        if Bees.rjWanted(r) then
            setCfg("AutoRJ", false)
            Bees.rjStatus = "Parou: " .. r.bee .. " (" .. r.rarity .. ")" .. (r.gifted and " GIFTED" or "") .. " no " .. slot
            if Hook and Hook.post and Cfg.WebhookOn then
                Hook.post({ content = string.format("👑 Royal Jelly: **%s** (%s)%s no slot %s", r.bee, r.rarity, r.gifted and " GIFTED" or "", slot) })
            end
        end
    else
        Bees.rjStatus = "O jogo não respondeu ao Royal Jelly (acabou?): desliguei"
        Con.log("Info", "Hive: RJ sem resposta, desliguei o Auto RJ")
        setCfg("AutoRJ", false)
    end
    task.wait(0.4)
end

-- AUTO LEVEL UP HIVE: dá Treat pras abelhas abaixo do Target Level (menor level primeiro)
function Bees.below(noAsk)
    local t = {}
    local all, noLv = Bees.list(), 0
    for _, i in ipairs(all) do
        if not i.lvLabel and not noAsk then   -- sem plaquinha: pergunta pro servidor (sempre atualizado)
            local lv = Bees.askLevel(i)
            if lv > 0 then i.level = lv end
        end
        if i.level <= 0 then noLv += 1 end
        if i.level > 0 and i.level < Cfg.TargetLevel then table.insert(t, i) end
    end
    if not noAsk and tick() - (Bees.belowLogT or 0) > 60 then
        Bees.belowLogT = tick()
        local cs = Bees.cells()
        Con.log("Info", string.format("Hive: %d células, %d com abelha, %d sem level, %d abaixo do %d",
            cs and #cs:GetChildren() or 0, #all, noLv, #t, Cfg.TargetLevel))
    end
    table.sort(t, function(a, b) return a.level < b.level end)
    return t
end
local function askFeed(slot)
    if not FeedR then return nil end
    local t = tick()
    pcall(function() FeedR:FireServer(slot, "Treat") end)
    while tick() - t < 3 and running() do
        local a = Bees.feedAns
        if a and a.t > t then return a end
        task.wait(0.05)
    end
    return nil
end
Bees.LVL_PRIO = { Exclusive = 7, Event = 6, Mythic = 5, Legendary = 4, Epic = 3, Rare = 2, Common = 1 }
function Bees.levelStep()
    local list = Bees.below()
    if #list == 0 then
        Bees.lvlStatus = "Pronto: todas as abelhas no level " .. Cfg.TargetLevel .. "+"
        setCfg("AutoLevelHive", false)
        return
    end
    local treats = invHave("Treat")
    if treats <= 0 then
        Bees.lvlStatus = string.format("Acabou o Treat (faltam %d abelha(s) pro level %d)", #list, Cfg.TargetLevel)
        setCfg("AutoLevelHive", false)
        return
    end
    -- prioridade: Exclusive > Event > Mythic > Legendary > Epic > Rare > Common; mesma raridade: menor level
    for _, x in ipairs(list) do if not Bees.rarityOf(x.name) then Bees.askRarity(x) end end
    table.sort(list, function(x, y)
        local rx, ry = Bees.LVL_PRIO[Bees.rarityOf(x.name) or ""] or 0, Bees.LVL_PRIO[Bees.rarityOf(y.name) or ""] or 0
        if rx ~= ry then return rx > ry end
        return x.level < y.level
    end)
    local b = list[1]
    local a = askFeed(b.slot)
    if not a then Bees.lvlStatus = "Sem resposta do FeedEvent" task.wait(2) return end
    local n = math.min(a.need, treats)
    if n <= 0 then task.wait(1) return end
    useOn("Treat", b.slot, n)
    Bees.lvlStatus = string.format("%s %s (%s) Lv%d: %d Treat%s | faltam %d abelhas | Treat: %d",
        b.slot, b.name or "?", Bees.rarityOf(b.name) or "?", b.level, n, n < a.need and " (faltou Treat)" or "", #list, treats - n)
    task.wait(1.2)
end
-- quantos Treats faltam: o bond é ACUMULADO (Lvl 6 = 4000/15000 -> o 15000 é o total pra chegar no Lvl 7).
-- GetBeeStats(abelha) -> { nome, level, raridade, bond, bond do próximo level, ... }.
-- Guarda o total de cada level (aprende com as abelhas e salva) e calcula até o Target Level. Treat = 10 de bond.
Bees.bondLvl = readJSON("BSU2_BondLevels.json") or {}   -- ["6"] = 15000 (bond total pra sair do 6 pro 7)
Bees.calc = { busy = false, total = nil, unknown = 0, t = 0, target = nil }
local function askStats(bee)
    if not (StatsR and bee) then return nil end
    local t = tick()
    pcall(function() StatsR:FireServer(bee) end)
    while tick() - t < 2.5 and running() do
        local a = Bees.statsAns
        if a and a.t > t then return a end
        task.wait(0.05)
    end
    return nil
end
if StatsR then conn(StatsR.OnClientEvent:Connect(function(t)
    if type(t) == "table" then
        local lv, mx = tonumber(t[2]), tonumber(t[5])
        if lv and mx and mx > 0 and Bees.bondLvl[tostring(lv)] ~= mx then
            Bees.bondLvl[tostring(lv)] = mx
            writeJSON("BSU2_BondLevels.json", Bees.bondLvl)
        end
    end
end)) end
function Bees.calcTreats()
    if Bees.calc.busy then return end
    Bees.calc.busy = true
    task.spawn(function()
        local list, stats = Bees.below(), {}
        for _, b in ipairs(list) do
            if not running() then break end
            stats[b.slot] = askStats(b.bee)
            task.wait(0.1)
        end
        local total, unknown = 0, 0
        local goal = Bees.bondLvl[tostring(Cfg.TargetLevel - 1)]   -- bond total pra chegar no Target Level
        for _, b in ipairs(list) do
            local st = stats[b.slot]
            if st and st.bond then
                local need = goal or (Cfg.TargetLevel - (st.level or b.level) == 1 and st.max) or nil
                if need then total += math.max(0, math.ceil((need - st.bond) / 10))
                else
                    unknown += 1
                    total += math.max(0, math.ceil(((st.max or st.bond) - st.bond) / 10))   -- pelo menos o próximo level
                end
            end
        end
        Bees.calc.total, Bees.calc.unknown, Bees.calc.t, Bees.calc.target = total, unknown, tick(), Cfg.TargetLevel
        Bees.calc.busy = false
    end)
end
function Bees.levelInfo()
    local list = Bees.below(true)
    local txt = string.format("Abaixo do level %d: %d abelha(s) | Treat: %d", Cfg.TargetLevel, #list, invHave("Treat"))
    local c = Bees.calc
    if c.busy then
        txt ..= "\nCalculando Treats necessários..."
    elseif c.total and c.target == Cfg.TargetLevel then
        local have = invHave("Treat")
        txt ..= string.format("\nTreats necessários: %d%s %s", c.total, c.unknown > 0 and "+" or "",
            have >= c.total and "(dá)" or string.format("(faltam %d)", c.total - have))
        if c.unknown > 0 then
            txt ..= string.format("\n%d abelha(s): ainda não sei o bond do level %d (aprende quando alguma abelha chegar no level %d)",
                c.unknown, Cfg.TargetLevel - 1, Cfg.TargetLevel - 1)
        end
    else
        txt ..= "\nTreats necessários: clique em Calcular"
    end
    return txt
end

-- FEED UNTIL GIFTED: descobre a comida que a abelha ama (FeedEvent responde "ama?"),
-- guarda por tipo de abelha e dá N dessa comida repetidamente até virar gifted / limite / acabar.
Bees.FOODS = { "Blueberry", "Strawberry", "Pineapple", "Sunflower Seed" }   -- completa com o UpdateInventory
Bees.fav = {}    -- [tipo de abelha] = comida favorita (só enquanto o Feed Until Gifted está ligado: testa toda vez)
Bees.feedStatus, Bees.fed, Bees.giftNote = "-", 0, 0
function Bees.addFood(n)
    n = tostring(n)
    if n == "" or U.key(n) == "treat" then return end
    for _, f in ipairs(Bees.FOODS) do if U.key(f) == U.key(n) then return end end
    table.insert(Bees.FOODS, n)
end
do
    local inv = remote("UpdateInventory")
    if inv then conn(inv.OnClientEvent:Connect(function(txt)
        if type(txt) ~= "string" then return end
        local name, desc = txt:match("^%d+|([^\255]+)\255([^\255]*)")
        if name and desc and desc:lower():find("bond", 1, true) then Bees.addFood(name) end
    end)) end
    local nt = remote("NotificationSent")
    if nt then conn(nt.OnClientEvent:Connect(function(_, txt)
        if type(txt) == "string" and txt:lower():find("gifted", 1, true) then Bees.giftNote = tick() end
    end)) end
end
-- pergunta pro jogo se a abelha do slot ama essa comida (não gasta)
local function askFood(slot, food)
    if not FeedR then return nil end
    local t = tick()
    pcall(function() FeedR:FireServer(slot, food) end)
    while tick() - t < 2.5 and running() do
        local a = Bees.feedAns
        if a and a.t > t then return a end
        task.wait(0.05)
    end
    return nil
end
function Bees.findFav(info)
    local key = info.name or ""
    if Bees.fav[key] then return Bees.fav[key] end
    for _, food in ipairs(Bees.FOODS) do
        Bees.feedStatus = "Testando " .. food .. " na " .. key
        local a = askFood(info.slot, food)
        if a and a.loves then
            Bees.fav[key] = food
            return food
        end
        task.wait(0.2)
    end
    return nil
end
function Bees.feedStep()
    local slot = Cfg.HiveSlot
    local info = slot ~= "" and Bees.slot(slot)
    local function stop(msg) Bees.feedStatus = msg setCfg("FeedGifted", false) Bees.fed = 0 end
    if not info or not info.bee then return stop("Escolha um slot com abelha (Select Position)") end
    if info.gifted then return stop("Pronto: " .. (info.name or "abelha") .. " já é gifted (" .. slot .. ")") end
    local food = Bees.findFav(info)
    if not food then return stop((info.name or "A abelha") .. " não gosta de nada") end
    local limit = math.max(1, math.floor(Cfg.FeedLimit))
    if Bees.fed >= limit then return stop(string.format("Limite atingido: %d %s sem gifted", Bees.fed, food)) end
    local have = invHave(food)
    if have <= 0 then return stop("Acabou " .. food .. " (" .. Bees.fed .. " dados)") end
    local n = math.min(math.max(1, math.floor(Cfg.FeedAmount)), limit - Bees.fed, have)
    local t = tick()
    useOn(food, slot, n)
    Bees.fed += n
    Bees.feedStatus = string.format("%s: %d %s (%d/%d) | sobrou %d", info.name or "?", n, food, Bees.fed, limit, have - n)
    -- espera a moldura/notificação de gifted
    while tick() - t < 1.5 and running() do
        local now = Bees.slot(slot)
        if (now and now.gifted) or Bees.giftNote > t then
            Bees.feedStatus = "GIFTED! " .. (info.name or "abelha") .. " no " .. slot .. " com " .. Bees.fed .. " " .. food
            if Hook and Hook.post and Cfg.WebhookOn then
                Hook.post({ content = string.format("🎁 **%s** virou gifted com %d %s (slot %s)", info.name or "Abelha", Bees.fed, food, slot) })
            end
            setCfg("FeedGifted", false)
            Bees.fed = 0
            return
        end
        task.wait(0.1)
    end
end
function Bees.favText()
    local info = Cfg.HiveSlot ~= "" and Bees.slot(Cfg.HiveSlot)
    if not info or not info.name then return "Favorita: -" end
    return "Favorita da " .. info.name .. ": " .. (Bees.fav[info.name] or "testa ao ligar")
end
onCfg("FeedGifted", function(v) if v then Bees.fed = 0 Bees.fav = {} end end)

-- FEED BEES FOR QUESTS: objetivos "Feed 500 Treat to your Bees. 0/500" das quests que o script faz.
-- Dá o item que falta pra abelha de menor level (sem ir pra colmeia, junto com o farm).
-- "Raise N Bees to Level X" é ignorado (fica manual).
Bees.questStatus = "-"
function Bees.questFeeds()
    local out = {}
    for n, q in pairs(Quest.read()) do
        local owner = Quest.owner[n]
        if not q.complete and owner and Quest.doing(owner) then
            for _, o in ipairs(q.objs) do
                if not o.done then
                    local item = o.text:match("[Ff]eed%s+[%d,]+%s+(.-)%s+to%s+[Yy]our")
                    local a, b = o.text:match("([%d,]+)%s*/%s*([%d,]+)%s*$")
                    if item and a and b then
                        local left = (tonumber((b:gsub(",", ""))) or 0) - (tonumber((a:gsub(",", ""))) or 0)
                        if left > 0 then table.insert(out, { item = item, left = left, quest = n }) end
                    end
                end
            end
        end
    end
    return out
end
local function invItem(name)
    if Inv.find(name) then return name end
    local alt = name:gsub("ies$", "y"):gsub("s$", "")   -- "Blueberries" -> "Blueberry", "Seeds" -> "Seed"
    if Inv.find(alt) then return alt end
    return nil
end
-- fruta: vai pra abelha de raridade mais alta que AMA essa fruta (Treat: abelha de menor level)
Bees.RANK = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5 }
Bees.loves = {}   -- [tipo][fruta] = true/false (só nesta sessão)
function Bees.pickFor(item, bees)
    if U.key(item) == "treat" then
        table.sort(bees, function(a, b) return a.level < b.level end)
        return bees[1], false
    end
    for _, b in ipairs(bees) do if not Bees.rarityOf(b.name) then Bees.askRarity(b) end end   -- raridade desconhecida: pergunta
    -- Event/Exclusive não gostam de nenhuma fruta: fora da lista
    local filtered = {}
    for _, b in ipairs(bees) do if not Bees.NO_RJ[Bees.rarityOf(b.name) or ""] then table.insert(filtered, b) end end
    bees = filtered
    if #bees == 0 then return nil, false end
    table.sort(bees, function(a, b)
        local ra, rb = Bees.RANK[Bees.rarityOf(a.name) or ""] or 0, Bees.RANK[Bees.rarityOf(b.name) or ""] or 0
        if ra ~= rb then return ra > rb end
        return a.level > b.level
    end)
    local seen = {}
    for _, b in ipairs(bees) do
        local k = b.name or "?"
        if not seen[k] then
            seen[k] = true
            Bees.loves[k] = Bees.loves[k] or {}
            if Bees.loves[k][item] == nil then
                local a = askFood(b.slot, item)
                Bees.loves[k][item] = a ~= nil and a.loves == true
                task.wait(0.1)
            end
        end
        if Bees.loves[k][item] then return b, true end
    end
    return bees[1], false   -- nenhuma ama: vai pra de raridade mais alta
end
function Bees.questFeedStep()
    local list = Bees.questFeeds()
    if #list == 0 then Bees.questStatus = "Nenhuma quest de alimentar" return false end
    if #Bees.list() == 0 then Bees.questStatus = "Colmeia não encontrada" return false end
    local missing = {}
    for _, e in ipairs(list) do
        local item = invItem(e.item)
        local have = item and invHave(item) or 0
        if item and U.key(item) == "treat" then
            -- Treat: só faz quando dá pra completar tudo de uma vez (nada de 1 em 1 conforme ganha treat)
            if have >= e.left then
                local left, given = e.left, 0
                while left > 0 and running() and Cfg.FeedForQuests do
                    local bee = Bees.pickFor(item, Bees.list())
                    if not bee then break end
                    local ans = askFood(bee.slot, item)
                    local n = left
                    if ans and ans.need > 0 then n = math.min(n, ans.need) end
                    n = math.min(n, invHave(item))
                    if n <= 0 or not useOn(item, bee.slot, n) then break end
                    left -= n
                    given += n
                    Bees.questStatus = string.format("%s: dando %d Treat de uma vez | faltam %d", e.quest, e.left, left)
                end
                Bees.questStatus = string.format("%s: dei %d Treat%s", e.quest, given, left > 0 and (" (faltaram " .. left .. ")") or " (completo)")
                Quest.cacheT = 0
                return true
            end
            table.insert(missing, string.format("Treat (tem %d, precisa %d de uma vez)", have, e.left))
        elseif have > 0 then
            local bee, loved = Bees.pickFor(item, Bees.list())
            if not bee then Bees.questStatus = "Nenhuma abelha pode receber " .. item return false end
            local ans = askFood(bee.slot, item)
            local n = math.min(e.left, have)
            if ans and ans.need > 0 then n = math.min(n, ans.need) end
            useOn(item, bee.slot, n)
            Bees.questStatus = string.format("%s: dei %d %s pra %s (%s)%s | faltam %d", e.quest, n, item, bee.name or "?", bee.slot,
                loved and " ♥" or "", e.left - n)
            Quest.cacheT = 0
            return true
        else
            table.insert(missing, e.item)
        end
    end
    Bees.questStatus = "Sem item pra quest: " .. table.concat(missing, ", ")
    return false
end
task.spawn(function()
    while running() do
        task.wait(2)
        if Cfg.FeedForQuests and Hive.mine() and not Bees.anyOn() and U.alive() then
            local ok, e = pcall(Bees.questFeedStep)
            if not ok then Err.log("FeedQuest", e) end
        end
    end
end)

-- Qualquer função da aba Hive ligada: liga o Stop Everything (pausa o farm), vai até a colmeia
-- e fica lá. Desligou tudo: desliga o Stop Everything (se foi a aba Hive que ligou).
Bees.autoStop = false
function Bees.anyOn() return Cfg.AutoGiftedBasic or Cfg.AutoRJ or Cfg.FeedGifted or Cfg.AutoLevelHive end
function Bees.goHive()
    local h = Hive.mine()
    if not h then pcall(Hive.claim) h = Hive.mine() end
    local plat = h and Hive.platform(h)
    local hrp = U.hrp()
    if not (plat and hrp and U.alive()) then return false end
    local pos = Hive.convertPos(h, plat)
    if U.fdist(pos, hrp.Position) > 10 then
        Bees.status = "Indo pra colmeia"
        Move.tween(pos)
    end
    return true
end
task.spawn(function()
    while running() do
        local ok, e = pcall(function()
            if not Bees.anyOn() then
                -- desligou a última função da aba Hive: desliga o Stop Everything e o farm volta
                if Bees.autoStop or Bees.wasOn then
                    Bees.autoStop, Bees.wasOn = false, false
                    if Cfg.StopEverything then setCfg("StopEverything", false) end
                end
                task.wait(0.5)
                return
            end
            Bees.wasOn = true
            if not Cfg.StopEverything then
                setCfg("StopEverything", true)
                Sched.abort = true
                Move.cancel()
                Bees.autoStop = true
                task.wait(0.5)   -- deixa a tarefa atual parar antes de andar
            end
            if not Bees.goHive() then task.wait(1) return end
            if Cfg.AutoGiftedBasic then Bees.giftedStep()
            elseif Cfg.AutoRJ then Bees.rjStep()
            elseif Cfg.FeedGifted then Bees.feedStep()
            elseif Cfg.AutoLevelHive then Bees.levelStep()
            else task.wait(0.5) end
        end)
        if not ok then Err.log("Hive", e) task.wait(2) end
        task.wait()
    end
end)

------------------------------------------------------------------
-- GUI estilo Atlas: barra lateral de abas + busca, seções expansíveis em
-- duas colunas. Cada opção é uma "ficha" (spec) — a busca reaproveita as fichas.
------------------------------------------------------------------
;(function()
local T = {
    Bg = Color3.fromRGB(22, 22, 24), Side = Color3.fromRGB(28, 28, 31), Sec = Color3.fromRGB(32, 32, 35),
    Head = Color3.fromRGB(40, 40, 44), Item = Color3.fromRGB(46, 46, 51), Box = Color3.fromRGB(36, 50, 80),
    Accent = Color3.fromRGB(52, 96, 170), Top = Color3.fromRGB(42, 74, 128), Stroke = Color3.fromRGB(58, 58, 64),
    Text = Color3.fromRGB(232, 232, 236), Sub = Color3.fromRGB(150, 150, 160),
    Red = Color3.fromRGB(190, 65, 65), Green = Color3.fromRGB(80, 180, 105),
}
local Order = 0
local function new(class, props, children)
    local o = Instance.new(class)
    if o:IsA("GuiObject") then Order += 1 o.LayoutOrder = Order o.BorderSizePixel = 0 end
    for k, v in pairs(props or {}) do o[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = o end
    return o
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r or 6) }) end
local function vlist(p) return new("UIListLayout", { Padding = UDim.new(0, p or 6), SortOrder = Enum.SortOrder.LayoutOrder }) end
local function pad(t, l, b, r)
    return new("UIPadding", { PaddingTop = UDim.new(0, t), PaddingLeft = UDim.new(0, l), PaddingBottom = UDim.new(0, b or t), PaddingRight = UDim.new(0, r or l) })
end
local function label(text, size, color, props)
    local p = { Text = text, Font = Enum.Font.Gotham, TextSize = size or 14, TextColor3 = color or T.Text,
                BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left }
    for k, v in pairs(props or {}) do p[k] = v end
    return new("TextLabel", p)
end

local Gui = new("ScreenGui", { Name = "BSU2_Hub", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 50 })
if syn and syn.protect_gui then pcall(syn.protect_gui, Gui) end
if not pcall(function() Gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end) then
    Gui.Parent = LP:WaitForChild("PlayerGui")
end

local W, H = 780, 480
local Main = new("Frame", { Size = UDim2.fromOffset(W, H), Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2),
    BackgroundColor3 = T.Bg, ClipsDescendants = true, Parent = Gui }, { corner(6), new("UIStroke", { Color = T.Stroke }) })
local Top = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = T.Top, Parent = Main })
label("BSU v" .. VERSION, 18, T.Text, { Font = Enum.Font.GothamBold, Size = UDim2.new(0, 110, 1, 0), Position = UDim2.fromOffset(14, 0), Parent = Top })
label("Bee Swarm Unleashed", 13, Color3.fromRGB(190, 205, 230), { Size = UDim2.new(0, 200, 1, 0), Position = UDim2.fromOffset(110, 1), Parent = Top })
local CollapseBtn = new("TextButton", { Text = "▼", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = T.Text,
    BackgroundTransparency = 1, Size = UDim2.fromOffset(32, 36), Position = UDim2.new(1, -72, 0, 0), Parent = Top })
local CloseBtn = new("TextButton", { Text = "✕", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = T.Text,
    BackgroundTransparency = 1, Size = UDim2.fromOffset(32, 36), Position = UDim2.new(1, -38, 0, 0), Parent = Top })
do -- arrastar
    local dragging, start, startPos
    conn(Top.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, start, startPos = true, i.Position, Main.Position
        end
    end))
    conn(UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - start
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
    conn(UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))
end

local Side = new("Frame", { Position = UDim2.fromOffset(0, 36), Size = UDim2.new(0, 160, 1, -36), BackgroundColor3 = T.Side, Parent = Main })
local SearchBox = new("TextBox", { Text = "", PlaceholderText = "🔍  Search", Font = Enum.Font.GothamSemibold, TextSize = 14,
    TextColor3 = T.Text, PlaceholderColor3 = T.Sub, BackgroundColor3 = T.Item, ClearTextOnFocus = false,
    TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 8), Parent = Side },
    { corner(6), pad(0, 10) })
new("Frame", { Size = UDim2.new(1, -16, 0, 2), Position = UDim2.fromOffset(8, 50), BackgroundColor3 = T.Stroke, Parent = Side })
local TabList = new("ScrollingFrame", { Position = UDim2.fromOffset(8, 58), Size = UDim2.new(1, -16, 1, -64), BackgroundTransparency = 1,
    ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = Side }, { vlist(6) })
local Content = new("Frame", { Position = UDim2.fromOffset(168, 44), Size = UDim2.new(1, -176, 1, -52), BackgroundTransparency = 1, Parent = Main })

------------------------------------------------------------------
-- WIDGETS (cada um recebe uma ficha). Campos comuns:
--   key (Cfg) ou get/set, label, cb(v) depois de mudar
------------------------------------------------------------------
local Labels = {}   -- { lbl, fn, page }
local CurPage = nil
local function getV(s) if s.get then return s.get() end return Cfg[s.key] end
local function setV(s, v)
    if s.set then s.set(v) else setCfg(s.key, v) end
    if s.cb then pcall(s.cb, v) end
end
local function watch(s, row, fn)
    if s.key then onCfg(s.key, function(v) if row.Parent then fn(v) end end) end
end

local W_ = {}
function W_.toggle(s, p)
    local row = new("TextButton", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = p })
    local box = new("Frame", { Size = UDim2.fromOffset(24, 24), Position = UDim2.new(0, 0, 0.5, -12), BackgroundColor3 = T.Box, Parent = row }, { corner(5) })
    local mark = label("✓", 16, T.Text, { Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = box })
    label(s.label, 14, T.Text, { Size = UDim2.new(1, -34, 1, 0), Position = UDim2.fromOffset(34, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
    local function render(v) box.BackgroundColor3 = v and T.Accent or T.Box mark.Visible = v and true or false end
    render(getV(s))
    row.MouseButton1Click:Connect(function() setV(s, not getV(s)) render(getV(s)) end)
    watch(s, row, render)
end
function W_.slider(s, p)
    local mul = s.mul or 1
    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Parent = p })
    label(s.label, 14, T.Text, { Size = UDim2.new(1, -60, 0, 20), Parent = row })
    local val = label("", 13, T.Sub, { Size = UDim2.new(0, 60, 0, 20), Position = UDim2.new(1, -60, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
    local bar = new("Frame", { Size = UDim2.new(1, 0, 0, 8), Position = UDim2.fromOffset(0, 27), BackgroundColor3 = T.Box, Parent = row }, { corner(4) })
    local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, Parent = bar }, { corner(4) })
    local function render(v)
        local ui = (tonumber(v) or 0) * mul
        fill.Size = UDim2.fromScale(math.clamp((ui - s.min) / (s.max - s.min), 0, 1), 1)
        val.Text = (math.floor(ui) == ui and tostring(ui) or string.format("%.2f", ui)) .. (s.suffix or "")
    end
    local function setUI(ui)
        ui = math.clamp(math.floor((ui - s.min) / s.step + 0.5) * s.step + s.min, s.min, s.max)
        ui = tonumber(string.format("%.2f", ui))
        setV(s, ui / mul)
        render(ui / mul)
    end
    render(getV(s))
    local dragging = false
    local function upd(x) setUI(s.min + (s.max - s.min) * math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)) end
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true upd(i.Position.X) end
    end)
    conn(UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then upd(i.Position.X) end
    end))
    conn(UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))
    watch(s, row, render)
end
-- dropdown (uma opção) e multi (várias, valor = { [opção] = true })
local function dropdownBase(s, p, multi)
    local wrap = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = p }, { vlist(3) })
    local btn = new("TextButton", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = T.Item, Text = "", AutoButtonColor = false, Parent = wrap }, { corner(6) })
    local txt = label("", 15, T.Text, { Font = Enum.Font.GothamSemibold, Size = UDim2.new(1, -36, 1, 0), Position = UDim2.fromOffset(10, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = btn })
    local arrow = label("▼", 13, T.Text, { TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(28, 36), Position = UDim2.new(1, -30, 0, 0), Parent = btn })
    local list = new("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = T.Head, Visible = false, ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.Accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = wrap },
        { corner(6), vlist(3), pad(5, 5) })
    local function opts()
        local o = s.options
        if type(o) == "function" then o = o() end
        return o or {}
    end
    local function title()
        local v = getV(s)
        if multi then
            local n = 0
            local valid = {}
            for _, o in ipairs(opts()) do valid[o] = true end
            for k, on in pairs(v or {}) do if on and valid[k] then n += 1 end end
            txt.Text = s.label .. ": " .. n .. " selecionado(s)"
        else
            txt.Text = s.label .. ": " .. ((s.show and s.show(v)) or tostring(v or "-"))
        end
    end
    local open = false
    local function rebuild()
        for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        local o = opts()
        for _, name in ipairs(o) do
            local sel
            if multi then sel = (getV(s) or {})[name] == true else sel = getV(s) == name end
            local b = new("TextButton", { Size = UDim2.new(1, -6, 0, 34), BackgroundColor3 = sel and T.Accent or T.Item,
                Text = "   " .. ((s.show and s.show(name)) or name), Font = Enum.Font.GothamSemibold, TextSize = 16, TextColor3 = T.Text,
                TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = true, Parent = list }, { corner(4) })
            b.MouseButton1Click:Connect(function()
                if multi then
                    local v = getV(s) or {}
                    v[name] = (not v[name]) or nil
                    setV(s, v)
                    b.BackgroundColor3 = v[name] and T.Accent or T.Item
                else
                    setV(s, name)
                    open = false
                    list.Visible = false
                    arrow.Text = "▼"
                end
                title()
            end)
        end
        list.Size = UDim2.new(1, 0, 0, math.min(#o * 37 + 10, 300))
    end
    btn.MouseButton1Click:Connect(function()
        open = not open
        if open then rebuild() end
        list.Visible = open
        arrow.Text = open and "▲" or "▼"
    end)
    title()
    watch(s, wrap, function() title() if open then rebuild() end end)
end
function W_.dropdown(s, p) dropdownBase(s, p, false) end
function W_.multi(s, p) dropdownBase(s, p, true) end
function W_.text(s, p)
    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = p }, { vlist(3) })
    label(s.label, 13, T.Sub, { Size = UDim2.new(1, 0, 0, 16), Parent = row })
    local function show(v)
        if type(v) == "table" then return table.concat(v, ", ") end
        return tostring(v or "")
    end
    local box = new("TextBox", { Text = show(getV(s)), PlaceholderText = s.placeholder or "", Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = T.Text, PlaceholderColor3 = T.Sub, BackgroundColor3 = T.Item, ClearTextOnFocus = false, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, s.list and 48 or 30), Parent = row }, { corner(6), pad(4, 8) })
    box.FocusLost:Connect(function()
        if s.number then
            local n = tonumber((box.Text:gsub("[^%d%.]", "")))
            if n then
                n = math.floor(n)
                if s.min then n = math.max(n, s.min) end
                if s.max then n = math.min(n, s.max) end
                setV(s, n)
            end
        elseif s.list then
            local t = {}
            for part in box.Text:gmatch("[^,]+") do
                local n = part:gsub("^%s+", ""):gsub("%s+$", "")
                if n ~= "" then table.insert(t, n) end
            end
            setV(s, t)
        else
            setV(s, (box.Text:gsub("^%s+", ""):gsub("%s+$", "")))
        end
        box.Text = show(getV(s))
    end)
    watch(s, row, function(v) if not box:IsFocused() then box.Text = show(v) end end)
end
function W_.button(s, p)
    local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = s.color or T.Accent, Text = s.label,
        Font = Enum.Font.GothamSemibold, TextSize = 14, TextColor3 = T.Text, AutoButtonColor = true, Parent = p }, { corner(6) })
    b.MouseButton1Click:Connect(function() task.spawn(s.fn) end)
end
function W_.label(s, p, page)
    local l = label("", s.size or 13, s.color or T.Sub, { Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, RichText = false, Parent = p })
    table.insert(Labels, { lbl = l, fn = s.fn, page = page })
    pcall(function() l.Text = s.fn() end)
end
function W_.bar(s, p, page)
    local bg = new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = T.Box, Parent = p }, { corner(6) })
    local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, Parent = bg }, { corner(6) })
    local tx = label("", 12, T.Text, { Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = bg })
    table.insert(Labels, { lbl = tx, page = page, fn = function()
        local f, text = s.fn()
        fill.Size = UDim2.fromScale(math.clamp(f, 0, 1), 1)
        return text
    end })
end
local function build(s, p, page)
    local f = W_[s.t]
    if f then f(s, p, page) end
end

------------------------------------------------------------------
-- PÁGINAS / SEÇÕES
------------------------------------------------------------------
local Pages, TabBtns, TabDefs = {}, {}, {}
local function makePage()
    local page = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.Accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = Content })
    local left = new("Frame", { Size = UDim2.new(0.5, -5, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = page }, { vlist(8) })
    local right = new("Frame", { Size = UDim2.new(0.5, -9, 0, 0), Position = UDim2.new(0.5, 3, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = page }, { vlist(8) })
    return page, left, right
end
local function makeSection(col, title, key, defaultOpen)
    local sec = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Sec, Parent = col }, { corner(6), vlist(0) })
    local head = new("TextButton", { Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = T.Head, Text = "", AutoButtonColor = false, Parent = sec }, { corner(6) })
    label(title, 15, T.Text, { Font = Enum.Font.GothamBold, Size = UDim2.new(1, -44, 1, 0), Position = UDim2.fromOffset(12, 0), Parent = head })
    local arrow = label("▼", 15, T.Text, { TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(34, 38), Position = UDim2.new(1, -38, 0, 0), Parent = head })
    local body = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = sec }, { vlist(6), pad(10, 12) })
    local open = Cfg.UIOpen[key]
    if open == nil then open = defaultOpen ~= false end
    local function render() body.Visible = open arrow.Text = open and "▼" or "◀" end
    render()
    head.MouseButton1Click:Connect(function()
        open = not open
        if key then Cfg.UIOpen[key] = open end
        render()
    end)
    return body
end
local function selectPage(name)
    for n, pg in pairs(Pages) do pg.Visible = (n == name) end
    for n, b in pairs(TabBtns) do b.BackgroundColor3 = (n == name) and T.Head or T.Side end
    CurPage = Pages[name]
end

------------------------------------------------------------------
-- DIAGNÓSTICOS (aba Debug)
------------------------------------------------------------------
local function copy(txt)
    if setclipboard then pcall(setclipboard, txt) end
    print(txt)
end
local Diag = {}
function Diag.marks()
    local out = { "Meu UserId: " .. LP.UserId }
    for m in pairs(Mark.list) do
        if m.Parent then
            local line = m:GetFullName() .. " kind=" .. Mark.kind(m) .. " mine=" .. tostring(Mark.mine(m))
            for k, v in pairs(m:GetAttributes()) do line ..= " @" .. k .. "=" .. tostring(v) end
            table.insert(out, line)
        end
    end
    copy(table.concat(out, "\n"))
end
function Diag.bubbles()
    local out = { "Meu UserId: " .. LP.UserId }
    local n = 0
    for _ in pairs(Bub.bees) do n += 1 end
    table.insert(out, "Abelhas de bolha rastreadas: " .. n)
    for b in pairs(Bub.list) do
        if b.Parent then
            table.insert(out, string.format("%s dono=%s Type=%s Pop=%s", b:GetFullName(), tostring(Bub.owner[b]),
                tostring(b:GetAttribute("Type")), tostring(b:GetAttribute("Pop"))))
        end
    end
    copy(table.concat(out, "\n"))
end
function Diag.quests()
    local out = { "Painel: " .. tostring(Quest.container() and Quest.container():GetFullName()) }
    for n, q in pairs(Quest.read()) do
        table.insert(out, string.format("[%s] dono=%s pronta=%s", n, tostring(Quest.owner[n]), tostring(q.complete)))
        for _, o in ipairs(q.objs) do table.insert(out, string.format("   %s  (%.0f%%)", o.text, o.p * 100)) end
    end
    for k, v in pairs(Quest.avail) do table.insert(out, "WarnEvent " .. k .. " = " .. tostring(v)) end
    copy(table.concat(out, "\n"))
end
function Diag.tokens()
    local hb = F.hb(Farm.field())
    local hrp = U.hrp()
    local out = { "Campo: " .. tostring(Farm.field()) .. " | AutoTokens=" .. tostring(Cfg.AutoTokens) }
    for t in pairs(Tok.list) do
        local p = U.pos(t)
        if p and hb and F.inside(hb, p, 10) then
            local attrs = {}
            for k, v in pairs(t:GetAttributes()) do table.insert(attrs, k .. "=" .. tostring(v)) end
            table.insert(out, string.format("%s [%s] dist=%.0f dentro=%s -> %s | %s", t.Name, t.ClassName,
                hrp and (p - hrp.Position).Magnitude or -1, tostring(F.inside(hb, p)), Tok.why(t), table.concat(attrs, " ")))
        end
    end
    copy(table.concat(out, "\n"))
end
function Diag.buffs()
    local b = Boost.buffFolder()
    local out = { "Buffs: " .. tostring(b and b:GetFullName()) }
    if b then
        for _, c in ipairs(b:GetChildren()) do
            table.insert(out, "== " .. c.Name .. " [" .. c.ClassName .. "]")
            for k, v in pairs(c:GetAttributes()) do table.insert(out, "   @" .. k .. "=" .. tostring(v)) end
            for _, d in ipairs(c:GetDescendants()) do
                local line = "   " .. d:GetFullName():sub(#c:GetFullName() + 2) .. " [" .. d.ClassName .. "]"
                if d:IsA("TextLabel") or d:IsA("TextButton") then line ..= " = " .. d.Text end
                if d:IsA("GuiObject") and d.Name:lower():find("bar") then line ..= " size=" .. tostring(d.Size) end
                for k, v in pairs(d:GetAttributes()) do line ..= " @" .. k .. "=" .. tostring(v) end
                table.insert(out, line)
            end
        end
    end
    copy(table.concat(out, "\n"))
end
function Diag.boosters()
    pcall(Boost.scan)
    local out = {}
    for _, k in ipairs(Boost.KNOWN) do
        local pp = Boost.prompts[k.name]
        table.insert(out, string.format("%s: prompt=%s | lugar=%s", k.name, pp and pp:GetFullName() or "nenhum",
            tostring(Boost.where and Boost.where[k.name])))
    end
    table.insert(out, "== prompts com 'booster' ==")
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and (d.ActionText .. " " .. d.ObjectText):lower():find("booster", 1, true) then
            table.insert(out, d:GetFullName() .. " | " .. d.ActionText .. " | pos=" .. tostring(Boost.pos(d)))
        elseif d.Name:lower():find("booster", 1, true) then
            table.insert(out, "obj " .. d:GetFullName() .. " [" .. d.ClassName .. "]")
        end
    end
    copy(table.concat(out, "\n"))
end
function Diag.fight()
    copy(Fight.learnText() .. "\n\n" .. Fight.timersText())
end

------------------------------------------------------------------
-- DECLARAR DONO (quests antigas sem dono)
------------------------------------------------------------------
local Decl = { q = nil, npc = nil }
local function questOptions()
    local u, k = {}, {}
    for n in pairs(Quest.read()) do
        if Quest.owner[n] then table.insert(k, n) else table.insert(u, n) end
    end
    table.sort(u) table.sort(k)
    for _, n in ipairs(k) do table.insert(u, n) end
    return u
end

------------------------------------------------------------------
-- FICHAS DAS ABAS
------------------------------------------------------------------
local function fieldNames() return F.names() end
local function sec(title, key, items, open) return { title = title, key = key, items = items, open = open } end
local function tg(key, lbl, extra) local s = { t = "toggle", key = key, label = lbl } for k, v in pairs(extra or {}) do s[k] = v end return s end
local function sl(key, lbl, min, max, step, extra)
    local s = { t = "slider", key = key, label = lbl, min = min, max = max, step = step }
    for k, v in pairs(extra or {}) do s[k] = v end
    return s
end
local function lb(fn) return { t = "label", fn = fn } end
local function bt(lbl, fn, color) return { t = "button", label = lbl, fn = fn, color = color } end

local hpH = function()
    local g = U.honey() - St.startHoney
    return g / (math.max(tick() - St.startT, 1) / 3600)
end
local curHB = function() local f = Farm.field() return F.hb(f) end


-- SELECT POSITION: janela com a colmeia (rosto, level e ★ gifted de cada abelha) pra escolher o slot
local HivePicker = { frame = nil }
function HivePicker.close()
    if HivePicker.frame then HivePicker.frame:Destroy() HivePicker.frame = nil end
end
function HivePicker.open()
    HivePicker.close()
    local cs = Bees.cells()
    if not cs then Bees.status = "Colmeia não encontrada (dê claim)" return end
    local cells = {}
    for _, c in ipairs(cs:GetChildren()) do
        local i = Bees.cellInfo(c)
        local x, y = i.slot:match("(%d+),(%d+)")
        i.x, i.y = tonumber(x) or 0, tonumber(y) or 0
        if i.owned or i.bee then table.insert(cells, i) end
    end
    -- igual à colmeia: colunas em pé, linha mais alta em cima, colunas pares meia célula pra baixo (hexágono)
    local SZ, GAP = 56, 5
    local maxY = 1
    for _, i in ipairs(cells) do maxY = math.max(maxY, i.y) end
    local w = 5 * (SZ + GAP) + 30
    local hCanvas = maxY * (SZ + GAP) + SZ / 2 + 8
    local hFrame = math.min(hCanvas + 96, 600)
    local f = new("Frame", { Size = UDim2.fromOffset(w, hFrame), Position = UDim2.new(0.5, -w / 2, 0.5, -hFrame / 2), BackgroundColor3 = T.Bg,
        ZIndex = 20, Parent = Gui }, { corner(8), new("UIStroke", { Color = T.Stroke, Thickness = 1 }) })
    HivePicker.frame = f
    new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = T.Top, ZIndex = 21, Parent = f }, { corner(8),
        label("Select Position", 16, T.Text, { Font = Enum.Font.GothamBold, Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(12, 0), ZIndex = 22 }) })
    local grid = new("ScrollingFrame", { Size = UDim2.new(1, -16, 1, -96), Position = UDim2.fromOffset(8, 44), BackgroundColor3 = Color3.fromRGB(205, 165, 30),
        ScrollBarThickness = 4, ScrollBarImageColor3 = T.Accent, CanvasSize = UDim2.fromOffset(0, hCanvas), ZIndex = 21, Parent = f }, { corner(6) })
    -- cor da célula: a parte mais colorida entre Cell/Backplate (a Faceplate é transparente)
    local function cellColor(i)
        local best, sat = nil, -1
        for _, n in ipairs({ "Cell", "Backplate" }) do
            local p = i.cell:FindFirstChild(n)
            if p and p:IsA("BasePart") then
                local c = p.Color
                local sc = math.max(c.R, c.G, c.B) - math.min(c.R, c.G, c.B)
                if sc > sat then best, sat = c, sc end
            end
        end
        return best or T.Item
    end
    for _, i in ipairs(cells) do
        local face = i.cell:FindFirstChild("Faceplate")
        local decal = face and face:FindFirstChildWhichIsA("Decal")
        local px = 6 + (i.x - 1) * (SZ + GAP)
        local py = 4 + (maxY - i.y) * (SZ + GAP) + ((i.x % 2 == 0) and SZ / 2 or 0)
        local b = new("ImageButton", { Size = UDim2.fromOffset(SZ, SZ), Position = UDim2.fromOffset(px, py),
            BackgroundColor3 = i.bee and cellColor(i) or Color3.fromRGB(120, 95, 20), Image = (i.bee and decal) and decal.Texture or "",
            ScaleType = Enum.ScaleType.Fit, AutoButtonColor = true, ZIndex = 22, Parent = grid }, { corner(14) })
        if Cfg.HiveSlot == i.slot then new("UIStroke", { Color = T.Green, Thickness = 3, Parent = b }) end
        if i.gifted then
            label("★", 16, Color3.fromRGB(255, 210, 60), { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -19, 0, 1),
                TextStrokeTransparency = 0.3, ZIndex = 23, Parent = b })
        end
        label(i.bee and tostring(i.level) or "", 15, T.Text, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(20, 18),
            Position = UDim2.fromOffset(3, 1), TextStrokeTransparency = 0.1, ZIndex = 23, Parent = b })
        b.MouseButton1Click:Connect(function()
            setCfg("HiveSlot", i.slot)
            Bees.status = "Slot escolhido: " .. Bees.slotText(i.slot)
            HivePicker.close()
        end)
    end
    local close = new("TextButton", { Size = UDim2.fromOffset(120, 32), Position = UDim2.new(0.5, -60, 1, -42), BackgroundColor3 = T.Box,
        Text = "Close", Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = T.Text, ZIndex = 22, Parent = f }, { corner(6) })
    close.MouseButton1Click:Connect(HivePicker.close)
end

TabDefs = {
    { name = "Home", icon = "🏠",
      left = {
          sec("Status", "home_status", {
              { t = "bar", fn = function() local p, c = U.pollen(), U.cap() return p / c, string.format("Pólen %s / %s (%d%%)", U.short(p), U.short(c), math.floor(p / c * 100)) end },
              lb(function() return "Tarefa: " .. St.task end),
              lb(function() return "Motivo: " .. (St.reason ~= "" and St.reason or "-") end),
              lb(function() return "Ação: " .. (St.action ~= "" and St.action or "-") end),
              lb(function() local h = Hive.mine() return "Colmeia: " .. (h and h.Name or ("nenhuma " .. Hive.status)) end),
              lb(function() return "Último erro: " .. ((St.err and St.err.last or "-"):match("^[^\n]*")) end),
          }),
          sec("Controle", "home_quick", {
              tg("StopEverything", "Stop Everything (jogar na mão)", { cb = function(v)
                  if v then
                      Sched.abort = true
                      Move.cancel()
                      local hum, hrp = U.hum(), U.hrp()
                      if hrp then hrp.Anchored = false end
                      if hum and hrp then hum:MoveTo(hrp.Position) end
                      act("Pausado: jogando na mão")
                  end
              end }),
              lb(function() return "Ligado: o script para de mexer o personagem. Desligou: volta ao normal." end),
          }),
      },
      right = {
          sec("Sessão", "home_session", {
              lb(function() return "Mel: " .. U.fmtNum(U.honey()) end),
              lb(function() return "Ganho na sessão: " .. U.fmtNum(U.honey() - St.startHoney) end),
              lb(function() return "Honey Per Hour: " .. U.fmtNum(hpH()) .. "  (" .. U.short(hpH()) .. ")" end),
              lb(function() return "Tempo: " .. U.fmtTime(tick() - St.startT) end),
              lb(function() return string.format("Mobs mortos: %d | Hits levados: %d | Quests: %d", St.kills, St.hits, St.quests) end),
          }),
          sec("Campo atual", "home_field", {
              lb(function() local f, why = Farm.field() return "Campo: " .. U.fname(f) .. " (" .. tostring(why) .. ")" end),
              lb(function() return Sprout.statusText() end),
              lb(function() return Mark.statusText(curHB()) end),
              lb(function() return Bub.statusText(curHB()) end),
          }),
          sec("Console", "home_console", {
              lb(function()
                  local t = Con.tail(18)
                  return #t > 0 and table.concat(t, "\n") or "(vazio)"
              end),
              bt("Copiar console", function() copy(table.concat(Con.lines, "\n")) end),
              bt("Limpar console", function() table.clear(Con.lines) end, T.Red),
          }),
      } },
    { name = "Farming", icon = "🌻",
      left = {
          sec("Farming", "farm_main", {
              { t = "dropdown", key = "Field", label = "Field", options = fieldNames, show = function(v) return U.fname(v) end },
              tg("AutoFarm", "Autofarm"), tg("AutoTool", "Auto Tool (bater sempre)"),
              { t = "dropdown", key = "Sprinkler", label = "Sprinkler",
                options = function() return Spr.ORDER end },
              tg("AutoSprinkler", "Auto Sprinkler"),
              lb(function() return "Sprinkler: " .. Spr.current() .. "\nÚltimo: " .. Spr.status end),
          }),
          sec("Farm Settings", "farm_settings", {
              sl("ToolRange", "Alcance da ferramenta (grade)", 4, 20, 1),
              sl("EdgeMargin", "Margem da borda", 0, 15, 1),
              sl("FieldRandom", "Aleatoriedade", 5, 100, 5, { suffix = "%" }),
              sl("MinPointDist", "Distância mínima entre pontos", 0, 40, 1),
              sl("ToolDelay", "Delay da ferramenta", 50, 1000, 10, { mul = 1000, suffix = "ms" }),
          }, false),
          sec("Convert Settings", "farm_convert", {
              tg("AutoConvert", "Auto Convert"),
              sl("ConvertPercent", "Converter com a bolsa em", 50, 100, 5, { suffix = "%" }),
              tg("UseTicketConverters", "Use Ticket Converters (gasta 1 Medal)"),
              sl("ConverterCD", "Cooldown de cada converter", 5, 60, 1, { suffix = " min" }),
              lb(function() return Cfg.UseTicketConverters and TConv.statusText() or "Ticket Converters: desligado" end),
              tg("UseMicroConverters", "Convert with Micro Converters"),
              sl("MicroCD", "Cooldown custom do Micro Converter (0 = só o do jogo)", 0, 60, 1, { suffix = " min" }),
              { t = "text", key = "MicroKeep", label = "Guardar no inventário (só usa se tiver mais que isso)", number = true, min = 0, max = 999999 },
              lb(function() return Micro.statusText() end),
              sl("HiveEdgeMargin", "Margem da borda da colmeia", 0, 9, 0.5),
              sl("ConvertSettle", "Esperar o mel parar", 2, 15, 1, { suffix = "s" }),
              tg("AutoClaimHive", "Auto Claim Hive"),
              bt("Pegar colmeia agora", function() Hive.claim() end),
          }, false),
      },
      right = {
          sec("Sprout Settings", "farm_sprout", {
              tg("AutoSprout", "Farm Sprouts"),
              tg("SproutRarePlus", "Rare+ (farma todas menos Basic)"),
              sl("SproutTokenDelay", "Sprout: pegar cada token (remoto) com quantos segundos de vida", 0.1, 2, 0.05, { suffix = "s" }),
              lb(function()
                  if not firetouchinterest then return "Seu executor não tem firetouchinterest (não funciona)" end
                  return "Tokens pegos na sprout: " .. SproutTok.count
              end),
              tg("BeanOn", "Plantar sprouts com Magic Bean", { cb = function(v) if v then Bean.planted = 0 end end }),
              { t = "dropdown", key = "BeanField", label = "Field pra plantar", options = fieldNames,
                show = function(v) return (v == "" or v == nil) and "-" or U.fname(v) end },
              { t = "text", key = "BeanCount", label = "Quantas sprouts plantar (digite o número)", number = true, min = 1, max = 9999 },
              sl("BeanDelay", "Plantar a próxima depois de quebrar", 1, 15, 1, { suffix = "s" }),
              lb(function()
                  return string.format("Plantadas: %d/%d | Magic Beans: %d\nÚltimo: %s", Bean.planted, Cfg.BeanCount, Inv.count("Magic Bean"), Bean.status)
              end),
              bt("Zerar contador", function() Bean.planted = 0 end),
              lb(function() return Sprout.statusText() end),
          }),
          sec("Marks", "farm_marks", {
              tg("StayInMarks", "Farm Marks (maior network de marks)"),
              { t = "dropdown", key = "MarkPrefer", label = "Desempate: preferir", options = { "HoneyMark+", "PollenMark+", "PollenMark" } },
              lb(function() return Mark.statusText(curHB()) end),
          }, false),
          sec("Bubbles", "farm_bubbles", {
              tg("AutoBubbles", "Estourar bolhas"), tg("BubblesFirst", "Bolhas antes dos tokens"),
              tg("OnlyMyBubbles", "Só minhas bolhas"),
              lb(function() return Bub.statusText(curHB()) end),
          }, false),
          sec("Flames", "farm_flames", {
              sl("FlameHeatMax", "Abaixo desse Flame Heat (x): flames antes dos tokens", 10, 150, 5),
              lb(function()
                  local hb = curHB()
                  local e = hb and Flame.cluster(hb)
                  local ab = hb and Abyss.best(hb)
                  return string.format("Flame Heat: x%d | Dark Flames suas agora: %d\nAbaixo de x%d: fica no meio delas. Acima: igual bolha.\nAbyss rift: %s (prioridade máxima: fica dentro e estoura as bolhas Gold)",
                      Flame.heat(), e and e.n or 0, Cfg.FlameHeatMax, ab and "ativo" or "nenhum")
              end),
          }, false),
      } },
    { name = "Tokens", icon = "🎯",
      left = {
          sec("Tokens", "tok_main", {
              tg("OnlyMyTokens", "Ignorar tokens de outros players"),
              tg("IgnoreBomb", "Ignorar Bombs"), tg("IgnoreBoost", "Ignorar Boosts"),
              lb(function()
                  if not firetouchinterest then return "Coleta remota: seu executor não tem firetouchinterest (anda até os tokens)" end
                  return string.format("Tokens e bolhas 100%% remotos: %d toques (campo: %s). O personagem só anda pra Dark Flames, Abyss e marks.", Remote.touches, Remote.last ~= "" and Remote.last or "-")
              end),
              { t = "text", key = "TokenPriority", label = "Prioridade extra (vírgula)", list = true, placeholder = "ex: Link, Haste" },
              { t = "text", key = "TokenBlacklist", label = "Nunca pegar (vírgula)", list = true },
              { t = "text", key = "AbilityTokens", label = "Tokens de habilidade (ignorados no loot da sprout)", list = true },
          }),
      },
      right = {
          sec("Tween to Rare", "tok_rare", {
              tg("TweenToRare", "Tween to Rare"), tg("RareTeleport", "Teleportar direto (TP)"),
              tg("RareDuringConvert", "Interromper conversão"),
              sl("RareTweenSpeed", "Velocidade do tween", 100, 500, 10),
              sl("RareHold", "Ficar em cima do token", 0, 2, 0.1, { suffix = "s" }),
              { t = "text", key = "RareTokens", label = "Tokens raros (vírgula)", list = true },
          }),
          sec("Info", "tok_info", {
              lb(function() local n = 0 for _ in pairs(Tok.list) do n += 1 end return "Tokens no mapa: " .. n end),
              lb(function() return "Última lista negra: " .. St.lastBlack end),
              lb(function()
                  local t = {}
                  for n in pairs(Tok.seen) do table.insert(t, n) end
                  table.sort(t)
                  return "Já vistos: " .. (#t > 0 and table.concat(t, ", ") or "-")
              end),
          }, false),
      } },
    { name = "Combat", icon = "⚔️",
      left = {
          sec("Auto Kill", "cb_main", {
              tg("AutoKill", "Auto Kill"),
              { t = "multi", key = "KillMobs", label = "Mobs", options = function() return Mob.names end },
              tg("KillOnlyAfterConvert", "Só depois de converter"),
              tg("FieldMobDodge", "Lutar com mob no campo do farm"),
              lb(function() return "Vai só em campos liberados; chegando lá mata TODOS os mobs daquele campo." end),
          }),
      },
      right = {
          sec("Timers", "cb_timers", { lb(function() return Fight.timersText() end) }),
          sec("Aprendizado", "cb_learn", {
              lb(function() return Fight.learnText() end),
              bt("Resetar aprendizado", function() Fight.data = {} writeJSON(FILES.mobs, {}) end, T.Red),
          }, false),
      } },
    { name = "Quests", icon = "📜",
      left = {
          sec("Quests", "q_main", {
              tg("AutoQuest", "Auto Complete Quests"),
              { t = "multi", key = "QuestClaim", label = "Auto Claim Quests", options = function() return Quest.npcNames() end },
          }),
          sec("Quest Settings", "q_settings", {
              tg("QuestField", "Farmar no campo que a quest pede"),
              { t = "dropdown", key = "BestBlue", label = "Best Blue Field",
                options = function() local o = Quest.colorOptions("blue") table.insert(o, 1, "Automático") return o end,
                show = function(v) return (v == "" or v == nil) and "Automático" or U.fname(v) end },
              { t = "dropdown", key = "BestRed", label = "Best Red Field",
                options = function() local o = Quest.colorOptions("red") table.insert(o, 1, "Automático") return o end,
                show = function(v) return (v == "" or v == nil) and "Automático" or U.fname(v) end },
              { t = "dropdown", key = "BestWhite", label = "Best White Field",
                options = function() local o = Quest.colorOptions("white") table.insert(o, 1, "Automático") return o end,
                show = function(v) return (v == "" or v == nil) and "Automático" or U.fname(v) end },
              tg("QuestMobs", "Matar mobs que a quest pede"),
              tg("QuestKillBoss", "Kill Boss (Royal Beetle / Shadow Bear) pra quest"),
              tg("FeedForQuests", "Feed Bees For Quests"),
              lb(function() return Cfg.FeedForQuests and ("Feed: " .. Bees.questStatus) or "Feed: desligado (Raise Level fica manual)" end),
              tg("QuestAfterConvert", "Só entregar/pegar depois de converter"),
              sl("TalkDelay", "Delay do diálogo", 0.05, 1, 0.05, { suffix = "s" }),
              sl("QuestInterval", "Re-tentar urso sem quest após", 30, 900, 10, { suffix = "s" }),
              bt("Visitar ursos agora", function()
                  for _, n in ipairs(Quest.npcNames()) do if Quest.active(n) then Quest.forced[n] = true end end
                  Quest.cooldown = {}
                  Quest.wantT = 0
              end),
          }, false),
          sec("Main Quest Toggles", "q_mainnpc", (function()
              local t = {}
              for _, n in ipairs(Quest.npcGroup(false)) do
                  table.insert(t, { t = "toggle", label = n,
                      get = function() return Cfg.QuestNPCs[n] == true end,
                      set = function(v) Quest.setDoing(n, v) end })
              end
              if #t == 0 then t[1] = lb(function() return "Nenhum urso encontrado" end) end
              return t
          end)(), false),
          sec("Repeatable Quest Toggles", "q_repnpc", (function()
              local t = {}
              for _, n in ipairs(Quest.npcGroup(true)) do
                  table.insert(t, { t = "toggle", label = n,
                      get = function() return Cfg.QuestNPCs[n] == true end,
                      set = function(v) Quest.setDoing(n, v) end })
              end
              if #t == 0 then t[1] = lb(function() return "Nenhum urso encontrado" end) end
              return t
          end)(), false),
          sec("Declarar dono", "q_decl", {
              lb(function() return "Só pra quests que você já tinha antes do script (sem dono)." end),
              { t = "dropdown", label = "Quest", options = questOptions,
                get = function() return Decl.q end, set = function(v) Decl.q = v end,
                show = function(v) if not v then return "-" end return v .. (Quest.owner[v] and (" [" .. Quest.owner[v] .. "]") or " [?]") end },
              { t = "dropdown", label = "Urso", options = function() return Quest.npcNames() end,
                get = function() return Decl.npc end, set = function(v) Decl.npc = v end },
              bt("Salvar dono", function()
                  if Decl.q and Decl.npc then
                      Quest.setOwner(Decl.q, Decl.npc, "declarado")
                      Quest.cooldown[Decl.npc] = nil
                      Quest.wantT = 0
                  end
              end),
              bt("Esquecer todos os donos", function() Quest.owner, Quest.base = {}, {} Quest.save() end, T.Red),
          }, false),
      },
      right = {
          sec("Quests ativas", "q_list", { lb(function() return Quest.statusText() end) }),
      } },
    { name = "Campos", icon = "🗺️",
      left = {
          sec("Campos liberados", "fld_main", {
              lb(function() return "O script NUNCA entra em campo que não esteja marcado aqui (evita kick)." end),
              { t = "multi", key = "Unlocked", label = "Allowed Fields", options = fieldNames, show = function(v) return U.fname(v) end },
              lb(function()
                  local t = {}
                  for _, n in ipairs(F.names()) do if F.unlocked(n) then table.insert(t, U.fname(n)) end end
                  return "Liberados: " .. (#t > 0 and table.concat(t, ", ") or "nenhum")
              end),
          }),
      },
      right = {
          sec("Movimento", "fld_move", {
              sl("TweenSpeed", "Velocidade do tween", 16, 250, 1),
              tg("Noclip", "Noclip durante o tween"),
              tg("WalkSpeedOn", "WalkSpeed personalizado"),
              sl("WalkSpeed", "WalkSpeed", 30, 90, 1),
          }),
      } },
    { name = "Webhook", icon = "🔗",
      left = {
          sec("Webhook", "wh_main", {
              tg("WebhookOn", "Ativar webhook"),
              { t = "text", key = "WebhookURL", label = "URL do webhook do Discord", placeholder = "https://discord.com/api/webhooks/..." },
              { t = "text", key = "WebhookPing", label = "Seu ID do Discord (pra marcar em itens/morte)", placeholder = "opcional" },
              sl("WebhookInterval", "Status a cada", 5, 180, 5, { suffix = " min" }),
              bt("Enviar teste", function() Hook.test() end),
              bt("Enviar status agora", function() Hook.post({ embeds = { { title = "📊 Status", color = 0x2F5AA0, fields = Hook.statsFields(),
                  description = "__Itens na sessão__\n" .. Hook.itemsText(),
                  footer = { text = "BSU v" .. VERSION .. " • " .. LP.Name } } } }) end),
          }),
      },
      right = {
          sec("Avisos", "wh_events", {
              tg("WebhookItems", "Itens únicos (Egg, Star Jelly...)"),
              tg("WebhookQuests", "Quest entregue"),
              tg("WebhookDeath", "Morte"),
              tg("WebhookDisconnect", "Desconectou / kick"),
              { t = "text", key = "GraphWebhookURL", label = "Webhook dos gráficos (vazio = o mesmo de cima)", placeholder = "https://discord.com/api/webhooks/..." },
              tg("StatsOn", "Relatório completo (BSU Stats)"),
              { t = "text", key = "StatsURL", label = "Endereço do BSU Stats (Render)", placeholder = "https://bsu-stats.onrender.com" },
              { t = "text", key = "StatsSecret", label = "Senha do BSU Stats (SECRET)", placeholder = "a mesma do Render" },
              bt("Enviar relatório completo agora", function() task.spawn(Stats.send) end),
              lb(function() return "BSU Stats: " .. Stats.status end),
              lb(function() return "Status: " .. Hook.status .. (Hook.req and "" or " (seu executor não tem request)") end),
          }),
      } },
    { name = "Config", icon = "⚙️",
      left = {
          sec("Geral", "cfg_main", {
              tg("AntiAFK", "Anti-AFK"),
              lb(function() return "RightShift = mostrar/esconder a GUI" end),
              bt("Salvar config agora", function() saveCfg() end),
              bt("Resetar config (padrão)", function()
                  for k, v in pairs(Defaults) do setCfg(k, deepcopy(v)) end
                  saveCfg()
              end, T.Red),
              bt("Fechar script", function() if Env.Destroy then Env.Destroy() end end, T.Red),
          }),
      },
      right = {
          sec("Sobre", "cfg_about", {
              lb(function() return "BSU v" .. VERSION .. "\nArquivos: BSU2_Config.json, BSU2_QuestOwners.json, BSU2_MobData.json" end),
          }),
      } },
    { name = "Toys", icon = "🧸",
      left = {
          sec("Field Boosters", "toy_boost", {
              tg("AutoBooster", "Auto Boosters"),
              tg("RequireBooster", "Require Field Booster (só renova boost de booster)"),
              tg("StaggerBoosters", "Stagger Boosters (15 min entre boosts bons)"),
              { t = "multi", key = "BoostFields", label = "Allowed Fields", options = fieldNames, show = function(v) return U.fname(v) end },
              { t = "multi", key = "Boosters", label = "Allowed Boosters", options = function() return Boost.names() end },
              tg("UseDice", "Usar Field Dice pra renovar"),
              tg("UseGlitter", "Usar Glitter pra renovar"),
              tg("ExtendOnce", "Estender só uma vez (por booster)"),
              sl("MinBoostFarm", "Minimum Field Boost To Farm", 1, 10, 1),
              sl("WantedBoost", "Wanted Field Boost", 1, 10, 1),
              sl("RenewTime", "Min Time Left To Roll Dice", 10, 300, 5, { suffix = "s" }),
              sl("MaxDicePerRenew", "Máximo de dados por renovação", 1, 50, 1),
              bt("Procurar boosters de novo", function() Boost.scan() end),
              lb(function()
                  local st = ""
                  if Cfg.StaggerBoosters and tick() < Boost.staggerUntil then st = "\nPróximo booster em " .. U.fmtTime(Boost.staggerUntil - tick()) end
                  return Boost.statusText() .. string.format("\nField Dice: %d | Glitter: %d", Inv.count("FieldDice"), Inv.count("Glitter")) .. st
              end),
          }),
      },
      right = {
          sec("Materials", "toy_mats", (function()
              local items = { tg("AutoMaterials", "Auto Materials") }
              for _, m in ipairs(Mat.LIST) do
                  table.insert(items, { t = "toggle", label = m.name,
                      get = function() return Mat.cfg(m.name).on end,
                      set = function(v) Mat.cfg(m.name).on = v end })
                  table.insert(items, { t = "slider", label = m.name .. ": intervalo" .. (m.unit == 60 and " (min)" or " (s)"),
                      min = 1, max = m.unit == 60 and 60 or 30, step = 1,
                      get = function() return Mat.cfg(m.name).interval end,
                      set = function(v) Mat.cfg(m.name).interval = v end })
              end
              table.insert(items, lb(function() return Mat.statusText() end))
              return items
          end)()),
      } },
    { name = "Hive", icon = "🐝",
      left = {
          sec("Eggs", "hv_egg", {
              bt("Select Position", function() HivePicker.open() end),
              { t = "dropdown", key = "HiveSlot", label = "Slot", options = function() return Bees.slotOptions() end,
                show = function(v) return Bees.slotText(v) end },
              tg("AutoGiftedBasic", "Auto Gifted Basic Bee"),
              tg("BuyBasicEggs", "Purchase Basic Eggs"),
              sl("EggBuyAmount", "Amount To Purchase", 1, 100, 1),
              lb(function() return "Basic Egg: " .. Inv.count("Basic Egg") .. "\n" .. Bees.status end),
          }),
          sec("Royal Jelly", "hv_rj", {
              tg("AutoRJ", "Auto Royal Jelly"),
              tg("RJStopGifted", "Stop On Any Gifted"),
              { t = "multi", key = "RJBeeTypes", label = "Bee Types", options = function() return Bees.rjTypes() end },
              { t = "multi", key = "RJStopRarity", label = "Stop On Bee Rarity", options = Bees.RJ_RARITIES },
              lb(function() return "Royal Jelly: " .. Inv.count("Royal Jelly") .. " | Slot: " .. Bees.slotText(Cfg.HiveSlot) .. "\n" .. Bees.rjStatus end),
          }),
      },
      right = {
          sec("Feed Until Gifted", "hv_feed", {
              tg("FeedGifted", "Feed Until Gifted"),
              { t = "text", key = "FeedAmount", label = "Quantidade por vez (digite)", number = true, min = 1, max = 99999 },
              { t = "text", key = "FeedLimit", label = "Limite total (digite)", number = true, min = 1, max = 9999999 },
              lb(function() return Bees.favText() .. "\n" .. Bees.feedStatus end),
          }),
          sec("Level Up Hive", "hv_lvl", {
              tg("AutoLevelHive", "Auto Level Up Hive"),
              sl("TargetLevel", "Target Level", 1, 25, 1),
              bt("Calcular Treats necessários", function() Bees.calcTreats() end),
              lb(function() return Bees.levelInfo() .. "\n" .. Bees.lvlStatus end),
          }),
          sec("Abelhas", "hv_list", {
              lb(function()
                  local t = {}
                  for _, i in ipairs(Bees.list()) do
                      table.insert(t, string.format("%s  %s Lv%d%s", i.slot, i.name or "?", i.level, i.gifted and " ★" or ""))
                  end
                  return #t > 0 and table.concat(t, "\n") or "Colmeia não encontrada"
              end),
          }, false),
      } },
    { name = "Debug", icon = "🐞",
      left = {
          sec("Diagnóstico (copia pro clipboard)", "dbg_main", {
              bt("Copiar marks", Diag.marks), bt("Copiar bolhas", Diag.bubbles),
              bt("Copiar quests", Diag.quests), bt("Copiar luta/timers", Diag.fight),
              bt("Copiar tokens do campo", Diag.tokens),
              bt("Copiar buffs (field boost)", Diag.buffs),
              bt("Copiar log de sprouts", function()
                  copy(#Sprout.log > 0 and table.concat(Sprout.log, "\n") or "nenhuma sprout registrada ainda")
              end),
              bt("Copiar boosters", Diag.boosters),
          }),
      },
      right = {
          sec("Ao vivo", "dbg_live", {
              lb(function() return "Tarefa: " .. St.task .. " | " .. St.reason end),
              lb(function() return "Interrompido: " .. tostring(Sched.abort) .. " | Tween: " .. tostring(Move.tweening) end),
              lb(function()
                  local t = {}
                  for _, tk in ipairs(Tasks) do
                      local ok, r = pcall(tk.want)
                      table.insert(t, tk.label .. ": " .. (ok and (r or "-") or "erro"))
                  end
                  return table.concat(t, "\n")
              end),
          }),
      } },
}

-- monta tudo
for _, tab in ipairs(TabDefs) do
    local page, left, right = makePage()
    Pages[tab.name] = page
    for _, s in ipairs(tab.left) do
        local body = makeSection(left, s.title, s.key, s.open)
        for _, it in ipairs(s.items) do build(it, body, page) end
    end
    for _, s in ipairs(tab.right) do
        local body = makeSection(right, s.title, s.key, s.open)
        for _, it in ipairs(s.items) do build(it, body, page) end
    end
    local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = T.Side, Text = "", AutoButtonColor = false, Parent = TabList }, { corner(6) })
    label(tab.icon, 15, T.Text, { TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(30, 36), Position = UDim2.fromOffset(4, 0), Parent = b })
    label(tab.name, 15, T.Text, { Font = Enum.Font.GothamSemibold, Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(38, 0), Parent = b })
    TabBtns[tab.name] = b
    b.MouseButton1Click:Connect(function() SearchBox.Text = "" selectPage(tab.name) end)
end

-- BUSCA: mostra as opções que batem com o texto (mesmas fichas, sincronizadas)
local SearchPage, SLeft, SRight = makePage()
Pages.__search = SearchPage
local lastTab = "Home"
local function runSearch(q)
    for _, col in ipairs({ SLeft, SRight }) do
        for _, c in ipairs(col:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
    end
    for i = #Labels, 1, -1 do if Labels[i].page == SearchPage then table.remove(Labels, i) end end
    q = q:lower()
    local n = 0
    for _, tab in ipairs(TabDefs) do
        for _, s in ipairs(tab.left) do
            local hits = {}
            for _, it in ipairs(s.items) do if it.label and it.label:lower():find(q, 1, true) then table.insert(hits, it) end end
            if #hits > 0 then
                n += 1
                local body = makeSection(n % 2 == 1 and SLeft or SRight, tab.name .. " › " .. s.title, nil, true)
                for _, it in ipairs(hits) do build(it, body, SearchPage) end
            end
        end
        for _, s in ipairs(tab.right) do
            local hits = {}
            for _, it in ipairs(s.items) do if it.label and it.label:lower():find(q, 1, true) then table.insert(hits, it) end end
            if #hits > 0 then
                n += 1
                local body = makeSection(n % 2 == 1 and SLeft or SRight, tab.name .. " › " .. s.title, nil, true)
                for _, it in ipairs(hits) do build(it, body, SearchPage) end
            end
        end
    end
    if n == 0 then
        local body = makeSection(SLeft, "Nada encontrado", nil, true)
        build(lb(function() return "Nenhuma opção com \"" .. q .. "\"" end), body, SearchPage)
    end
end
do
    local pending = 0
    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        pending += 1
        local my = pending
        task.delay(0.25, function()
            if my ~= pending then return end
            local q = SearchBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
            if q == "" then selectPage(lastTab) return end
            runSearch(q)
            for n, pg in pairs(Pages) do pg.Visible = (pg == SearchPage) end
            CurPage = SearchPage
        end)
    end)
end
for name, b in pairs(TabBtns) do b.MouseButton1Click:Connect(function() lastTab = name end) end
selectPage("Home")

-- atualiza os textos só da página aberta
task.spawn(function()
    while running() do
        for _, l in ipairs(Labels) do
            if l.page == CurPage and l.lbl.Parent then
                local ok, txt = pcall(l.fn)
                if ok and txt then l.lbl.Text = tostring(txt) end
            end
        end
        task.wait(0.5)
    end
end)

-- minimizar / tecla
local collapsed = false
CollapseBtn.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    Main.Size = collapsed and UDim2.fromOffset(W, 36) or UDim2.fromOffset(W, H)
    CollapseBtn.Text = collapsed and "◀" or "▼"
end)
conn(UIS.InputBegan:Connect(function(i, gp)
    if not gp and i.KeyCode == Enum.KeyCode.RightShift then Gui.Enabled = not Gui.Enabled end
end))

------------------------------------------------------------------
-- FECHAR / LIMPEZA (executar de novo chama isso)
------------------------------------------------------------------
Env.Destroy = function()
    if not Env.Running then return end
    saveCfg()
    if Fight.dirty then writeJSON(FILES.mobs, Fight.data) end
    Env.Running = false
    Move.cancel()
    pcall(function() local h = U.hrp() if h then h.Anchored = false end end)
    pcall(function() if DefaultWS and U.hum() then U.hum().WalkSpeed = DefaultWS end end)
    for _, c in ipairs(Env.Conns) do pcall(function() c:Disconnect() end) end
    pcall(function() Gui:Destroy() end)
end
CloseBtn.MouseButton1Click:Connect(function() Env.Destroy() end)

task.spawn(function()
    while running() do task.wait(3) saveCfg() end
end)
print("[BSU] v" .. VERSION .. " carregado! RightShift para mostrar/esconder.")
end)()
