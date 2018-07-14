
[console]::CursorVisible=$false
#Clear-Host
write-host
$originalBufferSize = $Host.UI.RawUI.BufferSize
$Host.UI.RawUI.BufferSize = $Host.UI.RawUI.WindowSize
$Script:Exit = $false
$Script:Score = 0
$fenceColor = 'Yellow'

# :TODO: For shits and giggles, I could remove the segment 
# array list and add a script method to the worm that 
# constructs a correctly ordered array from the hashmap 
# and then erases the worm from the tip of the tail to its 
# head. Maybe keep the head on screen for gore and merriment.
# This would also have the benefit of not having to add to 
# the array list while the game is ongoing.
# :TODO: Remove the fence when game ends
# :TODO: Diagonal movement! Or not, maybe.
# :TODO: Clear the first row
# :TODO: Clear other areas outside of the play area
# :TODO: Tasty morsels!
# :TODO: Might want to add a win state too at some point...
# ...though I guess when you start generating tasty morsels, 
# the game could just go on forever.
# :TODO: Allow play area to be set via parameter(s)

$playArea = @{
    UpperLeft = [PSCustomObject]@{
        X = 1
        Y = 2 # Leave the first row for the score counter
    }
    BottomLeft = [PSCustomObject]@{
        X = 1
        Y = $Host.UI.RawUI.BufferSize.Height - 2
    }
    BottomRight = [PSCustomObject]@{
        X = $Host.UI.RawUI.BufferSize.Width - 2
        Y = $Host.UI.RawUI.BufferSize.Height - 2
    }
    UpperRight = [PSCustomObject]@{
        X = $Host.UI.RawUI.BufferSize.Width - 2
        Y = 2 # Leave the first row for the score counter
    }
}

# If the width of the $playArea isn't divisible by two...
if ((($UpperRight.X - $UpperLeft.X + 1) % 2) -ne 0) {
    # ...decrease its width by one so that it will be!
    $playArea.UpperLeft.X += 1
    $playArea.BottomLeft.X += 1
}

$worm = [PSCustomObject]@{
    Color   = @('Magenta', 'Green', 'Cyan', 'Red', 'Yellow')[0]
    Length  = 3
    CurrentLength = 0   # Compared to Length to determine if a tail segment 
                        # should be removed. A hopeful performance consideration.
    Direction       = 'Right'
    Segments        = @{}
    LastNewSegment  = $null
    TailTipKey      = $null
    SegmentKeys     = [System.Collections.ArrayList]$segments = @()
    # SegmentKeys is required to keep track of the last key in order to 
    # be able to remove it. Unless I come up with an alternative. Which I hope I do. 
    # I could add a Direction to each segment and infer from that what the next 
    # tail segment is. Shit, I'm trying that! :TODO:
    TailTipIndex    = 0
}

function Move-CursorPosition {
    Param(
        [Parameter(Mandatory=$false)][Int]$X = 0,
        [Parameter(Mandatory=$false)][Int]$Y = 0
    )
    $pos = $host.UI.RawUI.CursorPosition
    $pos.X += $X
    $pos.Y += $Y
    Set-CursorPosition -X $pos.X -Y $pos.Y
}

function Set-CursorPosition {
    Param(
        [Parameter(Mandatory=$false)]$X,
        [Parameter(Mandatory=$false)]$Y
    )
    $pos = $host.UI.RawUI.CursorPosition
    if ($X) {
        $pos.X = $X
        if ($pos.X -ge $Host.UI.RawUI.BufferSize.Width) {
            $pos.X = $Host.UI.RawUI.BufferSize.Width - 1
        }
        if ($pos.X -lt 0) {
            $pos.X = 0
        }
    }
    # :TODO: 'If ($X)' thinks 0 is $null, so the line below. There must be a better way.
    if ($X -eq 0) { $pos.X = 0 }
    if ($Y) {
        $pos.Y = $Y
        if ($pos.Y -ge $Host.UI.RawUI.BufferSize.Height) {
            $pos.Y = $Host.UI.RawUI.BufferSize.Height - 1
        }
        if ($pos.Y -lt 0) {
            $pos.Y = 0
        }
    }
    # :TODO: 'If ($Y)' thinks 0 is $null, so the line below. There must be a better way.
    if ($Y -eq 0) { $pos.Y = 0 }
    $host.UI.RawUI.CursorPosition = $pos
}

