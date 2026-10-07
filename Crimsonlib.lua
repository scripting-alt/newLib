
-- ================================================================
--  CrimsonLib
--  Painel único vermelho com tooltips, keybinds, notificações,
--  ícones por nome e flags salvas em arquivo.
--
--  A interface é criada no CoreGui (gethui -> CoreGui -> PlayerGui).
--  Os arquivos ficam no workspace do executor:
--      <workspace>/<Folder>/Icons.lua
--      <workspace>/<Folder>/ScriptFlags.json
--      <workspace>/<Folder>/LibrarySettings.json
-- ================================================================

local cloneRef = (typeof(cloneref) == "function" and cloneref) or function(instance)
	return instance
end

local function getService(name)
	local ok, result = pcall(function()
		return cloneRef(game:GetService(name))
	end)
	if ok and typeof(result) == "Instance" then
		return result
	end
	return game:GetService(name)
end

local Players = getService("Players")
local UserInputService = getService("UserInputService")
local TweenService = getService("TweenService")
local RunService = getService("RunService")
local TextService = getService("TextService")
local HttpService = getService("HttpService")

-- funções que só existem dentro de executores
local makefolderFn = (typeof(makefolder) == "function" and makefolder) or nil
local writefileFn = (typeof(writefile) == "function" and writefile) or nil
local readfileFn = (typeof(readfile) == "function" and readfile) or nil
local isfileFn = (typeof(isfile) == "function" and isfile) or nil
local isfolderFn = (typeof(isfolder) == "function" and isfolder) or nil
local delfileFn = (typeof(delfile) == "function" and delfile) or nil
local protectGuiFn = (typeof(protect_gui) == "function" and protect_gui)
	or (typeof(syn) == "table" and typeof(syn.protect_gui) == "function" and syn.protect_gui)
	or nil
local loadChunk = (typeof(loadstring) == "function" and loadstring) or load

local Library = {}
local Window = {}
Window.__index = Window

-- pasta/arquivos usados no workspace do executor
Library.Folder = "CrimsonLib"
Library.Files = {
	Icons = "Icons.lua",
	Flags = "ScriptFlags.json",
	Settings = "LibrarySettings.json",
}
Library.IconsUrl = "https://raw.githubusercontent.com/tlredz/Library/refs/heads/main/redz-V5-remake/Utils/Icons.lua"
Library.Icons = {}
Library.Debug = false
Library.SavePosition = true
Library._flagBinds = {}

----------------------------------------------------------------
-- TEMA
----------------------------------------------------------------
Library.Theme = {
	Dark = Color3.fromRGB(30, 0, 6),
	Glass = Color3.fromRGB(20, 0, 4),
	Red = Color3.fromRGB(200, 20, 40),
	RedBright = Color3.fromRGB(255, 60, 80),
	RedSoft = Color3.fromRGB(255, 130, 140),
	Text = Color3.fromRGB(255, 240, 242),
	SubText = Color3.fromRGB(255, 170, 178),
	SwitchOff = Color3.fromRGB(70, 22, 30),
}

local TITLE_H = 38
local PAD_TOP = 8
local PAD_BOTTOM = 12
local MIN_BODY = 40
local KEY_W = 52

