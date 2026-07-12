#Requires AutoHotkey v2.0.26+

class WindowSlots {
    static _Slots := Map()
    static _PendingLaunches := Map()
    static _ActivationGeneration := 0

    static Init() {
        SplitPath(MyCapsloxConfig.WindowSlotFile, , &dataDirectory)
        if !DirExist(dataDirectory)
            DirCreate(dataDirectory)
        this._MigrateLegacySlotFile()

        this._Slots := Map()
        Loop MyCapsloxConfig.WindowSlotCount {
            data := this._ReadSlot(A_Index)
            if IsObject(data)
                this._Slots[A_Index] := data
        }
    }

    static Bind(slot) {
        this._ValidateSlot(slot)
        hwnd := WindowUtils.GetBindableForeground()
        if !hwnd {
            Toast.Show("当前没有可绑定的窗口", "error")
            return false
        }
        return this.BindWindow(slot, hwnd)
    }

    static BindWindow(slot, hwnd) {
        this._ValidateSlot(slot)
        if this._PendingLaunches.Has(slot)
            this._StopLaunch(slot)
        if !WindowUtils.IsVisibleWindow(hwnd) {
            Toast.Show("指定窗口不可绑定", "error")
            return false
        }

        try {
            data := WindowUtils.CaptureWindow(hwnd)
        } catch Error as err {
            Toast.Show("读取当前窗口失败：" err.Message, "error", hwnd)
            return false
        }

        if StrLower(data.processName) = "applicationframehost.exe" {
            Toast.Show("当前版本暂不支持绑定 Microsoft Store/UWP 窗口", "error", hwnd)
            return false
        }
        if data.exePath = "" && data.processName = "" {
            Toast.Show("无法读取该窗口的程序身份，可能受到管理员权限限制", "error", hwnd)
            return false
        }

        data.titleRegex := WindowTitlePatterns.Has(slot) ? WindowTitlePatterns[slot] : ""
        if data.titleRegex != "" {
            try titleMatches := RegExMatch(data.titleHint, data.titleRegex)
            catch Error {
                Toast.Show("槽位 " slot " 的 WindowTitlePatterns 正则无效", "error", hwnd)
                return false
            }
            if !titleMatches {
                Toast.Show("当前窗口标题不匹配槽位 " slot " 的 WindowTitlePatterns", "error", hwnd)
                return false
            }
        }
        data.launchCommand := WindowLaunchCommands.Has(slot) ? WindowLaunchCommands[slot] : ""
        try this._WriteSlot(slot, data)
        catch Error as err {
            Toast.Show("窗口已识别，但保存槽位失败：" err.Message, "error", hwnd)
            return false
        }
        this._Slots[slot] := data
        Toast.Show("槽位 " slot " 已绑定 · " data.displayName, "success", hwnd)
        return true
    }

    static Activate(slot) {
        this._ValidateSlot(slot)
        this._ActivationGeneration += 1
        if !this._Slots.Has(slot) {
            Toast.Show("槽位 " slot " 尚未绑定", "warning")
            return false
        }

        if this._PendingLaunches.Has(slot) {
            Toast.Show("槽位 " slot " 正在等待应用启动", "info")
            return false
        }

        data := this._Slots[slot]
        hwnd := this._FastWindow(data)
        if hwnd = -1 {
            Toast.Show("槽位 " slot " 的 WindowTitlePatterns 正则无效", "error")
            return false
        }
        if hwnd
            return this._ActivateResolved(slot, data, hwnd)

        resolved := this._FindCandidate(data)
        if resolved.status = "found"
            return this._ActivateResolved(slot, data, resolved.hwnd)

        if resolved.status = "ambiguous" {
            Toast.Show("槽位 " slot " 匹配到多个窗口，请重新绑定", "error")
            return false
        }
        if resolved.status = "other-desktop" {
            Toast.Show("槽位 " slot " 的窗口位于其他虚拟桌面", "warning")
            return false
        }
        if resolved.status = "hidden" {
            Toast.Show("槽位 " slot " 的窗口当前不可见，已避免重复启动", "warning")
            return false
        }
        if resolved.status = "invalid-pattern" {
            Toast.Show("槽位 " slot " 的 WindowTitlePatterns 正则无效", "error")
            return false
        }

        return this._BeginLaunch(slot, data)
    }

