#Requires AutoHotkey v2.0.26+

global MyCapsloxBindingDefinitions := BuildBindingDefinitions()
global MyCapsloxBindings := Map()
global MyCapsloxBindingsGui := 0
global MyCapsloxBindingsList := 0
global MyCapsloxBindingsEditor := 0
global MyCapsloxBindingRowIds := []
global MyCapsloxBindingSelectedId := ""

BuildBindingDefinitions() {
    defs := Map()
    AddBinding(defs, "enter", "Enter", "Space", "在光标处按 Enter")
    AddBinding(defs, "up", "向上移动", "e", "移动 1 次")
    AddBinding(defs, "down", "向下移动", "d", "移动 1 次")
    AddBinding(defs, "left", "向左移动", "s", "移动 1 次")
    AddBinding(defs, "right", "向右移动", "f", "移动 1 次")
    AddBinding(defs, "up_fast", "快速向上移动", "!e", "移动 5 次")
    AddBinding(defs, "down_fast", "快速向下移动", "!d", "移动 5 次")
    AddBinding(defs, "left_fast", "快速向左移动", "!s", "移动 5 次")
    AddBinding(defs, "right_fast", "快速向右移动", "!f", "移动 5 次")
    AddBinding(defs, "up_line", "向上移动多行", "t", "移动 20 行")
    AddBinding(defs, "down_line", "向下移动多行", "z", "移动 20 行")
    AddBinding(defs, "up_line_fast", "快速向上移动多行", "!t", "移动 50 行")
    AddBinding(defs, "down_line_fast", "快速向下移动多行", "!z", "移动 50 行")
    AddBinding(defs, "word_left", "向前移动单词", "a", "移动 1 个单词")
    AddBinding(defs, "word_right", "向后移动单词", "g", "移动 1 个单词")
    AddBinding(defs, "word_left_fast", "快速向前移动单词", "!a", "移动 5 个单词")
    AddBinding(defs, "word_right_fast", "快速向后移动单词", "!g", "移动 5 个单词")
    AddBinding(defs, "line_home", "行首", "p", "跳到当前行首")
    AddBinding(defs, "line_end", "行尾", "SC027", "跳到当前行尾")
    AddBinding(defs, "doc_home", "文档首", "!p", "跳到文档首")
    AddBinding(defs, "doc_end", "文档尾", "!SC027", "跳到文档尾")

    AddBinding(defs, "select_up", "选择向上", "i", "选择 1 次")
    AddBinding(defs, "select_down", "选择向下", "k", "选择 1 次")
    AddBinding(defs, "select_left", "选择向左", "j", "选择 1 次")
    AddBinding(defs, "select_right", "选择向右", "l", "选择 1 次")
    AddBinding(defs, "select_up_fast", "快速选择向上", "!i", "选择 5 次")
    AddBinding(defs, "select_down_fast", "快速选择向下", "!k", "选择 5 次")
    AddBinding(defs, "select_left_fast", "快速选择向左", "!j", "选择 5 次")
    AddBinding(defs, "select_right_fast", "快速选择向右", "!l", "选择 5 次")
    AddBinding(defs, "select_up_line", "选择向上多行", "m", "选择 20 行")
    AddBinding(defs, "select_down_line", "选择向下多行", "SC033", "选择 20 行")
    AddBinding(defs, "select_up_line_fast", "快速选择向上多行", "!m", "选择 50 行")
    AddBinding(defs, "select_down_line_fast", "快速选择向下多行", "!SC033", "选择 50 行")
    AddBinding(defs, "select_word_left", "选择前一个单词", "h", "选择 1 个单词")
    AddBinding(defs, "select_word_right", "选择后一个单词", "SC034", "选择 1 个单词")
    AddBinding(defs, "select_word_left_fast", "快速选择前一个单词", "!h", "选择 5 个单词")
    AddBinding(defs, "select_word_right_fast", "快速选择后一个单词", "!SC034", "选择 5 个单词")
    AddBinding(defs, "select_word", "选择当前单词", "n", "选择光标附近的单词范围")
    AddBinding(defs, "select_line", "选择当前行", "!n", "选择当前行")
    AddBinding(defs, "select_line_start", "选择到行首", "u", "选择到当前行首")
    AddBinding(defs, "select_line_end", "选择到行尾", "o", "选择到当前行尾")
    AddBinding(defs, "select_doc_start", "选择到文档首", "!u", "选择到文档首")
    AddBinding(defs, "select_doc_end", "选择到文档尾", "!o", "选择到文档尾")

    AddBinding(defs, "backspace", "删除前一个字符", "w", "删除 1 个字符")
    AddBinding(defs, "delete", "删除后一个字符", "r", "删除 1 个字符")
    AddBinding(defs, "backspace_word", "删除前一个单词", "!w", "删除 1 个单词")
    AddBinding(defs, "delete_word", "删除后一个单词", "!r", "删除 1 个单词")
    AddBinding(defs, "delete_line_start", "删除到行首", "SC01A", "删除到当前行首")
    AddBinding(defs, "delete_line_end", "删除到行尾", "SC035", "删除到当前行尾")
    AddBinding(defs, "delete_doc_start", "删除到文档首", "!SC01A", "删除到文档首")
    AddBinding(defs, "delete_doc_end", "删除到文档尾", "!SC035", "删除到文档尾")
    AddBinding(defs, "clear_line", "清空当前行", "Backspace", "清空当前行内容")
    AddBinding(defs, "clear_all", "清空全部内容", "!Backspace", "清空全部内容")
    AddBinding(defs, "new_line", "插入新行", "Enter", "移到当前行末尾并插入新行")

    AddBinding(defs, "clipboard_cut_1", "剪切（槽位 1）", "x", "剪贴板槽位 1")
    AddBinding(defs, "clipboard_copy_1", "复制（槽位 1）", "c", "剪贴板槽位 1")
    AddBinding(defs, "clipboard_paste_1", "粘贴（槽位 1）", "v", "剪贴板槽位 1")
    AddBinding(defs, "clipboard_plain_1", "纯文本粘贴（槽位 1）", "+v", "剪贴板槽位 1")
    AddBinding(defs, "clipboard_cut_2", "剪切（槽位 2）", "!x", "剪贴板槽位 2")
    AddBinding(defs, "clipboard_copy_2", "复制（槽位 2）", "!c", "剪贴板槽位 2")
    AddBinding(defs, "clipboard_paste_2", "粘贴（槽位 2）", "!v", "剪贴板槽位 2")
    AddBinding(defs, "clipboard_plain_2", "纯文本粘贴（槽位 2）", "!+v", "剪贴板槽位 2")

    AddBinding(defs, "snap_left", "窗口贴靠左侧", "+s", "贴靠左半屏")
    AddBinding(defs, "snap_right", "窗口贴靠右侧", "+f", "贴靠右半屏")
    AddBinding(defs, "maximize", "窗口最大化", "+e", "最大化当前窗口")
    AddBinding(defs, "restore_minimize", "还原或最小化", "+d", "还原或最小化当前窗口")
    AddBinding(defs, "monitor_left", "移动到左显示器", "+a", "移动当前窗口")
    AddBinding(defs, "monitor_right", "移动到右显示器", "+g", "移动当前窗口")

    Loop 10 {
        key := A_Index = 10 ? "0" : String(A_Index)
        AddBinding(defs, "slot_activate_" A_Index, "激活窗口槽位 " A_Index, key, "已在前台时再次按下会最小化")
        AddBinding(defs, "slot_bind_" A_Index, "绑定窗口槽位 " A_Index, "!" key, "将当前窗口绑定到槽位")
    }

    AddBinding(defs, "open_folder", "打开程序目录", "+SC033", "打开项目目录或安装目录")
    AddBinding(defs, "show_guide", "快捷键指南", "+SC035", "打开本窗口")
    return defs
}