----------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------
local function create(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	return inst
end

local function corner(r)
	return create("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function tween(obj, props, time, style)
	local t = TweenService:Create(
		obj,
		TweenInfo.new(time or 0.18, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function gradient(c0, c1, rotation)
	return create("UIGradient", {
		Color = ColorSequence.new(c0, c1),
		Rotation = rotation or 90,
	})
end

local function pcallCallback(fn, ...)
	if typeof(fn) ~= "function" then return end
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[CrimsonLib] erro no callback: " .. tostring(err))
	end
end

----------------------------------------------------------------
-- ONDE A INTERFACE É CRIADA
-- Prioridade: gethui() -> CoreGui -> PlayerGui (fallback)
----------------------------------------------------------------
local guiParentOverride = nil
local cachedGuiParent = nil

-- Força um container específico (ex: Library:SetGuiParent(game.CoreGui))
function Library:SetGuiParent(parent)
	guiParentOverride = parent
	cachedGuiParent = parent
end

function Library:GetGuiParent()
	if guiParentOverride and guiParentOverride.Parent then
		return guiParentOverride
	end
	if cachedGuiParent and cachedGuiParent.Parent then
		return cachedGuiParent
	end

	local holder = nil

	if typeof(gethui) == "function" then
		local ok, result = pcall(gethui)
		if ok and typeof(result) == "Instance" then
			holder = result
		end
	end

	if not holder then
		local ok, result = pcall(function()
			return cloneRef(game:GetService("CoreGui"))
		end)
		if ok and typeof(result) == "Instance" then
			holder = result
		else
			-- alguns executores não deixam clonar o CoreGui
			local ok2, result2 = pcall(function()
				return game:GetService("CoreGui")
			end)
			if ok2 and typeof(result2) == "Instance" then
				holder = result2
			end
		end
	end

	if not holder then
		holder = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
			or Players.LocalPlayer:WaitForChild("PlayerGui", 5)
	end

	cachedGuiParent = holder
	return holder
end

-- Cria a ScreenGui já dentro do CoreGui (ou do container escolhido)
local function mountScreenGui(name, props)
	props = props or {}
	props.Name = name
	props.ResetOnSpawn = false
	props.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local parent = Library:GetGuiParent()
	if parent then
		local old = parent:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	local gui = create("ScreenGui", props)

	if protectGuiFn then
		pcall(protectGuiFn, gui)
	end

	local ok = pcall(function()
		gui.Parent = parent
	end)
	if not ok or gui.Parent ~= parent then
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	return gui
end

----------------------------------------------------------------
-- ARQUIVOS NO WORKSPACE DO EXECUTOR
----------------------------------------------------------------
local function folderPath()
	return (type(Library.Folder) == "string" and Library.Folder ~= "" and Library.Folder) or "CrimsonLib"
end

local function filePath(name)
	return folderPath() .. "/" .. name
end

local function ensureFolder()
	if not makefolderFn then
		return
	end
	local folder = folderPath()
	if isfolderFn and isfolderFn(folder) then
		return
	end
	pcall(makefolderFn, folder)
end

local function writeRaw(name, content)
	if not writefileFn then
		return false
	end
	ensureFolder()
	return pcall(writefileFn, filePath(name), content)
end

local function readRaw(name)
	if not readfileFn then
		return nil
	end
	if isfileFn and not isfileFn(filePath(name)) then
		return nil
	end
	local ok, data = pcall(readfileFn, filePath(name))
	if ok and type(data) == "string" then
		return data
	end
	return nil
end

local function deleteRaw(name)
	if not delfileFn then
		return false
	end
	return pcall(delfileFn, filePath(name))
end

function Library:GetFilePath(name)
	return filePath(name)
end

function Library:HasFileSupport()
	return writefileFn ~= nil and readfileFn ~= nil
end

function Library:WriteFile(name, content)
	assert(type(name) == "string", "[CrimsonLib] WriteFile: nome do arquivo precisa ser string")
	assert(type(content) == "string", "[CrimsonLib] WriteFile: conteúdo precisa ser string")
	return writeRaw(name, content)
end

function Library:ReadFile(name)
	assert(type(name) == "string", "[CrimsonLib] ReadFile: nome do arquivo precisa ser string")
	return readRaw(name)
end

function Library:DeleteFile(name)
	assert(type(name) == "string", "[CrimsonLib] DeleteFile: nome do arquivo precisa ser string")
	return deleteRaw(name)
end

function Library:FileExists(name)
	if not isfileFn then
		return false
	end
	return isfileFn(filePath(name))
end

----------------------------------------------------------------
-- JSON + SAVE COM DEBOUNCE
----------------------------------------------------------------
local function jsonEncode(data)
	local ok, result = pcall(function()
		return HttpService:JSONEncode(data)
	end)
	if ok and type(result) == "string" then
		return result
	end
	if Library.Debug then
		warn("[CrimsonLib] falha ao codificar JSON: " .. tostring(result))
	end
	return nil
end

local function jsonDecode(source)
	if type(source) ~= "string" or source == "" then
		return nil
	end
	local ok, result = pcall(function()
		return HttpService:JSONDecode(source)
	end)
	if ok and type(result) == "table" then
		return result
	end
	if Library.Debug then
		warn("[CrimsonLib] falha ao decodificar JSON: " .. tostring(result))
	end
	return nil
end

-- grava no máximo uma vez a cada intervalo, mesmo com muitas mudanças
local function makeSaver(write)
	local pending = false
	return {
		Queue = function()
			if pending then
				return
			end
			pending = true
			task.delay(0.5, function()
				pending = false
				write()
			end)
		end,
		Flush = write,
	}
end

----------------------------------------------------------------
-- FLAGS  (ScriptFlags.json)
-- Guarda o valor dos toggles/sliders e a tecla dos keybinds.
-- Uso:  Win:Toggle({ Name = "Auto Farm", Flag = "AutoFarm", Default = false })
--       Library:GetFlag("AutoFarm")  /  Library:SetFlag("AutoFarm", true)
-- A tecla do keybind de uma flag fica em "<Flag>_Key".
----------------------------------------------------------------
local FLAG_TYPES = { number = true, string = true, boolean = true, table = true }
local FlagData = {}

Library.Flags = FlagData

local SaveFlags = makeSaver(function()
	local data = jsonEncode(FlagData)
	if data then
		writeRaw(Library.Files.Flags, data)
	end
end)

local FlagsLoaded = false

local function ensureFlags()
	if FlagsLoaded then
		return
	end
	FlagsLoaded = true
	local data = jsonDecode(readRaw(Library.Files.Flags))
	if data then
		for key, value in pairs(data) do
			FlagData[key] = value
		end
	end
end

function Library:LoadFlags()
	FlagsLoaded = false
	table.clear(FlagData)
	ensureFlags()
end

function Library:SetFlag(name, value)
	assert(type(name) == "string", "[CrimsonLib] SetFlag: o nome da flag precisa ser string")
	if value ~= nil and not FLAG_TYPES[type(value)] then
		error("[CrimsonLib] SetFlag: tipo de valor não suportado (" .. type(value) .. ")", 2)
	end

	ensureFlags()
	FlagData[name] = value
	SaveFlags:Queue()

	-- mantém o elemento da interface em sincronia com a flag
	local bind = Library._flagBinds[name]
	if bind then
		pcall(bind, value)
	end
end

function Library:GetFlag(name, default)
	ensureFlags()
	local value = FlagData[name]
	if value == nil then
		return default
	end
	return value
end

function Library:HasFlag(name)
	ensureFlags()
	return FlagData[name] ~= nil
end

-- usado pelos elementos: mantém a UI em sincronia com SetFlag()
function Library:_registerFlag(name, setter)
	if type(name) ~= "string" or type(setter) ~= "function" then
		return
	end
	Library._flagBinds[name] = setter
end

function Library:GetFlags()
	ensureFlags()
	return FlagData
end

function Library:SaveFlags()
	SaveFlags:Flush()
end

function Library:DeleteFlags()
	table.clear(FlagData) -- os elementos continuam existindo, então os binds ficam
	deleteRaw(Library.Files.Flags)
	FlagsLoaded = true
end

-- keybinds: guardados como string (Enum.KeyCode.Name)
function Library:SetKeyFlag(flag, key)
	if type(flag) ~= "string" then
		return
	end
	self:SetFlag(flag .. "_Key", (typeof(key) == "EnumItem" and key.Name) or nil)
end

function Library:GetKeyFlag(flag, default)
	if type(flag) ~= "string" then
		return default
	end
	local name = self:GetFlag(flag .. "_Key")
	if type(name) ~= "string" then
		return default
	end
	local ok, key = pcall(function()
		return Enum.KeyCode[name]
	end)
	if ok and typeof(key) == "EnumItem" then
		return key
	end
	return default
end

----------------------------------------------------------------
-- SETTINGS  (LibrarySettings.json)
-- Posição da janela, estado minimizado etc.
----------------------------------------------------------------
local SettingData = {}
local SettingsLoaded = false

local SaveSettings = makeSaver(function()
	local data = jsonEncode(SettingData)
	if data then
		writeRaw(Library.Files.Settings, data)
	end
end)

local function ensureSettings()
	if SettingsLoaded then
		return
	end
	SettingsLoaded = true
	local data = jsonDecode(readRaw(Library.Files.Settings))
	if data then
		for key, value in pairs(data) do
			SettingData[key] = value
		end
	end
end

function Library:SetSetting(key, value)
	assert(type(key) == "string", "[CrimsonLib] SetSetting: a chave precisa ser string")
	ensureSettings()
	SettingData[key] = value
	SaveSettings:Queue()
end

function Library:GetSetting(key, default)
	ensureSettings()
	local value = SettingData[key]
	if value == nil then
		return default
	end
	return value
end

function Library:SaveSettings()
	SaveSettings:Flush()
end

function Library:LoadSettings()
	SettingsLoaded = false
	table.clear(SettingData)
	ensureSettings()
end

function Library:DeleteSettings()
	table.clear(SettingData)
	deleteRaw(Library.Files.Settings)
	SettingsLoaded = true
end

----------------------------------------------------------------
-- ÍCONES POR NOME  (Icons.lua)
-- Icon = "sword" | "Sword" | 123456 | "rbxassetid://123456"
----------------------------------------------------------------
local ICON_SEPARATORS = {}
do
	for _, char in ipairs({ " ", "_", "-", ".", ",", "/", "\\", "(", ")", "[", "]", ":", ";", "'", '"' }) do
		ICON_SEPARATORS[char] = true
	end
end

local IconsLoaded = false

local function normalizeIconName(name)
	return (string.lower(name):gsub(".", function(char)
		return ICON_SEPARATORS[char] and "" or char
	end))
end

local function importIcons(data)
	if type(data) ~= "table" then
		return false
	end
	local count = 0
	for key, value in pairs(data) do
		if type(key) == "string" then
			local id = type(value) == "string" and tonumber(value) or value
			if type(id) == "number" then
				Library.Icons[normalizeIconName(key)] = id
				count += 1
			end
		end
	end
	IconsLoaded = count > 0
	return IconsLoaded
end

local function httpGet(url)
	if typeof(game) == "Instance" and typeof(game.HttpGet) == "function" then
		local ok, result = pcall(function()
			return game:HttpGet(url)
		end)
		if ok and type(result) == "string" and #result > 0 then
			return result
		end
	end
	local ok, result = pcall(function()
		return HttpService:HttpGetAsync(url)
	end)
	if ok and type(result) == "string" and #result > 0 then
		return result
	end
	return nil
end

-- Carrega os ícones: primeiro o cache em arquivo, depois o GitHub
-- (quando baixa, salva o arquivo para as próximas execuções)
function Library:LoadIcons(force)
	if IconsLoaded and not force then
		return true
	end

	if not force then
		local cached = readRaw(self.Files.Icons)
		if cached and loadChunk then
			local chunk = loadChunk(cached)
			if chunk then
				local ok, result = pcall(chunk)
				if ok and importIcons(result) then
					return true
				end
			end
		end
	end

	local source = httpGet(self.IconsUrl)
	if source and loadChunk then
		local chunk = loadChunk(source)
		if chunk then
			local ok, result = pcall(chunk)
			if ok and importIcons(result) then
				writeRaw(self.Files.Icons, source)
				return true
			end
		end
	end

	if Library.Debug then
		warn("[CrimsonLib] não foi possível carregar a lista de ícones")
	end
	return false
end

-- força o download de uma lista nova de ícones
function Library:RefreshIcons()
	return self:LoadIcons(true)
end

-- ícones avulsos, sem precisar do arquivo
function Library:AddIcon(name, id)
	if type(name) ~= "string" then
		return
	end
	local value = type(id) == "string" and tonumber(id) or id
	if type(value) == "number" then
		Library.Icons[normalizeIconName(name)] = value
	end
end

function Library:AddIcons(list)
	if type(list) ~= "table" then
		return
	end
	for name, id in pairs(list) do
		self:AddIcon(name, id)
	end
end

function Library:GetIconList()
	local names = {}
	for name in pairs(Library.Icons) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

-- Converte o que o usuário passou em um asset utilizável (ou nil)
function Library:GetIcon(icon)
	if icon == nil then
		return nil
	end
	if typeof(icon) == "number" then
		return "rbxassetid://" .. tostring(icon)
	end
	if type(icon) ~= "string" or icon == "" then
		return nil
	end
	if icon:sub(1, 13) == "rbxassetid://" or icon:sub(1, 9) == "rbxasset://" or icon:sub(1, 7) == "http://" or icon:sub(1, 8) == "https://" then
		return icon
	end

	self:LoadIcons()

	local key = normalizeIconName(icon)
	local id = Library.Icons[key]
	if id then
		return "rbxassetid://" .. tostring(id)
	end
	-- busca parcial: "swordshield" encontra "sword" etc.
	for name, value in pairs(Library.Icons) do
		if name:find(key, 1, true) then
			return "rbxassetid://" .. tostring(value)
		end
	end
	if Library.Debug then
		warn("[CrimsonLib] ícone não encontrado: " .. tostring(icon))
	end
	return nil
end

----------------------------------------------------------------
-- ÍCONE DENTRO DOS ELEMENTOS
-- Devolve a largura ocupada (0 quando não há ícone)
----------------------------------------------------------------
local ICON_SIZE = 16
local ICON_GAP = 7
local ICON_INSET = 8
local TEXT_ICON_GAP = 4
local TITLE_ROW_INSET = 4

local function attachIcon(parent, opts, size, position, gap)
	if type(opts) ~= "table" then
		return 0
	end
	local asset = Library:GetIcon(opts.Icon)
	if not asset then
		return 0
	end

	local iconSize = size or ICON_SIZE
	create("ImageLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = position or UDim2.new(0, ICON_INSET, 0.5, 0),
		Size = UDim2.fromOffset(iconSize, iconSize),
		BackgroundTransparency = 1,
		Image = asset,
		ImageColor3 = opts.IconColor or Library.Theme.RedSoft,
		ZIndex = 5,
		Parent = parent,
	})
	return iconSize + (gap or ICON_GAP)
end

-- Corpo "vidro" usado por botões, toggles e sliders
local function glassBody(class, parent, props)
	local T = Library.Theme
	local base = {
		-- inset de 1px: a UIStroke (que desenha pra fora) não é cortada pelo ScrollingFrame
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.fromOffset(1, 1),
		BackgroundColor3 = T.Glass,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = parent,
	}
	if class == "TextButton" then
		base.AutoButtonColor = false
	end
	for k, v in pairs(props or {}) do
		base[k] = v
	end
	local body = create(class, base, {
		corner(10),
		create("UIStroke", { Color = T.RedBright, Thickness = 1.3, Transparency = 0.5 }),
	})
	return body, body:FindFirstChildOfClass("UIStroke")
end

local function hookHover(hit, body, stroke, solid)
	local baseBg = solid and 0.15 or 0.5
	local hoverBg = solid and 0 or 0.25
	local baseStroke = solid and 0.2 or 0.5
	hit.MouseEnter:Connect(function()
		tween(body, { BackgroundTransparency = hoverBg })
		tween(stroke, { Transparency = 0 })
	end)
	hit.MouseLeave:Connect(function()
		tween(body, { BackgroundTransparency = baseBg })
		tween(stroke, { Transparency = baseStroke })
	end)
end

local function formatNumber(v)
	return tostring(math.floor(v * 1000 + 0.5) / 1000)
end

-- Lista tudo que precisa de fade (fundo, texto, bordas, scrollbar)
local FADE_TIME = 0.28
local function fadeTargets(root)
	local list = {}
	local function add(inst)
		if inst:IsA("GuiObject") then
			table.insert(list, { inst, "BackgroundTransparency" })
			if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
				table.insert(list, { inst, "TextTransparency" })
				table.insert(list, { inst, "TextStrokeTransparency" })
			end
			if inst:IsA("ScrollingFrame") then
				table.insert(list, { inst, "ScrollBarImageTransparency" })
			end
		elseif inst:IsA("UIStroke") then
			table.insert(list, { inst, "Transparency" })
		end
	end
	add(root)
	for _, d in ipairs(root:GetDescendants()) do
		add(d)
	end
	return list
end

----------------------------------------------------------------
-- TOOLTIP
-- Uso: adicione Tooltip = "texto" em Button, Toggle ou Slider.
-- Aparece ao passar o mouse (após um pequeno atraso) e segue o cursor.
----------------------------------------------------------------
local TOOLTIP_MAX_W = 230
local TOOLTIP_DELAY = 0.35
local tooltip = nil
local tooltipToken = 0

local function ensureTooltip()
	if tooltip and tooltip.gui.Parent then
		return tooltip
	end

	local T = Library.Theme

	local gui = mountScreenGui("CrimsonLib_Tooltip", {
		IgnoreGuiInset = true, -- posição igual à do mouse
		DisplayOrder = 200,
	})

	local frame = create("Frame", {
		Size = UDim2.fromOffset(100, 30),
		BackgroundColor3 = T.Dark,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		Parent = gui,
	}, {
		corner(8),
		create("UIStroke", { Color = T.RedBright, Thickness = 1.2, Transparency = 1 }),
	})

	local label = create("TextLabel", {
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 1, -16),
		BackgroundTransparency = 1,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 1,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		Parent = frame,
	})

	tooltip = {
		gui = gui,
		frame = frame,
		label = label,
		stroke = frame:FindFirstChildOfClass("UIStroke"),
		visible = false,
		w = 100,
		h = 30,
	}
	return tooltip
end

local function placeTooltip(tt)
	local m = UserInputService:GetMouseLocation()
	local view = tt.gui.AbsoluteSize
	local x = m.X + 14
	local y = m.Y + 18
	if x + tt.w > view.X - 6 then
		x = m.X - tt.w - 10
	end
	if y + tt.h > view.Y - 6 then
		y = m.Y - tt.h - 12
	end
	tt.frame.Position = UDim2.fromOffset(math.max(6, x), math.max(6, y))
end

local function showTooltip(text)
	local tt = ensureTooltip()
	local bounds = TextService:GetTextSize(text, 12, Enum.Font.Gotham, Vector2.new(TOOLTIP_MAX_W - 20, 1000))
	tt.w = math.ceil(bounds.X) + 22
	tt.h = math.ceil(bounds.Y) + 16
	tt.frame.Size = UDim2.fromOffset(tt.w, tt.h)
	tt.label.Text = text
	tt.visible = true
	tt.frame.Visible = true
	placeTooltip(tt)
	tween(tt.frame, { BackgroundTransparency = 0.08 }, 0.15)
	tween(tt.stroke, { Transparency = 0.35 }, 0.15)
	tween(tt.label, { TextTransparency = 0 }, 0.15)
end

function Library.HideTooltip()
	tooltipToken += 1
	local tt = tooltip
	if not tt or not tt.visible then return end
	tt.visible = false
	tween(tt.frame, { BackgroundTransparency = 1 }, 0.12)
	tween(tt.stroke, { Transparency = 1 }, 0.12)
	tween(tt.label, { TextTransparency = 1 }, 0.12)
	task.delay(0.14, function()
		if not tt.visible then
			tt.frame.Visible = false
		end
	end)
end

local function attachTooltip(obj, text)
	if type(text) ~= "string" or text == "" then return end

	obj.MouseEnter:Connect(function()
		tooltipToken += 1
		local token = tooltipToken
		task.delay(TOOLTIP_DELAY, function()
			if token == tooltipToken then
				showTooltip(text)
			end
		end)
	end)

	obj.MouseMoved:Connect(function()
		if tooltip and tooltip.visible then
			placeTooltip(tooltip)
		end
	end)

	obj.MouseLeave:Connect(Library.HideTooltip)
end

----------------------------------------------------------------
-- CRIAR JANELA
----------------------------------------------------------------
-- Dimensões de referência convertidas para UDim2.Scale; o layout pai aplica a
-- escala conforme o espaço disponível, sem ler CurrentCamera.ViewportSize.
local SCALE_REFERENCE_WIDTH = 1280
local SCALE_REFERENCE_HEIGHT = 720
local MIN_WINDOW_WIDTH_SCALE = 0.1
local MAX_WINDOW_WIDTH_SCALE = 0.5

local function computeWindowWidthScale(width)
	return math.clamp(width / SCALE_REFERENCE_WIDTH, MIN_WINDOW_WIDTH_SCALE, MAX_WINDOW_WIDTH_SCALE)
end

local function computeWindowHeightScale(height)
	return height / SCALE_REFERENCE_HEIGHT
end

-- Mantém a janela inteira visível usando o tamanho real do container de UI.
local function clampWindowPosition(position, frame, bounds)
	local viewSize = bounds.AbsoluteSize
	local frameSize = frame.AbsoluteSize
	if viewSize.X <= 0 or viewSize.Y <= 0 or frameSize.X <= 0 or frameSize.Y <= 0 then
		return position
	end

	local absoluteX = position.X.Scale * viewSize.X + position.X.Offset
	local absoluteY = position.Y.Scale * viewSize.Y + position.Y.Offset
	local minX = frameSize.X * frame.AnchorPoint.X
	local maxX = viewSize.X - frameSize.X * (1 - frame.AnchorPoint.X)
	local minY = frameSize.Y * frame.AnchorPoint.Y
	local maxY = viewSize.Y - frameSize.Y * (1 - frame.AnchorPoint.Y)

	if maxX < minX then minX, maxX = viewSize.X / 2, viewSize.X / 2 end
	if maxY < minY then minY, maxY = viewSize.Y / 2, viewSize.Y / 2 end
	absoluteX = math.clamp(absoluteX, minX, maxX)
	absoluteY = math.clamp(absoluteY, minY, maxY)

	return UDim2.new(
		position.X.Scale, absoluteX - position.X.Scale * viewSize.X,
		position.Y.Scale, absoluteY - position.Y.Scale * viewSize.Y
	)
end


--[[
	Library.new({
		Title = "CRIMSON PANEL",      -- título da barra
		Subtitle = "v1.0",            -- subtítulo (opcional)
		Name = "CrimsonLib",          -- nome da ScreenGui
		Folder = "CrimsonLib",        -- pasta no workspace do executor
		Icon = "flame",               -- ícone na barra de título (por nome ou id)
		Width = 300,                   -- largura de referência (layout 1280x720)
		MaxHeight = 360,               -- altura máxima de referência
		ToggleKey = Enum.KeyCode.RightShift,
		Parent = nil,                 -- força outro container (padrão: CoreGui)
		Particles = true,
		SavePosition = true,          -- salva/minimizado em LibrarySettings.json
		PreloadIcons = true,          -- baixa a lista de ícones antes de montar a UI
		Debug = false,
	})
]]
function Library.new(config)
	config = config or {}
	local T = Library.Theme
	local self = setmetatable({}, Window)

	-- pasta onde ficam Icons.lua / ScriptFlags.json / LibrarySettings.json
	if type(config.Folder) == "string" and config.Folder ~= "" and config.Folder ~= Library.Folder then
		Library.Folder = config.Folder
		if FlagsLoaded then
			Library:LoadFlags()
		end
		if SettingsLoaded then
			Library:LoadSettings()
		end
	end
	if config.Parent then
		Library:SetGuiParent(config.Parent)
	end
	if config.Debug ~= nil then
		Library.Debug = config.Debug and true or false
	end
	if config.SavePosition ~= nil then
		Library.SavePosition = config.SavePosition and true or false
	end
	if type(config.IconsUrl) == "string" and config.IconsUrl ~= "" then
		Library.IconsUrl = config.IconsUrl
	end

	-- ícones: usa o cache do arquivo quando existe, senão baixa e salva
	if config.PreloadIcons ~= false then
		Library:LoadIcons()
	end

	self._conns = {}
	self._binds = {}
	self._listening = false
	self._minimized = false
	self._destroyed = false
	self._visible = true
	self._fading = false
	self._canScroll = false
	self._dragging = false
	self._order = 0
	self._width = config.Width or 300
	self._maxHeight = config.MaxHeight or 360
	self._fullH = TITLE_H + MIN_BODY
	self._h = self._fullH

	local WIDTH = self._width
	local guiName = config.Name or "CrimsonLib"

	-- ScreenGui criada no CoreGui (gethui -> CoreGui -> PlayerGui)
	local screenGui = mountScreenGui(guiName, {})
	self.Gui = screenGui

	local widthScale = computeWindowWidthScale(WIDTH)
	self._widthScale = widthScale

	-- Container que ocupa a área da ScreenGui; as dimensões da janela usam Scale.
	local screenBounds = create("Frame", {
		Name = "ScreenBounds",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = screenGui,
	})
	self._screenBounds = screenBounds

	-- A versão anterior salvava a origem no canto superior esquerdo; converte
	-- esses valores para o novo ponto de ancoragem central uma única vez.
	local startPos = UDim2.fromScale(0.5, 0.5)
	local savedPos = Library.SavePosition and Library:GetSetting("Position")
	local savedPositionFormat = Library.SavePosition and Library:GetSetting("PositionFormat")
	if type(savedPos) == "table" and type(savedPos[2]) == "number" and type(savedPos[4]) == "number" then
		if savedPositionFormat == "scale-center" then
			startPos = UDim2.new(savedPos[1] or 0, savedPos[2], savedPos[3] or 0, savedPos[4])
		else
			startPos = UDim2.new(
				savedPos[1] or 0, savedPos[2] + WIDTH / 2,
				savedPos[3] or 0, savedPos[4] + self._maxHeight / 2
			)
		end
	end

	local aspectConstraint = create("UIAspectRatioConstraint", {
		AspectRatio = WIDTH / self._h,
		AspectType = Enum.AspectType.FitWithinMaxSize,
		DominantAxis = Enum.DominantAxis.Width,
	})
	local positionFrame = create("Frame", {
		Name = "WindowPositioner",
		Size = UDim2.new(widthScale, 0, computeWindowHeightScale(self._h), 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = startPos + UDim2.fromOffset(0, 14),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = screenBounds,
	}, { aspectConstraint })
	self._positionFrame = positionFrame
	self._aspectConstraint = aspectConstraint

	local main = create("Frame", {
		Name = "Main",
		Size = UDim2.fromOffset(WIDTH, self._h),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = positionFrame,
	}, {
		corner(14),
		gradient(Color3.fromRGB(150, 15, 35), T.Dark, 120),
		create("UIScale", { Scale = 1 }),
	})
	self.Main = main

	local uiScale = main:FindFirstChildOfClass("UIScale")
	self._uiScale = uiScale

	-- O conteúdo é dimensionado pela largura efetiva do container de UI.
	local function updateContentScale()
		local width = positionFrame.AbsoluteSize.X
		if width > 0 then
			uiScale.Scale = width / WIDTH
		end
	end
	updateContentScale()
	table.insert(self._conns, positionFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		updateContentScale()
		positionFrame.Position = clampWindowPosition(positionFrame.Position, positionFrame, screenBounds)
	end))

	-- Borda com brilho girando
	local stroke = create("UIStroke", {
		Color = Color3.new(1, 1, 1),
		Thickness = 2,
		Transparency = 0.15,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = main,
	})
	local strokeGradient = create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, T.RedBright),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 0, 12)),
			ColorSequenceKeypoint.new(1, T.RedBright),
		}),
		Parent = stroke,
	})

	-- Partículas
	local particleLayer = create("Frame", {
		Name = "Particles",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = main,
	})
	self._particleLayer = particleLayer

	-- Brilho do topo
	create("Frame", {
		Name = "Shine",
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = main,
	}, {
		corner(14),
		create("UIGradient", { Transparency = NumberSequence.new(0, 1), Rotation = 90 }),
	})

	----------------------------------------------------------------
	-- BARRA DE TÍTULO
	----------------------------------------------------------------
	local titleBar = create("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, TITLE_H),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 5,
		Parent = main,
	})

	local titleBg = create("Frame", {
		Name = "TitleBg",
		Size = UDim2.new(1, 0, 0, TITLE_H + 20),
		BackgroundColor3 = T.Glass,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = titleBar,
	}, { corner(14) })

	self._divider = create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = T.RedBright,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = titleBar,
	})

	local dot = create("Frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.new(0, 10, 0.5, -4),
		BackgroundColor3 = T.RedBright,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = titleBar,
	}, { corner(4) })

	-- ícone da barra de título (nome do ícone ou id)
	local windowIcon = Library:GetIcon(config.Icon)
	if windowIcon then
		dot.Visible = false
		create("ImageLabel", {
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.new(0, ICON_INSET, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = windowIcon,
			ImageColor3 = config.IconColor or T.RedBright,
			ZIndex = 6,
			Parent = titleBar,
		})
	end

	task.spawn(function()
		while dot.Parent do
			tween(dot, { BackgroundTransparency = 0.7 }, 0.8, Enum.EasingStyle.Sine)
			task.wait(0.8)
			tween(dot, { BackgroundTransparency = 0 }, 0.8, Enum.EasingStyle.Sine)
			task.wait(0.8)
		end
	end)

	local titleHolder = create("Frame", {
		Size = UDim2.new(1, -110, 1, 0),
		Position = UDim2.new(0, 26, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = titleBar,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 7),
		}),
	})

	local titleLabel = create("TextLabel", {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Text = config.Title or "CRIMSON  PANEL",
		TextColor3 = T.Text,
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		ZIndex = 6,
		Parent = titleHolder,
	})
	self._titleLabel = titleLabel

	-- Subtítulo: menor e com degradê de branco para cinza
	local hasSubtitle = config.Subtitle ~= nil and config.Subtitle ~= ""
	local subtitleLabel = create("TextLabel", {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Text = config.Subtitle or "",
		Visible = hasSubtitle,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.Gotham,
		TextSize = 11,
		ZIndex = 6,
		Parent = titleHolder,
	}, {
		create("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 210)),
			Rotation = 0,
		}),
	})
	self._subtitleLabel = subtitleLabel

	local function titleButton(text, xOffset)
		local btn = create("TextButton", {
			Size = UDim2.fromOffset(24, 24),
			Position = UDim2.new(1, xOffset, 0.5, -12),
			BackgroundColor3 = T.Red,
			BackgroundTransparency = 0.6,
			Text = text,
			TextColor3 = T.Text,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = titleBar,
		}, {
			corner(7),
			create("UIStroke", { Color = T.RedBright, Transparency = 0.6, Thickness = 1 }),
		})
		btn.MouseEnter:Connect(function()
			tween(btn, { BackgroundTransparency = 0.1, BackgroundColor3 = T.RedBright })
		end)
		btn.MouseLeave:Connect(function()
			tween(btn, { BackgroundTransparency = 0.6, BackgroundColor3 = T.Red })
		end)
		return btn
	end

	local closeBtn = titleButton("×", -34)
	local minBtn = titleButton("–", -64)

	----------------------------------------------------------------
	-- ÁREA DE CONTEÚDO (scroll)
	----------------------------------------------------------------
	local layout = create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	local scroll = create("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.new(0, 12, 0, TITLE_H + PAD_TOP),
		Size = UDim2.new(1, -18, 1, -(TITLE_H + PAD_TOP + PAD_BOTTOM)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollBarImageColor3 = T.RedBright,
		ScrollBarImageTransparency = 0.2,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		ZIndex = 2,
		Parent = main,
	}, {
		layout,
		create("UIPadding", { PaddingRight = UDim.new(0, 6) }),
	})

	self._scroll = scroll
	self._layout = layout
	self._titleBg = titleBg
	self._minBtn = minBtn

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self:_refresh()
	end)

	----------------------------------------------------------------
	-- PARTÍCULAS (loop)
	----------------------------------------------------------------
	local rng = Random.new()
	local particles = {}
	local particleCount = config.Particles == false and 0 or 22

	local function resetParticle(p, anywhere)
		local h = self._h
		p.x = rng:NextNumber(18, WIDTH - 18)
		p.y = anywhere and rng:NextNumber(0, h) or (h + p.size)
		p.speed = rng:NextNumber(12, 38)
		p.drift = rng:NextNumber(4, 14)
		p.phase = rng:NextNumber(0, math.pi * 2)
	end

	for _ = 1, particleCount do
		local size = rng:NextInteger(2, 6)
		local frame = create("Frame", {
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = rng:NextNumber() > 0.5 and T.RedBright or T.RedSoft,
			BackgroundTransparency = rng:NextNumber(0.35, 0.8),
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = particleLayer,
		}, { corner(size) })
		local p = { frame = frame, size = size }
		resetParticle(p, true)
		table.insert(particles, p)
	end

	local t = 0
	table.insert(self._conns, RunService.RenderStepped:Connect(function(dt)
		t += dt
		strokeGradient.Rotation = (t * 60) % 360
		if self._minimized then return end
		for _, p in ipairs(particles) do
			p.y -= p.speed * dt
			if p.y < -p.size then
				resetParticle(p, false)
			end
			p.frame.Position = UDim2.fromOffset(p.x + math.sin(t + p.phase) * p.drift, p.y)
		end
	end))

	----------------------------------------------------------------
	-- MINIMIZAR / FECHAR
	----------------------------------------------------------------
	minBtn.MouseButton1Click:Connect(function()
		self:SetMinimized(not self._minimized)
	end)

	closeBtn.MouseButton1Click:Connect(function()
		self:Destroy(true)
	end)

	----------------------------------------------------------------
	-- ARRASTAR
	----------------------------------------------------------------
	local dragging, dragStart, startFramePos
	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startFramePos = positionFrame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					if dragging then
						dragging = false
						self:_savePosition()
					end
				end
			end)
		end
	end)

	table.insert(self._conns, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			positionFrame.Position = clampWindowPosition(UDim2.new(
				startFramePos.X.Scale, startFramePos.X.Offset + delta.X,
				startFramePos.Y.Scale, startFramePos.Y.Offset + delta.Y
			), positionFrame, screenBounds)
		end
	end))

	----------------------------------------------------------------
	-- KEYBINDS GLOBAIS
	----------------------------------------------------------------
	table.insert(self._conns, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if self._listening or gameProcessed then return end

		if config.ToggleKey and input.KeyCode == config.ToggleKey then
			self:ToggleVisible()
			return
		end

		for _, bind in ipairs(self._binds) do
			if bind.data.Key and bind.data.Key == input.KeyCode then
				task.spawn(bind.fn)
			end
		end
	end))

	-- Animação de entrada
	tween(positionFrame, { Position = startPos }, 0.4, Enum.EasingStyle.Quart)
	tween(main, { BackgroundTransparency = 0.28 }, 0.4, Enum.EasingStyle.Quart)

	-- volta minimizado se era assim que estava na última execução
	if Library.SavePosition and Library:GetSetting("Minimized") == true then
		task.defer(function()
			if not self._destroyed then
				self:SetMinimized(true)
			end
		end)
	end

	return self
