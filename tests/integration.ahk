#Requires AutoHotkey v2.0.26+
#ErrorStdOut UTF-8
#SingleInstance Off
#Warn All, StdOut

OnError(IntegrationFatal)

#Include ..\config.ahk
#Include ..\lib\WindowUtils.ahk
#Include ..\lib\Toast.ahk
#Include ..\lib\WindowSlots.ahk
#Include ..\lib\WindowMover.ahk

global IntegrationFailures := 0
global OriginalForeground := WindowUtils.GetForegroundWindow()
global TestSlotFile := A_Temp "\my-capslox-integration-" DllCall("GetCurrentProcessId", "UInt") ".ini"
global TestGuiOne := 0
global TestGuiTwo := 0
global TestMoveGui := 0

IntegrationAssert(value, label) {
    global IntegrationFailures
    if value
        return
    IntegrationFailures += 1
    FileAppend("FAIL " label "`n", "**")
}

IntegrationRequire(value, label) {
    if !value
        throw Error("Integration precondition failed: " label)
}

RequireActive(hwnd, label) {
    WinActivate("ahk_id " hwnd)
    IntegrationRequire(WinWaitActive("ahk_id " hwnd, , 1), label)
}

IntegrationFatal(error, mode) {
    FileAppend(
        "FATAL " error.File ":" error.Line " " error.Message " (" mode ")`n",
        "**"
    )
    CleanupIntegration()
    ExitApp(1)
    return true
}

CleanupIntegration() {
    global OriginalForeground, TestSlotFile, TestGuiOne, TestGuiTwo, TestMoveGui
    if IsObject(TestGuiOne)
        try TestGuiOne.Destroy()
    if IsObject(TestGuiTwo)
        try TestGuiTwo.Destroy()
    if IsObject(TestMoveGui)
        try TestMoveGui.Destroy()
    if FileExist(TestSlotFile)
        try FileDelete(TestSlotFile)
    if WindowUtils.IsWindow(OriginalForeground)
        try WinActivate("ahk_id " OriginalForeground)
}

RunCrossMonitorMoveTest() {
    global TestMoveGui

    areas := WindowUtils.AllWorkAreas()
    if areas.Length < 2 {
        FileAppend("SKIP cross-monitor integration test (single display)`n", "*")
        return
    }

    pair := 0
    bestShrink := 1.0e30
    for sourceArea in areas {
        for direction in ["left", "right"] {
            targetArea := WindowUtils.FindDirectionalArea(sourceArea, direction, areas)
            if !IsObject(targetArea)
                continue
            shrink := Min(
                targetArea.width / Max(1, sourceArea.width),
                targetArea.height / Max(1, sourceArea.height)
            )
            if shrink < bestShrink {
                bestShrink := shrink
                pair := {
                    source: sourceArea,
                    target: targetArea,
                    direction: direction
                }
            }
        }
    }

    if !IsObject(pair) {
        FileAppend("SKIP cross-monitor integration test (no horizontal neighbor)`n", "*")
        return
    }

    source := pair.source
    width := Max(320, Round(source.width * 0.55))
    height := Max(240, Round(source.height * 0.70))
    width := Min(width, source.width - 40)
    height := Min(height, source.height - 40)
    x := Round(source.left + (source.width - width) / 2)
    y := Round(source.top + (source.height - height) / 2)

    TestMoveGui := Gui("+ToolWindow +Resize -DPIScale", "MyCapslox constrained move test")
    TestMoveGui.AddText("xm ym", "Temporary cross-monitor target")
    TestMoveGui.Show("NA x" x " y" y " w" width " h" height)
    Sleep(120)

    try {
        before := WindowUtils.GetExtendedFrameRect(TestMoveGui.Hwnd)
        beforeArea := WindowUtils.WorkAreaForWindow(TestMoveGui.Hwnd)
        IntegrationRequire(WindowMover._SameArea(beforeArea, source), "constrained window starts on source display")
        TestMoveGui.Opt("+MinSize") ; Force a legal post-DPI size adjustment on a smaller target dimension.
        expected := WindowUtils.ProjectRect(before, beforeArea, pair.target)

        movedToMonitor := WindowMover.MoveWindowToMonitor(TestMoveGui.Hwnd, pair.direction)
        IntegrationRequire(movedToMonitor, "constrained window moves across displays")
        actual := WindowUtils.GetExtendedFrameRect(TestMoveGui.Hwnd)
        actualArea := WindowUtils.WorkAreaForWindow(TestMoveGui.Hwnd)
        IntegrationAssert(WindowMover._SameArea(actualArea, pair.target), "cross-monitor move reaches target display")
        IntegrationAssert(actual.width > 0 && actual.height > 0, "cross-monitor window remains valid")

        sizeAdjusted := Abs(actual.width - expected.width) > 64
            || Abs(actual.height - expected.height) > 64
        if bestShrink < 0.90
            IntegrationAssert(sizeAdjusted, "cross-monitor test exercises a legal size adjustment")

        wrongAreaRejected := false
        try WindowMover._WaitForMove(TestMoveGui.Hwnd, actual, source)
        catch Error as err
            wrongAreaRejected := err.Message = "窗口拒绝移动到目标显示器"
        IntegrationAssert(wrongAreaRejected, "monitor verification rejects the wrong display")

        ; The public path must restore, transfer and re-maximize a maximized window.
        TestMoveGui.Opt("-MinSize")
        maximizeDirection := pair.direction = "left" ? "right" : "left"
        maximizeTarget := WindowUtils.FindDirectionalArea(pair.target, maximizeDirection, areas)
        IntegrationRequire(IsObject(maximizeTarget), "maximized move has a return display")
        WinMaximize("ahk_id " TestMoveGui.Hwnd)
        Sleep(120)
        IntegrationRequire(WinGetMinMax("ahk_id " TestMoveGui.Hwnd) = 1, "cross-monitor test window maximizes")
        IntegrationRequire(
            WindowMover.MoveWindowToMonitor(TestMoveGui.Hwnd, maximizeDirection),
            "maximized window moves across displays"
        )
        Sleep(120)
        maximizedArea := WindowUtils.WorkAreaForWindow(TestMoveGui.Hwnd)
        IntegrationAssert(WindowMover._SameArea(maximizedArea, maximizeTarget), "maximized move reaches target display")
        IntegrationAssert(WinGetMinMax("ahk_id " TestMoveGui.Hwnd) = 1, "window is re-maximized after transfer")
    } finally {
        if IsObject(TestMoveGui)
            try TestMoveGui.Destroy()
        TestMoveGui := 0
    }
}

