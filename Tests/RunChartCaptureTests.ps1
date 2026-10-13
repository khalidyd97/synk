$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Add-Type -Path @((Join-Path $projectRoot 'Assets/Synk/Scripts/ChartCapture.cs'), (Join-Path $projectRoot 'Assets/Synk/Scripts/ChartDocument.cs'))
function Assert-True($condition, $message) {
    if (-not $condition) { throw $message }
}
function New-Capture { return New-Object Synk.ChartCapture }
$auto = [Synk.CaptureTool]::Auto
$capture = New-Capture
Assert-True (-not $capture.Begin(1, -1, .5, .23, $auto)) 'Countdown must not record'
Assert-True (-not $capture.Begin(1, 1, .5, .8, $auto)) 'Toolbar must not record'
Assert-True ($capture.Begin(1, 1, .5, .23, $auto)) 'Valid touch begins'
$note = $capture.End(1, 1.08, .5, .23, $false)
Assert-True ($note.kind -eq 'Tap' -and $note.time -eq 1 -and $note.lane -eq 6) 'Tap keeps touch-down timestamp and lane'
$null = $capture.Begin(1, 2, .5, .23, $auto)
$note = $capture.End(1, 2.6, .5, .23, $false)
Assert-True ($note.kind -eq 'Hold' -and [Math]::Abs($note.duration - .6) -lt .001) 'Stationary long gesture becomes hold'
foreach ($case in @(@(.5, .3, 'Up'), @(.5, .15, 'Down'), @(.6, .23, 'Right'), @(.4, .23, 'Left'))) {
    $null = $capture.Begin(1, 3, .5, .23, $auto)
    $note = $capture.End(1, 3.1, $case[0], $case[1], $false)
    Assert-True ($note.kind -eq 'Flick' -and $note.direction.ToString() -eq $case[2]) "Flick direction $($case[2])"
}
$null = $capture.Begin(1, 4, .5, .23, $auto)
$capture.Move(1, 4.3, .7, .23)
$capture.Move(1, 4.6, .3, .23)
$note = $capture.End(1, 4.9, .5, .23, $false)
Assert-True ($note.kind -eq 'Slide' -and $note.path.Count -ge 4) 'Reversing slide retains full path'
Assert-True ($note.LaneAt(4.3) -gt 8 -and $note.LaneAt(4.6) -lt 4) 'Playback follows both turns'
Assert-True ([Math]::Abs($note.LaneAt(4.9) - 6) -lt .001) 'Slide ends at snapped lane'
$null = $capture.Begin(1, 5, .5, .23, [Synk.CaptureTool]::Slide)
$note = $capture.End(1, 5.1, .7, .23, $false)
Assert-True ($note.kind -eq 'Slide') 'Explicit slide tool resolves quick swipe ambiguity'
$before = $capture.notes.Count
$null = $capture.Begin(1, 6, .5, .23, $auto)
$note = $capture.End(1, 6.5, .6, .23, $true)
Assert-True ($null -eq $note -and $capture.notes.Count -eq $before) 'Canceled touch is discarded'
$null = $capture.Begin(1, 7, .5, .23, $auto)
$capture.CancelActive()
$note = $capture.End(1, 8, .5, .23, $false)
Assert-True ($null -eq $note) 'Pause discards unfinished gesture'
$capture.Clear()
$null = $capture.Begin(1, 10, .3, .23, $auto)
$null = $capture.Begin(2, 10.1, .7, .23, $auto)
$null = $capture.End(2, 10.15, .7, .23, $false)
$null = $capture.End(1, 10.5, .3, .23, $false)
$sorted = $capture.SortedNotes()
Assert-True ($sorted.Count -eq 2 -and $sorted[0].time -eq 10 -and $sorted[1].time -eq 10.1) 'Multitouch sorts by onset rather than release'
$capture.Undo()
Assert-True ($capture.notes.Count -eq 1 -and $capture.notes[0].time -eq 10.1) 'Undo removes latest completed gesture'
$capture.Undo(); $capture.Undo()
Assert-True ($capture.notes.Count -eq 0) 'Undo safely handles empty draft'
Write-Output 'PASS: chart capture timing, tap/hold/slide/four flick directions, paths, explicit tools, cancellation, multitouch, sorting and undo.'
$doc = New-Object Synk.ChartDocument
$doc.Add(2, 6)
$doc.Convert([Synk.NoteKind]::Flick, .5)
Assert-True ($doc.Selection.kind -eq 'Flick' -and $doc.Selection.duration -eq 0) 'Tap converts to flick'
$doc.Convert([Synk.NoteKind]::Tap, .5)
Assert-True ($doc.Selection.kind -eq 'Tap') 'Flick converts to tap'
$doc.Undo()
Assert-True ($doc.notes[0].kind -eq 'Flick') 'Undo restores previous type'
$doc.Redo()
Assert-True ($doc.notes[0].kind -eq 'Tap') 'Redo reapplies conversion'
$doc.selected = 0
$doc.Convert([Synk.NoteKind]::Slide, .5)
$doc.SetEndLane(9)
Assert-True ([Math]::Abs($doc.Selection.LaneAt(2.5) - 9) -lt .001) 'Converted slide follows configured end lane'
$doc.Selection.path.Add((New-Object Synk.SlidePoint -Property @{offset=0;lane=6}))
$doc.Selection.path.Add((New-Object Synk.SlidePoint -Property @{offset=.5;lane=9}))
$doc.Resize(1, 10)
Assert-True ($doc.Selection.path[1].offset -eq 1) 'Resizing stretches recorded slide path'
$doc.Checkpoint()
$doc.Move(20, 20, 10)
Assert-True ($doc.Selection.time -eq 9 -and $doc.Selection.lane -eq 12 -and $doc.Selection.endLane -eq 12) 'Dragging clamps note and slide path to song and lane bounds'
$doc.Undo()
Assert-True ($doc.notes[0].time -eq 2 -and $doc.notes[0].lane -eq 6 -and $doc.notes[0].path[1].lane -eq 9) 'Undo deep-restores paths'
$copy = [Synk.ChartDocument]::Copy($doc.notes)
$copy[0].path[1].lane = 1
Assert-True ($doc.notes[0].path[1].lane -eq 9) 'Chart previews use independent slide paths'
Assert-True ([Math]::Abs($doc.Snap(1.13, 120, 4) - 1.125) -lt .0001) 'Sixteenth-note snapping'
Assert-True ($doc.Snap(1.13, 120, 0) -eq 1.13) 'Free-time positioning'
$doc.Saved()
Assert-True (-not $doc.dirty) 'Save clears unsaved state'
$doc.selected = 0; $doc.Delete(); $doc.Undo()
Assert-True ($doc.notes.Count -eq 1 -and $doc.dirty) 'Deleted notes can be restored'
Write-Output 'PASS: editor conversion, undo/redo, slide resizing, bounded dragging, deep snapshots, snapping and save state.'
