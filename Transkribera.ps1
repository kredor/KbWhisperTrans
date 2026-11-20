param([string]$AudioPath = '')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$script:Root = $PSScriptRoot
$script:Process = $null
$script:LineTask = $null
$script:ErrorTask = $null
$script:Finished = $false
$script:OutputPath = ''
$script:Started = $null
$script:JobPath = $null
$script:LastProgress = $null

$form = New-Object System.Windows.Forms.Form
$form.Text = 'KB Transkriberare'
$form.ClientSize = New-Object System.Drawing.Size(720, 570)
$form.MinimumSize = New-Object System.Drawing.Size(736, 609)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)
$form.AutoScaleMode = 'Dpi'

function Add-Label($text, $x, $y, $w, $h) {
    $control = New-Object System.Windows.Forms.Label
    $control.Text = $text
    $control.SetBounds($x, $y, $w, $h)
    $form.Controls.Add($control)
    return $control
}
function Add-Button($text, $x, $y, $w, $h) {
    $control = New-Object System.Windows.Forms.Button
    $control.Text = $text
    $control.SetBounds($x, $y, $w, $h)
    $form.Controls.Add($control)
    return $control
}
function Format-Time([double]$seconds) {
    $span = [TimeSpan]::FromSeconds([Math]::Max(0, $seconds))
    return ('{0:00}:{1:00}:{2:00}' -f [int][Math]::Floor($span.TotalHours), $span.Minutes, $span.Seconds)
}
$title = Add-Label 'Ljud till text' 24 18 660 36
$title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 20)
$subtitle = Add-Label 'Lokalt på datorn · Svenska med KB-Whisper · Engelska med Distil-Whisper' 26 62 670 28
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(70, 80, 95)
$null = Add-Label 'Ljudfil' 26 101 100 24
$fileBox = New-Object System.Windows.Forms.TextBox
$fileBox.SetBounds(26, 128, 552, 29)
$fileBox.Text = $AudioPath
$form.Controls.Add($fileBox)
$browse = Add-Button 'Välj fil …' 590 126 104 32
$null = Add-Label 'Språk' 26 177 150 24
$language = New-Object System.Windows.Forms.ComboBox
$language.SetBounds(26, 204, 200, 30)
$language.DropDownStyle = 'DropDownList'
$language.Items.AddRange(@('Svenska', 'Engelska'))
$language.SelectedIndex = 0
$form.Controls.Add($language)
$null = Add-Label 'Svensk modell' 248 177 260 24
$quality = New-Object System.Windows.Forms.ComboBox
$quality.SetBounds(248, 204, 446, 30)
$quality.DropDownStyle = 'DropDownList'
$quality.Items.AddRange(@('KB-Whisper Small – snabbare', 'KB-Whisper Large – högre noggrannhet, långsammare'))
$quality.SelectedIndex = 0
$form.Controls.Add($quality)
$hint = Add-Label 'Sparas som en .md-fil i ljudfilens mapp. Löpande text utan tidsangivelser.' 26 248 668 24
$start = Add-Button 'Starta transkribering' 26 282 218 40
$start.BackColor = [System.Drawing.Color]::FromArgb(25, 90, 135)
$start.ForeColor = [System.Drawing.Color]::White
$cancel = Add-Button 'Avbryt' 258 282 106 40
$cancel.Enabled = $false
$status = Add-Label 'Välj en ljudfil och tryck på Starta.' 26 344 668 30
$status.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 11)
$bar = New-Object System.Windows.Forms.ProgressBar
$bar.SetBounds(26, 382, 668, 24)
$form.Controls.Add($bar)
$stats = Add-Label '' 26 416 668 49
$stats.ForeColor = [System.Drawing.Color]::FromArgb(70, 80, 95)
$open = Add-Button 'Öppna transkription' 26 478 200 36
$open.Enabled = $false
$folder = Add-Button 'Öppna mapp' 240 478 152 36
$folder.Enabled = $false
$privacy = Add-Label 'Ljudfilen lämnar aldrig datorn. Förlopps- och tidsuppskattningar uppdateras per textsegment.' 26 532 668 30
$privacy.Font = New-Object System.Drawing.Font('Segoe UI', 8)

