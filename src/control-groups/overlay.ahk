overlayGui := ""
isShowing := false

ToggleMousePosOverlay() {
  global isShowing
  if (isShowing) {
    HideMousePosOverlay()
  } else {
    ShowMousePosOverlay()
  }
}

ShowMousePosOverlay() {
  global overlayGui, isShowing

  ; Create a GUI window
  overlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
  overlayGui.BackColor := "Black"
  overlayGui.SetFont("s12 cLime", "Consolas")
  overlayGui.Add("Text", "vPosText w200 h30 Center", "X: 0000 Y: 0000")
  overlayGui.Show("x10 y10 NoActivate")

  isShowing := true

  ; Update position every 50ms
  SetTimer(UpdatePosition, 50)
}

HideMousePosOverlay() {
  global overlayGui, isShowing

  SetTimer(UpdatePosition, 0)  ; Stop the timer
  if (overlayGui)
    overlayGui.Destroy()

  isShowing := false
}

UpdatePosition() {
  global overlayGui

  MouseGetPos(&xPos, &yPos)
  overlayGui["PosText"].Text := "X: " . xPos . " Y: " . yPos
}
