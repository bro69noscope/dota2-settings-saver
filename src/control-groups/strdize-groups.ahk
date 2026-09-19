#Requires AutoHotkey v2.0
#SingleInstance Force
#Include overlay.ahk

; =========================================================
; === Globals ===
; =========================================================

; --- Dota user keys --- Update as needed. Fkeys require braces e.g. {F1}
; same for end, etc: {end}, {home} ...
CtrlGroups := Map(
  1, "6",
  2, "8",
  3, "9",
  4, "5",
  5, "{F2}",
  6, "{F4}",
  7, "{F3}",
  8, "!6",
  9, "!8",
  10, "!7"
)

ALL_OTHER_UNITS_KEY := "m"
CAM_POS_KEY := "{End}"
ITEM_SLOT1_KEY := "g"
NEXT_UNIT_KEY := "0"
SHOP_KEY := ";"
DEV_TP_KEY := "{F7}"

; =========================================================
; === Sequence coordinates === Update as needed
; Normally, only screen resolution REF_WIDTH REF_HEIGHT and dota heroes amount need to
; be changed, as long as your aspect ratio is 16:9.
; =========================================================

DOTA_CURRENT_HEROES_AMOUNT := 127
REF_WIDTH := 2560
REF_HEIGHT := 1440

; --- Hero grid layout ---

; pushing only to have a nicer formatting of the code even with an aggressive formatter
HeroCategories := []
HeroCategories.Push({ name: "str", rows: 9, cols: 4 })
HeroCategories.Push({ name: "agi", rows: 9, cols: 4, lastRowCols: 3 })
HeroCategories.Push({ name: "int", rows: 9, cols: 4, lastRowCols: 2 })
HeroCategories.Push({ name: "universal", rows: 8, cols: 3, lastRowCols: 1 })

ScaleX(v) {
  return Round(v * A_ScreenWidth / REF_WIDTH)
}

ScaleY(v) {
  return Round(v * A_ScreenHeight / REF_HEIGHT)
}

GRID_START_X_REF := 435
GRID_START_Y_REF := 325
COL_OFFSET_X_REF := 75
COL_OFFSET_Y_REF := 0
ROW_OFFSET_X_REF := 0
ROW_OFFSET_Y_REF := 75
CATEGORY_OFFSET_X_REF := 330
CATEGORY_OFFSET_Y_REF := 0

HERO_CHANGE_X_REF := 188
HERO_CHANGE_Y_REF := 230
HERO_CHANGE_CLOSE_X_REF := 1640
HERO_CHANGE_CLOSE_Y_REF := 200

DEMO_HERO_X_REF := 310
DEMO_HERO_Y_REF := 920

QUIT_X_REF := 310
QUIT_Y_REF := 860

MORE_SUBMENU_X_REF := 310
MORE_SUBMENU_Y_REF := 180

LOAD_HERO_X_REF := 175
LOAD_HERO_Y_REF := 294

RUNE_SPAWN_X_REF := 511
RUNE_SPAWN_Y_REF := 225

RUNE_SELECT_X_REF := 1404
RUNE_SELECT_Y_REF := 584

REMOVE_X_REF := 300
REMOVE_Y_REF := 530

SHOP_SEARCH_X_REF := 2110
SHOP_SEARCH_Y_REF := 80

; --- Scaled to actual screen resolution ---
GRID_START_X := ScaleX(GRID_START_X_REF)
GRID_START_Y := ScaleY(GRID_START_Y_REF)
COL_OFFSET_X := ScaleX(COL_OFFSET_X_REF)
COL_OFFSET_Y := ScaleY(COL_OFFSET_Y_REF)
ROW_OFFSET_X := ScaleX(ROW_OFFSET_X_REF)
ROW_OFFSET_Y := ScaleY(ROW_OFFSET_Y_REF)
CATEGORY_OFFSET_X := ScaleX(CATEGORY_OFFSET_X_REF)
CATEGORY_OFFSET_Y := ScaleY(CATEGORY_OFFSET_Y_REF)

HERO_CHANGE_X := ScaleX(HERO_CHANGE_X_REF)
HERO_CHANGE_Y := ScaleY(HERO_CHANGE_Y_REF)
HERO_CHANGE_CLOSE_X := ScaleX(HERO_CHANGE_CLOSE_X_REF)
HERO_CHANGE_CLOSE_Y := ScaleY(HERO_CHANGE_CLOSE_Y_REF)

DEMO_HERO_X := ScaleX(DEMO_HERO_X_REF)
DEMO_HERO_Y := ScaleY(DEMO_HERO_Y_REF)

QUIT_X := ScaleX(QUIT_X_REF)
QUIT_Y := ScaleY(QUIT_Y_REF)

MORE_SUBMENU_X := ScaleX(MORE_SUBMENU_X_REF)
MORE_SUBMENU_Y := ScaleY(MORE_SUBMENU_Y_REF)

TP_MOUSE_X := A_ScreenWidth // 2
TP_MOUSE_Y := A_ScreenHeight // 2

