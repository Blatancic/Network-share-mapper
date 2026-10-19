<#
NetworkFolderMapper_v6.ps1
Maps UNC folders as Windows Network Locations (not drive letters).
Author: Misel Blatancic  2026
Windows PowerShell 5.1
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:CsvPath   = Join-Path $script:ScriptDir 'users.csv'
$script:SharedPath = '\\192.168.1.150\Zajednicki'
$script:SharedName = 'Zajednicki'
$script:Dark = $false
$script:Rows = @()

if (-not (Test-Path -LiteralPath $script:CsvPath)) {
    @'
Username,Password,SharePath,DisplayName
Sinisateo,vezkhnTP7bjxDB6J,\\192.168.1.150\Sinisateo,Sinisa Privatno
Slobateo,TF8rJRNmyZUsYf6t,\\192.168.1.150\Slobateo,Slobodan Privatno
'@ | Set-Content -LiteralPath $script:CsvPath -Encoding UTF8
}

function Get-UserRows { @(Import-Csv -LiteralPath $script:CsvPath -Encoding UTF8) }

function Save-UserRows($rows) {
    $rows = @($rows)
    if ($rows.Count -eq 0) { Set-Content -LiteralPath $script:CsvPath -Value 'Username,Password,SharePath,DisplayName' -Encoding UTF8 }
    else { $rows | Export-Csv -LiteralPath $script:CsvPath -NoTypeInformation -Encoding UTF8 }
}

function Test-UncPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if (-not $Path.StartsWith('\\')) { return $false }
    $parts = $Path.Substring(2).Split('\') | Where-Object { $_ -ne '' }
    return (@($parts).Count -ge 2)
}

function Test-EntryFields($u,$p,$path,$name) {
    if ([string]::IsNullOrWhiteSpace($u))    { return 'Username is required.' }
    if ([string]::IsNullOrWhiteSpace($p))    { return 'Password is required.' }
    if (-not (Test-UncPath $path))           { return 'Share path must look like \\server\share' }
    if ([string]::IsNullOrWhiteSpace($name)) { return 'Display name is required.' }
    return $null
}

