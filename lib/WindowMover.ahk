#Requires AutoHotkey v2.0.26+

class WindowMover {
    static Snap(side) {
        hwnd := WindowUtils.GetBindableForeground()
        if !hwnd {
            Toast.Show("当前没有可移动的窗口", "error")
            return false
        }

        return this.SnapWindow(hwnd, side)
    }

    static SnapWindow(hwnd, side) {
        if !WindowUtils.IsVisibleWindow(hwnd) {
            Toast.Show("指定窗口不可移动", "error")
            return false
        }

        area := WindowUtils.WorkAreaForWindow(hwnd)
        target := WindowUtils.HalfRect(area, side)
        return this._Move(hwnd, target, false, side = "left" ? "已贴靠左半屏" : "已贴靠右半屏")
    }

    static Maximize() {
        hwnd := WindowUtils.GetBindableForeground()
        if !hwnd {
            Toast.Show("当前没有可最大化的窗口", "error")
            return false
        }
        try WinMaximize("ahk_id " hwnd)
        catch Error as err {
            Toast.Show("最大化失败：" err.Message, "error", hwnd)
            return false
        }
        return true
    }

    static RestoreOrMinimize() {
        hwnd := WindowUtils.GetBindableForeground()
        if !hwnd {
            Toast.Show("当前没有可操作的窗口", "error")
            return false
        }

        try {
            state := WinGetMinMax("ahk_id " hwnd)
            if state = 1
                WinRestore("ahk_id " hwnd)
            else
                WinMinimize("ahk_id " hwnd)
        } catch Error as err {
            Toast.Show("调整窗口失败：" err.Message, "error", hwnd)
            return false
        }
        return true
    }

    static MoveToMonitor(direction) {
        hwnd := WindowUtils.GetBindableForeground()
        if !hwnd {
            Toast.Show("当前没有可移动的窗口", "error")
            return false
        }

        return this.MoveWindowToMonitor(hwnd, direction)
    }

    static MoveWindowToMonitor(hwnd, direction) {
        if !WindowUtils.IsVisibleWindow(hwnd) {
            Toast.Show("指定窗口不可移动", "error")
            return false
        }

        try {
            wasMaximized := WinGetMinMax("ahk_id " hwnd) = 1
            sourceArea := WindowUtils.WorkAreaForWindow(hwnd)
            if wasMaximized {
                WinRestore("ahk_id " hwnd)
                Sleep(60)
            }
            rect := WindowUtils.GetExtendedFrameRect(hwnd)
        } catch Error as err {
            if IsSet(wasMaximized) && wasMaximized
                try WinMaximize("ahk_id " hwnd)
            Toast.Show("读取窗口位置失败：" err.Message, "error", hwnd)
            return false
        }

        areas := WindowUtils.AllWorkAreas()
        source := WindowUtils.AreaForRect({
            x: sourceArea.left,
            y: sourceArea.top,
            width: sourceArea.width,
            height: sourceArea.height
        }, areas)
        targetArea := WindowUtils.FindDirectionalArea(source, direction, areas)
        if !IsObject(targetArea) {
            if wasMaximized
                try WinMaximize("ahk_id " hwnd)
            Toast.Show(direction = "left" ? "左侧没有其他显示器" : "右侧没有其他显示器", "info", hwnd)
            return false
        }

        targetRect := WindowUtils.ProjectRect(rect, source, targetArea)
        label := direction = "left" ? "已移动到左侧显示器" : "已移动到右侧显示器"
        return this._Move(hwnd, targetRect, wasMaximized, label, targetArea)
    }

    static _Move(hwnd, target, maximizeAfter, successMessage, expectedArea := 0) {
        try {
            if WinGetMinMax("ahk_id " hwnd) = 1 {
                WinRestore("ahk_id " hwnd)
                Sleep(40)
            }
            outerTarget := WindowUtils.OuterRectForVisibleTarget(hwnd, target)
            WinMove(outerTarget.x, outerTarget.y, outerTarget.width, outerTarget.height, "ahk_id " hwnd)
            this._WaitForMove(hwnd, target, expectedArea)
            if maximizeAfter
                WinMaximize("ahk_id " hwnd)
        } catch Error as err {
            if maximizeAfter && WindowUtils.IsWindow(hwnd)
                try WinMaximize("ahk_id " hwnd)
            Toast.Show("移动窗口失败，可能受到管理员权限限制：" err.Message, "error", hwnd)
            return false
        }

        Toast.Show(successMessage, "success", hwnd, 1400)
        return true
    }

    static _WaitForMove(hwnd, target, expectedArea := 0) {
        deadline := WindowUtils.TickCount64() + 500
        lastActual := 0
        targetAreaSamples := 0

        Loop {
            Sleep(40)
            if !WindowUtils.IsWindow(hwnd)
                throw Error("窗口在移动过程中已关闭")

            lastActual := WindowUtils.GetExtendedFrameRect(hwnd)
            if IsObject(expectedArea) {
                actualMonitor := WindowUtils.MonitorHandleForWindow(hwnd)
                expectedMonitor := expectedArea.monitorHandle
                if actualMonitor && expectedMonitor
                    monitorMatches := actualMonitor = expectedMonitor
                else
                    monitorMatches := this._SameArea(WindowUtils.WorkAreaForWindow(hwnd), expectedArea)

                if monitorMatches
                    targetAreaSamples += 1
                else
                    targetAreaSamples := 0

                ; Wait for several samples so a pending WM_DPICHANGED can settle.
                if targetAreaSamples >= 3
                    return lastActual
            } else {
                positionMatches := Abs(lastActual.x - target.x) <= 48
                    && Abs(lastActual.y - target.y) <= 48
                sizeMatches := Abs(lastActual.width - target.width) <= 64
                    && Abs(lastActual.height - target.height) <= 64
                if positionMatches && sizeMatches
                    return lastActual
            }

            if WindowUtils.TickCount64() >= deadline
                break
        }

        if IsObject(expectedArea)
            throw Error("窗口拒绝移动到目标显示器")
        if !IsObject(lastActual)
            throw Error("无法验证窗口位置")
        if Abs(lastActual.x - target.x) > 48 || Abs(lastActual.y - target.y) > 48
            throw Error("窗口拒绝了目标位置")
        throw Error("窗口拒绝了目标尺寸")
    }

    static _SameArea(left, right) {
        return left.left = right.left
            && left.top = right.top
            && left.right = right.right
            && left.bottom = right.bottom
    }
}