LOAD_HERO_X := ScaleX(LOAD_HERO_X_REF)
LOAD_HERO_Y := ScaleY(LOAD_HERO_Y_REF)

RUNE_SPAWN_X := ScaleX(RUNE_SPAWN_X_REF)
RUNE_SPAWN_Y := ScaleY(RUNE_SPAWN_Y_REF)

RUNE_SELECT_X := ScaleX(RUNE_SELECT_X_REF)
RUNE_SELECT_Y := ScaleY(RUNE_SELECT_Y_REF)

REMOVE_X := ScaleX(REMOVE_X_REF)
REMOVE_Y := ScaleY(REMOVE_Y_REF)

SHOP_SEARCH_X := ScaleX(SHOP_SEARCH_X_REF)
SHOP_SEARCH_Y := ScaleY(SHOP_SEARCH_Y_REF)


; -- other globals ---
MANTA_SEARCH_TEXT := "manta style"
Cells := BuildCells()
HeroIndex := 1
SHORT_SLEEP := 100
NORMAL_SLEEP := 250

; =========================================================
; === Grid math ===
; =========================================================

ColsInRow(cat, row) {
  return (row = cat.rows && cat.HasOwnProp("lastRowCols")) ? cat.lastRowCols : cat.cols
}

HeroPos(catIdx, row, col) {
  x :=
    GRID_START_X + (catIdx * CATEGORY_OFFSET_X) +
    ((row - 1) * ROW_OFFSET_X) +
    ((col - 1) * COL_OFFSET_X)

  y :=
    GRID_START_Y + (catIdx * CATEGORY_OFFSET_Y) +
    ((row - 1) * ROW_OFFSET_Y) +
    ((col - 1) * COL_OFFSET_Y)

  return { x: x, y: y }
}

BuildCells() {
  cells := []
  for catIdx, cat in HeroCategories {
    loop cat.rows {
      row := A_Index
      cols := ColsInRow(cat, row)
      loop cols {
        pos := HeroPos(catIdx - 1, row, A_Index)
        cells.Push(pos)
      }
    }
  }
  return cells
}

; =========================================================
; === Input helpers ===
; =========================================================

WaitForStepKey() {
  loop {
    if GetKeyState("Left", "P") {
      while GetKeyState("Left", "P")
        Sleep(10)
      return "Left"
    }
    if GetKeyState("Right", "P") {
      while GetKeyState("Right", "P")
        Sleep(10)
      return "Right"
    }
    Sleep(10)
  }
}

DebugPause(label, x, y) {
  ToolTip(label . "`nPos: " x ", " y)
  WaitForStepKey()
  ToolTip()
  Sleep(SHORT_SLEEP)
}

; =========================================================
; === Step primitives ===
; =========================================================

AssignGroup(n) {
  Send("^" CtrlGroups[n])
}

ClickStep(label, x, y, debug, button := "Left", sleeptime := NORMAL_SLEEP) {
  MouseMove(x, y, 0)
  if debug
    DebugPause(label, x, y)
  Click(button)
  if !debug
    Sleep(sleeptime)
}

KeyStep(label, keyStr, debug, sleeptime := NORMAL_SLEEP) {
  Send(keyStr)
  if debug {
    MouseGetPos(&mx, &my)
    DebugPause(label, mx, my)
  } else
    Sleep(sleeptime)
}

GroupStep(label, groupNum, debug, sleeptime := NORMAL_SLEEP) {
  AssignGroup(groupNum)
  if debug {
    MouseGetPos(&mx, &my)
    DebugPause(label, mx, my)
  } else
    Sleep(sleeptime)
}

TypeStep(label, text, debug, sleeptime := NORMAL_SLEEP) {
  SendText(text)
  if debug {
    MouseGetPos(&mx, &my)
    DebugPause(label, mx, my)
  } else
    Sleep(sleeptime)
}

; =========================================================
; === High-level flows ===
; =========================================================

TeleportToSpot(debug) {
  Send(CAM_POS_KEY)
  if debug
    DebugPause("Camera pos key sent", TP_MOUSE_X, TP_MOUSE_Y)
  else
    Sleep(NORMAL_SLEEP)

  MouseMove(TP_MOUSE_X, TP_MOUSE_Y, 0)
  if debug
    DebugPause("Teleport mouse pos", TP_MOUSE_X, TP_MOUSE_Y)
  else
    Sleep(NORMAL_SLEEP)

  Send(DEV_TP_KEY)
  if debug
    DebugPause("Teleport sent", TP_MOUSE_X, TP_MOUSE_Y)
  else
    Sleep(NORMAL_SLEEP)
}