function Write-Score {
    $pos = $host.UI.RawUI.CursorPosition
    Set-CursorPosition -X 0 -Y 0
    Write-Host $Script:Score -ForegroundColor Black -BackgroundColor Green -NoNewline
    Set-CursorPosition -X $pos.X -Y $pos.Y
}

function Write-Character {
    Param(
        [Parameter(Mandatory=$true)][Char]$Character,
        [Parameter(Mandatory=$false)][String]$ForegroundColor = (Get-Host).ui.rawui.ForegroundColor,
        [Parameter(Mandatory=$false)][String]$BackgroundColor = (Get-Host).ui.rawui.BackgroundColor,
        [Parameter(Mandatory=$false)][Int]$X = 0,
        [Parameter(Mandatory=$false)][Int]$Y = 0
    )
    $pos = $host.UI.RawUI.CursorPosition
    if ((-not $X) -and (-not $Y)) { # :TODO: 0 0 here will equal to $false, fix
        # Place the character where the cursor is currently located
        Write-Host $Character -NoNewline -ForegroundColor $ForegroundColor -BackgroundColor `
            $BackgroundColor
    } else {
        Set-CursorPosition -X $X -Y $Y
        Write-Host $Character -NoNewline -ForegroundColor $ForegroundColor -BackgroundColor `
            $BackgroundColor
    }
    Set-CursorPosition -X $pos.X -Y $pos.Y
}

function Convert-ToWorm {
    # :TODO: Change to Get-WormDestinationPositionBuffer, return $destinationPos.
    # Perhaps even create Get-PositionBuffer and just feed coordinates from 
    # this to that.

    # Capture the content of the destination position, 
    # if it's not just whitespace, eat it and grow!

    $pos = $host.UI.RawUI.CursorPosition

    # :TODO: Shit, the worm now gets a point from the fence

    #New-Object System.Management.Automation.Host.Rectangle LEFT, BOTTOM, RIGHT, TOP
    switch ($worm.Direction) {
        Up      {
            $left   = $pos.X
            $bottom = ($pos.Y - 1)
            $right  = ($pos.X + 1)
            $top    = ($pos.Y - 1)
        }
        Right   {
            $left   = ($pos.X + 2)
            $bottom = $pos.Y
            $right  = ($pos.X + 3)
            $top    = $pos.Y
        }
        Down    {
            $left   = $pos.X
            $bottom = ($pos.Y + 1)
            $right  = ($pos.X + 1)
            $top    = ($pos.Y + 1)
        }
        Left    {
            $left   = ($pos.X - 2)
            $bottom = $pos.Y
            $right  = ($pos.X - 1)
            $top    = $pos.Y
        }
    }
    $rec = New-Object System.Management.Automation.Host.Rectangle $left, $bottom, $right, $top
    
    $destinationPos = $Host.UI.RawUI.GetBufferContents($rec)
    if (($destinationPos[0,0].Character -ne ' ') -or ($destinationPos[0,1].Character -ne ' ')) {
        $worm.Length += 1
        $Script:Score += 1
    }
}
function Add-WormSegment {

    Convert-ToWorm

    switch ($worm.Direction) {
        Up      {
            $wormEyeChar1 = "'"
            $wormEyeChar2 = "'"
            $wormBodyChar = '-'
        }
        Right   {
            $wormEyeChar1 = ' '
            $wormEyeChar2 = ':'
            $wormBodyChar = '|'
        }
        Down    {
            $wormEyeChar1 = '.'
            $wormEyeChar2 = '.'
            $wormBodyChar = '-'
        }
        Left    {
            $wormEyeChar1 = ':'
            $wormEyeChar2 = ' '
            $wormBodyChar = '|'
        }
    }

    $pos = $host.UI.RawUI.CursorPosition

    # Place left half of the segment
    Write-Character -Character $wormEyeChar1 -ForegroundColor White -BackgroundColor $worm.Color

    # Move cursor one position to the right and place the right half of the segment
    Move-CursorPosition -X 1
    Write-Character -Character $wormEyeChar2 -ForegroundColor White -BackgroundColor $worm.Color

    # Replace the previous head characters with body characters
    if ($worm.Segments.Count -gt 1) {
        Write-Character -Character $wormBodyChar -X $worm.LastNewSegment.X -Y $worm.LastNewSegment.Y `
            -BackgroundColor $worm.Color -ForegroundColor Black
        Write-Character -Character $wormBodyChar -X ($worm.LastNewSegment.X + 1) -Y $worm.LastNewSegment.Y `
            -BackgroundColor $worm.Color -ForegroundColor Black
    }
    
    # Add segment to the worm object
    $X1 = $pos.X
    $X2 = $X1 + 1
     $Y = $pos.Y
    $worm.LastNewSegment = @{X = $X1; Y = $Y; Direction = $worm.Direction}
    $segmentKey = "X1$($X1)X2$($X2)Y$($Y)"
    $worm.Segments.$segmentKey = $worm.LastNewSegment
    $worm.SegmentKeys.Add($segmentKey) | Out-Null
    $worm.CurrentLength += 1
}

