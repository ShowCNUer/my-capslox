#Requires AutoHotkey v2.0.26+

; Personal settings. Edit this file directly, then reload the script from the tray menu.
global MyCapsloxDataDirectory := EnvGet("LOCALAPPDATA")
if MyCapsloxDataDirectory != ""
    MyCapsloxDataDirectory .= "\MyCapslox\data"
else
    MyCapsloxDataDirectory := A_AppData "\MyCapslox\data"

global MyCapsloxConfig := {
    ToastDurationMs: 2600,
    ToastErrorDurationMs: 3600,
    ToastFadeDurationMs: 180,
    WindowLaunchTimeoutMs: 10000,
    WindowLaunchPollMs: 150,
    WindowSlotCount: 10,
    WindowSlotFile: MyCapsloxDataDirectory "\window-slots.ini",
    ClipboardRestoreDelayMs: 220,
    EditorExecutable: "notepad.exe",
    EditorArguments: ""
}

; Optional per-slot launch commands. A missing entry falls back to the bound exe path.
global WindowLaunchCommands := Map()
; Example (add entries below this Map initialization):
; WindowLaunchCommands[1] := 'code.exe "D:\Luca\Code"'

; Optional regex used to disambiguate multiple windows from the same application.
global WindowTitlePatterns := Map()
; Example (add entries below this Map initialization):
; WindowTitlePatterns[1] := "i)my-project.*Visual Studio Code"
