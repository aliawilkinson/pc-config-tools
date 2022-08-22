#requires -RunAsAdministrator
<#
    .Synopsis
        Fast initial setup of a DevOps laptop for use with the dotnet and Azure stacks
    .Description
        Installs integral and nice to have tools on a windows workstation 64x. 
        This script must be run from an elevated shell

    .EXAMPLE
        & .\projects\initialize-windows-pc.ps1
    
    .Example
        initialize-windows-pc -Insiders -ShareX

        Chooses to install and configure the "Insiders Edition" of Visual Studio Code
        Also installs ShareX rather than the default Greenshot
#>
[CmdletBinding()]
param(
    # Install ShareX rather than Greenshot
    [switch]
    $ShareX,

    # Install VS Code Insiders edition
    [switch]
    $Insiders,

    # Install Fira Code instead of Cascadia Code
    [switch]
    $Firacode
)
# This parameter handling is so we can use the script as a script
# ... and also as a ChocolateyInstall.ps1 in the DevOpsBox package
if (Get-Command Get-PackageParameters -ErrorAction SilentlyContinue)
{
    $parameters = Get-PackageParameters
    if ($parameters.Contains("ShareX")) {
        $ShareX = $parameters["ShareX"]
    }
    if ($parameters.Contains("Insiders")) {
        $Insiders = $parameters["Insiders"]
    }
    if ($parameters.Contains("Firacode")) {
        $Firacode = $parameters["Firacode"]
    }
}

# Change your execution policy to Bypass
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine
# Turn on remoting
Enable-PSRemoting -Verbose -Force
# Set trusted hosts
Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value * -Verbose -Force

# Ensure the PowerShell DevOpsPowerShell source
Install-PackageProvider NuGet -MinimumVersion 2.8.5.208 -ForceBootstrap
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
# $name = "DevOpsPowerShell"
# $location = "https://nuget.loandepot.com/nuget/PowerShell"
# Register-PackageSource -Name $name -Location $location -Trusted -Force -ForceBootstrap -ProviderName PowerShellGet
Register-PackageSource -Name MyNuGet -Location https://www.nuget.org/api/v2 -ProviderName PowerShellGet

Write-Verbose -Verbose "  Updating PackageManagement"
Install-Module -Repository DevOpsPowerShell -Name PackageManagement -Force -Scope AllUsers -AllowClobber -SkipPublisherCheck
Write-Verbose -Verbose "  Updating PowerShellGet"
Install-Module -Repository DevOpsPowerShell -Name PowerShellGet -Force -Scope AllUsers -AllowClobber -SkipPublisherCheck


# Now install the basic apps
choco upgrade -y nuget.commandline
choco upgrade -y 7zip.install
choco upgrade -y arsclip # OR: ditto
choco upgrade -y keepass.install
if ($Sharex)
{
    choco upgrade -y sharex
}
else
{
    choco upgrade -y greenshot
}
choco upgrade -y microsoft-windows-terminal
choco upgrade -y git.install --package-parameters="'/GitOnlyOnPath /WindowsTerminal /NoShellIntegration /SChannel'"
if ($Insiders)
{
    choco upgrade -y vscode-insiders
}
else
{
    choco upgrade -y vscode
}
choco upgrade -y ssms
choco upgrade -y terraform --version 1.2.7
choco upgrade -y terragrunt --version 0.38.0
choco upgrade -y tflint
# PowerShell v7 (because )
choco upgrade -y pwsh

# ActiveDirectory RSAT tools
choco upgrade -y rsat -params "/AD /DNS"

# You need a good coding font like Cascadia or Fira Code. Get the nerdfont versions
if ($firacode)
{
    choco upgrade -y firacodenf
}
else
{
    choco upgrade -y cascadia-code-nerd-font
}

# Configure nuget sources
@{
    PublicNuget      = "https://api.nuget.org/v3"
}.GetEnumerator().ForEach({
    nuget source add -Name $_.Key -Source $_.Value
})

# Configure git
git config --global push.default current
if ($Insiders)
{
    git config --global core.editor "code-insiders --wait"
}
else
{
    git config --global core.editor "code --wait"
}

# Configure VSCode
@(
    "ms-azuretools.vscode-docker"
    "ms-vscode.powershell-preview" # or "ms-vscode.PowerShell"
    "ms-vscode.azurecli"
    "ms-azure-devops.azure-pipelines"
    "aaron-bond.better-comments"
    "coenraads.bracket-pair-colorizer-2"
    "vsls-contrib.codetour"
    "editorconfig.editorconfig"
    "wengerk.highlight-bad-chars"
    "oderwat.indent-rainbow"
    "ms-vsliveshare.vsliveshare"
).ForEach({
    if ($Insiders)
    {
        code-insiders --install-extension $_
    }
    else
    {
        code --install-extension $_
    }
})

# Make/update a profile for VSCode
$VSCProfile = $profile.CurrentUserAllHosts |
    Split-Path |
    Join-Path -Child Microsoft.VSCode_profile.ps1