    static Clear(slot) {
        this._ValidateSlot(slot)
        if this._PendingLaunches.Has(slot)
            this._StopLaunch(slot)
        try IniDelete(MyCapsloxConfig.WindowSlotFile, "slot-" slot)
        catch Error as err {
            Toast.Show("清除槽位失败：" err.Message, "error")
            return false
        }
        if this._Slots.Has(slot)
            this._Slots.Delete(slot)
        Toast.Show("已清除窗口槽位 " slot, "info")
        return true
    }

    static _FastWindow(data) {
        hwnd := data.hwnd
        if !WindowUtils.IsVisibleWindow(hwnd)
            return 0

        try snapshot := WindowUtils.CaptureWindow(hwnd)
        catch Error
            return 0

        if snapshot.pid != data.pid
            return 0
        if data.processStart != "" && snapshot.processStart != data.processStart
            return 0
        if data.exePath != "" && !WindowUtils.SamePath(snapshot.exePath, data.exePath)
            return 0
        if data.className != "" && snapshot.className != data.className
            return 0
        if data.titleRegex != "" {
            try titleMatches := RegExMatch(snapshot.titleHint, data.titleRegex)
            catch Error
                return -1
            if !titleMatches
                return 0
        }
        return hwnd
    }

    static _FindCandidate(data) {
        candidates := []
        bestOtherDesktopScore := -1
        bestHiddenScore := -1
        if data.titleRegex != "" {
            try RegExMatch("", data.titleRegex)
            catch Error
                return {status: "invalid-pattern", hwnd: 0}
        }
        try {
            windows := data.processName != ""
                ? WinGetList("ahk_exe " data.processName)
                : WinGetList()
        } catch Error {
            return {status: "missing", hwnd: 0}
        }

        for hwnd in windows {
            if !WindowUtils.IsVisibleWindow(hwnd, true, true)
                continue

            cloaked := WindowUtils.IsCloaked(hwnd)
            try snapshot := WindowUtils.CaptureWindow(hwnd, true)
            catch Error
                continue

            ; A full executable path is the durable identity for ordinary desktop apps.
            if data.exePath != "" && !WindowUtils.SamePath(snapshot.exePath, data.exePath)
                continue
            if data.exePath = "" && data.processName != "" && StrLower(snapshot.processName) != StrLower(data.processName)
                continue

            score := data.exePath != "" ? 100 : 50
            if data.className != "" && snapshot.className = data.className
                score += 30
            else if data.exePath = "" && data.className != ""
                continue

            if data.titleRegex != "" {
                titleMatches := RegExMatch(snapshot.titleHint, data.titleRegex)
                if !titleMatches
                    continue
                score += 60
            }

            if data.titleHint != "" && snapshot.titleHint != "" {
                if snapshot.titleHint = data.titleHint
                    score += 30
                else if InStr(snapshot.titleHint, data.titleHint) || InStr(data.titleHint, snapshot.titleHint)
                    score += 10
            }

            exactStaleIdentity := snapshot.hwnd = data.hwnd
                && snapshot.pid = data.pid
                && (data.processStart = "" || snapshot.processStart = data.processStart)
            if exactStaleIdentity
                score += 50

            if cloaked {
                desktopState := WindowUtils.VirtualDesktopState(hwnd)
                if desktopState = 0 {
                    if exactStaleIdentity
                        return {status: "other-desktop", hwnd: 0}
                    bestOtherDesktopScore := Max(bestOtherDesktopScore, score)
                } else {
                    if exactStaleIdentity
                        return {status: "hidden", hwnd: 0}
                    bestHiddenScore := Max(bestHiddenScore, score)
                }
                continue
            }
            candidates.Push({hwnd: hwnd, score: score, snapshot: snapshot})
        }

        if candidates.Length = 0 {
            if bestOtherDesktopScore > bestHiddenScore
                return {status: "other-desktop", hwnd: 0}
            if bestHiddenScore >= 0
                return {status: "hidden", hwnd: 0}
            return {status: "missing", hwnd: 0}
        }

        best := candidates[1]
        ties := 0
        for candidate in candidates {
            if candidate.score > best.score {
                best := candidate
                ties := 0
            } else if candidate.hwnd != best.hwnd && candidate.score = best.score {
                ties += 1
            }
        }

        if ties > 0
            return {status: "ambiguous", hwnd: 0}
        if bestOtherDesktopScore > best.score
            return {status: "other-desktop", hwnd: 0}
        return {status: "found", hwnd: best.hwnd, snapshot: best.snapshot}
    }