AddBinding(defs, id, label, defaultKey, description) {
    defs[id] := {label: label, default: defaultKey, description: description}
}

BindingFilePath() {
    global MyCapsloxDataDirectory
    return MyCapsloxDataDirectory "\keybindings.ini"
}

LoadKeyBindings() {
    global MyCapsloxBindingDefinitions, MyCapsloxBindings
    MyCapsloxBindings := Map()
    path := BindingFilePath()
    for id, definition in MyCapsloxBindingDefinitions {
        saved := IniRead(path, "Bindings", id, definition.default)
        MyCapsloxBindings[id] := NormalizeBinding(saved, definition.default)
    }
}

SaveKeyBindings() {
    global MyCapsloxBindings, MyCapsloxDataDirectory
    path := BindingFilePath()
    DirCreate(MyCapsloxDataDirectory)
    for id, key in MyCapsloxBindings
        IniWrite(key, path, "Bindings", id)
}

NormalizeBinding(value, fallback) {
    value := StrReplace(Trim(String(value)), " ")
    if value = ""
        return fallback
    modifiers := ""
    while value != "" && InStr("^!+#", SubStr(value, 1, 1)) {
        modifiers .= SubStr(value, 1, 1)
        value := SubStr(value, 2)
    }
    aliases := Map(";", "SC027", ",", "SC033", ".", "SC034", "/", "SC035", "[", "SC01A")
    if aliases.Has(value)
        value := aliases[value]
    return modifiers value
}