end

----------------------------------------------------------------
-- LAYOUT / TAMANHO AUTOMÁTICO
----------------------------------------------------------------
function Window:_applyScroll()
	self._scroll.ScrollingEnabled = self._canScroll and not self._dragging
end

function Window:_setHeight(height, duration)
	local ratio = self._width / math.max(height, 1)
	local size = UDim2.fromOffset(self._width, height)
	local scaledBounds = UDim2.new(self._widthScale, 0, computeWindowHeightScale(height), 0)
	if duration and duration > 0 then
		tween(self.Main, { Size = size }, duration, Enum.EasingStyle.Quart)
		tween(self._positionFrame, { Size = scaledBounds }, duration, Enum.EasingStyle.Quart)
		tween(self._aspectConstraint, { AspectRatio = ratio }, duration, Enum.EasingStyle.Quart)
	else
		self.Main.Size = size
		self._positionFrame.Size = scaledBounds
		self._aspectConstraint.AspectRatio = ratio
	end
end

function Window:_refresh()
	if self._refreshQueued or self._destroyed then return end
	self._refreshQueued = true
	task.defer(function()
		self._refreshQueued = false
		if self._destroyed then return end

		local scale = math.max(self._uiScale.Scale, 0.001)
		local contentHeight = self._layout.AbsoluteContentSize.Y / scale
		local needed = TITLE_H + PAD_TOP + contentHeight + PAD_BOTTOM
		local target = math.clamp(needed, TITLE_H + MIN_BODY, self._maxHeight)

		self._fullH = target
		self._canScroll = needed > self._maxHeight + 0.5
		self._scroll.ScrollBarThickness = self._canScroll and 3 or 0
		self:_applyScroll()

		if not self._minimized then
			self._h = target
			self:_setHeight(target, 0.25)
		end
	end)