function Remove-WormSegment {
    #$tailKey = $($worm.SegmentKeys[$worm.TailTipIndex])
    #$tailSegment = $worm.Segments.$tailKey
    $tailTipSegment = $worm.Segment.($worm.TailTipKey)
    Write-Character -Character ' ' -X $tailTipSegment.X -Y $tailTipSegment.Y
    Write-Character -Character ' ' -X ($tailTipSegment.X + 1) -Y $tailTipSegment.Y

    switch ($tailTipSegment.Direction) {
        Up      {
            $X1 = $tailTipSegment.X
            $X2 = $X1 + 1
             $Y = $tailTipSegment.Y - 1
        }
        Right   {
            $X1 = $tailTipSegment.X + 1
            $X2 = $X1 + 1
             $Y = $tailTipSegment.Y - 1
        }
        Down    {
            $X1 = $tailTipSegment.X
            $X2 = $X1 + 1
             $Y = $tailTipSegment.Y + 1
        }
        Left    {
            $X1 = $tailTipSegment.X - 2
            $X2 = $X1 + 1
             $Y = $tailTipSegment.Y
        }
    }
    $worm.Segments.Remove($worm.TailTipKey)
    $worm.TailTipKey = "X1$($X1)X2$($X2)Y$($Y)"

    $worm.CurrentLength -= 1
    $worm.TailTipIndex += 1
    
}

Function Get-CursorWithinPlayArea {
    if ($Host.UI.RawUI.CursorPosition.X -lt $playArea.UpperLeft.X) {
        # The cursor has exited the play area on the left side
        return $false
    } elseif ($Host.UI.RawUI.CursorPosition.Y -gt $playArea.BottomLeft.Y) {
        # The cursor has exited the play area at the bottom
        return $false        
    } elseif ($Host.UI.RawUI.CursorPosition.X -gt $playArea.BottomRight.X) {
        # The cursor has exited the play area at the right side
        return $false        
    } elseif ($Host.UI.RawUI.CursorPosition.Y -lt $playArea.UpperRight.Y) {
        # The cursors has exited the play area at the top
        return $false        
    }
    return $true
}

function Get-CursorIsOnWormSegment {
    $pos = $host.UI.RawUI.CursorPosition
    # Check if the player is running into himself
    $X1 = $pos.X
    $X2 = $X1 + 1
     $Y = $pos.Y
    if ($worm.Segments."X1$($X1)X2$($X2)Y$($Y)") {
        return $true
    }
    return $false
}

