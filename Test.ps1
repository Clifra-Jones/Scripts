# Demo script for Show-ProgressBar with various color options
# Make sure Write-ConsoleOnly and Show-ProgressBar functions are defined first

# Source the necessary functions - adjust paths as needed
# . .\Write-ConsoleOnly.ps1
# . .\Show-ProgressBar.ps1

# For the demo, let's include the functions directly

function Write-ConsoleOnly {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true)]
        [string]$Message='',
        
        [Parameter()]
        [ConsoleColor]$ForegroundColor = [Console]::ForegroundColor,
        
        [Parameter()]
        [ConsoleColor]$BackgroundColor = [Console]::BackgroundColor,
        
        [Parameter()]
        [switch]$NoNewline
    )
    
    # Save original colors
    $originalForeground = [Console]::ForegroundColor
    $originalBackground = [Console]::BackgroundColor
    
    # Set new colors
    [Console]::ForegroundColor = $ForegroundColor
    [Console]::BackgroundColor = $BackgroundColor
    
    # Write to console only
    if ($NoNewline) {
        [Console]::Write($Message)
    } else {
        [Console]::WriteLine($Message)
    }
    
    # Restore original colors
    [Console]::ForegroundColor = $originalForeground
    [Console]::BackgroundColor = $originalBackground
}

