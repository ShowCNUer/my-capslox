#Requires AutoHotkey v2.0.26+

class WindowUtils {
    static _IgnoredClasses := Map(
        "Progman", true,
        "WorkerW", true,
        "Shell_TrayWnd", true,
        "Shell_SecondaryTrayWnd", true
    )

    static EnablePerMonitorDpi() {
        ; DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = -4.
        try DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
    }

    static GetForegroundWindow() {
        hwnd := DllCall("GetForegroundWindow", "Ptr")
        if !hwnd
            return 0

        root := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr") ; GA_ROOT
        return root ? root : hwnd
    }

    static IsWindow(hwnd) {
        return hwnd && DllCall("IsWindow", "Ptr", hwnd, "Int")
    }

    static IsVisibleWindow(hwnd, allowMinimized := true, allowCloaked := false) {
        if !this.IsWindow(hwnd)
            return false
        if !DllCall("IsWindowVisible", "Ptr", hwnd, "Int")
            return false
        if !allowMinimized && DllCall("IsIconic", "Ptr", hwnd, "Int")
            return false

        try {
            className := WinGetClass("ahk_id " hwnd)
            if this._IgnoredClasses.Has(className)
                return false
        } catch Error {
            return false
        }

        if !allowCloaked && this.IsCloaked(hwnd)
            return false

        return true
    }

    static IsCloaked(hwnd) {
        cloaked := 0
        try {
            result := DllCall(
                "dwmapi\DwmGetWindowAttribute",
                "Ptr", hwnd,
                "UInt", 14, ; DWMWA_CLOAKED
                "Int*", &cloaked,
                "UInt", 4,
                "Int"
            )
            return result = 0 && cloaked
        }
        return false
    }

    static VirtualDesktopState(hwnd) {
        ; 1 = current desktop, 0 = another desktop, -1 = Windows could not decide.
        ; DWMWA_CLOAKED alone is not enough: apps and the Shell can cloak windows
        ; for reasons unrelated to virtual desktops.
        if !this.IsWindow(hwnd)
            return -1

        manager := 0
        coInitialized := false
        try {
            initResult := DllCall("ole32\CoInitializeEx", "Ptr", 0, "UInt", 0x2, "Int")
            coInitialized := initResult >= 0

            classId := Buffer(16, 0)
            interfaceId := Buffer(16, 0)
            if DllCall(
                "ole32\CLSIDFromString",
                "WStr", "{AA509086-5CA9-4C25-8F95-589D3C07B48A}",
                "Ptr", classId.Ptr,
                "Int"
            ) < 0
                return -1
            if DllCall(
                "ole32\IIDFromString",
                "WStr", "{A5CD92FF-29BE-454C-8D04-D82879FB3F1B}",
                "Ptr", interfaceId.Ptr,
                "Int"
            ) < 0
                return -1

            createResult := DllCall(
                "ole32\CoCreateInstance",
                "Ptr", classId.Ptr,
                "Ptr", 0,
                "UInt", 0x1, ; CLSCTX_INPROC_SERVER
                "Ptr", interfaceId.Ptr,
                "Ptr*", &manager,
                "Int"
            )
            if createResult < 0 || !manager
                return -1

            vtable := NumGet(manager, 0, "Ptr")
            isCurrentMethod := NumGet(vtable, 3 * A_PtrSize, "Ptr")
            onCurrent := 0
            result := DllCall(
                isCurrentMethod,
                "Ptr", manager,
                "Ptr", hwnd,
                "Int*", &onCurrent,
                "Int"
            )
            return result >= 0 ? (onCurrent ? 1 : 0) : -1
        } catch Error {
            return -1
        } finally {
            if manager {
                try {
                    vtable := NumGet(manager, 0, "Ptr")
                    releaseMethod := NumGet(vtable, 2 * A_PtrSize, "Ptr")
                    DllCall(releaseMethod, "Ptr", manager, "UInt")
                }
            }
            if coInitialized
                DllCall("ole32\CoUninitialize")
        }
    }

    static GetBindableForeground() {
        hwnd := this.GetForegroundWindow()
        return this.IsVisibleWindow(hwnd) ? hwnd : 0
    }

    static GetDeepestLastActivePopup(rootWindow) {
        current := rootWindow
        seen := Map()
        Loop 8 {
            if !current || seen.Has(current)
                break
            seen[current] := true
            nextPopup := DllCall("GetLastActivePopup", "Ptr", current, "Ptr")
            if !nextPopup || nextPopup = current || !this.IsVisibleWindow(nextPopup)
                break
            current := nextPopup
        }
        return current
    }