    static _ActivateResolved(slot, data, hwnd) {
        if !WindowUtils.IsVisibleWindow(hwnd)
            return false

        snapshot := 0
        try snapshot := WindowUtils.CaptureWindow(hwnd)
        if IsObject(snapshot) {
            snapshot.titleRegex := data.titleRegex
            snapshot.launchCommand := data.launchCommand
            snapshot.aumid := data.aumid
            this._Slots[slot] := snapshot
            try this._WriteSlot(slot, snapshot)
            catch Error as err
                Toast.Show("窗口已找到，但槽位状态保存失败：" err.Message, "warning", hwnd)
            data := snapshot
        }

        target := WindowUtils.GetDeepestLastActivePopup(hwnd)
        foreground := WindowUtils.GetForegroundWindow()

        if WindowUtils.BelongsToRoot(foreground, hwnd) {
            try {
                WinMinimize("ahk_id " hwnd)
                Sleep(60)
                if WinGetMinMax("ahk_id " hwnd) != -1
                    throw Error("窗口拒绝最小化")
            } catch Error as err {
                Toast.Show("最小化失败：" err.Message, "error", hwnd)
                return false
            }
            Toast.Show("已最小化 · " data.displayName, "info", hwnd, 1500)
            return true
        }

        try {
            if DllCall("IsIconic", "Ptr", hwnd, "Int")
                WinRestore("ahk_id " hwnd)
            WinActivate("ahk_id " target)
            DllCall("SetForegroundWindow", "Ptr", target, "Int")
        } catch Error as err {
            Toast.Show("激活窗口失败：" err.Message, "error", hwnd)
            return false
        }

        generation := this._ActivationGeneration
        verify := ObjBindMethod(this, "_VerifyActivation", target, hwnd, data.displayName, generation)
        SetTimer(verify, -350)
        return true
    }

    static _VerifyActivation(target, rootWindow, displayName, generation) {
        if generation != this._ActivationGeneration
            return
        foreground := WindowUtils.GetForegroundWindow()
        if !WindowUtils.BelongsToRoot(foreground, rootWindow)
            Toast.Show("窗口未获得焦点，可能受到管理员权限限制 · " displayName, "warning", target)
    }

    static _BeginLaunch(slot, data) {
        command := data.launchCommand
        if command = "" && WindowLaunchCommands.Has(slot)
            command := WindowLaunchCommands[slot]
        if command = "" && data.exePath != ""
            command := Chr(34) data.exePath Chr(34)

        if command = "" {
            Toast.Show("找不到槽位 " slot " 的窗口，也没有启动命令", "error")
            return false
        }

        workingDirectory := ""
        if data.exePath != ""
            SplitPath(data.exePath, , &workingDirectory)

        try Run(command, workingDirectory, , &launchedPid)
        catch Error as err {
            Toast.Show("启动应用失败：" err.Message, "error")
            return false
        }

        pending := {
            data: data,
            deadline: WindowUtils.TickCount64() + MyCapsloxConfig.WindowLaunchTimeoutMs,
            lastHwnd: 0,
            stableCount: 0,
            timer: 0
        }
        pending.timer := ObjBindMethod(this, "_PollLaunch", slot)
        this._PendingLaunches[slot] := pending
        SetTimer(pending.timer, MyCapsloxConfig.WindowLaunchPollMs)
        Toast.Show("正在启动 · " data.displayName, "info")
        return true
    }