RunIntegration() {
    global IntegrationFailures, TestSlotFile, TestGuiOne, TestGuiTwo

    MyCapsloxConfig.WindowSlotFile := TestSlotFile
    MyCapsloxConfig.ToastDurationMs := 220
    MyCapsloxConfig.ToastFadeDurationMs := 60
    WindowUtils.EnablePerMonitorDpi()
    WindowSlots.Init()

    TestGuiOne := Gui("+ToolWindow", "MyCapslox 集成窗口一")
    TestGuiOne.AddText("xm ym", "Window slot target")
    TestGuiOne.Show("w420 h260")
    TestGuiTwo := Gui("+ToolWindow", "MyCapslox Integration Two")
    TestGuiTwo.AddText("xm ym", "Foreground decoy")
    TestGuiTwo.Show("x80 y80 w360 h220")

    IntegrationAssert(
        WindowUtils.VirtualDesktopState(TestGuiOne.Hwnd) = 1,
        "visible test window is on the current virtual desktop"
    )

    WindowTitlePatterns[1] := "["
    IntegrationAssert(!WindowSlots.BindWindow(1, TestGuiOne.Hwnd), "binding rejects invalid title regex")
    WindowTitlePatterns[1] := "this-title-does-not-exist"
    IntegrationAssert(!WindowSlots.BindWindow(1, TestGuiOne.Hwnd), "binding rejects mismatched title regex")
    WindowTitlePatterns.Delete(1)
    IntegrationRequire(WindowSlots.BindWindow(1, TestGuiOne.Hwnd), "bind test window")
    IntegrationRequire(FileExist(TestSlotFile), "slot persistence file created")
    savedName := IniRead(TestSlotFile, "slot-1", "displayName", "")
    IntegrationAssert(InStr(savedName, "集成窗口一"), "Unicode window title is persisted")

    ; The fast live-HWND path must apply the same title filter as recovery.
    slotData := WindowSlots._Slots[1]
    slotData.titleRegex := "i)mycapslox.*集成窗口一"
    IntegrationAssert(WindowSlots._FastWindow(slotData) = TestGuiOne.Hwnd, "fast path accepts matching title regex")
    slotData.titleRegex := "this-title-does-not-exist"
    IntegrationAssert(WindowSlots._FastWindow(slotData) = 0, "fast path rejects mismatched title regex")
    slotData.titleRegex := "["
    IntegrationAssert(WindowSlots._FastWindow(slotData) = -1, "fast path reports invalid title regex")
    invalidResolved := WindowSlots._FindCandidate(slotData)
    IntegrationAssert(invalidResolved.status = "invalid-pattern", "candidate search reports invalid title regex")
    slotData.titleRegex := ""

    WindowSlots.Init() ; Reload from INI so activation also exercises persistence parsing.

    ; Replace the original HWND with an equivalent window to exercise stale-handle recovery.
    TestGuiOne.Destroy()
    TestGuiOne := Gui("+ToolWindow", "MyCapslox 集成窗口一")
    TestGuiOne.AddText("xm ym", "Replacement window slot target")
    TestGuiOne.Show("x520 y180 w420 h260")

    RequireActive(TestGuiTwo.Hwnd, "decoy window receives foreground")
    IntegrationRequire(WindowSlots.Activate(1), "activate recovered slot")
    IntegrationRequire(WinWaitActive("ahk_id " TestGuiOne.Hwnd, , 1), "recovered window receives foreground")

    RequireActive(TestGuiOne.Hwnd, "target remains active before minimize")
    IntegrationRequire(WindowSlots.Activate(1), "second activation minimizes")
    Sleep(120)
    IntegrationAssert(WinGetMinMax("ahk_id " TestGuiOne.Hwnd) = -1, "bound window is minimized")
    WinRestore("ahk_id " TestGuiOne.Hwnd)
    RequireActive(TestGuiOne.Hwnd, "restored target receives foreground")

    workArea := WindowUtils.WorkAreaForWindow(TestGuiOne.Hwnd)
    expectedLeft := WindowUtils.HalfRect(workArea, "left")
    IntegrationRequire(WindowMover.SnapWindow(TestGuiOne.Hwnd, "left"), "snap test window left")
    Sleep(120)
    moved := WindowUtils.GetExtendedFrameRect(TestGuiOne.Hwnd)
    IntegrationAssert(Abs(moved.x - expectedLeft.x) <= 48, "left snap x")
    IntegrationAssert(Abs(moved.y - expectedLeft.y) <= 48, "left snap y")
    IntegrationAssert(Abs(moved.width - expectedLeft.width) <= 64, "left snap width")
    IntegrationAssert(Abs(moved.height - expectedLeft.height) <= 64, "left snap height")

    expectedRight := WindowUtils.HalfRect(workArea, "right")
    IntegrationRequire(WindowMover.SnapWindow(TestGuiOne.Hwnd, "right"), "snap test window right")
    Sleep(120)
    moved := WindowUtils.GetExtendedFrameRect(TestGuiOne.Hwnd)
    IntegrationAssert(Abs(moved.x - expectedRight.x) <= 48, "right snap x")
    IntegrationAssert(Abs(moved.width - expectedRight.width) <= 64, "right snap width")

    RunCrossMonitorMoveTest()

    RequireActive(TestGuiOne.Hwnd, "target active before toast")
    foregroundBeforeToast := WindowUtils.GetForegroundWindow()
    Toast.Show("integration toast", "success", TestGuiOne.Hwnd, 180)
    toastHwnd := Toast._CurrentGui.Hwnd
    IntegrationAssert(WindowUtils.IsWindow(toastHwnd), "toast is created")
    Sleep(60)
    IntegrationAssert(WindowUtils.GetForegroundWindow() = foregroundBeforeToast, "toast does not steal focus")
    exStyle := WinGetExStyle("ahk_id " toastHwnd)
    IntegrationAssert(exStyle & 0x20, "toast is mouse transparent")
    IntegrationAssert(exStyle & 0x08000000, "toast is no-activate")

    Toast.Show("replacement toast", "success", TestGuiOne.Hwnd, 300)
    replacementToast := Toast._CurrentGui.Hwnd
    Sleep(160)
    IntegrationAssert(WindowUtils.IsWindow(replacementToast), "old timer does not destroy replacement toast")
    Sleep(300)
    IntegrationAssert(!WindowUtils.IsWindow(replacementToast), "toast auto-dismisses")

    IntegrationRequire(WindowSlots.Clear(1), "clear persisted slot")
    IntegrationAssert(IniRead(TestSlotFile, "slot-1", "processName", "") = "", "slot section is removed")

    CleanupIntegration()
    if IntegrationFailures = 0
        FileAppend("PASS integration tests`n", "*")
    ExitApp(IntegrationFailures ? 1 : 0)
}

RunIntegration()