end

-- Guarda a posição da janela em LibrarySettings.json
-- atalhos: Win:SetFlag / Win:GetFlag usam as flags globais
function Window:SetFlag(name, value)
	return Library:SetFlag(name, value)
end

function Window:GetFlag(name, default)
	return Library:GetFlag(name, default)
end

function Window:GetKeyFlag(flag, default)
	return Library:GetKeyFlag(flag, default)
end

-- Guarda a posição da janela em LibrarySettings.json
function Window:_savePosition()
	if not Library.SavePosition or self._destroyed then
		return
	end
	local position = self._positionFrame.Position
	Library:SetSetting("Position", { position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset })
	Library:SetSetting("PositionFormat", "scale-center")
end

function Window:SetMinimized(state)
	self._minimized = state and true or false
	Library.HideTooltip()
	if Library.SavePosition then
		Library:SetSetting("Minimized", self._minimized)
	end
	self._minBtn.Text = self._minimized and "+" or "–"
	self._scroll.Visible = not self._minimized
	self._particleLayer.Visible = not self._minimized
	self._divider.Visible = not self._minimized
	-- minimizado: fundo da barra com altura exata (cantos de baixo redondos)
	self._titleBg.Size = UDim2.new(1, 0, 0, self._minimized and TITLE_H or TITLE_H + 20)

	local h = self._minimized and TITLE_H or self._fullH
	self._h = h
	self:_setHeight(h, 0.3)
