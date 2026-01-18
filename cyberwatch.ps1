# ==========================================================
# CYBERWATCH EDR: STARTUP NOTIFICATION SYSTEM (BSSID FIX)
# ==========================================================

# Configuration
$botToken = "Telegram_bot_token"
$chatID   = "telegram_channel_id"

function Get-CyberwatchStatus {
    # Battery Information
    $bat = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
    $lvl = if($bat){$bat.EstimatedChargeRemaining}else{"N/A"}
    $status = if($bat.BatteryStatus -eq 2){"Charging"}else{"Discharging"}

    # Robust Internal IP Detection
    $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
        $_.InterfaceAlias -notlike "*Loopback*" -and 
        $_.InterfaceAlias -notlike "*vEthernet*" -and 
        $_.InterfaceAlias -notlike "*Virtual*" -and 
        $_.PrefixOrigin -eq "Dhcp" # Adətən real qoşulmalar DHCP vasitəsilə olur
    } | Select-Object -ExpandProperty IPAddress -First 1)

    # Əgər hələ də tapılmasa, ən sadə aktiv IP-ni götür
    if (!$ip) {
        $ip = (Get-NetIPInterface -AddressFamily IPv4 | Where-Object {$_.ConnectionState -eq 'Connected'} | Get-NetIPAddress | Select-Object -ExpandProperty IPAddress -First 1)
    }

    if (!$ip) { $ip = "N/A" }

    # Extracting Wi-Fi Router's MAC Address (BSSID)
    $wlanInfo = netsh wlan show interfaces
    $bssid = "Not Connected"
    $macMatch = $wlanInfo | Select-String "BSSID"
    if ($macMatch) {
        $bssid = $macMatch.ToString().Split(":")[1..6] -join ":"
        $bssid = $bssid.Trim()
    }

    # Network SSID (Wi-Fi Name)
    $ssid = "Unknown"
    $ssidMatch = $wlanInfo | Select-String "^\s+SSID"
    if ($ssidMatch) {
        $ssid = $ssidMatch.ToString().Split(":")[1].Trim()
    }

    # Current Timestamp
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Report Construction (Bold + Italic Header)
    $Report = "___CYBERWATCH EDR - SYSTEM ALERT___`n" +
              "User: $env:USERNAME`n" +
              "Hostname: $env:COMPUTERNAME`n" +
              "Battery: $lvl% ($status)`n" +
              "Internal IP: $ip`n" +
              "Router MAC: $bssid`n" +
              "Wi-Fi Name: $ssid`n" +
              "Timestamp: $time"
    return $Report
}

function Send-CyberwatchAlert {
    param([string]$message)
    $url = "https://api.telegram.org/bot$botToken/sendMessage"
    $payload = @{
        chat_id    = $chatID
        text       = $message
        parse_mode = "Markdown"
    }
    
    try {
        Invoke-RestMethod -Uri $url -Method Post -Body $payload
    } catch { }
}

# Execute Report
$statusReport = Get-CyberwatchStatus
Send-CyberwatchAlert -message $statusReport