function Show-ProgressBar {
    param (
        [Parameter(Mandatory = $false)]
        [int]$PercentComplete = 100,
        
        [Parameter(Mandatory = $false)]
        [int]$BarLength = 60,
        
        [Parameter(Mandatory = $false)]
        [char]$BarChar = '=',
        
        [Parameter(Mandatory = $false)]
        [string]$Activity = "Processing",
        
        [Parameter(Mandatory = $false)]
        [string]$Status = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$Completed,
        
        [Parameter(Mandatory = $false)]
        [switch]$Spinner,
        
        [Parameter(Mandatory = $false)]
        [System.ConsoleColor]$ForegroundColor = [Console]::ForegroundColor,
        
        [Parameter(Mandatory = $false)]
        [System.ConsoleColor]$BarForegroundColor,
        
        [Parameter(Mandatory = $false)]
        [System.ConsoleColor]$BarBackgroundColor
    )

    # We are performing some parameter checking here
    # we are doing this here because Parameter sets are two confusing and don't give meaningful error messages.
    if ($PercentComplete -lt 0 -or $PercentComplete -gt 100) {
        Write-Host "PercentComplete must be between 0 and 100." -ForegroundColor Red
        return
    }

    if ($BarLength -lt 1) {
        Write-Host "BarLength must be at least 1." -ForegroundColor Red
        return
    }

    if ($BarChar -and $Spinner) {
        Write-Host "BarChar and Spinner cannot be used together." -ForegroundColor Red
        return
    }

    if ($BarForegroundColor -and $BarBackgroundColor -and $BarForegroundColor -eq $BarBackgroundColor) {
        Write-Host "BarForegroundColor and BarBackgroundColor cannot be the same." -ForegroundColor Red
        return
    }
    
    # Static variable to keep track of spinner state
    if (-not [bool]::TryParse($script:spinnerInitialized, [ref]$null)) {
        $script:spinnerInitialized = $true
        $script:spinnerIndex = 0
    }
    
    # Spinner characters in correct rotation order
    $spinnerChars = @('-', '\', '|', '/', '-', '\', '|', '/')
    
    # Check if only the -Completed switch was provided (with default values for other parameters)
    $onlyCompletedProvided = $Completed -and 
                             $PSBoundParameters.Count -eq 1 -and
                             $PercentComplete -eq 100 -and
                             $BarLength -eq 60 -and
                             $BarChar -eq '=' -and
                             $Activity -eq "Processing" -and
                             $Status -eq "" -and
                             (-not $Spinner)
    
    # If only -Completed is specified, clear the progress bar line
    if ($onlyCompletedProvided) {
        # Create a blank line that overwrites the existing progress bar
        $clearLine = "`r" + " " * 200 + "`r"  # 200 spaces should be enough to clear most lines
        Write-ConsoleOnly $clearLine -NoNewline
        return
    }
    
    # Build the display string
    if ($Spinner) {
        if ($Completed) {
            # For completed spinners, we want to clear the line first to avoid residual characters
            $clearLine = "`r" + " " * 200 + "`r"  # 200 spaces should be enough to clear most lines
            Write-ConsoleOnly $clearLine -NoNewline
            
            # Then display the final state
            $finalChar = $spinnerChars[0]  # Use the first spinner character for completion
            
            # Record the previous status length to ensure we clear it properly
            $maxStatusLength = 0
            foreach ($char in $spinnerChars) {
                $tempStatus = "$Activity [$char]"
                if (-not [string]::IsNullOrWhiteSpace($Status)) {
                    $tempStatus += " - $Status"
                }
                $maxStatusLength = [Math]::Max($maxStatusLength, $tempStatus.Length)
            }
            
            # Add padding to ensure we clear the longest possible status message
            $padding = [string]::new(' ', $maxStatusLength + 20) # Extra padding to be safe
            Write-ConsoleOnly "`r$padding`r" -NoNewline
            
            if ($PSBoundParameters.ContainsKey('BarForegroundColor') -or $PSBoundParameters.ContainsKey('BarBackgroundColor')) {
                # Final state with custom colors
                $spinnerFg = if ($PSBoundParameters.ContainsKey('BarForegroundColor')) { $BarForegroundColor } else { $ForegroundColor }
                $spinnerBg = if ($PSBoundParameters.ContainsKey('BarBackgroundColor')) { $BarBackgroundColor } else { [Console]::BackgroundColor }
                
                # Display the prefix with main foreground color
                Write-ConsoleOnly "$Activity [" -ForegroundColor $ForegroundColor -NoNewline
                
                # Display the spinner character with its specific colors
                Write-ConsoleOnly "$finalChar" -ForegroundColor $spinnerFg -BackgroundColor $spinnerBg -NoNewline
                
                # Display the suffix with main foreground color
                Write-ConsoleOnly "]" -ForegroundColor $ForegroundColor -NoNewline
                
                # Add status if provided
                if (-not [string]::IsNullOrWhiteSpace($Status)) {
                    Write-ConsoleOnly " - $Status" -ForegroundColor $ForegroundColor
                } else {
                    Write-ConsoleOnly "" -ForegroundColor $ForegroundColor
                }
            }
            else {
                # Final state with default colors
                $finalDisplay = "$Activity [$finalChar]"
                if (-not [string]::IsNullOrWhiteSpace($Status)) {
                    $finalDisplay += " - $Status"
                }
                Write-ConsoleOnly $finalDisplay -ForegroundColor $ForegroundColor
            }
            
            return
        }
        
        # Get the current spinner character for animated spinner
        $currentSpinnerChar = $spinnerChars[$script:spinnerIndex]
        
        # Update spinner index for next call
        $script:spinnerIndex = ($script:spinnerIndex + 1) % $spinnerChars.Length
        
        # Create spinner display
        $displayStringPrefix = "$Activity ["
        $displayStringSuffix = "]"
        
        # Handle the spinner character separately to apply specific colors
        if ($PSBoundParameters.ContainsKey('BarForegroundColor') -or $PSBoundParameters.ContainsKey('BarBackgroundColor')) {
            # Prepare spinner character with specific colors
            $spinnerFg = if ($PSBoundParameters.ContainsKey('BarForegroundColor')) { $BarForegroundColor } else { $ForegroundColor }
            $spinnerBg = if ($PSBoundParameters.ContainsKey('BarBackgroundColor')) { $BarBackgroundColor } else { [Console]::BackgroundColor }
            
            # Display the prefix with main foreground color
            Write-ConsoleOnly "`r$displayStringPrefix" -ForegroundColor $ForegroundColor -NoNewline
            
            # Display the spinner character with its specific colors
            Write-ConsoleOnly "$currentSpinnerChar" -ForegroundColor $spinnerFg -BackgroundColor $spinnerBg -NoNewline
            
            # Display the suffix with main foreground color
            Write-ConsoleOnly "$displayStringSuffix" -ForegroundColor $ForegroundColor -NoNewline
            
            # Add status if provided
            if (-not [string]::IsNullOrWhiteSpace($Status)) {
                Write-ConsoleOnly " - $Status" -ForegroundColor $ForegroundColor -NoNewline
            }
        }
        else {
            # Use the default/specified foreground color for everything
            Write-ConsoleOnly "`r$Activity [$currentSpinnerChar]" -ForegroundColor $ForegroundColor -NoNewline
            
            # Add status if provided
            if (-not [string]::IsNullOrWhiteSpace($Status)) {
                Write-ConsoleOnly " - $Status" -ForegroundColor $ForegroundColor -NoNewline
            }
        }
        
        # If -Completed is specified with -Spinner, add a newline to finalize and show completion
        # This block was moved to the beginning of the Spinner section
    }
    else {
        # Regular progress bar
        # Ensure percent is within valid range
        $PercentComplete = [Math]::Max(0, [Math]::Min(100, $PercentComplete))
        
        # Calculate how many bar characters to display
        $completedChars = [Math]::Floor(($BarLength * $PercentComplete) / 100)
        
        # Check if we need to apply special colors to the bar
        $useSpecialBarColors = $PSBoundParameters.ContainsKey('BarForegroundColor') -or $PSBoundParameters.ContainsKey('BarBackgroundColor')
        
        if ($useSpecialBarColors) {
            # Write the first part of the string with main foreground color
            Write-ConsoleOnly "`r$Activity [" -ForegroundColor $ForegroundColor -NoNewline
            
            # Progress bar with special colors
            $barFg = if ($PSBoundParameters.ContainsKey('BarForegroundColor')) { $BarForegroundColor } else { $ForegroundColor }
            $barBg = if ($PSBoundParameters.ContainsKey('BarBackgroundColor')) { $BarBackgroundColor } else { [Console]::BackgroundColor }
            
            # Write the completed part of the bar with special colors
            if ($completedChars -gt 0) {
                $progressBar = [string]::new($BarChar, $completedChars)
                Write-ConsoleOnly $progressBar -ForegroundColor $barFg -BackgroundColor $barBg -NoNewline
            }
            
            # Write the remaining part of the bar with main foreground color and default background
            $remainingLength = $BarLength - $completedChars
            if ($remainingLength -gt 0) {
                $remainingBar = [string]::new(' ', $remainingLength)
                # Always use default background for the remaining part
                Write-ConsoleOnly $remainingBar -ForegroundColor $ForegroundColor -NoNewline
            }
            
            # Write the rest of the string with main foreground color
            $statusText = "] $PercentComplete%"
            if (-not [string]::IsNullOrWhiteSpace($Status)) {
                $statusText += " - $Status"
            }
            Write-ConsoleOnly $statusText -ForegroundColor $ForegroundColor -NoNewline
        }
        else {
            # Build the progress bar (standard version with no special colors)
            $progressBar = [string]::new($BarChar, $completedChars)
            $remainingBar = [string]::new(' ', $BarLength - $completedChars)
            
            # Build the display string for progress bar
            $displayString = "`r$Activity [$progressBar$remainingBar] $PercentComplete%"
            
            # Add status if provided
            if (-not [string]::IsNullOrWhiteSpace($Status)) {
                $displayString += " - $Status"
            }
            
            # Display the progress indicator with the specified foreground color
            Write-ConsoleOnly $displayString -ForegroundColor $ForegroundColor -NoNewline
        }
        
        # If -Completed is specified with custom parameters, add a newline to finalize and keep it visible
        if ($Completed) {
            Write-ConsoleOnly "" -ForegroundColor $ForegroundColor
        }
    }
}

# Demo 1: Basic progress bar with no color customization
Write-Host "`nDemo 1: Basic progress bar"
for ($i = 0; $i -le 100; $i += 10) {
    Show-ProgressBar -PercentComplete $i -Activity "Basic Demo" -Status "Processing $i%"
    Start-Sleep -Milliseconds 300
}
Show-ProgressBar -Completed
Start-Sleep -Seconds 1

# Demo 2: Progress bar with custom foreground color
Write-Host "`nDemo 2: Progress bar with custom foreground color (Green)"
for ($i = 0; $i -le 100; $i += 10) {
    Show-ProgressBar -PercentComplete $i -Activity "Green Demo" -Status "Processing $i%" -ForegroundColor Green
    Start-Sleep -Milliseconds 300
}
Show-ProgressBar -Completed
Start-Sleep -Seconds 1

# Demo 3: Progress bar with custom bar character and bar foreground color
Write-Host "`nDemo 3: Progress bar with custom bar character (#) and bar color (Red)"
for ($i = 0; $i -le 100; $i += 10) {
    Show-ProgressBar -PercentComplete $i -Activity "Custom Bar" -Status "Processing $i%" -BarChar "#" -BarForegroundColor Red
    Start-Sleep -Milliseconds 300
}
Show-ProgressBar -Completed
Start-Sleep -Seconds 1

# Demo 4: Progress bar with bar foreground and background colors
Write-Host "`nDemo 4: Progress bar with bar foreground (Yellow) and background (DarkBlue) colors"
for ($i = 0; $i -le 100; $i += 10) {
    Show-ProgressBar -PercentComplete $i -Activity "Colorful Bar" -Status "Processing $i%" -BarForegroundColor Yellow -BarBackgroundColor DarkBlue
    Start-Sleep -Milliseconds 300
}
Show-ProgressBar -Completed
Start-Sleep -Seconds 1

# Demo 5: Progress bar with all custom colors
Write-Host "`nDemo 5: Progress bar with all custom colors (Cyan text, Red bar with White background)"
for ($i = 0; $i -le 100; $i += 10) {
    Show-ProgressBar -PercentComplete $i -Activity "All Colors" -Status "Processing $i%" -ForegroundColor Cyan -BarForegroundColor Red -BarBackgroundColor White
    Start-Sleep -Milliseconds 300
}
Show-ProgressBar -Completed -ForegroundColor Cyan
Start-Sleep -Seconds 1

# Demo 6: Custom length progress bar
Write-Host "`nDemo 6: Custom length progress bar (30 characters)"
for ($i = 0; $i -le 100; $i += 10) {
    Show-ProgressBar -PercentComplete $i -Activity "Short Bar" -Status "Processing $i%" -BarLength 30 -BarForegroundColor Green
    Start-Sleep -Milliseconds 300
}
Show-ProgressBar -Completed
Start-Sleep -Seconds 1

# Demo 7: Basic spinner
Write-Host "`nDemo 7: Basic spinner"
for ($i = 0; $i -lt 20; $i++) {
    Show-ProgressBar -Spinner -Activity "Loading" -Status "Please wait..."
    Start-Sleep -Milliseconds 150
}
# Complete with just -Completed to clear the spinner
Show-ProgressBar -Completed
Start-Sleep -Seconds 1

# Demo 8: Colored spinner
Write-Host "`nDemo 8: Colored spinner (Magenta)"
for ($i = 0; $i -lt 20; $i++) {
    Show-ProgressBar -Spinner -Activity "Colored Spinner" -Status "Processing item $i" -ForegroundColor Magenta
    Start-Sleep -Milliseconds 150
}
# Complete with final message
Show-ProgressBar -Spinner -Completed -Activity "Colored Spinner" -Status "Process complete!" -ForegroundColor Magenta
Start-Sleep -Seconds 1

# Demo 9: Spinner with custom colors
Write-Host "`nDemo 9: Spinner with Yellow symbol on Blue background"
for ($i = 0; $i -lt 20; $i++) {
    Show-ProgressBar -Spinner -Activity "Fancy Spinner" -Status "Working..." -BarForegroundColor Yellow -BarBackgroundColor Blue
    Start-Sleep -Milliseconds 150
}
Show-ProgressBar -Spinner -Completed -Activity "Fancy Spinner" -Status "Work complete!" -BarForegroundColor Yellow -BarBackgroundColor Blue
Start-Sleep -Seconds 1

# Demo 10: All custom colors for spinner
Write-Host "`nDemo 10: All custom colors for spinner (Green text, Red spinner on Yellow background)"
for ($i = 0; $i -lt 20; $i++) {
    Show-ProgressBar -Spinner -Activity "Ultimate Spinner" -Status "Almost done ($i/20)" -ForegroundColor Green -BarForegroundColor Red -BarBackgroundColor Yellow
    Start-Sleep -Milliseconds 150
}
Show-ProgressBar -Spinner -Completed -Activity "Ultimate Spinner" -Status "Completed!" -ForegroundColor Green -BarForegroundColor Red -BarBackgroundColor Yellow
#Show-ProgressBar -Spinner -Completed -ForegroundColor Green

# Final message
Write-Host "`nAll demos completed!" -ForegroundColor Cyan