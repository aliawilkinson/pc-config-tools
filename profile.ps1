
# Joel magic to un-bork
function Set-BorkedPath {
    [CmdletBinding()]
    param(
        # Cache file for the calculated PSModulePath (e.g. $Profile.PSModulePath.env)
        $PSModulePathFile = [IO.Path]::ChangeExtension($Profile, ".PSModulePath.env"),

        # Cache file for the calculated Path (e.g. $Profile.Path.env)
        $PathFile = [IO.Path]::ChangeExtension($Profile, ".Path.env"),

        # Root for "this" version of PowerShell
        $ProfileDir = [IO.Path]::GetDirectoryName($Profile.CurrentUserAllHosts),

        # Determine whether the provider is case insensitive (calculated automatically)
        [switch]$CaseInsensitive = $($false -notin (Test-Path $ProfileDir.ToLowerInvariant(), $ProfileDir.ToUpperInvariant()))
    )

    function Select-UniquePath {
        #
        #    .SYNOPSIS
        #        Select-UniquePath normalizes path variables and ensures only folders that actually currently exist are in them.
        #    .EXAMPLE
        #        $ENV:PATH = $ENV:PATH | Select-UniquePath
        #
        #        Shows how to deduplicate
        #    .EXAMPLE
        #        $ENV:PSModulePath | Select-UniquePath -PathName ENV:PSModulePath -RemoveNonexistent
        [CmdletBinding()]
        param(
            # Paths to folders
            [Parameter(Position = 1, Mandatory, ValueFromRemainingArguments, ValueFromPipeline, ValueFromPipelineByPropertyName)]
            [AllowEmptyCollection()]
            [AllowEmptyString()]
            [string[]]$Path,

            # PowerShell Paths which will will be Set-Content with the array
            [string[]]$OutPathNameAsArray,

            # PowerShell Paths which will will be Set-Content with the $Delimiter joined string
            [string[]]$OutPathName,

            # Force passing through output even when ArrayContentPaths or JoinContentPaths are specified
            [switch]$Passthru,

            # The Path value is split by the delimiter. Defaults to '[IO.Path]::PathSeparator' so you can use this on $Env:Path
            [Parameter(Mandatory = $False)]
            [AllowNull()]
            [string]$Delimiter = [IO.Path]::PathSeparator,

            # Root for "this" version of PowerShell (calculated automatically)
            $ProfileDir = [IO.Path]::GetDirectoryName($Profile),

            # Determine whether the provider is case insensitive (calculated automatically)
            [switch]$CaseInsensitive = $($false -notin (Test-Path $ProfileDir.ToLowerInvariant(), $ProfileDir.ToUpperInvariant())),

            [switch]$RemoveNonExistent
        )
        begin {
            # Write-Information "Select-UniquePath ENTER BEGIN $fg:red$Delimiter$fg:clear $Path" -Tags "Trace", "Enter", "Begin"
            # [string[]]$oldFolders = @()
            [System.Collections.Generic.List[string]]$inputPaths = @()

            # Write-Information "Select-UniquePath EXIT BEGIN $fg:red$Delimiter$fg:clear $Path" -Tags "Trace", "Exit", "Begin"
        }
        process {
            # Write-Information "Select-UniquePath ENTER PROCESS $fg:cyan$Path$fg:clear" -Tags "Trace", "Enter", "Process"
            # Split and trim trailing slashes to normalize, and drop empty strings
            $inputPaths.AddRange([string[]]($Path.Split($Delimiter).TrimEnd('\/').Where{ $_ -gt "" }))
            # Write-Information "Select-UniquePath EXIT PROCESS $fg:cyan$Path$fg:clear" -Tags "Trace", "Exit", "Process"
        }
        end {
            # Correct the case of all paths in PATH, even on Windows.
            [string[]]$outputPaths =
            if ($CaseInsensitive -or $RemoveNonExistent) {
                @(
                    if ($CaseInsensitive) {
                        # Using wildcards on every folder forces Windows to calculate the ACTUAL case of the path
                        $inputPaths -replace '(?<!:|\\|/|\*)(\\|/|$)', '*$1'
                    }
                    else {
                        $inputPaths
                    }
                ) |
                # Because Convert-Path will not resolve hidden folders, like C:\ProgramData*\ ...
                # Use Get-Item -Force to ensure we don't loose hidden folders
                Get-Item -Force |
                # But make sure we didn't add anything that wasn't already there
                Where-Object { $_.FullName -iin $inputPaths } |
                ForEach-Object FullName
            }
            else {
                $inputPaths
            }

            if (!$outputPaths) {
                throw "No valid paths after filter. InputPaths: $($InputPaths -join "`n")"
            }

            [string[]]$Result = [System.Linq.Enumerable]::Distinct($outputPaths, [StringComparer]::OrdinalIgnoreCase)

            if ($OutPathNameAsArray) {
                # Write-Information "Set-Content $fg:green$OutPathNameAsArray${fg:clear}:`n$($Result -join "`n")" -Tags "Trace"
                Set-Content -Path $OutPathNameAsArray -Value $Result
            }
            if ($OutPathName) {
                # Write-Information "Set-Content $fg:green$OutPathName${fg:clear}: $Result" -Tags "Trace"
                Set-Content -Path $OutPathName -Value ($Result -join $Delimiter)
            }
            if ($Passthru -or -not ($OutPathNameAsArray -or $OutPathName)) {
                # Write-Information "${fg:Green}Passthru:$fg:clear $Result" -Tags "Trace"
                $Result
            }
            # Write-Information "Select-UniquePath $fg:red$Delimiter$fg:clear $($Result -join "$fg:red$Delimiter$fg:clear")" -Tags "Trace", "Exit"
        }
    }

    # NOTES:
    # 1. The main concern is to keep things in order:
    #     a. User path ($Home) before machine path ($PSHome)
    #     b. Existing PSModulePath before other versions
    #     c. current version before other versions
    # 2. I don't worry about duplicates because `Select-UniquePath` takes care of it
    # 3. I don't worry about missing paths, because `Select-UniquePath` takes care of it
    # 4. I don't worry about x86 because I never use it.
    # 5. I don't worry about linux because I add paths based on `$PSScriptRoot`, `$Profile` and `$PSHome`
    # The normal first location in PSModulePath is the "Modules" folder next to the real profile:
    @([IO.Path]::Combine($ProfileDir, "Modules")) +
    # After that, I guess we'll keep whatever is in the environment variable
    @($Env:PSModulePath) +
    # PSHome is where powershell.exe or pwsh.exe lives ... it should already be in the Env:PSModulePath, but just in case:
    @([IO.Path]::Combine($PSHome, "Modules")) +
    # FINALLY, add the Module paths for other PowerShell versions, because I'm an optimist
    @(Get-ChildItem ([IO.Path]::Combine([IO.Path]::GetDirectoryName([IO.Path]::GetDirectoryName($PSHome)), "*PowerShell")) -Filter Modules -Recurse -Depth 2).FullName +
    @(Convert-Path @(
            [IO.Path]::Combine([IO.Path]::GetDirectoryName($ProfileDir), "*PowerShell\Modules")
            # These may be duplicate or not exist, but it doesn't matter
            "$Env:ProgramFiles\*PowerShell\Modules"
            "$Env:ProgramFiles\*PowerShell\*\Modules"
            "$Env:SystemRoot\System32\*PowerShell\*\Modules"
        )) +
    # Guarantee my ~\Projects\Modules are there so I can load my dev projects
    @("$Home\Projects\Modules") +
    # Avoid duplicates and ensure canonical path case
    @() |
    Select-UniquePath -OutPathName Env:PSModulePath -OutPathNameAsArray $PSModulePathFile -CaseInsensitive:$CaseInsensitive -RemoveNonExistent

    # I want to make sure that THIS version's Scripts (and then other versions) path is in the PATH
    @($Env:Path) +
    @([IO.Path]::Combine($ProfileDir, "Scripts")) +
    @(Get-ChildItem ([IO.Path]::Combine([IO.Path]::GetDirectoryName($ProfileDir), "*PowerShell\*")) -Filter Scripts -Directory).FullName +
    # Avoid duplicates and ensure canonical path case
    @() | Select-UniquePath -OutPathName Env:Path -OutPathNameAsArray $PathFile -CaseInsensitive:$CaseInsensitive -RemoveNonExistent
}

