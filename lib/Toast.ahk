#Requires AutoHotkey v2.0.26+

class Toast {
    static _CurrentGui := 0
    static _Generation := 0
    static _DismissTimer := 0

    static Show(message, kind := "success", targetHwnd := 0, durationMs := 0) {
        this._Generation += 1
        generation := this._Generation
        this._DestroyCurrent()

        palette := this._Palette(kind)
        toastGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000 -DPIScale")
        toastGui.MarginX := 20
        toastGui.MarginY := 13
        toastGui.BackColor := palette.background
        toastGui.SetFont("s10 w600 c" palette.foreground, "Microsoft YaHei UI")
        toastGui.AddText("Center", palette.symbol "  " message)
        toastGui.Show("Hide AutoSize")
        toastRect := WindowUtils.GetRect(toastGui.Hwnd)
        toastWidth := toastRect.width
        toastHeight := toastRect.height

        area := targetHwnd && WindowUtils.IsWindow(targetHwnd)
            ? WindowUtils.WorkAreaForWindow(targetHwnd)
            : WindowUtils.PrimaryWorkArea()

        if targetHwnd && WindowUtils.IsWindow(targetHwnd) && !DllCall("IsIconic", "Ptr", targetHwnd, "Int") {
            try {
                targetRect := WindowUtils.GetExtendedFrameRect(targetHwnd)
                x := Round(targetRect.x + (targetRect.width - toastWidth) / 2)
                y := targetRect.y + 42
            } catch Error {
                x := Round(area.left + (area.width - toastWidth) / 2)
                y := area.top + 42
            }
        } else {
            x := Round(area.left + (area.width - toastWidth) / 2)
            y := area.top + 42
        }

        x := WindowUtils.Clamp(x, area.left + 8, area.right - toastWidth - 8)
        y := WindowUtils.Clamp(y, area.top + 8, area.bottom - toastHeight - 8)

        try WinSetTransparent(245, toastGui.Hwnd)
        this._SetRoundedCorners(toastGui.Hwnd)
        toastGui.Show("NA x" x " y" y)

        this._CurrentGui := toastGui
        if durationMs <= 0
            durationMs := kind = "error" ? MyCapsloxConfig.ToastErrorDurationMs : MyCapsloxConfig.ToastDurationMs

        this._DismissTimer := ObjBindMethod(this, "_BeginDismiss", toastGui, generation)
        SetTimer(this._DismissTimer, -durationMs)
    }

    static _BeginDismiss(toastGui, generation) {
        if generation != this._Generation || !IsObject(toastGui)
            return

        steps := 6
        stepDuration := Max(10, Floor(MyCapsloxConfig.ToastFadeDurationMs / steps))
        Loop steps {
            if generation != this._Generation || !WindowUtils.IsWindow(toastGui.Hwnd)
                return
            alpha := Max(0, 245 - Round(245 * A_Index / steps))
            try WinSetTransparent(alpha, toastGui.Hwnd)
            Sleep(stepDuration)
        }

        if generation = this._Generation
            this._DestroyCurrent()
    }

    static _DestroyCurrent() {
        if IsObject(this._DismissTimer) {
            try SetTimer(this._DismissTimer, 0)
        }
        this._DismissTimer := 0

        if IsObject(this._CurrentGui) {
            try this._CurrentGui.Destroy()
        }
        this._CurrentGui := 0
    }

    static _SetRoundedCorners(hwnd) {
        preference := 2 ; DWMWCP_ROUND
        try DllCall(
            "dwmapi\DwmSetWindowAttribute",
            "Ptr", hwnd,
            "UInt", 33,
            "Int*", &preference,
            "UInt", 4,
            "Int"
        )
    }

    static _Palette(kind) {
        switch kind {
            case "error":
                return {background: "7F1D1D", foreground: "FFFFFF", symbol: "×"}
            case "warning":
                return {background: "78350F", foreground: "FFF7ED", symbol: "!"}
            case "info":
                return {background: "1E3A5F", foreground: "EFF6FF", symbol: "i"}
            default:
                return {background: "173F35", foreground: "ECFDF5", symbol: "✓"}
        }
    }
}