    static _PollLaunch(slot) {
        if !this._PendingLaunches.Has(slot)
            return

        pending := this._PendingLaunches[slot]
        resolved := this._FindCandidate(pending.data)
        if resolved.status = "ambiguous" {
            this._StopLaunch(slot)
            Toast.Show("应用已启动，但槽位 " slot " 匹配到多个窗口", "error")
            return
        }

        if resolved.status = "found" {
            if pending.lastHwnd = resolved.hwnd
                pending.stableCount += 1
            else {
                pending.lastHwnd := resolved.hwnd
                pending.stableCount := 1
            }

            if pending.stableCount >= 2 {
                data := pending.data
                hwnd := resolved.hwnd
                this._StopLaunch(slot)
                this._ActivateResolved(slot, data, hwnd)
                return
            }
        }

        if WindowUtils.TickCount64() >= pending.deadline {
            displayName := pending.data.displayName
            this._StopLaunch(slot)
            Toast.Show("等待窗口超时 · " displayName, "error")
        }
    }

    static _StopLaunch(slot) {
        if !this._PendingLaunches.Has(slot)
            return
        pending := this._PendingLaunches[slot]
        if IsObject(pending.timer)
            SetTimer(pending.timer, 0)
        this._PendingLaunches.Delete(slot)
    }

    static _ReadSlot(slot) {
        if !FileExist(MyCapsloxConfig.WindowSlotFile)
            return 0

        section := "slot-" slot
        try {
            schemaVersion := IniRead(MyCapsloxConfig.WindowSlotFile, section, "schemaVersion", "1")
            if schemaVersion != "1"
                return 0
            processName := IniRead(MyCapsloxConfig.WindowSlotFile, section, "processName", "")
            exePath := IniRead(MyCapsloxConfig.WindowSlotFile, section, "exePath", "")
            if processName = "" && exePath = ""
                return 0

            return {
                hwnd: IniRead(MyCapsloxConfig.WindowSlotFile, section, "lastHwnd", "0") + 0,
                pid: IniRead(MyCapsloxConfig.WindowSlotFile, section, "lastPid", "0") + 0,
                processStart: IniRead(MyCapsloxConfig.WindowSlotFile, section, "lastProcessStart", ""),
                exePath: exePath,
                processName: processName,
                className: IniRead(MyCapsloxConfig.WindowSlotFile, section, "className", ""),
                titleHint: IniRead(MyCapsloxConfig.WindowSlotFile, section, "titleHint", ""),
                displayName: IniRead(MyCapsloxConfig.WindowSlotFile, section, "displayName", processName),
                titleRegex: WindowTitlePatterns.Has(slot)
                    ? WindowTitlePatterns[slot]
                    : IniRead(MyCapsloxConfig.WindowSlotFile, section, "titleRegex", ""),
                aumid: IniRead(MyCapsloxConfig.WindowSlotFile, section, "aumid", ""),
                launchCommand: WindowLaunchCommands.Has(slot) ? WindowLaunchCommands[slot] : ""
            }
        } catch Error {
            return 0
        }
    }

    static _MigrateLegacySlotFile() {
        target := MyCapsloxConfig.WindowSlotFile
        defaultTarget := MyCapsloxDataDirectory "\window-slots.ini"
        legacy := A_ScriptDir "\data\window-slots.ini"
        if !WindowUtils.SamePath(target, defaultTarget)
            return
        if FileExist(target) || !FileExist(legacy) || WindowUtils.SamePath(target, legacy)
            return
        try FileCopy(legacy, target, false)
    }

    static _WriteSlot(slot, data) {
        section := "slot-" slot
        slotFile := MyCapsloxConfig.WindowSlotFile
        pairs := "schemaVersion=1`n"
        pairs .= "displayName=" data.displayName "`n"
        pairs .= "exePath=" data.exePath "`n"
        pairs .= "processName=" data.processName "`n"
        pairs .= "className=" data.className "`n"
        pairs .= "titleHint=" data.titleHint "`n"
        pairs .= "titleRegex=" data.titleRegex "`n"
        pairs .= "aumid=" data.aumid "`n"
        pairs .= "lastHwnd=" data.hwnd "`n"
        pairs .= "lastPid=" data.pid "`n"
        pairs .= "lastProcessStart=" data.processStart
        IniWrite(pairs, slotFile, section)
    }

    static _ValidateSlot(slot) {
        if slot < 1 || slot > MyCapsloxConfig.WindowSlotCount
            throw ValueError("Invalid window slot: " slot)
    }
}