$browse.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    # Avoid Windows' redirected Documents folder, which can be an unavailable UNC share.
    $dialog.InitialDirectory = $script:Root
    $dialog.RestoreDirectory = $true
    if ($fileBox.Text -and (Test-Path -LiteralPath $fileBox.Text -PathType Leaf)) {
        $dialog.InitialDirectory = [System.IO.Path]::GetDirectoryName($fileBox.Text)
    }
    $dialog.Filter = 'Ljud och video|*.mp3;*.wav;*.m4a;*.flac;*.ogg;*.opus;*.aac;*.wma;*.aiff;*.aif;*.mp4;*.mkv;*.webm;*.m4b;*.amr;*.mpga|Alla filer|*.*'
    if ($dialog.ShowDialog() -eq 'OK') { $fileBox.Text = $dialog.FileName }
    $dialog.Dispose()
})
$language.Add_SelectedIndexChanged({ $quality.Enabled = ($language.SelectedIndex -eq 0) })

function Set-Running([bool]$running) {
    $start.Enabled = -not $running
    $browse.Enabled = -not $running
    $fileBox.Enabled = -not $running
    $language.Enabled = -not $running
    $quality.Enabled = (-not $running) -and ($language.SelectedIndex -eq 0)
    $cancel.Enabled = $running
}
function Handle-Event($eventData) {
    switch ($eventData.kind) {
        'status' { $status.Text = $eventData.text }
        'progress' {
            $script:LastProgress = $eventData
            $bar.Style = 'Continuous'
            $bar.Value = [Math]::Min(99, [int]$eventData.percent)
            $status.Text = ('Transkriberar … {0:N0} %' -f $eventData.percent)
        }
        'done' {
            $script:Finished = $true
            $script:OutputPath = $eventData.output
            $bar.Style = 'Continuous'
            $bar.Value = 100
            $status.Text = 'Klart! Transkriptionen har sparats.'
            $stats.Text = ('Tid: {0} · Ljudlängd: {1}' -f (Format-Time $eventData.elapsed), (Format-Time $eventData.duration)) + "`r`n" + [System.IO.Path]::GetFileName($eventData.output)
            $open.Enabled = $true
            $folder.Enabled = $true
            [System.Media.SystemSounds]::Asterisk.Play()
        }
        'empty' {
            $script:Finished = $true
            $bar.Style = 'Continuous'
            $bar.Value = 0
            $status.Text = 'Inget tal identifierades.'
            $stats.Text = $eventData.text
        }
        'error' {
            $script:Finished = $true
            $bar.Style = 'Continuous'
            $status.Text = 'Transkriberingen kunde inte slutföras.'
            $stats.Text = $eventData.text
        }
    }
}
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 200
$timer.Add_Tick({
    if ($null -eq $script:Process) { return }
    try {
        while ($null -ne $script:LineTask -and $script:LineTask.IsCompleted) {
            $line = $script:LineTask.GetAwaiter().GetResult()
            if ($null -eq $line) { $script:LineTask = $null; break }
            if ($line.Trim()) { Handle-Event ($line | ConvertFrom-Json) }
            $script:LineTask = $script:Process.StandardOutput.ReadLineAsync()
        }
        if (-not $script:Finished) {
            $elapsed = ([DateTime]::Now - $script:Started).TotalSeconds
            $stats.Text = 'Förfluten tid: ' + (Format-Time $elapsed)
            if ($null -ne $script:LastProgress) {
                $p = $script:LastProgress
                $stats.Text += (' · Hastighet: {0:N1}× ljudets längd' -f $p.speed)
                $stats.Text += "`r`n" + ('Bearbetat {0} av {1} · Uppskattat kvar: {2}' -f (Format-Time $p.processed), (Format-Time $p.duration), (Format-Time $p.remaining))
            } else { $stats.Text += ' · Förbereder, tidsuppskattning kommer efter första textsegmentet.' }
        }
        if ($script:Process.HasExited -and $null -eq $script:LineTask) {
            $stderr = $script:ErrorTask.GetAwaiter().GetResult()
            if (-not $script:Finished) {
                $bar.Style = 'Continuous'
                $status.Text = 'Programmet avslutades innan transkriptionen blev klar.'
                $stats.Text = 'Se senaste-felet.log i programmappen.'
            }
            if ($stderr) { [System.IO.File]::WriteAllText((Join-Path $script:Root 'senaste-felet.log'), $stderr) }
            $script:Process.Dispose()
            $script:Process = $null
            if ($script:JobPath -and (Test-Path -LiteralPath $script:JobPath)) { Remove-Item -LiteralPath $script:JobPath }
            Set-Running $false
            $timer.Stop()
        }
    } catch {
        $timer.Stop()
        if ($script:Process -and -not $script:Process.HasExited) { $script:Process.Kill() }
        $script:Process = $null
        $bar.Style = 'Continuous'
        $status.Text = 'Ett fel inträffade.'
        $stats.Text = $_.Exception.Message
        Set-Running $false
    }
})
$start.Add_Click({
    try {
        $audio = $fileBox.Text.Trim().Trim('"')
        if (-not (Test-Path -LiteralPath $audio -PathType Leaf)) { throw 'Välj en ljudfil som finns på datorn.' }
        $audio = (Get-Item -LiteralPath $audio).FullName
        $destination = [System.IO.Path]::ChangeExtension($audio, '.md')
        if ($audio -eq $destination) { throw 'Välj en ljudfil, inte en Markdown-fil.' }
        $overwrite = $false
        if (Test-Path -LiteralPath $destination) {
            $answer = [System.Windows.Forms.MessageBox]::Show("Filen finns redan:`r`n$destination`r`n`r`nVill du ersätta den när transkriberingen är klar?", 'Ersätta transkription?', 'YesNo', 'Question')
            if ($answer -ne 'Yes') { return }
            $overwrite = $true
        }
        $jobs = Join-Path $script:Root 'jobs'
        New-Item -ItemType Directory -Force -Path $jobs | Out-Null
        $script:JobPath = Join-Path $jobs ([Guid]::NewGuid().ToString() + '.json')
        $lang = if ($language.SelectedIndex -eq 0) { 'sv' } else { 'en' }
        $size = if ($quality.SelectedIndex -eq 1) { 'large' } else { 'small' }
        $job = @{audio=$audio; language=$lang; quality=$size; overwrite=$overwrite} | ConvertTo-Json
        [System.IO.File]::WriteAllText($script:JobPath, $job, (New-Object System.Text.UTF8Encoding($false)))
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = Join-Path $script:Root 'runtime\python.exe'
        $psi.Arguments = '-u "' + (Join-Path $script:Root 'worker.py') + '" --job "' + $script:JobPath + '"'
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
        $script:Finished = $false
        $script:LastProgress = $null
        $script:OutputPath = ''
        $open.Enabled = $false
        $folder.Enabled = $false
        $script:Started = [DateTime]::Now
        $script:Process = [System.Diagnostics.Process]::Start($psi)
        $script:LineTask = $script:Process.StandardOutput.ReadLineAsync()
        $script:ErrorTask = $script:Process.StandardError.ReadToEndAsync()
        $bar.Value = 0
        $bar.Style = 'Marquee'
        $status.Text = 'Startar …'
        Set-Running $true
        $timer.Start()
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Kunde inte starta', 'OK', 'Error') | Out-Null }
})
function Stop-Transcription {
    if ($script:Process -and -not $script:Process.HasExited) {
        $script:Process.Kill()
        $script:Finished = $true
        $bar.Style = 'Continuous'
        $status.Text = 'Avbrutet.'
        $stats.Text = 'Ingen ofullständig transkription har sparats.'
    }
}
$cancel.Add_Click({ Stop-Transcription })
$form.Add_FormClosing({
    if ($script:Process -and -not $script:Process.HasExited) {
        $answer = [System.Windows.Forms.MessageBox]::Show('Transkribering pågår. Vill du avbryta och stänga?', 'Avbryta?', 'YesNo', 'Question')
        if ($answer -ne 'Yes') { $_.Cancel = $true; return }
        Stop-Transcription
    }
    $timer.Stop()
})
$open.Add_Click({ if ($script:OutputPath) { Start-Process -FilePath $script:OutputPath } })
$folder.Add_Click({ if ($script:OutputPath) { Start-Process -FilePath 'explorer.exe' -ArgumentList ('/select,"' + $script:OutputPath + '"') } })
[System.Windows.Forms.Application]::Run($form)
$timer.Dispose()
$form.Dispose()