CapsLayerActive(*) {
    return GetKeyState("CapsLock", "P")
}

CapsLayerAltBlock(*) {
}

RegisterCapsHotkeys() {
    global MyCapsloxBindingDefinitions, MyCapsloxBindings
    LoadKeyBindings()
    try {
        HotIf(CapsLayerActive)
        Hotkey("*LAlt", CapsLayerAltBlock, "On")
        Hotkey("*RAlt", CapsLayerAltBlock, "On")
        for id, definition in MyCapsloxBindingDefinitions
            Hotkey(MyCapsloxBindings[id], ExecuteCapsHotkey, "On")
        HotIf()
    } catch Error as err {
        HotIf()
        UnregisterCapsHotkeys()
        MyCapsloxBindings := Map()
        for id, definition in MyCapsloxBindingDefinitions
            MyCapsloxBindings[id] := definition.default
        try RegisterCapsHotkeysFromDefaults()
        catch Error as fallbackError
            throw Error("快捷键注册失败：" fallbackError.Message, -1, fallbackError)
    }
}

RegisterCapsHotkeysFromDefaults() {
    global MyCapsloxBindingDefinitions, MyCapsloxBindings
    HotIf(CapsLayerActive)
    Hotkey("*LAlt", CapsLayerAltBlock, "On")
    Hotkey("*RAlt", CapsLayerAltBlock, "On")
    for id, definition in MyCapsloxBindingDefinitions
        Hotkey(MyCapsloxBindings[id], ExecuteCapsHotkey, "On")
    HotIf()
}

UnregisterCapsHotkeys() {
    global MyCapsloxBindingDefinitions, MyCapsloxBindings
    try {
        HotIf(CapsLayerActive)
        Hotkey("*LAlt", "Off")
        Hotkey("*RAlt", "Off")
        for id, definition in MyCapsloxBindingDefinitions {
            if MyCapsloxBindings.Has(id)
                Hotkey(MyCapsloxBindings[id], "Off")
        }
    } catch Error {
    } finally {
        HotIf()
    }
}

ExecuteCapsHotkey(*) {
    global MyCapsloxBindings
    pressedKey := StrLower(A_ThisHotkey)
    for id, binding in MyCapsloxBindings {
        if StrLower(binding) = pressedKey {
            ExecuteCapsBinding(id)
            return
        }
    }
}

