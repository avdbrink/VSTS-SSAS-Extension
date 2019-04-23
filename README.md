## Introduction
> VSTS Extension task to build and deploy Visual Studio Project - SQL Server Analysis Services Tabular and Multi Dimensional entities.

## Description
> A Visual Studio project, containing a tabular model or a multi dimensional cube, is deployed to a SQL Server Analysis Server Instance.
> Tabular Projects are build using the standard MSBuild component in TFS Build services. (Use Visual Studio Build task or MSBuild task)
> Multidimensional projects are build using the SSASBuild compontent from this package. This is because Multidimensional projects are not supported by msbuild
> For building multi dimensionals make sure you use a build agent that has Visual Studio with at least SSDT functionallity installed.
> The deploy component than takes the .asdatabase created by the build to deploy the model to the server
> [Build of Projects](https://docs.microsoft.com/en-us/sql/analysis-services/multidimensional-models/build-analysis-services-projects-ssdt)

### How to Setup build
> NOTE: Building is only for Multi dimensional cubes, not for Tabular models. Don't forget to read the last part of this step if you're building 
> a Tabular moel because you need the right file in your build artifact
> In the path to project file property make sure you specify the .dwproj file or a solution containing the multi dimensional cube. When entering a 
> solution file in stead of a project file the complete solution is build using Visual Studion, so make sure that is what you want.
> You can specify build parameters and configurtion and platform specifications as in any other buid component.
> Under the Advanced options of the component you can specify the location of the devenv.com executable. Make sure this location matches the location
> of devenv.com on yourt agent machine (so not necessarily the same location as on your local workstation). Make sure you specify the .com file and not 
> the .exe!

## How to Setup deploy
> Point the Path to .asdatabase file field to your .asdatabase file you just created in your build step
> Specify your database server and enter a name for your database
> All other options are the same as when using the Analysis Services Deployment wizard. Except for the datasources. You cannot specify datasources 
> while defining your release. You should enter this once your database has been deployed for the first time. You can specify to not overwrite these settings
> for a next release.
> NOTE: the deployment uses the Management Studio executable Microsoft.AnalysisServices.Deployment.exe Make sure that this is installed on your build agent!
> Currently the Microsoft Hosted Agents DO NOT have Management Studio installed, so deployement from these hosts is unsupported. Setup a self hosted agent with SQL
> Server Managenment Studio installed on it to use the deployment component
> SECURITY WARNING: if you choose to use Windows username and password as impersonation mode the password you supply will be written in plaintext on disk at the deploy agent!\s\s
> NOTE: When using Impersonation changing capabilities the outputfile that is used to deploy the model is written to disk using UTF8 encoding. If you're model uses some other encoding you might want to skip impersonation settings. (message me if this is a problem, I'll see if I can fix this)


## Contribute
> * Contributions are welcome!
> * Submit bugs and help verify fixes
> [File an issue](https://github.com/avdbrink/VSTS-SSAS-Extension/issues)

## Latest Updates
> * Added functionality to update Service Account details on target server 
> * Added options for Writeback table options
> * Added documentation
> * Upated to use fit in Azure piplines category
> * Added ImpersonationInformation option None, to skip impersonation settings altogether
> * Custom Management Studio location (Microsoft.AnalysisServices.Deployment.exe) for deployment component
> * Forced UTF8 encoding on writing .asdatabase json files to disk after changing impersonation information

## TODO:
> * a Lot!
