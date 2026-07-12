#Requires AutoHotkey v2.0.26+
#ErrorStdOut UTF-8
#SingleInstance Off
#Warn All, StdOut

OnError(TestFatal)

#Include ..\config.ahk
#Include ..\lib\WindowUtils.ahk

global Failures := 0

AssertEqual(actual, expected, label) {
    global Failures
    if actual = expected
        return
    Failures += 1
    FileAppend("FAIL " label ": expected=" expected " actual=" actual "`n", "**")
}

AssertTrue(value, label) {
    global Failures
    if value
        return
    Failures += 1
    FileAppend("FAIL " label "`n", "**")
}

TestFatal(error, mode) {
    FileAppend(
        "FATAL " error.File ":" error.Line " " error.Message " (" mode ")`n",
        "**"
    )
    ExitApp(1)
    return true
}

; Clamp and negative-coordinate monitor geometry.
AssertEqual(WindowUtils.Clamp(5, 0, 10), 5, "clamp keeps in-range values")
AssertEqual(WindowUtils.Clamp(-5, 0, 10), 0, "clamp lower bound")
AssertEqual(WindowUtils.Clamp(15, 0, 10), 10, "clamp upper bound")

oddArea := WindowUtils.MakeArea(0, 40, 1919, 1080)
leftHalf := WindowUtils.HalfRect(oddArea, "left")
rightHalf := WindowUtils.HalfRect(oddArea, "right")
AssertEqual(leftHalf.x, 0, "left half starts at work area")
AssertEqual(leftHalf.width, 959, "odd left half width")
AssertEqual(rightHalf.x, 959, "right half has no gap")
AssertEqual(rightHalf.width, 960, "odd right half owns remainder")
AssertEqual(rightHalf.y, 40, "taskbar work-area offset is preserved")

source := WindowUtils.MakeArea(-1920, 0, 0, 1080)
target := WindowUtils.MakeArea(0, 40, 2560, 1440)
rect := {x: -1800, y: 100, width: 960, height: 540}
projected := WindowUtils.ProjectRect(rect, source, target)
AssertEqual(projected.x, 160, "projected x")
AssertEqual(projected.y, 170, "projected y")
AssertEqual(projected.width, 1280, "projected width")
AssertEqual(projected.height, 700, "projected height")
AssertTrue(projected.x >= target.left, "projected x is inside target")
AssertTrue(projected.y >= target.top, "projected y is inside target")
AssertTrue(projected.x + projected.width <= target.right, "projected right is clamped")
AssertTrue(projected.y + projected.height <= target.bottom, "projected bottom is clamped")

areas := [
    WindowUtils.MakeArea(-1920, 0, 0, 1080),
    WindowUtils.MakeArea(0, 0, 1920, 1080),
    WindowUtils.MakeArea(1920, -200, 3840, 880)
]
middle := areas[2]
AssertEqual(WindowUtils.FindDirectionalArea(middle, "left", areas).left, -1920, "find left display")
AssertEqual(WindowUtils.FindDirectionalArea(middle, "right", areas).left, 1920, "find right display")
AssertEqual(WindowUtils.AreaForRect({x: -1500, y: 100, width: 800, height: 600}, areas).left, -1920, "negative-coordinate area selection")
AssertEqual(WindowUtils.AreaForRect({x: 4100, y: 100, width: 300, height: 200}, areas).left, 1920, "off-screen rect chooses nearest display")

if Failures = 0
    FileAppend("PASS geometry tests`n", "*")
ExitApp(Failures ? 1 : 0)