RunSequence(debug := false) {
  global HeroIndex
  TeleportToSpot(debug)
  ClickStep("Change hero", HERO_CHANGE_X, HERO_CHANGE_Y, debug)
  pos := Cells[HeroIndex]
  ClickStep("Hero pick (" HeroIndex "/" Cells.Length ")", pos.x, pos.y, debug, , 100)
  ClickStep("Close Hero pick", HERO_CHANGE_CLOSE_X, HERO_CHANGE_CLOSE_Y, debug, , 100)
  ClickStep("Load Hero", LOAD_HERO_X, LOAD_HERO_Y, debug, , 700)
  ClickStep("Rune spawn", RUNE_SPAWN_X, RUNE_SPAWN_Y, debug)

  ClickStep("Rune select", RUNE_SELECT_X, RUNE_SELECT_Y, debug, "Right", 700)
  KeyStep("Next unit", NEXT_UNIT_KEY, debug, 50)
  GroupStep("Assign group 8", 8, debug, 50)
  KeyStep("Next unit", NEXT_UNIT_KEY, debug, 50)
  GroupStep("Assign group 9", 9, debug, 50)
  KeyStep("All other units", ALL_OTHER_UNITS_KEY, debug, 50)
  GroupStep("Assign group 10", 10, debug, 100)
  ClickStep("Remove", REMOVE_X, REMOVE_Y, debug, , 400)

  KeyStep("Open shop", SHOP_KEY, debug)
  ClickStep("Shop search", SHOP_SEARCH_X, SHOP_SEARCH_Y, debug, , 50)
  TypeStep("Type manta style", MANTA_SEARCH_TEXT, debug, 100)
  KeyStep("Confirm search", "{Enter}", debug)
  KeyStep("Close shop", SHOP_KEY, debug)
  KeyStep("Item slot 1", ITEM_SLOT1_KEY, debug)
  KeyStep("Next unit", NEXT_UNIT_KEY, debug, 50)
  GroupStep("Assign group 5", 5, debug, 50)
  KeyStep("Next unit", NEXT_UNIT_KEY, debug, 50)
  GroupStep("Assign group 6", 6, debug, 50)
  KeyStep("All other units", ALL_OTHER_UNITS_KEY, debug, 50)
  GroupStep("Assign group 7", 7, debug)
  ClickStep("Remove", REMOVE_X, REMOVE_Y, debug)

  HeroIndex := Mod(HeroIndex, Cells.Length) + 1
}

DryRunOffsets() {
  ClickStep("Change hero", HERO_CHANGE_X, HERO_CHANGE_Y, debug := false)
  cells := []
  for catIdx, cat in HeroCategories {
    loop cat.rows {
      row := A_Index
      cols := ColsInRow(cat, row)
      loop cols
        cells.Push({ cat: cat, catIdx: catIdx, row: row, col: A_Index })
    }
  }

  i := 1
  while i <= cells.Length {
    c := cells[i]
    pos := HeroPos(c.catIdx - 1, c.row, c.col)
    MouseMove(pos.x, pos.y, 0)
    ToolTip(c.cat.name . " r" c.row " c" c.col . "`nPos: " pos.x ", " pos.y)
    key := WaitForStepKey()
    i += (key = "Right") ? 5 : 1
  }
  ToolTip()
}

RunHeroesRange(startIndex := 1, endIndex := 0) {
  global HeroIndex
  if !endIndex
    endIndex := Cells.Length
  HeroIndex := startIndex
  remaining := endIndex - startIndex + 1
  loop remaining {
    RunSequence()
  }
}

TakeABreakToAvoidCrashes() {
  ; trying to go through all heroes in one go seems to always crash the game at some
  ; point. Maybe we are loading too many different entities. Probably an upstream bug

  ; back to main menu
  MouseMove(QUIT_X, QUIT_Y, 0)
  Click()
  Sleep(6000)

  ; back to demo hero
  MouseMove(DEMO_HERO_X, DEMO_HERO_Y, 0)
  Click()
  Sleep(17000)
  ClickStep("Open 'more' submenu", MORE_SUBMENU_X, MORE_SUBMENU_Y, debug := false)
}

; =========================================================
; === Usage Hotkeys ===
; =========================================================

#HotIf WinActive("ahk_exe dota2.exe")
!F1:: RunSequence(debug := false) ; test run
!F2:: RunSequence(debug := true) ; test run with manual step-through
!f3:: Reload
!f5:: DryRunOffsets() ; run to verify that the hero grid values are correct

!f6:: { ; run for all heroes
  half := DOTA_CURRENT_HEROES_AMOUNT // 2
  RunHeroesRange(1, half)
  TakeABreakToAvoidCrashes()
  RunHeroesRange(half + 1, DOTA_CURRENT_HEROES_AMOUNT)
}

!f7:: { ; run for a range of heroes (using their index in the hero, base 1)
  result := InputBox("Start-End (e.g. 5-20), or just Start", "Run all heroes")
  if result.Result = "Cancel"
    return
  parts := StrSplit(result.Value, "-")
  startIdx := Integer(Trim(parts[1]))
  endIdx := parts.Length >= 2 ? Integer(Trim(parts[2])) : 0
  WinActivate("ahk_exe dota2.exe")
  RunHeroesRange(startIdx, endIdx)
}

!f8:: ToggleMousePosOverlay() ; use it to figure out the coordinates constants
#HotIf

esc:: Pause ; emergency
!f4:: ExitApp
