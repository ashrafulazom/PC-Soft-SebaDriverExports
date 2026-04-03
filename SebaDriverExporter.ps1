Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Global variables
$global:stopProcess = $false
$global:currentProcess = $null

# Main Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Seba Driver Exporter"
$form.Size = New-Object System.Drawing.Size(800,580)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.BackColor = "#1c1c1c"

# Title Label
$title = New-Object System.Windows.Forms.Label
$title.Text = "Seba Driver Exporter"
$title.ForeColor = "#00ffff"
$title.Font = New-Object System.Drawing.Font("Segoe UI",16,[System.Drawing.FontStyle]::Bold)
$title.Location = "20,10"
$title.AutoSize = $false
$title.Size = New-Object System.Drawing.Size(740,40)

# Path TextBox
$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = "20,60"
$textBox.Size = "520,30"
$textBox.BackColor = "#2a2a2a"
$textBox.ForeColor = "White"
$textBox.Font = New-Object System.Drawing.Font("Segoe UI",10)

# Button Function
function Create-RoundedButton($text,$x,$y,$w,$h,$bg,$fg){
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Location = New-Object System.Drawing.Point($x,$y)
    $btn.Size = New-Object System.Drawing.Size($w,$h)
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 0
    $btn.BackColor = $bg
    $btn.ForeColor = $fg
    $btn.Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
    return $btn
}

$browse = Create-RoundedButton "Browse" 560 60 120 30 "#0078D7" "White"
$export = Create-RoundedButton "Export Drivers" 20 110 150 35 "#28a745" "White"
$restore = Create-RoundedButton "Restore Drivers" 190 110 150 35 "#ffc107" "Black"
$scan = Create-RoundedButton "Scan Drivers" 360 110 150 35 "#17a2b8" "White"
$online = Create-RoundedButton "Find Online" 530 110 150 35 "#6f42c1" "White"
$stop = Create-RoundedButton "Stop Process" 700 110 80 35 "#dc3545" "White"
$about = Create-RoundedButton "About" 700 60 80 35 "#6c757d" "White"

$stop.Enabled = $false

# Progress Bar
$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = "20,160"
$progress.Size = "740,25"

# Log Box
$log = New-Object System.Windows.Forms.TextBox
$log.Location = "20,200"
$log.Size = "740,300"
$log.Multiline = $true
$log.ScrollBars = "Vertical"
$log.BackColor = "#2a2a2a"
$log.ForeColor = "White"

# Status Label
$status = New-Object System.Windows.Forms.Label
$status.Text = "Ready"
$status.ForeColor = "White"
$status.Location = "20,510"

# Browse
$browse.Add_Click({
    $f = New-Object System.Windows.Forms.FolderBrowserDialog
    if($f.ShowDialog() -eq "OK"){ $textBox.Text = $f.SelectedPath }
})

# 🔥 EXPORT (REAL STOP)
$export.Add_Click({
    $path = $textBox.Text.Trim()

    if([string]::IsNullOrWhiteSpace($path)){
        [System.Windows.Forms.MessageBox]::Show("Please select a folder path first","Warning")
        return
    }

    if(!(Test-Path $path)){ New-Item -ItemType Directory -Path $path | Out-Null }

    $status.Text = "Exporting..."
    $progress.Style = 'Marquee'
    $stop.Enabled = $true
    $global:stopProcess = $false

    try {
        $process = Start-Process "cmd.exe" -ArgumentList "/c dism /online /export-driver /destination:`"$path`"" -Verb RunAs -WindowStyle Hidden -PassThru
        $global:currentProcess = $process

        while(!$process.HasExited){
            Start-Sleep -Milliseconds 500
            [System.Windows.Forms.Application]::DoEvents()

            if($global:stopProcess){
                $process.Kill()
                $log.AppendText("Export stopped by user`r`n")
                $status.Text = "Stopped"
                break
            }
        }

        if(!$global:stopProcess){
            $log.AppendText("Drivers exported to: $path`r`n")
            $status.Text = "Export Done"
        }
    }
    catch {
        $log.AppendText("Export failed: $_`r`n")
        $status.Text = "Export Failed"
    }

    $progress.Style = 'Continuous'
    $stop.Enabled = $false
    $global:currentProcess = $null
})

# 🔥 RESTORE (REAL STOP)
$restore.Add_Click({
    $path = $textBox.Text.Trim()

    if([string]::IsNullOrWhiteSpace($path)){
        [System.Windows.Forms.MessageBox]::Show("Please select a folder path first","Warning")
        return
    }

    if(!(Test-Path $path)){
        [System.Windows.Forms.MessageBox]::Show("Path does not exist","Error")
        return
    }

    $status.Text = "Restoring..."
    $stop.Enabled = $true
    $global:stopProcess = $false

    $drivers = Get-ChildItem $path -Recurse -Filter *.inf
    $progress.Maximum = $drivers.Count
    $progress.Value = 0

    foreach($d in $drivers){
        if($global:stopProcess){
            $log.AppendText("Restore stopped by user`r`n")
            break
        }

        $process = Start-Process "cmd.exe" -ArgumentList "/c pnputil /add-driver `"$($d.FullName)`" /install" -Verb RunAs -WindowStyle Hidden -PassThru
        $global:currentProcess = $process

        while(!$process.HasExited){
            Start-Sleep -Milliseconds 300
            [System.Windows.Forms.Application]::DoEvents()

            if($global:stopProcess){
                $process.Kill()
                break
            }
        }

        $log.AppendText("Installed: $($d.Name)`r`n")
        $progress.Value += 1
    }

    $status.Text = "Restore Done"
    $stop.Enabled = $false
    $global:currentProcess = $null
})

# Scan
$scan.Add_Click({
    $status.Text = "Scanning..."
    $devices = Get-WmiObject Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 }

    if($devices.Count -eq 0){ $log.AppendText("No missing drivers`r`n") }
    else{
        foreach($d in $devices){
            $log.AppendText("$($d.Name)`r`n")
        }
    }

    $status.Text = "Scan Complete"
})

# Online
$online.Add_Click({
    $devices = Get-WmiObject Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 }
    foreach($d in $devices){
        Start-Process ("https://www.google.com/search?q=" + [uri]::EscapeDataString($d.Name + " driver"))
    }
})

# Stop
$stop.Add_Click({
    $global:stopProcess = $true

    if($global:currentProcess -ne $null){
        try{ $global:currentProcess.Kill() } catch {}
    }

    $log.AppendText("Stopping process...`r`n")
})

# About
$about.Add_Click({
    [System.Windows.Forms.MessageBox]::Show("Seba Driver Exporter v1.0`r`nDeveloper: S M Ashraful Azom`r`nPhone: +8801711986954`r`nWebSite: sebacomputers.com","About")
})

# Add Controls
$form.Controls.AddRange(@($title,$textBox,$browse,$export,$restore,$scan,$online,$stop,$about,$progress,$log,$status))

$form.ShowDialog()