function Stop-Game {
    Param(
        [Parameter(Mandatory=$true)]$Message
    )
    $Script:Exit = $true
    # Erase the worm!
    1..($worm.CurrentLength) | ForEach-Object {
        Start-Sleep -Milliseconds 10
        Remove-WormSegment
    }
    Set-CursorPosition -X ($Host.UI.RawUI.BufferSize.Width / 2 - ($Message.Length / 2)) `
        -Y ($Host.UI.RawUI.BufferSize.Height / 2)
    Write-Host $Message -ForegroundColor Black -BackgroundColor DarkRed -NoNewline
}

function Move-Worm {
    switch ($worm.Direction) {
        Up      {
            Move-CursorPosition -Y -1 -X -1
        }
        Right   {
            Move-CursorPosition -X 1
        }
        Down    {
            Move-CursorPosition -Y 1 -X -1
        }
        Left    {
            Move-CursorPosition -X -3
        }
    }
    
    if ((-not (Get-CursorWithinPlayArea)) -or (Get-CursorIsOnWormSegment)) {
        Stop-Game -Message " BAM! You're DEAD! Score : $Script:Score "
    } else {
        Add-WormSegment
        if ($worm.CurrentLength -gt $worm.Length) {
            Remove-WormSegment
        }
    }
}

Function Read-Key {
    $hideKeysStrokes = $true
    if ([console]::KeyAvailable) {
        $key = [Console]::ReadKey($hideKeysStrokes)
        switch ($key.key) {
            RightArrow  {
                switch ($worm.Direction) {
                    Right   { $worm.Direction = 'Down' }
                    Down    { $worm.Direction = 'Left' }
                    Left    { $worm.Direction = 'Up' }
                    Up      { $worm.Direction = 'Right' }
                }
            }
            LeftArrow   {
                switch ($worm.Direction) {
                    Right   { $worm.Direction = 'Up' }
                    Up      { $worm.Direction = 'Left' }
                    Left    { $worm.Direction = 'Down' }
                    Down    { $worm.Direction = 'Right' }
                }
            }
            Escape {
                Stop-Game -Message " Goodbye! Score : $Script:Score "
            }
        }
    }
}

function Write-Fence {
    $pos = $Host.UI.RawUI.CursorPosition
    $pos.X = $playArea.UpperLeft.X - 1
    $pos.Y = $playArea.UpperLeft.Y - 1
    $Host.UI.RawUI.CursorPosition = $pos
    do {
        Write-Host '#' -NoNewline -ForegroundColor $fenceColor
        $pos.Y += 1
        $Host.UI.RawUI.CursorPosition = $pos
    } until ($pos.Y -eq ($playArea.BottomRight.Y + 1))
    do {
        Write-Host '#' -NoNewline -ForegroundColor $fenceColor
        $pos.X += 1
        $Host.UI.RawUI.CursorPosition = $pos
    } until ($pos.X -eq ($playArea.BottomRight.X + 1))
    do {
        Write-Host '#' -NoNewline -ForegroundColor $fenceColor
        $pos.Y -= 1
        $Host.UI.RawUI.CursorPosition = $pos
    } until ($pos.Y -eq ($playArea.UpperRight.Y - 1))
    do {
        Write-Host '#' -NoNewline -ForegroundColor $fenceColor
        $pos.X -= 1
        $Host.UI.RawUI.CursorPosition = $pos
    } until ($pos.X -eq ($playArea.UpperLeft.X - 1))
}

Write-Fence

# Set starting position to the middle of the buffer by moving the cursor there
Set-CursorPosition -X ($Host.UI.RawUI.BufferSize.Width / 2) -Y ($Host.UI.RawUI.BufferSize.Height / 2)

# Set random starting direction
switch (Get-Random -Minimum 0 -Maximum 4) {
    0 {
        $worm.Direction = 'Up'
    }
    1 {
        $worm.Direction = 'Right'
    }
    2 {
        $worm.Direction = 'Down'
    }
    3 {
        $worm.Direction = 'Left'
    }
}

# Set the coordinates of the first worm segment determined by the starting direction
$X1 = $Host.UI.RawUI.CursorPosition.X
$X2 = $X1 + 1
$Y  = $Host.UI.RawUI.CursorPosition.Y
$worm.LastNewSegment = @{'X' = $X1;'Y' = $Y; Direction = $worm.Direction}
$segmentKey = "X1$($X1)X2$($X2)Y$($Y)"
$worm.TailTipKey = $segmentKey
$worm.Segments.$segmentKey = $worm.LastNewSegment
$worm.SegmentKeys.Add($segmentKey) | Out-Null
$worm.CurrentLength += 1

# :TODO: Add all of the beginning segments here and set the correct .TailTipKey ($worm.Length segment)
# 1..$worm.Length

Move-CursorPosition -X 1 # Unless the cursor is repositioned here, the worm 
                         # immediately eats itself if the starting direction is Right

while ($Script:Exit -eq $false) {
    Write-Score
    Read-Key
    Move-Worm
    Start-Sleep -Milliseconds 40
}

#Start-Sleep 10
Set-CursorPosition -X 0 -Y $Host.UI.RawUI.BufferSize.Height
Write-Host "#" # Moves prompt below the bottom fence
$Host.UI.RawUI.BufferSize = $originalBufferSize
[console]::CursorVisible=$true