function Get-ServerFromPath([string]$Path) {
    if (-not $Path -or -not $Path.StartsWith('\\')) { return $null }
    $server = $Path.Substring(2).Split('\')[0]
    if ($server) { return $server }
    return $null
}

function Get-NetHoodPath {
    Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Microsoft\Windows\Network Shortcuts'
}

function New-NetworkLocation([string]$Name,[string]$Target) {
    try {
        $dir = Join-Path (Get-NetHoodPath) $Name
        if (Test-Path -LiteralPath $dir) {
            (Get-Item -LiteralPath $dir -Force).Attributes = 'Directory'
            Remove-Item -LiteralPath $dir -Recurse -Force
        }
        [void](New-Item -ItemType Directory -Path $dir -Force)
        $ini = Join-Path $dir 'desktop.ini'
        Set-Content -LiteralPath $ini -Value "[.ShellClassInfo]`r`nCLSID2={0AFACED1-E828-11D1-9187-B532F1E9575D}`r`nFlags=2" -Encoding ASCII
        $wsh = New-Object -ComObject WScript.Shell
        $lnk = $wsh.CreateShortcut((Join-Path $dir 'target.lnk'))
        $lnk.TargetPath = $Target
        $lnk.Save()
        (Get-Item -LiteralPath $ini -Force).Attributes = 'Hidden,System'
        (Get-Item -LiteralPath $dir -Force).Attributes = 'ReadOnly'
        return $true
    } catch { return $false }
}

function Remove-NetworkLocation([string]$Name) {
    try {
        $dir = Join-Path (Get-NetHoodPath) $Name
        if (Test-Path -LiteralPath $dir) {
            (Get-Item -LiteralPath $dir -Force).Attributes = 'Directory'
            Remove-Item -LiteralPath $dir -Recurse -Force
        }
        return $true
    } catch { return $false }
}

function Add-ShareLocation([string]$Path,[string]$User,[string]$Pass,[string]$Name) {
    $server = Get-ServerFromPath $Path
    if (-not $server) { return "FAILED: $Name - invalid path." }
    if ($User) {
        & cmdkey.exe "/delete:$server" 2>&1 | Out-Null
        & cmdkey.exe "/add:$server" "/user:$User" "/pass:$Pass" 2>&1 | Out-Null
    }
    if (-not (Test-Path -LiteralPath $Path)) { return "FAILED: $Name - cannot reach $Path." }
    if (-not (New-NetworkLocation -Name $Name -Target $Path)) { return "FAILED: $Name - could not create location." }
    return "OK: $Name added."
}

function Remove-ShareLocation([string]$Path,[string]$Name) {
    $server = Get-ServerFromPath $Path
    if (-not (Remove-NetworkLocation -Name $Name)) { return "FAILED: could not remove $Name." }
    if ($server) { & cmdkey.exe "/delete:$server" 2>&1 | Out-Null }
    return "OK: $Name removed."
}

function Get-ShareUser([string]$Path) {
    $server = Get-ServerFromPath $Path
    if (-not $server) { return $null }
    $out = & cmdkey.exe /list 2>&1 | Out-String
    $blocks = $out -split '(?m)^\s*$'
    foreach ($b in $blocks) {
        if ($b -match ('(?im)Target:\s*(Domain:target=)?' + [regex]::Escape($server) + '\s*$') -and $b -match '(?im)User:\s*(.+?)\s*$') { return $Matches[1] }
    }
    return $null
}

try {
    $form = New-Object Windows.Forms.Form
    $form.Text = 'Network Folder Mapper'
    $form.StartPosition = 'CenterScreen'
    $form.ClientSize = New-Object Drawing.Size(700,680)
    $form.FormBorderStyle = 'FixedSingle'
    $form.MaximizeBox = $false
    $form.Font = New-Object Drawing.Font('Segoe UI',9.5)

    # ---------- header ----------
    $header = New-Object Windows.Forms.Panel
    $header.Location = New-Object Drawing.Point(0,0)
    $header.Size = New-Object Drawing.Size(700,70)
    $form.Controls.Add($header)

    $title = New-Object Windows.Forms.Label
    $title.Text = 'Network Folder Mapper'
    $title.Font = New-Object Drawing.Font('Segoe UI',17,[Drawing.FontStyle]::Bold)
    $title.Location = New-Object Drawing.Point(20,10)
    $title.AutoSize = $true
    $header.Controls.Add($title)

    $sub = New-Object Windows.Forms.Label
    $sub.Text = 'Create Windows Network Locations for shared folders'
    $sub.Location = New-Object Drawing.Point(22,44)
    $sub.AutoSize = $true
    $header.Controls.Add($sub)

    $darkChk = New-Object Windows.Forms.CheckBox
    $darkChk.Text = 'Dark mode'
    $darkChk.Location = New-Object Drawing.Point(590,24)
    $darkChk.AutoSize = $true
    $header.Controls.Add($darkChk)

    # ---------- tab bar ----------
    $tabBar = New-Object Windows.Forms.Panel
    $tabBar.Location = New-Object Drawing.Point(0,70)
    $tabBar.Size = New-Object Drawing.Size(700,42)
    $form.Controls.Add($tabBar)

    $host_ = New-Object Windows.Forms.Panel
    $host_.Location = New-Object Drawing.Point(0,112)
    $host_.Size = New-Object Drawing.Size(700,538)
    $form.Controls.Add($host_)

    $footer = New-Object Windows.Forms.Label
    $footer.Text = 'Author: Misel Blatancic  |  2026'
    $footer.TextAlign = 'MiddleCenter'
    $footer.Location = New-Object Drawing.Point(0,650)
    $footer.Size = New-Object Drawing.Size(700,30)
    $form.Controls.Add($footer)

    # ---------- helpers ----------
    function New-Page {
        $p = New-Object Windows.Forms.Panel
        $p.Location = New-Object Drawing.Point(0,0)
        $p.Size = New-Object Drawing.Size(700,538)
        $p.Visible = $false
        $host_.Controls.Add($p)
        return $p
    }
    function New-Btn($text,$x,$y,$w,$parent,$primary) {
        $b = New-Object Windows.Forms.Button
        $b.Text = $text
        $b.Location = New-Object Drawing.Point($x,$y)
        $b.Size = New-Object Drawing.Size($w,34)
        $b.FlatStyle = 'Flat'
        $b.Cursor = 'Hand'
        $b.Tag = $(if ($primary) { 'primary' } else { 'normal' })
        $parent.Controls.Add($b)
        return $b
    }
    function New-Lbl($text,$x,$y,$parent) {
        $l = New-Object Windows.Forms.Label
        $l.Text = $text
        $l.Location = New-Object Drawing.Point($x,$y)
        $l.AutoSize = $true
        $parent.Controls.Add($l)
        return $l
    }
    function New-Txt($x,$y,$w,$parent) {
        $t = New-Object Windows.Forms.TextBox
        $t.Location = New-Object Drawing.Point($x,$y)
        $t.Size = New-Object Drawing.Size($w,27)
        $t.BorderStyle = 'FixedSingle'
        $parent.Controls.Add($t)
        return $t
    }
    function Set-Status($label,$text,$ok) {
        $label.Text = $text
        $label.ForeColor = $(if ($ok) { [Drawing.Color]::FromArgb(40,167,69) } else { [Drawing.Color]::FromArgb(220,53,69) })
    }

    $pgConnect = New-Page
    $pgShared  = New-Page
    $pgAdd     = New-Page
    $pgEdit    = New-Page

    # ===== Connect =====
    $connectList = New-Object Windows.Forms.CheckedListBox
    $connectList.Location = New-Object Drawing.Point(20,20)
    $connectList.Size = New-Object Drawing.Size(440,250)
    $connectList.DisplayMember = 'DisplayName'
    $connectList.CheckOnClick = $true
    $connectList.BorderStyle = 'FixedSingle'
    $pgConnect.Controls.Add($connectList)

    $btnAll   = New-Btn 'Select all'  480 20  180 $pgConnect $false
    $btnNone  = New-Btn 'Select none' 480 62  180 $pgConnect $false
    $btnRefC  = New-Btn 'Refresh'     480 104 180 $pgConnect $false
    $btnApply = New-Btn 'Apply'       480 156 180 $pgConnect $true
    $btnRem   = New-Btn 'Remove'      480 198 180 $pgConnect $false

    $null = New-Lbl 'Tick users, then click Apply to create their Network Locations.' 20 282 $pgConnect

    $connectOut = New-Object Windows.Forms.Label
    $connectOut.Location = New-Object Drawing.Point(20,312)
    $connectOut.Size = New-Object Drawing.Size(640,200)
    $connectOut.BorderStyle = 'FixedSingle'
    $connectOut.Padding = New-Object Windows.Forms.Padding(8)
    $pgConnect.Controls.Add($connectOut)

    # ===== Mutual shares =====
    $null = New-Lbl 'Windows keeps one login per server. The login you choose is used for Zajednicki.' 20 20 $pgShared
    $null = New-Lbl 'Connect as:' 20 66 $pgShared
    $sharedUser = New-Object Windows.Forms.ComboBox
    $sharedUser.Location = New-Object Drawing.Point(120,62)
    $sharedUser.Size = New-Object Drawing.Size(400,28)
    $sharedUser.DropDownStyle = 'DropDownList'
    $pgShared.Controls.Add($sharedUser)
    $null = New-Lbl 'Share location:' 20 112 $pgShared
    $sharedPathBox = New-Txt 120 108 400 $pgShared
    $sharedPathBox.Text = $script:SharedPath
    $sharedAdd = New-Btn 'Add Zajednicki'    120 160 190 $pgShared $true
    $sharedRem = New-Btn 'Remove Zajednicki' 330 160 190 $pgShared $false
    $sharedStatus = New-Lbl '' 120 215 $pgShared
    $null = New-Lbl 'Currently used by:' 20 262 $pgShared
    $sharedCurrent = New-Lbl '' 150 262 $pgShared
    $sharedCurrent.Font = New-Object Drawing.Font('Segoe UI',9.5,[Drawing.FontStyle]::Bold)

    # ===== Add user =====
    $null = New-Lbl 'Username' 20 26 $pgAdd;      $addUser = New-Txt 140 22 400 $pgAdd
    $null = New-Lbl 'Password' 20 70 $pgAdd;      $addPass = New-Txt 140 66 300 $pgAdd; $addPass.UseSystemPasswordChar = $true
    $addShow = New-Object Windows.Forms.CheckBox; $addShow.Text = 'Show password'; $addShow.Location = New-Object Drawing.Point(450,68); $addShow.AutoSize = $true; $pgAdd.Controls.Add($addShow)
    $null = New-Lbl 'Share path' 20 114 $pgAdd;   $addPath = New-Txt 140 110 400 $pgAdd
    $null = New-Lbl 'Display name' 20 158 $pgAdd; $addDisp = New-Txt 140 154 400 $pgAdd
    $btnSaveAdd = New-Btn 'Save user' 140 200 160 $pgAdd $true
    $addStatus = New-Lbl '' 140 248 $pgAdd
    $null = New-Lbl 'Delete user' 20 318 $pgAdd
    $delBox = New-Object Windows.Forms.ComboBox
    $delBox.Location = New-Object Drawing.Point(140,314)
    $delBox.Size = New-Object Drawing.Size(270,28)
    $delBox.DropDownStyle = 'DropDownList'
    $pgAdd.Controls.Add($delBox)
    $btnDel = New-Btn 'Delete' 425 311 115 $pgAdd $false

    # ===== Edit user =====
    $null = New-Lbl 'Select user' 20 26 $pgEdit
    $editBox = New-Object Windows.Forms.ComboBox
    $editBox.Location = New-Object Drawing.Point(140,22)
    $editBox.Size = New-Object Drawing.Size(400,28)
    $editBox.DropDownStyle = 'DropDownList'
    $pgEdit.Controls.Add($editBox)
    $null = New-Lbl 'Username' 20 70 $pgEdit;      $editUser = New-Txt 140 66 400 $pgEdit
    $null = New-Lbl 'Password' 20 114 $pgEdit;     $editPass = New-Txt 140 110 300 $pgEdit; $editPass.UseSystemPasswordChar = $true
    $editShow = New-Object Windows.Forms.CheckBox; $editShow.Text = 'Show password'; $editShow.Location = New-Object Drawing.Point(450,112); $editShow.AutoSize = $true; $pgEdit.Controls.Add($editShow)
    $null = New-Lbl 'Share path' 20 158 $pgEdit;   $editPath = New-Txt 140 154 400 $pgEdit
    $null = New-Lbl 'Display name' 20 202 $pgEdit; $editDisp = New-Txt 140 198 400 $pgEdit
    $btnSaveEdit = New-Btn 'Save changes' 140 246 150 $pgEdit $true
    $btnRefE     = New-Btn 'Refresh'      305 246 110 $pgEdit $false
    $editStatus  = New-Lbl '' 140 294 $pgEdit

    # ---------- tabs + theme ----------
    $script:Pages = @($pgConnect,$pgShared,$pgAdd,$pgEdit)
    $script:TabBtns = @()
    $tabNames = @('Connect','Mutual shares','Add User','Edit User')
    $script:ActiveTab = 0

    $underline = New-Object Windows.Forms.Panel
    $underline.Height = 3
    $underline.Width = 160
    $tabBar.Controls.Add($underline)

    function Apply-Theme {
        if ($script:Dark) {
            $bg=[Drawing.Color]::FromArgb(30,30,30); $panel=[Drawing.Color]::FromArgb(37,37,38)
            $fg=[Drawing.Color]::FromArgb(235,235,235); $inp=[Drawing.Color]::FromArgb(51,51,55)
            $bar=[Drawing.Color]::FromArgb(24,24,24); $border=[Drawing.Color]::FromArgb(70,70,74)
        } else {
            $bg=[Drawing.Color]::FromArgb(243,243,243); $panel=[Drawing.Color]::White
            $fg=[Drawing.Color]::FromArgb(30,30,30); $inp=[Drawing.Color]::White
            $bar=[Drawing.Color]::FromArgb(31,47,67); $border=[Drawing.Color]::FromArgb(180,180,180)
        }
        $accent=[Drawing.Color]::FromArgb(0,120,212)
        $form.BackColor=$bg; $header.BackColor=$bar; $title.ForeColor=[Drawing.Color]::White
        $sub.ForeColor=[Drawing.Color]::FromArgb(200,210,220); $darkChk.ForeColor=[Drawing.Color]::White
        $darkChk.BackColor=$bar; $title.BackColor=$bar; $sub.BackColor=$bar
        $tabBar.BackColor=$bar; $footer.BackColor=$bg; $footer.ForeColor=[Drawing.Color]::Gray
        $host_.BackColor=$panel
        foreach ($pg in $script:Pages) {
            $pg.BackColor=$panel
            foreach ($c in $pg.Controls) {
                if ($c -is [Windows.Forms.Button]) {
                    $c.FlatAppearance.BorderSize = 1
                    if ($c.Tag -eq 'primary') { $c.BackColor=$accent; $c.ForeColor=[Drawing.Color]::White; $c.FlatAppearance.BorderColor=$accent }
                    else { $c.BackColor=$inp; $c.ForeColor=$fg; $c.FlatAppearance.BorderColor=$border }
                }
                elseif ($c -is [Windows.Forms.TextBox] -or $c -is [Windows.Forms.ComboBox] -or $c -is [Windows.Forms.CheckedListBox]) {
                    $c.BackColor=$inp; $c.ForeColor=$fg
                }
                elseif ($c -is [Windows.Forms.Label] -and $c -ne $connectOut) {
                    $c.BackColor=$panel
                    if ($c -ne $sharedStatus -and $c -ne $addStatus -and $c -ne $editStatus) { $c.ForeColor=$fg }
                }
                elseif ($c -is [Windows.Forms.CheckBox]) { $c.BackColor=$panel; $c.ForeColor=$fg }
            }
        }
        $connectOut.BackColor=$inp; $connectOut.ForeColor=$fg
        for ($i=0; $i -lt $script:TabBtns.Count; $i++) {
            $tb=$script:TabBtns[$i]
            $tb.BackColor=$bar; $tb.FlatAppearance.BorderSize=0
            if ($i -eq $script:ActiveTab) { $tb.ForeColor=[Drawing.Color]::White; $tb.Font=New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold) }
            else { $tb.ForeColor=[Drawing.Color]::FromArgb(150,160,170); $tb.Font=New-Object Drawing.Font('Segoe UI',10) }
        }
        $underline.BackColor=$accent
    }

    function Show-Tab([int]$i) {
        $script:ActiveTab = $i
        for ($k=0; $k -lt $script:Pages.Count; $k++) { $script:Pages[$k].Visible = ($k -eq $i) }
        $underline.Location = New-Object Drawing.Point((20 + $i*165), 38)
        $underline.BringToFront()
        Apply-Theme
    }

    for ($i=0; $i -lt 4; $i++) {
        $tb = New-Object Windows.Forms.Button
        $tb.Text = $tabNames[$i]
        $tb.FlatStyle = 'Flat'
        $tb.Cursor = 'Hand'
        $tb.Size = New-Object Drawing.Size(160,38)
        $tb.Location = New-Object Drawing.Point((20 + $i*165), 0)
        $tb.Tag = $i
        $tb.Add_Click({ Show-Tab ([int]$this.Tag) })
        $tabBar.Controls.Add($tb)
        $script:TabBtns += $tb
    }

    # ---------- data refresh ----------
    function Update-SharedCurrent {
        $u = Get-ShareUser $sharedPathBox.Text.Trim()
        if ($u) { $sharedCurrent.Text = $u } else { $sharedCurrent.Text = '(none saved - using current Windows login)' }
    }

    function Refresh-All {
        $script:Rows = @(Get-UserRows)
        $connectList.Items.Clear(); $delBox.Items.Clear(); $editBox.Items.Clear(); $sharedUser.Items.Clear()
        foreach ($r in $script:Rows) {
            [void]$connectList.Items.Add($r)
            [void]$delBox.Items.Add($r.Username)
            [void]$editBox.Items.Add($r.Username)
            [void]$sharedUser.Items.Add($r.Username)
        }
        [void]$sharedUser.Items.Add('(current Windows login)')
        if ($sharedUser.Items.Count -gt 0) { $sharedUser.SelectedIndex = 0 }
        Update-SharedCurrent
    }

    # ---------- logic ----------
    $btnAll.Add_Click({ for ($i=0;$i -lt $connectList.Items.Count;$i++) { $connectList.SetItemChecked($i,$true) } })
    $btnNone.Add_Click({ for ($i=0;$i -lt $connectList.Items.Count;$i++) { $connectList.SetItemChecked($i,$false) } })
    $btnRefC.Add_Click({ Refresh-All; $connectOut.Text = ('List refreshed ({0} users).' -f $script:Rows.Count) })
    $btnRefE.Add_Click({ Refresh-All; Set-Status $editStatus ('List refreshed ({0} users).' -f $script:Rows.Count) $true })
    $addShow.Add_CheckedChanged({ $addPass.UseSystemPasswordChar = -not $addShow.Checked })
    $editShow.Add_CheckedChanged({ $editPass.UseSystemPasswordChar = -not $editShow.Checked })

    $btnApply.Add_Click({
        $msgs = New-Object Collections.Generic.List[string]
        foreach ($it in @($connectList.CheckedItems)) {
            [void]$msgs.Add((Add-ShareLocation -Path $it.SharePath -User $it.Username -Pass $it.Password -Name $it.DisplayName))
        }
        if ($msgs.Count -eq 0) { $msgs.Add('Nothing selected.') }
        $connectOut.Text = ($msgs -join [Environment]::NewLine)
    })

    $btnRem.Add_Click({
        $msgs = New-Object Collections.Generic.List[string]
        foreach ($it in @($connectList.CheckedItems)) {
            [void]$msgs.Add((Remove-ShareLocation -Path $it.SharePath -Name $it.DisplayName))
        }
        if ($msgs.Count -eq 0) { $msgs.Add('Nothing selected.') }
        $connectOut.Text = ($msgs -join [Environment]::NewLine)
    })

    $sharedAdd.Add_Click({
        $path = $sharedPathBox.Text.Trim()
        if (-not (Test-UncPath $path)) { Set-Status $sharedStatus 'Share location must look like \\server\share' $false; return }
        $script:SharedPath = $path
        $u=''; $p=''; $label='current Windows login'
        $sel = [string]$sharedUser.SelectedItem
        if ($sel -and $sel -ne '(current Windows login)') {
            $r = @($script:Rows | Where-Object { $_.Username -eq $sel } | Select-Object -First 1)
            if ($r.Count -gt 0) { $u=$r[0].Username; $p=$r[0].Password; $label=$u }
        }
        $res = Add-ShareLocation -Path $script:SharedPath -User $u -Pass $p -Name $script:SharedName
        if ($res -like 'OK:*' -and $u) {
            $rows = @(Get-UserRows)
            $exists = @($rows | Where-Object { $_.SharePath -eq $path -and $_.DisplayName -eq $script:SharedName }).Count -gt 0
            if (-not $exists) {
                $rows += [pscustomobject]@{ Username=$u; Password=$p; SharePath=$path; DisplayName=$script:SharedName }
                Save-UserRows $rows
            }
            Refresh-All
        }
        Set-Status $sharedStatus ($res + ' Using ' + $label + '.') ($res -like 'OK:*')
        Update-SharedCurrent
    })

    $sharedRem.Add_Click({
        $path = $sharedPathBox.Text.Trim()
        $res = Remove-ShareLocation -Path $path -Name $script:SharedName
        if ($res -like 'OK:*') {
            $rows = @(Get-UserRows) | Where-Object { -not ($_.SharePath -eq $path -and $_.DisplayName -eq $script:SharedName) }
            Save-UserRows @($rows)
            Refresh-All
        }
        Set-Status $sharedStatus $res ($res -like 'OK:*')
        Update-SharedCurrent
    })

    $btnSaveAdd.Add_Click({
        $err = Test-EntryFields $addUser.Text $addPass.Text $addPath.Text $addDisp.Text
        $rows = @(Get-UserRows)
        if (-not $err -and @($rows | Where-Object { $_.Username -eq $addUser.Text -and $_.SharePath -eq $addPath.Text }).Count -gt 0) { $err = 'Duplicate username and share path.' }
        if ($err) { Set-Status $addStatus $err $false; return }
        $rows += [pscustomobject]@{ Username=$addUser.Text; Password=$addPass.Text; SharePath=$addPath.Text; DisplayName=$addDisp.Text }
        Save-UserRows $rows
        $addUser.Clear(); $addPass.Clear(); $addPath.Clear(); $addDisp.Clear()
        Set-Status $addStatus 'Saved.' $true
        Refresh-All
    })

    $btnDel.Add_Click({
        if ([string]::IsNullOrWhiteSpace($delBox.Text)) { Set-Status $addStatus 'Select a user first.' $false; return }
        $ans = [Windows.Forms.MessageBox]::Show('Delete this entry? Remove its Network Location first if connected.','Confirm',[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Warning)
        if ($ans -ne [Windows.Forms.DialogResult]::Yes) { return }
        Save-UserRows @(@(Get-UserRows) | Where-Object { $_.Username -ne $delBox.Text })
        Set-Status $addStatus 'Deleted.' $true
        Refresh-All
    })

    $editBox.Add_SelectedIndexChanged({
        $r = @($script:Rows | Where-Object { $_.Username -eq $editBox.Text } | Select-Object -First 1)
        if ($r.Count -gt 0) { $editUser.Text=$r[0].Username; $editPass.Text=$r[0].Password; $editPath.Text=$r[0].SharePath; $editDisp.Text=$r[0].DisplayName }
    })

    $btnSaveEdit.Add_Click({
        $err = Test-EntryFields $editUser.Text $editPass.Text $editPath.Text $editDisp.Text
        $rows = @(Get-UserRows)
        $orig = $editBox.Text
        if (-not $err -and @($rows | Where-Object { $_.Username -eq $editUser.Text -and $_.SharePath -eq $editPath.Text -and $_.Username -ne $orig }).Count -gt 0) { $err = 'Duplicate username and share path.' }
        if ($err) { Set-Status $editStatus $err $false; return }
        foreach ($r in $rows) {
            if ($r.Username -eq $orig) { $r.Username=$editUser.Text; $r.Password=$editPass.Text; $r.SharePath=$editPath.Text; $r.DisplayName=$editDisp.Text }
        }
        Save-UserRows $rows
        Set-Status $editStatus 'Changes saved.' $true
        Refresh-All
    })

    $darkChk.Add_CheckedChanged({ $script:Dark = $darkChk.Checked; Apply-Theme })

    # ---------- start ----------
    Refresh-All
    Show-Tab 0
    [void]$form.ShowDialog()
}
catch {
    [Windows.Forms.MessageBox]::Show(("Error: " + $_.Exception.Message + "`r`nLine: " + $_.InvocationInfo.ScriptLineNumber),'Network Folder Mapper') | Out-Null
}