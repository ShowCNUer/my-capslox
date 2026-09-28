;@Ahk2Exe-SetName MyCapslox
;@Ahk2Exe-SetDescription Caps Lock keyboard and window productivity tool
;@Ahk2Exe-SetProductName My Capslox
;@Ahk2Exe-SetVersion 1.0.0.0
;@Ahk2Exe-SetCompanyName My Capslox
#Requires AutoHotkey v2.0.26+
#Warn All, StdOut
#SingleInstance Off
#UseHook
#MaxThreadsPerHotkey 1

#Include config.ahk
#Include lib\WindowUtils.ahk
#Include lib\Toast.ahk
#Include lib\WindowSlots.ahk
#Include lib\WindowMover.ahk
#Include lib\ClipboardSlots.ahk
#Include lib\KeyBindings.ahk

if A_Args.Length && A_Args[1] = "--self-test"
    ExitApp(RunCompiledSelfTest())

global MyCapsloxInstanceMutex := AcquireInstanceMutex()

SendMode("Input")
SetStoreCapsLockMode(false)
SetWorkingDir(A_ScriptDir)
SetTitleMatchMode(2)
WindowUtils.EnablePerMonitorDpi()
try WindowSlots.Init()
catch Error as startupError {
    MsgBox("初始化窗口槽位失败：`n" startupError.Message, "My Capslox", "Iconx")
    ExitApp(1)
}
SetupTray()

global CapsLayerUsed := false
global CapsLayerInput := 0
global CapsLayerBaseState := false

RegisterCapsHotkeys()

if ProcessExist("Capslox.exe") {
    if A_IsCompiled {
        MsgBox("检测到原 Capslox 仍在运行。请先退出它，再启动 My Capslox。", "My Capslox", "Icon!")
        ExitApp(3)
    }
    SetTimer(NotifyCapsloxConflict, -500)
} else
    SetTimer(NotifyStarted, -250)

; Caps Lock is a hold modifier. A short standalone press toggles the real Caps Lock state.
*CapsLock::{
    global CapsLayerUsed, CapsLayerInput, CapsLayerBaseState
    CapsLayerUsed := false

    ; Keep the real toggle state neutral while Caps Lock acts as a modifier.
    CapsLayerBaseState := GetKeyState("CapsLock", "T")
    SetCapsLockState("Off")

    try {
        CapsLayerInput := InputHook("V")
        CapsLayerInput.KeyOpt("{All}", "N")
        CapsLayerInput.OnKeyDown := CapsLayerKeyDown
        CapsLayerInput.Start()
        KeyWait("CapsLock")
    } finally {
        if IsObject(CapsLayerInput) {
            try CapsLayerInput.Stop()
            CapsLayerInput := 0
        }

        if CapsLayerUsed
            SetCapsLockState(CapsLayerBaseState ? "On" : "Off")
        else
            SetCapsLockState(CapsLayerBaseState ? "Off" : "On")
    }
}

MarkCapsLayerUsed() {
    global CapsLayerUsed
    CapsLayerUsed := true
}

CapsLayerKeyDown(input, virtualKey, scanCode) {
    ; Any secondary key turns the press into a modifier chord, including an unbound key.
    if virtualKey != 0x14
        MarkCapsLayerUsed()
}

CapsSend(keys) {
    MarkCapsLayerUsed()
    Send(keys)
}

CapsSendSequence(keys*) {
    MarkCapsLayerUsed()
    for sequence in keys
        Send(sequence)
}

UseClipboard(action, slot) {
    MarkCapsLayerUsed()
    switch action {
        case "copy":
            ClipboardSlots.Copy(slot)
        case "cut":
            ClipboardSlots.Cut(slot)
        case "plain":
            ClipboardSlots.Paste(slot, true)
        default:
            ClipboardSlots.Paste(slot, false)
    }
}

UseWindowSlot(slot, bind) {
    MarkCapsLayerUsed()
    if bind
        WindowSlots.Bind(slot)
    else
        WindowSlots.Activate(slot)
}

UseWindowAction(action) {
    MarkCapsLayerUsed()
    action.Call()
}

OpenProjectFolder(*) {
    MarkCapsLayerUsed()
    try Run("explorer.exe " Chr(34) A_ScriptDir Chr(34))
}

ReloadMyCapslox(*) {
    Reload()
}

ToggleMyCapslox(*) {
    Suspend(-1)
    Toast.Show(A_IsSuspended ? "快捷键已暂停" : "快捷键已恢复", "info")
}

ExitMyCapslox(*) {
    ExitApp()
}

SetupTray() {
    A_TrayMenu.Delete()
    A_TrayMenu.Add("快捷键指南", ShowKeyBindings)
    if A_IsCompiled {
        A_TrayMenu.Add("打开程序目录", OpenProjectFolder)
        defaultItem := "打开程序目录"
    } else {
        A_TrayMenu.Add("打开脚本目录", OpenProjectFolder)
        defaultItem := "快捷键指南"
    }
    A_TrayMenu.Add()
    A_TrayMenu.Add("暂停 / 继续", ToggleMyCapslox)
    A_TrayMenu.Add("重新加载", ReloadMyCapslox)
    A_TrayMenu.Add("退出", ExitMyCapslox)
    A_TrayMenu.Default := defaultItem
    A_IconTip := "My Capslox · AutoHotkey v2"
}

AcquireInstanceMutex() {
    mutexName := "Local\MyCapslox-4E0E38C1-475D-4BA4-BC45-FB0E8D8CA23D"
    handle := DllCall("CreateMutex", "Ptr", 0, "Int", false, "Str", mutexName, "Ptr")
    alreadyRunning := A_LastError = 183 ; ERROR_ALREADY_EXISTS
    if !handle {
        MsgBox("无法创建 My Capslox 实例锁。", "My Capslox", "Iconx")
        ExitApp(1)
    }
    if alreadyRunning {
        DllCall("CloseHandle", "Ptr", handle)
        MsgBox("My Capslox 已经在运行。请先从托盘退出旧实例。", "My Capslox", "Icon!")
        ExitApp(2)
    }
    return handle
}

RunCompiledSelfTest() {
    if !A_IsCompiled
        return 10
    if MyCapsloxConfig.WindowSlotCount != 10
        return 11
    if !IsObject(WindowLaunchCommands) || !IsObject(WindowTitlePatterns)
        return 12
    if !InStr(MyCapsloxConfig.WindowSlotFile, "\MyCapslox\data\window-slots.ini")
        return 13
    return 0
}

NotifyCapsloxConflict() {
    Toast.Show("检测到 Capslox 仍在运行，快捷键可能冲突", "warning")
}

NotifyStarted() {
    Toast.Show("My Capslox 已启动", "success", 0, 1500)
}

#Include user_bindings.ahk