end

function Window:SetTitle(text)
	self._titleLabel.Text = text
end

function Window:SetSubtitle(text)
	self._subtitleLabel.Text = text or ""
	self._subtitleLabel.Visible = text ~= nil and text ~= ""
end

-- Mostra/esconde a janela com animação de fade + leve deslize
function Window:SetVisible(state)
	state = state and true or false
	if self._destroyed or self._fading or state == self._visible then return end
	self._fading = true

	local main = self.Main
	local positionFrame = self._positionFrame

	Library.HideTooltip()

	if not state then
		-- some: guarda os valores originais e leva tudo a 100% transparente
		local snapshot = {}
		for _, item in ipairs(fadeTargets(main)) do
			local inst, prop = item[1], item[2]
			table.insert(snapshot, { inst, prop, inst[prop] })
			tween(inst, { [prop] = 1 }, FADE_TIME)
		end
		self._snapshot = snapshot
		self._shownPos = positionFrame.Position
		tween(positionFrame, { Position = positionFrame.Position + UDim2.fromOffset(0, 12) }, FADE_TIME)

		task.delay(FADE_TIME + 0.03, function()
			if self._destroyed then return end
			self.Gui.Enabled = false
			self._visible = false
			self._fading = false
		end)
	else
		-- aparece: volta aos valores originais subindo de leve
		self.Gui.Enabled = true
		local shownPos = self._shownPos or positionFrame.Position
		positionFrame.Position = shownPos + UDim2.fromOffset(0, 12)
		for _, s in ipairs(self._snapshot or {}) do
			if s[1].Parent then
				tween(s[1], { [s[2]] = s[3] }, FADE_TIME)
			end
		end
		tween(positionFrame, { Position = shownPos }, FADE_TIME)

		task.delay(FADE_TIME + 0.03, function()
			if self._destroyed then return end
			self._visible = true
			self._fading = false
		end)
	end
