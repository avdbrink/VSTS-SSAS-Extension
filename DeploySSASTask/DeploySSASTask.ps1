#
# DeploySSASTask.ps1
#
[CmdletBinding(DefaultParameterSetName = 'None')]
param()
Trace-VstsEnteringInvocation $MyInvocation

# Test-XMLFile function by Jonathan Medd
# https://www.jonathanmedd.net/2012/05/quick-and-easy-powershell-test-xmlfile.html
function Test-XMLFile {
	<#
	.SYNOPSIS
	Test the validity of an XML file
	#>
	[CmdletBinding()]
	param (
		[parameter(mandatory=$true)][ValidateNotNullorEmpty()][string]$xmlFilePath
	)

	# Check the file exists
	if (!(Test-Path -Path $xmlFilePath)){
		throw "$xmlFilePath is not valid. Please provide a valid path to the .xml fileh"
	}
	# Check for Load or Parse errors when loading the XML file
	$xml = New-Object System.Xml.XmlDocument
	try {
		$xml.Load((Get-ChildItem -Path $xmlFilePath).FullName)
		return $true
	}
	catch [System.Xml.XmlException] {
		Write-Verbose "$xmlFilePath : $($_.toString())"
		return $false
	}
}

try {
    # Import the localized strings.
    Import-VstsLocStrings "$PSScriptRoot\Task.json"

    Write-host ("==============================================================================")
	Write-Host (Get-VstsLocString -Key StartingTask)

    $AsDBFilePath = Get-VstsInput -Name AsDBFilePath -Require
    $ServerName = Get-VstsInput -Name ServerName -Require
    $DatabaseName = Get-VstsInput -Name DatabaseName -Require

	#Advanced group
	$TransactionalDeployment = Get-VstsInput -Name TransactionalDeployment -Require
	$PartitionDeployment = Get-VstsInput -Name PartitionDeployment -Require
	$RoleDeployment = Get-VstsInput -Name RoleDeployment -Require
	$ProcessingOption = Get-VstsInput -Name ProcessingOption -Require
	$ConfigurationSettingsDeployment = Get-VstsInput -Name ConfigurationSettingsDeployment -Require
	$OptimizationSettingsDeployment = Get-VstsInput -Name OptimizationSettingsDeployment -Require
	$WriteBackTableCreation = Get-VstsInput -Name WriteBackTableCreation -Require
	$mgmtVersion = Get-VstsInput -Name mgmtVersion -Require
	$customMGMTVersion = Get-VstsInput -Name customMGMTVersion
	$ImpersonationInformation = Get-VstsInput -Name ImpersonationInformation -Require
	$ServiceAccountName = Get-VstsInput -Name ServiceAccountName
	$ServiceAccountPassword = Get-VstsInput -Name ServiceAccountPassword
	
	
	if (!(Test-Path $AsDBFilePath)) {
		Write-Error (Get-VstsLocString -Key AsDBFile0AccessDenied -ArgumentList $AsDBFilePath)
	} else {
		Write-Host (Get-VstsLocString -Key AsDBFile0 -ArgumentList $AsDBFilePath)
	}

	switch ($mgmtVersion) 
	{ 
		2012 {$compiler = "C:\Program Files (x86)\Microsoft SQL Server\110\Tools\Binn\ManagementStudio\Microsoft.AnalysisServices.Deployment.exe"} 
		2014 {$compiler = "C:\Program Files (x86)\Microsoft SQL Server\120\Tools\Binn\ManagementStudio\Microsoft.AnalysisServices.Deployment.exe"}
		2016 {$compiler = "C:\Program Files (x86)\Microsoft SQL Server\130\Tools\Binn\ManagementStudio\Microsoft.AnalysisServices.Deployment.exe"}
		2017 {$compiler = "C:\Program Files (x86)\Microsoft SQL Server\140\Tools\Binn\ManagementStudio\Microsoft.AnalysisServices.Deployment.exe"}
		"auto" {
			if (Test-Path("C:\Program Files (x86)\Microsoft SQL Server\140\Tools\Binn\ManagementStudio\Microsoft.AnalysisServices.Deployment.exe")) { $compiler = "C:\Program Files (x86)\Microsoft SQL Server\140\Tools\Binn\ManagementStudio\Microsoft.AnalysisServices.Deployment.exe"}
			if (Test-Path("C:\Program Files (x86)\Microsoft SQL Server\130\Tools\Binn\ManagementStudio\Microsoft.AnalysisServices.Deployment.exe")) { $compiler = "C:\Program Files (x86)\Microsoft SQL Server\130\Tools\Binn\ManagementStudio\Microsoft.AnalysisServices.Deployment.exe"}
			if (Test-Path("C:\Program Files (x86)\Microsoft SQL Server\120\Tools\Binn\ManagementStudio\Microsoft.AnalysisServices.Deployment.exe")) { $compiler = "C:\Program Files (x86)\Microsoft SQL Server\120\Tools\Binn\ManagementStudio\Microsoft.AnalysisServices.Deployment.exe"}
			if (Test-Path("C:\Program Files (x86)\Microsoft SQL Server\110\Tools\Binn\ManagementStudio\Microsoft.AnalysisServices.Deployment.exe")) { $compiler = "C:\Program Files (x86)\Microsoft SQL Server\110\Tools\Binn\ManagementStudio\Microsoft.AnalysisServices.Deployment.exe"}
		}
		"custom" {
			if (Test-Path($customMGMTVersion)) { 
				if ($customMGMTVersion.EndsWith(".exe","CurrentCultureIgnoreCase")) {
					$compiler = $customMGMTVersion
				} else {
					if (!$customMGMTVersion.EndsWith('\')) {
						$customMGMTVersion = $customMGMTVersion + '\'
					}
					$compiler = $customMGMTVersion + "Microsoft.AnalysisServices.Deployment.exe"
				}
			}
		}
	}
	try {
		if (!(Test-Path($compiler))) {
			if ($mgmtVersion -eq "custom") {
				Write-Host "##vso[task.logissue type=error;] Cannot access compiler. Selected version: $mgmtVersion : $customMGMTVersion" 
			} else {
				Write-Host "##vso[task.logissue type=error;] Cannot access compiler. Selected version: $mgmtVersion"
			}
			Exit 1
		} else {
    	Write-Host (Get-VstsLocString -key DeploymentExecutable0 -ArgumentList $compiler)
    }
	}
	catch {
		Write-Error (Get-VstsLocString -key CompilerNotFound)
		Exit 1
	}

  if (Get-Module -ListAvailable -Name SqlServer) {
		if (-not (Get-Module -Name "SqlServer")) {
      # if module is not loaded
      Import-Module "SqlServer" -DisableNameChecking
    }
  } else {
    Write-Host "##vso[task.logissue type=error;]SqlServer Powershell module not installed"
  }

	if([System.Convert]::ToBoolean($ConfigurationSettingsDeployment)) {		
		$ConfigurationSettingsDeployment = "Retain"
	} else {
		$ConfigurationSettingsDeployment = "Deploy"
	}
	if([System.Convert]::ToBoolean($OptimizationSettingsDeployment)) {		
		$OptimizationSettingsDeployment = "Retain"
	} else {
		$OptimizationSettingsDeployment = "Deploy"
	}

	$path = Split-Path -Path $AsDBFilePath
	$modelName = [io.path]::GetFileNameWithoutExtension($AsDBFilePath)

	$DeploymentOptions = "$path\$modelName.deploymentoptions"
	$DeploymentTargets = "$path\$modelName.deploymenttargets"

	$SsasDBconnection = "DataSource=$ServerName;Timeout=0"

	[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices") | Out-Null;
	$server = New-Object Microsoft.AnalysisServices.Server
	$server.connect("$ServerName")
	if ($server.Connected -eq $false) {
		Write-Error (Get-VstsLocString -Key Server0AccessDenied -ArgumentList $ServerName)
		Exit 1
	}

	# Edit DeploymentTargets file
	$xml = [xml](Get-Content $DeploymentTargets)
	$xml.Data.Course.Subject
	$node = $xml.DeploymentTarget
	$node.Database = $DatabaseName
	$node = $xml.DeploymentTarget
	$node.Server = $ServerName
	$node = $xml.DeploymentTarget
	$node.ConnectionString = $SsasDBconnection
	$xml.Save($DeploymentTargets)
	# End Edit DeploymentTargets file

	# Edit DeploymentOptions file
	$xml = [xml](Get-Content $DeploymentOptions)
	$xml.Data.Course.Subject
	$node = $xml.DeploymentOptions
	$node.ProcessingOption = "DoNotProcess" # Never use anything else or it will break. Porcessing is handled after deployment 
	$node.TransactionalDeployment = $TransactionalDeployment
	$node.PartitionDeployment = $PartitionDeployment
	$node.RoleDeployment = $RoleDeployment
	$node.ConfigurationSettingsDeployment = $ConfigurationSettingsDeployment
	$node.OptimizationSettingsDeployment = $OptimizationSettingsDeployment
	$node.WriteBackTableCreation = $WriteBackTableCreation
	$xml.Save($DeploymentOptions)
	# End Edit DeploymentOptions file

	# Edit impersonation settings
	switch ($ImpersonationInformation) {
		"UseASpecificWindowsUser" { 
			$NewImpersonationMode = "ImpersonateAccount"
			break 
		}
		"UseTheCredentialsOfTheCurrentUser" { 
			$NewImpersonationMode = "ImpersonateCurrentUser"
			break 
		}
		"Inherit" { 
			$NewImpersonationMode = "Default"
			break 
		}
		default {  # Default to "UseTheServiceAccount"
			$NewImpersonationMode = "ImpersonateServiceAccount"
			break 
		}
	}
	
	# Impersonation settings should only be  set if ImpersonationInformation <> None
	# Some users reported problems when deploying impersonation settings, so the option to skip it altogether 
	if ($ImpersonationInformation -ne "None") {
		# object structure for multidimensionals is slightly different from tabulars
		# Datasource of a multidimensional has an ImpersonationInfo object, where tabulars 
		# can have the impoersonation info written directly to the datasource object
		if ($server.ServerMode -eq "Multidimensional") {

			# First we find out if it's XML or JSON (SQL Compatability <= 1000 == XML; Compatability >= 1200 == JSON)
			if ((Test-XMLFile "$AsDBFilePath") -eq "True") {
				$xml = [xml](Get-Content $AsDBFilePath)
				$datasources = $xml.Database.DataSources
				foreach ($datasource in $datasources.ChildNodes) {
					Write-Host("[XML] Changing impersonation info from " + $datasource.ImpersonationInfo.ImpersonationMode + " to " + $NewImpersonationMode + " on datasource " + $datasource.Name)
					$datasource.ImpersonationInfo.ImpersonationMode = $NewImpersonationMode
					if ($NewImpersonationMode -eq "ImpersonateAccount") {
						$datasource.ImpersonationInfo.Account = $ServiceAccountName
						$datasource.ImpersonationInfo.Password = $ServiceAccountPassword
					}
				}
				$xml.Save($AsDBFilePath)
			} else {
				# Assume it's JSON if Test-XMLFile returned false
				$model = [IO.File]::ReadAllText($AsDBFilePath)
				$db = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::DeserializeDatabase($model)
				foreach ($datasource in $db.Model.Model.DataSources) {
					Write-Host("[JSON] Changing impersonation info from " + $datasource.ImpersonationInfo.ImpersonationMode + " to " + $NewImpersonationMode + " on datasource " + $datasource.Name)
					$datasource.ImpersonationInfo.ImpersonationMode = $NewImpersonationMode
					if ($NewImpersonationMode -eq "ImpersonateAccount") {
						$datasource.ImpersonationInfo.Account = $ServiceAccountName
						$datasource.ImpersonationInfo.Password = $ServiceAccountPassword
					} else {
						$datasource.ImpersonationInfo.Account = ""
						$datasource.ImpersonationInfo.Password = ""
					}
				}
				[Microsoft.AnalysisServices.Tabular.JsonSerializer]::SerializeDatabase($db) | Set-Content $AsDBFilePath -Encoding UTF8
			}
			write-host "Impersonation information is changed on the Multidimensional Server"
		}
		else {
		  
			# First we find out if it's XML or JSON (SQL Compatability <= 1000 == XML; Compatability >= 1200 == JSON)
			if ((Test-XMLFile "$AsDBFilePath") -eq "True") {
				$xml = [xml](Get-Content $AsDBFilePath)
				$datasources = $xml.Database.DataSources
				foreach ($datasource in $datasources.ChildNodes) {
					Write-Host("[XML] Changing impersonation info from " + $datasource.ImpersonationMode + " to " + $NewImpersonationMode + " on datasource " + $datasource.Name)
					$datasource.ImpersonationMode = $NewImpersonationMode
					if ($NewImpersonationMode -eq "ImpersonateAccount") {
						$datasource.Account = $ServiceAccountName
						$datasource.Password = $ServiceAccountPassword
					}
				}
				$xml.Save($AsDBFilePath)
			} else {
				# Assume it's JSON if Test-XMLFile returned false
				$model = [IO.File]::ReadAllText($AsDBFilePath)
				$db = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::DeserializeDatabase($model)
				foreach ($datasource in $db.Model.Model.DataSources) {
					Write-Host("[JSON] Changing impersonation info from " + $datasource.ImpersonationMode + " to " + $NewImpersonationMode + " on datasource " + $datasource.Name)
					$datasource.ImpersonationMode = $NewImpersonationMode
					if ($NewImpersonationMode -eq "ImpersonateAccount") {
						$datasource.Account = $ServiceAccountName
						$datasource.Password = $ServiceAccountPassword
					} else {
						$datasource.Account = ""
						$datasource.Password = ""
					}
				}
				[Microsoft.AnalysisServices.Tabular.JsonSerializer]::SerializeDatabase($db) | Set-Content $AsDBFilePath -Encoding UTF8
			}
			write-host "Impersonation information is changed on the Tabular server"

		}
	}
	# End Edit impersonation settings
	
	
	Write-Host (Get-VstsLocString -Key CreatingXmlFromAsDatabase )
	& $compiler $AsDBFilePath /s:$path\ScriptLog.txt /o:$path\$modelName.xmla
	
	$log = Get-Content $path\ScriptLog.txt
	foreach ($line in $log) {
	    Write-Host $line
	}
	
    Write-Host (Get-VstsLocString -Key DeployingDatabase0 -ArgumentList $Database)
	Invoke-ASCmd -InputFile $path\$modelName.xmla -Server $ServerName | Out-File $path\Result.xml
	$xml = [xml](Get-Content $path\Result.xml)
	if ($xml.return.root.Messages.Error) {
		$xml.return.root.Messages.Error | % { Write-Host ($_.ErrorCode + ": " + $_.Description) }
		Write-Error (Get-VstsLocString -key ErrorDuringDeployment)
	}
	
	if ($ProcessingOption -ne "DoNotProcess") {
		Write-Host (Get-VstsLocString -Key ProcessingDatabase0 -ArgumentList $ProcessingOption)

		# Determine the desired processing option and translate to the correct command for the json we're going to generate
		if ($ProcessingOption -eq "Full") {
			$type = "full"
		} else {
			$type = "automatic"
		}
		# Create a JSON  file containing the processing command
		$fileContent = @"
{
  "refresh": {
    "type": "$type",
    "objects": [
      {
        "database": "$DatabaseName"
      }
    ]
  }
}
"@
		Set-Content -Path $path\processing.json -Value ($fileContent)
		Invoke-ASCmd -InputFile $path\processing.json -Server $ServerName | Out-File $path\ProcessingResult.xml
		$xml = [xml](Get-Content $path\ProcessingResult.xml)
		if ($xml.return.root.Messages.Error) {
			$xml.return.root.Messages.Error | % { Write-Host ($_.ErrorCode + ": " + $_.Description) }
			Write-Error (Get-VstsLocString -key ErrorDuringProcessing)
		}
	}

} catch {
    Write-Error (Get-VstsLocString -Key InternalError0 -ArgumentList $_.Exception.Message)
} finally {
	Trace-VstsLeavingInvocation $MyInvocation
}

Write-Host (Get-VstsLocString -Key EndingTask)
