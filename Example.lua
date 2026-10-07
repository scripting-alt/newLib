-- ================================================================
--  CrimsonLib - exemplo de uso
--
--  A interface é criada no CoreGui (gethui -> CoreGui -> PlayerGui)
--  e os arquivos ficam no workspace do executor:
--      <workspace>/MeuScript/Icons.lua
--      <workspace>/MeuScript/ScriptFlags.json
--      <workspace>/MeuScript/LibrarySettings.json
-- ================================================================

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/scripting-alt/newLib/main/Crimsonlib.lua"))()

local Window = Library.new({
	Title = "MEU SCRIPT",
	Subtitle = "v1.0",
	Folder = "MeuScript", -- pasta dos arquivos no workspace do executor
	Icon = "flame", -- ícone da barra de título (nome ou id)
	Width = 320,
	MaxHeight = 420,
	ToggleKey = Enum.KeyCode.RightShift, -- esconde/mostra a janela
})

----------------------------------------------------------------------
-- TÍTULOS
----------------------------------------------------------------------
Window:Title({ Text = "Farm", Icon = "sword" })
Window:Subtitle({ Text = "Configurações", Icon = "settings" })
Window:Paragraph("As flags abaixo são salvas em ScriptFlags.json e recarregadas sozinhas na próxima execução.")

----------------------------------------------------------------------
-- TOGGLE (Flag = valor salvo, Keybind = tecla salva em <Flag>_Key)
----------------------------------------------------------------------
local autoFarm = Window:Toggle({
	Name = "Auto Farm",
	Flag = "AutoFarm", -- Library:GetFlag("AutoFarm")
	Default = false,
	Keybind = true, -- clique no botão "KEY" para definir a tecla
	Icon = "zap",
	Tooltip = "Liga e desliga o farm automaticamente",
	Callback = function(value)
		print("Auto Farm:", value)
	end,
})

----------------------------------------------------------------------
-- SLIDER
----------------------------------------------------------------------
local velocidade = Window:Slider({
	Name = "Velocidade",
	Flag = "Velocidade",
	Min = 0,
	Max = 100,
	Increment = 5,
	Default = 25,
	Icon = "gauge",
	Suffix = "%",
	Callback = function(value)
		print("Velocidade:", value)
	end,
})

----------------------------------------------------------------------
-- BOTÃO (ícone + keybind)
----------------------------------------------------------------------
Window:Button({
	Name = "Executar agora",
	Icon = "play",
	Primary = true,
	Keybind = Enum.KeyCode.E, -- tecla já definida no código
	Flag = "Executar",
	Tooltip = "Roda a ação uma vez",
	Callback = function()
		Library.Notify({
			Title = "Executado",
			Text = "Velocidade atual: " .. tostring(velocidade.Get()) .. "%",
			Icon = "check-circle",
			Duration = 3,
		})
	end,
})

----------------------------------------------------------------------
-- LENDO AS FLAGS DE OUTRO LUGAR DO SCRIPT
----------------------------------------------------------------------
Window:Separator()
Window:Subtitle({ Text = "Debug", Icon = "terminal" })

Window:Button({
	Name = "Mostrar flags salvas",
	Icon = "list",
	Callback = function()
		print("AutoFarm:", Library:GetFlag("AutoFarm"))
		print("Velocidade:", Library:GetFlag("Velocidade"))
		print("Tecla do AutoFarm:", Library:GetFlag("AutoFarm_Key"))
		print("Arquivo:", Library:GetFilePath("ScriptFlags.json"))
	end,
})

Window:Button({
	Name = "Alternar AutoFarm pelo código",
	Icon = "refresh-cw",
	Callback = function()
		-- mexer na flag também mexe no toggle da interface
		Library:SetFlag("AutoFarm", not Library:GetFlag("AutoFarm"))
	end,
})

Window:Button({
	Name = "Apagar configurações salvas",
	Icon = "trash",
	Callback = function()
		Library:DeleteFlags()
		Library.Notify({ Title = "Limpo", Text = "Flags apagadas", Type = "Warning", Duration = 3 })
	end,
})

----------------------------------------------------------------------
-- NOTIFICAÇÃO DE BOAS-VINDAS
----------------------------------------------------------------------
Library.Notify({
	Title = "CrimsonLib",
	Text = "Interface criada no CoreGui. Ícones e flags prontos para uso.",
	Icon = "bell",
	Duration = 5,
})
