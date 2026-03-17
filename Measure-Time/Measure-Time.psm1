function Format-Duration {
  <#
    .SYNOPSIS
      Formats a TimeSpan into a human-readable string.
    .DESCRIPTION
      Formats a TimeSpan into a human-readable string.
    .PARAMETER TimeSpan
      [TimeSpan] The TimeSpan object to format.
    .OUTPUTS
      [string] A human-readable string representing the duration.
    .NOTES
      Returns '000ms' if the duration is zero.
    .EXAMPLE
      Format-Duration -TimeSpan (New-TimeSpan -Seconds 5)
  #>
  param (
    [Parameter(Mandatory)]
    [TimeSpan] $TimeSpan
  )

  $timeSpanStr = @()

  # Define units and their values from the TimeSpan object
  $timeComponents = @(
    @{"unit" = "h"; "value" = $TimeSpan.Hours },
    @{"unit" = "m"; "value" = $TimeSpan.Minutes },
    @{"unit" = "s"; "value" = $TimeSpan.Seconds },
    @{"unit" = "ms"; "value" = $TimeSpan.Milliseconds }
  )

  # Build the string by appending non-zero units
  foreach ($timeComponent in $timeComponents) {
    if ($timeComponent.value -gt 0) {
      $timeSpanStr += "{0:0#}{1}" -f $timeComponent.value, $timeComponent.unit
    }
  }

  if ($timeSpanStr.Count -gt 0) {
    $timeSpanStr -join " "
  }
  else {
    "000ms"
  }
}

function Measure-Time {
  <#
    .SYNOPSIS
      Measure command execution time and cpu usage.
    .DESCRIPTION
      Measure command execution time and cpu usage.
    .PARAMETER Command
      [ScriptBlock] The script block to be measured.
    .OUTPUTS
      [string] A human-readable string containing user time, system time,
               cpu usage, and total wall time.
    .NOTES
      Requires JobApiLib.dll to access Windows Job Objects for resource tracking.
      This should be bundled with the module.
    .EXAMPLE
      Measure-Time -Command { Get-ChildItem -Recurse }
  #>
  param (
    [Parameter(Mandatory)]
    [ScriptBlock] $Command
  )

  # Reference the loaded types from the Nested C# DLL
  $JobApi = [JobApiLib.JobApi]
  $JobResourceUsage = [JobApiLib.JobApi+JobResourceUsage]

  try {
    $commandString = $Command.ToString().Trim()

    # Create a Windows Job Object to track resource usage of child processes
    $jobHandle = $JobApi::CreateJobObject([IntPtr]::Zero, $null)

    # Setup the subprocess to execute the user's command
    $processInfo = [System.Diagnostics.ProcessStartInfo]::new("powershell", "-NoLogo -NoProfile -Command & { $commandString }")
    $processInfo.UseShellExecute = $false
    $processInfo.WorkingDirectory = (Get-Location).Path

    # Start the process and assign it to the Job Object
    $subProcess = [System.Diagnostics.Process]::Start($processInfo)
    [void]$JobApi::AssignProcessToJobObject($jobHandle, $subProcess.Handle)

    # Start wall-clock timer and wait for command completion
    $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $subProcess.WaitForExit()
  }
  finally {
    $stopWatch.Stop()

    # Allocate unmanaged memory to hold the Job Object information struct
    $bufferSize = $JobApi::GetStructSize()
    $bufferPointer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($bufferSize)

    # Query the Job Object for CPU and timing statistics
    if ($jobHandle -ne [IntPtr]::Zero -and $JobApi::QueryInformationJobObject($jobHandle, 1, $bufferPointer, $bufferSize, [ref]0)) {
      $jobUsageData = [System.Runtime.InteropServices.Marshal]::PtrToStructure($bufferPointer, [type]$JobResourceUsage)

      # Convert Ticks to TimeSpan for calculation
      $userTime = [TimeSpan]::FromTicks($jobUsageData.TotalUserTime)
      $kernelTime = [TimeSpan]::FromTicks($jobUsageData.TotalPrivilegedTime)
      $processorTime = $userTime + $kernelTime
      $wallTime = $stopWatch.Elapsed

      # Calculate CPU Load percentage based on total processor time vs wall time
      $cpuLoad = [math]::Round($processorTime.TotalSeconds / $wallTime.TotalSeconds * 100)
      $usage = "$cpuLoad%"

      # Format all times for display
      $userTime = Format-Duration $userTime
      $kernelTime = Format-Duration $kernelTime
      $processorTime = Format-Duration $processorTime
      $wallTime = Format-Duration $wallTime

      # Output results to host
      Write-Host "{ $commandString }  $userTime user $kernelTime system $usage cpu $wallTime total"
    }

    # Clean up unmanaged memory and handles
    if ($bufferPointer -ne [IntPtr]::Zero) { [System.Runtime.InteropServices.Marshal]::FreeHGlobal($bufferPointer) }
    if ($jobHandle -ne [IntPtr]::Zero) { [void]$JobApi::CloseHandle($jobHandle) }
  }
}

# Create a global alias for the command
New-Alias -Name time -Value Measure-Time -Force

# Export both the function and its alias for module users
Export-ModuleMember -Function Measure-Time -Alias time