ExecuteCapsBinding(id, *) {
    MarkCapsLayerUsed()
    switch id {
        case "enter": CapsSend("{Enter}")
        case "up": CapsSend("{Up}")
        case "down": CapsSend("{Down}")
        case "left": CapsSend("{Left}")
        case "right": CapsSend("{Right}")
        case "up_fast": CapsSend("{Up 5}")
        case "down_fast": CapsSend("{Down 5}")
        case "left_fast": CapsSend("{Left 5}")
        case "right_fast": CapsSend("{Right 5}")
        case "up_line": CapsSend("{Up 20}")
        case "down_line": CapsSend("{Down 20}")
        case "up_line_fast": CapsSend("{Up 50}")
        case "down_line_fast": CapsSend("{Down 50}")
        case "word_left": CapsSend("^{Left}")
        case "word_right": CapsSend("^{Right}")
        case "word_left_fast": CapsSend("^{Left 5}")
        case "word_right_fast": CapsSend("^{Right 5}")
        case "line_home": CapsSend("{Home}")
        case "line_end": CapsSend("{End}")
        case "doc_home": CapsSend("^{Home}")
        case "doc_end": CapsSend("^{End}")
        case "select_up": CapsSend("+{Up}")
        case "select_down": CapsSend("+{Down}")
        case "select_left": CapsSend("+{Left}")
        case "select_right": CapsSend("+{Right}")
        case "select_up_fast": CapsSend("+{Up 5}")
        case "select_down_fast": CapsSend("+{Down 5}")
        case "select_left_fast": CapsSend("+{Left 5}")
        case "select_right_fast": CapsSend("+{Right 5}")
        case "select_up_line": CapsSend("+{Up 20}")
        case "select_down_line": CapsSend("+{Down 20}")
        case "select_up_line_fast": CapsSend("+{Up 50}")
        case "select_down_line_fast": CapsSend("+{Down 50}")
        case "select_word_left": CapsSend("^+{Left}")
        case "select_word_right": CapsSend("^+{Right}")
        case "select_word_left_fast": CapsSend("^+{Left 5}")
        case "select_word_right_fast": CapsSend("^+{Right 5}")
        case "select_word": CapsSendSequence("^{Left}", "^+{Right}")
        case "select_line": CapsSendSequence("{Home}", "+{End}")
        case "select_line_start": CapsSend("+{Home}")
        case "select_line_end": CapsSend("+{End}")
        case "select_doc_start": CapsSend("^+{Home}")
        case "select_doc_end": CapsSend("^+{End}")
        case "backspace": CapsSend("{Backspace}")
        case "delete": CapsSend("{Delete}")
        case "backspace_word": CapsSend("^{Backspace}")
        case "delete_word": CapsSend("^{Delete}")
        case "delete_line_start": CapsSendSequence("+{Home}", "{Backspace}")
        case "delete_line_end": CapsSendSequence("+{End}", "{Delete}")
        case "delete_doc_start": CapsSendSequence("^+{Home}", "{Backspace}")
        case "delete_doc_end": CapsSendSequence("^+{End}", "{Delete}")
        case "clear_line": CapsSendSequence("{End}", "+{Home}", "{Backspace}")
        case "clear_all": CapsSendSequence("^a", "{Backspace}")
        case "new_line": CapsSendSequence("{End}", "{Enter}")
        case "clipboard_cut_1": UseClipboard("cut", 1)
        case "clipboard_copy_1": UseClipboard("copy", 1)
        case "clipboard_paste_1": UseClipboard("paste", 1)
        case "clipboard_plain_1": UseClipboard("plain", 1)
        case "clipboard_cut_2": UseClipboard("cut", 2)
        case "clipboard_copy_2": UseClipboard("copy", 2)
        case "clipboard_paste_2": UseClipboard("paste", 2)
        case "clipboard_plain_2": UseClipboard("plain", 2)
        case "snap_left": UseWindowAction(ObjBindMethod(WindowMover, "Snap", "left"))
        case "snap_right": UseWindowAction(ObjBindMethod(WindowMover, "Snap", "right"))
        case "maximize": UseWindowAction(ObjBindMethod(WindowMover, "Maximize"))
        case "restore_minimize": UseWindowAction(ObjBindMethod(WindowMover, "RestoreOrMinimize"))
        case "monitor_left": UseWindowAction(ObjBindMethod(WindowMover, "MoveToMonitor", "left"))
        case "monitor_right": UseWindowAction(ObjBindMethod(WindowMover, "MoveToMonitor", "right"))
        case "open_folder": OpenProjectFolder()
        case "show_guide": ShowKeyBindings()
        default:
            if InStr(id, "slot_activate_")
                UseWindowSlot(Integer(SubStr(id, 15)), false)
            else if InStr(id, "slot_bind_")
                UseWindowSlot(Integer(SubStr(id, 11)), true)
    }
}