    static BelongsToRoot(hwnd, rootWindow) {
        if !hwnd || !rootWindow
            return false
        if hwnd = rootWindow
            return true
        hwndOwner := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 3, "Ptr") ; GA_ROOTOWNER
        rootOwner := DllCall("GetAncestor", "Ptr", rootWindow, "UInt", 3, "Ptr")
        return hwndOwner && rootOwner && hwndOwner = rootOwner
    }

    static TickCount64() {
        return DllCall("GetTickCount64", "UInt64")
    }

    static CaptureWindow(hwnd, allowCloaked := false) {
        if !this.IsVisibleWindow(hwnd, true, allowCloaked)
            throw TargetError("The active window is no longer available.")

        pid := WinGetPID("ahk_id " hwnd)
        processName := ""
        exePath := ""
        className := ""
        title := ""

        try processName := WinGetProcessName("ahk_id " hwnd)
        try exePath := WinGetProcessPath("ahk_id " hwnd)
        try className := WinGetClass("ahk_id " hwnd)
        try title := WinGetTitle("ahk_id " hwnd)

        title := StrReplace(StrReplace(title, "`r", " "), "`n", " ")
        return {
            hwnd: hwnd,
            pid: pid,
            processStart: this.GetProcessStartToken(pid),
            exePath: exePath,
            processName: processName,
            className: className,
            titleHint: title,
            displayName: this.DisplayName(title, processName),
            aumid: ""
        }
    }

    static GetProcessStartToken(pid) {
        if !pid
            return ""

        ; PROCESS_QUERY_LIMITED_INFORMATION
        processHandle := DllCall("OpenProcess", "UInt", 0x1000, "Int", false, "UInt", pid, "Ptr")
        if !processHandle
            return ""

        creation := Buffer(8, 0)
        exitTime := Buffer(8, 0)
        kernel := Buffer(8, 0)
        user := Buffer(8, 0)
        try {
            ok := DllCall(
                "GetProcessTimes",
                "Ptr", processHandle,
                "Ptr", creation.Ptr,
                "Ptr", exitTime.Ptr,
                "Ptr", kernel.Ptr,
                "Ptr", user.Ptr,
                "Int"
            )
            return ok ? String(NumGet(creation, 0, "UInt64")) : ""
        } finally {
            DllCall("CloseHandle", "Ptr", processHandle)
        }
    }

    static DisplayName(title, processName) {
        value := Trim(title)
        if value = ""
            value := processName
        if value = ""
            value := "未命名窗口"
        return StrLen(value) > 52 ? SubStr(value, 1, 51) "…" : value
    }

    static NormalizePath(path) {
        return StrLower(Trim(path, " `t`r`n`""))
    }

    static SamePath(left, right) {
        return left != "" && right != "" && this.NormalizePath(left) = this.NormalizePath(right)
    }

    static GetRect(hwnd) {
        rectBuffer := Buffer(16, 0)
        if !DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rectBuffer.Ptr, "Int")
            throw OSError(A_LastError, "GetWindowRect")
        left := NumGet(rectBuffer, 0, "Int")
        top := NumGet(rectBuffer, 4, "Int")
        right := NumGet(rectBuffer, 8, "Int")
        bottom := NumGet(rectBuffer, 12, "Int")
        return {x: left, y: top, width: right - left, height: bottom - top}
    }

    static GetExtendedFrameRect(hwnd) {
        rectBuffer := Buffer(16, 0)
        result := DllCall(
            "dwmapi\DwmGetWindowAttribute",
            "Ptr", hwnd,
            "UInt", 9, ; DWMWA_EXTENDED_FRAME_BOUNDS
            "Ptr", rectBuffer.Ptr,
            "UInt", 16,
            "Int"
        )
        if result != 0
            return this.GetRect(hwnd)

        left := NumGet(rectBuffer, 0, "Int")
        top := NumGet(rectBuffer, 4, "Int")
        right := NumGet(rectBuffer, 8, "Int")
        bottom := NumGet(rectBuffer, 12, "Int")
        return {x: left, y: top, width: right - left, height: bottom - top}
    }

    static OuterRectForVisibleTarget(hwnd, visibleTarget) {
        outer := this.GetRect(hwnd)
        visible := this.GetExtendedFrameRect(hwnd)
        leftBorder := visible.x - outer.x
        topBorder := visible.y - outer.y
        rightBorder := (outer.x + outer.width) - (visible.x + visible.width)
        bottomBorder := (outer.y + outer.height) - (visible.y + visible.height)
        return {
            x: visibleTarget.x - leftBorder,
            y: visibleTarget.y - topBorder,
            width: visibleTarget.width + leftBorder + rightBorder,
            height: visibleTarget.height + topBorder + bottomBorder
        }
    }

    static WorkAreaForWindow(hwnd) {
        monitor := this.MonitorHandleForWindow(hwnd)
        return this.WorkAreaForMonitorHandle(monitor)
    }

    static WorkAreaForPoint(x, y) {
        monitor := this.MonitorHandleForPoint(x, y)
        return this.WorkAreaForMonitorHandle(monitor)
    }

    static MonitorHandleForWindow(hwnd) {
        return DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr")
    }

    static MonitorHandleForPoint(x, y) {
        x := Round(x)
        y := Round(y)
        packedPoint := (y << 32) | (x & 0xFFFFFFFF)
        return DllCall("MonitorFromPoint", "Int64", packedPoint, "UInt", 2, "Ptr")
    }

    static WorkAreaForMonitorHandle(monitor) {
        info := Buffer(40, 0)
        NumPut("UInt", 40, info, 0)
        if !monitor || !DllCall("GetMonitorInfo", "Ptr", monitor, "Ptr", info.Ptr, "Int")
            return this.PrimaryWorkArea()

        left := NumGet(info, 20, "Int")
        top := NumGet(info, 24, "Int")
        right := NumGet(info, 28, "Int")
        bottom := NumGet(info, 32, "Int")
        return this.MakeArea(left, top, right, bottom, monitor)
    }

    static PrimaryWorkArea() {
        primary := MonitorGetPrimary()
        MonitorGetWorkArea(primary, &left, &top, &right, &bottom)
        return this.MakeArea(left, top, right, bottom, 0)
    }

    static AllWorkAreas() {
        monitorAreas := []
        Loop MonitorGetCount() {
            MonitorGetWorkArea(A_Index, &left, &top, &right, &bottom)
            area := this.MakeArea(left, top, right, bottom, 0)
            area.index := A_Index
            area.monitorHandle := this.MonitorHandleForPoint(area.centerX, area.centerY)
            monitorAreas.Push(area)
        }
        return monitorAreas
    }

    static MakeArea(left, top, right, bottom, monitorHandle := 0) {
        return {
            left: left,
            top: top,
            right: right,
            bottom: bottom,
            width: right - left,
            height: bottom - top,
            centerX: left + (right - left) / 2,
            centerY: top + (bottom - top) / 2,
            monitorHandle: monitorHandle
        }
    }

    static AreaForRect(rect, areas := unset) {
        if !IsSet(areas)
            areas := this.AllWorkAreas()

        best := areas[1]
        bestIntersection := -1
        for area in areas {
            overlapWidth := Max(0, Min(rect.x + rect.width, area.right) - Max(rect.x, area.left))
            overlapHeight := Max(0, Min(rect.y + rect.height, area.bottom) - Max(rect.y, area.top))
            intersection := overlapWidth * overlapHeight
            if intersection > bestIntersection {
                bestIntersection := intersection
                best := area
            }
        }
        if bestIntersection > 0
            return best

        rectCenterX := rect.x + rect.width / 2
        rectCenterY := rect.y + rect.height / 2
        bestDistance := 1.0e30
        for area in areas {
            nearestX := this.Clamp(rectCenterX, area.left, area.right)
            nearestY := this.Clamp(rectCenterY, area.top, area.bottom)
            distance := (rectCenterX - nearestX) ** 2 + (rectCenterY - nearestY) ** 2
            if distance < bestDistance {
                bestDistance := distance
                best := area
            }
        }
        return best
    }

    static FindDirectionalArea(source, direction, areas := unset) {
        if !IsSet(areas)
            areas := this.AllWorkAreas()

        best := 0
        bestScore := 1.0e30
        for area in areas {
            deltaX := area.centerX - source.centerX
            if direction = "left" && deltaX >= -1
                continue
            if direction = "right" && deltaX <= 1
                continue

            score := Abs(deltaX) + Abs(area.centerY - source.centerY) * 2
            if score < bestScore {
                bestScore := score
                best := area
            }
        }
        return best
    }

    static ProjectRect(rect, source, target) {
        relativeX := (rect.x - source.left) / Max(1, source.width)
        relativeY := (rect.y - source.top) / Max(1, source.height)
        relativeWidth := rect.width / Max(1, source.width)
        relativeHeight := rect.height / Max(1, source.height)

        width := Min(target.width, Max(240, Round(target.width * relativeWidth)))
        height := Min(target.height, Max(160, Round(target.height * relativeHeight)))
        x := Round(target.left + target.width * relativeX)
        y := Round(target.top + target.height * relativeY)
        x := this.Clamp(x, target.left, target.right - width)
        y := this.Clamp(y, target.top, target.bottom - height)
        return {x: x, y: y, width: width, height: height}
    }

    static HalfRect(area, side) {
        leftWidth := Floor(area.width / 2)
        if side = "left"
            return {x: area.left, y: area.top, width: leftWidth, height: area.height}
        return {
            x: area.left + leftWidth,
            y: area.top,
            width: area.width - leftWidth,
            height: area.height
        }
    }

    static Clamp(value, minimum, maximum) {
        if maximum < minimum
            return minimum
        return Min(maximum, Max(minimum, value))
    }
}
