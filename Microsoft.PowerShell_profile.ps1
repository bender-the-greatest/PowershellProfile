# This is more of a backup of my profile but if you like it use it I guess.
# Some of the custom functions I have sourced on Github as gists, which are
# commented and documented, unlike these here.

# Needed for uru
$env:HOME = $env:USERPROFILE

# Set Security Protocol to TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

function Install-AndImport {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$moduleName
    )

    Write-Verbose "Importing $moduleName"
    if ( -not $( Get-Module -Name $moduleName -ListAvailable ) ) {
        Write-Verbose " Module $moduleName is not installed. Installing now..."
        Install-Module -Name $moduleName -Force -AllowClobber
    }

    Import-Module $moduleName -NoClobber
}

function Load-Customizations {
    Install-AndImport posh-ssh
    Install-AndImport posh-git
    Install-AndImport historypx
    Install-AndImport PSGithub
    Install-AndImport posh-with
    Install-AndImport pscx
    Install-AndImport importexcel
}


if( $env:PSLoadCustomizations ){
  Load-Customizations
}

# Force MS archive module to supercede pcsx since tooling requires it
Import-Module Microsoft.Powershell.Archive

function ConvertTo-ScriptBlock {
  <#
    Convert a string to a ScriptBlock
  #>
  Param(
    [Parameter( Mandatory=$true, ValueFromPipeline=$true )]
    [string]$ScriptContents
  )

  begin { $fullpipeline = "" }
  process { $fullpipeline += $ScriptContents }
  end {
    [ScriptBlock]::Create( $fullpipeline )
  }
}

function Open-ContainingFolder {
    Param(
        [string]$File
    )
    if ( -Not $File ) {
      Invoke-Item .
    } elseif (Test-Path -LiteralPath $File) {
        Invoke-Item $(Split-Path -Parent $File)
    } else {
        Write-Error "$File does not exist"
    }
}
Set-Alias -Name ocf -Value Open-ContainingFolder -Description "Open a file or directory parent folder in Windows Explorer."

function watch {
    Param(
        [Parameter(Mandatory=$true)][string]
        $command,
        [Parameter(Mandatory=$false)][int]
        $n = 2
    )

    while($true) {
        clear
        Write-Output (iex $command | Format-Table)
        sleep $n
    }
}

function Format-XML {
    Param(
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)]
        [xml]$xmldata,
        [int]$indent=2
    )
    $writer = New-Object System.IO.StringWriter
    $xwriter = New-Object System.XML.XmlTextWriter($writer)
    $xwriter.Formatting = "indented"
    $xwriter.Indentation = $indent
    $xmldata.WriteContentTo($xwriter)
    $xwriter.Flush()
    $writer.Flush()
    Write-Output $writer.ToString()
}

function Format-Json {
    Param(
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)]
        [string]$jsondata,
        [int]$indent=2
    )
    # Processing blocks are useful for multiline JSON strings
    begin { $fullpipeline = "" }
    process { $fullpipeline += $jsondata }
    end {
        $jsonformatted += $fullpipeline | ConvertFrom-Json | ConvertTo-Json

        # ConvertTo-Json doesn't have an indentation parameter, so do it ourselves
        $nested = 1
        ($jsonformatted -split '\r\n' |
            % {
                $line = $_
                if ($_ -match '^ +') {
                    $length = $indent * $nested
                    $line = ' ' * $length + $_.TrimStart()

                    # Determine the nesting of the next line
                    if ($_ -match '^*[\{|\[]$') {
                        $nested++
                    } elseif ($_ -match '^*[\}|\]]$') {
                        $nested--
                    }

                }
                Write-Output $line
            }
        ) -join "`r`n"
    }
}

function Convert-MultilineToSingleLine {
    Param(
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)]
        [string]$multilineString,
        [switch]$nixEnd = $False
    )
    begin {
        $fullPipeline = ""
        $linebreak = "\r\n"
        if ($nixEnd) {
            $linebreak = "\n"
        }
    }
    process { $fullPipeline += $multilineString + $linebreak }
    end { $fullPipeline }
}

function time {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$command,
        [switch]$quiet = $false
    )
    $start = Get-Date
    try {
        if ( -not $quiet ) {
            iex $command | Write-Host
        } else {
            iex $command | Out-Null
        }
    } finally {
        $(Get-Date) - $start
    }
}