ShowKeyBindings(*) {
    global MyCapsloxBindingsGui
    if IsObject(MyCapsloxBindingsGui) {
        try {
            MyCapsloxBindingsGui.Show()
            WinActivate("ahk_id " MyCapsloxBindingsGui.Hwnd)
            return
        }
    }

    global MyCapsloxBindingDefinitions, MyCapsloxBindings, MyCapsloxBindingsList, MyCapsloxBindingsEditor, MyCapsloxBindingRowIds
    MyCapsloxBindingsGui := Gui("+Resize", "快捷键指南")
    MyCapsloxBindingsGui.SetFont("s10", "Segoe UI")
    MyCapsloxBindingsGui.Add("Text", "x12 y10 w700", "所有快捷键都以按住 Caps Lock 开始；选中一行后可录入新的组合键。")
    MyCapsloxBindingsList := MyCapsloxBindingsGui.Add("ListView", "x12 y34 w700 h390 Grid", ["功能", "当前键位", "说明"])
    MyCapsloxBindingsList.ModifyCol(1, 190)
    MyCapsloxBindingsList.ModifyCol(2, 150)
    MyCapsloxBindingsList.ModifyCol(3, 330)
    MyCapsloxBindingRowIds := []
    for id, definition in MyCapsloxBindingDefinitions {
        MyCapsloxBindingRowIds.Push(id)
        MyCapsloxBindingsList.Add("", definition.label, FormatBinding(MyCapsloxBindings[id]), definition.description)
    }
    MyCapsloxBindingsList.OnEvent("ItemSelect", BindingGuiSelect)
    MyCapsloxBindingsGui.Add("Text", "x12 y438", "新键位：")
    MyCapsloxBindingsEditor := MyCapsloxBindingsGui.Add("Hotkey", "x72 y434 w170")
    MyCapsloxBindingsGui.Add("Button", "x252 y432 w130", "保存并重新加载").OnEvent("Click", SaveSelectedBinding)
    MyCapsloxBindingsGui.Add("Button", "x390 y432 w130", "恢复当前默认").OnEvent("Click", ResetSelectedBinding)
    MyCapsloxBindingsGui.Add("Button", "x540 y432 w80", "关闭").OnEvent("Click", BindingGuiClose)
    MyCapsloxBindingsGui.OnEvent("Close", BindingGuiClose)
    MyCapsloxBindingsGui.OnEvent("Escape", BindingGuiClose)
    MyCapsloxBindingsGui.Show("w730 h480")
}

BindingGuiSelect(list, row, selected) {
    global MyCapsloxBindingRowIds, MyCapsloxBindingSelectedId, MyCapsloxBindings, MyCapsloxBindingsEditor
    if !selected || row < 1 || row > MyCapsloxBindingRowIds.Length
        return
    MyCapsloxBindingSelectedId := MyCapsloxBindingRowIds[row]
    MyCapsloxBindingsEditor.Value := MyCapsloxBindings[MyCapsloxBindingSelectedId]
}

SaveSelectedBinding(*) {
    global MyCapsloxBindingSelectedId, MyCapsloxBindings, MyCapsloxBindingsEditor, MyCapsloxBindingDefinitions
    if MyCapsloxBindingSelectedId = "" {
        MsgBox("请先选择要修改的快捷键。", "快捷键指南", "Icon!")
        return
    }
    key := NormalizeBinding(MyCapsloxBindingsEditor.Value, "")
    if key = "" {
        MsgBox("快捷键不能为空。", "快捷键指南", "Icon!")
        return
    }
    for id, existing in MyCapsloxBindings {
        if id != MyCapsloxBindingSelectedId && StrLower(existing) = StrLower(key) {
            MsgBox("该键位已经分配给“" MyCapsloxBindingDefinitions[id].label "”。", "快捷键指南", "Icon!")
            return
        }
    }
    MyCapsloxBindings[MyCapsloxBindingSelectedId] := key
    SaveKeyBindings()
    Reload()
}

ResetSelectedBinding(*) {
    global MyCapsloxBindingSelectedId, MyCapsloxBindings, MyCapsloxBindingDefinitions, MyCapsloxBindingsEditor
    if MyCapsloxBindingSelectedId = ""
        return
    MyCapsloxBindings[MyCapsloxBindingSelectedId] := MyCapsloxBindingDefinitions[MyCapsloxBindingSelectedId].default
    MyCapsloxBindingsEditor.Value := MyCapsloxBindings[MyCapsloxBindingSelectedId]
    SaveKeyBindings()
    Reload()
}

BindingGuiClose(*) {
    global MyCapsloxBindingsGui
    try MyCapsloxBindingsGui.Destroy()
    MyCapsloxBindingsGui := 0
}

FormatBinding(binding) {
    labels := []
    key := String(binding)
    while key != "" {
        prefix := SubStr(key, 1, 1)
        if prefix = "^"
            labels.Push("Ctrl")
        else if prefix = "!"
            labels.Push("Alt")
        else if prefix = "+"
            labels.Push("Shift")
        else if prefix = "#"
            labels.Push("Win")
        else
            break
        key := SubStr(key, 2)
    }
    names := Map("SC027", ";", "SC033", ",", "SC034", ".", "SC035", "/", "SC01A", "[", "Space", "Space")
    keyLabel := names.Has(key) ? names[key] : key
    labels.Push(StrUpper(keyLabel))
    return JoinStrings(labels, " + ")
}

JoinStrings(values, separator) {
    result := ""
    for index, value in values
        result .= (index = 1 ? "" : separator) value
    return result
}
