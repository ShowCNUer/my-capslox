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

if A_Args.Length && A_Args[1] = "--self-test"
    ExitApp(RunCompiledSelfTest())

global MyCapsloxInstanceMutex := AcquireInstanceMutex()

SendMode("Input")
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
    global CapsLayerUsed, CapsLayerInput
    CapsLayerUsed := false
    CapsLayerInput := InputHook("V")
    CapsLayerInput.KeyOpt("{All}", "N")
    CapsLayerInput.OnKeyDown := CapsLayerKeyDown
    CapsLayerInput.Start()
    KeyWait("CapsLock")
    CapsLayerInput.Stop()
    CapsLayerInput := 0
    if !CapsLayerUsed && A_PriorKey = "CapsLock" {
        nextState := GetKeyState("CapsLock", "T") ? "Off" : "On"
        SetCapsLockState(nextState)
    }
}

#HotIf GetKeyState("CapsLock", "P")

; Navigation.
Space::CapsSend("{Enter}")
e::CapsSend("{Up}")
d::CapsSend("{Down}")
s::CapsSend("{Left}")
f::CapsSend("{Right}")
!e::CapsSend("{Up 5}")
!d::CapsSend("{Down 5}")
!s::CapsSend("{Left 5}")
!f::CapsSend("{Right 5}")
t::CapsSend("{Up 20}")
z::CapsSend("{Down 20}")
!t::CapsSend("{Up 50}")
!z::CapsSend("{Down 50}")
a::CapsSend("^{Left}")
g::CapsSend("^{Right}")
!a::CapsSend("^{Left 5}")
!g::CapsSend("^{Right 5}")
p::CapsSend("{Home}")
SC027::CapsSend("{End}") ; semicolon
!p::CapsSend("^{Home}")
!SC027::CapsSend("^{End}")

; Selection.
i::CapsSend("+{Up}")
k::CapsSend("+{Down}")
j::CapsSend("+{Left}")
l::CapsSend("+{Right}")
!i::CapsSend("+{Up 5}")
!k::CapsSend("+{Down 5}")
!j::CapsSend("+{Left 5}")
!l::CapsSend("+{Right 5}")
m::CapsSend("+{Up 20}")
SC033::CapsSend("+{Down 20}") ; comma
!m::CapsSend("+{Up 50}")
!SC033::CapsSend("+{Down 50}")
h::CapsSend("^+{Left}")
SC034::CapsSend("^+{Right}") ; period
!h::CapsSend("^+{Left 5}")
!SC034::CapsSend("^+{Right 5}")
n::CapsSendSequence("^{Left}", "^+{Right}")
!n::CapsSendSequence("{Home}", "+{End}")
u::CapsSend("+{Home}")
o::CapsSend("+{End}")
!u::CapsSend("^+{Home}")
!o::CapsSend("^+{End}")

; Deletion and insertion.
w::CapsSend("{Backspace}")
r::CapsSend("{Delete}")
!w::CapsSend("^{Backspace}")
!r::CapsSend("^{Delete}")
SC01A::CapsSendSequence("+{Home}", "{Backspace}") ; left bracket
SC035::CapsSendSequence("+{End}", "{Delete}") ; slash
!SC01A::CapsSendSequence("^+{Home}", "{Backspace}")
!SC035::CapsSendSequence("^+{End}", "{Delete}")
Backspace::CapsSendSequence("{End}", "+{Home}", "{Backspace}")
!Backspace::CapsSendSequence("^a", "{Backspace}")
Enter::CapsSendSequence("{End}", "{Enter}")

; Independent clipboard slots.
x::UseClipboard("cut", 1)
c::UseClipboard("copy", 1)
v::UseClipboard("paste", 1)
+v::UseClipboard("plain", 1)
!x::UseClipboard("cut", 2)
!c::UseClipboard("copy", 2)
!v::UseClipboard("paste", 2)
!+v::UseClipboard("plain", 2)

; Predictable window movement without routing through Capslox.
+s::UseWindowAction(ObjBindMethod(WindowMover, "Snap", "left"))
+f::UseWindowAction(ObjBindMethod(WindowMover, "Snap", "right"))
+e::UseWindowAction(ObjBindMethod(WindowMover, "Maximize"))
+d::UseWindowAction(ObjBindMethod(WindowMover, "RestoreOrMinimize"))
+a::UseWindowAction(ObjBindMethod(WindowMover, "MoveToMonitor", "left"))
+g::UseWindowAction(ObjBindMethod(WindowMover, "MoveToMonitor", "right"))

; Window slots: Caps+number activates/minimizes, Caps+Alt+number binds.
1::UseWindowSlot(1, false)
!1::UseWindowSlot(1, true)
2::UseWindowSlot(2, false)
!2::UseWindowSlot(2, true)
3::UseWindowSlot(3, false)
!3::UseWindowSlot(3, true)
4::UseWindowSlot(4, false)
!4::UseWindowSlot(4, true)
5::UseWindowSlot(5, false)
!5::UseWindowSlot(5, true)
6::UseWindowSlot(6, false)
!6::UseWindowSlot(6, true)
7::UseWindowSlot(7, false)
!7::UseWindowSlot(7, true)
8::UseWindowSlot(8, false)
!8::UseWindowSlot(8, true)
9::UseWindowSlot(9, false)
!9::UseWindowSlot(9, true)
0::UseWindowSlot(10, false)
!0::UseWindowSlot(10, true)

; Script controls.
+SC033::OpenProjectFolder() ; Caps+Shift+comma
+SC035::EditBindings() ; Caps+Shift+slash

#HotIf

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

EditBindings(*) {
    MarkCapsLayerUsed()
    if A_IsCompiled {
        Toast.Show("可执行版快捷键已内置；请修改源码后重新构建", "info")
        return
    }

    command := Chr(34) MyCapsloxConfig.EditorExecutable Chr(34)
    if MyCapsloxConfig.EditorArguments != ""
        command .= " " MyCapsloxConfig.EditorArguments
    command .= " " Chr(34) A_ScriptFullPath Chr(34)
    try Run(command)
    catch Error as err
        Toast.Show("打开编辑器失败：" err.Message, "error")
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
    if A_IsCompiled {
        A_TrayMenu.Add("打开程序目录", OpenProjectFolder)
        defaultItem := "打开程序目录"
    } else {
        A_TrayMenu.Add("编辑快捷键", EditBindings)
        A_TrayMenu.Add("打开脚本目录", OpenProjectFolder)
        defaultItem := "编辑快捷键"
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
