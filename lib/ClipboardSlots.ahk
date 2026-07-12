#Requires AutoHotkey v2.0.26+

class ClipboardSlots {
    static _Slots := Map()
    static _RestoreGeneration := 0
    static _RestoreBaseline := 0
    static _RestoreTimer := 0

    static Copy(slot) {
        return this._Capture(slot, false)
    }

    static Cut(slot) {
        return this._Capture(slot, true)
    }

    static Paste(slot, plainText := false) {
        if !this._Slots.Has(slot) {
            Toast.Show("剪贴板槽位 " slot " 为空", "warning")
            return false
        }

        target := WindowUtils.GetForegroundWindow()
        createdBaseline := !IsObject(this._RestoreBaseline)
        if createdBaseline
            this._RestoreBaseline := ClipboardAll()
        this._RestoreGeneration += 1
        generation := this._RestoreGeneration
        if IsObject(this._RestoreTimer)
            SetTimer(this._RestoreTimer, 0)
        this._RestoreTimer := 0

        record := this._Slots[slot]
        try {
            A_Clipboard := plainText ? record.text : record.all
            if !ClipWait(0.6, true)
                throw Error("无法写入系统剪贴板")
            Send("^v")
        } catch Error as err {
            if IsObject(this._RestoreBaseline) {
                A_Clipboard := this._RestoreBaseline
                this._RestoreBaseline := 0
            }
            Toast.Show("粘贴失败：" err.Message, "error", target)
            return false
        }

        expectedSequence := DllCall("GetClipboardSequenceNumber", "UInt")
        this._RestoreTimer := ObjBindMethod(this, "_RestoreClipboard", generation, expectedSequence)
        SetTimer(this._RestoreTimer, -MyCapsloxConfig.ClipboardRestoreDelayMs)
        return true
    }

    static _Capture(slot, cut) {
        this._FlushPendingRestore()
        target := WindowUtils.GetForegroundWindow()
        originalClipboard := ClipboardAll()
        try {
            A_Clipboard := ""
            Send(cut ? "^x" : "^c")
            if !ClipWait(1.0, true)
                throw Error(cut ? "没有可剪切的内容" : "没有可复制的内容")

            this._Slots[slot] := {
                all: ClipboardAll(),
                text: A_Clipboard
            }
            A_Clipboard := originalClipboard
        } catch Error as err {
            A_Clipboard := originalClipboard
            Toast.Show((cut ? "剪切" : "复制") "失败：" err.Message, "error", target)
            return false
        }

        Toast.Show((cut ? "已剪切到" : "已复制到") "剪贴板槽位 " slot, "success", target, 1400)
        return true
    }

    static _RestoreClipboard(generation, expectedSequence) {
        if generation != this._RestoreGeneration
            return
        if IsObject(this._RestoreBaseline)
            && DllCall("GetClipboardSequenceNumber", "UInt") = expectedSequence
            try A_Clipboard := this._RestoreBaseline
        this._RestoreBaseline := 0
        this._RestoreTimer := 0
    }

    static _FlushPendingRestore() {
        this._RestoreGeneration += 1
        if IsObject(this._RestoreTimer)
            SetTimer(this._RestoreTimer, 0)
        this._RestoreTimer := 0
        if IsObject(this._RestoreBaseline)
            try A_Clipboard := this._RestoreBaseline
        this._RestoreBaseline := 0
    }
}
