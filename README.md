# My Capslox

一个直接使用 AutoHotkey v2 编写的 Windows 键盘效率工具。它不读取 Capslox 的
`keymap.jsonc`，快捷键直接写在 `.ahk` 文件中。

当前实现包括：

- Caps Lock 作为自定义修饰键；短按仍然切换大小写。
- 光标移动、选择、删除和重复操作。
- 两个独立的内存剪贴板槽位。
- 10 个持久窗口槽位：绑定、激活、再次按下最小化、应用重启后重新查找。
- 找不到应用时按绑定的程序路径重新启动，并异步等待窗口出现。
- 左右半屏、最大化/还原、多显示器移动。
- 绑定成功、失败、启动等待等不抢焦点的几秒提示弹窗。
- 托盘菜单、可视化快捷键指南、可编辑键位、重载和 `user_bindings.ahk` 扩展入口。

## 从 GitHub Release 直接使用

如果不需要修改快捷键或重新编译，可以直接从 [GitHub Releases](https://github.com/ShowCNUer/my-capslox/releases) 下载最新版本。Release 中通常包含：

- `MyCapslox.exe`：独立的 Windows 64 位可执行文件。
- `MyCapslox.sha256`：用于校验下载文件完整性。

下载 `MyCapslox.exe` 后可以直接双击启动，不需要另外安装 AutoHotkey，也不需要管理员权限。建议把它复制到一个不会随意删除的目录，例如 `C:\Users\<用户名>\Apps\MyCapslox\`。

下载后可以使用 PowerShell 校验 SHA-256：

```powershell
Get-FileHash .\MyCapslox.exe -Algorithm SHA256
Get-Content .\MyCapslox.sha256
```

确认第一个命令输出的哈希值与 `.sha256` 文件中的值一致后再运行。首次启动前请先退出原版 Capslox；两套程序不能同时运行，否则可能争抢同一组键盘钩子。

当前 Release 没有 Authenticode 数字签名，Windows SmartScreen 或安全软件可能显示“未知发布者”提示。确认文件来自本项目的 GitHub Release 并完成哈希校验后，再按系统提示选择运行。

直接运行 Release 版本时，窗口槽位数据仍保存到 `%LOCALAPPDATA%\MyCapslox\data\window-slots.ini`。更新时退出正在运行的 My Capslox，下载新的 `MyCapslox.exe` 覆盖旧文件即可；绑定数据不会因此删除。Release 版本默认不会自动启动，如需开机启动，可以手动为 exe 创建快捷方式并放入当前用户的 Windows“启动”文件夹。

## 可执行版与开始菜单（从源码构建）

构建独立的 64 位 `MyCapslox.exe`：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1 -Integration
```

构建脚本会下载并校验固定版本的官方 Ahk2Exe，验证源码后生成 `dist/MyCapslox.exe`。安装到当前用户并创建 Windows 开始菜单快捷方式：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

安装位置为 `%LOCALAPPDATA%\Programs\MyCapslox\MyCapslox.exe`，在开始菜单中搜索“My Capslox”即可启动。安装不需要管理员权限，也不会自动启动程序；第一次从源码版切换前，请先从托盘退出正在运行的源码实例和原 Capslox。

启用用户登录后自启：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\autostart.ps1
```

关闭自启时添加 `-Disable`。自启使用当前用户的 Windows“启动”文件夹，不需要管理员权限，也不会在登录前启动。

更新时重新执行构建和安装命令。安装器会拒绝覆盖正在运行的安装版，并保留窗口绑定数据。卸载程序和开始菜单入口、但保留绑定数据：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1
```

当前可执行文件没有 Authenticode 数字签名；本机使用不受影响，对外分发时 Windows SmartScreen 或安全软件可能给出提示。

## 运行源码版

要求 AutoHotkey `v2.0.26` 或更高版本：

```powershell
winget install --id AutoHotkey.AutoHotkey --exact
```

安装 AutoHotkey 后双击 `main.ahk`。开始使用前请先退出 Capslox，并关闭 Capslox 的开机自启，否则两套键盘钩子可能冲突。直接双击源码时 My Capslox 只会给出冲突警告；从开始菜单启动的可执行版会明确拒绝与原 Capslox 并存。

本机未安装 AutoHotkey 时，也可以从官方地址下载便携包：

<https://www.autohotkey.com/download/2.0/AutoHotkey_2.0.26.zip>

解压后使用其中的 `AutoHotkey64.exe main.ahk`。

也可以使用项目内的启动脚本；它会优先使用 `.tools` 中的便携运行时：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start.ps1
```

如果检测到 `Capslox.exe` 仍在运行，启动脚本会拒绝继续，避免两套热键互相争抢。

首次使用：

1. 退出原 Capslox，然后启动 My Capslox。
2. 聚焦要绑定的窗口，按住 `Caps Lock`，再按 `Alt + 1`。
3. 屏幕上方会出现约 2.6 秒、不抢焦点且鼠标可穿透的绑定成功提示。
4. 以后用 `Caps + 1` 激活该窗口；目标已在前台时再按一次会将其最小化。

## 默认快捷键

右键托盘图标选择“快捷键指南”可以查看所有内置快捷键。选中任意一行后，在“新键位”输入框中按下新的组合键，点击“保存并重新加载”即可立即生效。快捷键配置保存在 `%LOCALAPPDATA%\MyCapslox\data\keybindings.ini`，可执行版和源码版共用这份配置。每个键位只能分配给一个内置功能；个人在 `user_bindings.ahk` 中添加的自定义热键不会自动显示在指南中。

所有快捷键都以按住 Caps Lock 开始。

| 按键 | 功能 |
| --- | --- |
| `Space` | 在光标处按 Enter |
| `E D S F`；`Alt + E D S F` | 上、下、左、右移动 1 次；5 次 |
| `T/Z`；`Alt + T/Z` | 上/下移动 20 行；50 行 |
| `A/G`；`Alt + A/G` | 向前/后移动 1 个单词；5 个单词 |
| `P/;`；`Alt + P/;` | 行首/行尾；文档首/文档尾 |
| `I K J L`；`Alt + I K J L` | 向四个方向选择 1 次；5 次 |
| `M/,`；`Alt + M/,` | 向上/下选择 20 行；50 行 |
| `H/.`；`Alt + H/.` | 向前/后选择 1 个单词；5 个单词 |
| `N`；`Alt + N` | 选择光标附近的单词范围；选择当前行 |
| `U/O`；`Alt + U/O` | 选择到行首/行尾；文档首/文档尾 |
| `W/R`；`Alt + W/R` | 删除前/后 1 个字符；1 个单词 |
| `[` / `/`；`Alt + [` / `Alt + /` | 删除到行首/行尾；文档首/文档尾 |
| `Backspace`；`Alt + Backspace` | 清空当前行内容；清空全部内容 |
| `Enter` | 移到当前行末尾并插入新行 |
| `1 … 9/0` | 激活槽位 1 … 9/10；当前已是目标时最小化 |
| `Alt + 1 … 9/0` | 将当前窗口绑定到槽位 1 … 9/10 |
| `Shift + S/F` | 窗口贴靠左/右半屏 |
| `Shift + E/D` | 最大化；还原或最小化 |
| `Shift + A/G` | 移动到左/右显示器 |
| `C/X/V` | 剪贴板槽位 1 的复制/剪切/粘贴 |
| `Alt + C/X/V` | 剪贴板槽位 2 的复制/剪切/粘贴 |
| `Shift + V`；`Alt + Shift + V` | 槽位 1；槽位 2 的纯文本粘贴 |
| `Shift + /` | 源码版编辑 `main.ahk`；可执行版提示重新构建 |
| `Shift + ,` | 打开项目目录或安装目录 |

短按 Caps Lock 会切换真实的大写锁定状态。

跨显示器移动以“窗口已经进入目标显示器”为成功条件。混合 DPI、窗口最小尺寸或应用自身布局可能让目标程序在跨屏后调整宽高，这是正常行为；左右半屏贴靠仍会严格验证位置和尺寸。

## 窗口槽位

绑定记录写入 `%LOCALAPPDATA%\MyCapslox\data\window-slots.ini`。首次安装或加载新版本时，会在目标文件不存在的前提下迁移项目原有的 `data/window-slots.ini`。脚本会记住窗口的临时编号和所属进程，以便快速确认原窗口；窗口关闭或应用重启后，再根据程序路径、窗口类型和标题重新查找。进程创建时间用于避免误认被 Windows 重复使用的窗口编号。

具体记录包括：

- 上次的 HWND、PID 和进程创建时间，用于快速且安全地验证原窗口。
- 可执行文件完整路径、进程名和窗口类，用于应用重启后重新查找。
- 窗口标题提示，用于存在多个同类窗口时提高匹配准确度。

如果多个窗口得到相同匹配分数，脚本会要求重新绑定，不会随意激活其中一个。
同一程序有多个窗口时，可在 `config.ahk` 中按槽位设置标题正则；需要特殊启动参数时，也可覆盖启动命令：

```ahk
global WindowLaunchCommands := Map(
    1, 'code.exe "D:\Luca\Code\MyProject\my-capslox"'
)

global WindowTitlePatterns := Map(
    1, "i)my-capslox.*Visual Studio Code"
)
```

这里的键是槽位号 `1..10`，数字键 `0` 对应槽位 `10`。`WindowTitlePatterns` 会作为窗口标题的硬过滤条件，`i)` 表示忽略大小写；绑定时正则无效或当前标题不匹配会直接失败，使用时也不会激活不匹配的窗口。模式不要写得过严：没有窗口匹配时，脚本会进入 `WindowLaunchCommands` 或绑定程序路径的启动流程。

普通提示默认显示 2600 毫秒，错误提示显示 3600 毫秒，可分别修改 `config.ahk` 中的 `ToastDurationMs` 和 `ToastErrorDurationMs`。

当前限制：

- 由 `ApplicationFrameHost.exe` 承载的 Microsoft Store/UWP 窗口会明确拒绝绑定；当前尚未实现 AUMID 身份和启动支持。
- 普通权限运行的脚本可能无法读取、聚焦或移动管理员窗口。必要时可让 AutoHotkey 以管理员身份运行，但它随后启动的程序也可能继承管理员权限。
- 对被 DWM 标记为隐藏的窗口，脚本会通过 Windows Virtual Desktop 接口确认其是否位于其他桌面，并避免重复启动，但不会自动切换桌面或移动窗口。接口确认窗口仍在当前桌面或无法判断所属桌面时，脚本会按“当前不可见”处理并给出较保守的提示。

## 自定义

- 通用参数和启动命令：`config.ahk`
- 默认快捷键：`main.ahk`
- 个人附加快捷键：`user_bindings.ahk`

源码版修改后从托盘菜单选择“重新加载”。可执行版会在构建时嵌入这些 `.ahk` 文件，修改后必须重新执行 `build.ps1` 和 `install.ps1`；安装版中的“重新加载”只会重新启动已编译代码。自定义命令应使用绝对路径或位于 `PATH` 中的程序，因为安装版的相对路径以安装目录为起点。

## 验证

`scripts/verify.ps1` 会先以 `/Validate` 检查入口脚本及其依赖，再运行不接触真实窗口的几何单元测试：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify.ps1
```

需要额外验证真实窗口绑定、激活、最小化、移动和提示窗时，可运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify.ps1 -Integration
```

集成测试只操作它自己创建的临时窗口；存在多个显示器时还会覆盖受最小尺寸约束及最大化窗口的跨屏移动。测试结束后会恢复之前的前台窗口。
