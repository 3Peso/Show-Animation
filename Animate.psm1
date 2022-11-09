# Author: DreiPeso, 2017

#### Script Variables ####

$script:done = $false
$script:animationForegroundColor = 'Yellow'
$script:animationBackgroundColor = 'DarkGreen'
$script:walkingManAnimation = @(
@(' ',' ','O'),
@(' ','/','L'),
@(' ','>','\'),
@(' ',' ','O'),
@(' ','|','\'),
@(' ','/','>')
)
$script:speed = 200

#### Public Functions  ####

<#
.SYNOPSIS
Shows an animation at the top of the host window.

.DESCRIPTION
Shows an animation at the top of the host window which will move from left to right and then disappears.
After one pass the animation will stop.

.EXAMPLE
Show-Animation

.NOTES

.LINK

#>
function Show-Animation {
    param(
        [Parameter(Mandatory=$false)][Array]$animationTemplate
    )
    try {
        Clear-Host

        if($animationTemplate -ne $null) {
            $animation = New-AnimationSeries -animationCharacters $animationTemplate
        } else {
            $animation = New-AnimationSeries  
        }
        $left = 0
        while (-not $script:done) {
            Set-AnimationArea -top 0 -left 0 -height 3
            Set-AnimationFrame -top 0 -left $left -frame $animation[$left%$animation.Count]

            if($left -lt (Get-HostWindowSize).Width-1) {
                $left++
            } else {
                $script:done = $true
            }

            Start-Sleep -Milliseconds $script:speed     
        }
    } finally {
        $script:done = $false
        Clear-Host
    }
}

<#
.SYNOPSIS
Returns the walking man animation template.

.DESCRIPTION
Returns the walking man animation template which is defined inside the module. This is meant to be a
wrapper around a script variable to prevent the need for a global variable.

.EXAMPLE
Get-WalkingManAnimation
#>
function Get-WalkingManAnimation {
    return $script:walkingManAnimation
}

#### Private Functions ####

function Set-AnimationArea {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param(
        [Parameter(Mandatory=$true)][UInt32]$top,
        [Parameter(Mandatory=$true)][UInt32]$left,
        [Parameter(Mandatory=$true)][UInt32]$height
    )

    $size = Get-HostWindowSize
    $cell = New-BufferCell -character ' ' -ForeGroundColor $script:animationForegroundColor `
        -BackGroundColor $script:animationBackgroundColor
    Write-Debug $cell
    $rect = New-Rectangle -top $top -left $left -bottom ($top+$height-1) -right ($left+$size.Width)
    Write-Debug $rect
    
    Set-HostRectContent -cell $cell -rectangle $rect
}

function Set-AnimationFrame {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param(
        [Parameter(Mandatory=$true)][UInt32]$top,
        [Parameter(Mandatory=$true)][UInt32]$left,
        [Parameter(Mandatory=$true)][Array]$frame 
    )

    for($i = 0; $i -lt $frame.Count; $i++) {
        Write-Debug "Setting character $($frame[$i].Character) of frame $i."
        Set-AnimationCharacter -top $top -left $left -character $frame[$i]    
    }
}

function Set-AnimationCharacter {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param(
        [Parameter(Mandatory=$true)][UInt32]$top,
        [Parameter(Mandatory=$true)][UInt32]$left,
        [Parameter(Mandatory=$true)][PSObject]$character  
    )

    $cell = New-BufferCell -character ($character.Character) -ForeGroundColor $script:animationForegroundColor `
        -BackGroundColor $script:animationBackgroundColor
    Write-Debug $cell
    $rect = New-Rectangle -top ($top+$character.Coordinates.Y) -left ($left+$character.Coordinates.X) `
        -bottom ($top+$character.Coordinates.Y) -right ($left+$character.Coordinates.X)
    Write-Debug $rect

    Set-HostRectContent -cell $cell -rectangle $rect
}

# Just a wrapper around $host.UI.RawUI.SetBufferContents for mocking purpose
function Set-HostRectContent {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][System.Management.Automation.Host.BufferCell]$cell,
        [Parameter(Mandatory=$true)][System.Management.Automation.Host.Rectangle]$rectangle
    )

    If($PSCmdlet.ShouldProcess("Drawing rectangle")) {
        Write-Debug "Drawing contents..."
        $host.UI.RawUI.SetBufferContents($rectangle, $cell)
    }
}

# Just a wrapper around $host.UI.RawUI.WindowSize for mocking purpose
function Get-HostWindowSize {
    return $host.UI.RawUI.WindowSize
}

function New-AnimationSeries {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param(
        [Parameter(Mandatory=$false)][Array]$animationCharacters = @(
            @("X"," "," "),
            @(" "," "," "),
            @(" "," "," "),
            @("X"," "," "),
            @(" ","O"," "),
            @(" "," "," "),
            @("X"," "," "),
            @(" ","O"," "),
            @(" "," ","X"),
            @("X"," "," "),
            @(" ","O"," "),
            @("O"," ","X"),
            @("X"," ","X"),
            @(" ","O"," "),
            @("O"," ","X"),
            @("X","O","X"),
            @(" ","O"," "),
            @("O"," ","X"),
            @("X","O","X"),
            @(" ","O","X"),
            @("O"," ","X")            
        ),
        [Parameter(Mandatory=$false)][UInt32]$animationFrameLength = 3
    )

    Test-AnimationTemplate -animationCharacters $animationCharacters `
        -animationFrameLength $animationFrameLength | Out-Null

    $animationSeries = [Ordered]@{}
    $blockCount = $animationCharacters.Count / $animationFrameLength
    for([int]$i = 0; $i -lt $blockCount; $i++) {
        $animationSeries.Add($i, (Get-AnimationRectangle -animationCharacters $animationCharacters -animationFrameLength $animationFrameLength `
            -animationBlockNumber $i))
    }
    
    Write-Debug "Animation series of $($animationSeries.Count) single frames created."
    $animationSeries   
}

function Get-AnimationRectangle {
    param(
        [Parameter(Mandatory=$true)][Array]$animationCharacters,
        [Parameter(Mandatory=$true)][UInt32]$animationFrameLength,
        [Parameter(Mandatory=$true)][UInt32]$animationBlockNumber
    )
    
    $rect = @()
    $offset = $animationBlockNumber * $animationFrameLength
    $localY = 0
    for([int]$i = $offset; $i -lt $offset + $animationFrameLength; $i++, $localY++) {

        for([int]$j = 0; $j -lt $animationFrameLength; $j++) {

            $cell = [Ordered]@{
                "Character" = $animationCharacters[$i][$j]
                "Coordinates" = New-Object System.Management.Automation.Host.Coordinates
            }
            $cell.Coordinates.X = $j
            $cell.Coordinates.Y = $localY
            $cell = New-Object -TypeName PSObject -Property $cell

            Write-Debug "New cell. Character: '$($cell.Character)'; localX: '$($cell.Coordinates.X)'; localY: '$($cell.Coordinates.Y)'"
            $rect += $cell
        }
    }
    
    Write-Debug "Rectangle with $($rect.Count) cells created."
    $rect    
}

function Test-AnimationTemplate {
    param(
        [Parameter(Mandatory=$false)][Array]$animationCharacters,
        [Parameter(Mandatory=$false)][UInt32]$animationFrameLength
    )

    $exceptionMessage = "Animation must consist of series of arrays. `
        These arrays must consist of single characters, with each array having the same length."
    $exceptionFrameLenghtMessage = "Animation frame lenght must be the lenght of one scene in the animation. `
        It cannot be as long as all character arrays and the modulo of the character array count and the fame lenght must be 0."
    
    Write-Debug "FrameLenght: $animationFrameLength; Characters Count: $($animationCharacters.Count)"
    if($animationFrameLength -ge $animationCharacters.Count) {
        throw $exceptionFrameLenghtMessage
    }
    Write-Debug "Animation template passed framelength check."

    if(($animationCharacters.Count % $animationFrameLength) -ne 0) {
        throw $exceptionFrameLenghtMessage
    }
    Write-Debug "Animation templated passed check that it is x times the lenght of the framelength."

    $expectedLength = -1
    for([int]$i = 0; $i -lt $animationCharacters.Count; $i++) {
        if($expectedLength -eq -1) {
            $expectedLength = $animationCharacters[$i].Count
            Write-Debug "Expected length of every animation is $expectedLength."
        }
        
        if($animationCharacters[$i] -isnot [Array]) {
            throw $exceptionMessage
        }
        Write-Debug "Animation frame $i passed the test that itself is an array."

        if($animationCharacters[$i].Count -ne $expectedLength) {
            throw $excpetionMessage
        }
        Write-Debug "Animation frame $i passed the test that it has the expected length $expectedLength."

        if($animationCharacters[$i].Count -eq 1) {
            throw $excpetionMessage
        }
        Write-Debug "Animation frame $i passed the test that it is bigger than 1."

        for([int]$j = 0; $j -lt $animationCharacters[$i].Count; $j++) {
            if($animationCharacters[$i][$j].Length -ne 1) {
                throw $exceptionMessage
            }
            Write-Debug "Animation frame cell $i $j passed the test that it has the length 1."                  
        }
    }
}

function New-BufferCell {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param(
        [Parameter(Mandatory=$true)][String]$character,
        [Parameter(Mandatory=$false)][ConsoleColor]$ForeGroundColor = $(Get-Buffercell -x 0 -y 0).ForegroundColor,
        [Parameter(Mandatory=$false)][ConsoleColor]$BackGroundColor = $(Get-Buffercell -x 0 -y 0).BackgroundColor,
        [Parameter(Mandatory=$false)]
            [ValidateSet("Complete","Trailing","Format","Leading")]
            [System.Management.Automation.Host.BufferCellType]$BufferCellType = "Complete"
    )
    
    $cell = New-Object System.Management.Automation.Host.BufferCell
    $cell.Character = $Character
    $cell.ForegroundColor = $foregroundcolor
    $cell.BackgroundColor = $backgroundcolor
    $cell.BufferCellType = $buffercelltype
    
    Write-Debug "New buffer cell created."
    $cell
}

function Get-BufferCell {
    param(
        [Parameter(Mandatory=$false)][UInt32]$x = 0,
        [Parameter(Mandatory=$false)][UInt32]$y = 0
    )

    $rect = New-Rectangle -top 0 -left 0
    [System.Management.Automation.Host.BufferCell[,]]$cells = $host.UI.RawUI.GetBufferContents($rect)

    Write-Debug "Buffer cell from host at position $x $y read."
    $cells[0,0]
}

function New-Rectangle {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param(
        [Parameter(Mandatory=$true)][UInt32]$top,
        [Parameter(Mandatory=$true)][UInt32]$left,
        [Parameter(Mandatory=$false)][UInt32]$bottom = 0,
        [Parameter(Mandatory=$false)][UInt32]$right = 0
    )

    $newRectangle = New-Object System.Management.Automation.Host.Rectangle
    $newRectangle.Bottom = $bottom
    $newRectangle.Right = $right
    $newRectangle.Top = $top
    $newRectangle.Left = $left

    Write-Debug "New rectangle created."
    $newRectangle
}

#### Exports ####

Export-ModuleMember -Function Show-Animation
Export-ModuleMember -Function Get-WalkingManAnimation