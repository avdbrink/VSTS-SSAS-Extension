#
# DeploySSASTask.ps1
#
[CmdletBinding(DefaultParameterSetName = 'None')]
param()
Trace-VstsEnteringInvocation $MyInvocation

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
	}
	if (!(Test-Path($compiler))) {
		Write-Host "##vso[task.logissue type=error;]Cannot access compiler. Selected version: $mgmtVersion"
	} else {
    	Write-Host ("Deployment executable version: $compiler")
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
	$server.connect($ServerName)
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
	$node.ProcessingOption = $ProcessingOption
	$node.TransactionalDeployment = $TransactionalDeployment
	$node.PartitionDeployment = $PartitionDeployment
	$node.RoleDeployment = $RoleDeployment
	$node.ConfigurationSettingsDeployment = $ConfigurationSettingsDeployment
	$node.OptimizationSettingsDeployment = $OptimizationSettingsDeployment
	$node.WriteBackTableCreation = $WriteBackTableCreation
	$xml.Save($DeploymentOptions)
	# End Edit DeploymentOptions file

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
	else {
		# No errors so far
		# Start updating impersonation information
		[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices") >$NULL
		$server = New-Object Microsoft.AnalysisServices.Server
		$server.connect("$($ServerName)")
		$Database = $server.Databases.item("$($DatabaseName)")
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

		# object structure for multidimensionals is slightly different from tabulars
		# Datasource of a multidimensional has an ImpersonationInfo object, where tabulars 
		# can have the impoersonation info written directly to the datasource object
		if ($server.ServerMode -eq "Multidimensional") {

			$ds = $Database.DataSources
			foreach($_ in $ds)	{ 
				Write-Host("Changing impersonation info from " + $_.ImpersonationInfo.ImpersonationMode + " to " + $NewImpersonationMode + " on datasource " + $_.Name)
				$_.ImpersonationInfo.ImpersonationMode = $NewImpersonationMode
				if ($NewImpersonationMode -eq "ImpersonateAccount") {
					$_.ImpersonationInfo.Account = $ServiceAccountName
					$_.ImpersonationInfo.Password = $ServiceAccountPassword
				}
			}
			$ds.update()
			write-host "Impersonation information is changed on the Multidimensional Server"
		}
		else {
		  
			$ds = New-Object Microsoft.AnalysisServices.Tabular.ProviderDataSource
			$ds = $Database.model

			foreach($_ in $ds.Model.DataSources) {
				Write-Host("Changing impersonation info from " + $_.ImpersonationMode + " to " + $NewImpersonationMode + " on datasource " + $_.Name)
				$_.ImpersonationMode = $NewImpersonationMode
				if ($NewImpersonationMode -eq "ImpersonateAccount") {
					$_.Account = $ServiceAccountName
					$_.Password = $ServiceAccountPassword
				}
			}
			$ds.Model.SaveChanges()
			write-host "Impersonation information is changed on the Tabular server"

		}
	}



} catch {
    Write-Error (Get-VstsLocString -Key InternalError0 -ArgumentList $_.Exception.Message)
} finally {
	Trace-VstsLeavingInvocation $MyInvocation
}

Write-Host (Get-VstsLocString -Key EndingTask)