Set-BorkedPath

# sets the path using the files create by the Set-BorkedModulePath func above
if (Test-Path ($PSModulePathPath = [IO.Path]::ChangeExtension($Profile, ".PSModulePath.env"))) {
    $Env:PSModulePath = @(Get-Content $PSModulePathPath) -join [IO.Path]::PathSeparator
}
if (Test-Path ($PathPath = [IO.Path]::ChangeExtension($Profile, ".Path.env"))) {
    $Env:Path = @(Get-Content $PathPath) -join [IO.Path]::PathSeparator
}


# psreadline txt console history
# C:\Users\awilkinson\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt

# works with powershell 5 and 7
$env:psmodulepath += ';C:\Users\awilkinson\Documents\WindowsPowerShell\Modules'
Import-Module Posh-Git, LDOther, LDUtility
if ($host.name -like "Visual*") { Import-EditorCommand -Module EditorServicesCommandSuite }
$deut = "C:\ldx\Deuterium"
$ldx = "C:\ldx"
$toolkit = 'C:\ldx\DevOpsScripts\Toolkit'
$dsc = 'S-LV8-DSC01.ld.corp.local'
$PSDefaultParameterValues["*:DeuteriumPath"] = "$deut"
# Gives you tab completion on -Component, -Environment, -Datacenter, -ComputerName, -Role parameters on all commands in the below modules.
# Beware the more modules you add to this list, the longer you powershell profile will take to set up.
Update-LDArgumentCompleter -ModuleName "LDXGet", "LDXSet", "LDNetworking", "LDF5", "LDServerManagement"
# You must regularly Update-LDModule...
# $Now = Get-Date
# $LDUtilityManifest = Get-Module -List LDUtility | Sort-Object Version | Select-Object -last 1 | Get-Item
# $Age = ($Now - $LDUtilityManifest.LastWriteTime).TotalHours
# if ($Age -gt 12) {
#     Update-LDModule -Verbose -Clean
#     $LDUtilityManifest.LastWriteTime = $Now
# }  

