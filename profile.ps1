
# psreadline txt console history
# C:\Users\awilkinson\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt

# works with powershell 5 and 7
$env:psmodulepath += ';C:\Users\awilkinson\Documents\WindowsPowerShell\Modules'
Import-Module EditorServicesCommandSuite, Posh-Git
if ($host.name -like "Visual*") { Import-EditorCommand -Module EditorServicesCommandSuite }

function gclean {
    git checkout master
    $mergedBranches = git branch --merged | where-object { $_ -notmatch "\*|master" } 
    Write-Host "Localy merged branches`n$($mergedBranches -join ', ')"
    $mergedBranches | % { git branch -d $_.trim() }
    Write-Host "Remote branches pruned"
    git remote prune origin
}  

function CleanGitBranches {
    $br = git branch | Where-Object { $_ -notlike "*master*" -and $_ -notlike "*main*"}
    $br | ForEach-Object { git branch -d $_.trim() }
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
    if ($global:azcontext) {$global:azcontext}
    else {        
        $context =(Get-AzContext).Subscription.Name 
        (Set-Variable -Scope Global -Name AzContext -Value $context -PassThru).Value
    }
}
New-Alias -Name 'sclip' -Value Set-Clipboard -force