end

function Window:ToggleVisible()
	self:SetVisible(not self._visible)
end

function Window:Destroy(animated)
	if self._destroyed then return end
	self._destroyed = true
	Library.HideTooltip()

	-- grava no disco o que ainda estiver pendente
	Library:SaveFlags()
	Library:SaveSettings()

	for _, c in ipairs(self._conns) do
		c:Disconnect()
	end
	self._conns = {}

	local gui = self.Gui
	if animated and gui.Parent then
		self:_setHeight(TITLE_H, 0.2)
		tween(self._positionFrame, {
			Position = self._positionFrame.Position + UDim2.fromOffset(0, 10),
		}, 0.2)
		tween(self.Main, { BackgroundTransparency = 1 }, 0.2)
		task.delay(0.22, function()
			gui:Destroy()
		end)
	else
		gui:Destroy()
	end
end

----------------------------------------------------------------
-- ELEMENTOS: helpers internos
----------------------------------------------------------------
function Window:_nextOrder()
	self._order += 1
	return self._order
end

function Window:_row(height)
	return create("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = self:_nextOrder(),
		Parent = self._scroll,
	})
end

----------------------------------------------------------------
-- POPUP DE KEYBIND
----------------------------------------------------------------
function Window:_openKeyPopup(label, keyData, onChange)
	if self._popup or self._destroyed then return end
	Library.HideTooltip()
	self._listening = true
	local T = Library.Theme

	local overlay = create("TextButton", {
		Name = "KeybindOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 50,
		Parent = self.Gui,
	})
	self._popup = overlay
	tween(overlay, { BackgroundTransparency = 0.55 }, 0.2)

	local card = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 14),
		Size = UDim2.fromOffset(260, 168),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Active = true, -- não deixa o clique atravessar para o overlay
		ZIndex = 51,
		Parent = overlay,
	}, {
		corner(14),
		gradient(Color3.fromRGB(150, 15, 35), T.Dark, 120),
		create("UIStroke", { Color = T.RedBright, Thickness = 1.6, Transparency = 0.1 }),
	})
	tween(card, { Position = UDim2.new(0.5, 0, 0.5, 0) }, 0.25, Enum.EasingStyle.Back)

	local function label_(props)
		local base = {
			BackgroundTransparency = 1,
			TextColor3 = T.Text,
			ZIndex = 52,
			Parent = card,
		}
		for k, v in pairs(props) do base[k] = v end
		return create("TextLabel", base)
	end

	label_({
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.new(0, 12, 0, 12),
		Text = "DEFINIR KEYBIND",
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	label_({
		Size = UDim2.new(1, -24, 0, 14),
		Position = UDim2.new(0, 12, 0, 30),
		Text = label,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = T.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	-- caixa da tecla
	local keyBox = create("Frame", {
		Size = UDim2.new(1, -24, 0, 50),
		Position = UDim2.new(0, 12, 0, 54),
		BackgroundColor3 = T.Glass,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 52,
		Parent = card,
	}, {
		corner(10),
		create("UIStroke", { Color = T.RedBright, Thickness = 1.3, Transparency = 0.3 }),
	})

	local keyLabel = create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		TextColor3 = T.Text,
		ZIndex = 53,
		Parent = keyBox,
	})

	local hint = label_({
		Size = UDim2.new(1, -24, 0, 14),
		Position = UDim2.new(0, 12, 0, 108),
		Text = "",
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = T.RedSoft,
	})

	local function refresh(text)
		keyLabel.Text = keyData.Key and keyData.Key.Name or "—"
		hint.Text = text or "Pressione uma tecla...  (ESC cancela)"
	end
	refresh()

	local closed = false
	local captured = false
	local conn

	local function close()
		if closed then return end
		closed = true
		if conn then conn:Disconnect() end
		tween(overlay, { BackgroundTransparency = 1 }, 0.15)
		tween(card, { Position = UDim2.new(0.5, 0, 0.5, 14) }, 0.15)
		task.delay(0.16, function()
			overlay:Destroy()
			self._popup = nil
			self._listening = false
		end)
	end

	local function popupButton(text, xScale, xOff, callback)
		local btn = create("TextButton", {
			Size = UDim2.new(0.5, -17, 0, 28),
			Position = UDim2.new(xScale, xOff, 1, -40),
			BackgroundColor3 = T.Glass,
			BackgroundTransparency = 0.45,
			Text = text,
			TextColor3 = T.Text,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 52,
			Parent = card,
		}, {
			corner(8),
			create("UIStroke", { Color = T.RedBright, Thickness = 1.2, Transparency = 0.4 }),
		})
		local s = btn:FindFirstChildOfClass("UIStroke")
		btn.MouseEnter:Connect(function()
			tween(btn, { BackgroundTransparency = 0.15 })
			tween(s, { Transparency = 0 })
		end)
		btn.MouseLeave:Connect(function()
			tween(btn, { BackgroundTransparency = 0.45 })
			tween(s, { Transparency = 0.4 })
		end)
		btn.MouseButton1Click:Connect(callback)
		return btn
	end

	popupButton("Limpar", 0, 12, function()
		if closed or captured then return end
		captured = true
		keyData.Key = nil
		onChange(nil)
		refresh("Keybind removida")
		task.delay(0.3, close)
	end)
	popupButton("Fechar", 0.5, 5, close)

	overlay.MouseButton1Click:Connect(close)

	conn = UserInputService.InputBegan:Connect(function(input)
		if closed or captured then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if input.KeyCode == Enum.KeyCode.Escape then
			close()
			return
		end
		if input.KeyCode == Enum.KeyCode.Unknown then return end

		captured = true
		keyData.Key = input.KeyCode
		onChange(input.KeyCode)
		refresh("Tecla definida!")
		task.delay(0.4, close)
	end)
end

-- Cria o botão de keybind ao lado de um elemento (se opts.Keybind estiver ativo)
-- Retorna: handle (ou nil), largura usada
function Window:_attachKeybind(row, body, opts, trigger)
	local hasKey = opts.Keybind ~= nil and opts.Keybind ~= false
	if not hasKey then return nil end

	local T = Library.Theme
	local keyData = { Key = nil }
	if typeof(opts.Keybind) == "EnumItem" then
		keyData.Key = opts.Keybind
	end

	-- a tecla é salva em "<Flag>_Key" dentro de ScriptFlags.json
	local flag = type(opts.Flag) == "string" and opts.Flag or nil
	if flag then
		local savedKey = Library:GetKeyFlag(flag)
		if savedKey then
			keyData.Key = savedKey
		end
	end

	body.Size = UDim2.new(1, -(KEY_W + 7), 1, -2)

	local keyBtn, keyStroke = glassBody("TextButton", row, {
		Name = "KeybindButton",
		Size = UDim2.new(0, KEY_W, 1, -2),
		Position = UDim2.new(1, -(KEY_W + 1), 0, 1),
		Text = "",
		TextColor3 = T.Text,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
	})
	create("UITextSizeConstraint", { MaxTextSize = 12, MinTextSize = 8, Parent = keyBtn })
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		Parent = keyBtn,
	})
	hookHover(keyBtn, keyBtn, keyStroke, false)
	attachTooltip(keyBtn, opts.KeybindTooltip or "Clique para definir uma tecla de atalho")

	local handle = {}

	local function updateText()
		if keyData.Key then
			keyBtn.Text = keyData.Key.Name
			keyBtn.TextColor3 = T.Text
		else
			keyBtn.Text = "KEY"
			keyBtn.TextColor3 = T.SubText
		end
	end
	updateText()

	local function changed(key)
		updateText()
		if flag then
			Library:SetKeyFlag(flag, key)
		end
		pcallCallback(opts.KeybindChanged, key)
	end

	keyBtn.MouseButton1Click:Connect(function()
		self:_openKeyPopup(opts.Name or "Keybind", keyData, changed)
	end)

	table.insert(self._binds, { data = keyData, fn = trigger })

	function handle.GetKey()
		return keyData.Key
	end
	function handle.SetKey(key)
		keyData.Key = key
		changed(key)
	end

	return handle