# adds autocomplete for pwsh 7
if ($PSVersionTable.PSVersion.Major -eq 7) {
    Set-PSReadLineOption -PredictionViewStyle ListView
}

if ($ENV:TERM_PROGRAM -ne "vscode") {
    # Write-Information "Detected not VS Code"

    $Now = Get-Date
    $LDUtilityManifest = Get-Module -List LDUtility | Get-Item | Select-Object -First 1
    $Age = ($Now - $LDUtilityManifest.LastWriteTime).TotalHours
    if ($Age -gt 12) {
        $LDUtilityManifest.LastWriteTime = $Now
        # Run this super frustrating update in a separate tab in windows terminal
        wt -w 0 --title "Update-LDModule" -p "PowerShell" pwsh -NonInteractive -Command Update-LDModule -Scope CurrentUser -Verbose 
    }
    <#
    As a developer, I have full admin rights on my laptop...
    But our IT department still deploys GPO's that break things from time to time.
    So for breaking policies that can be removed in the registry, I just fix it.
    The Microsoft\FVE policy breaks Docker: https://github.com/docker/for-win/issues/1297
    The Microsoft\Edge and Google\Chrome policies force startup options
    #>
    $Roots = @(
        "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        "HKLM:\SOFTWARE\Policies\Google\Chrome"
        "HKCU:\SOFTWARE\Policies\Microsoft\Edge"
        "HKCU:\SOFTWARE\Policies\Google\Chrome"
    )

    $Paths = $Roots | Where-Object { $_ | Test-Path }
    # If any of these policy folders exist, run PowerShell elevated to clean up
    if ($Paths) {
        Start-Process pwsh -Verb RunAs -ArgumentList "-NoProfile -NonInteractive -Command ""&{ Set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Policies\Microsoft\FVE FDVDenyWriteAccess 0; Remove-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Edge','HKCU:\SOFTWARE\Policies\Microsoft\Edge','HKLM:\SOFTWARE\Policies\Google\Chrome','HKCU:\SOFTWARE\Policies\Google\Chrome' -Recurse -ErrorAction SilentlyContinue }"""
    }

    # Corporate keeps pinning things. They obviously don't understand the meaning of "User Pinned"
    Get-ChildItem "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\Taskbar" |
        Where-Object { $_.BaseName -notin "KeePass 2", "File Explorer", "Microsoft Teams", "Visual Studio Code - Insiders", "Outlook" } |
        ForEach-Object {
            Start-Process -FilePath $_.FullName -Verb "taskbarunpin" -ErrorAction SilentlyContinue
        }
}

function gclean {
    git checkout main
    $mergedBranches = git branch --merged | where-object { $_ -notmatch "\*|main" } 
    Write-Host "Localy merged branches`n$($mergedBranches -join ', ')"
    $mergedBranches | ForEach-Object { git branch -d $_.trim() }
    Write-Host "Remote branches pruned"
    git remote prune origin
}  

function gcleanMaster {
    git checkout master
    $mergedBranches = git branch --merged | where-object { $_ -notmatch "\*|master" } 
    Write-Host "Localy merged branches`n$($mergedBranches -join ', ')"
    $mergedBranches | ForEach-Object { git branch -d $_.trim() }
    Write-Host "Remote branches pruned"
    git remote prune origin
}  

function gpullglobal {
    Push-Location $ldx
    $repos = (ls).fullname
    $repos | ForEach-Object { Set-Location $_; git pull}
    Pop-Location
}  


function ss {
    [CmdletBinding()]
    param (
        [parameter()]
        [validateNotNullOrEmpty()]
        [ValidateSet(
            'dvo-dv1',
            'inf-pd-01', 
            'inf-sl1',
            'dvo-qa1',
            'dvo-sg1',
            'dvo-rprd',                 
            'dvo-hf1',
            'crp-pd-SharedServices-01',
            'dvo-sl1',
            'thr-sb-01',
            'dvo-tn1',
            'dvo-sb-01',
            'dvo-dr-01'
        )]
        [string]
        $sub
    )
    (Select-AzSubscription "sb-azu-$sub").Subscription.Name
    Set-Variable -Scope Global -Name AzContext -Value "sb-azu-$sub"
}
function con {
    if ($global:azcontext) { $global:azcontext }
    else {        
        $context = (Get-AzContext).Subscription.Name 
        (Set-Variable -Scope Global -Name AzContext -Value $context -PassThru).Value
    }
}
New-Alias -Name 'sclip' -Value Set-Clipboard -force

