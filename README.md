# CrimsonLib

Painel único (vermelho/vidro) com tooltips, keybinds, notificações, partículas, **ícones por nome** e **flags salvas em arquivo**. A interface é criada no **CoreGui**.

```
local Library = loadstring(game:HttpGet("<raw do Crimsonlib.lua>"))()

local Window = Library.new({ Title = "MEU SCRIPT", Folder = "MeuScript", Icon = "flame" })
Window:Toggle({ Name = "Auto Farm", Flag = "AutoFarm", Default = false, Keybind = true, Icon = "zap" })
```

Veja `Example.lua` para um script completo.

---

## Onde a interface é criada

`gethui()` → `CoreGui` → `PlayerGui` (fallback automático).

- Se o executor tiver `protect_gui` / `syn.protect_gui`, ele é chamado antes de parentar a `ScreenGui`.
- Janela, notificações e tooltips usam o mesmo container.
- Para forçar outro lugar:

```lua
Library:SetGuiParent(game:GetService("CoreGui"))   -- ou
Library.new({ Parent = game:GetService("CoreGui") })
```

## Arquivos no workspace do executor

Mesmo esquema da Redz Library. No Windows: `C:\Users\<você>\AppData\Local\<Executor>\workspace\<Folder>\`

| Arquivo              | Conteúdo                                                        |
| -------------------- | --------------------------------------------------------------- |
| `Icons.lua`          | cache da lista de ícones (baixada uma vez do GitHub)            |
| `ScriptFlags.json`   | valores dos toggles/sliders e teclas dos keybinds               |
| `LibrarySettings.json` | posição da janela e estado minimizado                         |

A pasta é definida por `Library.Folder` ou por `Library.new({ Folder = "..." })` (padrão: `CrimsonLib`).
Sem `writefile`/`readfile` (executor limitado) tudo continua funcionando — só não persiste entre execuções.

```lua
Library:WriteFile("minha-config.json", "{}")
Library:ReadFile("minha-config.json")
Library:FileExists("Icons.lua")   Library:DeleteFile("Icons.lua")
Library:GetFilePath("ScriptFlags.json")   Library:HasFileSupport()
```

---

## Ícones por nome

A lista (Lucide, ~1.500 ícones) é baixada uma vez e salva em `Icons.lua`; nas próximas execuções sai do cache, sem esperar rede.

```lua
Library:GetIcon("sword")        -- "rbxassetid://10709752939" (procura por nome)
Library:GetIcon("Sword")        -- ignora maiúsculas
Library:GetIcon("arrow-right")  -- ignora espaço/hífen/underline
Library:GetIcon(123456)         -- número vira rbxassetid://
Library:GetIcon("rbxassetid://123456")  -- passa direto
Library:GetIcon("naoexiste")    -- nil (o elemento simplesmente fica sem ícone)

Library:RefreshIcons()   -- força baixar uma lista nova e atualiza o cache
Library:AddIcon("meuIcone", 123456)   -- ícone avulso, sem arquivo
Library:GetIconList()    -- todos os nomes disponíveis (ordenados)
```

Fonte da lista: `Library.IconsUrl` (padrão: `Utils/Icons.lua` do repositório do redz).

`Icon` funciona em `Toggle`, `Slider`, `Button`, `Title`, `Subtitle`, `Notify` e na barra de título da janela. Use `IconColor = Color3` para tingir.

---

## Flags (valores salvos)

Basta passar `Flag = "Nome"` no elemento — o valor é gravado e **recarregado sozinho** na próxima execução (a flag vence o `Default`).

```lua
local toggle = Window:Toggle({ Name = "Auto Farm", Flag = "AutoFarm", Default = false })
toggle.Set(true)                  -- salva a flag e chama o Callback
toggle.Get()                      -- lê o estado atual

Library:SetFlag("AutoFarm", true) -- escreve do arquivo E atualiza o toggle na tela
Library:GetFlag("AutoFarm")       -- true
Library:GetFlag("Velocidade", 10) -- com valor padrão
Library:HasFlag("AutoFarm")       -- existe?
Library:GetFlags()                -- tabela inteira
Library:SaveFlags()               -- grava na hora (o save normal tem debounce de 0.5s)
Library:DeleteFlags()             -- apaga ScriptFlags.json e limpa a memória
```

Atalhos equivalentes na janela: `Window:SetFlag`, `Window:GetFlag`, `Window:GetKeyFlag`.

Tipos aceitos: `boolean`, `number`, `string`, `table` e `nil`.

| Elemento | O que a flag guarda                          |
| -------- | -------------------------------------------- |
| `Toggle` | `boolean`                                    |
| `Slider` | `number` (já passado pelo `Increment`/`Min`/`Max`) |
| `Button` | só o keybind                                 |

### Keybinds

A tecla escolhida pelo usuário é salva em `<Flag>_Key` (nome da tecla, ex.: `"F"`).

```lua
local toggle = Window:Toggle({ Name = "Auto Farm", Flag = "AutoFarm", Keybind = true })
toggle.SetKey(Enum.KeyCode.F)         -- define e salva
toggle.GetKey()                       -- Enum.KeyCode.F
Library:GetFlag("AutoFarm_Key")       -- "F"
Library:GetKeyFlag("AutoFarm")        -- Enum.KeyCode.F
```

`Keybind = true` deixa o botão vazio (`KEY`); `Keybind = Enum.KeyCode.E` já começa com a tecla definida (a flag salva tem prioridade).

---

## Janela

```lua
local Window = Library.new({
	Title = "MEU SCRIPT",
	Subtitle = "v1.0",
	Name = "CrimsonLib",      -- nome da ScreenGui
	Folder = "CrimsonLib",    -- pasta dos arquivos
	Icon = "flame",           -- ícone da barra de título
	Width = 300,              -- tamanho base (a janela escala sozinha com a resolução)
	MaxHeight = 360,
	ToggleKey = Enum.KeyCode.RightShift,
	Parent = nil,             -- força outro container
	Particles = true,
	SavePosition = true,      -- salva posição/minimizado em LibrarySettings.json
	PreloadIcons = true,      -- baixa os ícones antes de montar a UI
	Debug = false,            -- avisa quando um ícone não é encontrado
})
```

A janela usa **escala automática**: o tamanho é pensado para 1080p e um `UIScale`
multiplica tudo proporcionalmente — em telas menores (ex.: notebooks 768p) a
interface encolhe até 70% e em telas maiores (2K/4K) cresce até 2x, sempre
acompanhando mudanças de resolução na hora.

Métodos: `SetMinimized`, `SetVisible`/`ToggleVisible`, `SetTitle`, `SetSubtitle`, `Destroy`, `Notify`.
Elementos: `Title`, `Subtitle`, `Paragraph`, `Separator`, `Button`, `Toggle`, `Slider`.

Opções comuns dos elementos: `Name`, `Flag`, `Icon`, `IconColor`, `Tooltip`, `Keybind`, `Callback`.
O `Slider` ainda aceita `Min`, `Max`, `Increment`, `Default`, `Suffix`.

## Notificações

```lua
Library.Notify({
	Title = "Título",
	Text = "Mensagem",
	Type = "Info",          -- Info | Success | Warning | Error
	Icon = "bell",          -- nome de ícone, id ou rbxassetid://
	Duration = 4,           -- false/0 = fica até clicar
	Callback = function() end,
})
```