Function Write-FileWithoutBom {
    Param(
        [Parameter(Mandatory = $true)]
        [string]$Content,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    $UTF8EncodingNoBom = New-Object System.Text.UTF8Encoding( $False )
    [System.IO.File]::WriteAllText( $Path, $Content, $UTF8EncodingNoBom )
}

Function Get-PSBoundKeys {
    Get-PSReadLineHandler | Where-Object Key -ne unbound
}

# Set up a simple prompt, adding the git prompt parts inside git repos
function global:prompt {
    $realLASTEXITCODE = $LASTEXITCODE

    Write-Host -NoNewLine -ForegroundColor "green" "${env:UserName}@${env:ComputerName} "

    # Do the newline because why waste the input linespace?
    Write-Host $pwd.ProviderPath.Replace( $env:UserProfile, '~' )
    Write-VcsStatus

    if ( $realLASTEXITCODE -ne 0 ) {
      Write-Host -NoNewLine -BackgroundColor "red" $realLASTEXITCODE
    }
    $global:LASTEXITCODE = $realLASTEXITCODE
    return "> "
}

# Get-ChildItem-Color: https://github.com/joonro/Get-ChildItem-Color
function Get-ChildItem-Color {
  if ( $pwd.Provider.Name -eq 'filesystem' ) {
    if ($Args[0] -eq $true) {
        $ifwide = $true

        if ($Args.Length -gt 1) {
            $Args = $Args[1..($Args.length - 1)]
        } else {
            $Args = @()
        }
    } else {
        $ifwide = $false
    }

    if (($Args[0] -eq "-a") -or ($Args[0] -eq "--all")) {
        $Args[0] = "-Force"
    }

    $width =  $host.UI.RawUI.WindowSize.Width

    $items = Invoke-Expression "Get-ChildItem `"$Args`"";
    $lnStr = $items | select-object Name | sort-object { "$_".length } -descending | select-object -first 1
    $len = $lnStr.name.length
    $cols = If ($len) {($width+1)/($len+2)} Else {1};
    $cols = [math]::floor($cols);
    if(!$cols){ $cols=1;}

    $color_fore = $Host.UI.RawUI.ForegroundColor

    $compressed_list = @(".7z", ".gz", ".rar", ".tar", ".zip")
    $executable_list = @(".exe", ".bat", ".cmd", ".py", ".pl", ".ps1",
                         ".psm1", ".vbs", ".rb", ".reg", ".fsx")
    $dll_pdb_list = @(".dll", ".pdb")
    $text_files_list = @(".csv", ".lg", "markdown", ".rst", ".txt")
    $configs_list = @(".cfg", ".config", ".conf", ".ini")

    $color_table = @{}
    foreach ($Extension in $compressed_list) {
        $color_table[$Extension] = "Yellow"
    }

    foreach ($Extension in $executable_list) {
        $color_table[$Extension] = "Blue"
    }

    foreach ($Extension in $text_files_list) {
        $color_table[$Extension] = "Cyan"
    }

    foreach ($Extension in $dll_pdb_list) {
        $color_table[$Extension] = "Darkgreen"
    }

    foreach ($Extension in $configs_list) {
        $color_table[$Extension] = "DarkYellow"
    }

    $i = 0
    $pad = [math]::ceiling(($width+2) / $cols) - 3
    $nnl = $false

    $items |
    %{
        if ($_.GetType().Name -eq 'DirectoryInfo') {
            $c = 'Green'
            $length = ""
        } else {
            $c = $color_table[$_.Extension]

            if ($c -eq $none) {
                $c = $color_fore
            }

            $length = $_.length
        }

        # get the directory name
        if ($_.GetType().Name -eq "FileInfo") {
            $DirectoryName = $_.DirectoryName
        } elseif ($_.GetType().Name -eq "DirectoryInfo") {
            $DirectoryName = $_.Parent.FullName
        }

        if ($ifwide) {  # Wide (ls)
            if ($LastDirectoryName -ne $DirectoryName) {  # change this to `$LastDirectoryName -ne $DirectoryName` to show DirectoryName
                if($i -ne 0 -AND $host.ui.rawui.CursorPosition.X -ne 0){ # conditionally add an empty line
                    write-host ""
                }
                Write-Host -Fore $color_fore ("`n   Directory: $DirectoryName`n")
            }

            $nnl = ++$i % $cols -ne 0

            # truncate the item name
            $towrite = $_.Name
            if ($towrite.length -gt $pad) {
                $towrite = $towrite.Substring(0, $pad - 3) + "..."
            }

            Write-Host ("{0,-$pad}" -f $towrite) -Fore $c -NoNewLine:$nnl
            if($nnl){
                write-host "  " -NoNewLine
            }
        } else {
            If ($LastDirectoryName -ne $DirectoryName) {  # first item - print out the header
                Write-Host "`n    Directory: $DirectoryName`n"
                Write-Host "Mode                LastWriteTime     Length Name"
                Write-Host "----                -------------     ------ ----"
            }
            $Host.UI.RawUI.ForegroundColor = $c

            Write-Host ("{0,-7} {1,25} {2,10} {3}" -f $_.mode,
                        ([String]::Format("{0,10}  {1,8}",
                                          $_.LastWriteTime.ToString("d"),
                                          $_.LastWriteTime.ToString("t"))),
                        $length, $_.name)

            $Host.UI.RawUI.ForegroundColor = $color_fore

            ++$i  # increase the counter
        }
        $LastDirectoryName = $DirectoryName
    }

    if ($nnl) {  # conditionally add an empty line
        Write-Host ""
    }
  } else {
    Get-ChildItem $Args
  }
}

function Get-ChildItem-Format-Wide {
    $New_Args = @($true)
    $New_Args += "$Args"
    Invoke-Expression "Get-ChildItem-Color $New_Args"
}
# End Get-ChildItem-Color

# Set project dir
$projectsdir = '\Projects'

# Set chefdk gem path
$env:PATH += ';C:\Users\localuser\AppData\Local\chefdk\gem\ruby\2.1.0\bin'

# GnuWin32 utils
$env:PATH += ";${env:ProgramFiles(x86)}\GnuWin32\bin"

# Chocolatey Test Package Dir
$chocoTestPackageDir = 'C:\Projects\chocolatepackages\chocolatey-test-environment\packages'

# Aliases
if ( (Get-Command curl).Name.ToLower().Contains('curl.exe') ) {
    Remove-Item alias:curl
}

function git-status { git status $args }
Set-Alias g git-status

Set-Alias cd pushd -Option AllScope
Set-Alias pd popd

function emacs-nw { emacs -nw $args }
Set-Alias e emacs-nw

function choco-search { choco search $args }
Set-Alias csearch choco-search

Set-Alias dir Get-ChildItem-Color -Option AllScope
Set-Alias ls Get-ChildItem-Color -Option AllScope
