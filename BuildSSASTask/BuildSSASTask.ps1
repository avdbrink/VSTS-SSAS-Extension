#
# CompileSSASTask.ps1
#
[CmdletBinding(DefaultParameterSetName = 'None')]
param(
[string]$workingFolder = $env:BUILD_SOURCESDIRECTORY
)

Write-host ("==============================================================================")

Write-Host "Starting BuildSSASTask"
Trace-VstsEnteringInvocation $MyInvocation

#Project Group
$projPath            = Get-VstsInput -Name projPath -Require
$projCmdSwitch       = Get-VstsInput -Name projCmdSwitch -Require
$projConfigName      = Get-VstsInput -Name projConfigName -Require
$projPlatformName    = Get-VstsInput -name projPlatformName -Require
$devenv              = Get-VstsInput -name devenvPath -Require

Write-host ("==============================================================================")
#Format/Initialise Values

if (!(Test-Path($devenv))) {
	Write-Host "##vso[task.logissue type=error;]Cannot access devenv."
} else {
    Write-Host ("Devenv executable found: $devenv")
}

Write-Host ("Working Directory: $workingFolder")
cd $workingFolder

#Test Project path
if(!(Test-Path $projPath))
{
	Write-Host "##vso[task.logissue type=error;]Cannot access Project file path: $projPath"
} else {
	Write-Host ("Project file path: $projPath")
    $Folder = Split-Path -Path $projPath
    $BuildPlatform = $projPlatformName
    $BuildConfiguration = $projConfigName
}

Write-Host ("Building project")
$ArgumentList = "`"$projPath`" /build"
try {
    Start-Process $devenv $ArgumentList -NoNewWindow -PassThru -Wait -Verbose -RedirectStandardError $true
} catch {
    Write-Host ("##vso[task.logissue type=error;]Task_InternalError "+ $_.Exception.Message)
} finally {
    $outputFile = Get-ChildItem $_.Directory -Recurse -Filter "*.asdatabase"
    if (!$outputFile)
    {
        Write-Host "##vso[task.logissue type=error;]Test Output: No .asdatabase file found in " + $_.Directory
        Write-Host "##vso[task.complete result=Failed;]"
    }
}


Trace-VstsLeavingInvocation $MyInvocation


Write-Host "Ending BuildSSASTask"
