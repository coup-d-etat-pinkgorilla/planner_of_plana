param([string]$Updater, [string]$Harness, [string]$Output)
$ErrorActionPreference = 'Stop'
Add-Type -Path @($Updater, $Harness) -ReferencedAssemblies @('System.dll','System.Core.dll',
    'System.IO.Compression.dll','System.IO.Compression.FileSystem.dll','System.Web.Extensions.dll') `
    -OutputAssembly $Output -OutputType ConsoleApplication