end

----------------------------------------------------------------
-- ELEMENTOS PÚBLICOS
----------------------------------------------------------------
-- Aceita "texto", ("texto", "icone") ou ({ Text = "...", Icon = "..." })
function Window:Title(text, icon)
	local T = Library.Theme
	local opts = type(text) == "table" and text or { Text = text, Icon = icon }
	-- ícone na mesma cor do ícone da barra de título
	opts.IconColor = opts.IconColor or T.RedBright

	local row = self:_row(24)
	-- Aproxima o ícone e o texto da borda esquerda da janela.
	local iconPosition = UDim2.new(0, TITLE_ROW_INSET, 0.5, 0)
	local iconWidth = attachIcon(row, opts, 17, iconPosition, TEXT_ICON_GAP)
	local textOffset = TITLE_ROW_INSET + iconWidth

	local label = create("TextLabel", {
		Size = UDim2.new(1, -textOffset, 0, 24),
		Position = UDim2.new(0, textOffset, 0, 0),
		BackgroundTransparency = 1,
		Text = opts.Text or opts.Name or "",
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Enum.Font.GothamBlack,
		TextSize = 17,
		Parent = row,
	})
	return { Set = function(v) label.Text = v end }
end

function Window:Subtitle(text, icon)
	local T = Library.Theme
	local opts = type(text) == "table" and text or { Text = text, Icon = icon }
	-- ícone na mesma cor do ícone da barra de título
	opts.IconColor = opts.IconColor or T.RedBright

	local row = self:_row(18)
	-- Aproxima o ícone e o texto da borda esquerda da janela.
	local iconPosition = UDim2.new(0, TITLE_ROW_INSET, 0.5, 0)
	local iconWidth = attachIcon(row, opts, 14, iconPosition, TEXT_ICON_GAP)
	local textOffset = TITLE_ROW_INSET + iconWidth

	local label = create("TextLabel", {
		Size = UDim2.new(1, -textOffset, 0, 18),
		Position = UDim2.new(0, textOffset, 0, 0),
		BackgroundTransparency = 1,
		Text = opts.Text or opts.Name or "",
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Parent = row,
	})
	return { Set = function(v) label.Text = v end }
end

function Window:Paragraph(text)
	local T = Library.Theme
	local label = create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = T.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		LayoutOrder = self:_nextOrder(),
		Parent = self._scroll,
	})
	return { Set = function(v) label.Text = v end }
end

function Window:Separator()
	local T = Library.Theme
	local row = self:_row(1)
	create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = T.RedBright,
		BackgroundTransparency = 0.65,
		BorderSizePixel = 0,
		Parent = row,
	})
end

function Window:Button(opts)
	opts = opts or {}
	local T = Library.Theme
	local row = self:_row(38)

	-- O texto fica numa label separada: um UIGradient no botão tingiria o texto de vermelho
	local body, bodyStroke = glassBody("TextButton", row, {
		Text = "",
		BackgroundColor3 = opts.Primary and Color3.new(1, 1, 1) or T.Glass,
		BackgroundTransparency = opts.Primary and 0.15 or 0.5,
	})
	local label = create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = opts.Name or "Botão",
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = Color3.fromRGB(35, 0, 6),
		TextStrokeTransparency = 0.7,
		Font = opts.Primary and Enum.Font.GothamBold or Enum.Font.GothamMedium,
		TextSize = 13,
		Interactable = false,
		ZIndex = 4,
		Parent = body,
	})

	-- ícone (nome ou id): o texto continua centralizado
	local buttonIconWidth = attachIcon(body, opts)
	if buttonIconWidth > 0 then
		create("UIPadding", {
			PaddingLeft = UDim.new(0, buttonIconWidth),
			PaddingRight = UDim.new(0, buttonIconWidth),
			Parent = label,
		})
	end
	if opts.Primary then
		gradient(T.RedBright, Color3.fromRGB(150, 10, 30), 90).Parent = body
		bodyStroke.Transparency = 0.2
	end
	hookHover(body, body, bodyStroke, opts.Primary)
	attachTooltip(body, opts.Tooltip)

	local function fire()
		pcallCallback(opts.Callback)
		-- flash de feedback
		local prev = body.BackgroundTransparency
		body.BackgroundTransparency = 0
		tween(body, { BackgroundTransparency = prev }, 0.25)
	end

	body.MouseButton1Click:Connect(fire)

	local handle = self:_attachKeybind(row, body, opts, fire) or {}
	handle.Fire = fire
	handle.SetText = function(text)
		label.Text = text
	end
	return handle
end

function Window:Toggle(opts)
	opts = opts or {}
	local T = Library.Theme
	local row = self:_row(38)

	local body, bodyStroke = glassBody("Frame", row)

	local iconWidth = attachIcon(body, opts)

	create("TextLabel", {
		Size = UDim2.new(1, -(60 + iconWidth), 1, 0),
		Position = UDim2.new(0, ICON_INSET + iconWidth, 0, 0),
		BackgroundTransparency = 1,
		Text = opts.Name or "Toggle",
		TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		ZIndex = 3,
		Parent = body,
	})

	local switch = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(38, 20),
		BackgroundColor3 = T.SwitchOff,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = body,
	}, { corner(10) })

	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = T.Text,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = switch,
	}, { corner(7) })

	local hit = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 5,
		Parent = body,
	})
	hookHover(hit, body, bodyStroke, false)
	attachTooltip(hit, opts.Tooltip)

	-- valor inicial: Default, ou o que estiver salvo na flag
	local flag = type(opts.Flag) == "string" and opts.Flag or nil
	local state = opts.Default and true or false
	if flag then
		local saved = Library:GetFlag(flag)
		if type(saved) == "boolean" then
			state = saved
		end
	end

	local function render(animated)
		local info = animated and 0.18 or 0
		local goalColor = state and T.RedBright or T.SwitchOff
		local goalPos = state and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		if animated then
			tween(switch, { BackgroundColor3 = goalColor }, info)
			tween(knob, { Position = goalPos }, info, Enum.EasingStyle.Back)
		else
			switch.BackgroundColor3 = goalColor
			knob.Position = goalPos
		end
	end

	local function set(value, silent)
		state = value and true or false
		render(true)
		if not silent then
			if flag then
				Library:SetFlag(flag, state)
			end
			pcallCallback(opts.Callback, state)
		end
	end

	local function flip()
		set(not state)
	end

	hit.MouseButton1Click:Connect(flip)

	render(false)

	-- SetFlag() externo também mexe no toggle da interface
	if flag then
		Library:_registerFlag(flag, function(value)
			if type(value) == "boolean" and value ~= state then
				set(value, true)
			end
		end)
	end

	local handle = self:_attachKeybind(row, body, opts, flip) or {}
	handle.Set = set
	handle.Get = function()
		return state
	end
	return handle
end

function Window:Slider(opts)
	opts = opts or {}
	local T = Library.Theme
	local min = opts.Min or 0
	local max = opts.Max or 100
	local inc = opts.Increment or 1
	local suffix = opts.Suffix or ""
	local row = self:_row(52)

	local body, bodyStroke = glassBody("Frame", row)

	-- O título do slider fica no topo do controle; alinhe o ícone ao texto.
	local iconWidth = attachIcon(body, opts, nil, UDim2.new(0, ICON_INSET, 0, 16))

	create("TextLabel", {
		Size = UDim2.new(0.6, -(ICON_INSET + iconWidth), 0, 16),
		Position = UDim2.new(0, ICON_INSET + iconWidth, 0, 8),
		BackgroundTransparency = 1,
		Text = opts.Name or "Slider",
		TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		ZIndex = 3,
		Parent = body,
	})

	local valueLabel = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.new(0.4, -12, 0, 16),
		Position = UDim2.new(1, -12, 0, 8),
		BackgroundTransparency = 1,
		TextColor3 = T.RedSoft,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		ZIndex = 3,
		Parent = body,
	})

	local track = create("Frame", {
		Position = UDim2.new(0, 12, 0, 34),
		Size = UDim2.new(1, -24, 0, 6),
		BackgroundColor3 = Color3.fromRGB(12, 0, 3),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = body,
	}, { corner(3) })

	local fill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = track,
	}, {
		corner(3),
		gradient(Color3.fromRGB(170, 15, 35), T.RedBright, 0),
	})

	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = T.Text,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = track,
	}, {
		corner(6),
		create("UIStroke", { Color = T.RedBright, Thickness = 1.5 }),
	})

	local hit = create("TextButton", {
		Position = UDim2.new(0, 6, 0, 24),
		Size = UDim2.new(1, -12, 0, 26),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 6,
		Parent = body,
	})
	hookHover(hit, body, bodyStroke, false)
	attachTooltip(hit, opts.Tooltip)

	local value = min
	local flag = type(opts.Flag) == "string" and opts.Flag or nil

	local function snap(v)
		v = math.floor(v / inc + 0.5) * inc
		return math.clamp(v, min, max)
	end

	local function render()
		local a = (max == min) and 0 or (value - min) / (max - min)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		valueLabel.Text = formatNumber(value) .. suffix
	end

	local function set(v, silent)
		local newValue = snap(v)
		local changedValue = newValue ~= value
		value = newValue
		render()
		if not silent then
			if flag then
				Library:SetFlag(flag, value)
			end
			if changedValue then
				pcallCallback(opts.Callback, value)
			end
		end
	end

	local function updateFromX(x)
		local width = track.AbsoluteSize.X
		if width <= 0 then return end
		local a = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
		set(min + a * (max - min))
	end

	local dragging = false

	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			self._dragging = true
			self:_applyScroll()
			updateFromX(input.Position.X)
		end
	end)

	table.insert(self._conns, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			updateFromX(input.Position.X)
		end
	end))

	table.insert(self._conns, UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			self._dragging = false
			self:_applyScroll()
		end
	end))

	-- valor inicial: Default, ou o que estiver salvo na flag
	value = snap(opts.Default or min)
	if flag then
		local saved = Library:GetFlag(flag)
		if type(saved) == "number" then
			value = snap(saved)
		end
	end
	render()

	-- SetFlag() externo também mexe no slider da interface
	if flag then
		Library:_registerFlag(flag, function(newValue)
			if type(newValue) == "number" and newValue ~= value then
				set(newValue, true)
			end
		end)
	end

	return {
		Set = set,
		Get = function()
			return value
		end,
		Flag = flag,
	}
end

----------------------------------------------------------------
-- NOTIFICAÇÕES (canto inferior direito, empilham subindo)
--
-- Library.Notify({
--     Title = "Título",
--     Text = "Mensagem",            -- (ou Message)
--     Type = "Info",                -- "Info" | "Success" | "Warning" | "Error"
--     Duration = 4,                 -- segundos (false ou 0 = fica até clicar)
--     Icon = 123456789,             -- opcional: id de imagem (número ou "rbxassetid://...")
--     IconColor = Color3,           -- opcional: tinge o ícone de imagem
--     Callback = function() end,    -- opcional: chamado ao clicar na notificação
-- })
-- Também disponível como Window:Notify({...})
-- Retorna { Dismiss = function }
----------------------------------------------------------------
local NOTIFY_WIDTH = 290
local NOTIFY_MAX = 6
local notifier = nil
local notifyCounter = 0

local NotifyTypes = {
	Info = { color = Color3.fromRGB(255, 100, 115), glyph = "i" },
	Success = { color = Color3.fromRGB(95, 230, 135), glyph = "✓" },
	Warning = { color = Color3.fromRGB(255, 198, 75), glyph = "!" },
	Error = { color = Color3.fromRGB(255, 70, 90), glyph = "✕" },
}

local function ensureNotifier()
	if notifier and notifier.gui.Parent then
		return notifier
	end

	local gui = mountScreenGui("CrimsonLib_Notifications", {
		DisplayOrder = 100,
	})

	local holder = create("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, NOTIFY_WIDTH, 1, -32),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		}),
	})

	notifier = { gui = gui, holder = holder, active = {} }
	return notifier
end

function Library.Notify(opts)
	opts = opts or {}
	local T = Library.Theme
	local n = ensureNotifier()

	local kind = NotifyTypes[opts.Type] or NotifyTypes.Info
	local title = opts.Title or "Notificação"
	local text = opts.Text or opts.Message or ""

	local duration = opts.Duration
	if duration == nil then duration = 4 end
	local persistent = duration == false or (type(duration) == "number" and duration <= 0)

	-- altura calculada pelo tamanho do texto
	local textW = NOTIFY_WIDTH - 56 - 14
	local msgH = 0
	if text ~= "" then
		msgH = TextService:GetTextSize(text, 12, Enum.Font.Gotham, Vector2.new(textW, 1000)).Y
	end
	local height = math.max(58, 29 + msgH + (persistent and 12 or 18))

	notifyCounter += 1
	local wrapper = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		LayoutOrder = notifyCounter,
		Parent = n.holder,
	})

	local offscreen = UDim2.new(0, NOTIFY_WIDTH + 40, 1, 0)

	local card = create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = offscreen,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Parent = wrapper,
	}, {
		corner(12),
		gradient(Color3.fromRGB(150, 15, 35), T.Dark, 120),
		create("UIStroke", { Color = T.RedBright, Thickness = 1.3, Transparency = 0.25 }),
	})

	-- ícone
	local iconHolder = create("Frame", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = kind.color,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Parent = card,
	}, {
		corner(10),
		create("UIStroke", { Color = kind.color, Thickness = 1.2, Transparency = 0.35 }),
	})

	local notifyIcon = Library:GetIcon(opts.Icon)
	if notifyIcon then
		create("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 1,
			Image = notifyIcon,
			ImageColor3 = opts.IconColor or Color3.new(1, 1, 1),
			Parent = iconHolder,
		})
	else
		create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = kind.glyph,
			TextColor3 = kind.color,
			Font = Enum.Font.GothamBlack,
			TextSize = 18,
			Parent = iconHolder,
		})
	end

	create("TextLabel", {
		Position = UDim2.fromOffset(56, 10),
		Size = UDim2.new(1, -70, 0, 16),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Parent = card,
	})

	if text ~= "" then
		create("TextLabel", {
			Position = UDim2.fromOffset(56, 29),
			Size = UDim2.new(1, -70, 0, msgH),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = Color3.fromRGB(235, 220, 222),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			Parent = card,
		})
	end

	-- barra de progresso (tempo restante)
	local fill
	if not persistent then
		local track = create("Frame", {
			Position = UDim2.new(0, 56, 1, -10),
			Size = UDim2.new(1, -70, 0, 3),
			BackgroundColor3 = kind.color,
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
			Parent = card,
		}, { corner(2) })
		fill = create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = kind.color,
			BorderSizePixel = 0,
			Parent = track,
		}, { corner(2) })
	end

	-- clique = dispensar
	local hit = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 10,
		Parent = card,
	})

	local handle = {}
	local dismissed = false

	local function dismiss()
		if dismissed then return end
		dismissed = true

		for i, item in ipairs(n.active) do
			if item == handle then
				table.remove(n.active, i)
				break
			end
		end

		tween(card, { Position = offscreen }, 0.28, Enum.EasingStyle.Quart)
		task.delay(0.26, function()
			tween(wrapper, { Size = UDim2.new(1, 0, 0, 0) }, 0.22, Enum.EasingStyle.Quart)
			task.delay(0.24, function()
				wrapper:Destroy()
			end)
		end)
	end
	handle.Dismiss = dismiss

	hit.MouseButton1Click:Connect(function()
		pcallCallback(opts.Callback)
		dismiss()
	end)

	-- entrada: o espaço cresce (as antigas sobem) e o card desliza da direita
	tween(wrapper, { Size = UDim2.new(1, 0, 0, height) }, 0.25, Enum.EasingStyle.Quart)
	task.delay(0.05, function()
		if not dismissed then
			tween(card, { Position = UDim2.new(0, 0, 1, 0) }, 0.4, Enum.EasingStyle.Back)
		end
	end)

	if fill then
		TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
			Size = UDim2.new(0, 0, 1, 0),
		}):Play()
		task.delay(duration, dismiss)
	end

	table.insert(n.active, handle)
	if #n.active > NOTIFY_MAX then
		n.active[1].Dismiss()
	end

	return handle
end

function Window:Notify(opts)
	return Library.Notify(opts)
end

return Library
