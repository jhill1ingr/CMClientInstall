<#
.SYNOPSIS
	This script is a template that allows you to extend the toolkit with your own custom functions.
.DESCRIPTION
	The script is automatically dot-sourced by the AppDeployToolkitMain.ps1 script.
.NOTES
    Toolkit Exit Code Ranges:
    60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
    69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
    70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK 
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
)

##*===============================================
##* VARIABLE DECLARATION
##*===============================================
Try {
# Variables: Script
[string]$appDeployToolkitExtName = 'PSAppDeployToolkitExt'
[string]$appDeployExtScriptFriendlyName = 'App Deploy Toolkit Extensions'
[version]$appDeployExtScriptVersion = [version]'1.5.0'
[string]$appDeployExtScriptDate = '02/12/2017'
[hashtable]$appDeployExtScriptParameters = $PSBoundParameters
[System.TimeSpan]$global:minuteTimespace = $(New-Object -TypeName 'System.TimeSpan' -ArgumentList 0,0,60)
[string]$global:FTPSourceUrl = 'ftp://whdq2032/ftp'
[string]$global:DAVSourceRoot = 'http://whdq2032.global.ual.com/dav'
[string]$MSIPSModule="$dirSupportFiles\Modules\MSI\MSI.psd1"
[string]$DefaultInstallSourcePath = 'http://vcld11gpsccmm01.global.ual.com/CCM_Client'
[string]$CCMSetupPackageID='CAS00003';
[string[]]$NomadSourcePaths=@('http://vndcdfgpmgtdp01.global.ual.com/sms_dp_smspkg$/CAS00003.14','http://vndcdfgpmgtdp02.global.ual.com/sms_dp_smspkg$/CAS00003.14','http://vndcdfgpmgtdp03.global.ual.com/sms_dp_smspkg$/CAS00003.14')
[string[]]$NomadCores = @('vndcdfgpmgtdp01.global.ual.com','vndcdfgpmgtdp02.global.ual.com','vndcdfgpmgtdp03.global.ual.com')
[string]$GLOBAL:CCM_CAS_SQLSERVER = 'VOPCDCGPCMSQL01.GLOBAL.UAL.COM';
[string]$GLOBAL:CCM_CAS_SQLDATABASE = 'CM_CAS'
[string]$GLOBAL:CCM_CAS_SQLINSTANCE='SQLINST1'
[string]$GLOBAL:CCM_CAS_SQLDATASOURCE="$GLOBAL:CCM_CAS_SQLSERVER\$GLOBAL:CCM_CAS_SQLINSTANCE";
Remove-Variable -Name "CCM_SETUP_ARGUMENT_*" -Force -ErrorAction SilentlyContinue -Scope Global
Remove-Variable -Name "CCM_PREREQ_*" -Force -ErrorAction SilentlyContinue -Scope Global
[psobject[]]$CCMSetupErrors=@(
     $(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            [bool](@($Last50|?{$_ -like "*File 'C:\windows\ccmsetup\Silverlight.exe' returned failure exit code 1612*"}).Count -gt 0)
        };
        Remediation={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            Remove-RegistryKey -Key "HKLM\Software\Classes\Installer\Products\Silverlight" -ContinueOnError $true -Recurse -EA SilentlyContinue 
        };
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            [string[]]$ClientMsi = Get-Content -Path "$Env:windir\ccmsetup\logs\client.msi.log" -Ea SilentlyContinue
            [bool](@($Last50 | ?{$_ -like "*File 'C:\Windows\ccmsetup\*.*' returned failure exit code 1601. Fail the installation.*"}).Count -gt 0) -or `
            ([bool](@($Last50 | ?{$_ -like "*Installation failed with error code 1601*"}).Count -gt 0)) -or `
            ([bool](@($ClientMsi | ?{$_ -like "*Failed to connect to server. Error: 0x80040154*"}).Count -gt 0))
        };
        Remediation={
            Reset-MsiServerRegistration
        };
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            [string[]]$ClientMsi = Get-Content -Path "$Env:windir\ccmsetup\logs\client.msi.log" -Ea SilentlyContinue
            If ( [bool](@($Last50 | ?{$_ -like "*client.msi installation failed. Error text: ExitCode: 1603*" }).Count -gt 0)) {
                [bool](@($ClientMsi| ?{$_ -like "*CcmRegisterWinTask returned actual error code 1603*" }).Count -gt 0)
            }
            Else { $false }
        };
        Remediation={Remediate-TaskScheduler};
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            [bool](@($Last50 | ?{$_ -like "*Could not access network location %APPDATA%\*" }).Count -gt 0)
        };
        Remediation={Repair-AppDataDirectory};
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            [string[]]$ClientMsi = Get-Content -Path "$Env:windir\ccmsetup\logs\client.msi.log" -Ea SilentlyContinue
            If ( [bool](@($Last50 | ?{$_ -like "*client.msi installation failed. Error text: ExitCode: 1635*" }).Count -gt 0)) {
                [bool](@($ClientMsi| ?{$_ -like "*Unable to create a temp copy of patch 'configmgr2012*.msp'.*" }).Count -gt 0)
            }
            Else { $false }
        };
        Remediation={ 
            ## Add Parameter PATCH="%~dp0configmgr2012ac-sp1-kb2882125-x86.msp"
        };
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            [string[]]$ClientMsi = Get-Content -Path "$Env:windir\ccmsetup\logs\client.msi.log" -Ea SilentlyContinue
            If ( [bool](@($Last50 | ?{$_ -like "*Service 'SMS Agent Host' (CcmExec) failed to start.  Verify that you have sufficient privileges to start system services.*" }).Count -gt 0)) {
                [bool](@($ClientMsi| ?{$_ -like "*Service initialization failed (0x80070422)*" }).Count -gt 0)
            }
            Else { $false }
        };
        Remediation={ Repair-SccmClientServices };

    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50          
            [bool](@($Last50 | ?{$_ -like "*File 'C:\windows\ccmsetup\vcredist_x*.exe' returned failure exit code 1603. Fail the installation.*" }).Count -gt 0)
        };
        Remediation={ 
            Remove-MicrosoftRedistributables 
        };
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            ([bool](@($Last50 | ?{$_ -like "*CreateInstance of CLSID_BackgroundCopyManager failed with 8007042C. Unable to check BITS version*" }).Count -gt 0) -or `
            [bool](@($Last50 | ?{$_ -like "*This operating system does not contain the correct version of BITS. BITS 2.5 or later is required.*" }).Count -gt 0)) `
            -and `
            ([bool](@($Last50 | ?{$_ -like "*CcmSetup failed with error code 0x8007042c*" }).Count -gt 0) -or `
            [bool](@($Last50 | ?{$_ -like "*CcmSetup failed with error code 0x80004005*" }).Count -gt 0))
            
        };
        Remediation={ Repair-SccmClientServices };
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            [bool](@($Last50 | ?{$_ -like "*BITS job creation failed with 80200014. Unable to check BITS version*" }).Count -gt 0)
            
        };
        Remediation={ <# /BITSpriority:low  #>  };
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            [bool](@($Last50 | ?{$_ -like "*Setup failed due to unexpected circumstances*"}).Count -gt 0) -and `
            [bool](@($Last50 | ?{$_ -like "*The error code is 80070534*"}).Count -gt 0)
        };
        Remediation={ Reset-DCOMPermissions;  Reset-WingmtPermissions; };
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            #[string[]]$WmiErrors = Get-WmiErrors -ExpandErrors -FormatHex | %{$_.Replace('0x','')}
            #[bool](@($Last50 | ?{$_ -like "*Setup failed due to unexpected circumstances*"}).Count -gt 0) -and `
            #[string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            #[bool](@($Last50 | ?{$_ -match "The error code is ($($WmiErrors -join '|'))"}).Count -gt 0)
            $false
        };#Get-WMIErrors
        Remediation={ Rebuild-WmiRepository }
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            [bool](@($Last50 | ?{$_ -match "Setup was unable to (create|delete) the WMI namespace"}).Count -gt 0)
        };
        Remediation={ Rebuild-WmiRepository };
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            
            [bool](@($Last50 | ?{$_ -like "*client.msi installation failed. Error text: ExitCode: 1603*"}).Count -gt 0) -and `
            [bool](@($Last50 | ?{$_ -like "*Module *\StatusAgentProxy.dll failed to register. HRESULT -2147024770*"}).Count -gt 0)
        };
        Remediation={ Remove-MicrosoftRedistributables; };
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            [bool](@($Last50 | ?{$_ -like "*File *\MicrosoftPolicyPlatformSetup.msi installation failed. Error text: ExitCode: 1603*"}).Count -gt 0) -and `
            [bool](@($Last50 | ?{$_ -like "*CcmSetup failed with error code 0x80070643*"}).Count -gt 0) 
        };
        Remediation={ Remove-PolicyPlatform; Rebuild-WmiRepository};
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect=$([scriptblock]{[string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50;[bool](@($Last50 | ?{$_ -like "*Setup failed due to unexpected circumstances The error code is 80070005*"}).Count -gt 0)};)
        Remediation={ 
            Reset-DCOMPermissions; 
            ## Schedule Reboot
        };
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect=$([scriptblock]({[string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50; [bool](@($Last50 | ?{$_ -like "*MSI: Setup failed due to unexpected circumstances*"}).Count -gt 0) -and [bool](@($Last50 | ?{$_ -like "*The error code is 800706FD*"}).Count -gt 0) -and [bool](@($Last50 | ?{$_ -like "*CcmSetup failed with error code 0x80004004*"}).Count -gt 0)}));
        Remediation=$({ Set-ServiceStartMode -Name 'netlogon' -StartMode Automatic -ContinueOnError $true -ea silentlycontinue; Clear-CMRegistrySettings;});
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect=$([scriptblock]({ [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50; [bool](@($Last50 | ?{$_ -like "*Failed to get assigned site from AD. Error 0x80004005*"}).Count -gt 0) -and [bool](@($Last50 | ?{$_ -like "*GetADInstallParams failed with 0x80004005*"}).Count -gt 0) -and [bool](@($Last50 | ?{$_ -like "*Couldn't find an MP source through AD. Error 0x80004005*"}).Count -gt 0) -and [bool](@(Get-Content -Path "$Env:windir\ccmsetup\logs\client.msi.log" -Ea SilentlyContinue | ?{$_ -like "*ERROR: Failed to resolve the account *"}).Count -gt 0)}));
        Remediation=$([scriptblock]({ 
            Set-ServiceStartMode -Name 'netlogon' -StartMode Automatic -ContinueOnError $true -ea silentlycontinue; Start-ServiceAndDependencies -Name 'netlogon' -ContinueOnError $true -ea silentlycontinue;
            ## Valid CM Boundaries
            ## Use Source Parameter
        })); 
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect=([scriptblock]{[string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50;[bool](@($Last50 | ?{$_ -like "*No valid source or MP locations*"}).Count -gt 0) -and [bool](@($Last50 | ?{$_ -like "*CcmSetup failed with error code 0x80004005*"}).Count -gt 0);});
        Remediation=([scriptblock]{ 
            ## ReInstall-CMClientWithSource
        });
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            [string[]]$ClientMsi = Get-Content -Path "$Env:windir\ccmsetup\logs\client.msi.log" -Ea SilentlyContinue
            [bool](@($Last50 | ?{$_ -like "*client.msi installation failed. Error text: ExitCode: 1603*"}).Count -gt 0) -and `
            [bool](@($ClientMsi| ?{$_ -like "*Failed to instantiate MSXML with error 0x8007045a.*"}).Count -gt 0)
        };
        Remediation=$([scriptblock]({ Repair-MsXmlParser}));
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            [string[]]$ClientMsi = Get-Content -Path "$Env:windir\ccmsetup\logs\client.msi.log" -Ea SilentlyContinue| Select -Last 50
            [bool](@($Last50 | ?{$_ -like "*SMSMP cannot be specified without SMSSITECODE*"}).Count -gt 0) -and `
            [bool](@($Last50 | Select -Last 30 | ?{$_ -like "*The error code is 80004005*"}).Count -gt 0) -and `
            [bool](@($ClientMsi | ?{$_ -like "*Note: 1: 1708*"}).Count -gt 0)
        };
        Remediation={ 
            <# Invalid Command Line.  Re-run as default. #>
        }
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            [bool](@($Last50 | ?{$_ -like "*\MicrosoftPolicyPlatformSetup.msi' authenticode signature. Return code 0x800b0101*"}).Count -gt 0)
        };
        Remediation={ 
            <# Install 457899_ENU_x64_zip.exe. #>
        }
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            [bool](@($Last50 | ?{$_ -like "*Setup was unable to compile Sql CE script file *.sqlce. The error code is 87D00244.*"}).Count -gt 0)
        };
        Remediation={ Clear-CMFiles}
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            [bool](@($Last50 | ?{$_ -like "*Installation failed with error code 1612*"}).Count -gt 0) -and [bool](@($Last50 | ?{$_ -like "*CcmSetup failed with error code 0x8007064c*"}).Count -gt 0)
        };
        Remediation={ 
            <#
                HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\
            #>
        Clear-CMRegistrySettings
        }
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            [bool](@($Last50 | ?{$_ -like "*Module C:\WINNT\system32\CCM\VAppRegHandler.dll failed to register*"}).Count -gt 0) -and [bool](@($Last50 | ?{$_ -like "*CcmSetup failed with error code 0x8007064c*"}).Count -gt 0)
        };
        Remediation={ 
            <#
                1. Manually created folder “CCM” under C:\WINDOWS\system32\ to the problem computer

                2. Copied “VAppRegHandler.dll” to the problem computer’s C:\WINDOWS\system32\CCM\

                3. On the problem computer, ran in the console: regsvr32 atl.dll

                4. On the problem computer, ran in the console: regsvr32 C:\WINDOWS\system32\CCM\VAppRegHandler.dll

                5. WMI repair.
                If still its not resolved .. Please delete the below “.dll” Files which is related to SCCM client CCMPerf.dll (C:\Windows\system32\) CCMcore.dll(C:\Windows\system32\) Then retry the installation it will get success
            #>
        Clear-CMRegistrySettings
        }
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            [bool](@($Last50 | ?{$_ -like "*File ‘*\SCEPInstall.exe’ with hash '*' from manifest doesn’t match with the file hash*"}).Count -gt 0) -or `
            [bool](@($Last50 | ?{$_ -like "*Couldn't verify '*\MicrosoftPolicyPlatformSetup.msi' authenticode signature.*"}).Count -gt 0)
        };
        Remediation={ 
            <#
                Failed.  Server Problem.
            #>
        
        }
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            [bool](@($Last50 | ?{$_ -like "*ERROR: Failed to execute SQL statement*"}).Count -gt 0) -and `
            [bool](@($Last50 | ?{$_ -like "*with error (0x80040e37)*"}).Count -gt 0)
        };
        Remediation={ 
            <#
                Failed.  Server Problem.
            #>
            Remove-MicrosoftRedistributables;
            Install-MicrosoftRedistributable13
        }
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            [bool](@($Last50 | ?{$_ -like "*File 'windowsupdateagent30-x*.exe' returned failure exit code 775. Fail the installation.*"}).Count -gt 0) -and `
            [bool](@($Last50 | ?{$_ -like "*CcmSetup failed with error code 0x80070307*"}).Count -gt 0)
        };
        Remediation={ 
            <#
                Rerun with /skipprereq:windowsupdateagent30-x64.exe
            #>
        }
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50
            $([bool](@($Last50 | ?{$_ -like "*Failed to get DP locations as the expected version from MP '*'. Error 0x8000ffff*"}).Count -gt 0)) -or `
            $([bool](@($Last50 | ?{$_ -like "*Failed to get DP locations as the expected version from MP 'http*'. Error 0x80072f78*"}).Count -gt 0)) -or `
            $([bool](@($Last50 | ?{$_ -like "*Failed to get DP locations as the expected version from MP '*'. Error 0x87d00215*"}).Count -gt 0))
        };
        Remediation={ 
            ## ????   
        }
    })
    ,$(New-Object -TypeName psobject -property @{
        Detect={
            [string[]]$Last50 = Get-Content -Path "$Env:windir\ccmsetup\logs\ccmsetup.log" -Ea SilentlyContinue| Select -Last 50; [bool](@($Last50 | ?{$_ -like "*GetDPLocations failed with error 0x80072f78*"}).Count -gt 0)
        };
        Remediation={ 
            <#
            Our Firewall ist working as a webproxy and it seems that http POST request got lost somewhere in the communication client->firewall->sccm (iis) sccm->firewall->client
            I now made an exception for the sccm host and it works.
            #>
        }
    })
)
Try {
    Get-ChildItem -Path $dirSupportFiles -Filter "*.psd1" -Force -Recurse | Select-Object -ExpandProperty 'FullName' | %{
            Write-Verbose -Message "Importing Module: '$($_)''..."
            Import-Module -Name $_ -Force -Ea 'SilentlyContinue';
    };
}
Catch {
    Write-Warning -Message "Unable To Import Module 'MSI' from Path '$MSIPSModule': $($_.Exception.Message)" 
}
Try {
    [System.Management.Automation.PSObject]$GLOBAL:dirFiles_Index = New-Object -TypeName PSObject;
    Get-ChildItem -Path $dirFiles -Filter *.* -Recurse -Force | ? { !$_.PSIsContainer } | %{
        If ( $_.FullName -match '(\\x64\\)' ) {
            [string]$i386File = $($_.FullName -Replace '\\x64\\','\i386\');
            Write-Log -Message "i386File: $i386File" -Source ${CmdletName}
            If ( Test-Path -Path $i386File){[string]$Suffix = "_x64"}Else{[string]$Suffix = ""}
        }
        ElseIf ( $_.FullName -match '(\\i386\\)' ) {
            [string]$x64File = $($_.FullName -Replace '\\i386\\','\x64\');
            Write-Log -Message "x64File: $x64File" -Source ${CmdletName}
            If ( Test-Path -Path $x64File){[string]$Suffix = "_x86"}Else{[string]$Suffix = ""}
        }
        Else {
            [string]$Suffix = ""
        }
        [string]$VariableName = "CCM_" +'FILES_'+ $([System.IO.Path]::GetFileNameWithoutExtension($_.FullName)).ToUpper() + '_' + $( ([System.IO.Path]::GetExtension($_.FullName).Trimstart('.')).ToUpper()) + $Suffix
        Write-Log -Message "VariableName: $VariableName" -Source ${CmdletName}
        Add-Member -InputObject $GLOBAL:dirFiles_Index -MemberType NoteProperty -Name $VariableName.Replace('.','_') -Value $_.FullName -Force;
    }
    [System.Management.Automation.PSObject]$GLOBAL:dirSupportFiles_Index = New-Object -TypeName PSObject;
    Get-ChildItem -Path $dirSupportFiles -Filter *.* -Recurse -Force | ? { !$_.PSIsContainer } | %{
        If ( $_.FullName -match '(\\x64\\)' ) {
            [string]$i386File = $($_.FullName -Replace '\\x64\\','\i386\');
            Write-Log -Message "i386File: $i386File" -Source ${CmdletName}
            If ( Test-Path -Path $i386File){[string]$Suffix = "_x64"}Else{[string]$Suffix = ""}
        }
        ElseIf ( $_.FullName -match '(\\i386\\)' ) {
            [string]$x64File = $($_.FullName -Replace '\\i386\\','\x64\');
            Write-Log -Message "x64File: $x64File" -Source ${CmdletName}
            If ( Test-Path -Path $x64File){[string]$Suffix = "_x86"}Else{[string]$Suffix = ""}
        }
        Else {
            [string]$Suffix = ""
        }
        [string]$VariableName = "CCM_" +'SUPPORTFILES_'+ $([System.IO.Path]::GetFileNameWithoutExtension($_.FullName)).ToUpper() + '_' + $( ([System.IO.Path]::GetExtension($_.FullName).Trimstart('.')).ToUpper()) + $Suffix
        Write-Log -Message "VariableName: $VariableName" -Source ${CmdletName}
        Add-Member -InputObject $GLOBAL:dirFiles_Index -MemberType NoteProperty -Name $VariableName.Replace('.','_') -Value $_.FullName -Force;
    }
    <#
    Get-ChildItem -Path $dirFiles,$dirSupportFiles -Filter *.* -Recurse -Force | ? { !$_.PSIsContainer } | %{ 
        [string]$Prefix = ([regex]'(?<=\\)(Files|SupportFiles)(?=\\)').Matches($Path) | Select-Object -First 1 -ExpandProperty Value
        [string]$VariableName = @(@('CCM') + @($_.Name.Split('.'))) -join '_'
        Write-Log -Message "[$VariableName]=[$($_.FullName)]" -Source ${CmdletName}
        Set-Variable -Name $VariableName.Toupper() -Value $_.FullName -Scope Global -Force; 
    }
    #>
}
Catch {
    Write-Log -Message "Unable To Set Global Variables For file" -Source $appDeployToolkitExtName -Severity 2;
}
##*===============================================
##* FUNCTION LISTINGS
##*===============================================

# <Your custom functions go here>

##*===============================================
#region ScriptBlocks
[scriptblock]$global:ProcessStartCommand = {
    [string]${CmdletName} = 'Process-StartCommand'
    Try {
        [string]$ExpressionValue = $ExecutionContext.InvokeCommand.ExpandString($InputObject.command);
        Write-Log -Message "ExpressionValue [$($ExpressionValue)]..." -Source ${CmdletName};

        [string]$Expression = "Set-Variable -Name '$($InputObject.variable)' -Value ([$($InputObject.type)]`$($ExpressionValue)) -Force -Scope Global"
        Write-Log -Message "Executing Expression [$($Expression)]..." -Source ${CmdletName};

        Invoke-Expression -Command $Expression|out-null
        #Write-Log -Message "Resulting Value: [$(Get-Variable -Name $InputObject.variable -ValueOnly -Scope 'Global')]." -Source ${CmdletName};
    }
    Catch {
        Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 3
    }
}
[scriptblock]$global:ProcessPostCommand = {
    [string]${CmdletName} = 'Process-PostCommand'
    Try {
        [string]$ExpressionValue = $ExecutionContext.InvokeCommand.ExpandString($InputObject.command);
        Write-Log -Message "ExpressionValue [$($ExpressionValue)]..." -Source ${CmdletName};

        [string]$Expression = "Set-Variable -Name '$($InputObject.variable)' -Value ([$($InputObject.type)]`$($ExpressionValue)) -Force -Scope Global"
        Write-Log -Message "Executing Expression [$($Expression)]..." -Source ${CmdletName};

        Invoke-Expression -Command $Expression|out-null
        #Write-Log -Message "Resulting Value: [$(Get-Variable -Name $InputObject.variable -ValueOnly -Scope 'Global')]." -Source ${CmdletName};
    }
    Catch {
        Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 3
    }
}
[scriptblock]$global:ProcessPrereqCommand = {
	param
	(
        [Parameter(Mandatory=$true,Position=0)]
        $InputObject
    )
    [pscustomobject]$CmdletDetails = New-Object -TypeName PSObject;
    Try {
        ## Check If Applicable
        [string]${CmdletName} = 'ProcessPrereqCommand'
        Set-Variable -Name applicableString -Value $(Invoke-Expression -Command $($InputObject.Applicable)) -Force;
        Write-Log -Message "applicableString: $applicableString" -Source ${CmdletName}

        Set-Variable -Name removeString -Value $(Invoke-Expression -Command "`$$($InputObject.remove)") -Force;
        Write-Log -Message "removeString: $removeString" -Source ${CmdletName}
            
        Set-Variable -Name excludeString -Value $(Invoke-Expression -Command "`$$($InputObject.skip)") -Force;
        Write-Log -Message "excludeString: $excludeString" -Source ${CmdletName}
            
        [System.Boolean]$IsApplicable = [System.Boolean]::Parse($applicableString)
        Write-Log -Message "IsApplicable: $IsApplicable" -Source ${CmdletName}

        If ( !$IsApplicable ) {
            Throw "Prerequisite '$($InputObject.Path)' Is Not Applicable."
        }

        [string]$PreFilePath = $ExecutionContext.InvokeCommand.ExpandString($InputObject.filepath)
        Write-Log -Message "PreFilePath: $PreFilePath" -Source ${CmdletName}

        [System.Boolean]$IsRemove = [System.Boolean]::Parse($removeString)
        Write-Log -Message "IsRemove: $IsRemove" -Source ${CmdletName}            
            
        [System.Boolean]$IsExclude = [System.Boolean]::Parse($excludeString)
        Write-Log -Message "IsExclude: $IsExclude" -Source ${CmdletName}

        Add-Member -InputObject $CmdletDetails -MemberType NoteProperty -Name 'Path' -Value $PreFilePath -Force;
        Add-Member -InputObject $CmdletDetails -MemberType NoteProperty -Name 'Remove' -Value $IsRemove -Force;
        Add-Member -InputObject $CmdletDetails -MemberType NoteProperty -Name 'Exclude' -Value $IsExclude -Force;

        foreach ( $ChildNode in @($InputObject.ChildNodes) ) {
                
            $addObject=Assemble-Cmdlet -InputObject $ChildNode
            Write-Log -Message "addObject: $($CHildNode.Name)::['$($addObject|fl * |out-string)']"
            $CmdletDetails | Add-Member -MemberType NoteProperty -Name $ChildNode.Name -Value $addObject -Force;
        }

        trY{
            [int]$lastIndex = Get-Variable | ?{$_.Name -match 'CCM_PREREQ_\d{2}'}|sort -Descending -Property Name|select -first 1 -ExpandProperty name|%{ ([regex]'(\d{2})$').Matches($_)|select -first 1 -ExpandProperty Value }
        }
        catch{
            [int]$lastIndex = 0;
        }
        Write-Log -Message "lastIndex: $lastIndex" -Source ${CmdletName}
            
        [int]$NewIndex = $lastIndex+1;
        Write-Log -Message "NewIndex: $NewIndex" -Source ${CmdletName}

        [string]$VariableName = 'CCM_PREREQ_' + ('{0:D2}' -f $NewIndex)
        Write-Log -Message "VariableName: $VariableName" -Source ${CmdletName}
        Set-Variable -Name $VariableName -Value $CmdletDetails -Force -Scope Global -Ea 'SilentlyContinue'
            
        If ( $IsExclude ) {

            trY{
                [int]$lastIndex1 = Get-Variable | ?{$_.Name -match 'CCM_PREREQ_VALUE_\d{2}'}|sort -Descending -Property Name|select -first 1 -ExpandProperty name|%{ ([regex]'(\d{2})$').Matches($_)|select -first 1 -ExpandProperty Value }
            }
            catch{
                [int]$lastIndex1 = 0;
            }
            Write-Log -Message "lastIndex1: $lastIndex1" -Source ${CmdletName}

            [int]$NewIndex1 = $lastIndex1+1;
            Write-Log -Message "NewIndex1: $NewIndex1" -Source ${CmdletName}

            [string]$PRVar = 'CCM_PREREQ_VALUE_' + ('{0:D2}' -f $NewIndex1)
            Write-Log -Message "PRVar: $PRVar" -Source ${CmdletName}
            Set-Variable -Name $PRVar -Value $(Split-Path -Path $PreFilePath -Leaf) -Force -Scope Global -Ea 'SilentlyContinue'
        }

            
    }
    Catch {
        Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 1
    }
}
[scriptblock]$global:ProcessSetupParameter = {
	param
	(
        [Parameter(Mandatory=$true,Position=0)]
        $InputObject
    )
        Try {
            [string]${CmdletName} = 'Process-SetupParameter'
            ## Check If Applicable
            Set-Variable -Name applicableString -Value $(Invoke-Expression -Command $($InputObject.Applicable)) -Force;
            Write-Log -Message "applicableString: $applicableString" -Source ${CmdletName}

            Set-Variable -Name removeString -Value $(Invoke-Expression -Command "`$$($InputObject.remove)") -Force;
            Write-Log -Message "removeString: $removeString" -Source ${CmdletName}
            
            Set-Variable -Name excludeString -Value $(Invoke-Expression -Command "`$$($InputObject.skip)") -Force;
            Write-Log -Message "excludeString: $excludeString" -Source ${CmdletName}
            
            [System.Boolean]$IsApplicable = [System.Boolean]::Parse($applicableString)
            Write-Log -Message "IsApplicable: $IsApplicable" -Source ${CmdletName}

            If ( !$IsApplicable ) {
                Throw "Prerequisite '$($InputObject.Path)' Is Not Applicable."
            }

            [string]$PreFilePath = $ExecutionContext.InvokeCommand.ExpandString($InputObject.filepath)
            Write-Log -Message "PreFilePath: $PreFilePath" -Source ${CmdletName}

            [System.Boolean]$IsRemove = [System.Boolean]::Parse($removeString)
            Write-Log -Message "IsRemove: $IsRemove" -Source ${CmdletName}            
            
            [System.Boolean]$IsExclude = [System.Boolean]::Parse($excludeString)
            Write-Log -Message "IsExclude: $IsExclude" -Source ${CmdletName}

            Add-Member -InputObject $CmdletDetails -MemberType NoteProperty -Name 'Path' -Value $PreFilePath -Force;
            Add-Member -InputObject $CmdletDetails -MemberType NoteProperty -Name 'Remove' -Value $IsRemove -Force;
            Add-Member -InputObject $CmdletDetails -MemberType NoteProperty -Name 'Exclude' -Value $IsExclude -Force;

            foreach ( $ChildNode in @($InputObject.ChildNodes) ) {
                
                $addObject=Assemble-Cmdlet -InputObject $ChildNode
                Write-Log -Message "addObject: $($CHildNode.Name)::['$($addObject|fl * |out-string)']"
                $CmdletDetails | Add-Member -MemberType NoteProperty -Name $ChildNode.Name -Value $addObject -Force;
            }

            trY{
                [int]$lastIndex = Get-Variable | ?{$_.Name -match 'CCM_PREREQ_\d{2}'}|sort -Descending -Property Name|select -first 1 -ExpandProperty name|%{ ([regex]'(\d{2})$').Matches($_)|select -first 1 -ExpandProperty Value }
            }
            catch{
                [int]$lastIndex = 0;
            }
            Write-Log -Message "lastIndex: $lastIndex" -Source ${CmdletName}
            
            [int]$NewIndex = $lastIndex+1;
            Write-Log -Message "NewIndex: $NewIndex" -Source ${CmdletName}

            [string]$VariableName = 'CCM_PREREQ_' + ('{0:D2}' -f $NewIndex)
            Write-Log -Message "VariableName: $VariableName" -Source ${CmdletName}
            Set-Variable -Name $VariableName -Value $CmdletDetails -Force -Scope Global -Ea 'SilentlyContinue'
            
            If ( $IsExclude ) {

                trY{
                    [int]$lastIndex1 = Get-Variable | ?{$_.Name -match 'CCM_PREREQ_VALUE_\d{2}'}|sort -Descending -Property Name|select -first 1 -ExpandProperty name|%{ ([regex]'(\d{2})$').Matches($_)|select -first 1 -ExpandProperty Value }
                }
                catch{
                    [int]$lastIndex1 = 0;
                }
                Write-Log -Message "lastIndex1: $lastIndex1" -Source ${CmdletName}

                [int]$NewIndex1 = $lastIndex1+1;
                Write-Log -Message "NewIndex1: $NewIndex1" -Source ${CmdletName}

                [string]$PRVar = 'CCM_PREREQ_VALUE_' + ('{0:D2}' -f $NewIndex1)
                Write-Log -Message "PRVar: $PRVar" -Source ${CmdletName}
                Set-Variable -Name $PRVar -Value $(Split-Path -Path $PreFilePath -Leaf) -Force -Scope Global -Ea 'SilentlyContinue'
            }

            
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 1
        }
}
[scriptblock]$global:ProcessVariable = {
	param
	(
        [Parameter(Mandatory=$true,Position=0)]
        $InputObject
    )
    Try {
        [string]${CmdletName} = $PsCmdlet.MyInvocation.MyCommand.Name;	
        $expandedValue = $ExecutionContext.InvokeCommand.ExpandString($InputObject.value)
        $convertedValue = Convert-Variable -InputObject $expandedValue -TypeString $InputObject.type
        [hashtable]$SetGlobalVariable = @{Force=[switch]::Present;Scope='Global';Name=$InputObject.id;Value=$convertedValue;}
        Write-Log -Message "Attempting To Set Global Variable [$($InputObject.id)]=[$($convertedValue;)]..." -Source ${cmdletname}
        Set-Variable @SetGlobalVariable;
        Write-Log -Message "Completed [$($?)]." -Source ${cmdletname}
        }
    Catch {
        Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 1
    }
}
#endregion ScriptBlocks
##*===============================================


##*===============================================
#region [Assemble Functions]
function Assemble-CCMSetupParameters
{
	[CmdletBinding()]
	param ()
	Begin  {
	    [string]${CmdletName} = 'Assemble-CCMSetupParameters'
    }
    Process {
        Try { 
            [string[]]$ArgArr=@();
            If ($GLOBAL:CCM_SETUP_USE_SOURCE){If ( ![string]::IsNullOrEmpty($GLOBAL:CCM_SETUP_SOURCE_PARAMETER) ){ $ArgArr+=$GLOBAL:CCM_SETUP_SOURCE_PARAMETER  }    }
            If ( ![string]::IsNullOrEmpty($GLOBAL:CCM_SETUP_SKIP_PREREQ_PARAM) ){ $ArgArr+=$GLOBAL:CCM_SETUP_SKIP_PREREQ_PARAM  }
            Get-LoadedSetupParameters -Ea SilentlyContinue | %{$ArgArr += $_.Value;}
            [string]$GLOBAL:CCM_SETUP_PARAMETER_STRING = $($ArgArr -join ' ')
            Write-Verbose "[${CmdletName}]Parameters ($GLOBAL:CCM_SETUP_PARAMETER_STRING)."
        }
        Catch { Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source 'Convert-Variable' -Severity 2; }
	}
}
function Assemble-SkipPrerequisites
{
	[CmdletBinding()]
	param (
    )
	Begin  {
	    [string]${CmdletName} = 'Assemble-SkipPrerequisites'	
        [string]$ReturnValue = [string]::Empty
    }
    Process {
        Try {
            [string]$ParameterValue = $(Get-LoadedSkippedPrereqs|Select-Object -ExpandProperty Value | %{$_}) -join ';'
            If ( ![string]::IsNullOrEmpty($ParameterValue) ) {
                 Set-Variable -Name 'CCM_SETUP_SKIP_PREREQ_PARAM' -Value "/skipprereq:`"$ParameterValue`"" -Force -Scope 'Global' 
                Write-Verbose "[ ${CmdletName}]::[CCM_SETUP_SKIP_PREREQ_PARAM = '/skipprereq:$ParameterValue']"
            }
            Else {
                Set-Variable -Name 'CCM_SETUP_SKIP_PREREQ_PARAM' -Value $([string]::Empty) -Force -Scope 'Global' -Ea SilentlyContinue
                Write-Verbose "[ ${CmdletName}]::[CCM_SETUP_SKIP_PREREQ = '$ParameterValue']"
            }
            
            
        }
        Catch {
            Write-Host "[${CmdletName}] Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)"
	    }
    }
}
function Assemble-Cmdlet
{
	[CmdletBinding()]
    [OutputType([PSCustomObject])]
	param
	(
        [Parameter(Mandatory=$true)]
        $InputObject
    )
	Begin 
    {
	    [string]${CmdletName} = $PsCmdlet.MyInvocation.MyCommand.Name;	
        [PSCustomObject]$ReturnObject = New-Object -TypeName PSCustomObject;
    }
    Process {
        Try {
            [hashtable]$CmdletParams = @{}
            If ( ${InputObject}.HasChildNodes ) {
                Foreach ( $ChildNode in $InputObject.ChildNodes ) {
                    Switch ( $ChildNode.Type ) {
                        'string'{
                            ($CmdletParams).Add( $ChildNode.Name, $ExecutionContext.InvokeCommand.ExpandString($ChildNode.'#text') )
                            break;
                        }
                        'int'{
                            ($CmdletParams).Add( $ChildNode.Name, [Int32]::Parse($ChildNode.'#text') )
                            break;
                        }
                       'switch'{
                            ($CmdletParams).Add( $ChildNode.Name, [switch]::Present )
                            break;
                        }
                        'bool'{
                            ($CmdletParams).Add( $ChildNode.Name, [bool](Invoke-Expression -Command $($ChildNode.'#text')) )
                            break;
                        }
                       'string[]'{
                            ($CmdletParams).Add( $ChildNode.Name, $ExecutionContext.InvokeCommand.ExpandString($ChildNode.'#text').Split(","))
                            break;
                        }
                    }
                }
            }
            Add-Member -InputObject $ReturnObject -MemberType NoteProperty -Name 'CmdletName' -Value $InputObject.CmdletName  -TypeName 'String' -Force;
            Add-Member -InputObject $ReturnObject -MemberType NoteProperty -Name 'Parameters' -Value $CmdletParams  -TypeName 'String' -Force;
            Add-Member -InputObject $ReturnObject -MemberType ScriptMethod -Name 'Execute' -Value {
                Param() 
                [bool]$ReturnVal = $false; [hashtable]$ScriptBlockParams = $this.Parameters;
                if ( $ScriptBlockParams.Count -gt 0 ) {[bool]$ReturnVal = & $($this.CmdletName) @ScriptBlockParams}
                Else {[bool]$ReturnVal = & $($this.CmdletName)}
                Write-Output $ReturnVal
            }  -Force
            

            #5Write-Log -Message "ReturnObject: $($ReturnObject | fl * | out-string)`r`nMembers: $($ReturnObject|gm)"
            
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        }
	}
	End
	{
		Write-Output -InputObject $ReturnObject 
	}
}
#endregion [Import Settings]
##*===============================================

##*===============================================
#region [Variable Functions]
function Get-LoadedSetupSources
{
	[CmdletBinding()]
    [OutputType([psobject[]])]
	param
	(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]${BaseVariableName} = 'CCM_SETUPSOURCE'
    )
	Begin 
    {
	    [string]${CmdletName} = $PsCmdlet.MyInvocation.MyCommand.Name;	
        [psobject[]]$ReturnValue = @();
    }
    Process {
        Try {
            Get-Variable | ? { $_.Name -match "${BaseVariableName}[_]\d{2}" } | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name 'Index' -Value $([int]($($_.Name.Split('_')|Select-Object -Last 1).TrimStart('0'))) -PassThru -Force} |Sort-Object -Property 'Index' | Select-Object -Property "Name","Value","Index"  | %{$ReturnValue += $_}
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        }
	}
    End {
        Write-Output -InputObject $ReturnValue
    }
}
function Get-LoadedSetupParameters
{
	[CmdletBinding()]
    [OutputType([psobject[]])]
	param
	(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]${BaseVariableName} = 'CCM_SETUP_ARGUMENT'
    )
	Begin 
    {
	    [string]${CmdletName} = $PsCmdlet.MyInvocation.MyCommand.Name;	
        [psobject[]]$ReturnValue = @();
    }
    Process {
        Try {
            Get-Variable | ? { $_.Name -match "${BaseVariableName}[_]\d{2}" } | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name 'Index' -Value $([int]($($_.Name.Split('_')|Select-Object -Last 1).TrimStart('0'))) -PassThru -Force} |Sort-Object -Property 'Index' | Select-Object -Property "Name","Value","Index"  | %{$ReturnValue += $_}
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 3
        }
	}
    End {
        Write-Output -InputObject $ReturnValue
    }
}
function Get-LoadedSkippedPrereqs
{
	[CmdletBinding()]
    [OutputType([psobject[]])]
	param
	(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]${BaseVariableName} = 'CCM_PREREQ_VALUE'
    )
	Begin 
    {
	    [string]${CmdletName} = $PsCmdlet.MyInvocation.MyCommand.Name;	
        [psobject[]]$ReturnValue = @();
    }
    Process {
        Try {
            Get-Variable | ? { $_.Name -match "${BaseVariableName}[_]\d{2}" } | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name 'Index' -Value $([int]($($_.Name.Split('_')|Select-Object -Last 1).TrimStart('0'))) -PassThru -Force} |Sort-Object -Property 'Index' | Select-Object -Property "Name","Value","Index"  | %{$ReturnValue += $_}
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 3
        }
	}
    End {
        Write-Output -InputObject $ReturnValue
    }
}
function Get-LoadedPrereqParameters
{
	[CmdletBinding()]
    [OutputType([psobject[]])]
	param
	(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]${BaseVariableName} = 'CCM_PREREQ'
    )
	Begin 
    {
	    [string]${CmdletName} = $PsCmdlet.MyInvocation.MyCommand.Name;	
        [psobject[]]$ReturnValue = @();
    }
    Process {
        Try {
            Get-Variable | ? { $_.Name -match "${BaseVariableName}[_]\d{2}" } | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name 'Index' -Value $([int]($($_.Name.Split('_')|Select-Object -Last 1).TrimStart('0'))) -PassThru -Force} |Sort-Object -Property 'Index' | Select-Object -Property "Name","Value","Index"  | %{$ReturnValue += $_}
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 3
        }
	}
    End {
        Write-Output -InputObject $ReturnValue
    }
}
function Convert-Variable
{
	[CmdletBinding()]
	param
	(
        [Parameter(Mandatory=$true)]
        $InputObject,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$TypeString
    )
	Begin 
    {
	    [string]${CmdletName} = $PsCmdlet.MyInvocation.MyCommand.Name;	
    }
    Process {
        Try {
            Write-Verbose -Message "Input Type Name: $($InputObject.GetType().N)."
            Write-Verbose -Message "Target Type Name: $($TypeString)." 
            $ReturnValue = $InputObject -as $([System.Type]::GetType($TypeString))
            Write-Log -Message "[$($ReturnValue.GetType().Name)]`$ReturnValue = $($ReturnValue)" -Source 'Convert-Variable'

            If ( $ReturnValue -is [System.Boolean] ) {
                If ( $ReturnValue.ToString() -like 'true' ) {
                    [System.Boolean]$ReturnValue = $true;
                }
                Else {
                    [System.Boolean]$ReturnValue = $false
                }
            }
            
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source 'Convert-Variable' -Severity 2
            
        }
	}
    End {
        Write-Output -InputObject $ReturnValue
    }
}
#endregion [Variable Functions]
##*===============================================

##*===============================================
#region [Import Settings]
function Set-CCMSetupSource 
{
	[CmdletBinding()]
	param (
    )
	Begin  {
	    [string]${CmdletName} = 'Set-CCMSetupSource '	
        [string]$ReturnValue = [string]::Empty
    }
    Process {
        Try {
            Get-LoadedSetupSources | ?{
                If ( $_.Value -like 'http*'  ) { Test-URI -URI $_.Value}
                Else {Test-Path -Path $_.Value}
            }|Select-Object -First 1 -ExpandProperty Value|%{
                Write-Host "Valid Source. Set Parameter [$($_)]" 
                [string]$global:CCM_SETUP_SOURCE_PARAMETER =  "/source:`"$_`""            
            }
        }
        Catch {
            Write-Host "[${CmdletName}] Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)"
	    }
        Finally{
            Write-Host -Message "[ ${CmdletName}]::[CCM_SETUP_SOURCE_PARAMETER = '$global:CCM_SETUP_SOURCE_PARAMETER']"
        }
    }
}
function Process-SetupParameter
{
	[CmdletBinding()]
	param
	(
        [Parameter(Mandatory=$true)]
        $InputObject
    )
	Begin 
    {
        [string]${CmdletName} = 'Process-SetupParameter'
        #Write-Log -Message "InputObject: $($InputObject|fl *|out-string)" -Source 'Process-SetupParameter'
        [string]${BaseVariableName} = 'CCM_SETUP_ARGUMENT'
        [string]${ParameterHashTableName}= 'CCM_SETUP_PARAMETERS'
    }
    Process {
        Try {
            ## Validate InputObject Value
            If (![string]::IsNullOrEmpty($($InputObject.value))){
                Write-Log "`r`n##############################################################################" -Source ${CmdletName}
                Write-Log "------------------------------------- BEGIN PARSE ON [$($inPUToBJECT.ID)] -------------------------------------" -Source ${CmdletName}
                
                ## Expand Variable Value
                ${Value} = $ExecutionContext.InvokeCommand.ExpandString($InputObject.value);
                If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "[$(${Value}.GetType().Name)]`${Value} = '$(${Value})'" -Source 'Process-SetupParameter'}
            
                ## Existing Parameter Variables
                [object[]]${ExistingVariables} = Get-LoadedSetupParameters;
                If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "Found $(${ExistingVariables}.Count) Existing Parameter Variables." -Source 'Process-SetupParameter'}

                ## Get Next Parameter Index To Use
                If ( ${ExistingVariables}.Count -eq 0 ) {[int]${ParameterIndex} =  1}
                Else {[int]${ParameterIndex} =  ${ExistingVariables} | Sort-Object -Descending -Property 'Index' | Select-Object -First 1  -ExpandProperty 'Index' | %{ ($_ + 1) } | Select-Object -First 1}
                If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "[$(${ParameterIndex}.GetType().Name)]`${ParameterIndex} = ${ParameterIndex}" -Source 'Process-SetupParameter'}

                ## Assemble Variable Name
                [string]${ParameterVariableName} = ${BaseVariableName},('{0:D2}' -f ${ParameterIndex}) -join '_'
                If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "[$(${ParameterVariableName}.GetType().Name)]`${ParameterVariableName} = ${ParameterVariableName}" -Source 'Process-SetupParameter'}

                If ( $InputObject.value -match '^(\d{1,5})$' ) { [System.Int32]${ParameterVariableVal} = ([int32]::Parse($InputObject.value)); }
                ElseIf ( ${Value}.ToString().ToLower() -match '(true|false)' ) { [System.Boolean]${ParameterVariableVal} = [System.Convert]::ToBoolean(${Value}); }
                Else { [System.String]${ParameterVariableVal} = $ExecutionContext.InvokeCommand.ExpandString($InputObject.value);}
                If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "ParameterVariableVal: $(${ParameterVariableVal})" -Source 'Process-SetupParameter'}

                ## Configure Both PArameter Types By Value Type and Setup Target
                If ( @([System.Boolean],[System.Management.Automation.SwitchParameter]) -contains ${ParameterVariableVal}.GetType() ) {
                    If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "Parameter Value is [BOOLEAN]" -Source ${CmdletName}}
                    Switch ( $InputObject.target ) {
                        'msi'{ 
                            If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "Target Is 'MSI', Value is '$($InputObject.variable)=`"$($InputObject.variable)=`"$(${ParameterVariableVal}.ToString().ToUpper())`"" -Source ${CmdletName}}
                            Set-Variable -Name ${ParameterVariableName} -Value "$($inputobject.variable)=`"$(${ParameterVariableVal}.ToString())`"" -Force -Scope 'Global' -Ea 'Stop';  
                            break; 
                        }
                        'ccm' { 
                            If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "Target Is 'CCM', Value is '/$($InputObject.variable)" -Source ${CmdletName}}
                            Set-Variable -Name ${ParameterVariableName} -Value "/$($InputObject.variable)" -Force -Scope 'Global' -Ea 'Stop';  
                            break; 
                        }
                    }
                }
                ElseIf ( @([System.String]) -contains ${ParameterVariableVal}.GetType() ) {
                    If ( ![string]::IsNullOrEmpty(${ParameterVariableVal}) ) {
                        If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "Parameter Value is [STRING]" -Source ${CmdletName}}
                        Switch ( $InputObject.target ) {
                            'msi'{ 
                                If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "Target Is 'MSI', Value is '$($InputObject.variable)=`"$(${ParameterVariableVal}.ToString().ToUpper())`"" -Source ${CmdletName}}
                                Set-Variable -Name ${ParameterVariableName} -Value "$($InputObject.variable)=`"$(${ParameterVariableVal}.ToString().ToUpper())`"" -Force -Scope 'Global' -Ea 'Stop';  
                                break;
                            }
                            'ccm' { 
                                If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "Target Is 'CCM', Value is '/$($InputObject.variable):$(${ParameterVariableVal})'" -Source ${CmdletName}}
                                Set-Variable -Name ${ParameterVariableName} -Value "/$($InputObject.variable):`"$(${ParameterVariableVal})`"" -Force -Scope 'Global' -Ea 'Stop';  break; }
                        }
                    }
                }
                ElseIf ( @([System.Int32]) -contains ${ParameterVariableVal}.GetType() ) {
                    If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "Parameter Value is [INT32]" -Source ${CmdletName}}
                    Switch ( $InputObject.target ) {
                        'msi'{
                            If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "Target Is 'MSI', Value is '$($InputObject.variable)=`"$(${ParameterVariableVal})`"'" -Source ${CmdletName}}
                            Set-Variable -Name ${ParameterVariableName} -Value "$($InputObject.variable)=`"$(${ParameterVariableVal})`"" -Force -Scope 'Global' -Ea 'Stop'; 
                            break;
                        }
                        'ccm' {
                            If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "Target Is 'CCM', Value is '/$($InputObject.variable):$(${ParameterVariableVal})'" -Source ${CmdletName}}
                            Set-Variable -Name ${ParameterVariableName} -Value "/$($InputObject.variable):$(${ParameterVariableVal})" -Force -Scope 'Global' -Ea 'Stop'; 
                            break;
                        }
                    }
                }
                Else {
                    If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "Parameter Value is [$(${ParameterVariableVal}.gETtYPE().Name)]" -Source ${CmdletName}}
                    Switch ( $InputObject.target ) {
                        'msi'{ 
                            If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "Target Is 'MSI', Value is '$($InputObject.variable)=`"$(${ParameterVariableVal}.ToString().ToUpper())`"'" -Source ${CmdletName}}
                            Set-Variable -Name ${ParameterVariableName} -Value "$($InputObject.variable)=`"$(${ParameterVariableVal}.ToString().ToUpper())`"" -Force -Scope 'Global' -Ea 'Stop';  break;}
                        'ccm' { 
                            If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "Target Is 'CCM', Value is '/$($InputObject.variable):$(${ParameterVariableVal})'" -Source ${CmdletName}}
                            Set-Variable -Name ${ParameterVariableName} -Value "/$($InputObject.variable):`"$(${ParameterVariableVal})`"" -Force -Scope 'Global' -Ea 'Stop';  break; 
                        }
                    }
                }

                ## Add Value To the Hashtable
                If ( Test-Path -Path "Variable:\$(${ParameterHashTableName})" ) {
                    If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "Hashtable Already Exists." -Source 'Process-SetupParameter' }

                    [hashtable]${ParameterObject} = Get-Variable -Name ${ParameterHashTableName} -ValueOnly;
                    If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "[$(${ParameterObject}.GetType().Name)]`${ParameterObject} = ${ParameterObject}" -Source 'Process-SetupParameter' }
                
                    If ( ${ParameterObject}.ContainsKey($InputObject.id) ) { ${ParameterObject}.$($InputObject.id) = ${ParameterVariableVal}; }
                    Else { ${ParameterObject}.Add($InputObject.id,${ParameterVariableVal}); }

                    Set-Variable -Name ${ParameterHashTableName} -Value ${ParameterObject} -Force -Scope Global;
                }
                Else {
                    If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "Create Hash Table." -Source 'Process-SetupParameter'  }
                    New-Variable -Name ${ParameterHashTableName} -Value @{$($InputObject.id) = ${ParameterVariableVal};} -Force -Scope 'Global'
                }
                Write-Log -Message "Added Global PS Parameter: [$($InputObject.id)]=[${ParameterVariableVal}]" -Source 'Process-SetupParameter' 
            
                Write-Log "------------------------------------- FINISH PARSE ON [$($inPUToBJECT.ID)] -------------------------------------" -Source 'Process-SetupParameter' 
                Write-Log "##############################################################################`r`n" -Source 'Process-SetupParameter'
            }
            Else { Write-Log -Message "Value For [$($InputObject.id)] is null." -Source 'Process-SetupParameter' }
        }
        Catch { Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)`r`n`r`n$(Resolve-Error)" -Source 'Process-SetupParameter' -Severity 2}
	}
    End { }
}
function Process-PrerequisiteParameter
{
	[CmdletBinding()]
	param
	(
        [Parameter(Mandatory=$true)]
        $InputObject
    )
	Begin 
    {
        [string]${CmdletName} = 'Process-PrerequisiteParameter'
        [pscustomobject]$CmdletDetails = New-Object -TypeName PSObject;
    }
    Process {
        Try {
            ## Check If Applicable
            Set-Variable -Name applicableString -Value $(Invoke-Expression -Command $($InputObject.Applicable)) -Force;
            If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "applicableString: $applicableString" -Source ${CmdletName}}

            Set-Variable -Name removeString -Value $(Invoke-Expression -Command "`$$($InputObject.remove)") -Force;
            If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "removeString: $removeString" -Source ${CmdletName}}
            
            Set-Variable -Name excludeString -Value $(Invoke-Expression -Command "`$$($InputObject.skip)") -Force;
            If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "excludeString: $excludeString" -Source ${CmdletName}}
            
            [System.Boolean]$IsApplicable = [System.Boolean]::Parse($applicableString)
            If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "IsApplicable: $IsApplicable" -Source ${CmdletName}}

            If ( !$IsApplicable ) {
                Throw "Prerequisite '$($InputObject.Path)' Is Not Applicable."
            }

            [string]$PreFilePath = $ExecutionContext.InvokeCommand.ExpandString($InputObject.filepath)
            If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "PreFilePath: $PreFilePath" -Source ${CmdletName}}

            [System.Boolean]$IsRemove = [System.Boolean]::Parse($removeString)
            If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "IsRemove: $IsRemove" -Source ${CmdletName}            }
            
            [System.Boolean]$IsExclude = [System.Boolean]::Parse($excludeString)
            If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "IsExclude: $IsExclude" -Source ${CmdletName}}

            Add-Member -InputObject $CmdletDetails -MemberType NoteProperty -Name 'Path' -Value $PreFilePath -Force;
            Add-Member -InputObject $CmdletDetails -MemberType NoteProperty -Name 'Remove' -Value $IsRemove -Force;
            Add-Member -InputObject $CmdletDetails -MemberType NoteProperty -Name 'Exclude' -Value $IsExclude -Force;

            foreach ( $ChildNode in @($InputObject.ChildNodes) ) {
                
                $addObject=Assemble-Cmdlet -InputObject $ChildNode
                If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "addObject: $($CHildNode.Name)::['$($addObject|fl * |out-string)']"}
                $CmdletDetails | Add-Member -MemberType NoteProperty -Name $ChildNode.Name -Value $addObject -Force;
            }

            trY{
                [int]$lastIndex = Get-Variable | ?{$_.Name -match 'CCM_PREREQ_\d{2}'}|sort -Descending -Property Name|select -first 1 -ExpandProperty name|%{ ([regex]'(\d{2})$').Matches($_)|select -first 1 -ExpandProperty Value }
            }
            catch{
                [int]$lastIndex = 0;
            }
            If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "lastIndex: $lastIndex" -Source ${CmdletName}}
            
            [int]$NewIndex = $lastIndex+1;
            If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "NewIndex: $NewIndex" -Source ${CmdletName}}

            [string]$VariableName = 'CCM_PREREQ_' + ('{0:D2}' -f $NewIndex)
            If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "VariableName: $VariableName" -Source ${CmdletName}}
            Set-Variable -Name $VariableName -Value $CmdletDetails -Force -Scope Global -Ea 'SilentlyContinue'
            
            If ( $IsExclude ) {

                trY{
                    [int]$lastIndex1 = Get-Variable | ?{$_.Name -match 'CCM_PREREQ_VALUE_\d{2}'}|sort -Descending -Property Name|select -first 1 -ExpandProperty name|%{ ([regex]'(\d{2})$').Matches($_)|select -first 1 -ExpandProperty Value }
                }
                catch{
                    [int]$lastIndex1 = 0;
                }
                If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "lastIndex1: $lastIndex1" -Source ${CmdletName}}

                [int]$NewIndex1 = $lastIndex1+1;
                If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "NewIndex1: $NewIndex1" -Source ${CmdletName}}

                [string]$PRVar = 'CCM_PREREQ_VALUE_' + ('{0:D2}' -f $NewIndex1)
                If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "PRVar: $PRVar" -Source ${CmdletName}}
                Set-Variable -Name $PRVar -Value $(Split-Path -Path $PreFilePath -Leaf) -Force -Scope Global -Ea 'SilentlyContinue'
            }

            
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 1
        }
	}
}
function Process-StartCommand
{
	[CmdletBinding()]
	param
	(
        [Parameter(Mandatory=$true)]
        $InputObject
    )
	Begin 
    {
	    [string]${CmdletName} = 'Process-StartCommand'
        #Write-Log -Message "InputObject: $($InputObject|fl *|out-string)" -Source ${CmdletName}
    }
    Process {
        Try {
            If ( [string]::IsNullOrEmpty($InputObject.variable) ) {
                [string]$Expression = $InputObject.command
            }
            Else {
                [string]$ExpressionValue = $ExecutionContext.InvokeCommand.ExpandString($InputObject.command);
                If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "ExpressionValue [$($ExpressionValue)]..." -Source ${CmdletName};}
                
                [string]$Expression = "Set-Variable -Name '$($InputObject.variable)' -Value ([$($InputObject.type)]`$($ExpressionValue)) -Force -Scope Global"
                Write-Log -Message "Executing Expression [$($Expression)]..." -Source ${CmdletName};
            }
            Invoke-Expression -Command $Expression
            #Write-Log -Message "Resulting Value: [$(Get-Variable -Name $InputObject.variable -ValueOnly -Scope 'Global')]." -Source ${CmdletName};
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 3
        }
	}
}
function Process-PostCommand
{
	[CmdletBinding()]
	param
	(
        [Parameter(Mandatory=$true)]
        $InputObject
    )
	Begin 
    {
	    [string]${CmdletName} = 'Process-PostCommand'
        #Write-Log -Message "InputObject: $($InputObject|fl *|out-string)" -Source ${CmdletName}
    }
    Process {
        Try {
            If ( [string]::IsNullOrEmpty($InputObject.variable) ) {
                [string]$Expression = $InputObject.command
            }
            Else {
                [string]$ExpressionValue = $ExecutionContext.InvokeCommand.ExpandString($InputObject.command);
                If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "ExpressionValue [$($ExpressionValue)]..." -Source ${CmdletName};}
                
                [string]$Expression = "Set-Variable -Name '$($InputObject.variable)' -Value ([$($InputObject.type)]`$($ExpressionValue)) -Force -Scope Global"
                Write-Log -Message "Executing Expression [$($Expression)]..." -Source ${CmdletName};
            }
            Invoke-Expression -Command $Expression
            #Write-Log -Message "Resulting Value: [$(Get-Variable -Name $InputObject.variable -ValueOnly -Scope 'Global')]." -Source ${CmdletName};
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 3
        }
	}
}
function Process-Variable
{
	[CmdletBinding()]
	param
	(
        [Parameter(Mandatory=$true)]
        $InputObject
    )
	Begin 
    {
	    
        #Write-Log -Message "InputObject: $($InputObject|fl *|out-string)" -Source ${CmdletName}
    }
    Process {
        Try {
            [string]${CmdletName} = $PsCmdlet.MyInvocation.MyCommand.Name;	
            $expandedValue = $ExecutionContext.InvokeCommand.ExpandString($InputObject.value)
            $convertedValue = Convert-Variable -InputObject $expandedValue -TypeString $InputObject.type
            [hashtable]$SetGlobalVariable = @{Force=[switch]::Present;Scope='Global';Name=$InputObject.id;Value=$convertedValue;}
            Write-Log -Message "Attempting To Set Global Variable [$($InputObject.id)]=[$($convertedValue;)]..." -Source ${cmdletname}
            Set-Variable @SetGlobalVariable;
            If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "Completed [$($?)]." -Source ${cmdletname}}
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 3
        }
	}
}
#endregion [Import Settings]
##*===============================================

#region [Main Execution]
<#
	.SYNOPSIS
		A brief description of the Get-CCMSetup function.
	
	.DESCRIPTION
		A detailed description of the Get-CCMSetup function.
	
	.PARAMETER Parameters
		A description of the Parameters parameter.
	
	.PARAMETER Remove
		Specifies that the System Center 2012 Configuration Manager client software should be uninstalled.
	
	.PARAMETER SourcePath
		Specifies the location from which to download installation files. You can use a local or UNC installation path. Files are downloaded by using the server message block (SMB) protocol.
	
	.PARAMETER ManagementPoint
		Specifies a source management point for computers to connect to so that they can find the nearest distribution point to download the client installation files. If there are no distribution points or computers cannot download the files from the distribution points after 4 hours, clients download the files from the specified management point.
		Computers download the files over an HTTP or HTTPS connection, depending on the site system role configuration for client connections. The download uses BITS throttling
	
	.PARAMETER RetryInterval
		Specifies the retry interval if CCMSetup.exe fails to download installation files. The default value is 10 minutes. CCMSetup continues to retry until it reaches the limit specified in the downloadtimeout installation property.
	
	.PARAMETER NoServiceAccount
		Prevents CCMSetup from running as a service. When CCMSetup runs as a service, it runs in the context of the Local System account of the computer, which might not have sufficient rights to access network resources that are required for the installation process. When you specify the /noservice option, CCMSetup.exe runs in the context of the user account that you use to start the installation process. Additionally, if you are use a script to run CCMSetup.exe with the /service property, CCMSetup.exe exits after
	
	.PARAMETER NoForce
		Specifies that the client installation should stop if any version of the System Center 2012 Configuration Manager or the Configuration Manager client is already installed.
	
	.PARAMETER ForceRestart
		Specifies that CCMSetup should force the client computer to restart if this is necessary to complete the client installation. If this option is not specified, CCMSetup exits when a restart is necessary, and then continues after the next manual restart.
	
	.PARAMETER Priority
		Specifies the download priority when client installation files are downloaded over an HTTP connection. Possible values are as follows:
		FOREGROUND
		HIGH
		NORMAL
		LOW
		The default value is NORMAL.
	
	.PARAMETER Timeout
		Specifies the length of time in minutes that CCMSetup attempts to download the client installation files before it gives up. The default value is 1440 minutes (1 day).
	
	.PARAMETER UseCertificate
		When specified, the client uses a PKI certificate that includes client authentication, if one is available. If a valid certificate cannot be found, the client falls back to using an HTTP connection and a self-signed certificate. When this option is not specified, the client uses a self-signed certificate and all communications to site systems are over HTTP.
	
	.PARAMETER SkipCRLCheck
		Specifies that a client should not check the certificate revocation list (CRL) when it communicates over HTTPS by using a PKI certificate.
		When this option is not specified, the client checks the CRL before establishing an HTTPS connection by using PKI certificates.
		For more information about client CRL checking, see Planning for PKI Certificate Revocation.
		Example: CCMSetup.exe /UsePKICert /NoCRLCheck
	
	.PARAMETER ConfigurationFile
		Specifies the name of a text file containing client installation properties. Unless you also specify the /noservice CCMSetup property, this file must be located in the CCMSetup folder, which is <%Windir%>\Ccmsetup for 32-bit and 64-bit operating systems. If you specify the /noservice property, this file must be located in the same folder from which you run CCMSetup.exe.
	
	.PARAMETER Reinstall
		For System Center 2012 Configuration Manager SP1 and later:
		Specify that any existing client will be uninstalled and then a new client will be installe
	
	.PARAMETER ExcludeFeatures
		A description of the ExcludeFeatures parameter.
	
	.PARAMETER ClientParameters
		A description of the ClientParameters parameter.
	
	.PARAMETER ForceInternetClient
		et to 1 to specify that the client will always be Internet-based and will never connect to the intranet. The client's connection type displays Always Internet.
		This property should be used in conjunction with CCMHOSTNAME, which specifies the FQDN of the Internet-based management point. It should also be used in conjunction with the CCMSetup property /UsePKICert and with the site code.
	
	.PARAMETER CertificateIssuers
		Specifies the certificate issuers list, which is a list of trusted root certification (CA) certificates that the Configuration Manager site trusts.
		
		This is a case-sensitive match for subject attributes that are in the root CA certificate. Attributes can be separated by a comma (,) or semi-colon (;). Multiple root CA certificates can be specified by using a separator bar. Example:
	
	.PARAMETER CertificateSelection
		Specifies the certificate selection criteria if the client has more than one certificate that can be used for HTTPS communication (a valid certificate that includes client authentication capability).
		
		You can search for an exact match in the Subject Name or Subject Alternative Name (use Subject:) or a partial match (use SubjectStr:), in the Subject Name or Subject Alternative Name. Examples:
	
	.PARAMETER CertificateStore
		Specifies an alternate certificate store name if the client certificate to be used for HTTPS communication is not located in the default certificate store of Personal in the Computer store.
	
	.PARAMETER FirstCertificate
		A description of the FirstCertificate parameter.
	
	.PARAMETER HostName
			
		
		Specifies the FQDN of the Internet-based management point, if the client is managed over the Internet.
		
		Do not specify this option with the installation property of SMSSITECODE=AUTO. Internet-based clients must be directly assigned to their Internet-based site.
	
	.PARAMETER HttpPort
		Specifies the port that the client should use when communicating over HTTP to site system servers.
		
		If the port is not specified, the default value of 80 will be used.
	
	.PARAMETER HttpsPort
		Specifies the port that the client should use when communicating over HTTPS to site system servers. If the port is not specified, the default value of 443 will be used.
	
	.PARAMETER PublicKey
		A description of the PublicKey parameter.
	
	.PARAMETER RootKey
		Used to reinstall the Configuration Manager trusted root key. Specifies the full path and file name to a file containing the trusted root key. This property applies to clients that use HTTP and HTTPS client communication. For more information, see Planning for the Trusted Root Key.
	
	.PARAMETER ResetKey
		If a System Center 2012 Configuration Manager client has the wrong Configuration Manager trusted root key and cannot contact a trusted management point to receive a valid copy of the new trusted root key, you must manually remove the old trusted root key by using this property. This situation commonly occurs when you move a client from one site hierarchy to another. This property applies to clients that use HTTP and HTTPS client communication.
	
	.PARAMETER DebugLogging
		Enables debug logging. Values can be set to 0 (off) or 1 (on). The default value is 0. This causes the client to log low-level information that might be useful for troubleshooting problems. As a best practice, avoid using this property in production sites because excessive logging can occur, which might make it difficult to find relevant information in the log files. CCMENABLELOGGING must be set to TRUE to enable debug logging.
	
	.PARAMETER EnableLogging
		Enables logging if this property is set to TRUE. By default, logging is enabled. The log files are stored in the Logs folder in the Configuration Manager Client installation folder. By default, this folder is %Windir%\CCM\Logs.
	
	.PARAMETER LogLevel
		Specifies the amount of detail to write to System Center 2012 Configuration Manager log files. Specify an integer ranging from 0 to 3, where 0 is the most verbose logging and 3 logs only errors. The default is 1.
	
	.PARAMETER MaximumLogs
		When a System Center 2012 Configuration Manager log file reaches 250000 bytes in size (or the value specified by the property CCMLOGMAXSIZE), it is renamed as a backup, and a new log file is created.
		
		This property specifies how many previous versions of the log file to retain. The default value is 1. If the value is set to 0, no old log files are kept.
	
	.PARAMETER MaximumLogSize
		Specifies the maximum log file size in bytes. When a log grows to the size that is specified, it is renamed as a history file, and a new file is created. This property must be set to at least 10000 bytes. The default value is 250000 bytes.
	
	.PARAMETER AllowSilentReboot
		Specifies that the computer is allowed to restart following the client installation, if this is required.
	
	.PARAMETER DisableSiteChange
		If set to TRUE, disables the ability of end users with administrative credentials on the client computer to change the Configuration Manager Client assigned site by using Configuration Manager in Control Panel of the client computer.
	
	.PARAMETER DisableCacheModify
		If set to TRUE, disables the ability of end users with administrative credentials on the client computer to change the client cache folder settings for the Configuration Manager Client by using Configuration Manager in Control Panel of the client computer.
	
	.PARAMETER CacheDirectory
		Specifies the location of the client cache folder on the client computer, which stores temporary files. By default, the location is %Windir \ccmcache.
	
	.PARAMETER CacheFlags
		Configures the System Center 2012 Configuration Manager cache folder, which stores temporary files. You can use SMSCACHEFLAGS properties individually or in combination, separated by semicolons. If this property is not specified, the client cache folder is installed according to the SMSCACHEDIR property, the folder is not compressed, and the SMSCACHESIZE value is used as the size in MB of the folder.
	
	.PARAMETER CacheSize
		Specifies the size of the client cache folder in megabyte (MB) or as a percentage when used with the PERCENTDISKSPACE or PERCENTFREEDISKSPACE property. If this property is not set, the folder defaults to a maximum size of 5120 MB. The lowest value that you can specify is 1 MB.
	
	.PARAMETER ConfigurationSource
		Specifies the location and order that the Configuration Manager Installer checks for configuration settings. The property is a string containing one or more characters, each defining a specific configuration source. Use the character values R, P, M, and U, alone or in combination, as shown in the following examples:
	
	.PARAMETER DirectoryLookup
		A description of the DirectoryLookup parameter.
	
	.PARAMETER CertificatePath
		Specifies the full path and .cer file name of the exported self-signed certificate on the site server.
		
		This certificate is stored in the SMS certificate store and has the Subject name Site Server and the friendly name Site Server Signing Certificate.
	
	.PARAMETER InitialManagementPoint
		Specifies an initial management point for the Configuration Manager client to use.
	
	.PARAMETER SiteCode
		Specifies the Configuration Manager site to assign the Configuration Manager client to. This can either be a three-character site code or the word AUTO. If AUTO is specified, or if this property is not specified, the client attempts to determine its Configuration Manager site assignment from Active Directory Domain Services or from a specified management point.
	
	.PARAMETER InstallationDirectory
		Identifies the folder where the Configuration Manager client files are installed. If this property is not set, the client software is installed in the %Windir%\CCM folder. Regardless of where these files are installed, the Ccmcore.dll file is always installed in the %Windir%\System32 folder. In addition, on 64-bit operating systems, a copy of the Ccmcore.dll file is always installed in the %Windir%\SysWOW64 folder to support 32-bit applications that use the 32-bit version of the Configuration Manager c
	
	.PARAMETER Administrators
		Specifies one or more Windows user accounts or groups to be given access to client settings and policies. This is useful where the System Center 2012 Configuration Manager administrator does not have local administrative credentials on the client computer. You can specify a list of accounts that are separated by semi-colons.
	
	.PARAMETER FallbackStatusPoint
		Specifies the fallback status point that receives and processes state messages sent by Configuration Manager client computers.
		
		For more information about the fallback status point, see Determine Whether You Require a Fallback Status Point.
	
	.PARAMETER DomainNameSuffix
		Specifies a DNS domain for clients to locate management points that are published in DNS. When a management point is located, it informs the client about other management points in the hierarchy. This means that the management point that is located by using DNS publishing does not have to be from the client's site, but can be any management point in the hierarchy.
	
	.PARAMETER EvaluationInterval
		Specifies the frequency when the client health evaluation tool (ccmeval.exe) runs. You can specify a value from 1 through 1440 minutes. If you do not specify this property, or specify an incorrect value, the evaluation will run once a day.
	
	.PARAMETER EvaluationHour
		Specify the hour when the client health evaluation tool (ccmeval.exe) runs. You can specify a value between 0 (midnight) and 23 (11pm). If you do not specify this property, or specify and incorrect value, the evaluation will run at midnight.
	
	.PARAMETER NoAppVCheck
		Specifies that the existence of the minimum required version of Microsoft Application Virtualization (App-V) is not checked before the client is installed.
	
	.PARAMETER NoRemediate
		Specifies that client status will report, but not remediate problems that are found with the Configuration Manager client.
	
	.EXAMPLE
		PS C:\> Invoke-CCMSetup
	
	.NOTES
		Additional information about the function.
#>

#endregion [Main Execution]
##*===============================================

##*===============================================
#region [Nomad]
##*===============================================
#region [Nomad]
Function Test-CMNomadCacheItem {
    [CmdletBinding()]
    [OutputType([boolean])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageID,

        [Parameter(Mandatory=$false)]
        [ValidateRange(1,100)]
        [Int32]$PackageVersion
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [boolean]$ReturnValue = $false;
    }
    Process {
        Try {
                $Results = @();
                Get-CMNomadCache -PackageID $PackageID | % {  
                    If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey($PackageVersion)){If ( $_.Version -eq $PackageVersion ) {$Results += $_}}
                    Else { $Results += $_; }
                }

                [boolean]$ReturnValue = $Results.Count -gt 0;
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
    End {
        Write-Output -InputObject $ReturnValue
    }
}
Function Get-CMNomadCacheItemPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageID
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [string]$ReturnValue =[string]::Empty;
    }
    Process {
        Try {
            If ( !(Test-CMNomadCacheItem -PackageID $PackageID )) {Throw "Nomad Cache Item '$PackageID' Does Not Exist.";}
            
            [PSObject]$CacheObject = Get-CMNomadCache -PackageID $PackageID | Select-Object -First 1;
            Write-Log -Message "CacheObject: $($CacheObject|fl *|out-string)" -Source ${CmdletName}

            If ( $CacheObject.psobject.properties.name -contains 'CacheToFolder' -and ![string]::IsNullOrEmpty($CacheObject.CacheToFolder)) {[string]$SearchDirectory = $CacheObject.CacheToFolder}
            Else {[string]$SearchDirectory = Get-CMNomadCacheDirectory}
            Write-Log -Message "SearchDirectory: $($SearchDirectory)" -Source ${CmdletName}

            [string]$ReturnValue = Get-ChildItem -Path $SearchDirectory -Filter "$($PackageID)_Cache" -Force | ? { $_.PSIsContainer } | Select-Object -First 1 -ExpandProperty 'FullName'

        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
    End {
        Write-Output -InputObject $ReturnValue
    }
}
Function Test-CMNomadCacheContent {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path -Path $_})]
        [string]$NomadRegistrySettings = 'HKLM:\SOFTWARE\1E\NomadBranch',

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path -Path $_})]
        [string]$NomadCache = $(Get-CMNomadCacheDirectory)
    )
    Begin
    {

        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [bool]$ReturnValue = $false;
        [object[]]$Result = @();
    }
    Process
    {
        Try {
            [string[]]$RegisteredPaths = Get-CMNomadCache | %{
                If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Debug')){Write-Log -Message "Cache Item: [$($_ | fl *|out-string)]" -Source ${CmdletName}}
#                If ( ![string]::IsNullOrEmpty($_.CacheToFolder) ) {
                If ( $_.PSObject.Properties.Name -contains 'CacheToFolder') {
                    Join-Path -Path $_.CacheToFolder -ChildPath "$($_.PackageID)_Cache"
                }
                Else {
                    Join-Path -Path $NomadCache -ChildPath "$($_.PackageID)_Cache"
                }
            }
            Write-Log -Message "Cache Item Count $($RegisteredPaths.Count)" -Source ${CmdletName}
            
            $RegisteredPaths | ? {
                Write-Log -Message "Test Path '$($_)'..." -Source ${CmdletName}
                !( Test-Path -Path $_ )
            } |  %{
                Write-Log -Message "Path Doesn't Exist '$($_)'" -Source ${CmdletName}
                $Result += $_
            }
            Write-Log -Message "Result Count $($Result.Count)" -Source ${CmdletName}

            [bool]$ReturnValue = $Result.Count -eq 0
        }
        Catch
        {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
    End {
        Write-Output -InputObject $ReturnValue
    }
}
Function Get-CMNomadCache {
    [CmdletBinding()]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path -Path $_})]
        [string]$NomadRegistrySettings = 'HKLM:\SOFTWARE\1E\NomadBranch\PkgStatus',

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageID
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [psobject[]]$ReturnValue = @();
    }
    Process {
        Try {
                If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey($PackageID) ){
                    [string]$Filter = $PackageID
                }  Else {[string]$Filter = '*'}

                Get-ChildItem -Path $NomadRegistrySettings | %{
                    [string]$KeyPath = $_.Name
                    Get-RegistryKey -Key $KeyPath -ContinueOnError $true | `
                        %{$_|Add-Member -MemberType 'NoteProperty' -Name 'PackageID' -Value $_.PSChildName -Force -PassThru} | `
                        Select -Property * -ExcludeProperty 'PS*' |`
                        ?{ $_.PackageID -like $Filter} | `
                        %{$ReturnValue += $_}
                        
                }
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
        Finally {

        }
    }
    End {
        Write-Output -InputObject $ReturnValue
    }
}
Function Clear-CMNomadCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path -Path $_})]
        [string]$CacheCleaner = "$env:programfiles\1E\NomadBranch\CacheCleaner.exe"    
    )
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [bool]$ReturnValue = $false;
    }
    Process
    {
        Try {
            $CleanerProcess = Execute-CacheCleaner -All -ForceLevel 9;
            Write-Log -Message "CleanerProcess: $($CleanerProcess|fl *|out-string)" -Source ${CmdletName}
        }
        Catch
        {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
}
Function Repair-CMNomadCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path -Path $_})]
        [string]$NomadRegistrySettings = 'HKLM:\SOFTWARE\1E\NomadBranch',

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path -Path $_})]
        [string]$NomadCache = $(Get-CMNomadCacheDirectory)
    )
    Begin
    {

        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [bool]$ReturnValue = $false;
        [string]$RegNomadPkgStatus = Join-Path -Path $NomadRegistrySettings -ChildPath 'PkgStatus'
        
        [object[]]$Result = @();
    }
    Process
    {
        Try {
            [string[]]$RegisteredPaths = Get-CMNomadCache | %{
                If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Debug')){Write-Log -Message "Cache Item: [$($_ | fl *|out-string)]" -Source ${CmdletName}}
                If ( ![string]::IsNullOrEmpty($_.CacheToFolder) ) {
                    Join-Path -Path $_.CacheToFolder -ChildPath "$($_.PackageID)_Cache"
                }
                Else {
                    Join-Path -Path $NomadCache -ChildPath "$($_.PackageID)_Cache"
                }
            }
            Write-Log -Message "Cache Item Count $($RegisteredPaths.Count)" -Source ${CmdletName}
            
            $RegisteredPaths | ? {
                Write-Log -Message "Test Path '$($_)'..." -Source ${CmdletName}
                !( Test-Path -Path $_ )
            } |  %{
                Write-Log -Message "Path Doesn't Exist '$($_)'" -Source ${CmdletName}
                [string]$PkgID = $(Split-Path -Leaf -Path $_) -replace '_Cache$','';
                Write-Log -Message "PkgID: '$PkgID'" -Source ${CmdletName}

                [string]$RegPath = Join-Path -Path $RegNomadPkgStatus -ChildPath $PkgID
                Write-Log -Message "Removing Registry Key: '$RegPath'" -Source ${CmdletName}

                Remove-RegistryKey -Key $RegPath -Recurse -ContinueOnError $true -Ea 'SilentlyContinue';
            }

            Execute-Process -Path "$Env:ProgramFiles\1E\NomadBranch\Nomadbranch.exe" -Parameters '--ActivateAll' -CreateNoWindow -PassThru -ContinueOnError $true;
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }

}
Function Get-CMNomadCacheDirectory {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path -Path $_})]
        [string]$NomadRegistrySettings = 'HKLM:\SOFTWARE\1E\NomadBranch'
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [string[]]$ReturnValue = @();
    }
    Process {
        Try {
            [string]$ReturnValue = Get-RegistryKey -Key $NomadRegistrySettings -Value 'LocalCachePath' -ContinueOnError $true;
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
    End {
        Write-Output -InputObject $ReturnValue
    }
}
Function Set-CMNomadCacheSize {
	[CmdletBinding()]
	Param (
        [Parameter(Mandatory=$false,Position=0)]
		[ValidateNotNullorEmpty()]
		[int]$TargetPercentage = -1
	)
	
	Begin 
{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [string]$NomadRegPath = 'HKEY_LOCAL_MACHINE\SOFTWARE\1E\NomadBranch'
        [string]$RegValue = 'PercentAvailableDisk'
	    Stop-ServiceAndDependencies -Name 'NomadBranch' -PassThru -ContinueOnError $true -ErrorAction 'SilentlyContinue'
    }
	Process 
    {
		Try  {
            If ( $TargetPercentage -lt 0 ) {  
                [int]$CurrentPercentage = Get-RemoteRegistryKey -ComputerName $ComputerName -Path $NomadRegPath -Properties $RegValue| Select-Object -ExpandProperty $RegValue -First 1
                Write-Log -Message "CurrentPercentage: $CurrentPercentage" -Source ${CmdletName}
                [int]$TargetPercentage = $CurrentPercentage - 1
            }
            Write-Log -Message "TargetPercentage: $TargetPercentage" -Source ${CmdletName}
            Set-RegistryKey -Key $NomadRegPath -Name $RegValue -Value $TargetPercentage -Type DWord -ContinueOnError $true;
		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message)`n$(Resolve-Error)" -Severity 2 -Source ${CmdletName}
		}
	}
	End 
    {
		Start-ServiceAndDependencies -Name NomadBranch -PassThru -ContinueOnError $true -ErrorAction 'SilentlyContinue'
	}
}
<#
	.SYNOPSIS
		A brief description of the Execute-SMSNomad function.
	
	.DESCRIPTION
		A detailed description of the Execute-SMSNomad function.
	
	.PARAMETER Standalone
		This standalone mode option should be used when running Nomad independently of Configuration Manager. The --pp package path option is mandatory if this option is used. This value is set for the duration of the program.
	
	.PARAMETER CachePath
		Can be used to override the cache path (destination directory) of the download. This does not support peer sharing. As the new CachePath location is not shared, peer machines will not be able to copy from this cache. This feature is suitable for bandwidth throttled downloads to single machines. This value is set for the duration of the program.
	
	.PARAMETER Format
		The format in which data is downloaded from the DP/peer. Values are:
		0 – Original
		1 – Compressed
		2 – Encrypted and compressed
	
	.PARAMETER PackageHash
		The hash for the package to download and used to verify the integrity of the package on the DP.
	
	.PARAMETER HashFirst
		Stands for hash first. If the package is partially available in the local cache, causes a hash check to run on it. If the hash check passes, the cached package is used and no download occurs. Since hash check runs by default on fully downloaded packages, this switch is relevant only for partially downloaded content.
	
	.PARAMETER NoInstall
		Causes SMSNomad to quit immediately after downloading the package instead of waiting for the package command line to finish.
	
	.PARAMETER Multicast
		Specifies that this package may be multicast if required. If multicast is not licensed, a warning is logged and the standard peer-to-peer functionality used. This value is set for the duration of the program.
	
	.PARAMETER NoP2P
		Turns peer-to-peer communications off for the duration of the current package transfer.
	
	.PARAMETER PackageID
		Package identifier for the package to download.
	
	.PARAMETER PackagePath
		Sets PackagePath to be the directory containing the source files to be downloaded prior to installation. This value is set for the duration of the program. Supported in standalone mode only.
	
	.PARAMETER PackageVersion
		Version of the package to download.
	
	.PARAMETER SkipExecution
		A description of the SkipExecution parameter.
	
	.PARAMETER Duration
		Duration (in seconds) after which the download will time out.
	
	.PARAMETER CachePriority
		Priority for keeping the cache. Use values between 1 (lowest priority) and 9 (highest priority).
		
		If 0 is specified, then the default 1 is used.
	
	.PARAMETER InstallCommandLine
		command-line required for the target installation
	
	.PARAMETER DownloadOnly
		This option enables Nomad to download a package without the need to run any executable in the package. Supported in standalone mode only
	
	.EXAMPLE
		PS C:\> Execute-SMSNomad
	
	.OUTPUTS
		System.Management.Automation.PSObject, System.Management.Automation.PSObject
	
	.NOTES
		Additional information about the function.
#>
function Execute-SMSNomad {
	[CmdletBinding(DefaultParameterSetName = 'SMSMode')]
	[OutputType([System.Management.Automation.PSObject], ParameterSetName = 'SMSMode')]
	[OutputType([System.Management.Automation.PSObject], ParameterSetName = 'StandaloneMode')]
	param
	(
		
		[Parameter(ParameterSetName = 'SMSMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 0)]
		[Parameter(ParameterSetName = 'StandaloneMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 0)]
		[AllowNull()]
		[AllowEmptyString()]
		[Alias('Command')]
		[string]$InstallCommandLine,

		[Parameter(ParameterSetName = 'StandaloneMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $false,ValueFromRemainingArguments = $false,Position = 1)]
		[Alias('s')]
		[switch]$Standalone = $false,

		[Parameter(ParameterSetName = 'StandaloneMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 2)]
		[AllowNull()]
		[AllowEmptyString()]
		[ValidatePattern('^([A-Za-z]:\\)(.*)')]
        [ValidateScript({Test-Path -Path $_})]
		[Alias('cp')]
		[string]$CachePath,

		[Parameter(ParameterSetName = 'SMSMode', Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 1)]
		[Parameter(ParameterSetName = 'StandaloneMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 3)]
		[ValidateSet('Original', 'Compressed', 'Encrypted', IgnoreCase = $true)]
		[Alias('df')]
		[string]$Format = 'Original',

		[Parameter(ParameterSetName = 'SMSMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 2)]
		[Parameter(ParameterSetName = 'StandaloneMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 4)]
		[AllowNull()]
		[AllowEmptyString()]
		[Alias('hash')]
		[string]$PackageHash,

		[Parameter(ParameterSetName = 'SMSMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 3)]
		[Parameter(ParameterSetName = 'StandaloneMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 5)]
		[Alias('hf')]
		[switch]$HashFirst = $false,

		[Parameter(ParameterSetName = 'SMSMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 4)]
		[Parameter(ParameterSetName = 'StandaloneMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false, Position = 6)]
		[Alias('inst')]
		[switch]$NoInstall = $false,

		[Parameter(ParameterSetName = 'SMSMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 5)]
		[Parameter(ParameterSetName = 'StandaloneMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 7)]
		[Alias('mc')]
		[switch]$Multicast = $false,

		[Parameter(ParameterSetName = 'SMSMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 6)]
		[Parameter(ParameterSetName = 'StandaloneMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 8)]
		[Alias('p2p')]
		[switch]$NoP2P = $false,

        [Parameter(ParameterSetName = 'SMSMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 7)]
		[Parameter(ParameterSetName = 'StandaloneMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 9)]
		[ValidateNotNullOrEmpty()]
		[Alias('pkgid')]
		[string]$PackageID,

		[Parameter(ParameterSetName = 'StandaloneMode',Mandatory = $false,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $false,ValueFromRemainingArguments = $false,Position = 10)]
		[AllowEmptyString()]
		[AllowNull()]
		[Alias('pp')]
		[string]$PackagePath,

		[Parameter(ParameterSetName = 'SMSMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 8)]
        [Parameter(ParameterSetName = 'StandaloneMode',Mandatory = $false,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $false,ValueFromRemainingArguments = $false,Position = 11)]
		[ValidateRange(0, 100)]
		[Alias('ver')]
		[int]$PackageVersion,

		[Parameter(ParameterSetName = 'StandaloneMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 12)]
		[Alias('prestage')]
		[switch]$SkipExecution = $false,

		[Parameter(ParameterSetName = 'SMSMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 9)]
		[Parameter(ParameterSetName = 'StandaloneMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 13)]
		[ValidateRange(0, 1000000)]
		[Alias('timeout')]
		[int]$Duration,

		[Parameter(ParameterSetName = 'SMSMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 10)]
		[Parameter(ParameterSetName = 'StandaloneMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 14)]
		[ValidateRange(1, 9)]
		[Alias('pc')]
		[int]$CachePriority = 1,

		[Parameter(ParameterSetName = 'SMSMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 11)]
		[Parameter(ParameterSetName = 'StandaloneMode',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 15)]
        [switch]$PassThru = $false
	)
	
	Begin {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [hashtable]$CmdletBoundParameters = $PSCmdlet.MyInvocation.BoundParameters
        [string[]]$SMSNomadParameters = @('--//');
        [hashtable]$ExecuteProcess = @{CreateNoWindow=[switch]::Present;PassThru=[switch]::Present;ContinueOnError=$true;};
        [string[]]$NonStandardParameters = @(@(Get-PSCommonParameterNames) + @('InstallCommandLine','Format') )
	}
	Process {
		Try {
			[string]$NomadDirectory = Get-InstalledApplication -Name "(1E NomadBranch){1}( x64)?" -RegEx | ?{![string]::IsNullOrEmpty($_.InstallLocation)} |%{$_.InstallLocation.TrimEnd('\')}|Select-Object -first 1
            Write-Log -Message "NomadDirectory: $NomadDirectory" -Source ${CmdletName}

            If ( [string]::IsNullOrEmpty($NomadDirectory)) { Throw "Could Not Find 1E Nomad Branch Installed. Required To Run This Cmdlet." }
            Else { $ExecuteProcess.Add('WorkingDirectory',$NomadDirectory); }

            [string]$SMSNomad = Get-ChildItem -Path $NomadDirectory -Filter "SMSNomad.exe" | Select-Object -ExpandProperty FullName -First 1;
            Write-Log -Message "SMSNomad: $SMSNomad" -Source ${CmdletName}

            If ( [string]::IsNullOrEmpty($SMSNomad)) { Throw "Could Not Find 'SMSNomad.exe' in '$NomadDirectory'" }
            Else { $ExecuteProcess.Add('Path',$SMSNomad) }

            ## Clean Bound Parameters
            $NonStandardParameters | ?{$CmdletBoundParameters.ContainsKey($_)} | %{Write-Log -Message "Remove Key '$($_)'" -Source ${CmdletName}; $CmdletBoundParameters.Remove($_); }

            ## Parse Formt Parameter
            Switch ($Format.ToLower()) {'original'{[int]$FormatInt = 0; break;}'compressed'{[int]$FormatInt = 1; break;}'encrypted'{[int]$FormatInt = 2; break;}default {[int]$FormatInt = 0; break;}}
            Write-Log -Message "FormatInt: $FormatInt" -Source ${CmdletName}

            ## Add Format Parameter To Param Array
            $SMSNomadParameters+=('--df='+$FormatInt)

            ## Store Current Command Object as Object
            $ParameterObject = $(Get-Command -Name ${CmdletName})

            ## Enumerate Given Parameters
            Foreach ( $Parameter in $CmdletBoundParameters.Keys){
                
                ## Get Parameter Alias
                [string]$Alias = Get-CmdletParameterAlias -CommandObject $ParameterObject -ParameterName $Parameter

                ## Get Parameter Type
                [system.type]$Type = Get-CmdletParameterType -CommandObject $ParameterObject -ParameterName $Parameter
                Write-Log -Message "Parameter(Alias): [$($Type.Name)]$Parameter($Alias)" -Source ${CmdletName}

                ## Translate Parameter to cmd
                Switch ( $Type ){
                    $([string]){ 
                        [string]$ParameterString = '--' + $Alias + "=`""+$($CmdletBoundParameters.$Parameter)+"`""
                        break;
                    }
                    $([switch]){
                        [string]$ParameterString = '--' + $Alias
                    }
                    $([int]){
                        [string]$ParameterString = '--' + $Alias + "="+$($CmdletBoundParameters.$Parameter)
                    }
                    default{
                        [string]$ParameterString = '--' + $Alias + "=`""+$($CmdletBoundParameters.$Parameter)+"`""
                        break;
                    }
                }
                Write-Log -Message "ParameterString: $ParameterString" -Source ${CmdletName}

                ## Add to Parameter Array
                $SMSNomadParameters+=$ParameterString
            }
            ## Add Install Command Line
            If ( ![string]::IsNullOrEmpty($InstallCommandLine)){$SMSNomadParameters += $InstallCommandLine}
            Write-Log -Message "SMSNomadParameters: [$($SMSNomadParameters -join ' ')]" -Source ${CmdletName}

            ## Add Parameters to Hashtable
            $ExecuteProcess.Add('Parameters',$SMSNomadParameters);
            Write-Log -Message "Execute-Process Parameters: [$($ExecuteProcess| fl *|Out-String)]" -Source ${CmdletName}

            Write-Log -Message "Invoking SMSNomad.exe..." -Source ${CmdletName}
            [System.Management.Automation.PSObject]$ReturnValue = Execute-Process @ExecuteProcess;
            Write-Log -Message "Process Return: $($ReturnValue|fl *|out-string)" -Source ${CmdletName}
            
		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message)`n$(Resolve-Error)" -Severity 2 -Source ${CmdletName}
		}
	}
	End {
        If ( $PassThru ) {
            
            [string]$ItemPath = Get-CMNomadCacheItemPath -PackageID $PackageID;
            Write-Log -Message "ItemPath: $ItemPath" -Source ${CmdletName}
            [PSObject]$ReturnValue = Get-Item -Path $ItemPath;
        }
        Write-Output -InputObject $ReturnValue
	}
}
<#
	.SYNOPSIS
		A brief description of the Execute-CacheCleaner function.
	
	.DESCRIPTION
		CacheCleaner.exe Version 6.0.200.25891(Jan 29 2016)
		Usage: CacheCleaner [<-Options>]
		where:
		  [-help]                      : Displays help
		  [-debug=<dbg>]               : Increase logging lev
		  [-DeletePkg=<package id>]    : Deletes a single cac
		  [-PkgVer=n]                  : Required when using
		e version.
		  [-DeleteAll]                 : Deletes all cache fo
		  [-MaxCacheAge=<maxage>]      : Deletes cache folder
		                                 <maxage> in days, be
		  [-PercentAvailableDisk=[1-80]: Deletes lowest keep
		l Percent
		                                 Available disk is re
		  [-PkgSize=<pkgsize>]         : Used to reserve suff
		y remove
		                                 existing cache conte
		  [-Force=<1-9>]               : Folders created usin
		 removed
		                                 upt to and including
		  [-CachePriority=<1-9>]       : Used with -PkgSize,
		 or lower
		                                 CachePriority will b
		
		Examples:
		  CacheCleaner.exe -PercentAvailableDisk=10
		  
	
	.PARAMETER PackageID
		Deletes a single cache folder.
	
	.PARAMETER All
		Deletes all cache folders
	
	.PARAMETER MaximumAge
		Deletes cache folders older than <maxage> in days, between 1 and 1462
	
	.PARAMETER PackageSize
		Used to reserve sufficient cache space, this may remove existing cache content
	
	.PARAMETER PackageVersion
		Required when using -DeletePkg where n = Package version.
	
	.PARAMETER AvailableDiskPercentage
		Deletes lowest keep priority cache folders until Percent Available disk is reached.
	
	.PARAMETER Priority
		Used with -PkgSize, only cachecontent with this or lower CachePriority will be removed.
	
	.PARAMETER ForceLevel
		olders created using the --kc=n option will be removed upt to and including n where n=1-9.
	
	.EXAMPLE
		PS C:\> Execute-CacheCleaner -PackageID 'Value1'
	
	.OUTPUTS
		System.Management.Automation.PSObject
	
	.NOTES
		Additional information about the function.
#>
function Execute-CacheCleaner {
	[CmdletBinding(DefaultParameterSetName = 'ByID')]
	[OutputType([System.Management.Automation.PSObject], ParameterSetName = 'ByPct')]
	[OutputType([System.Management.Automation.PSObject], ParameterSetName = 'BySize')]
	[OutputType([System.Management.Automation.PSObject], ParameterSetName = 'ByAge')]
	[OutputType([System.Management.Automation.PSObject], ParameterSetName = 'ByAll')]
	[OutputType([System.Management.Automation.PSObject], ParameterSetName = 'ByID')]
	[OutputType([System.Management.Automation.PSObject])]
	param
	(
		[Parameter(ParameterSetName = 'ByID',Mandatory = $true,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 0)]
		[ValidateNotNullOrEmpty()]
		[Alias('DeletePkg')]
		[string]$PackageID,

		[Parameter(ParameterSetName = 'ByAll',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 0)]
		[Alias('DeleteAll')]
		[switch]$All,

		[Parameter(ParameterSetName = 'ByAge',Mandatory = $true,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 0)]
		[ValidateRange(1, 1462)]
		[ValidateNotNullOrEmpty()]
		[Alias('MaxCacheAge')]
		[int32]$MaximumAge,

		[Parameter(ParameterSetName = 'BySize',Mandatory = $true,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 0)]
		[ValidateNotNullOrEmpty()]
		[Alias('PkgSize')]
		[int32]$PackageSize,

		[Parameter(ParameterSetName = 'ByID',Mandatory = $true,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 1)]
		[ValidateRange(0, 100)]
		[ValidateNotNullOrEmpty()]
		[Alias('PkgVer')]
		[int32]$PackageVersion,

		[Parameter(ParameterSetName = 'ByPct',Mandatory = $true,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 0)]
		[ValidateRange(1, 80)]
		[ValidateNotNullOrEmpty()]
		[Alias('PercentAvailableDisk')]
		[int32]$AvailableDiskPercentage,

		[Parameter(ParameterSetName = 'BySize',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 1)]
		[ValidateRange(1, 9)]
		[ValidateNotNullOrEmpty()]
		[Alias('CachePriority')]
		[int32]$Priority,

		[Parameter(ParameterSetName = 'ByPct',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 1)]
		[Parameter(ParameterSetName = 'ByAll',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 1)]
		[Parameter(ParameterSetName = 'ByID',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 2)]
		[Parameter(ParameterSetName = 'ByAge',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 1)]
		[Parameter(ParameterSetName = 'BySize',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 2)]
		[ValidateRange(1, 9)]
		[ValidateNotNullOrEmpty()]
		[Alias('Force')]
		[int32]$ForceLevel
	)
	
	Begin {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [hashtable]$CmdletBoundParameters = $PSCmdlet.MyInvocation.BoundParameters
        [string[]]$CCParameters = @();
        [hashtable]$ExecuteProcess = @{CreateNoWindow=[switch]::Present;PassThru=[switch]::Present;ContinueOnError=$true;};
        [string[]]$NonStandardParameters = @(@(Get-PSCommonParameterNames) )
	}
	Process {
		Try {
			[string]$NomadDirectory = Get-InstalledApplication -Name "(1E NomadBranch){1}( x64)?" -RegEx | ?{![string]::IsNullOrEmpty($_.InstallLocation)} |%{$_.InstallLocation.TrimEnd('\')}|Select-Object -first 1
            Write-Log -Message "NomadDirectory: $NomadDirectory" -Source ${CmdletName}

            If ( [string]::IsNullOrEmpty($NomadDirectory)) { Throw "Could Not Find 1E Nomad Branch Installed. Required To Run This Cmdlet." }
            Else { $ExecuteProcess.Add('WorkingDirectory',$NomadDirectory); }

            [string]$CacheCleaner = Get-ChildItem -Path $NomadDirectory -Filter "CacheCleaner.exe" | Select-Object -ExpandProperty FullName -First 1;
            Write-Log -Message "CacheCleaner: $CacheCleaner" -Source ${CmdletName}

            If ( [string]::IsNullOrEmpty($CacheCleaner)) { Throw "Could Not Find 'CacheCleaner.exe' in '$NomadDirectory'" }
            Else { $ExecuteProcess.Add('Path',$CacheCleaner) }

            ## Clean Bound Parameters
            $NonStandardParameters | ?{$CmdletBoundParameters.ContainsKey($_)} | %{Write-Log -Message "Remove Key '$($_)'" -Source ${CmdletName}; $CmdletBoundParameters.Remove($_); }
            ## Store Current Command Object as Object
            $ParameterObject = $(Get-Command -Name ${CmdletName})

            ## Enumerate Given Parameters
            Foreach ( $Parameter in $CmdletBoundParameters.Keys){
                
                ## Get Parameter Alias
                [string]$Alias = Get-CmdletParameterAlias -CommandObject $ParameterObject -ParameterName $Parameter

                ## Get Parameter Type
                [system.type]$Type = Get-CmdletParameterType -CommandObject $ParameterObject -ParameterName $Parameter
                Write-Log -Message "Parameter(Alias): [$($Type.Name)]$Parameter($Alias)" -Source ${CmdletName}

                ## Translate Parameter to cmd
                Switch ( $Type ){
                    $([string]){ 
                        [string]$ParameterString = '-' + $Alias + "=`""+$($CmdletBoundParameters.$Parameter)+"`""
                        break;
                    }
                    $([switch]){
                        [string]$ParameterString = '-' + $Alias
                        break;
                    }
                    $([int]){
                        [string]$ParameterString = '-' + $Alias + "="+$($CmdletBoundParameters.$Parameter)
                        break;
                    }
                    default{
                        [string]$ParameterString = '-' + $Alias + "=`""+$($CmdletBoundParameters.$Parameter)+"`""
                        break;
                    }
                }
                Write-Log -Message "ParameterString: $ParameterString" -Source ${CmdletName}

                ## Add to Parameter Array
                $CCParameters+=$ParameterString
            }
            ## Add Install Command Line
            Write-Log -Message "CCParameters: [$($CCParameters -join ' ')]" -Source ${CmdletName}

            ## Add Parameters to Hashtable
            $ExecuteProcess.Add('Parameters',$CCParameters);
            Write-Log -Message "Execute-Process Parameters: [$($ExecuteProcess| fl *|Out-String)]" -Source ${CmdletName}

            Write-Log -Message "Invoking SMSNomad.exe..." -Source ${CmdletName}
            [System.Management.Automation.PSObject]$ReturnValue = Execute-Process @ExecuteProcess;
            Write-Log -Message "Process Return: $($ReturnValue|fl *|out-string)" -Source ${CmdletName}
            
		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message)`n$(Resolve-Error)" -Severity 2 -Source ${CmdletName}
		}
	}
	End {
        Write-Output -InputObject $ReturnValue
	}
}
#endregion [Nomad]
##*===============================================
#endregion [Nomad]
##*===============================================

##*===============================================
#region [Client Install/Uninstall]
Function Uninstall-CMPrerequisites {
	[CmdletBinding()]
	param (
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [psobject[]]$Products = $(Get-LoadedPrereqParameters | ? { [System.Boolean]::Parse($_.Value.Remove) }|Select -ExpandProperty 'Value')
    )
	Begin  {
	    [string]${CmdletName} = $PsCmdlet.MyInvocation.MyCommand.Name;	
        Write-FunctionHeaderOrFooter -Header -CmdletName ${CmdletName} -CmdletBoundParameters $PsCmdlet.MyInvocation.BoundParameters
    }
    Process {
        Try {
            [int]$Count = 0;
            Foreach ( $Product in  $Products) {
                $Count++
                $DetectResult = $Product.Detect.Execute();
                 If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "DetectResult: $DetectResult" -Source ${CmdletName};}
                 If ( $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose') ) {Write-Log -Message "DetectResult.GetType(): $($DetectResult.GetType().Name)" -Source ${CmdletName};}

                If ( $DetectResult.Stdout -match '(true|false)' ) {
                    [bool]$ProductDetected = [System.convert]::ToBoolean($DetectResult);    
                }
                Else {
                    [bool]$ProductDetected = $true
                }

                
                Write-Log -Message "ProductDetected: $ProductDetected" -Source ${CmdletName};
                If ( $ProductDetected ) {
                    Write-Log -Message "Invoking Method 'Execute()' For Uninstall of $(Split-Path -Path $Product.Path -Leaf)" -Source ${CmdletName};
                    $ResultObject = $Product.Uninstall.Execute()
                    Write-Log -Message "ResultObject:[$($ResultObject|fl * |out-string)]" -Source ${CmdletName};
                }
                Else {
                    Write-Log -Message "Prerequisite Not Detected." -Source ${CmdletName};
                }
            }
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        }
	}
    End {
        Write-Output -InputObject $ReturnValue
    }
}
Function Uninstall-CMClientProduct {
    [CmdletBinding()]
    Param()
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process {
        Try  
        {  
            Write-Log -Message "Removing MSI Product 'Configuration Manager Client'..." -Source ${CmdletName}
            Remove-MSIApplications -Name 'Configuration Manager Client' -Exact -PassThru -ContinueOnError $true|Out-Null;
            Write-Log -Message "Done." -Source ${CmdletName}
            
            Get-InstalledApplication -Name 'Configuration Manager Client' -Exact | %{
                Write-Log -Message "Removing MSI Product '$($_.ProductCode)'..." -Source ${CmdletName}    
                Execute-Msi -Action Uninstall -Path $_.ProductCode -PassThru;
                Write-Log -Message "Done." -Source ${CmdletName}
            }
        } 
        Catch  { Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 3 } 
    }
}
Function Clean-CMClientUninstall {
    [CmdletBinding()]
    [OutputType([PSObject])]
    Param(
        [Parameter(Position =0, Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path -Path $_})]
        [string]$CCMCleanExePath = $(Get-ChildItem -Path $dirSupportFiles -Force -Recurse -Filter 'ccmclean.exe' | select -first 1 -expandproperty fullname),

        [Parameter(Position =1, Mandatory=$false)]
        [string[]]$Arguments = @($global:CCM_CLEAN_PARAMETERS.Split(','))
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [psobject]$ReturnValue = New-Object -TypeName PSObject;
    }
    Process {
        Try  {
            Write-Log -Message "Executing '$CCMCleanExePath'...." -Source ${CmdletName}
            [psobject]$CCMCleanProcess = Execute-Process -Path $CCMCleanExePath -Parameters $Arguments -CreateNoWindow -WorkingDirectory $(Split-Path -Path $CCMCleanExePath -Parent) -PassThru -ContinueOnError $true;
            Write-Log -Message "CCMClean Process: $($CCMCleanProcess | Fl * | Out-String)" -Source ${CmdletName};
        } 
        Catch  { 
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        }     
    }
}
Function Execute-PostClientUninstall {
	[CmdletBinding()]
	Param ()
	Begin {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
        [bool]$ClientInstalled = Test-SccmClient
	}
	Process {
        Try {
            If ( !$ClientInstalled ) {
                Stop-CMServices;
                Remove-CMServices;
                Clear-CMTasks;
                Reset-LocalSecurityPolicy;
                Reset-WindowsUpdateComponents;
                Clear-SccmClientRsaFile|Out-Null;
                Reset-SccmClientSmsCertificateConfig|Out-Null;
                Clear-CMVirtualSettings|Out-Null;
                Clear-CMRegistrySettings|Out-Null;
                Clear-CMFiles|Out-Null;
                Clear-CMNamespaces|Out-Null;
                Clear-CMTasks|Out-Null;
                Call-Winmgmt -Reset;
            }
            Else {
                Throw "Client IS STill Detected as being installed."
            }
        } 
        Catch  {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 3
        }
	}
	End {
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
##*--------------------------------------------------
Function Uninstall-CMClient {
	[CmdletBinding()]
	Param ([string[]]$CleanProducts = $RepairProducts)
	Begin {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process {
        Try {
            
            If ( Test-SccmClient ) {

                Write-Log -Message "Removing SCCM Cache..." -Source ${CmdletName}
                Clear-CMCache|Out-Null;
                
                Write-Log -Message "Stopping CCMSetup Services..." -Source ${CmdletName}
                Stop-CMExec|Out-Null;

            }

            Write-Log -Message "Removing SCCM Client (CCMSETUP)..." -Source ${CmdletName}
            [Int64]$UninstallReturnValue = Execute-CMSetup -Remove -CCMSetup $GLOBAL:dirFiles_Index.CCM_FILES_CCMSETUP_EXE;
            Write-Log -Message "Done ($UninstallReturnValue)." -Source ${CmdletName}
            
            Write-Log -Message "Removing SCCM Client (CCMCLEAN)..." -Source ${CmdletName}
            Clean-CMClientUninstall|Out-Null;
            Write-Log -Message "Done." -Source ${CmdletName}
            
            Write-Log -Message "Removing SCCM Client (MSI)..." -Source ${CmdletName}
            Uninstall-CMClientProduct | Out-Null;
            Write-Log -Message "Done." -Source ${CmdletName}

        } 
        Catch  {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 3
        }
	}
}
Function Install-CMClient {
	[CmdletBinding()]
    [OutputType([psobject])]
	Param (
        [Alias('Parameters')]
        [string[]]$SetupParameters = $GLOBAL:CCM_SETUP_PARAMETER_STRING
    )
	Begin {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [Int32]$ReturnValue = 70000;
	}
	Process {
        Try {
            Write-log -Message "Ensuring CCMSETUP is Killed..." -Source ${CmdletName}
            Stop-CMSetup;
            Write-log -Message "Ensuring MSIExec is Stopped..." -Source ${CmdletName}

            Stop-Process -Name 'MsiExec','Ccmexec','ccmsetup' -Force -ErrorAction 'SilentlyContinue'|Out-Null; 
            Write-log -Message "Done ($?)." -Source ${CmdletName}
            
            Write-log -Message "Installing Nomad Client..." -Source ${CmdletName}
            Install-NomadBranch
            Write-log -Message "Done ($?)." -Source ${CmdletName}

            Write-log -Message "Move Files To CCMSetup Directory.." -Source ${CmdletName}
            Invoke-Expression -Command "Robocopy `"$dirfiles`" `"$Env:windir\ccmsetup`" /SEC /E /ETA /NFL /NDL"|Out-Null

            [string]$CCMSetupPath = Get-ChildItem -Path "$Env:windir\ccmsetup" -Filter "ccmsetup.exe" | Select -First 1 -ExpandProperty FullName
            Write-log -Message "CCMSetupPath: $CCMSetupPath" -Source ${CmdletName}
            $ccmsetupEC = Execute-CMSetup -Parameters $SetupParameters -CCMSetup $CCMSetupPath
            
            Write-Log -Message "CCMSetup.exe Exit Code: $ccmsetupEC" -Source ${CmdletName}
        } 
        Catch  {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 3
        }        
	}
    End {
        Write-Output -InputObject $ccmsetupEC
    }
}
##*--------------------------------------------------
Function Execute-CMSetup {
	[CmdletBinding(DefaultParameterSetName = 'ByParameterArrayInstall')]
    [OutputType([int64])]
	param
	(
		[Parameter(ParameterSetName = 'ByParameterArrayInstall',
				   Mandatory = $false,
				   ValueFromPipeline = $true,
				   Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Parameters = @($GLOBAL:CCM_SETUP_ARGUMENTS),

		[Parameter(ParameterSetName = 'NoParameterArrayUnInstall',
				   Mandatory = $false,
				   ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false,
				   Position = 0)]
		[Alias('uninstall')]
		[switch]$Remove,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall',
				   Mandatory = $false,
				   ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false,
				   Position = 0)]
		[AllowEmptyString()]
		[Alias('source')]
		[string]$SourcePath,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall',
				   Mandatory = $false,
				   ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[AllowEmptyCollection()]
		[Alias('mp')]
		[string]$ManagementPoint,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall',
				   Mandatory = $false,
				   ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[Alias('retry')]
		[int32]$RetryInterval = 10,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall',
				   Mandatory = $false,
				   ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[Alias('noservice')]
		[switch]$NoServiceAccount = $false,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall',
				   Mandatory = $false,
				   ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[Alias('logon')]
		[switch]$NoForce = $true,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall',
				   Mandatory = $false,
				   ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[Alias('forcereboot')]
		[switch]$ForceRestart = $false,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall',
				   Mandatory = $false,
				   ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[ValidateSet('FOREGROUND', 'HIGH', 'NORMAL', 'LOW', IgnoreCase = $true)]
		[AllowEmptyString()]
		[Alias('BITSPriority')]
		[string]$Priority,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall',
				   Mandatory = $false,
				   ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[Alias('downloadtimeout')]
		[int32]$Timeout = 1440,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall',
				   Mandatory = $false,
				   ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[Alias('UsePKICert')]
		[switch]$UseCertificate,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall',
				   Mandatory = $false,
				   ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[Alias('NoCRLCheck')]
		[switch]$SkipCRLCheck = $false,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall',
				   Mandatory = $false,
				   ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[Alias('config')]
		[string]$ConfigurationFile,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall',
				   Mandatory = $false,
				   ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[Alias('forceinstall')]
		[switch]$Reinstall,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall',
				   Mandatory = $false,
				   ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[Alias('skipprereq')]
		[string[]]$SkipPrerequisites,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[string[]]$ExcludeFeatures,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[hashtable]$ClientParameters,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('CCMALWAYSINF')]
		[switch]$ForceInternetClient,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('CCMCERTISSUERS')]
		[string[]]$CertificateIssuers,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('CCMCERTSEL')]
		[string]$CertificateSelection,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('CCMCERTSTORE')]
		[string]$CertificateStore,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('CCMFIRSTCERT')]
		[switch]$FirstCertificate,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('CCMHOSTNAME')]
		[string]$HostName,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('CCMHTTPPORT')]
		[int32]$HttpPort,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('CCMHTTPSPORT')]
		[int32]$HttpsPort,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[ValidateNotNullOrEmpty()]
		[Alias('SMSPUBLICROOTKEY')]
		[string]$PublicKey,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('SMSROOTKEYPATH')]
		[string]$RootKey,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('CCM_RESETKEYINFORMATION')]
		[switch]$ResetKey,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('CCMDEBUGLOGGING')]
		[switch]$DebugLogging,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('CCMENABLELOGGING')]
		[switch]$EnableLogging,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[ValidateRange(0, 3)]
		[Alias('CCMLOGLEVEL')]
		[int]$LogLevel,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[ValidateRange(0, 10)]
		[Alias('CCMLOGMAXHISTORY')]
		[int]$MaximumLogs,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[ValidateRange(0, 10000000)]
		[int]$MaximumLogSize,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('CCMALLOWSILENTREBOOT')]
		[switch]$AllowSilentReboot,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('CCM_DISABLESITEOPT')]
		[switch]$DisableSiteChange,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('CCM_DISABLECACHEOPT')]
		[switch]$DisableCacheModify,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[ValidateScript({ Test-Path -Path $_ })]
		[Alias('SMSCACHEDIR')]
		[string]$CacheDirectory,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[ValidateSet('PERCENTDISKSPACE', 'PERCENTFREEDISKSPACE', 'MAXDRIVE', 'MAXDRIVESPACE', 'NTFSONLY', 'COMPRESS', 'FAILIFNOSPACE', IgnoreCase = $true)]
		[Alias('SMSCACHEFLAGS')]
		[string[]]$CacheFlags,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[ValidateCount(0, 10000000)]
		[Alias('SMSCACHESIZE')]
		[int]$CacheSize,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[ValidateSet('Registry', 'CMD', 'Existing', 'Upgrade', IgnoreCase = $true)]
		[Alias('SMSCONFIGSOURCE')]
		[string[]]$ConfigurationSource,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[ValidateSet('NOWINS', 'WINSSECURE', IgnoreCase = $true)]
		[string]$DirectoryLookup,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[ValidateScript({ Test-Path -Path $_ })]
		[Alias('SMSSIGNCERT')]
		[string]$CertificatePath,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('SMSMP')]
		[string]$InitialManagementPoint,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('SMSSITECODE')]
		[string]$SiteCode,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('CCMINSTALLDIR')]
		[string]$InstallDirectory,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('CCMADMINS')]
		[string[]]$Administrators,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('FSP')]
		[string]$FallbackStatusPoint,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('DNSSUFFIX')]
		[string]$DomainNameSuffix,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[ValidateRange(1, 1440)]
		[Alias('CCMEVALINTERVAL')]
		[int32]$EvaluationInterval,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[ValidateRange(0, 23)]
		[Alias('CCMEVALHOUR')]
		[int32]$EvaluationHour,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('CCM_IGNOREAPPVVERSIONCHECK')]
		[switch]$NoAppVCheck,
		[Parameter(ParameterSetName = 'NoParameterArrayInstall')]
		[Alias('CCM_NOTIFYONLY')]
		[switch]$NoRemediate,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path -Path $_})]
        [string]$CCMSetup = $GLOBAL:CCM_CCMSETUP_EXE

	)
	Begin 
    {
	    [string]${CmdletName} = $PsCmdlet.MyInvocation.MyCommand.Name;	
		[psobject]$ResolveMsiParameterInfo = New-Object -TypeName PSObject -Property @{
			CCMALWAYSINF = {
				Param ([Parameter(Position = 0)]
					[switch]$SwitchPresent) If ($SwitchPresent.IsPresent) { 1 }
				Else { 0 }
			};
			CCMCERTISSUERS = {
				Param ([Parameter(Position = 0)]
					[string[]]$InputObject) $InputObject -join ' | '
			};
			CCMCERTSEL = {
				Param ([Parameter(Position = 0)]
					[string]$InputObject) $InputObject
			};
			CCMCERTSTORE = {
				Param ([Parameter(Position = 0)]
					[string]$InputObject) $InputObject
			};
			CCMFIRSTCERT = {
				Param ([Parameter(Position = 0)]
					[switch]$SwitchPresent) If ($SwitchPresent.IsPresent) { 1 }
				Else { 0 }
			};
			CCMHOSTNAME = {
				Param ([Parameter(Position = 0)]
					[string]$InputObject) $InputObject
			};
			CCMHTTPPORT = {
				Param ([Parameter(Position = 0)]
					[int]$InputObject) $InputObject
			};
			CCMHTTPSPORT = {
				Param ([Parameter(Position = 0)]
					[int]$InputObject) $InputObject
			};
			SMSPUBLICROOTKEY = {
				Param ([Parameter(Position = 0)]
					[string]$InputObject) $InputObject
			};
			SMSROOTKEYPATH = {
				Param ([Parameter(Position = 0)]
					[string]$InputObject) $InputObject
			};
			RESETKEYINFORMATION = {
				Param ([Parameter(Position = 0)]
					[switch]$SwitchPresent) If ($SwitchPresent.IsPresent) { 'TRUE' }
				Else { 'FALSE' }
			};
			CCMDEBUGLOGGING = {
				Param ([Parameter(Position = 0)]
					[switch]$SwitchPresent) If ($SwitchPresent.IsPresent) { 1 }
				Else { 0 }
			};
			CCMENABLELOGGING = {
				Param ([Parameter(Position = 0)]
					[switch]$SwitchPresent) If ($SwitchPresent.IsPresent) { 'TRUE' }
				Else { 'FALSE' }
			};
			CCMLOGLEVEL = {
				Param ([Parameter(Position = 0)]
					[int]$InputObject) $InputObject
			};
			CCMLOGMAXHISTORY = {
				Param ([Parameter(Position = 0)]
					[int]$InputObject) $InputObject
			};
			CCMLOGMAXSIZE = {
				Param ([Parameter(Position = 0)]
					[int]$InputObject) $InputObject
			};;
			CCMALLOWSILENTREBOOT = {
				Param ([Parameter(Position = 0)]
					[switch]$SwitchPresent) If ($SwitchPresent.IsPresent) { 1 }
				Else { 0 }
			};;
			DISABLESITEOPT = {
				Param ([Parameter(Position = 0)]
					[switch]$SwitchPresent) If ($SwitchPresent.IsPresent) { 'TRUE' }
				Else { 'FALSE' }
			};;
			DISABLECACHEOPT = {
				Param ([Parameter(Position = 0)]
					[switch]$SwitchPresent) If ($SwitchPresent.IsPresent) { 'TRUE' }
				Else { 'FALSE' }
			};;
			SMSCACHEDIR = {
				Param ([Parameter(Position = 0)]
					[string]$InputObject) $InputObject
			};
			SMSCACHEFLAGS = {
				Param ([Parameter(Position = 0)]
					[string[]]$InputObject) $InputObject -join ','
			};;
			SMSCACHESIZE = {
				Param ([Parameter(Position = 0)]
					[int]$InputObject) $InputObject
			};
			SMSCONFIGSOURCE = {
				Param ([Parameter(Position = 0)]
					[string[]]$InputObject) [string]$out = [string]::Empty; foreach ($Obj in $InputObject) { switch ($InputObject.ToLower()) { 'registry'{ $out += 'R'; break; }  'cmd'{ $out += 'P'; break; }  'existing'{ $out += 'M'; break; }  'upgrade'{ $out += 'U'; break; } } }; $out;
			};
			SMSDIRECTORYLOOKUP = {
				Param ([Parameter(Position = 0)]
					[string]$InputObject) $InputObject
			};
			SMSSIGNCERT = {
				Param ([Parameter(Position = 0)]
					[string]$InputObject) $InputObject
			};
			SMSMP = {
				Param ([Parameter(Position = 0)]
					[string]$InputObject) $InputObject
			};
			SMSSITECODE = {
				Param ([Parameter(Position = 0)]
					[string]$InputObject) $InputObject
			};
			CCMINSTALLDIR = {
				Param ([Parameter(Position = 0)]
					[string]$InputObject) $InputObject
			};
			CCMADMINS = {
				Param ([Parameter(Position = 0)]
					[string[]]$InputObject) $InputObject -join ','
			};
			FSP = {
				Param ([Parameter(Position = 0)]
					[string]$InputObject) $InputObject
			};
			DNSSUFFIX = {
				Param ([Parameter(Position = 0)]
					[string]$InputObject) $InputObject
			};
			CCMEVALINTERVAL = {
				Param ([Parameter(Position = 0)]
					[int]$InputObject) $InputObject
			};;
			CCMEVALHOUR = {
				Param ([Parameter(Position = 0)]
					[int]$InputObject) $InputObject
			};;
			IGNOREAPPVVERSIONCHECK = {
				Param ([Parameter(Position = 0)]
					[switch]$SwitchPresent) If ($SwitchPresent.IsPresent) { 'TRUE' }
				Else { 'FALSE' }
			};
			NOTIFYONLY = {
				Param ([Parameter(Position = 0)]
					[switch]$SwitchPresent) If ($SwitchPresent.IsPresent) { 'TRUE' }
				Else { 'FALSE' }
			};;
		}
        [int64]$ReturnValue = 67000

        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSCmdlet.MyInvocation.BoundParameters -Header
	}
	Process
	{
        Try {
            #Write-host $PSCmdlet.ParameterSetName
            [string[]]${ccmsetupParameters} = @();
		    switch ($PsCmdlet.ParameterSetName)
		    {
			    'ByParameterArrayInstall' {
				    #TODO: Place script here
                    [string[]]${ccmsetupParameters} = $Parameters;
                    Write-Log -Message "ParameterObject: [${ccmsetupParameters}]${ccmsetupParameters}" -Source ${CmdletName}
				    break
			    }
			    'NoParameterArrayInstall' {
				        #TODO: Place script here
                        [string[]]${ccmsetupParameters} = @();
                        [string[]]$CommonParams = @([System.Management.Automation.PSCmdlet]::OptionalCommonParameters + [System.Management.Automation.PSCmdlet]::CommonParameters)
                        [hashtable]$CmdletPArams = $PsCmdlet.MyInvocation.BoundParameters ;
                        If ( $CmdletPArams.ContainsKey('CCMSetup') ){$CmdletPArams.Remove('CCMSetup')}
                        If ( $CmdletPArams.ContainsKey('ClientParameters') ){$CmdletPArams.Remove('ClientParameters')}
                        $CommonParams|%{If ( $CmdletPArams.ContainsKey($_)){$CmdletPArams.Remove($_)}}
                        Foreach ( ${ParameterObject} in $($CmdletParams.Keys) ) {
                            $ParameterInfo=$PsCmdlet.MyInvocation.MyCommand.ResolveParameter(${ParameterObject})
                            $TypeName=$ParameterInfo.ParameterType.Name
                            $Alias = $ParameterInfo.Aliases|Select-Object -First 1;
                            If ( $Alias -like 'CCM_*' ) {[string]$AliasName = $Alias.Replace('CCM_','')}
                            Else {[string]$AliasName = $Alias}
                            Write-Log -Message "ParameterObject: [$TypeName]${ParameterObject}=$($Alias.ToUpper())" -Source ${CmdletName}
                            If ( $Alias -match '^(SMS|CCM)' ) {
                                [string]$AddValue="$($AliasName)=`"$($($ResolveMsiParameterInfo.$AliasName).Invoke($CmdletPArams.${ParameterObject}))`""
                            }
                            Else {
                                Switch ( $TypeName ) {
                                    'SwitchParameter' {
                                        [string]$AddValue = ('/'+$Alias)
                                        break;
                                    }
                                    'Int32' {
                                        [string]$AddValue = ('/'+$Alias+':' + $CmdletPArams.${ParameterObject})
                                        break;
                                    }
                                    'String' {
                                         [string]$AddValue = ('/'+$Alias+':"' + $CmdletPArams.${ParameterObject} + '"')
                                        break;
                                    }
                                    'String[]' {
                                         [string]$AddValue = ('/'+$Alias+':"' + ($CmdletPArams.${ParameterObject} -join ';') + '"')
                                        break;
                                    }
                                    default {break;}
                                }                                
                            }
                            Write-Log -Message "AddValue: $AddValue" -Source ${CmdletName}
                            ${ccmsetupParameters} += $AddValue
                            If ( $ClientParameters.Keys.Count -gt 0 ){Foreach ( $Key in $ClientParameters.Keys ) {${ccmsetupParameters} += "$($Key)=`"$($ClientParameters.$Key)`""}}
			        }
                    break;
                }
                'NoParameterArrayUnInstall' {
                    #TODO: Place script here
                    [string[]]${ccmsetupParameters} = '/uninstall'
                    break
                }
		    }
            Write-Log -Message "CCMSetupParameters: $(${ccmsetupParameters} -join ' ')" -Source ${Cmdletname}
            
            Write-Log -Message "Starting CCMSetup Process..." -Source ${Cmdletname}
            [psobject]$ReturnValue = Execute-Process -Path $CCMSetup -Parameters ${ccmsetupParameters} -CreateNoWindow -WorkingDirectory $(Split-Path -Parent -Path $CCMSetup) -PassThru -ContinueOnError $true
            [string]$CCMSetupLogPath="$env:windir\ccmsetup\logs\ccmsetup.log"        
            Try {
                [datetime]$startTime = [datetime]::Now;
                Do{
                    $RetryCaught = Get-Content  -Path $CCMSetupLogPath|select -last 1|Select-String -Pattern "Next retry in " -Quiet
                    $CCMSetupProcess = Get-Process -Name 'CCMSetup' -Ea 'SilentlyContinue'
                    Start-Sleep -Seconds 1
                    
                    If ($PSCmdlet.ParameterSetName -eq 'NoParameterArrayUnInstall' -and $([Datetime]::now).subtract($startTime).TotalSeconds -lt 60){Write-Log -Message "Hit Time Limit on Uninstall, Continue";break;}
                }While($CCMSetupProcess -and !$RetryCaught)
            }
            Catch{
                Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
            }
            If ( !(Test-Path -Path $CCMSetupLogPath) ){
                Throw "Could Not Find ccmsetup.log"
            }
            $content = (Format-SccmLog -FilePath $CCMSetupLogPath | Select -Last 10 | Sort-Object -Property Date -Descending|Select -ExpandProperty 'Message') -join "`r`n"
            [string]$ExitCodeString=([regex]'(?<=((CcmSetup is exiting with return code )|(CcmSetup failed with error code )|(The error code is )|(client.msi installation failed. Error text: ExitCode: )))(0x[A-Za-z0-9]{8}|\d{1,10})(?= )').Matches($Content)|Sort-Object -Property Value -Descending|Select -First 1 -ExpandProperty 'Value'
            If ( $ExitCodeString.Length -eq 8 -and $ExitCodeString.Substring(0,2) -ne '0x'){$ExitCodeString='0x'+$ExitCodeString}
            [int]$ReturnValue = [int]($ExitCodeString)
        }
        Catch {
            [int64]$ReturnValue = 67000;
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 3
        }
	}
	End
	{
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
		Write-Output -InputObject $ReturnValue
	}
}
Function Execute-CMUninstallPrerparation {
	[CmdletBinding()]
    [OutputType([psobject[]])]
	param
	(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]${BaseVariableName} = 'CCM_INSTALL_PRECMD'
    )
	Begin 
    {
	    [string]${CmdletName} = $PsCmdlet.MyInvocation.MyCommand.Name;	
        [psobject[]]$ReturnValue = @();
    }
    Process {
        Try {
            Get-Variable | ? { $_.Name -match "${BaseVariableName}[_]\d{2}" } | ForEach-Object {
                $_ | Add-Member -MemberType NoteProperty -Name 'Index' -Value $([int]($($_.Name.Split('_')|Select-Object -Last 1).TrimStart('0'))) -PassThru -Force
            } |Sort-Object -Property 'Index' | Select-Object -Property "Name","Value","Index"  | %{
                Write-Log -Message "Executing Prestart Command: [$($_.Value)]" -Source ${CmdletName}
                . $_.Value
            }
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 3
        }
	}
}
#endregion [Client Install/Uninstall]
##*===============================================

##*===============================================
#region [Client Repair]

#endregion [Client Repair]
##*===============================================

##*===============================================
#region [Client Cleanup]
Function Repair-AppDataDirectory {
	[CmdletBinding()]
	param
	()
	Begin
	{
		[string]${CmdletSection} = "Begin"
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
	Process
	{
		[string]${CmdletSection} = "Process"
		Try {
            Set-RegistryKey -Key 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -SID 'S-1-5-18' -Name 'AppData' -Value '%userprofile%\AppData\Roaming' -Type 'String' -ContinueOnError $true;
            Set-RegistryKey -Key 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'  -Name 'AppData' -Value '%userprofile%\AppData\Roaming' -Type 'String' -ContinueOnError $true -ea SilentlyContinue;
            Set-RegistryKey -Key 'HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'  -Name 'AppData' -Value '%userprofile%\AppData\Roaming' -Type 'String' -ContinueOnError $true -ea SilentlyContinue;
		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 3
		}
	}
}
Function Repair-MsXmlParser {
    [CmdletBinding()]
    Param()
    Begin
    {
        [string[]]$ReturnValue = @();
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
        Try
        {
            Get-ChildItem -Path "$Env:windir\system32","$Env:windir\syswow64" -Include 'msxml*.dll' -Force -Recurse -Ea Silentlycontinue | %{
                Invoke-RegisterOrUnregisterDLL -FilePath $_.FullName -DLLAction Register -ContinueOnError $true -Ea Silentlycontinue ;
            }
        }
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}        
        
    }
}
Function Clear-CMFiles {
    [CmdletBinding()]
    param()
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process
    {
        ## Method #1
        Try
        {
             [string[]]$CcmDirectories = @(
                $(Join-Path -Path $Env:ProgramData -ChildPath 'Microsoft\Crypto\RSA\MachineKeys\19c5cf9c7b5dc9de3e548adb70398402_bdc53444-4ebf-4226-8f9f-fcacc0a1f908'),
                "$env:windir\ccm",
                "$env:windir\system32\ccm",
                "$env:windir\syswow64\ccm",
                "$env:windir\ccmsetup",
                "$env:windir\ccmcache",
                "$env:windir\system32\ccmcache",
                "$env:windir\syswow64\ccmcache",
                "$env:windir\system32\ccmsetup",
                "$env:windir\syswow64\ccmsetup",
                "$env:windir\smscfg.ini",
                "$env:windir\sms*.mif"
            )
            $CcmDirectories | %{
                Write-Log -Message "Processing Client Path '$_'..." -Source ${CmdletName}
                If ( Test-Path -Path $_ ) {
                    If ( [System.IO.Path]::HasExtension($_) ) {
                        Remove-File -Path $_ -Recurse -ContinueOnError $true;
                    }
                    Else {
                        Remove-Folder -Path $_ -ContinueOnError $true;
                    }
                }
                Else {
                    Write-Log -Message "Path '$_' Does Not Exist." -Source ${CmdletName}
                }
            }           
        }
        Catch
        {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
    End
    {
        Write-Output -InputObject $ReturnValue
    }
}
Function Clear-CMRegistrySettings {
    [cmdletbinding()]
    Param()
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
        try 
        { 
            [string]$RegRoot = "HKLM:\Software\Microsoft";[string]$RegRoot64 = "HKLM:\Software\Wow6432Node\Microsoft";
            [string[]]$RegistryPaths = @(
                "$RegRoot\ccm",
                "$RegRoot\ccmsetup",
                "$RegRoot\sms",
                "$RegRoot64\ccm",
                "$RegRoot64\ccmsetup",
                "$RegRoot64\sms"
            )
            $RegistryPaths | %{
                Write-Log -Message "Processing Client Registry Key '$_'..." -Source ${CmdletName}
                If ( Test-Path -Path $_ ) {
                    Remove-RegistryKey -Key $_ -Recurse -ContinueOnError $true -ErrorAction 'SilentlyContinue';
                }
                Else {
                    Write-Log -Message "Path '$_' Does Not Exist." -Source ${CmdletName}
                }   
            }
        } 
        catch 
        {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        } 
    }
}
Function Clear-CMVirtualSettings {
    [cmdletbinding()]
    Param()
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
        try 
        { 
            If  (@($(Get-WMINameSpace -Name 'Client' -Root 'Root\Microsoft\AppVirt' -Ea SilentlyContinue)).Count -gt 0){
            Get-WmiObject -Query "SELECT * FROM Package WHERE SftPath like '%' AND InUse = 'FALSE' " -Namespace "Root\Microsoft\AppVirt\Client" | Foreach-Object {
                Execute-Process -Path 'cmd.exe' -Parameters '/c','sftmime.exe',"delete package:$([char]34)$($_.Name)$([char]34) /global" -CreateNoWindow -PassThru -ContinueOnError $true -ErrorAction 'SilentlyContinue';
            }         
            }
            Else {
                Write-Log -Message "Namespace 'Root\Microsoft\AppVirt\Client' Does Not Exist." -Source ${cmdletname}

            }
        } 
        catch 
        {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        } 
    }
}
Function Clear-CMNamespaces {
    [cmdletbinding()]
    Param()
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
        try 
        {
            Remove-WMINamespace -Path 'Root\CCM','Root\Cimv2\SMS' -ErrorAction 'SilentlyContinue';
        } 
        catch 
        {
            Write-Log -Message "[Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        } 
    }
    End
    { 
        [string]${CmdletSection} = 'End'
    }
}  
Function Clear-CMTasks {
    [CmdletBinding()]
    param()
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process
    {
        ## Method #1
        Try {
            Get-ScheduledTasks | ? { $_.Path -like '*Configuration Manager*' } | %{
                Write-Log -Message "Removing Scheduled Task '$($_.Path)'..." -Source ${CmdletName}
                Remove-ScheduledTask -Path $_.Path;
                Write-Log -Message "Done. ($($?))" -Source ${CmdletName}
            }
        }
        Catch
        {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
}
Function Clear-CMCache {
    [CmdletBinding()]
    param(
        [int]$AgeDays = 7
    )
    Begin
    {

        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [bool]$ReturnValue = $false;
    }
    Process
    {
        Try {
            ## Method #1
            Try
            {
                $CMObject = New-Object -ComObject "UIResource.UIResourceMgr" -Ea 'Stop'        
                $CMCacheObjects = $CMObject.GetCacheInfo()
                $CMCacheObjects.GetCacheElements() | Foreach-Object {
                
                    [string]$ElementId = $_.CacheElementId;
                    Write-Log -Message "ElementId: $ElementId" -Source ${CmdletName}

                    [string]$ElementLocation = $_.Location;
                    Write-Log -Message "ElementLocation: $ElementLocation" -Source ${CmdletName}

                    If ( ![string]::IsNullOrEmpty($ElementId) ) {
                        $CMCacheObjects.DeleteCacheElement($ElementId);
                        Write-Log -Message "Removed Cache Element: $ElementID." -Source ${CmdletName}
                    }
                    Else {
                        Write-Log -Message "Cache Element Is Null." -Source ${CmdletName}
                    }

                    If ( ![string]::IsNullOrEmpty($ElementLocation) ) {
                        If ( Test-Path -Path $ElementLocation ) {
                            Remove-Folder -Path $ElementLocation -ContinueOnError $true -ErrorAction 'SilentlyContinue';
                            Write-Log -Message "Removed Cache Location: $ElementLocation." -Source ${CmdletName};
                        }
                        Else {
                            Write-Log -Message "Location '$ElementLocation' Does Not Exist." -Source ${CmdletName}
                        }
                    }
                    Else {
                        Write-Log -Message "Location Is Null Or Empty." -Source ${CmdletName}
                    }
                    Remove-Variable -Name 'ElementId','ElementLocation' -Force -ErrorAction 'SilentlyContinue'
                }
            }
            Catch
            {
                Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName}
            }

            ## Method #2
            Try
            {
                [string]$Cachepath = ([wmi]"ROOT\ccm\SoftMgmtAgent:CacheConfig.ConfigKey='Cache'").Location
                If ( [string]::IsNullOrEmpty($Cachepath) ){
                    [string]$CachePath = Join-Path -Path $env:Windir -ChildPath 'ccmcache'
                }
                Write-Log -Message "Cachepath: $Cachepath" -Source ${CmdletName}
                Try {
                    $OldCache = Get-WMIObject -Query "SELECT * FROM CacheInfoEx" -namespace "ROOT\ccm\SoftMgmtAgent"; 
                    $OldCache | Remove-WmiObject -ErrorAction 'SilentlyContinue'
                } Catch {
                    Write-Log -Message "Attempt at Removing any Existing WMI Objects was unsuccessful." -Source ${CmdletName}    
                }
            }
            Catch
            {
                Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName}
            }
        }
        Catch
        {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
        Finally {
            Remove-Folder -Path $CachePath -ContinueOnError $true -ErrorAction 'SilentlyContinue' | Out-Null;
        }
    }
    End {
    }
}
#endregion [Client Cleanup]
##*===============================================

##*===============================================
#region [Prerequesites]
Function Remove-DotNetFramework
{
	[CmdletBinding()]
	param
	(
    )
	
	Begin {		
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
	Process
	{
		Try {
            $(New-Object PSObject -Property @{SetupPath="$Env:Windir\Microsoft.NET\Framework\v4.0.30319\SetupCache\Client\setup.exe"; Parameters='/uninstall /x86 /x64 /parameterfolder Client /q /norestart'}),
            $(New-Object PSObject -Property @{SetupPath="$Env:Windir\Microsoft.NET\Framework64\v4.0.30319\SetupCache\Client\setup.exe"; Parameters='/uninstall /x86 /x64 /parameterfolder Client /q /norestart'}),
            $(New-Object PSObject -Property @{SetupPath="$Env:Windir\Microsoft.NET\Framework\v4.0.30319\SetupCache\Extended\setup.exe"; Parameters='/uninstall /x86 /x64 /ia64 /parameterfolder Extended /q /norestart'}),
            $(New-Object PSObject -Property @{SetupPath="$Env:Windir\Microsoft.NET\Framework64\v4.0.30319\SetupCache\Extended\setup.exe"; Parameters='/uninstall /x86 /x64 /parameterfolder Client /q /norestart'}),
            $(New-Object PSObject -Property @{SetupPath="$env:windir\Microsoft.NET\Framework\v4.0.30319\SetupCache\setup.exe"; Parameters='/uninstall /x86 /x64 /q /norestart'}),
            $(New-Object PSObject -Property @{SetupPath="$env:windir\Microsoft.NET\Framework64\v4.0.30319\SetupCache\setup.exe"; Parameters='/uninstall /x86 /x64 /q /norestart'}),
            $(New-Object PSObject -Property @{SetupPath="$env:windir\Microsoft.NET\Framework\v4.0.30319\SetupCache\v4.5.50938\setup.exe"; Parameters='/uninstall /x86 /x64 /q /norestart'}),
            $(New-Object PSObject -Property @{SetupPath="$env:windir\Microsoft.NET\Framework64\v4.0.30319\SetupCache\v4.5.50938\setup.exe"; Parameters='/uninstall /x86 /x64 /q /norestart'}),
            $(New-Object PSObject -Property @{SetupPath="$env:windir\Microsoft.NET\Framework\v4.0.30319\SetupCache\v4.5.51209\setup.exe"; Parameters='/uninstall /x86 /x64 /q /norestart'}),
            $(New-Object PSObject -Property @{SetupPath="$env:windir\Microsoft.NET\Framework64\v4.0.30319\SetupCache\v4.5.51209\setup.exe"; Parameters='/uninstall /x86 /x64 /q /norestart'}) | %{
                If ( Test-Path -Path $_.SetupPath ) {
                    Write-Log -Message "Removing .NET Framework: [$($_.SetupPath) $($_.Parameters)]..." -Source ${CmdletName}
                    $UninstallProcess=Execute-Process -Path $_.SetupPath -Parameters @($_.Parameters) -CreateNoWindow -PassThru -ContinueOnError $true;
                    Write-Log -Message "Done: $($UninstallProcess|fl *|out-string)." -Source ${CmdletName}
                }
                Else {
                    Write-Log -Message "File '$($_.SetupPath)' Does Not Exist." -Source ${CmdletName}
                }
            }
		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
}
Function Test-DotNetFramework
{
	[CmdletBinding()]
    [OutputType([bool])]
	param
	(
        [int]$CompliantValue = 378389
    )
	
	Begin {		
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [bool]$ReturnValue=$false
    }
	Process
	{
		Try {
            
            [psobject]$NDPObject = Get-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -ContinueOnError $true
            Write-Log -Message "NDPObject: [$($NDPObject |fl *|out-string)]" -source ${cmdletname}
            
            If ( $NDPObject.psobject.Properties.Name -contains 'Release' ) {
                [bool]$ReturnValue = [int]($NDPObject.Release) -ge $CompliantValue
            }
            Else {
                Write-Log -Message "Could Not Find Property 'Release'." -source ${cmdletname}
                [bool]$ReturnValue = $false;
            }
		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
    End {
        Write-Output -InputObject $ReturnValue;
    }
}
##*--------------------------------------------------
Function Remove-Silverlight
{
	[CmdletBinding()]
	param
	(
        [string]$CcmSetupWorkingDirectory
    )
	Begin {		
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
	Process
	{
		[string]${CmdletSection} = "Process"
		Try {
            

            Write-Log -Message "Removing Silverlight Product '$dirFiles\i386\Silverlight.exe'..." -Source ${CmdletName}    
            Execute-Process -Path "$dirFiles\i386\Silverlight.exe" -Parameters '/qu' -CreateNoWindow -PassThru -ContinueOnError $true;
            Write-Log -Message "Done." -Source ${CmdletName}    
            
            Get-InstalledApplication -Name 'Microsoft Silverlight' -Exact| %{
                Write-Log -Message "Removing Silverlight Product '$($_.ProductCode)'..." -Source ${CmdletName}    
                Execute-MSI -Action Uninstall -Path $_.ProductCode -PassThru -ContinueOnError $true;
                Write-Log -Message "Done." -Source ${CmdletName}    
            }
		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
}
Function Test-Silverlight
{
	[CmdletBinding()]
    [OutputType([bool])]
	param
	(
        [string]$CompliantValue = '5.1.50901.0'
    )
	
	Begin {		
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [bool]$ReturnValue=$false
    }
	Process
	{
		Try {
             If ( $(Get-OSArchitecture) -like '*64*' ) {
                [string]$RegPath = 'HKLM\Software\Wow6432Node\Microsoft\Silverlight'
            }
            Else {
                [string]$RegPath = 'HKLM\Software\Microsoft\Silverlight'
            }

            [psobject]$regobj = Get-RegistryKey -Key $RegPath -ContinueOnError $true
            Write-Log -Message "regobj: [$($regobj |fl *|out-string)]" -source ${cmdletname}

            If ( $regobj.psobject.Properties.Name -contains 'Version' ) {
                [bool]$ReturnValue = (New-Object -TypeName System.Version -ArgumentList ($regobj.Version.Split('.'))).CompareTo($(New-Object -TypeName System.Version -ArgumentList ($CompliantValue.Split('.')))) -gt 0
            }
            Else {
                Write-Log -Message "Could Not Find Property 'Release'." -source ${cmdletname}
                [bool]$ReturnValue = $false;
            }
		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
    End {
        Write-Output -InputObject $ReturnValue;
    }
}
##*--------------------------------------------------
Function Remove-PolicyPlatform
{
	[CmdletBinding()]
	param
	()
	Begin {		
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
	Process
	{
		[string]${CmdletSection} = "Process"
		Try {
            If ( $envOSArchitecture -like '*64*' ) {[string]$installArchPath = Join-Path -Path $CcmSetupWorkingDirectory -ChildPath 'x64';   }
            Else {[string]$installArchPath = Join-Path -Path $CcmSetupWorkingDirectory -ChildPath 'i386';}
            Write-Log -Message "installArchPath: $($installArchPath)" -Source ${CmdletName}
            
            Write-Log -Message "Removing Microsoft Platform Policy '$installArchPath\microsoftpolicyplatformsetup.msi'..." -Source ${CmdletName}    
            Execute-MSI -Action Uninstall -Path "$installArchPath\microsoftpolicyplatformsetup.msi" -PassThru -ContinueOnError $true -ErrorAction 'SilentlyContinue'|Out-Null;
            Write-Log -Message "Done." -Source ${CmdletName}    

            Get-InstalledApplication -Name 'Microsoft Policy Platform' -Exact| %{
                Write-Log -Message "Removing Silverlight Product '$($_.ProductCode)'..." -Source ${CmdletName}    
                Execute-MSI -Action Uninstall -Path $_.ProductCode -PassThru -ContinueOnError $true;
                Write-Log -Message "Done." -Source ${CmdletName}    
            }
		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
}
Function Test-PolicyPlatform
{
	[CmdletBinding()]
    [OutputType([bool])]
	param
	(
        [string]$CompliantValue = '68.1.1010.0'
    )
	
	Begin {		
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [bool]$ReturnValue=$false
    }
	Process
	{
		Try {
            If ( $(Get-OSArchitecture) -like '*64*' ) {
                [string]$UpgradeCode = '{3868550C-1532-316A-9EFF-8509A6E92F79}'
            }
            Else {
                [string]$UpgradeCode = '{936E696B-0C8D-3A48-98DF-344FEA4E1139}'
            }

            [string]$ProductCode = Get-MsiProductCode -UpgradeCode $UpgradeCode
            Write-Log -Message "ProductCode: $ProductCode" -source ${cmdletname}

            If ( [string]::IsNullOrEmpty($ProductCode) ){
                Throw "Could Not Find Product Code For Upgrade Code '$UpgradeCode'"
            }

            [psobject]$InstalledProductObj = Get-InstalledApplication -ProductCode $ProductCode -Exact
            Write-Log -Message "InstalledProductObj: [$($InstalledProductObj |fl *|out-string)]" -source ${cmdletname}

            If ( !$InstalledProductObj ) {
                Throw "Could Not Find Installed Product For '$ProductCode'..."
            }

            If ( $InstalledProductObj.psobject.Properties.Name -contains 'DisplayVersion' ) {

                [int[]]$BaselineParts = $InstalledProductObj.DisplayVersion.Split('.');
                If ( $BaselineParts.Count -lt 4 ) { $BaselineParts += 0 }
                [version]$BaseLineVersion = New-Object -TypeName System.Version -ArgumentList $BaselineParts
                Write-Log -Message "BaseLineVersion: [$($BaseLineVersion |fl *|out-string)]" -source ${cmdletname}

                [int[]]$CompliantParts = $CompliantValue.Split('.')
                If ( $CompliantParts.Count -lt 4 ) { $CompliantParts += 0 }
                [version]$CompliantVersion = New-Object -TypeName System.Version -ArgumentList $CompliantParts
                Write-Log -Message "CompliantVersion: [$($CompliantVersion |fl *|out-string)]" -source ${cmdletname}

                [int]$CompareResult = $BaseLineVersion.CompareTo($CompliantVersion)
                Write-Log -Message "CompareResult: $CompareResult" -source ${cmdletname}

                [bool]$ReturnValue = $CompareResult -ge 0
            }
            Else {
                Write-Log -Message "Could Not Find Property 'Version'." -source ${cmdletname}
                [bool]$ReturnValue = $false;
            }
		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
    End {
        Write-Output -InputObject $ReturnValue;
    }
}
##*--------------------------------------------------
Function Test-MSXml
{
	[CmdletBinding()]
    [OutputType([bool])]
	param
	(
        [string]$CompliantValue = '6.10.1129.0'
    )
	
	Begin {		
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [bool]$ReturnValue=$false
    }
	Process
	{
		Try {
            
            If ( !(Test-Path -Path "$Env:windir\system32\msxml6.dll" )) {
                throw "Could Not Find File '$Env:windir\system32\msxml6.dll'."
            }

            [string]$FileVersionString = Get-ItemProperty -Path "$Env:windir\system32\msxml6.dll" -Name 'VersionInfo' -Ea 'SilentlyContinue'| Select-Object -Ea 'SilentlyContinue' -First 1 -ExpandProperty 'VersionInfo'| Select-Object -Ea 'SilentlyContinue' -First 1 -ExpandProperty 'FileVersion'
            Write-Log -Message "ProductCode: $ProductCode" -source ${cmdletname}

            [bool]$ReturnValue = (New-Object -TypeName System.Version -ArgumentList ($FileVersionString.Split('.'))).CompareTo($(New-Object -TypeName System.Version -ArgumentList ($CompliantValue.Split('.')))) -gt 0
            

		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
    End {
        Write-Output -InputObject $ReturnValue;
    }
}
Function Install-MSXml
{
	[CmdletBinding()]
	param
	()
	Begin {		
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
	Process
	{
		Try {
             If ( $(Get-OSArchitecture) -like '*64*' ) {
                [string]$InstallFolder = 'x64'
            }
            Else {
                [string]$InstallFolder = 'i386'
            }
            Write-Log -Message "InstallFolder: $InstallFolder" -Source ${CmdletName}

            [string]$MsiFileName = 'msxml6.msi';
            Write-Log -Message "MsiFileName: $MsiFileName" -Source ${CmdletName}

            [string]$SourceFolder = Join-Path -Path $dirFiles -ChildPath $InstallFolder
            Write-Log -Message "SourceFolder: $SourceFolder" -Source ${CmdletName}

            [string]$MsiFilePath = Get-ChildItem -Path $SourceFolder -Filter $MsiFileName -Force -Recurse | Select-Object -ExpandProperty 'fullname' -First 1
            Write-Log -Message "MsiFilePath: $MsiFilePath" -Source ${CmdletName}

            If ( [string]::IsNullOrEmpty($MsiFilePath) ) {
                throw "Could Not Find '$MsiFileName' in '$SourceFolder'"
            }
            
            [psobject]$InstallProcess = Execute-MSI -Action Install -Path $MsiFilePath -SkipMSIAlreadyInstalledCheck -WorkingDirectory $SourceFolder -PassThru -ContinueOnError $true
            Write-Log -Message "InstallProcess: $($InstallProcess | Fl * |Out-String)" -source ${cmdletname}

		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
}
##*--------------------------------------------------
Function Test-MicrosoftRedistributables
{
	[CmdletBinding()]
    [OutputType([bool])]
	param
	(
        [string]$CompliantValue = '12.0.21005'
    )
	
	Begin {		
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [bool]$ReturnValue=$false
    }
	Process
	{
		Try {
            If ( $(Get-OSArchitecture) -like '*64*' ) {
                [string]$UpgradeCode = '{3868550C-1532-316A-9EFF-8509A6E92F79}'
            }
            Else {
                [string]$UpgradeCode = '{936E696B-0C8D-3A48-98DF-344FEA4E1139}'
            }
                      
            [string]$ProductCode = Get-MsiProductCode -UpgradeCode $UpgradeCode
            Write-Log -Message "ProductCode: $ProductCode" -source ${cmdletname}

            If ( [string]::IsNullOrEmpty($ProductCode) ){
                Throw "Could Not Find Product Code For Upgrade Code '$UpgradeCode'"
            }

            [psobject]$InstalledProductObj = Get-InstalledApplication -ProductCode $ProductCode -Exact
            Write-Log -Message "InstalledProductObj: [$($InstalledProductObj |fl *|out-string)]" -source ${cmdletname}

            If ( !$InstalledProductObj ) {
                Throw "Could Not Find Installed Product For '$ProductCode'..."
            }

            If ( $InstalledProductObj.psobject.Properties.Name -contains 'DisplayVersion' ) {
                
                [int[]]$BaselineParts = $InstalledProductObj.DisplayVersion.Split('.');
                If ( $BaselineParts.Count -lt 4 ) { $BaselineParts += 0 }
                [version]$BaseLineVersion = New-Object -TypeName System.Version -ArgumentList $BaselineParts
                Write-Log -Message "BaseLineVersion: [$($BaseLineVersion |fl *|out-string)]" -source ${cmdletname}

                [int[]]$CompliantParts = $CompliantValue.Split('.')
                If ( $CompliantParts.Count -lt 4 ) { $CompliantParts += 0 }
                [version]$CompliantVersion = New-Object -TypeName System.Version -ArgumentList $CompliantParts
                Write-Log -Message "CompliantVersion: [$($CompliantVersion |fl *|out-string)]" -source ${cmdletname}

                [int]$CompareResult = $BaseLineVersion.CompareTo($CompliantVersion)
                Write-Log -Message "CompareResult: $CompareResult" -source ${cmdletname}

                [bool]$ReturnValue = $CompareResult -ge 0
            }
            Else {
                Write-Log -Message "Could Not Find Property 'Version'." -source ${cmdletname}
                [bool]$ReturnValue = $false;
            }

		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
    End {
        Write-Output -InputObject $ReturnValue;
    }
}
Function Remove-MicrosoftRedistributables
{
	[CmdletBinding()]
	param
	()
	
	Begin {		
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
	Process {
		Try {
            Get-InstalledApplication -Name 'Microsoft Visual C++*Redistributable*' -WildCard | %{
                If ( $_.UninstallString -like '*vc*redist*x*.exe*' ) {
                    [string]$exePath = $_.UninstallString.Split('"')|?{![string]::IsNullOrEmpty($_)}|Select-Object -First 1
                    Write-Log -Message "exePath: $exePath" -Source ${CmdletName}
                    [string[]]$Params = $_.UninstallString.Split('"')|?{![string]::IsNullOrEmpty($_)}|%{$_.ToLower()}|Select -Skip 1
                    If ( $Params -notcontains '/quiet') {
                        $Params += '/quiet'
                    }
                    Write-Log -Message "Params: $($Params -join "`r`n")" -Source ${CmdletName}
                    Execute-Process -Path $exePath -Parameters $Params -CreateNoWindow -PassThru -ContinueOnError $true;
                }
            }
            Remove-MSIApplications -Name 'Microsoft Visual C++*Redistributable*' -WildCard -PassThru -ContinueOnError $true; 
		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
}
Function Install-MicrosoftRedistributableUpdate
{
	[CmdletBinding()]
	param
	(
    )
	
	Begin {		
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
	Process
	{
		[string]${CmdletSection} = "Process"
		Try {
    
            [string[]]$FileFilter = @("$dirSupportFiles\vcredist_x86.exe");
            If ( $Is64Bit ) {$FileFilter += "$dirSupportFiles\vcredist_x64.exe";}
            Get-Item -ErrorAction 'SilentlyContinue' -Path $FileFilter -Force | %{ 
                [string[]]$ProcessParameters = @('/q',"/l $([system.io.path]::ChangeExtension("$configToolkitLogDir\$($_.Name)",'txt'))");
                Execute-Process -Path $_.FullName -Parameters $ProcessParameters -CreateNoWindow -PassThru -WorkingDirectory $_.DirectoryName -ContinueOnError $true;
            }
		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
}
##*--------------------------------------------------
Function Remove-NomadBranch
{
	[CmdletBinding()]
	param ()
	Begin {		
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
	Process
	{
		Try {

            $RemoveMSIApplications = Remove-MSIApplications -Name '1E NomadBranch*' -WildCard -ContinueOnError $true -ErrorAction SilentlyContinue
            Write-Log -Message "RemoveMSIApplications: '$($RemoveMSIApplications|fl *|out-string)'..." -Source ${CmdletName}    

            Get-InstalledApplication -Name '1E NomadBranch*' -WildCard | %{
                Write-Log -Message "Removing Nomad Branch '$($_.ProductCode)'..." -Source ${CmdletName}    
                Execute-MSI -Action Uninstall -Path $_.ProductCode -PassThru -ContinueOnError $true;
                Write-Log -Message "Done." -Source ${CmdletName}    
            }
		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
}
Function Install-NomadBranch
{
	[CmdletBinding()]
	param ()
	Begin {		
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
	Process
	{
		Try {
             If ( $(Get-OSArchitecture) -like '*64*' ) {
                [string]$FileSuffix = 'x64'
             }
             Else {
                [string]$FileSuffix = 'i386'
             }
             Write-Log -Message "FileSuffix: $FileSuffix." -Source ${CmdletName}    

             [string]$FileNameBase = 'ManualIn-Wks';
             Write-Log -Message "FileNameBase: $FileNameBase." -Source ${CmdletName}    

             [string]$FileExt = '.bat';
             Write-Log -Message "FileExt: $FileExt." -Source ${CmdletName}    

             [string]$FileDirectory = "$dirFiles\$fileSuffix"
             Write-Log -Message "FileDirectory: $FileDirectory." -Source ${CmdletName}    

             [string]$fileName = "$($fileNameBase)$($FileExt)"
             Write-Log -Message "fileName: $fileName." -Source ${CmdletName}    

             [string]$PayloadFilePath = Get-ChildItem -Path $FileDirectory -Filter $FileName -Force -Recurse| Select-Object -First 1 -ExpandProperty 'FullName'
             Write-Log -Message "PayloadFilePath: $PayloadFilePath." -Source ${CmdletName}    

             If ( [string]::IsNullOrEmpty($PayloadFilePath )){
                Throw "Unable To find file '$FileName' in '$FileDirectory'."
             }
             
             [psobject]$InstallProcess = Execute-Process -Path $env:comspec -Parameters @('/c',$PayloadFilePath) -CreateNoWindow -WorkingDirectory $FileDirectory -PassThru -ContinueOnError $true;
             Write-Log -Message "InstallProcess: '$($InstallProcess|fl *|out-string)'..." -Source ${CmdletName}    
		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
}
##*--------------------------------------------------
#endregion [Prerequesites]
##*===============================================

##*===============================================
#region [Certificates]
function Remove-Certificate
{
    [cmdletbinding()]
    Param(
    
        [ValidateNotNullOREmpty()]
        [ValidateSet('LocalMachine','CurrentUser',IgnoreCase=$true)]
        [string]$Scope = 'LocalMachine',

        [ValidateNotNullOREmpty()]
        [string]$Store = 'My',

        [ValidateNotNullOREmpty()]
        [string]$CertificateFilter = '*'
    )
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
        Try 
        { 
            [System.Security.Cryptography.X509Certificates.X509Store]$store = new-object 'System.Security.Cryptography.X509Certificates.X509Store' $Store,$Scope
            Write-Log -Message "Created Cert Store Object: $($store|fl *|out-string)" -source ${cmdletName}

            $store.Open("ReadWrite")
            Write-Log -Message "Opened Cert Store Object for 'ReadWrite' Access: $($?):[$($error[0])]" -source ${cmdletName}

            $certs = $store.Certificates
            Write-Log -Message "Found '$($certs.Count)' Certificates in Store." -source ${cmdletName}

            foreach ($cert in $certs) {
                Try
                {
                    Write-Log -Message "Cert: $($cert|fl *|out-string)'" -source ${cmdletName}

                    if (($cert.Subject -like $CertificateFilter) -or ($cert.Thumbprint -like $CertificateFilter))
                    {
                        write-log -message  "Deleting Certificate : '$($cert.Thumbprint)','$($cert.Subject)' ..." -Source ${CmdletName}
                        $store.Remove($cert)
                        Write-Log -Message "Removed Certificate '$($cert.Subject)': $($?):[$($error[0])]" -source ${cmdletName}
                    }
                }
                Catch
                {
                    Write-Log -Message "Exception Removing Certificate: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
                }
            }
        }
        Catch 
        {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        }  
    }
    End
    {
        $store.Close();
    }
}
function Clear-SccmClientRsaFile
{
    [cmdletbinding()]
    Param()
    Begin
    {
      [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
      Try 
      { 
        [string]$RSA = "$env:ALLUSERSPROFILE\Microsoft\Crypto\RSA"
        Write-Log -Message "RSA: $RSA" -Source ${CmdletName}

        [string]$MachineKeys = "$RSA\MachineKeys"
        Write-Log -Message "MachineKeys: $MachineKeys" -Source ${CmdletName}

        [string]$BatchOutput = Join-Path -Path $Env:Temp -ChildPath "RemoveCertGen.txt"
        Write-Log -Message "BatchOutput: $BatchOutput" -Source ${CmdletName}
        
        [string]$BatchScript = Join-Path -Path $Env:Temp -ChildPath "RemoveCertGen.bat"
@"
CD /D `"$($RSA)`"
takeown /f MachineKeys /r /d y
icacls MachineKeys /T /grant Administrators:F
CD /D `"$($MachineKeys)`"
takeown /f * /r /d y
icacls * /T /grant Administrators:F
DEL /S /Q %CD%\19c5cf9c7b5dc9de3e548adb70398402_bdc53444-4ebf-4226-8f9f-fcacc0a1f908
"@ | OUt-File -FilePath $BatchScript -Encoding ascii -Force;
        $ReturnProcess = Execute-Process -Path $Env:ComSpec -Parameters '/c',$BatchScript -WorkingDirectory $Env:Temp -PassThru -CreateNoWindow -ContinueOnError $true
        Write-Log -Message "Return: $($ReturnProcess | Fl * | Out-String)" -Source ${CmdletName}

      }
      Catch 
      {
        Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
      }  
    }
  }
function Reset-SccmClientSmsCertificateConfig
{
    [CmdletBinding()]
    Param
    (
    )
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
        ## Remove RSA Encryption Generator
        Try 
        { 
            
            [string]$GenLeaf = 'MachineKeys\19c5cf9c7b5dc9de3e548adb70398402*'
            Write-Log -Message "GenLeaf: $GenLeaf" -Source ${CmdletName}
            
            [string]$GenParent = Join-Path -Path $env:ALLUSERSPROFILE -ChildPath 'Microsoft\Crypto\RSA';
            Write-Log -Message "GenParent: $GenParent" -Source ${CmdletName}
                        
            Set-Owner -Path $GenParent -Recurse -ErrorAction 'SilentlyContinue';
            Write-Log -Message "Set Owner On Folder '$GenParent': $($?):['$($error[0])]'" -Source ${CmdletName}

            [string]$GenPath = Join-Path -Path $GenParent -ChildPath $GenLeaf
            Write-Log -Message "GenPath: $GenPath" -Source ${CmdletName}

            Get-ChildItem -Path $GenPath -Force -Recurse | %{  
                Remove-File -LiteralPath $_.FullName -ContinueOnError $true;
            }
            Write-Log -Message "Attempted To Remove File: '$GenPAth': $($?):['$($error[0])]'" -Source ${CmdletName}
        } 
        Catch 
        {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        } 

        ## Remove Certificates
        Try 
        { 
            Write-Log -Message "Removing Certificates From 'Cert:\LocalMachine\SMS\*'..." -Source ${CmdletName}
            Remove-Certificate -Scope 'LocalMachine' -Store 'SMS' -CertificateFilter '*' -ErrorAction 'SilentlyContinue'
            Write-Log -Message "Attempted To Remove File: '$GenPAth': $($?):['$($error[0])]'" -Source ${CmdletName}
        } 
        Catch 
        {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        } 
    }
}
#endregion [Client Certificate]
##*===============================================

##*===============================================
#region [Permissions]
Function Reset-LocalSecurityPolicy
{
	[CmdletBinding()]
	param
	()
	Begin
	{
		[string]${CmdletSection} = "Begin"
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
	Process
	{
		[string]${CmdletSection} = "Process"
		Try
		{
            [psobject]$ExecuteResults = Execute-Process -Path "$Env:windir\system32\secedit.exe" -Parameters "/configure","/cfg $Env:Windir\Inf\defltbase.inf","/db defltbase.sdb","/verbose" -CreateNoWindow -PassThru -ContinueOnError $true;
            Write-Log -Message "ExecuteResults: $($ExecuteResults|fl *|out-string)" -Source ${CmdletName} -Severity 2
		}
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
}
Function Set-Owner 
{
    [cmdletbinding(SupportsShouldProcess = $True)]
    Param (
        [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
        [Alias('FullName')]
        [string[]]$Path,
        [parameter()]
        [string]$Account = 'Builtin\Administrators',
        [parameter()]
        [switch]$Recurse
    )
    Begin 
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process 
    {
        Try
        {
            #Prevent Confirmation on each Write-Debug command when using -Debug
            If ($PSBoundParameters['Debug']) {$DebugPreference = 'Continue'}
            Try 
            {
                [void][TokenAdjuster]
            } 
            Catch 
            {
                Add-Type $(@"
            using System;
            using System.Runtime.InteropServices;

             public class TokenAdjuster
             {
              [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
              internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
              ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
              [DllImport("kernel32.dll", ExactSpelling = true)]
              internal static extern IntPtr GetCurrentProcess();
              [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
              internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr
              phtok);
              [DllImport("advapi32.dll", SetLastError = true)]
              internal static extern bool LookupPrivilegeValue(string host, string name,
              ref long pluid);
              [StructLayout(LayoutKind.Sequential, Pack = 1)]
              internal struct TokPriv1Luid
              {
               public int Count;
               public long Luid;
               public int Attr;
              }
              internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
              internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
              internal const int TOKEN_QUERY = 0x00000008;
              internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
              public static bool AddPrivilege(string privilege)
              {
               try
               {
                bool retVal;
                TokPriv1Luid tp;
                IntPtr hproc = GetCurrentProcess();
                IntPtr htok = IntPtr.Zero;
                retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
                tp.Count = 1;
                tp.Luid = 0;
                tp.Attr = SE_PRIVILEGE_ENABLED;
                retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
                retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
                return retVal;
               }
               catch (Exception ex)
               {
                throw ex;
               }
              }
              public static bool RemovePrivilege(string privilege)
              {
               try
               {
                bool retVal;
                TokPriv1Luid tp;
                IntPtr hproc = GetCurrentProcess();
                IntPtr htok = IntPtr.Zero;
                retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
                tp.Count = 1;
                tp.Luid = 0;
                tp.Attr = SE_PRIVILEGE_DISABLED;
                retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
                retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
                return retVal;
               }
               catch (Exception ex)
               {
                throw ex;
               }
              }
             }
"@)
                
            }

            #Activate necessary admin privileges to make changes without NTFS perms
            [void][TokenAdjuster]::AddPrivilege("SeRestorePrivilege") #Necessary to set Owner Permissions
            [void][TokenAdjuster]::AddPrivilege("SeBackupPrivilege") #Necessary to bypass Traverse Checking
            [void][TokenAdjuster]::AddPrivilege("SeTakeOwnershipPrivilege") #Necessary to override FilePermissions
            ForEach ($Item in $Path) 
            {
                Write-Log -Message "FullName: $Item" -Source ${CmdletName} 
                #The ACL objects do not like being used more than once, so re-create them on the Process block
                $DirOwner = New-Object System.Security.AccessControl.DirectorySecurity
                $DirOwner.SetOwner([System.Security.Principal.NTAccount]$Account)
                $FileOwner = New-Object System.Security.AccessControl.FileSecurity
                $FileOwner.SetOwner([System.Security.Principal.NTAccount]$Account)
                $DirAdminAcl = New-Object System.Security.AccessControl.DirectorySecurity
                $FileAdminAcl = New-Object System.Security.AccessControl.DirectorySecurity
                $AdminACL = New-Object System.Security.AccessControl.FileSystemAccessRule($Account,'FullControl','ContainerInherit,ObjectInherit','InheritOnly','Allow')
                $FileAdminAcl.AddAccessRule($AdminACL)
                $DirAdminAcl.AddAccessRule($AdminACL)
                Try {
                    $Item = Get-Item -LiteralPath $Item -Force -ErrorAction Stop
                    If (-NOT $Item.PSIsContainer) 
                    {
                        If ($PSCmdlet.ShouldProcess($Item, 'Set File Owner')) 
                        {
                            Try 
                            {
                                $Item.SetAccessControl($FileOwner)
                            } 
                            Catch 
                            {
                                Write-Log -Message "Couldn't take ownership of $($Item.FullName)! Taking FullControl of $($Item.Directory.FullName)" -Source ${CmdletName} 
                                $Item.Directory.SetAccessControl($FileAdminAcl)
                                $Item.SetAccessControl($FileOwner)
                            }
                        }
                    } 
                    Else 
                    {
                        If ($PSCmdlet.ShouldProcess($Item, 'Set Directory Owner')) 
                        {
                            Try 
                            {
                                $Item.SetAccessControl($DirOwner)
                            } Catch 
                            {
                                Write-Log -Message "Couldn't take ownership of $($Item.FullName)! Taking FullControl of $($Item.Parent.FullName)" -Source ${CmdletName} 
                                $Item.Parent.SetAccessControl($DirAdminAcl) 
                                $Item.SetAccessControl($DirOwner)
                            }
                        }
                        If ($Recurse) 
                        {
                            [void]$PSBoundParameters.Remove('Path')
                            Get-ChildItem $Item -Force | Set-Owner @PSBoundParameters
                        }
                    }
                } 
                Catch 
                {
                    Write-Log -Message "$($Item): $($_.Exception.Message)" -Source ${CmdletName} 
                }
            }
        }
        Catch
        {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        }
    }
    End {  
        #Remove priviledges that had been granted
        [void][TokenAdjuster]::RemovePrivilege("SeRestorePrivilege") 
        [void][TokenAdjuster]::RemovePrivilege("SeBackupPrivilege") 
        [void][TokenAdjuster]::RemovePrivilege("SeTakeOwnershipPrivilege")     
    }
}
#endregion [Permissions]
##*===============================================

##*===============================================
#region [Client Return Code]
function Analyze-SccmSetupResults {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$SetupPath = "$env:windir\ccmsetup\Logs",

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        $ExitCode = $mainExitCode
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [psobject[]]$ReturnValue = @();
    }
    Process {
        Try {
            ## Evaluate Overall Success
            If (@(0,7) -notcontains $ExitCode ){

            ## Test For Task Scheduler Corruption
            [bool]$TaskSchedulerError = Test-TaskSchedulerCorruption
            Write-Log -Message "TaskSchedulerError: $TaskSchedulerError" -Source ${CmdletName}
            [bool]$WmiErrors = Test-CCMSetupWmiErrors -LogPath "$SetupPath\ccmsetup.log" -ErrorAction 'SilentlyContinue';
            Write-Log -Message "WmiErrors: $WmiErrors" -Source ${CmdletName}
            [bool]$FailedRegister = Test-CCMSetupFailedRegister
            Write-Log -Message "FailedRegister: $FailedRegister" -Source ${CmdletName}
            
            

            ## Cleanup Existing Stuff If Repair Happening
            If ( $TaskSchedulerError -or $WmiErrors -or $FailedRegister ){ 
                Execute-PostClientUninstall|Out-Null;$RebootRequired=$true;
            }

            [bool]$RebootRequired = $false;
        
            ## Remediate Any Issues
            If ( $TaskSchedulerError ) { 
                Remediate-TaskScheduler|Out-Null; 
            }
            If ( $WmiErrors ) { 
                Rebuild-WmiRepository|Out-Null;
            }
            If ( $FailedRegister ) {
                Remove-PolicyPlatform|Out-Null; 
                Remove-MicrosoftRedistributables|Out-Null;
            }       
            }
            Else {
            
            }
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)"  -source ${cmdletname} -severity 2
        }
    }
    End {
        
    }
}
function Convert-Number {
[CmdletBinding()]
    param
        (
        [Parameter(Mandatory=$True)]
            $Number,
        [Parameter(Mandatory=$False,ParameterSetName='Binary')]
            [switch]$ToBinary,
        [Parameter(Mandatory=$False,ParameterSetName='Hex')]
            [switch]$ToHexadecimal,
        [Parameter(Mandatory=$False,ParameterSetName='Signed')]
            [switch]$ToSignedInteger,
        [Parameter(Mandatory=$False,ParameterSetName='Unsigned')]
            [switch]$ToUnSignedInteger
        )
 
    $binary = [Convert]::ToString($Number,2)
 
    if ($ToBinary)
    {
        $binary
    }
 
    if ($ToHexadecimal)
    {
        $hex = "0x" + [Convert]::ToString($Number,16)
        $hex
    }
 
    if ($ToSignedInteger)
    {
        $int32 = [Convert]::ToInt32($binary,2)
        $int32
    }
    if ($ToUnSignedInteger)
    {
        $Uint64 = [Convert]::ToUInt64($binary,2)
        $Uint64
    }
}
function Get-CustomErrors {
	[CmdletBinding()]
    [OutputType([psobject[]])]
	param (

        [Parameter(Mandatory=$false)]
        [ValidateSet('CBS','WU','BITS','INET','WINHTTP','MSI','WMI','CCM')]
        [string]$ErrorSource
    )
	Begin  {
	    [string]${CmdletName} = $PsCmdlet.MyInvocation.MyCommand.Name;	
        [psobject[]]$ReturnValue = @();
    }
    Process {
        Try {
            [string]$PropertyMajor = "$($ErrorSource)_Errors"
            Write-Log -Message "PropertyMajor: $PropertyMajor" -Source ${CmdletName}
            [string]$PropertyMinor= "$($ErrorSource)_Error"
            Write-Log -Message "PropertyMinor: $PropertyMinor" -Source ${CmdletName}
            $ErrorObjects = $xmlConfig.CCM_SetupErrors.$PropertyMajor
            [psobject[]]$Errors = $ErrorObjects |select-object -first 1 -ExpandProperty $PropertyMinor
            Write-Log -Message "ErrorObjects: $ErrorObjects" -Source ${CmdletName}
            [string[]]$PropertyNAmes =  $Errors | Select-Object -First 1 -Property Attributes,ChildNodes | %{$_.Attributes.Name +  $_.ChildNodes.Name}
            Write-Log -Message "PropertyNAmes: $PropertyNAmes" -Source ${CmdletName}
            [psobject[]]$ReturnValue = $Errors|Select-Object -Property $PropertyNames | %{Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Message' -Value $_.'#text' -PassThru -Force}|Select-Object -Property $(@($PropertyNAmes|Select -SkipLast 1) + 'Message')
            Write-Log -Message "ReturnValue: $ReturnValue" -Source ${CmdletName}
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source 'Convert-Variable' -Severity 2
        }
	}
    End {
        Write-Output -InputObject $ReturnValue
    }
}
function Test-CustomError {
	[CmdletBinding(DefaultParameterSetName='PassValue')]
    [OutputType([System.Boolean],ParameterSetName='PassQuiet')]
    [OutputType([System.Management.Automation.PSObject[]],ParameterSetName='PassValue')]
	param (
        [Parameter(Mandatory=$true, ParameterSetName='PassQuiet')]
        [Parameter(Mandatory=$true, ParameterSetName='PassValue')]
        [ValidateNotNullOrEmpty()]
        [object[]]$Errors,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('CBS','WU','BITS','INET','WINHTTP','MSI','WMI','CCM')]
        [string]$ErrorSource,

        [Parameter(Mandatory=$false, ParameterSetName='PassQuiet')]
        [switch]$Quiet
    )
	Begin  {
	    [string]${CmdletName} = $PsCmdlet.MyInvocation.MyCommand.Name;	
        [System.Management.Automation.PSObject[]]$Results = @();
    }
    Process {
        Try {
            [System.Management.Automation.PSObject[]]$ReferenceErrors = Get-CustomErrors -ErrorSource $ErrorSource
            Foreach ( $ErrorNumber in $Errors ) {
                 If ( $ErrorNumber -notmatch '0x[A-Za-z0-9]{8}' ) {
                    [string]$Hexidecimal = '0x{0:X8}' -f $ErrorNumber
                }
                else {
                    [string]$Hexidecimal = $ErrorNumber
                }               
                $ReferenceErrors | ? {  $($_.HResult).ToUpper() -like $Hexidecimal.ToUpper()} | %{$Results += $_}
            }
            Write-Log -Message "Found $($Results.Count) Matching Errors." -Source ${CmdletName}
            If ( $PsCmdlet.ParameterSetName -eq 'PassValue' ) {
                [System.Management.Automation.PSObject[]]$ReturnValue = $Results;
            }
            Else {
                [System.Boolean]$ReturnValue = $Results.Count -gt 0;
            }
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source 'Convert-Variable' -Severity 2
        }
	}
    End {
        Write-Output -InputObject $ReturnValue
    }
}
function Get-ClientErrorMessage {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [Int32]$ExitCode
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [psobject[]]$ReturnValue = @();

        If ( Test-Path -Path "$env:Temp\SCCMreporting.log" ) {Remove-Item -Path "$env:Temp\SCCMreporting.log" -force -ea SilentlyContinue;}
    }
    Process {
        Try {
            Add-Type -Path $GLOBAL:CCM_SRSRESOURCES_DLL | Out-Null;
            [string]$Message = [SrsResources.Localization]::GetErrorMessage($ExitCode,'en-US');

            If ( [string]::IsNullOrEmpty($Message) -or $Message -like 'Unknown Error' ) {
                $xmlConfig.CCM_SetupErrors.ChildNodes | ?{$_.Name -notlike 'CCM'} | %{
                    Foreach ($ErrorObject in @(Get-CustomErrors -ErrorSource $_.Name) ){
                        If( (Convert-Number -Number $ErrorObject.HResult -ToBinary) -eq (Convert-Numeber -Number $ExitCode)){[string]$Message = $ErrorObject.Message; [string]$Source = $ErrorObject.Message; break;}
                    }
                }
            }
            Else {
                [string]$MatchSourceLine = gc "$env:Temp\SCCMreporting.log"|Select-String "Found resource string " | Select -First 1 -ExpandProperty Line
                Write-Log -Message "MatchSourceLine: $MatchSourceLine" -Source ${CmdletName}

                 If ( $MatchSourceLine -like '*WUA:*'){
                    $Source = "WU"
                 }
                  elseIf ($MAtchSourceLine -like "*wmiutils.dll*"){
                    $Source = "WMI"
                 }
                 elseIf ($MAtchSourceLine -like "*System*"){
                    $Source = "Windows"
                 }
                 Else {
                    $Source = "WinHTTP"
                 }
             }        }
        Catch {
            Write-Host "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" 
        }
    }
    End {
        Write-Output -InputObject $(New-Object -TypeName PSObject -Property @{
            Message=$Message;
            Source=$Source;
        }); 
    }
}
function Test-HresultFailed($hr) {
  return $hr -lt 0
}
function Test-Hresult($Error) {
    [string]$HexString=$([System.Convert]::ToString($Error,16))
    
  return ($HexString.Length -eq 8 -and $HexString.Substring(0,1) -eq '8')
}
function Convert-ErrorCode {
[CmdletBinding()]
    param
        (
        [Parameter(Mandatory=$True,ParameterSetName='Decimal')]
            [int64]$DecimalErrorCode,
        [Parameter(Mandatory=$True,ParameterSetName='Hex')]
            $HexErrorCode
        )
if ($DecimalErrorCode)
    {
        $hex = '{0:x}' -f $DecimalErrorCode
        $hex = "0x" + $hex
        $hex
    }
 
if ($HexErrorCode)
    {
        $DecErrorCode = $HexErrorCode.ToString()
        $DecErrorCode
    }
}

function Get-Win32ErrorMessage($code) {
    $ex = New-Object System.ComponentModel.Win32Exception($code)
    return $ex.Message
}
function Get-SccmErrorMessage {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        $ExitCode,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path -Path $_})]
        [string]$DataFile = "$dirSupportFiles\ccmsetup.csv"
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [psobject[]]$ReturnValue = @();
    }
    Process {
        Try {
            Add-Type -Path "$dirSupportFiles\SrsResources.dll"|Out-Null;
            [string]$Message = [SrsResources.Localization]::GetErrorMessage($ExitCode,'en-US');
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)"  -source ${cmdletname} -severity 2
        }
    }
    End {
        Write-Output -InputObject $($ReturnValue|Select-Object -Property 'Message','SignedInt','UnsignedInt','Hex','Source')
    }
}

function Parse-SccmLogLine {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Text
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [psobject]$ReturnValue = New-Object -TypeName PSOBject
    }
    Process
    {
        Try {
            [string]$time=([regex]'(?<=time=")\d{2}:\d{2}:\d{2}\.\d{3}(\+|-)\d{3}(?=")').matches($Text)|select -first 1 -ExpandProperty value -ea SilentlyContinue;
            [string]$day=([regex]'(?<=date=")\d{2}-\d{2}-\d{4}(?=")').matches($Text)|select -first 1 -ExpandProperty value -ea SilentlyContinue;
            [datetime]$Date="$time $day"
            [string]$component = ([regex]'(?<=component=")\w+(?=")').matches($Text)|select -first 1 -ExpandProperty value -ea SilentlyContinue;
            [string]$context = ([regex]'(?<=context=")\w+(?=")').matches($Text)|select -first 1 -ExpandProperty value -ea SilentlyContinue;
            [string]$typeInt = ([regex]'(?<=type=")\d{1}(?=")').matches($Text)|select -first 1 -ExpandProperty value -ea SilentlyContinue;
            [string]$fileString = $(([regex]'(?<=file=").*(?=")').matches($Text)|select -first 1 -ExpandProperty value -ea SilentlyContinue);
            [string]$Type = $(if( $typeInt -eq '0' ){'Information'}elseif($typeInt -eq '1' ){'Information'}ElseIf($typeInt -eq '2'){ 'Warning' }ElseIf($typeInt -eq '3'){'Error'; })
            [string]$thread = ([regex]'(?<=thread=")\d{1,16}(?=")').matches($Text)|select -first 1 -ExpandProperty value;    
            [string]$message=([regex]'(?<=<!\[LOG\[)(.*)(?=\]LOG\]!>)').Matches($Text)
            #[string]$File = $fileString.Split(':')|select -first 1;
            #[string]$LineNumber= $fileString.Split(':')|select -last 1          
            [psobject]$ReturnValue = New-Object -TypeName PSOBject -Property (@{Message=$Message;Date=$Date;Component=$Component;Context=$Context;Type=$Type;Thread=$thread;LineNumber=$($fileString.Split(':')|select -last 1);File=$($fileString.Split(':')|select -first 1);});
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
    End
    {
        Write-Output -InputObject $ReturnValue
    }
}
function Join-SccmLogLines {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path -Path $_})]
        [string]$FilePath
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [string[]]$ReturnValue=@()
    }
    Process
    {
        Try {
            
            [string[]]$Lines=Get-Content -Path $FilePath|?{![string]::IsNullOrEmpty($_.Trim())}
            [string]$TrailingLine=$Lines[$LInes.Count-1]
            [string]$LastLine = $Lines[0];
            For($i=1;$i -lt $Lines.Count;$i++) {
                Try {
                    If ( $Lines[$i].Substring(0,3) -eq '<![' ) { $ReturnValue += $LastLine; [string]$LastLine = $Lines[$i]; }
                    Else {  $LastLine += " $($Lines[$i])" }
                }
                Catch {
                    $ReturnValue+=$Lines[$i]
                }
            }
            $ReturnValue+=$TRailingLine
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)"  -source ${cmdletname} -severity 2
        }
    }
    End
    {
        Write-Output -InputObject $ReturnValue
    }
}
function Format-SccmLog {
    [CmdletBinding()]
    [OutputType([psobject[]])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path -Path $_})]
        [string]$FilePath = "$env:windir\ccmsetup\logs\ccmsetup.log"
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [psobject[]]$ReturnValue = @();
    }
    Process
    {
        Try {
            Join-SccmLogLines -FilePath $FilePath | Foreach-Object {$ReturnValue += $(Parse-SccmLogLine -Text $_)}
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)"  -source ${cmdletname} -severity 2
        }
    }
    End
    {
        Write-Output -InputObject $ReturnValue
    }
}

Function ConvertFrom-Win32ErrorToHResult {
	[CmdletBinding()]
	Param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Int64]$ExitCode
    )
	Begin {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [string]$ReturnValue = [string]::Empty;
	}
	Process {
         Try {
            Try {
            add-type -typedefinition @"
using System;
using System.Drawing;
using System.Collections;
using System.ComponentModel;
using System.Runtime.InteropServices;
public static class HResult
{
	public const int FACILITY_WIN32 = unchecked((int)0x80070000);
	public static int HRESULT_FROM_WIN32(int x)
	{
		return x <= 0 ? x : ((x & 0x0000FFFF) | FACILITY_WIN32);
	}
}
"@ -Ea SilentlyContinue -IgnoreWarnings
            }
            Catch {
            
            }
            Finally {
                [string]$ReturnValue = [HResult]::HRESULT_FROM_WIN32($ExitCode);
            }
            
        } 
        Catch  {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        }          
	}
    End {
        Write-Output -InputObject $ReturnValue
    }
}
function ConvertFrom-HresultErrorToWin32($hr) {
  return $hr -band 0xFFFF
}

function Test-CCMSetupWmiErrors {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [parameter(Mandatory=$true, Position=0)][string]$LogPath
    )
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [bool]${ReturnValue} = $false;
    }
    Process
    {

        Try {                
            [Int32]$Error = Search-SCCMClientSetupReturnCode -LogPath $LogPath
            Write-Log -Message "Error: $Error" -Source ${CmdletName}

            If ( $Error -eq 0 ) {
                Throw "No Error At Last Line."
            }

            [string[]]$WmiMatches = @();
            gc $LogPath | Select-Object -Last 20 | ?{ 
                Write-Log -Message "(DEBUG) [Line]:[$($_)]" -Source ${CmdletName}
                Write-Log -Message "(DEBUG) [Match #1]:[$($($_ -like '*Failed*WMI*type="3"*'))]" -Source ${CmdletName}
                Write-Log -Message "(DEBUG) [Match #2]:[$($($_ -like '*unable to create the WMI namespace CCM*'))]" -Source ${CmdletName}
                Write-Log -Message "(DEBUG) [Match #3]:[$($($_ -like "*Failed to open to WMI namespace '\\.\root\ccm*"))]" -Source ${CmdletName}
                
                ($_ -like '*Failed*WMI*type="3"*' -or $_ -like '*Setup was unable to create the WMI namespace CCM*' -or "*Failed to open to WMI namespace '\\.\root\ccm*")
            } | %{$WmiMatches += $_}
            Write-Log -Message "Found '$($WmiMatches.Count)' Matching Lines." -Source ${CmdletName}

            [bool]${ReturnValue} = $WmiMatches.Count -gt 0
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
    End
    {
        Write-Output -InputObject ${ReturnValue}
    }
}
function Test-CCMSetupFailedRegister {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
	
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [bool]$ReturnValue = $false
    }
    Process
    {
        Try
        {
            [string]$CcmSetupPath = Join-Path -Path $Env:Windir -ChildPAth 'ccmsetup\Logs'
            Write-Log -Message  "CcmSetupPath: $CcmSetupPath"  -Source ${CmdletName}

            If ( !(Test-Path -Path $CcmSetupPath) ) {
                Throw "Could Not Locate CcmSetup Path."
            }

            [string]$ClientMsiLog = Get-ChildItem -Path $CcmSetupPath -Filter 'ccmsetup.log' -Force | Select-Object -First 1 -ExpandProperty 'FullName'
            Write-Log -Message  "ClientMsiLog: $ClientMsiLog"  -Source ${CmdletName}

            If ( [string]::IsNullOrEmpty($ClientMsiLog) ) {
                Throw "Could Not Locate 'client.msi.log' in '$CcmSetupPath' ."
            }

            [string]$MatchString = '*MSI: Module *.dll failed to register.  HRESULT *'
            #Write-Log -Message  "MatchString: $MatchString"  -Source ${CmdletName}

            [string[]]$MatchArray = @();
            Get-Content -Path $ClientMsiLog | ? { $_ -like $MatchString } | %{ $MatchArray += $_ }
            Write-Host "Found $($MatchArray.Count) Matches." 

            [bool]$ReturnValue = $MatchArray.Count -gt 0

        }
        Catch
        {
            Write-Host "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" 
        }
    }
    End
    {
        Write-Output -InputObject $ReturnValue
    }
}
function Test-TaskSchedulerCorruption {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [bool]$ReturnValue = $false
    }
    Process
    {
        Try
        {
            [string]$CcmSetupPath = Join-Path -Path $Env:Windir -ChildPAth 'ccmsetup\Logs'
            Write-Log -Message  "CcmSetupPath: $CcmSetupPath"  -Source ${CmdletName}

            If ( !(Test-Path -Path $CcmSetupPath) ) {
                Throw "Could Not Locate CcmSetup Path."
            }

            [string]$ClientMsiLog = Get-ChildItem -Path $CcmSetupPath -Filter 'client.msi.log' -Force | Select-Object -First 1 -ExpandProperty 'FullName'
            Write-Log -Message  "ClientMsiLog: $ClientMsiLog"  -Source ${CmdletName}

            If ( [string]::IsNullOrEmpty($ClientMsiLog) ) {
                Throw "Could Not Locate 'client.msi.log' in '$CcmSetupPath' ."
            }

            [string]$MatchString = ' ERROR: RegisterTaskDefinition failed with error '
            Write-Log -Message  "MatchString: $MatchString"  -Source ${CmdletName}

            [string[]]$MatchArray = @();
            Get-Content -Path $ClientMsiLog | ? { $_ -match $MatchString } | %{ $MatchArray += $_ }
            Write-Host "Found $($MatchArray.Count) Matches." 

            [bool]$ReturnValue = $MatchArray.Count -gt 0

        }
        Catch
        {
            Write-Host "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" 
        }
    }
    End
    {
        Write-Output -InputObject $ReturnValue
    }
}

function Expand-SCCMClientSetupReturnCode 
{
    [CmdletBinding()]
    [OutputType([Int32])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName = $env:ComputerName,
        [switch]$SetGlobalVariable = $true
    )
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [Int32]${ReturnValue} = 69000;
    }
    Process
    {
        If ( $ComputerName.ToLower() -eq $Env:ComputerName.ToLower() )
        {
            [string]$LogPath = "$Env:Windir\Ccmsetup\Logs\ccmsetup.log"
        }
        Else
        {
            [string]$LogPath = "\\$ComputerName\Admin$\Ccmsetup\Logs\ccmsetup.log"
        }
        Write-Log -Message "LogPath: $LogPath" -Source ${CmdletName}

        
        [Int32]${ReturnValue} = Search-SCCMClientSetupReturnCode -LogPath $LogPath;
        Write-Log -Message "ReturnValue: ${ReturnValue}" -Source ${CmdletName}
        $global:CcmSetupExitCode = ${ReturnValue}
    }
    End
    {
        Write-Output -INputObject ${ReturnValue}
    }
}
function Search-SCCMClientSetupReturnCode
{
    [CmdletBinding()]
    [OutputType([Int])]
    param(
        [parameter(Mandatory=$false, Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath = "$env:windir\ccmsetup\logs\ccmsetup.log"
    )
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [Int]${ReturnValue} = 69001;
    }
    Process
    {
        Try
        {
            [array]$LogContent = gc $LogPath | Select -Last 30;
            [Array]::Reverse($LogContent);
            [string]$Content = $LogContent -join "`r`n"
            [string]$RegexMatch = ([regex]'(?<=((CcmSetup is exiting with return code )|(CcmSetup failed with error code )|(The error code is )))(.*)(?=([]](LOG)))').Matches($Content)|select-object -last 1 -ExpandProperty 'Value'
            Write-Log -Message "RegexMatch: $($RegexMatch)" -Source ${cmdletname}

            If (([string]::IsNullOrEmpty($RegexMatch))){
                Throw "Could Not Extract CCM Exit Code."
            }
            Else {
                Write-Log -Message "Regex Not Null." -Source ${cmdletname}                

                #[bool]$HexidecimalMatch = $RegexMatch -match '^(0x8\d{7})$'
                [bool]$HexidecimalMatch = $RegexMatch -like '0x*' -or $RegexMatch -like '8007*'
                Write-Log -Message "HexidecimalMatch: $($HexidecimalMatch)" -Source ${cmdletname}

                If ( $HexidecimalMatch ){
                    [Int]${ReturnValue} = [System.Convert]::ToInt32($RegexMatch.Trim(),16)
                }
                Else {
                    [Int]${ReturnValue} = [Int32]::Parse($RegexMatch)
                }
                Write-Log -Message "ReturnValue: $(${ReturnValue})" -Source ${cmdletname}
            }
        }
        Catch
        {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        }
    }
    End
    {
        Write-Output -InputObject ${ReturnValue}
    }
}
#endregion [Client Return Code]
##*===============================================

##*===============================================
#region [WMI]
function Execute-WmiDialog
{
    [CmdletBinding()]
    param
    (
    [Parameter(Mandatory=$false,Position=0)]
    [string]$WmiDiag = $global:WmiDiagVbs,

    [Parameter(Mandatory=$false,Position=1)]
    [string]$FtpUrl = $global:FtpUrl,

    [Parameter(Mandatory=$false,Position=2)]
    [string]$WmiDiagLogPath = $global:WmiDialogLogPath,

    [Parameter(Mandatory=$false,Position=3)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WmiDiagArguments = $global:WmiDialogParameters
    )
	
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [string]$ReturnValue = [string]::Empty;
    }
    Process
    {
        Try
        {
            If ( ![string]::IsNullOrEmpty($WmiDiag) )
            {
                Write-Log -Message "WmiDiag: $WmiDiag" -Source ${CmdletName}
                If ( Test-Path -Path $WmiDiag )
                {
                    [string]$wmiDiagScriptPath = $WmiDiag;
                    [bool]$DownloadFtp = $false;
                }
                Else
                {
                    [bool]$DownloadFtp = $true;
                }
            }

            Else
            {
                [bool]$DownloadFtp = $true;
            }
            
            Write-Log -Message "DownloadFtp: $DownloadFtp" -Source ${CmdletName}

            If ( $DownloadFtp -and [string]::IsNullOrEmpty($FtpURl))
            {
                Throw "Unable To Find Script."
            }
            ElseIf ( $DownloadFtp )
            {
                [string]$TargetScriptPath = Join-Path -Path $Env:windir -ChildPath 'Temp\WmiDiag.vbs'
                Invoke-FtpRequest -url $FtpUrl -localPath $TargetScriptPath
                [string]$wmiDiagScriptPath = $TargetScriptPAth
            }
            write-Log -Message "wmiDiagScriptPath: $wmiDiagScriptPath" -Source ${CmdletName}
            
            If ( !(Test-Path -Path $WmiDiagLogPath) )
            {
                New-Item -Path $WmiDiagLogPath -ITemType 'Directory' -Force; 
                Write-Log -Message "Created WmiDiag Directory ($?)" -Source ${CmdletName}
            }

            [string[]]$cscriptArguments = @('//NoLogo',$wmiDiagScriptPath) + $WmiDiagArguments;
            Write-Log -Message "cscriptArguments: $($cscriptArguments -join ' ')" -Source ${CmdletName}

            [hashtable]$ExecuteProcessSplat = @{
                Path=$cscriptExe; 
                Parameters=$cscriptArguments; 
                CreateNoWindow=[switch]::Present; 
                WorkingDirectory=$systemDirectory; 
                PassThru=[switch]::Present;
                ContinueOnError=$true;
            }
            Execute-Process @ExecuteProcessSplat;
        }
        Catch
        {
            Write-Log -Message "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 3;
        }
    }
    end
    {

    }
}
function Get-WbemPath
{
    [CmdletBinding()]
    [OutputType([string])]
    param()
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [string]$ReturnValue = [string]::Empty;
    }
    Process
    {
        Try
        {
            [string]$ReturnValue = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Wbem\CIMOM' -Name 'Working Directory' -ErrorAction 'SilentlyContinue' | `
                Select-Object -ExpandProperty 'Working Directory' | `
                Foreach-Object {$_ -replace '([%])(\w+)([%])',"`$env:`$2"} | `
                Select-Object -First 1
        }
        Catch
        {
            Write-Log -Message "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
    End
    {
        Write-Output -InputObject ($ReturnValue)
    } 
}
function Call-Winmgmt
{
	[CmdletBinding(DefaultParameterSetName = 'VerifyRepository')]
	[OutputType([psobject], ParameterSetName = 'BackupRepository')]
	[OutputType([psobject], ParameterSetName = 'RestoreRepository')]
	[OutputType([psobject], ParameterSetName = 'SyncPerfCounters')]
	[OutputType([psobject], ParameterSetName = 'VerifyRepository')]
	[OutputType([psobject], ParameterSetName = 'RebuildRepository')]
	[OutputType([psobject], ParameterSetName = 'ResetRepository')]
	[OutputType([psobject], ParameterSetName = 'SalvageRepository')]
	[OutputType([psobject], ParameterSetName = 'ReRegisterMofFiles')]
	[OutputType([psobject])]
	param
	(
		[Parameter(ParameterSetName = 'RestoreRepository', Position = 0)]
		[switch]$Restore,
		
		[Parameter(ParameterSetName = 'BackupRepository', Position = 0)]
		[switch]$Backup,

		[Parameter(ParameterSetName = 'BackupRepository', Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false, ValueFromRemainingArguments = $false, Position = 2)]
		[Parameter(ParameterSetName = 'RestoreRepository', Mandatory = $false, ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $false, ValueFromRemainingArguments = $false, Position = 2)]
		[switch]$Force,
		
		[Parameter(ParameterSetName = 'BackupRepository', Mandatory = $true, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false, ValueFromRemainingArguments = $false, Position = 1)]
		[Parameter(ParameterSetName = 'RestoreRepository', Mandatory = $true, ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $false, ValueFromRemainingArguments = $false, Position = 1)]
		[ValidateNotNullOrEmpty()]
		[string]$FilePath,
		
		[Parameter(ParameterSetName = 'SyncPerfCounters',Position = 0)]
		[switch]$Sync,
		
		[Parameter(ParameterSetName = 'VerifyRepository',Position = 0)]
		[switch]$Verify,
		
		[Parameter(ParameterSetName = 'VerifyRepository', Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false, ValueFromRemainingArguments = $false,Position = 1)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ Test-Path -Path $_ })]
		[string]$Repository = $(Get-WmiRepositoryPath),
		
		[Parameter(ParameterSetName = 'SalvageRepository',Position = 0)]
		[switch]$Salvage,
		
		[Parameter(ParameterSetName = 'ResetRepository',Position = 0)]
		[switch]$Reset,

		[Parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false, ValueFromRemainingArguments = $false)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ Test-Path -Path $_ })]
        [string]$WorkingDirectory = $(Get-WbemPath),

        [switch]$NoWait

	)
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [string]${CmdletSection} = "Begin"
        [string[]]$WinMgmtArgs = @();
        [psobject]$ReturnValue = New-Object -TypeName PSObject
    }
    Process
    {
        Try 
        { 
            [string]$WinMgmtPath = Get-ChildItem -Path "$(Split-PAth -Path $(Get-WmiRepositoryPath) -Parent)" -Filter 'winmgmt.exe' -Force -Recurse -ErrorAction 'SilentlyContinue' | Select-Object -First 1 -ExpandProperty 'FullName';
            Write-Log -Message "WinMgmtPath: $WinMgmtPath" -Source ${CmdletName}

            If ( [string]::IsNullOrEmpty( $WinMgmtPath ) )
            {
                Throw "Could Not Find 'winmgmt.exe' in '$SystemDirectory'."
            }

            switch ($PsCmdlet.ParameterSetName)
            {
	            'BackupRepository' { 
                    $WinMgmtArgs += '/backup'; 
                    If ( (Test-Path -Path $FilePath) ) { 
                        If  (!($Force)) { 
                            Throw "Wmi Repository Backup '$($FilePath)' Already Exists. Use The '-Force' Paramater To Overwrite"; 
                        } 
                        Else  { 
                            Remove-Folder -Path $FilePath -ContinueOnError $true; 
                        } 
                    }; 
                    $WinMgmtArgs += "`"$($FilePath)`""; 
                    break; 
                }
	            'RestoreRepository'  { 
                    $WinMgmtArgs += '/restore'; 
                    $WinMgmtArgs += "`"$($FilePath)`""; 
                    If ( $Force ) { 
                        $WinMgmtArgs += '1'; }; 
                        break; 
                    }
	            'SyncPerfCounters' { 
                    $WinMgmtArgs += '/resyncperf'; 
                    break; 
                }
	            'VerifyRepository' { 
                    $WinMgmtArgs += '/verifyrepository'; $WinMgmtArgs += "`"$($Repository)`""; 
                    break;
                }
	            'ResetRepository' { 
                    $WinMgmtArgs += '/resetrepository'; 
                    break; 
                }
	            'SalvageRepository' { 
                    $WinMgmtArgs += '/salvagerepository'; 
                    break;
                }
            }
            Write-Log "WinMgmtArgs: $($WinMgmtArgs -join ' ')." -Source ${CmdletName}
        
            [Hashtable]$ExecuteProcess = @{
                Path=$WinMgmtPath;
                Parameters=$WinMgmtArgs;
                CreateNoWindow=[switch]::Present;
                WorkingDirectory=$WorkingDirectory;
                PassThru=[switch]::Present;
                ContinueOnError=$true;
            }
            If ( $nowait ) {
                $ExecuteProcess.Add('NoWait',[switch]::Present)
            }
            Write-Log "ExecuteProcess: $($ExecuteProcess|Fl *|Out-String)." -Source ${CmdletName}

            If ( $PSCmdlet.ParameterSetName -match 'ResetRepository' ) {
                Stop-WindowsManagementService -ErrorAction 'SilentlyContinue'
            }
            Write-Log "Starting Process: '$WinMgmtPath $($WinMgmtArgs -join ' ')'." -Source ${CmdletName}
            [psobject]$ReturnValue = Execute-Process @ExecuteProcess
            Write-Log "ReturnValue: $($ReturnValue|Fl *|Out-String)." -Source ${CmdletName}
            
            
            Start-WindowsManagementService -Ea SilentlyContinue
        }
        Catch 
        {
            Write-Log -Message "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }  
    }
    End
    {
        If ( !$NoWait ) { Write-Output -InputObject $ReturnValue };
    }
}
Function Compile-Mof
{
<#
.SYNOPSIS
	Register or unregister a DLL file.
.DESCRIPTION
	Register or unregister a DLL file using regsvr32.exe. Function can be invoked using alias: 'Register-DLL' or 'Unregister-DLL'.
.PARAMETER FilePath
	Path to the DLL file.
.PARAMETER DLLAction
	Specify whether to register or unregister the DLL. Optional if function is invoked using 'Register-DLL' or 'Unregister-DLL' alias.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Register-DLL -FilePath "C:\Test\DcTLSFileToDMSComp.dll"
	Register DLL file using the "Register-DLL" alias for this function
.EXAMPLE
	UnRegister-DLL -FilePath "C:\Test\DcTLSFileToDMSComp.dll"
	Unregister DLL file using the "Unregister-DLL" alias for this function
.EXAMPLE
	Invoke-RegisterOrUnregisterDLL -FilePath "C:\Test\DcTLSFileToDMSComp.dll" -DLLAction 'Register'
	Register DLL file using the actual name of this function
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
    [OutputType([psobject])]
	Param (
		[Parameter(Mandatory=$true)]
		[ValidateNotNullorEmpty()]
		[string]$FilePath,
		[Parameter(Mandatory=$false)]
		[ValidateNotNullorEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin 
    {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
        [psobject]$ReturnObject = $(New-Object -TypeName PSObject -Property (@{FilePath=$FilePath; HRESULT=0x00000000; ErrorCode=-1;Message=[string]::Empty;}));
        [string]$MOFActionParameters = "`"$FilePath`""
	}
	Process 
    {
		Try 
        {
			Write-Log -Message "Compile MOF file [$filePath]." -Source ${CmdletName}
			If (-not (Test-Path -LiteralPath $FilePath -PathType 'Leaf')) { Throw "File [$filePath] could not be found." }
			
			If ($Is64Bit) 
            {
                If ( ($FilePath -like '*\SysWow64\*') -or ($FilePath -like '*\Program Files (x86)*') )
                {
                    [string]$MofCompPath = "$envWinDir\syswow64\wbem\mofcomp.exe"
                }
                Else
                {
                    [string]$MofCompPath = "$envWinDir\system32\wbem\mofcomp.exe"
                }
			}
			Else 
            {
                [string]$MofCompPath = "$envWinDir\system32\wbem\mofcomp.exe"
			}
			
            
			[psobject]$ExecuteResult = Execute-Process -Path $MofCompPath -Parameters $MOFActionParameters -WindowStyle 'Hidden' -PassThru
            $ReturnObject.ErrorCode = $ExecuteResult.ExitCode;
            $ReturnOBject.Message = $ExecuteResult.StdOut
			If ($ExecuteResult.ExitCode -ne 0) {
                
                Foreach ( $RegexMatch in ([regex]'(\d{1}[x]\d{8})').Matches($ExecuteResult.StdOut) )
                {
                    $ReturnObject.HRESULT = $RegexMatch.Value
                }

				If ($ExecuteResult.ExitCode -eq 60002) {
					Throw "Execute-Process function failed with exit code [$($ExecuteResult.ExitCode)]."
				}
				Else {
					Throw "mofcomp.exe failed with exit code [$($ExecuteResult.ExitCode)]."
				}
			}
		}
		Catch 
        {
			Write-Log -Message "Failed to Compile Mof file. `n$(Resolve-Error)" -Severity 2 -Source ${CmdletName}
			If (-not $ContinueOnError) 
            {
				Throw "Failed to Compile MOF file: $($_.Exception.Message)"
			}
		}
	}
	End 
    {
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
        Write-Output -InputObject $ReturnObject;
	}
}
Function Register-ExeFile
{
	[CmdletBinding()]
    [OutputType([psobject])]
	param
	(
		[Parameter(Mandatory = $true,
				   Position = 0)]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('(.*)([.])([eE][xX][eE])$')]
		[ValidateScript({ Test-Path -Path $_ })]
		[string]$FilePath
	)
	
	Begin
	{
		[string]${CmdletSection} = "Begin"
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [psobject]$ReturnValue = New-Object -TypeName PSObject;
        
        [string]$WorkingDirectory = Split-Path -Parent -Path $FilePath;
        Write-Log -Message "WorkingDirectory: $WorkingDirectory" -Source ${CmdletName};
        
        [string]$FileName = Split-Path -Leaf -Path $FilePath
        Write-Log -Message "FileName: $FileName" -Source ${CmdletName};

        [string[]]$ExeArgs = @('/regserver');
        Write-Log -Message "ExeArgs: $ExeArgs" -Source ${CmdletName};
    }
	Process
	{
		[string]${CmdletSection} = "Process"
		try
		{
            [Hashtable]$ExecuteProcess = @{
                Path=$FilePath;
                Parameters=$ExeArgs;
                CreateNoWindow=[switch]::Present;
                WorkingDirectory=$WorkingDirectory;
                PassThru=[switch]::Present;
                ContinueOnError=$true;
            }
            Write-Log -Message "ExecuteProcess: $($ExecuteProcess | Fl * | Out-String)" -Source ${CmdletName};

            Write-Log -Message "Start Process: $FileName $($ExeArgs -join ' ')" -Source ${CmdletName};
            [psobject]$ReturnValue = Execute-Process @ExecuteProcess;
            Write-Log -Message "ReturnProcess: $($ReturnValue | Fl * | Out-String)" -Source ${CmdletName};
		}
		catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
		}
	}
	End
	{
		[string]${CmdletSection} = "End"
        Write-Output -InputObject $ReturnValue
	}
}
Function Register-CommonDlls
{
    [CmdletBinding()]
    Param()
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
        Try
        {
            [string[]]$CommonDlls = @(
"$env:windir\system32\actxprxy.dll",
"$env:windir\system32\atl.dll",
"$env:windir\system32\Bitsprx2.dll",
"$env:windir\system32\Bitsprx3.dll",
"$env:windir\system32\browseui.dll",
"$env:windir\system32\cryptdlg.dll",
"$env:windir\system32\dssenh.dll",
"$env:windir\system32\gpkcsp.dll",
"$env:windir\system32\initpki.dll",
"$env:windir\system32\jscript.dll",
"$env:windir\system32\mshtml.dll",
"$env:windir\system32\msi.dll",
"$env:windir\system32\mssip32.dll",
"$env:windir\system32\msxml.dll",
"$env:windir\system32\msxml3.dll",
"$env:windir\system32\msxml3a.dll",
"$env:windir\system32\msxml3r.dll",
"$env:windir\system32\msxml4.dll",
"$env:windir\system32\msxml4a.dll",
"$env:windir\system32\msxml4r.dll",
"$env:windir\system32\msxml6.dll",
"$env:windir\system32\msxml6r.dll",
"$env:windir\system32\muweb.dll",
"$env:windir\system32\ole32.dll",
"$env:windir\system32\oleaut32.dll",
"$env:windir\system32\Qmgr.dll",
"$env:windir\system32\Qmgrprxy.dll",
"$env:windir\system32\rsaenh.dll",
"$env:windir\system32\sccbase.dll",
"$env:windir\system32\scrrun.dll",
"$env:windir\system32\shdocvw.dll",
"$env:windir\system32\shell32.dll",
"$env:windir\system32\slbcsp.dll",
"$env:windir\system32\softpub.dll",
"$env:windir\system32\urlmon.dll",
"$env:windir\system32\userenv.dll",
"$env:windir\system32\vbscript.dll",
"$env:windir\system32\Winhttp.dll",
"$env:windir\system32\wintrust.dll",
"$env:windir\system32\wuapi.dll",
"$env:windir\system32\wuaueng.dll",
"$env:windir\system32\wuaueng1.dll",
"$env:windir\system32\wucltui.dll",
"$env:windir\system32\wucltux.dll",
"$env:windir\system32\wups.dll",
"$env:windir\system32\wups2.dll",
"$env:windir\system32\wuweb.dll",
"$env:windir\system32\wuwebv.dll",
"$env:windir\system32\wbem\wmisvc.dll",
"$env:windir\system32\Xpob2res.dll",
"$env:windir\syswow64\actxprxy.dll",
"$env:windir\syswow64\atl.dll",
"$env:windir\syswow64\Bitsprx2.dll",
"$env:windir\syswow64\Bitsprx3.dll",
"$env:windir\syswow64\browseui.dll",
"$env:windir\syswow64\cryptdlg.dll",
"$env:windir\syswow64\dssenh.dll",
"$env:windir\syswow64\gpkcsp.dll",
"$env:windir\syswow64\initpki.dll",
"$env:windir\syswow64\jscript.dll",
"$env:windir\syswow64\mshtml.dll",
"$env:windir\syswow64\msi.dll",
"$env:windir\syswow64\mssip32.dll",
"$env:windir\syswow64\msxml.dll",
"$env:windir\syswow64\msxml3.dll",
"$env:windir\syswow64\msxml3a.dll",
"$env:windir\syswow64\msxml3r.dll",
"$env:windir\syswow64\msxml4.dll",
"$env:windir\syswow64\msxml4a.dll",
"$env:windir\syswow64\msxml4r.dll",
"$env:windir\syswow64\msxml6.dll",
"$env:windir\syswow64\msxml6r.dll",
"$env:windir\syswow64\muweb.dll",
"$env:windir\syswow64\ole32.dll",
"$env:windir\syswow64\oleaut32.dll",
"$env:windir\syswow64\Qmgr.dll",
"$env:windir\syswow64\Qmgrprxy.dll",
"$env:windir\syswow64\rsaenh.dll",
"$env:windir\syswow64\sccbase.dll",
"$env:windir\syswow64\scrrun.dll",
"$env:windir\syswow64\shdocvw.dll",
"$env:windir\syswow64\shell32.dll",
"$env:windir\syswow64\slbcsp.dll",
"$env:windir\syswow64\softpub.dll",
"$env:windir\syswow64\urlmon.dll",
"$env:windir\syswow64\userenv.dll",
"$env:windir\syswow64\vbscript.dll",
"$env:windir\syswow64\Winhttp.dll",
"$env:windir\syswow64\wintrust.dll",
"$env:windir\syswow64\wuapi.dll",
"$env:windir\syswow64\wuaueng.dll",
"$env:windir\syswow64\wuaueng1.dll",
"$env:windir\syswow64\wucltui.dll",
"$env:windir\syswow64\wucltux.dll",
"$env:windir\syswow64\wups.dll",
"$env:windir\syswow64\wups2.dll",
"$env:windir\syswow64\wuweb.dll",
"$env:windir\syswow64\wuwebv.dll",
"$env:windir\syswow64\wbem\wmisvc.dll",
"$env:windir\syswow64\Xpob2res.dll"
            )
            Write-Log -Message "Process '$($CommonDlls.Count)' DLL Files..." -Source ${CmdletName}

            [int]$count = 0;
            Foreach ( $Dll in $CommonDlls ) {
                Write-Log -Message "Processing DLL file #$($count) of $($CommonDlls.Count)." -Source ${CmdletName}
                If ( Test-Path -Path $Dll ) {
                    Invoke-RegisterOrUnregisterDLL -FilePath $Dll -DLLAction Register -ContinueOnError $true -ErrorAction 'SilentlyContinue'
                }
                Else {
                    Write-Log -Message "DLL File '$($DLL)' Does Not Exist." -Source ${CmdletName} -Severity 2
                }
            }
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        }                
    }
}
Function Rename-WmiRepository
{
<#
.SYNOPSIS
	Test if SCCM programs can run currently by checking servicing window
.DESCRIPTION
	Test if SCCM programs can run currently by checking servicing window
.PARAMETER ComputerName
	Computer to test on
.EXAMPLE
	Test-SccmClientServiceWindow -ComputerName COMPOUTER01
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
        [switch]$NoRestart=$false
	)
	
	Begin 
    {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [string[]]$ReturnValue = @();
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process 
    {
		Try 
        {
            Write-Log -Message "Validate WMI Services Are Stopped." -Source ${CmdletName}
            If ( !(Test-WmiService -TestFor Stopped)) {
                Stop-WindowsManagementService;
            }
            If ( !(Test-WmiService -TestFor Stopped) ) { 
                Throw "Could Not Stop Wmi Service, Bail..." 
            }

            [string[]]$RepoNames = Get-ItemProperty -Path @(
                'HKLM:\Software\Microsoft\Wbem\CIMOM'
                ,'HKLM:\Software\Wow6432Node\Microsoft\Wbem\CIMOM'
            ) -Name 'Repository Directory' -ErrorAction 'SilentlyContinue'|Select-Object -ExpandProperty 'Repository Directory' -Unique 
            If ( $RepoNames.Count -eq 0 ){ Throw "Unable To Find Repository Path From registry." }
            Else {
                Write-Log -Message "RepoNames: $($RepoNames -join '; ')]" -source ${CmdletName}
                Foreach ( $Repo in $RepoNames )
                {
                    [string]$UtcDate=$(Get-Date -Format yymmddHHmmss)
                    Rename-Item -Path $Repo -NewName $('Repository_'+$UtcDate) -Force;
                }
            }
		}
		Catch 
        {
			Write-Log -Message "Exception: $($_.Exception.Message)`n$(Resolve-Error)" -Severity 2 -Source ${CmdletName}
		}
	}
	End 
    {
		if( !$NoRestart ) { Start-WindowsManagementService; }
	}
}
Function Clear-WmiRepository
{
	[CmdletBinding()]
	Param (
        [string]$RepositoryBackupFolder = $Env:ProgramData
	)
	
	Begin 
    {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [string[]]$ReturnValue = @();
        [string]$UtcDate=$(Get-Date -Format yymmddHHmmss)
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process 
    {
		Try 
        {
            [string[]]$RepoNames = Get-ItemProperty -Path @(
                'HKLM:\Software\Microsoft\Wbem\CIMOM'
                ,'HKLM:\Software\Wow6432Node\Microsoft\Wbem\CIMOM'
            ) -Name 'Repository Directory' -ErrorAction 'SilentlyContinue'|Select-Object -ExpandProperty 'Repository Directory' -Unique 
            If ( $RepoNames.Count -eq 0 ){ Throw "Unable To Find Repository Path From registry." }
            Else {
                Write-Log -Message "RepoNames: $($RepoNames -join '; ')]" -source ${CmdletName}
                Foreach ( $Repo in $RepoNames )
                {
                    [string]$RepositoryArchive = Join-Path -Path $RepositoryBackupFolder -ChildPath "WMI_$(Split-Path -Leaf -Path $Repo)_$($utcDate).cab"
                    Write-Log -Message "Create Repo Backup From '$Repo' To '$RepositoryArchive'" -source ${CmdletName}
                    Compress-WindowsCabinet -Path $Repo -Destination $RepositoryArchive;
                    Remove-Folder -Path $Repo -ContinueOnError $true -ErrorAction 'SilentlyContinue';
                }
            }
		}
		Catch 
        {
			Write-Log -Message "Exception: $($_.Exception.Message)`n$(Resolve-Error)" -Severity 2 -Source ${CmdletName}
		}
	}
	End 
    {
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}

Function Get-WmiAutoRecoverFiles
{
<#
.SYNOPSIS
	Test if SCCM programs can run currently by checking servicing window
.DESCRIPTION
	Test if SCCM programs can run currently by checking servicing window
.PARAMETER ComputerName
	Computer to test on
.EXAMPLE
	Test-SccmClientServiceWindow -ComputerName COMPOUTER01
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
    [OutputType([String[]])]
	Param (
	)
	
	Begin 
    {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [string[]]$ReturnValue = @();
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process 
    {
		Try 
        {
            ## Get Registry Mofs
            Write-Log -Message "Get MOF/MFL List From Registry..." -Source ${CmdletName}
            Get-ItemProperty -Path "HKLM:\Software\Microsoft\Wbem\CIMOM" -Name 'AutoRecover MOFs' | Select-Object -First 1 -ExpandProperty 'AutoRecover MOFs' | ?{![string]::IsNullOrEmpty($_) -and $_ -notlike '*uninst*'} | %{
                $ReturnValue += [System.Environment]::ExpandEnvironmentVariables($_).ToLower()
            }
            Write-Log -Message "Got Registry Mofs ($($ReturnValue.Count) Files)" -Source ${CmdletName}

            ## Get Existing Mofs
            Write-Log -Message "Get MOF List From Filesystem..." -Source ${CmdletName}
            Get-ChildItem -Path "$Env:Windir\System32\Wbem\*.mof","$Env:Windir\System32\*.mfl" -Exclude '*uninst*' -Force -Recurse -ErrorAction 'SilentlyContinue' | ?{ $ReturnValue -notcontains $_.FullName.ToLower() -and $_.FullName.ToLower() -notlike '*uninst*' -and $_.Directory.Name -notlike '*autorecover*'} |%{
                $ReturnValue += $_.FullName.ToLower();
            }
            Write-Log -Message "Got System Mofs ($($ReturnValue.Count) Files)" -Source ${CmdletName}

            ## Get Existing Mfls
            Write-Log -Message "Get MFL List From Filesystem..." -Source ${CmdletName}
            Get-ChildItem -Path "$Env:Windir\SysWow64\Wbem\*.mof","$Env:Windir\SysWow64\*.mfl" -Exclude '*uninst*' -Force -Recurse -ErrorAction 'SilentlyContinue' | ?{ $ReturnValue -notcontains $_.FullName.ToLower() -and $_.FullName.ToLower() -notlike '*uninst*' -and $_.Directory.Name -notlike '*autorecover*'} |%{
                $ReturnValue += $_.FullName.ToLower();
            }
            Write-Log -Message "Got System Mfls ($($ReturnValue.Count) Files)" -Source ${CmdletName}
		}
		Catch 
        {
			Write-Log -Message "Exception: $($_.Exception.Message)`n$(Resolve-Error)" -Severity 2 -Source ${CmdletName}
		}
	}
	End 
    {
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
        Write-Output -InputObject $($ReturnValue|Select-Object -Unique)
	}
}
Function Get-WmiProviderFiles
{
<#
.SYNOPSIS
	Test if SCCM programs can run currently by checking servicing window
.DESCRIPTION
	Test if SCCM programs can run currently by checking servicing window
.PARAMETER ComputerName
	Computer to test on
.EXAMPLE
	Test-SccmClientServiceWindow -ComputerName COMPOUTER01
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
    [OutputType([String[]])]
	Param (
	)
	
	Begin 
    {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [string[]]$ReturnValue = @();
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process 
    {
		Try 
        {

            ## Get DLL Files (sysnative)
            Write-Log -Message "Get DLL List From sysnative..." -Source ${CmdletName}
            Get-ChildItem -Path "$Env:Windir\System32\Wbem\*.dll","$Env:Windir\SysWow64\Wbem\*.dll" -Force -Recurse -ErrorAction 'SilentlyContinue' | ?{ $ReturnValue -notcontains $_.FullName.ToLower() } |%{
                $ReturnValue += $_.FullName.ToLower();
            }
            Write-Log -Message "Got Wmi Dll Provider Files ($($ReturnValue.Count) Files)" -Source ${CmdletName}
		}
		Catch 
        {
			Write-Log -Message "Exception: $($_.Exception.Message)`n$(Resolve-Error)" -Severity 2 -Source ${CmdletName}
		}
	}
	End 
    {
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
        Write-Output -InputObject $ReturnValue
	}
}
function Get-WmiRepositoryPath
{
    [CmdletBinding()]
    [OutputType([string])]
    param()
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [string]$ReturnValue = [string]::Empty;
    }
    Process
    {
        Try
        {
            [string]$ReturnValue = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Wbem\CIMOM' -Name 'Repository Directory' -ErrorAction 'SilentlyContinue' | `
                Select-Object -ExpandProperty 'Repository Directory' | `
                Foreach-Object {$_ -replace '([%])(\w+)([%])',"`$env:`$2"} | `
                Select-Object -First 1
        }
        Catch
        {
            Write-Log -Message "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
    End
    {
        Write-Output -InputObject ($ReturnValue)
    } 
}
function Get-WmiEventErrors
{
    [CmdletBinding()]
    [OutputType([psobject[]])]
    param()
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [string]$ReturnValue = [string]::Empty;
    }
    Process
    {
        Try
        {
            [psobject[]]$ReturnValue = Get-WinEvent -FilterHashtable @{logname='application';id=10;providername='*wmi*'}
        }
        Catch
        {
            Write-Log -Message "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
    End
    {
        Write-Output -InputObject ($ReturnValue)
    } 
}

Function Reset-WMIServicePermissions
{
    [CmdletBinding()]
    Param(
        [switch]$NoRestart=$false
    )
    Begin
    {
        [string[]]$ReturnValue = @();
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
        Try
        {
            Write-Log -Message "Validate WMI Services Are Stopped." -Source ${CmdletName}
            If ( !(Test-WmiService -TestFor Stopped)) {
                Stop-WindowsManagementService;
            }
            If ( !(Test-WmiService -TestFor Stopped) ) { 
                Throw "Could Not Stop Wmi Service, Bail..." 
            }

            Write-Log -Message "Repair DCOM Permissions..." -Source ${CmdletName}
            Reset-DCOMPermissions;
            Write-Log -Message "Done." -Source ${CmdletName}

            Write-Log -Message "Repair Wmi Permissions..." -Source ${CmdletName}
            Reset-WingmtPermissions;
            Write-Log -Message "Done." -Source ${CmdletName}          
        }
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}        
    }
    End {
        if( !$NoRestart ) { Start-WindowsManagementService; }
    }
}
Function Reset-WingmtPermissions
{
	[CmdletBinding()]
	param
	(
   		[Parameter(Mandatory=$false)]
		[ValidateNotNullorEmpty()]
        [ValidateScript({Test-connection -ComputerName $_ -BufferSize 16 -Count 1 -Quiet})]
		[string]$ComputerName = $Env:ComputerName,
     
        [ValidateNotNullOrEmpty()]
        [string]$RegistryKey = 'HKLM\SOFTWARE\Microsoft\Ole',

        [ValidateNotNullOrEmpty()]
        [hashtable]$AddValues=@{'EnableDCOM'="Y";'LegacyAuthenticationLevel'=2;'LegacyImpersonationLevel'=3;},
        
        [ValidateNotNullOrEmpty()]
        [string[]]$DeleteValues=@('DefaultLaunchPermission','MachineAccessRestriction','MachineLaunchRestriction')
    )
	Begin {
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;   
        [string]$scCmd='D:(A;;CCDCLCSWRPWPDTLOCRRC;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;DA)(A;;CCDCLCSWRPWPDTLOCRRC;;;PU)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)'
    }
	Process {
		Try {
            foreach($key in $AddValues.Keys){
                Try {
                    Set-RegistryKey -Path $RegistryKey -Name $Key -Value $AddValues.$Key -Type $($AddValues.$($key).GetType().Name.Replace('Int32','DWord'));
                    Write-Log -Message "Successfully Added Registry Key $RegistryKey`:[$Key]=[$AddValues.$Key] ($($AddValues.$($key).GetType().Name.Replace('Int32','DWord')))" -Source ${CmdletName}
                }
                Catch {
                    Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
                }
            }
            foreach(${Value} in $DeleteValues){
                Try {
                    Remove-RegistryKey -Path $RegistryKey -Name ${Value} -Recurse -ContinueOnError $true;
                    Write-Log -Message "Successfully Removed Registry Value $RegistryKey`:[$Key]=[${Value}]" -Source ${CmdletName}
                }
                Catch {
                    Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
                }
            }
            Execute-Process -Path "$env:windir\system32\sc.exe" -Parameters 'sdset','winmgmt',$scCmd 
		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
}
Function Reset-DCOMPermissions
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$RegistryKey = 'HKLM\SOFTWARE\Microsoft\Ole',

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$AddValues=@{
            'DefaultLaunchPermission'="O:BAG:BAD:(A;;CCDCLCSWRP;;;SY)(A;;CCDCLCSWRP;;;BA)(A;;CCDCLCSWRP;;;IU)";
            'MachineAccessRestriction'="O:BAG:BAD:(A;;CCDCLC;;;WD)(A;;CCDCLC;;;LU)(A;;CCDCLC;;;S-1-5-32-562)(A;;CCDCLC;;;AN)";
            'MachineLaunchRestriction'="O:BAG:BAD:(A;;CCDCSW;;;WD)(A;;CCDCLCSWRP;;;BA)(A;;CCDCLCSWRP;;;LU)(A;;CCDCLCSWRP;;;S-1-5-32-562)";
        }
    )
    Begin
    {
        [string[]]$ReturnValue = @();
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
        Try
        {
            Foreach ( $Key in $AddValues.Keys ) {
                Try {
                    [byte[]]$BinarySD = ConvertFrom-SDDLToBinary -SDDL $AddValues.$Key;
                    Set-RegistryKey -Key $RegistryKey -Name $Key -Value $BinarySD -Type Binary;
                }
                Catch {
                    Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2    
                }
                Finally {
                    Remove-Variable -Name BinarySD -Force -Ea SilentlyContinue
                }
            }

        }
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}        
        
    }
}

Function Register-WMIService
{
    [CmdletBinding()]
    Param(
    )
    Begin
    {
        [string[]]$ReturnValue = @();
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
        Try
        {
            Write-Log -Message "Register Wmi Server..." -Source ${CmdletName}
            [string]$wmiprvsn_regserver=Invoke-Expression "cmd /c wmiprvse /regserver"
            Write-Log -Message "wmiprvsn_regserver: '$($wmiprvsn_regserver)'." -Source ${CmdletName}           
        }
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}        
        
    }
}
Function Register-WMIServiceProvider
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ProviderFiles = $(Get-WmiProviderFiles),
        [switch]$NoRestart = $false
    )
    Begin
    {
        [string[]]$ReturnValue = @();
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
        Try
        {
            
            Write-Log -Message "Validate WMI Services Are Stopped." -Source ${CmdletName}
            If ( !(Test-WmiService -TestFor Stopped)) {
                Stop-WindowsManagementService;
            }
            If ( !(Test-WmiService -TestFor Stopped) ) { 
                Throw "Could Not Stop Wmi Service, Bail..." 
            }

            Write-Log -Message "Register Common Dll Files..." -Source ${CmdletName}
            Register-CommonDlls;
            Write-Log -Message "Done." -Source ${CmdletName}
            
            Write-Log -Message "Register WMI Dll Files..." -Source ${CmdletName}
            Foreach ( $ProviderFile in $ProviderFiles ) {Invoke-RegisterOrUnregisterDLL -FilePath $ProviderFile -DLLAction Register -ContinueOnError $true -Ea 'SilentlyContinue';}
            Write-Log -Message "Done." -Source ${CmdletName}
        }
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}        
    }
    End {
        If ( !$NoRestart ) { Start-WindowsManagementService; }
    }
}
Function Register-WMIServiceBinaries
{
    [CmdletBinding()]
    Param()
    Begin
    {
        [string[]]$ReturnValue = @();
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
        Try
        {
            Write-Log -Message "Register WMI Binaries..." -Source ${CmdletName}
            Get-ChildItem -Path  "$Env:Windir\System32\Wbem\*.exe","$Env:Windir\SysWow64\Wbem\*.exe" -Include 'unsecapp.exe','wmiadap.exe','wmiapsrv.exe','wmiprvse.exe','scrcons.exe' -Force -Recurse -ErrorAction 'SilentlyContinue' | select -ExpandProperty 'fullname' | %{Register-ExeFile -FilePath $_;}
        }
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}        
        
    }
}
Function Register-WMIServiceClasses
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]       
        [string[]]$ClassFiles = $global:WmiRepositoryMOFs
    )
    Begin
    {
        [string[]]$ReturnValue = @();
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
        Try
        {
            Write-Log -Message "Register Wmi Mof/Mfl Files ..." -Source ${CmdletName}
            Foreach ( $ClassFile in $ClassFiles ) {
                [psobject]$CompileResult = Compile-MOF -FilePath $ClassFile -ContinueOnError $true;
                Write-Log -Message "Compiled MOF File '$ClassFile': ($?): [$($CompileResult|Fl *|out-string)]" -Source ${CmdletName};
            }
            Write-Log -Message "Done." -Source ${CmdletName}
        }
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}        
        
    }
}

Function ConvertFrom-SDDLToBinary
{
	[CmdletBinding()]
    [OutputType([byte[]])]
	Param (
		[Parameter(Mandatory=$false)]
		[ValidateNotNullorEmpty()]
		[string]$SDDL
	)
	Begin 
    {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [byte[]]$ReturnValue = @();
	}
	Process  {
		Try  {
            [System.Reflection.Assembly]::LoadWithPartialName('System.DirectoryServices') | Out-Null
            [System.DirectoryServices.ActiveDirectorySecurity]$Ads = New-Object -TypeName 'System.DirectoryServices.ActiveDirectorySecurity';
            $ads.SetSecurityDescriptorSddlForm($SDDL);
            [byte[]]$ReturnValue = $ads.GetSecurityDescriptorBinaryForm();
		}
		Catch  {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
	End  {
        Write-Output -InputObject $ReturnValue;
	}
}
 
function Get-WBEMErrors
{
	[CmdletBinding()]
    [OutputType([psobject[]])]
	param (
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        $WmiErrorObjects = $xmlConfig.CCM_SetupErrors.WMI_Errors
    )
	Begin  {
	    [string]${CmdletName} = $PsCmdlet.MyInvocation.MyCommand.Name;	
        [psobject[]]$ReturnValue = @();
    }
    Process {
        Try {
            [psobject[]]$WmiErrors = $WmiErrorObjects |select-object -first 1 -ExpandProperty Wmi_Error
            [string[]]$PropertyNAmes =  $WmiErrors | Select-Object -First 1 -Property Attributes,ChildNodes | %{$_.Attributes.Name +  $_.ChildNodes.Name}
            [psobject[]]$ReturnValue = $WmiErrors|Select-Object -Property $PropertyNames | %{Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Message' -Value $_.'#text' -PassThru -Force}|Select-Object -Property $(@($PropertyNAmes|Select -SkipLast 1) + 'Message')
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source 'Convert-Variable' -Severity 2
        }
	}
    End {
        Write-Output -InputObject $ReturnValue
    }
}
function Test-WBEMError
{
	[CmdletBinding(DefaultParameterSetName='PassValue')]
    [OutputType([System.Boolean],ParameterSetName='PassQuiet')]
    [OutputType([System.Management.Automation.PSObject[]],ParameterSetName='PassValue')]
	param (
        [Parameter(Mandatory=$true, ParameterSetName='PassQuiet')]
        [Parameter(Mandatory=$true, ParameterSetName='PassValue')]
        [ValidateNotNullOrEmpty()]
        [object[]]$Errors,

        [Parameter(Mandatory=$false, ParameterSetName='PassQuiet')]
        [switch]$Quiet
    )
	Begin  {
	    [string]${CmdletName} = $PsCmdlet.MyInvocation.MyCommand.Name;	
        [System.Management.Automation.PSObject[]]$Results = @();
    }
    Process {
        Try {
            [System.Management.Automation.PSObject[]]$WBEMErrors = Get-WBemErrors
            Foreach ( $ErrorNumber in $Errors ) {
                 If ( $ErrorNumber -notmatch '0x[A-Za-z0-9]{8}' ) {
                    [string]$Hexidecimal = '0x{0:X8}' -f $ErrorNumber
                }
                else {
                    [string]$Hexidecimal = $ErrorNumber
                }               
                $WBEMErrors | ? {  $($_.HResult).ToUpper() -like $Hexidecimal.ToUpper()} | %{$Results += $_}
            }
            Write-Log -Message "Found $($Results.Count) Matching Errors." -Source ${CmdletName}
            If ( $PsCmdlet.ParameterSetName -eq 'PassValue' ) {
                [System.Management.Automation.PSObject[]]$ReturnValue = $Results;
            }
            Else {
                [System.Boolean]$ReturnValue = $Results.Count -gt 0;
            }
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source 'Convert-Variable' -Severity 2
        }
	}
    End {
        Write-Output -InputObject $ReturnValue
    }
}
function Test-WmiService
{
	[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Started','Stopped',IgnoreCase=$true)]
        [string]$TestFor
    )
    Begin
    {
        [string]${CmdletSection} = "Begin"
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [bool]$ReturnValue = $true;
        [string]$ServiceName = 'Winmgmt'
        
    }
    Process
    {
        [string]${CmdletSection} = "Process"
        Try 
        {
            [psobject[]]$ServiceObjects = @();
            
            Switch ( $TestFor ) {
                'Started' {
                    [string]$CompliantState = 'Running';
                    [string]$CompliantStart = 'Automatic'
                }
                'Stopped' {
                    [string]$CompliantState = 'Stopped';
                    [string]$CompliantStart = 'Disabled'
                }
            }
            @(Get-Service -Name Winmgmt) | %{$ServiceObjects += $_  }
            Write-Log -Message "CompliantState: $CompliantState" -Source ${CmdletName}
            Write-Log -Message "CompliantStart: $CompliantStart" -Source ${CmdletName}
            Foreach  ($Service in $ServiceObjects ) {

                [bool]$StateCompliance = $Service.Status -match $CompliantState;           
                Write-Log -Message "StateCompliance: $StateCompliance" -Source ${CmdletName}

                [string]$StartMode = Get-ServiceStartMode -Name $Service.Name -ContinueOnError $true -ErrorAction 'SilentlyContinue'
                Write-Log -Message "StartMode: $StartMode" -Source ${CmdletName}

                [bool]$StartCompliance = $StartMode -match $CompliantStart
                Write-Log -Message "StartCompliance: $StartCompliance" -Source ${CmdletName}

                [bool]$ReturnValue = !($StartCompliance) -or !($StateCompliance)
            }
        }
        Catch 
        {
            Write-Log -Message "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }  
    }
    End
    {
        Write-Output -InputObject $ReturnValue;
    }
}

function Start-WindowsManagementService
{
	[CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [timespan]$Timeout = $global:minuteTimespace
    )
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
        Try {
            Set-ServiceStartMode -Name winmgmt -StartMode Automatic -ContinueOnError $true -ErrorAction 'SilentlyContinue';
            Start-ServiceAndDependencies -Name 'Winmgmt' -SkipDependentServices -SkipServiceExistsTest -PendingStatusWait $Timeout -ContinueOnError $true;
        } 
        catch  {
            Write-Log -Message "Exception at line '$($_.InvocationInfo.ScriptLineNumber)': $($_.Exception.Message)." -Source ${CmdletName} -Severity 2
        } 
    }
    End {
        Start-Sleep -Seconds 10;
    }
}
function Stop-WindowsManagementService
{
	[CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [timespan]$Timeout = $global:minuteTimespace
    )
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
        Try {
            Set-ServiceStartMode -Name winmgmt -StartMode Disabled -ContinueOnError $true -ErrorAction 'SilentlyContinue';
            Stop-ServiceAndDependencies -Name 'Winmgmt' -PendingStatusWait $Timeout  -ContinueOnError $true
        } 
        catch  {
            Write-Log -Message "Exception at line '$($_.InvocationInfo.ScriptLineNumber)': $($_.Exception.Message)." -Source ${CmdletName} -Severity 2
        } 
    }
    End {
        Start-Sleep -Seconds 10;
    }
}

#$global:WmiRepositoryMOFs

function Repair-WmiRepository
{
	[CmdletBinding()]
    [OutputType([bool])]
	param
	(
        [switch]$Rebuild = $false,
        [switch]$BackupRepository = $false
    )
	Begin
	{
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
	Process
	{
		try
		{
            If ( $Rebuild ) { Rename-WmiRepository -NoRestart; }

            Reset-DCOMPermissions;
            Reset-WingmtPermissions;
            Reset-WMIServicePermissions;
            Reset-CryptographicService;
            Reset-PerformanceCounters;

            Register-CommonDlls
            Register-MsiServer;

            Register-WMIServiceProvider -NoRestart;
            Register-WMIServiceBinaries;
            Register-WMIService;

            Start-WindowsManagementService;
            Write-Log -Message "Sleep For 10 Seconds..." -Source ${CmdletName}; Start-Sleep -Seconds 10
            Register-WMIServiceClasses;
		}
		catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
		}
	}
    
}

Function Reset-PerformanceCounters
{
    [cmdletbinding()]
    Param(
        [switch]$PassThru
    )
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [psobject]$ReturnValue = New-Object -TypeName PSObject -Property (@{ExitCode=-1;StandardOutput=$([string]::Empty);})
    }
    Process
    {
        try 
        {
            Call-Winmgmt -Sync -ErrorAction 'SilentlyContinue';
            Write-Log -Message "Resynced Wmi Performance Counters." -Source ${CmdletName}

            [string]$SysDir = Split-Path -Parent -Path $Env:comspec;
            Write-Log -Message "SysDir: $SysDir" -Source ${CmdletName}
            
            [string]$LodCtr = Get-ChildItem -Path $SysDir -Filter 'lodctr.exe' -Force -Recurse -ErrorAction 'SilentlyContinue' | Select-Object -First 1 -ExpandProperty 'FullName';
            Write-Log -Message "LodCtr: $LodCtr" -Source ${CmdletName}

            If ( [string]::IsNullOrEmpty($LodCtr) ) {
                Throw "Could Not Find 'lodctr.exe' in '$sysdir'"
            }
            [psobject]$ExecuteResult = Execute-Process -Path $LodCtr -Parameters '/R' -CreateNoWindow -PassThru -ContinueOnError $true -ErrorAction 'SilentlyContinue'
        } 
        catch 
        {
            Write-Log -Message "[Exception at line '$($_.InvocationInfo.ScriptLineNumber)': $($_.Exception.Message)." -Source ${CmdletName} -Severity 2
        } 
    }
    End
    {
        If ( $PassThru -and $ExecuteResult ) {
             Write-Output -InputObject $ExecuteResult;
         }
    }
} 

Function New-WMIClass
{
<#
	.SYNOPSIS
		This function help to create a new WMI class.

	.DESCRIPTION
		The function allows to create a WMI class in the CimV2 namespace.
        Accepts a single string, or an array of strings.

	.PARAMETER  ClassName
		Specify the name of the class that you would like to create. (Can be a single string, or a array of strings).

    .PARAMETER  NameSpace
		Specify the namespace where class the class should be created.
        If not specified, the class will automatically be created in "Root\cimv2"

	.EXAMPLE
		New-WMIClass -ClassName "PowerShellDistrict"
        Creates a new class called "PowerShellDistrict"
    .EXAMPLE
        New-WMIClass -ClassName "aaaa","bbbb"
        Creates two classes called "aaaa" and "bbbb" in the Root\cimv2

	.NOTES
		Version: 1.0
        Author: Stephane van Gulick
        Creation date:16.07.2014
        Last modification date: 16.07.2014

	.LINK
		www.powershellDistrict.com

	.LINK
		http://social.technet.microsoft.com/profile/st%C3%A9phane%20vg/

#>
[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true,valueFromPipeLine=$true)][string[]]$ClassName,
        [Parameter(Mandatory=$false)][string]$NameSpace = "root\cimv2"
	
	)


        
        

        foreach ($NewClass in $ClassName){
            if (!(Get-WMIClass -ClassName $NewClass -NameSpace $NameSpace)){
                write-verbose "Attempting to create class $($NewClass)"
                    $WMI_Class = ""
                    $WMI_Class = New-Object System.Management.ManagementClass($NameSpace, $null, $null)
                    $WMI_Class.name = $NewClass
	                $WMI_Class.Put() | out-null
                
                write-output "Class $($NewClass) created."

            }else{
                write-output "Class $($NewClass) is already present. Skiping.."
            }
        }

}			
Function New-WMIProperty
{
<#
	.SYNOPSIS
		This function help to create new WMI properties.

	.DESCRIPTION
		The function allows to create new properties and set their values into a newly created WMI Class.
        Event though it is possible, it is not recommended to create WMI properties in existing WMI classes !

	.PARAMETER  ClassName
		Specify the name of the class where you would like to create the new properties.

	.PARAMETER  PropertyName
		The name of the property.

    .PARAMETER  PropertyValue
		The value of the property.

	.EXAMPLE
		New-WMIProperty -ClassName "PowerShellDistrict" -PropertyName "WebSite" -PropertyValue "www.PowerShellDistrict.com"

	.NOTES
		Version: 1.0
        Author: Stephane van Gulick
        Creation date:16.07.2014
        Last modification date: 16.07.2014

	.LINK
		www.powershellDistrict.com

	.LINK
		http://social.technet.microsoft.com/profile/st%C3%A9phane%20vg/

#>


[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true)]
        [ValidateScript({
            $_ -ne ""
        })]
        [string]$ClassName,

        [Parameter(Mandatory=$false)]
        [string]$NameSpace="Root\cimv2",

        [Parameter(Mandatory=$true)][string[]]$PropertyName,
        [Parameter(Mandatory=$false)][string]$PropertyValue=""

	
	)
    begin{
        [wmiclass]$WMI_Class = Get-WmiObject -Class $ClassName -Namespace $NameSpace -list
    }
    Process{
            write-verbose "Attempting to create property $($PropertyName) with value: $($PropertyValue) in class: $($ClassName)"
            $WMI_Class.Properties.add($PropertyName,$PropertyValue)
            Write-Output "Added $($PropertyName)."
    }
    end{
           		$WMI_Class.Put() | Out-Null
                [wmiclass]$WMI_Class = Get-WmiObject -Class $ClassName -list
                return $WMI_Class
    }

            
            
  
                    


}
Function Set-WMIPropertyValue
{

<#
	.SYNOPSIS
		This function set a WMI property value.

	.DESCRIPTION
		The function allows to set a new value in an existing WMI property.

	.PARAMETER  ClassName
		Specify the name of the class where the property resides.

	.PARAMETER  PropertyName
		The name of the property.

    .PARAMETER  PropertyValue
		The value of the property.

	.EXAMPLE
		New-WMIProperty -ClassName "PowerShellDistrict" -PropertyName "WebSite" -PropertyValue "www.PowerShellDistrict.com"
        Sets the property "WebSite" to "www.PowerShellDistrict.com"
    .EXAMPLE
		New-WMIProperty -ClassName "PowerShellDistrict" -PropertyName "MainTopic" -PropertyValue "PowerShellDistrict"
        Sets the property "MainTopic" to "PowerShell"


	.NOTES
		Version: 1.0
        Author: Stephane van Gulick
        Creation date:16.07.2014
        Last modification date: 16.07.2014

	.LINK
		www.powershellDistrict.com

	.LINK
		http://social.technet.microsoft.com/profile/st%C3%A9phane%20vg/

#>


[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true)]
        [ValidateScript({
            $_ -ne ""
        })]
        [string]$ClassName,

        [Parameter(Mandatory=$false)]
        [string]$NameSpace="Root\cimv2",

        [Parameter(Mandatory=$true)]
        [ValidateScript({
            $_ -ne ""
        })]
        [string]$PropertyName,

        [Parameter(Mandatory=$true)]
        [string]$PropertyValue

	
	)
    begin{
         write-verbose "Setting new  value : $($PropertyValue) on property: $($PropertyName):"
         [wmiclass]$WMI_Class = Get-WmiObject -Class $ClassName -list
         

    }
    Process{
            $WMI_Class.SetPropertyValue($PropertyName,$PropertyValue)
            
    }
    End{
        $WMI_Class.Put() | Out-Null
        return Get-WmiObject -Class $ClassName -list
    }


}
Function Remove-WMIProperty
{
<#
	.SYNOPSIS
		This function removes a WMI property.

	.DESCRIPTION
		The function allows to remove a specefic WMI property from a specefic WMI class.
        /!\Be aware that any wrongly deleted WMI properties could make your system unstable./!\

	.PARAMETER  ClassName
		Specify the name of the class name.

	.PARAMETER  PropertyName
		The name of the property.

	.EXAMPLE
		Remove-WMIProperty -ClassName "PowerShellDistrict" -PropertyName "MainTopic"
        Removes the WMI property "MainTopic".

	.NOTES
		Version: 1.0.1
        Author: Stephane van Gulick
        Creation date:21.07.2014
        Last modification date: 24.07.2014
        History: 21.07.2014 : Svangulick --> Creation
                 24.07.2014 : Svangulick --> Added new functionality
                 29.07.2014 : Svangulick --> Corrected minor bugs

	.LINK
		www.powershellDistrict.com

	.LINK
		http://social.technet.microsoft.com/profile/st%C3%A9phane%20vg/

#>


[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true)][string]$ClassName,
        [Parameter(Mandatory=$true)][string]$PropertyName,
        [Parameter(Mandatory=$false)][string]$NameSpace = "Root\Cimv2",
        [Parameter(Mandatory=$false)][string]$Force 

	
	)
        if ($PSBoundParameters['NameSpace']){

            [wmiclass]$WMI_Class = Get-WmiObject -Class $ClassName -Namespace $NameSpace -list
        }
        else{
            write-verbose "Gaterhing data of $($ClassName)"
            [wmiclass]$WMI_Class = Get-WmiObject -Class $ClassName -list
        }
        if (!($force)){
             
            $Answer = Read-Host "Deleting $($PropertyName) can make your system unreliable. Press 'Y' to continue"
                if ($Answer -eq"Y"){
                    $WMI_Class.Properties.remove($PropertyName)
                    $WMI_Class.Put() | out-null
                    write-output "Property $($propertyName) removed."
                
                }else{
                    write-output "Uknowned answer. Class '$($PropertyName)' has not been deleted."
                }
            }#End force
        elseif ($force){
                $WMI_Class.Properties.remove($PropertyName)
                $WMI_Class.Put()
                write-output "Property $($propertyName) removed."
        }

           
        

}
function Remove-WMIClass 
{
[CmdletBinding()]
	Param(
		    [parameter(mandatory=$true,valuefrompipeline=$true)]
            [ValidateScript({
                $_ -ne ""
            })]
            [string[]]$ClassName,

            [Parameter(Mandatory=$false)]
            [string[]]$NameSpace = "Root\CimV2",

            [Parameter(Mandatory=$false)]
            [Switch]$Force
    )
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
        Try {
                [int]$index=0;
                write-log "Attempting to delete classes"  -source ${cmdletname}
                foreach ($Class in $ClassName){
                    Try {
                        if(!($Class)){
                            write-log "Class name is empty. Skipping..." -source ${cmdletname}
                        }else{
                            If ( $index -ge $ClassName.Count ) {
                                $index = $NameSpace.Count-1
                            }
                            [wmiclass]$WMI_Class = Get-WmiObject -Namespace $NameSpace[$index] -Class $Class -list
                            if ($WMI_Class){
                                if (!($force)){
                                    $Answer = Read-Host "Deleting $($Class) can make your system unreliable. Press 'Y' to continue"
                                        if ($Answer -eq"Y"){
                                            $WMI_Class.Delete()
                                            write-log -message "$($Class) deleted." -source ${cmdletname}

                                        }else{
                                            write-log -message "Unknown answer. Class '$($class)' has not been deleted."  -source ${cmdletname}
                                        }
                                    }
                                elseif ($force){
                                    $WMI_Class.Delete()
                                    write-log "$($Class) deleted."   -source ${cmdletname}
                                }
                             }Else{
                                write-log "Class $($Class) not present"  -source ${cmdletname}
                             }#End if WMI_CLASS
                        }#EndIfclass emtpy
                        $index++
                    }
                    Catch {
                        Write-Log -Message "Exception at line '$($_.InvocationInfo.ScriptLineNumber)': $($_.Exception.Message)." -Source ${CmdletName} -Severity 2
                    }
                }#End foreach           
        } 
        catch  {
            Write-Log -Message "Exception at line '$($_.InvocationInfo.ScriptLineNumber)': $($_.Exception.Message)." -Source ${CmdletName} -Severity 2
        } 
    }
}
Function Import-MofFile
{
 
 <#
	.SYNOPSIS
		This function will compile a mof file.

	.DESCRIPTION
		The function allows to create new WMI Namespaces, classes and properties by compiling a MOF file.
        Important: Using the Import-MofFile cmdlet, assures that the newly created WMI classes and Namespaces will also be recreated in case of WMI rebuild.

	.PARAMETER  MofFile
		Specify the complete path to the MOF file.

	.EXAMPLE
		Import-MofFile -MofFile C:\tatoo.mof

	.NOTES
		Version: 1.0
        Author: Stéphane van Gulick
        Creation date:18.07.2014
        Last modification date: 18.07.2014
        History : Creation : 18.07.2014 --> SVG

	.LINK
		www.powershellDistrict.com

	.LINK
		http://social.technet.microsoft.com/profile/st%C3%A9phane%20vg/

#>

[CmdletBinding()]
	Param(
        [Parameter(Mandatory=$true)]
		[ValidateScript({
        
        test-path $_
    
        })][string]$MofFile

	
	)
   
   begin{
   
    if (test-path "C:\Windows\System32\wbem\mofcomp.exe"){
        $MofComp = get-item "C:\Windows\System32\wbem\mofcomp.exe"
    }else{
        write-warning "MofComp.exe could not be found. The process cannot continue."
        exit
    }

   }
   Process{
       Invoke-expression "& $MofComp $MofFile"
       Write-Output "Mof file compilation actions finished."
   }
   End{
    
   }

}
Function Export-MofFile 
{
    
     <#
	.SYNOPSIS
		This function export a specefic class to a MOF file.

	.DESCRIPTION
		The function allows export specefic WMI Namespaces, classes and properties by exporting the data to a MOF file format.
        Use the Generated MOF file in whit the cmdlet "Import-MofFile" in order to import, or re-import the existing class.

	.PARAMETER  MofFile
		Specify the complete path to the MOF file.(Must contain ".mof" as extension.

	.EXAMPLE
		Export-MofFile -ClassName "PowerShellDistrict" -Path "C:\temp\PowerShellDistrict_Class.mof"

	.NOTES
		Version: 1.0
        Author: Stéphane van Gulick
        Creation date:18.07.2014
        Last modification date: 18.07.2014
        History : Creation : 18.07.2014 --> SVG

	.LINK
		www.powershellDistrict.com

	.LINK
		http://social.technet.microsoft.com/profile/st%C3%A9phane%20vg/

#>

    [CmdletBinding()]
    Param(
        [parameter(mandatory=$true)]
        [ValidateScript({
            $_.endsWith(".mof")
        })]
        [string]$Path,


        [parameter(mandatory=$true)]
        [string]$ClassName,

        [Parameter(Mandatory=$false)]
        [string]$NameSpace = "Root\CimV2"
	
	)

    begin{}
    Process{

    if ($PSBoundParameters['ClassName']){
        write-verbose "Checking for Namespace: $($Namespace) and Class $($Classname)"

        [wmiclass]$WMI_Info = Get-WmiObject -Namespace $NameSpace -Class $ClassName -list 

        }
    else{
        [wmi]$WMI_Info = Get-WmiObject -Namespace $NameSpace -list

    }

        [system.management.textformat]$mof = "mof"
        $MofText = $WMI_Info.GetText($mof)
        Write-Output "Exporting infos to $($path)"
        "#PRAGMA AUTORECOVER" | out-file -FilePath $Path
        $MofText | out-file -FilePath $Path -Append
        
        

    }
    End{

        return Get-Item $Path
    }

}
Function Get-WMIClass
{
  <#
	.SYNOPSIS
		get information about a specefic WMI class.

	.DESCRIPTION
		returns the listing of a WMI class.

	.PARAMETER  ClassName
		Specify the name of the class that needs to be queried.

    .PARAMETER  NameSpace
		Specify the name of the namespace where the class resides in (default is "Root\cimv2").

	.EXAMPLE
		get-wmiclass
        List all the Classes located in the root\cimv2 namespace (default location).

	.EXAMPLE
		get-wmiclass -classname win32_bios
        Returns the Win32_Bios class.

	.EXAMPLE
		get-wmiclass -classname MyCustomClass
        Returns information from MyCustomClass class located in the default namespace (Root\cimv2).

    .EXAMPLE
		Get-WMIClass -NameSpace root\ccm -ClassName *
        List all the Classes located in the root\ccm namespace

	.EXAMPLE
		Get-WMIClass -NameSpace root\ccm -ClassName ccm_client
        Returns information from the cm_client class located in the root\ccm namespace.

	.NOTES
		Version: 1.0
        Author: Stephane van Gulick
        Creation date:23.07.2014
        Last modification date: 23.07.2014

	.LINK
		www.powershellDistrict.com

	.LINK
		http://social.technet.microsoft.com/profile/st%C3%A9phane%20vg/

#>
[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$false,valueFromPipeLine=$true)][string]$ClassName,
        [Parameter(Mandatory=$false)][string]$NameSpace = "root\cimv2"
	
	)  
    begin{
    write-verbose "Getting WMI class $($Classname)"
    }
    Process{
        if (!($ClassName)){
            $return = Get-WmiObject -Namespace $NameSpace -Class * -list
        }else{
            $return = Get-WmiObject -Namespace $NameSpace -Class $ClassName -list
        }
    }
    end{

        return $return
    }

}
function Remove-WMINamespace
{
[CmdletBinding()]
	Param(
		    [parameter(mandatory=$true,valuefrompipeline=$true)]
            [ValidateScript({
                $_ -ne ""
            })]
            [string[]]$Path

            #[Parameter(Mandatory=$false)]
            #[string[]]$ParentNameSpace = "Root\CimV2",

            #[Parameter(Mandatory=$false)]
            #[Switch]$Force
    )
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
        Try {
                [int]$index=0;
                write-log "Attempting to delete namespace..."  -source ${cmdletname}
                foreach ($namespace in $Path){
                    write-log "processing namespace $namespace"  -source ${cmdletname}
                    Try {
                        [string]$ParentNamespace = $namespace.split('\') | Select -First ($namespace.split('\').Count-1)
                        write-log "ParentNamespace: $ParentNamespace" -source ${cmdletname}

                        [string]$NamespaceName = $namespace.split('\') | Select -Last 1
                        write-log "NamespaceName: $NamespaceName" -source ${cmdletname}

                        if([string]::IsNullOrEmpty($NamespaceName)){
                            write-log "namespacee name is empty. Skipping..." -source ${cmdletname}
                        }else{
                           Get-WmiObject -Query "SELECT * FROM __Namespace WHERE Name='$NamespaceName'" -Namespace $ParentNamespace -ErrorAction 'SilentlyContinue'| Remove-WmiObject -ErrorAction 'SilentlyContinue';
                        }#EndIfclass emtpy
                    }
                    Catch {
                        Write-Log -Message "Exception at line '$($_.InvocationInfo.ScriptLineNumber)': $($_.Exception.Message)." -Source ${CmdletName} -Severity 2
                    }
                }#End foreach           
        } 
        catch  {
            Write-Log -Message "Exception at line '$($_.InvocationInfo.ScriptLineNumber)': $($_.Exception.Message)." -Source ${CmdletName} -Severity 2
        } 
    }
}
Function Get-WMIProperty 
{
<#
	.SYNOPSIS
		This function gets a WMI property.

	.DESCRIPTION
		The function allows return a WMI property from a specefic WMI Class and located in a specefic NameSpace.

    .PARAMETER  NameSpace
		Specify the name of the namespace where the class resides in (default is "Root\cimv2").

	.PARAMETER  ClassName
		Specify the name of the class.

	.PARAMETER  PropertyName
		The name of the property.

	.EXAMPLE
		Get-WMIProperty -ClassName "PowerShellDistrict" -PropertyName "WebSite"
        Returns the property information from the WMI propertyName "WebSite"

    .EXAMPLE
		Get-WMIProperty -ClassName "PowerShellDistrict"
        Returns all the properties located in the "PowerShellDistrict" WMI class.

	.NOTES
		Version: 1.0
        Author: Stephane van Gulick
        Creation date:29.07.2014
        Last modification date: 12.08.2014

	.LINK
		www.powershellDistrict.com

	.LINK
		http://social.technet.microsoft.com/profile/st%C3%A9phane%20vg/

#>


[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true)]
        [ValidateScript({
            $_ -ne ""
        })]
        [string]$ClassName,

        [Parameter(Mandatory=$false)]
        [string]$NameSpace="Root\cimv2",

        [Parameter(Mandatory=$false)]
        [string]$PropertyName

    

	
	)
    begin{
         

    }
    process{
        If ($PropertyName){
            write-verbose "Returning WMI property $($PropertyName) from class $($ClassName) and NameSpace $($NameSpace)."
            $return = (Get-WMIClass -ClassName $ClassName -NameSpace $NameSpace ).properties["$($PropertyName)"]


         }else{
            write-verbose "Returning list of WMI properties from class $($ClassName) and NameSpace $($NameSpace)."
            $return = (Get-WMIClass -ClassName $ClassName -NameSpace $NameSpace ).properties

            
         } 
    }
    end{
        Return $return
    }  
}
Function Get-WMIPropertyQualifier 
{

<#
	.SYNOPSIS
		This function gets a WMI property qualifier.

	.DESCRIPTION
		The function allows return a WMI property qualifiers from a specefic WMI property, from a specific Class and located in a specefic NameSpace.

	.PARAMETER  ClassName
		Specify the name of the class.

	.PARAMETER  PropertyName
		The name of the property to retrive the qualifiers from.

	.EXAMPLE
		Get-WMIPropertyQualifier -ClassName "PowerShellDistrict" -PropertyName "WebSite"
        Returns the property qualifier information from the WMI propertyName "WebSite"


	.NOTES
		Version: 1.0
        Author: Stephane van Gulick
        Creation date:29.07.2014
        Last modification date: 29.07.2014

	.LINK
		www.powershellDistrict.com

	.LINK
		http://social.technet.microsoft.com/profile/st%C3%A9phane%20vg/

#>


[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true)]
        [ValidateScript({
            $_ -ne ""
        })]
        [string]$ClassName,

        [Parameter(Mandatory=$false)]
        [string]$NameSpace="Root\cimv2",

        [Parameter(Mandatory=$false)]
        [ValidateScript({
            $_ -ne ""
        })]
        [string]$PropertyName

	
	)
    begin{
         write-verbose "getting property qualifiers from: $($PropertyName):"

    }
    process{
        
            write-verbose "Returning WMI property qualifiers $($PropertyName) from class $($ClassName) and NameSpace $($NameSpace)."
            $return = (Get-WMIProperty -NameSpace $NameSpace -ClassName $ClassName -PropertyName $PropertyName).qualifiers
         
    }
    end{
        Return $return
    }  


}
Function New-WMINameSpace 
{
<#
	.SYNOPSIS
		This function help to create a new WMI NameSpace.

	.DESCRIPTION
		The function allows to create a WMI nameSpace. Default path is "Root".
        Accepts a single string, or an array of strings.

	.PARAMETER  NameSpace
		Specify the name of the NameSpace that needs to be created. (Can be a single string, or a array of strings).

    .PARAMETER  Root
		Specify the root path where the NameSpace must be created. 
        If not specified, the NameSpace will automatically be created in "Root"

	.EXAMPLE
		New-WMINameSpace -NameSpace "PowerShellDistrict"
        Creates a new NameSpace called "PowerShellDistrict"

    .EXAMPLE
        New-WMINameSpace -NameSpace "PowerShellDistrict","MyNewNameSpace"
        Creates two NameSpaces called "PowerShellDistrict" and "MyNewNameSpace" in the 'Root' namespace (Default root).

    .EXAMPLE
        New-WMINameSpace -NameSpace "PowerShellDistrict"  -root 'Root\cimV2'
        Creates two NameSpaces called "PowerShellDistrict" in the 'Root\cimV2' namespace.

	.NOTES
		Version: 1.0
        Author: Stephane van Gulick
        Creation date:28.07.2014
        Last modification date: 28.07.2014

	.LINK
		www.powershellDistrict.com

	.LINK
		http://social.technet.microsoft.com/profile/st%C3%A9phane%20vg/

#>
[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true,valueFromPipeLine=$true)][string[]]$NameSpace,
        [Parameter(Mandatory=$false)][string]$Root = "root"
	
	)
begin{}
process{

        Foreach ($Nspace in $NameSpace){
            $Nspace = $([WMICLASS]"\\.\$($Root):__Namespace").CreateInstance()
            $Nspace.name = $NameSpace
            $Nspace.put()
        }
}
End{}

#TODO
<# 
$namespace = $([WMICLASS]"\\.\$($Root):__Namespace").CreateInstance()


$Namespace = New-Object -TypeName System.Management.ManagementObject
$Textpath = "Root\cimv2\New"
$MPath=[System.Management.ManagementPath]$Textpath

$DotNet= New-Object System.Management.ManagementObject($Mpath, $null, $null)

$ManagementScope = New-object System.Management.ManagementScope($MPath,$null)
#>
}
Function Set-WMIPropertyQualifier 
{
<#
	.SYNOPSIS
		This function sets a WMI property qualifier value.

	.DESCRIPTION
		The function allows to set a new property qualifier on an existing WMI property.

	.PARAMETER  ClassName
		Specify the name of the class where the property resides.

	.PARAMETER  PropertyName
		The name of the property.

    .PARAMETER  QualifierName
		The name of the qualifier.

    .PARAMETER  QualifierValue
		The value of the qualifier.

	.EXAMPLE
		Set-WMIPropertyQualifier -ClassName "PowerShellDistrict" -PropertyName "WebSite" -QualifierName Key -QualifierValue $true
        Sets the propertyQualifier "Key" on the property "WebSite"
    
		


	.NOTES
		Version: 1.1
        Author: Stephane van Gulick
        Creation date:16.07.2014
        Last modification date: 27.01.2015

	.LINK
		www.powershellDistrict.com

	.LINK
		http://social.technet.microsoft.com/profile/st%C3%A9phane%20vg/

#>


[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true)]
        [ValidateScript({
            $_ -ne ""
        })]
        [string]$ClassName,

        [Parameter(Mandatory=$false)]
        [string]$NameSpace="Root\cimv2",

        [Parameter(Mandatory=$true)]
        [ValidateScript({
            $_ -ne ""
        })]
        [string]$PropertyName,

        [Parameter(Mandatory=$false)]
        $QualifierName,

        [Parameter(Mandatory=$false)]
        $QualifierValue,

        [switch]$key,
        [switch]$IsAmended=$false,
        [switch]$IsLocal=$true,
        [switch]$PropagatesToInstance=$true,
        [switch]$PropagesToSubClass=$false,
        [switch]$IsOverridable=$true

	
	)

    
    write-verbose "Setting  qualifier $($QualifierName) with value $($QualifierValue) on property $($propertyName) located in $($ClassName) in Namespace $($NameSpace)"
    $Class = Get-WMIClass -ClassName $ClassName -NameSpace $NameSpace

    if ($Class.Properties[$PropertyName]){

        write-verbose "Property $($PropertyName) has been found."
        if ($Key){
            write-verbose "Setting Key property on $($PropertyName)"
            $Class.Properties[$PropertyName].Qualifiers.Add("Key",$true)
            $Class.put() | out-null
        
        
        }else{
            write-verbose "Setting $($QualifierName) with qualifier value $($QualifierValue) on property $($PropertyName)"
            $Class.Properties[$PropertyName].Qualifiers.add($QualifierName,$QualifierValue, $IsAmended,$IsLocal,$PropagatesToInstance,$PropagesToSubClass)
            $Class.put() | out-null
        }

        $return = Get-WMIProperty -NameSpace $Namespace -ClassName $ClassName -PropertyName $PropertyName
        return $return

    }else{
        write-warning "Could not find any property name named $($PropertyName)."
    }
    


}
Function Remove-WMIPropertyQualifier 
{
<#
	.SYNOPSIS
		This function removes a WMI qualifier from a specefic property.

	.DESCRIPTION
		The function allows remove a property qualifier from an existing WMI property (Or several ones).

	.PARAMETER  ClassName
		Specify the name of the class where the property resides.

	.PARAMETER  PropertyName
		The name of the property.

    .PARAMETER  QualifierName
		The name of the qualifier.

    .PARAMETER NameSpace
        Specify the name of the namespace where the class is located (default is Root\cimv2).

	.EXAMPLE
		Remove-WMIPropertyQualifier -ClassName "PowerShellDistrict" -PropertyName "WebSite" -QualifierName Key
        
	.NOTES
		Version: 1.0
        Author: Stephane van Gulick
        Creation date:16.07.2014
        Last modification date: 16.07.2014

	.LINK
		www.powershellDistrict.com

	.LINK
		http://social.technet.microsoft.com/profile/st%C3%A9phane%20vg/

#>


[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true)]
        [ValidateScript({
            $_ -ne ""
        })]
        [string]$ClassName,

        [Parameter(Mandatory=$false)]
        [string]$NameSpace="Root\cimv2",

        [Parameter(Mandatory=$true)]
        [ValidateScript({
            $_ -ne ""
        })]
        [string]$PropertyName,

        [Parameter(Mandatory=$false)]
        [string[]]$QualifierName

	
	)

    Begin{}
    Process{
        foreach ($Qualifier in $QualifierName){

            $Class = Get-WMIClass -ClassName $ClassName -NameSpace $NameSpace
            $Class.Properties[$PropertyName].Qualifiers.remove($QualifierName)
            $Class.put() | out-null
            Write-Output "The $($QualifierName) has been removed from $($PropertyName)"
        }

    }
    End{
    
    }  
        
    


}
Function Get-WMIClassInstance 
{
<#
	.SYNOPSIS
		Get a specefic WMI class instance.

	.DESCRIPTION
		The function allows to retrieve a specefic WMI class instance. If none is specified, all will be retrieved.

	.PARAMETER  ClassName
		Specify the name of the class where the instance resides.

	.PARAMETER NameSpace
        Specify the name of the namespace where the class is located (default is Root\cimv2).

    .PARAMETER  InstanceName
		Name of the Instance to retrieve. (value of the key property).

	.EXAMPLE
        Get-WMIClassInstance -ClassName PowerShellDistrict
        
        Returns all the instances located under the class "PowerShellDistrict".		

    .EXAMPLE
        Get-WMIClassInstance -ClassName PowerShellDistrict -InstanceName 001

        Returns the instance where the key property has a value of '001' located under the class "PowerShellDistrict".
		
	.NOTES
		Version: 1.0
        Author: Stephane van Gulick
        Creation date:16.07.2014
        Last modification date: 12.08.2014

	.LINK
		www.powershellDistrict.com

	.LINK
		http://social.technet.microsoft.com/profile/st%C3%A9phane%20vg/

#>


[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true)]
        [ValidateScript({
            $_ -ne ""
        })]
        [string]$ClassName,

        [Parameter(Mandatory=$false)]
        [string]$NameSpace="Root\cimv2",

        [Parameter(Mandatory=$false)]
        [ValidateScript({
            $_ -ne ""
        })]
        [string[]]$InstanceName


	
	)
    Begin{
            $WmiClass = Get-WMIClass -NameSpace $NameSpace -ClassName $ClassName
    }
    Process{
            

            if (!($InstanceName)){
                $return = $WmiClass.getInstances()
            }else{
               $Instances = $WmiClass.getInstances()
               $KeyProperty = Get-WMIKeyPropertyQualifier -NameSpace $NameSpace -ClassName $ClassName

               $return = $Instances | where $KeyProperty.name -eq $InstanceName
            }
    }
    End{
        return $return

    }


}
Function Remove-WMIClassInstance 
{
<#
	.SYNOPSIS
		removes a specefic WMI class instance.

	.DESCRIPTION
		The function allows to remove a specefic WMI class instance.

	.PARAMETER  ClassName
		Specify the name of the class where the instance is.

	.PARAMETER NameSpace
        Specify the name of the namespace where the class is located (default is Root\cimv2).

    .PARAMETER  InstanceName
		Name of the Instance to retrieve.

	.EXAMPLE
        Remove-WMIClassInstance -ClassName PowerShellDistrict -InstanceName 001
        
        Deletes the instance called "001" located in the custom class "PowerShellDistrict".	(Will be prompted for confirmation).	

    .EXAMPLE
        Remove-WMIClassInstance -ClassName PowerShellDistrict -InstanceName 001 -force
        
        Deletes the instance called "001" located in the custom class "PowerShellDistrict".	(Will NOT be prompted for confirmation).
		
	.NOTES
		Version: 1.0
        Author: Stephane van Gulick
        Creation date:16.07.2014
        Last modification date: 12.08.2014

        History:
            12.08.2014 --> Changed the ConfirmImpact section.

	.LINK
		www.powershellDistrict.com

	.LINK
		http://social.technet.microsoft.com/profile/st%C3%A9phane%20vg/

#>


[CmdletBinding(SupportsShouldProcess = $true)]
	Param(
		[Parameter(Mandatory=$true,ValuefromPipeLine=$true)]
        [ValidateScript({
            $_ -ne ""
        })]
        [string]$ClassName,

        [Parameter(Mandatory=$false)]
        [string]$NameSpace="Root\cimv2",

        [Parameter(Mandatory=$false,ValuefromPipeLine=$true)]
        [ValidateScript({
            $_ -ne ""
        })]
        [string]$InstanceName,

        [switch]$Force,

        [switch]$RemoveAll


	
	)
    Begin{
            if (!($RemoveAll)){
                $WmiInstance = Get-WMIClassInstance -NameSpace $NameSpace -ClassName $ClassName -InstanceName $InstanceName
            }else{
                $WmiInstance = Get-WMIClassInstance -NameSpace $NameSpace -ClassName $ClassName
            }
    }
    Process{
            
            If ($RemoveAll){
                if (!($force)){
             
                    #$Answer = Read-Host "Deleting all the instances from $($ClassName) Are you sure? Press 'Y' to continue"
                            if ($PSCmdlet.ShouldContinue($_, "Are you sure ?") ){
                                
                                    foreach ($instance in $WmiInstance){
                                        if ($instance){
                                            $instance.Delete()
                                    
                                            Write-Output "Deleted $($instance) from class $($ClassName)"
                                            
                                        }
                                    }
                                    break
                
                            }else{
                                write-output "Uknowned answer. '$($WmiInstance)' has not been deleted."
                                break
                            }
                        }#End force
                    elseif ($force){
                            
                                    foreach ($instance in $WmiInstance){
                                        if ($instance){
                                            $instance.Delete()
                                    
                                            Write-Output "Deleted $($instance) from class $($ClassName)"
                                            
                                        }
                                    }
                                
                        }#EndElseif Force
            }
            
            if ($InstanceName){
                    if (!($force)){
             
                    #$Answer = Read-Host "Deleting $($InstanceName) from $($ClassName) Are you sure? Press 'Y' to continue"
                            if ($PSCmdlet.ShouldContinue($_,"Are you sure ??") ){
                                
                                    $WmiInstance.Delete()
                                    
                                    Write-Output "Deleted $($WmiInstance) from class $($ClassName)"
                                
                    
                
                            }else{
                                write-output "Uknowned answer. '$($WmiInstance)' has not been deleted."
                                break
                            }
                        }#End force
                    elseif ($force){
                            
                                    $WmiInstance.Delete()
                                    
                                    Write-Output "Delete $($WmiInstance) from class $($ClassName)"
                                
                        }#EndElseif Force
            else{
                write-warning "Could locate the instance $($InstanceName) in class $($ClassName)"
            }
        }
      }#endProcess
    
    End{
        return $return

    }


}
Function New-WMIClassInstance 
{
    <#
	.SYNOPSIS
		creates a new WMI class instance.

	.DESCRIPTION
		The function allows to retrieve a specefic WMI class instance. If none is specified, all will be retrieved.

	.PARAMETER  ClassName
		Specify the name of the class where the instance resides.

	.PARAMETER NameSpace
        Specify the name of the namespace where the class is located (default is Root\cimv2).

    .PARAMETER  InstanceName
		Name of the Instance to retrieve.

    .PARAMETER  PutInstance
		This parameter needs to be called once the instance has all of its properties set up.

	.EXAMPLE
        $MyNewInstance = New-WMIClassInstance -ClassName PowerShellDistrict -InstanceName "Instance01"
        
        Creates a new Instance name "Instance01" of the WMI custom class "PowerShellDistrict" and sets it in a variable for future use.

        The at least the key property set to a value. To get the key property of a class, use the Get-WMIKeyPropertyQualifier cmdlet.		

    .EXAMPLE
        New-WMIClassInstance -ClassName PowerShellDistrict -PutInstance $MyNewInstance

        Validates the changes and writes the new Instance persistantly into memory.
		
	.NOTES
		Version: 1.0
        Author: Stéphane van Gulick
        Creation date:16.07.2014
        Last modification date: 21.08.2014

	.LINK
		www.powershellDistrict.com
        
        My blog.

	.LINK
		http://social.technet.microsoft.com/profile/st%C3%A9phane%20vg/

        My other projects and contributions.

#>


[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true)]
        [ValidateScript({
            $_ -ne ""
        })]
        [string]$ClassName,

        [Parameter(Mandatory=$false)]
        [string]$NameSpace="Root\cimv2",

        [Parameter(Mandatory=$false)]
        [ValidateScript({
            $_ -ne ""
        })]
        [string[]]$InstanceName,

        [Parameter(valueFromPipeLine=$true)]$PutInstance


	
	)
    Begin{
            $WmiClass = Get-WMIClass -NameSpace $NameSpace -ClassName $ClassName
    }
    Process{
            
            if ($PutInstance){
                
                $PutInstance.Put()
            }else{
                $Return = $WmiClass.CreateInstance()
            }
          
    }
    End{

        If ($Return){
            return $Return
        }

    }
}
Function Get-WMIKeyPropertyQualifier 
{

<#
	.SYNOPSIS
		This function gets the WMI Key property qualifier from a specefic class.

	.DESCRIPTION
		This functions willl return an object of the key property of a specefic WMI class.
        This key property is the property that has to be specified when creating a new isntance of that class.

	.PARAMETER  ClassName
		Specify the name of the class.

	.PARAMETER NameSpace
        Specify the name of the namespace where the class is located (default is Root\cimv2).

	.EXAMPLE
		Get-WMIKeyPropertyQualifier -ClassName "PowerShellDistrict"
        Returns the property that has the key qualifier.


	.NOTES
		Version: 1.0
        Author: Stephane van Gulick
        Creation date:12.08.2014
        Last modification date: 12.08.2014

	.LINK
		www.powershellDistrict.com

	.LINK
		http://social.technet.microsoft.com/profile/st%C3%A9phane%20vg/

#>


[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true)]
        [ValidateScript({
            $_ -ne ""
        })]
        [string]$ClassName,

        [Parameter(Mandatory=$false)]
        [string]$NameSpace="Root\cimv2"

	
	)
    begin{
         write-verbose "getting property qualifiers from: $($PropertyName):"
         $WmiClass = Get-WMIClass -NameSpace $NameSpace -ClassName $ClassName 
    }
    process{
                
            $Properties = Get-WMIProperty -NameSpace $NameSpace -ClassName $ClassName

            foreach ($Property in $Properties){
                
                $Qualifiers = Get-WMIPropertyQualifier -NameSpace $NameSpace -ClassName $ClassName -PropertyName $Property.name
                foreach ($Qualifier in $Qualifiers){
                    if ($Qualifier.name -eq "key"){
                        write-verbose "Key property for class $($ClassName) in NameSpace $($NameSpace) is $($Property.Name)."
                        return $Property
                    }
                }
                
            }

            
           
         
    }
    end{
        
    }  


}
Function Get-WMINameSpace 
{
  <#
	.SYNOPSIS
		get information about a specefic WMI NameSpace.

	.DESCRIPTION
		returns the listing of a WMI NameSpace.

	.PARAMETER  Name
		Specify the name of the namespace that needs to be queried.

    .PARAMETER  root
		Specify the name of the root where the namespace resides in (default is "Root").

	.EXAMPLE
		Get-WMINameSpace
        List all the NameSpaces located in the 'root' level. (default location).

	.EXAMPLE
		Get-WMINameSpace -Name "District"
        Returns information about the District class.

	.EXAMPLE
		Get-WMINameSpace -Root Root\cimv2
        Returns the namespaces located in Root\Cimv2

    .EXAMPLE
		Get-WMINameSpace -Name "District2" -root Root
        
	.NOTES
		Version: 1.0
        Author: Stephane van Gulick
        Creation date:15.08.2014
        Last modification date: 15.08.2014

	.LINK
		www.powershellDistrict.com

	.LINK
		http://social.technet.microsoft.com/profile/st%C3%A9phane%20vg/

#>
[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$false,valueFromPipeLine=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory=$false)][string]$Root = "root"
	
	) 
    Begin{}
    Process{
            
            if ($Name){
                $Return = Get-WMIObject -class __Namespace -namespace $Root -Filter "Name='$Name'"
            }else{
                $Return = Get-WMIObject -class __Namespace -namespace $Root
            }
    }
    End{
            return $Return
    }
}
#endregion [WMI]
##*===============================================

##*===============================================
#region [Services]
function Stop-CMSetup {
	[CmdletBinding()]
	Param ([switch]$Delete)
	Begin {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process {
         Try {
                    Stop-Process -Name 'ccmsetup' -Force -ErrorAction 'SilentlyContinue'|Out-Null                   
                    Stop-ServiceAndDependencies -Name 'ccmsetup' -PassThru -ContinueOnError $true -ErrorAction 'SilentlyContinue'|Out-Null
                    If ( $Delete ) {Remove-Service -Name 'ccmsetup'|OUt-Null}
        } 
        Catch  {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName}
        }          
	}
}
function Reset-CryptographicService {
	[CmdletBinding()]
	param
	(
    )

	Begin
	{
		[string]${CmdletSection} = "Begin"
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;

    }
	Process
	{
        Try {
            
            If ( !(Test-ServiceExists -Name 'Cryptsvc' -ContinueOnError $true -ErrorAction 'SilentlyContinue' )) {
                Throw "Service 'Cryptsvc' Does Not Exist."
            }
            Set-ServiceStartMode -Name 'Cryptsvc' -StartMode Disabled -ErrorAction 'SilentlyContinue' -ContinueOnError $true;
            Stop-ServiceAndDependencies -Name 'Cryptsvc' -ContinueOnError $true  -ErrorAction 'SilentlyContinue';
            Remove-File -Path "$env:windir\System32\catroot2\*.*" -Recurse -ContinueOnError $true  -ErrorAction 'SilentlyContinue';
            Remove-File -Path "$env:windir\security\logs\*.log" -Recurse -ContinueOnError $true  -ErrorAction 'SilentlyContinue';
            Set-ServiceStartMode -Name 'Cryptsvc' -StartMode Automatic  -ContinueOnError $true  -ErrorAction 'SilentlyContinue';
            Start-ServiceAndDependencies -Name 'Cryptsvc' -ContinueOnError $true -ErrorAction 'SilentlyContinue';
		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} 
		}
	}
}
function Remove-Service {
    [CmdletBinding()]
    param(
		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string]$Name   
    )
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process
    {
        Try {
            
            Stop-ServiceAndDependencies -Name $Name -ContinueOnError $true -ErrorAction 'SilentlyContinue';
            [psobject]$DeleteService = Execute-Process -Path $(Join-Path -Path $(Split-Path -Path $env:ComSpec -Parent) -ChildPath 'sc.exe') -Parameters 'delete',"`"$Name`"" -CreateNoWindow -PassThru -ContinueOnError $true -ErrorAction 'SilentlyContinue';
            Write-Log -Message "DeleteService: $($DeleteService |  Fl * | Out-String)" -Source ${CmdletName}
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} ;
        }
    }
    End
    {

    }
}
function Remove-CMServices {
    [cmdletbinding()]
    Param(
        [string[]]$Services = @('ccmsetup','ccmexec','smstsmgr','CmRcService')
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        Try{Stop-CMServices;}catch{}

    }
    Process {
        Try {
            If ( Test-SccmClient ) {
                throw "SCCM client still installed.  Uninstall Client First."
            }
            foreach ( $Service in $Services ) {
                Try {
                    Remove-Service -Name $Service -ErrorAction 'SilentlyContinue';
                }        
                Catch {
                    Write-Log -Message "[Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
                } 
            }
            [string]$RegParentPath = "HKLM\SYSTEM\CurrentControlSet\Services"
            foreach ( $Service in $Services ) {
                Try {
                    Remove-RegistryKey -Key "$RegParentPath\$Serivce" -Recurse -ContinueOnError $true -Ea Silentlycontinue;
                }        
                Catch {
                    Write-Log -Message "[Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} 
                } 
            }
        } 
        catch {
            Write-Log -Message "[Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        } 
    }
} 
function Stop-CMServices {
    [cmdletbinding()]
    Param(
        [string[]]$Services = $(Get-Variable "CCM_SERVICE_[0-9][0-9]" | Select -ExpandProperty Value)
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process {
        foreach ( $Service in $Services ) {
            Try {
                Write-Log -Message ""
                If ( Test-ServiceExists -Name $Service -ContinueOnError $true ) {
                    Stop-ServiceAndDependencies -Name $Service -PassThru -ContinueOnError $true -ErrorAction 'SilentlyContinue' -PendingStatusWait $([TimeSpan]::FromMinutes(1));
                    If ( (Get-Service -Name $service).Status -notlike 'Stopped' ){
                        [string]$ImageFilePath  = cmd /c sc qc $Service | Select-String "BINARY_PATH_NAME" | %{$_.Line.Split(' ')} | ?{$_ -match '[A-Za-z]:\\'}
                        Stop-Process -Name $ImageFilePath  -Force -Ea 'Stop'
                    }

                }
                Else {
                    Write-Log -Message "Service '$Service' Does Not Exist." -Source ${CmdletName} 
                }
            }        
            Catch {
                Write-Log -Message "[Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName}
            } 
        }
    }
} 
function Stop-CMExec {
	[CmdletBinding()]
	Param ([switch]$Delete)
	Begin {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process {
         Try {
                    Stop-ServiceAndDependencies -Name 'ccmexec' -PassThru -ContinueOnError $true -ErrorAction 'SilentlyContinue' -PendingStatusWait ([timespan]::FromSeconds(1))
                    If ( $(Get-Service -Name ccmexec ).Status -notlike 'Running' ){
                        [string]$ImagePath = cmd /c sc qc ccmexec | Select-String "BINARY_PATH_NAME" | %{$_.Line.Split(' ')} | ?{$_ -match '[A-Za-z]:\\'}
                        Invoke-Expression -command "cmd /c taskkill /IM `"$(Split-Path -Leaf -Path $ImagePath)`" /F"
                    }
        } 
        Catch  {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName}
        }          
	}
}
#endregion [Services]
##*===============================================

##*===============================================
#region [WindowsUpdate]
Function Reset-WUServicePermissions {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$SDDL = 'D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)'
        ,[Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Services = @('BITS','WUAUSERV','appidsvc','cryptsvc')
    )
    Begin
    {
        [string[]]$ReturnValue = @();
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
        Try
        {
            #[byte[]]$BinarySD = ConvertFrom-SDDLToBinary -SDDL $SDDL;
            Foreach ( $Service in $Services) {
                Try {
                        [psobject]$SetPerms = Execute-Process -Path "$env:windir\system32\sc.exe" -Parameters 'sdset',$Service,"`"$($SDDL)`"" -CreateNoWindow -PassThru -ContinueOnError $true
                        Write-Log -Message "SetPerms" -Source ${CmdletName}
                }
                Catch {
                    Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2    
                }
                Finally {
                    Remove-Variable -Name BinarySD -Force -Ea SilentlyContinue
                }
            }

        }
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}        
        
    }
}
Function Register-WUServiceLibraries {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Libraries = @('atl.dll ','urlmon.dll ','mshtml.dll ','shdocvw.dll ','browseui.dll ','jscript.dll ','vbscript.dll ','scrrun.dll ','msxml.dll ','msxml3.dll ','msxml6.dll ','actxprxy.dll ','softpub.dll ','wintrust.dll ','dssenh.dll ','rsaenh.dll ','gpkcsp.dll ','sccbase.dll ','slbcsp.dll ','cryptdlg.dll ','oleaut32.dll ','ole32.dll ','shell32.dll ','initpki.dll ','wuapi.dll ','wuaueng.dll ','wuaueng1.dll ','wucltui.dll ','wups.dll ','wups2.dll ','wuweb.dll ','qmgr.dll ','qmgrprxy.dll ','wucltux.dll ','muweb.dll ','wuwebv.dll')
    )
    Begin
    {
        [string[]]$ReturnValue = @();
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
        Try
        {
            Get-ChildItem -Path "$Env:windir\system32","$Env:windir\syswow64" -Include $Libraries -Force -Recurse -Ea Silentlycontinue | %{Invoke-RegisterOrUnregisterDLL -FilePath $_.FullName -DLLAction Register -ContinueOnError $true -Ea Silentlycontinue ;}
        }
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}        
        
    }
}
Function Clear-WUServiceCache {
    [CmdletBinding()]
    Param(

    )
    Begin
    {
        [string[]]$ReturnValue = @();
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
        Try
        {
            Remove-RegistryKey -Key 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Recurse -ContinueOnError $true -Ea Silentlycontinue;
            "$env:systemroot\SoftwareDistribution","$env:systemroot\system32\Catroot2" | %{Remove-Folder -Path $_ -ContinueOnError $true;}
            Remove-File -Path @(
                "$env:ALLUSERSPROFILE\Application Data\Microsoft\Network\Downloader\qmgr*.dat",
                "$env:ALLUSERSPROFILE\Microsoft\Network\Downloader\qmgr*.dat",
                "$env:SystemRoot\winsxs\pending.xml",
                "$env:SystemRoot\winsxs\WindowsUpdate.log",
                "$env:windir\security\logs\*.log"
            ) -Recurse -ContinueOnError $true -EA SilentlyContinue;

            Write-Log -Message "SetWUPerms" -Source ${CmdletName}
        }
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}        
        
    }
}
Function Stop-WUServices {
    [cmdletbinding()]
    Param(
        [string[]]$Services = @('BITS','WUAUSERV','appidsvc','cryptsvc')
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process {
        Try {
            foreach ( $Service in $Services ) {
                Try {
                    Stop-ServiceAndDependencies -Name $Service -PassThru -ContinueOnError $true -ErrorAction 'SilentlyContinue';
                }        
                Catch {
                    Write-Log -Message "[Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
                } 
            }
        } 
        catch {
            Write-Log -Message "[Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        } 
    }
} 
Function Start-WUServices {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Services = @('BITS','WUAUSERV','appidsvc','DcomLaunch','cryptsvc','DcomLaunch')

        ,[Parameter(Mandatory=$false)]
        [switch]$Remediate

    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process {
        Try {
            foreach ( $Service in $Services ) {
                Try {
                    Set-ServiceStartMode -Name $Service -ComputerName $env:computername -StartMode Automatic -ContinueOnError $true;
                    Start-ServiceAndDependencies -Name $Service -ComputerName $env:computername -ContinueOnError $true
                    If($Remediate -and $Service -match 'wuauserv') { Invoke-Expression -Command "cmd /c sc config wuauserv type= own"|out-null; }
                }        
                Catch {
                    Write-Log -Message "[Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
                } 
            }
        } 
        catch {
            Write-Log -Message "[Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        } 
    }
} 
Function Reset-WindowsUpdateComponents {
    [cmdletbinding()]
    Param(
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process {
        Try {
            Write-Log -Message "Stopping Services..." -Source ${CmdletName}
            Stop-WUServices;
            Write-Log -Message "Done." -Source ${CmdletName}

            Write-Log -Message "Clearing Files/Settings..." -Source ${CmdletName}
            Clear-WUServiceCache;
            Write-Log -Message "Done." -Source ${CmdletName}

            Write-Log -Message "Resetting Service Permissions..." -Source ${CmdletName}
            Reset-WUServicePermissions;
            Write-Log -Message "Done." -Source ${CmdletName}

            Write-Log -Message "Registering Service Libraries..." -Source ${CmdletName}
            Register-WUServiceLibraries;
            Write-Log -Message "Done." -Source ${CmdletName}

            Write-Log -Message "Restarting Services..." -Source ${CmdletName}
            Start-WUServices;
            Write-Log -Message "Done." -Source ${CmdletName}

        } 
        catch {
            Write-Log -Message "[Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        } 
    }
} 
#endregion [WindowsUpdate]
##*===============================================

##*===============================================
#region [Content info]
Function Get-ClientSetupInstallationInfo {
    [CmdletBinding(DefaultParameterSetName = 'ByValue')]
    [OutputType([psobject],ParameterSetName = 'ByValue')]
    param (
		[Parameter(ParameterSetName = 'ByValue',Mandatory = $false,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('([A-Za-z]{3}[A-Za-z0-9]{5})')]
        [System.String]$PackageID = $GLOBAL:CCM_CLIENT_PKG_ID,

		[Parameter(ParameterSetName = 'ByValue',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $false,ValueFromRemainingArguments = $false,Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]$DefaultSources = $(Get-Variable -Name "CCM_SETUPSOURCE_*" | Select-Object -ExpandProperty 'Value')
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Log -Source ${CmdletName} -Message "Executing '${CmdletName}'...."

        [psobject]$ReturnValue = New-Object -TypeName 'System.Management.Automation.PSObject' -Property (@{
            ID=$PackageID;
            Version=$(New-Object -TypeName 'System.Version')
            Sources=$(New-Object -TypeName 'System.Collections.ArrayList');
        });
    }
    Process {
        Try {
            

            ## Set Return Value
            [string]$ReturnValue = $();
        }
        Catch {
            Write-Log -Message "Exception: '$($_.Exception.Message)'`r`nLine Number:[$($_.InvocationInfo.ScriptLineNumber)]" -Source ${CmdletName} -Severity 2;
        }
    }
    End {
        Write-Output -InputObject $ReturnValue
    }
}
Function Get-CMObjectContentVersion {
    [CmdletBinding()]
    [OutputType([int32])]
    Param (
        [Parameter(Mandatory = $True)]
        $PackageID
    )
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [int32]$ReturnValue = -1
    }
    Process
    {
        Try
        {
            [int32]$ReturnValue = Invoke-SQL -Query @"
SELECT 
	loc.SourceVersion as 'SourceVersion'
FROM 
	fn_ListObjectContentExtraInfo(1033) loc
WHERE 
	loc.PackageID = '$PackageID'
ORDER BY 
	loc.SourceVersion DESC      
"@ | Select-Object -ExpandProperty 'SourceVersion' -First 1
        }
        Catch {
            Write-Log -Message "Exception: '$($_.Exception.Message)'`r`nLine Number:[$($_.InvocationInfo.ScriptLineNumber)]" -Source ${CmdletName} -Severity 2;
        }
    }
    End {
        Write-Output -InputObject $ReturnValue
    }
}
Function Get-CMClientContentLocations {
  [CmdletBinding()]
  [OutputType([string[]])]
  param
  (
    [Parameter(Mandatory = $false,Position = 0)]
    [ValidateLength(3, 3)]
    [ValidateNotNullOrEmpty()]
    [string]$MPSiteCode = $(Get-CMSiteCodeFromAD ),

    [Parameter(Mandatory = $false,Position = 1)]
    [ValidateNotNullOrEmpty()]
    [string]$MPSiteServer = $(Get-CMManagementPointFromAD),

    [Parameter(Mandatory = $false,Position = 2)]
    [ValidatePattern('([A-Za-z]{3})([A-Za-z0-9]{5})')]
    [ValidateNotNullOrEmpty()]
    [string]$PackageID = $GLOBAL:CCM_CLIENT_PKG_ID,

    [Parameter(Mandatory = $false,Position = 4)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -Path $_ })]
    [string]$MessagingRedist = "$dirSupportFiles\lib\MsgRedist.dll",

    [Parameter(Mandatory = $false,Position = 5)]
    [ValidateNotNullOrEmpty()]
    [string]$FullyQualifiedDomain = $(Get-ADDomainName),

    [Parameter(Position = 7)]
    [string]$ADSite = $(Get-ADSiteName)
  )
	
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [string[]]$ReturnValue = @();
        Write-Log -Source ${CmdletName} -Message "Executing '${CmdletName}'...."

        Write-Log -Message "FullyQualifiedDomain: $FullyQualifiedDomain" -Source ${CmdletName}
    }
    Process
    {
        Try
        {
            [string]$Domain = $FullyQualifiedDomain.Split('.') | Select-Object -First 1
            Write-Log -Message "Domain: $Domain" -Source ${CmdletName}

            If ( [string]::IsNullOrEmpty($Domain) ) {throw "Value of 'Domain' Is Null.";}
            
            [string]$Forest = ( $FullyQualifiedDomain.Split(".") | Select-Object -Skip 1 ) -join '.'
            Write-Log -Message "Forest: $Forest" -Source ${CmdletName}

            If ( [string]::IsNullOrEmpty($Forest) ) {throw "Value of 'Forest' Is Null.";}

            Add-Type -Path $MessagingRedist -ErrorAction Stop;
			
            # Set up the objects
            $httpSender = New-Object -TypeName Microsoft.ConfigurationManagement.Messaging.Sender.Http.HttpSender
            $clr = New-Object -TypeName Microsoft.ConfigurationManagement.Messaging.Messages.ConfigMgrContentLocationRequest
            $cmReply = New-Object -TypeName Microsoft.ConfigurationManagement.Messaging.Messages.ContentLocationReply
			
            # Discover (the try/catch is in case the ADSI COM
            # object cannot be loaded (WinPE).
            try {
                $clr.Discover()
            }
            catch {

                $clr.LocationRequest.ContentLocationInfo.IPAddresses.DiscoverIPAddresses()
                $clr.LocationRequest.ContentLocationInfo.ADSite.DiscoverADSite()

                $clr.LocationRequest.Domain = New-Object -TypeName Microsoft.ConfigurationManagement.Messaging.Messages.ContentLocationDomain
                $clr.LocationRequest.Domain.Name = $Domain

                $clr.LocationRequest.Forest = New-Object -TypeName Microsoft.ConfigurationManagement.Messaging.Messages.ContentLocationForest
                $clr.LocationRequest.Forest.Name = $Forest
            }

            [int]$PackageVersion = Get-CMObjectContentVersion -PackageID $PackageID
            Write-Log -Message "PackageVersion: $PackageVersion" -Source ${CmdletName}
            
            If ( $PackageVersion -le 0 ) {throw "Unknown Error getting package version of '$PackageID'.";}

            # Define our SCCM Settings for the message
            $clr.SiteCode = $MPSiteCode
            $clr.Settings.HostName = $MPSiteServer
            $clr.LocationRequest.Package.PackageId = $PackageID
            $clr.LocationRequest.Package.Version = $PackageVersion
			
            # If we want to "spoof" a request from a different
            # AD Site, we can just pass that AD Site in here.
            if (![string]::IsNullOrEmpty($ADSite)) {
                $clr.LocationRequest.ContentLocationInfo.ADSite = $ADSite
            }
			
            # Validate
            $clr.Validate([Microsoft.ConfigurationManagement.Messaging.Framework.IMessageSender]$httpSender)
			
            # Send the message
            $cmReply = $clr.SendMessage($httpSender)
			
            # Get response
            $response = $cmReply.Body.Payload.ToString()
	        Write-Log -Message "Response: $Response" -Source ${CmdletName}

            while ($response[$response.Length - 1] -ne '>') { $response = $response.TrimEnd($response[$response.Length - 1])}
	        Write-Log -Message "Response: $Response" -Source ${CmdletName}

            [xml]$XmlObject = [xml](ConvertTo-Xml -xml ($response))  
            Write-Log -Message "XmlObject: $($XmlObject | Fl *|out-string)" -Source ${CmdletName}

            [string]$UrlTemplate = 'http://$($_.LocationRecords.LocationRecord.ServerRemoteName)/SMS_DP_SMSPKG$/$($PackageID).$($PackageVersion)'
            $XmlObject.ContentLocationReply.Sites.Site|?{![string]::IsNullOrEmpty($_.LocationRecords.LocationRecord.ServerRemoteName)}|%{
                $ReturnValue += $ExecutionContext.InvokeCommand.ExpandString($UrlTemplate);
                #$_.LocationRecords.LocationRecord.ServerRemoteName
            }
        }
        Catch {
            Write-Log -Message "Exception: '$($_.Exception.Message)'`r`nLine Number:[$($_.InvocationInfo.ScriptLineNumber)]" -Source ${CmdletName} -Severity 2;
        }
    }
    end
    {
        Write-Output -InputObject $ReturnValue
    }
}
Function Select-CMClientSetupSource {
	[CmdletBinding()]
	param (
    )
	Begin  {
	    [string]${CmdletName} = 'Set-CCMSetupSource '	
        [string]$ReturnValue = [string]::Empty
    }
    Process {
        Try {
            [string[]]$PotentialSources = @( @($(Get-CMClientContentLocations)) + @($(Get-LoadedSetupSources|Select -ExpandProperty Value)))
            Write-Log -Message "Gathered $($PotentialSources.Count) Potential Sources:[$($PotentialSources|%{"`r`n$_"})]" -Source ${CmdletName}

            If ( $PotentialSources.Count -eq 0 ) {
                $GLOBAL:CCM_SETUP_USE_SOURCE = $false;
                Throw "No Valid Potential Sources Detected."
            }

            $PotentialSources | Where-Object { 
                    If ( $_ -like 'http*'  ) { 
                        Write-Log -Message "Testing HTTP Source '$($_)'..." -Source ${CmdletName}
                        Test-URI -URI $_
                    } Else {
                        Write-Log -Message "Testing SMB Source '$($_)'..." -Source ${CmdletName}
                        Test-Path -Path $_
                    } 
                } | `
                    Select-Object -First 1 `
                | %{
                    Write-Log -Message "Valid Source. Set Parameter [$($_)]" -Source ${CmdletName}
                    [string]$global:CCM_SETUP_SOURCE_PARAMETER =  "/source:`"$_`"";
        
                }
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -SEverity 3
	    }
        Finally{
            Write-Log -Message "[CCM_SETUP_SOURCE_PARAMETER = '$global:CCM_SETUP_SOURCE_PARAMETER']" -Source ${CmdletName}
        }
    }
}
#endregion [Content info]
##*===============================================

##*===============================================
#region [Set Site Info]
Function Set-CMSetupDomainInfo {
    [CmdletBinding(DefaultParameterSetName = 'ByValue')]
    param ()
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Log -Source ${CmdletName} -Message "Executing '${CmdletName}'...."
    }
    Process {

         Try {
            [string]$ADDomainName = [System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain() |Select -ExpandProperty 'Name' -First 1
            Write-Log -Source ${CmdletName} -Message "ADDomainName: $ADDomainName"
             If ( [string]::IsNullOrEmpty($ADSiteName) ) {throw "Value of 'ADSiteName' Is Null.";}
        }
        Catch {
            [string]$ADDomainName = $((([regex]'(?<=,DC=)(\w*)(?=($|,))').Matches($($(get-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine' -Value 'Distinguished-Name') ))|Select-Object -ExpandProperty Value) -join '.')
            Write-Log -Source ${CmdletName} -Message "ADDomainName: $ADDomainName"
        }
        Finally {
            Set-Variable -Name "CCM_AD_DOMAIN_NAME" -Value $ADDomainName -Force -Scope Global;
        }
               
        Try {
            [string]$ADForestName = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest() | Select-Object -ExpandProperty 'Name' -First 1;
            Write-Log -Source ${CmdletName} -Message "ADForestName: $ADForestName"
        }
        Catch {
            [string]$ADForestName = $ADDomainName.Replace(${ENV:USERDOMAIN},'').TrimSTart('.').TrimEnd('.')
            Write-Log -Source ${CmdletName} -Message "ADForestName: $ADForestName"
        }
        Finally {
             Set-Variable -Name "CCM_AD_FOREST_NAME" -Value $ADForestName -Force -Scope Global;
        }

        Try {
            [string]$ADSiteName = [System.DirectoryServices.ActiveDirectory.ActiveDirectorySite]::GetComputerSite()|Select -ExpandProperty 'Name' -First 1
            Write-Log -Source ${CmdletName} -Message "ADSiteName: $ADSiteName"
            If ( [string]::IsNullOrEmpty($ADSiteName) ) {throw "Value of 'ADSiteName' Is Null.";}
        }
        Catch {
            [string]$ADSiteName = $(Get-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine'  -Value 'Site-Name' -ReturnEmptyKeyIfExists -ContinueOnError $true -ErrorAction 'SilentlyContinue' | select-object -first 1)
            Write-Log -Source ${CmdletName} -Message "ADSiteName: $ADSiteName"
        }
        Finally {
            Set-Variable -Name "CCM_AD_SITE_NAME" -Value $ADSiteName -Force -Scope Global;    
        }
        
    }
}
Function Set-CMSetupNetworkInfo {
    [CmdletBinding(DefaultParameterSetName = 'ByValue')]
    param ()
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Log -Source ${CmdletName} -Message "Executing '${CmdletName}'...."
    }
    Process {
        [psobject]$ActiveNetworkAddress = Select-NetworkAddress;
        Write-Log -Source ${CmdletName} -Message "ActiveNetworkAddress: [$($ActiveNetworkAddress|fl *|out-string)]"

         If (!$ActiveNetworkAddress ) {throw "Value of 'ActiveNetworkAddress' Is Null.";}

         $SubnetInformation = Get-SubnetDetails -IPAddress $ActiveNetworkAddress.IPAddress -SubnetMask $ActiveNetworkAddress.SubnetMask
         Write-Log -Source ${CmdletName} -Message "SubnetInformation: [$($SubnetInformation|fl *|out-string)]"

        Set-Variable -Name "CCM_NETWORK_IP" -Value $ActiveNetworkAddress.IPAddress -Force -Scope Global;
        Set-Variable -Name "CCM_NETWORK_SUBNET_MASK" -Value $ActiveNetworkAddress.SubnetMask -Force -Scope Global;
        Set-Variable -Name "CCM_NETWORK_SUBNET_ADDRESS" -Value $SubnetInformation.NetworkAddress -Force -Scope Global;
        Set-Variable -Name "CCM_NETWORK_START_IP" -Value $SubnetInformation.MinimumHost -Force -Scope Global;
        Set-Variable -Name "CCM_NETWORK_END_IP" -Value $SubnetInformation.MinimumHost -Force -Scope Global;
        Set-Variable -Name "CCM_NETWORK_START_IP_DECIMAL" -Value $SubnetInformation.MinimumHostDecimal -Force -Scope Global;
        Set-Variable -Name "CCM_NETWORK_END_IP_DECIMAL" -Value $SubnetInformation.MaximumHostDecimal -Force -Scope Global;
    }
}
Function Set-CMPrimarySiteCode {
    [CmdletBinding()]
    param()
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [string]$ReturnValue = [string]::Empty
    }
    Process {
        Try {
            [string]$PrimarySiteCode = Get-CMSiteCodeFromAD;
            Write-Log -Message "PrimarySiteCode: $PrimarySiteCode" -Source ${CmdletName}
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2         
        }
        Finally {
            Write-Log -Message "PrimarySiteCode: $PrimarySiteCode" -Source ${CmdletName}
            if ( [string]::IsNullOrEmpty($PrimarySiteCode)){
                Try {
                    [string]$PrimarySiteCode = Get-CMSiteCodeFromCM;
                }
                Catch {
                    Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2         
                }
                Finally {
                    Write-Log -Message "PrimarySiteCode: $PrimarySiteCode" -Source ${CmdletName}
                }                          
            }
        }
    }
    End {
        Set-Variable -Name 'CCM_MP_SITECODE' -Value $PrimarySitecode -Scope Global -Force;
    }
}
Function Set-CMPrimaryManagementPoint {
    [CmdletBinding()]
    param()
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [string]$ReturnValue = [string]::Empty
    }
    Process {
        Try {
            [string]$PrimaryServer = Get-CMManagementPointFromAD;
            Write-Log -Message "PrimaryServer: $PrimaryServer" -Source ${CmdletName}
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2         
        }
        Finally {
            Write-Log -Message "PrimaryServer: $PrimaryServer" -Source ${CmdletName}
            if ( [string]::IsNullOrEmpty($PrimaryServer)){
                Try {
                    [string]$PrimaryServer = Get-CMManagementPointFromCM;
                }
                Catch {
                    Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2         
                }
                Finally {
                    Write-Log -Message "PrimaryServer: $PrimaryServer" -Source ${CmdletName}
                }                          
            }
        }
    }
    End {
        Set-Variable -Name 'CCM_MP_SITESERVER' -Value $PrimaryServer -Scope Global -Force;
    }
}
Function Set-CMFallbackStatusPoint {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(3,3)]
        [string]$SiteCode = $GLOBAL:CCM_MP_SITECODE
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process {
        Try  { 
            ## 1) Try to get primary boundary via AD Group
            [string]$PrimaryBoundaryQuery = @"
SELECT 
    srl.ServerName as 'FallbackStatusPoint'
FROM
    v_SystemResourceList srl
WHERE 
    srl.SiteCode = '$($SiteCode.ToUpper())'
"@
            Write-Log -Message "PrimaryBoundaryQuery: $PrimaryBoundaryQuery" -Source ${CmdletName}
            
            [string]$ReturnValue = Invoke-SQL -Query $PrimaryBoundaryQuery|select -ExpandProperty 'FallbackStatusPoint' -First 1
            Write-Log -Message "BoundaryID: $BoundaryID" -Source ${CmdletName}
        } 
        Catch  { 
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2 
        }     
    }
    End {
        Set-Variable -Name 'CCM_FSP_SERVER' -Value $PrimarySitecode -Scope Global -Force;
    }
}
Function Set-CMBoundaryInformation {
    [CmdletBinding()]
    param(

        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [string]$ADSite = $($GLOBAL:CCM_AD_SITE_NAME),

        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [string]$ADDomain = $($GLOBAL:CCM_AD_DOMAIN_NAME),

        [Parameter(Mandatory=$false)]
        [string]$ADForest = $($GLOBAL:CCM_AD_FOREST_NAME),

        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [string]$StartIP = $($GLOBAL:CCM_NETWORK_START_IP),

        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [string]$EndIP = $($GLOBAL:CCM_NETWORK_END_IP),

        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [int]$StartDecimal = $($GLOBAL:CCM_NETWORK_START_IP_DECIMAL),

        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [int]$EndDecimal = $($GLOBAL:CCM_NETWORK_END_IP_DECIMAL)

    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [string]$ReturnValue = [string]::Empty
    }
    Process {
        Try {
            [string]$SystemsQuery = @"
SELECT 
	bss.SiteSystemName as 'DistributionPoint', 
    bg.DefaultSiteCode as 'SiteCode'
  FROM 
	BoundaryGroupMembers bgm
  INNER JOIN 
	vSMS_BoundaryGroup bg
  ON 
	bgm.GroupID = bg.GroupID
  INNER JOIN 
	fn_rbac_BoundarySiteSystems ('disabled') bss
  ON
	bgm.BoundaryID = bss.BoundaryID
  WHERE bgm.BoundaryID IN (SELECT bou.BoundaryID FROM BoundaryEx bou WHERE (((bou.BoundaryType = 1 AND bou.Value = '$ADSite') OR (bou.BoundaryType = 3 AND ((bou.NumericValueLow <= $StartDecimal AND bou.NumericValueHigh >= $EndDecimal) OR (bou.Value = '$StartIP-$EndIP')))) AND bou.Name LIKE '$ADForest/%'))
"@
            
            [psobject[]]$BoundaryGroups = @();
            
            Invoke-SQL -Query $SystemsQuery | Select-Object -Property "DistributionPoint","SiteCode"|%{ $BoundaryGroups += $_}
            Write-Log -Source ${CmdletName} -Message "BoundaryGroups: $($BoundaryGroups | Fl * |Out-String)."
            
            [string]$SetCMSiteCode = $BoundaryGroups | Group-Object -Property SiteCode | Sort-Object -Property 'Count' -Descending | Select-Object -First 1 -ExpandProperty 'Name'
            Write-Log -Source ${CmdletName} -Message "SetCMSiteCode: $($SetCMSiteCode)."

            Set-Variable -Name "CCM_BOUNDARY_SYSTEMS" -Value $($BoundaryGroups | Select-Object -ExpandProperty 'DistributionPoint') -Force -Scope Global;
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2         
        }
    }
}
#endregion [Set Site Info]
##*===============================================

##*===============================================
#region [AD/CM Site Info]
Function Get-ADDomainName {
    [CmdletBinding(DefaultParameterSetName = 'ByValue')]
    [OutputType([string],ParameterSetName = 'ByValue')]
    param ()
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Log -Source ${CmdletName} -Message "Executing '${CmdletName}'...."
        [string]$ReturnValue = [string]::Empty;
    }
    Process {
        Try {
            Try {
                [System.Reflection.Assembly]::LoadWithPartialName('System.DirectoryServices.ActiveDirectory')|Out-Null;
                [string]$ReturnValue = [System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()|Select-Object -ExpandProperty 'Name' -First 1;
            }
            Catch {
                [string]$ReturnValue=$((([regex]'(?<=,DC=)(\w*)(?=($|,))').Matches($($(Get-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine' -Value 'Distinguished-Name') ))|Select-Object -ExpandProperty Value) -join '.')
            }
            Finally {
                Write-Log -Message "ReturnValue :$ReturnValue" -Source ${CmdletName}
            }
        }
        Catch {
            Write-Log -Message "Exception: '$($_.Exception.Message)'`r`nLine Number:[$($_.InvocationInfo.ScriptLineNumber)]" -Source ${CmdletName} -Severity 2;
        }
    }
    End {
        Write-Output -InputObject $ReturnValue
    }
}
Function Get-ADSiteName {
    [CmdletBinding(DefaultParameterSetName = 'ByValue')]
    [OutputType([string],ParameterSetName = 'ByValue')]
    param ()
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Log -Source ${CmdletName} -Message "Executing '${CmdletName}'...."
        [string]$ReturnValue = [string]::Empty;
    }
    Process {
        Try {
            Try {
                [System.Reflection.Assembly]::LoadWithPartialName('System.DirectoryServices.ActiveDirectory')|Out-Null;
                [string]$ReturnValue = [System.DirectoryServices.ActiveDirectory.ActiveDirectorySite]::GetComputerSite()|Select-Object -ExpandProperty 'Name' -First 1;
            }
            Catch {
                [string]$ReturnValue = $(Get-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine'  -Value 'Site-Name' -ReturnEmptyKeyIfExists -ContinueOnError $true -ErrorAction 'SilentlyContinue' | select-object -first 1)
            }
            Finally {
                Write-Log -Message "ReturnValue :$ReturnValue" -Source ${CmdletName}
            }
        }
        Catch {
            Write-Log -Message "Exception: '$($_.Exception.Message)'`r`nLine Number:[$($_.InvocationInfo.ScriptLineNumber)]" -Source ${CmdletName} -Severity 2;
        }
    }
    End {
        Write-Output -InputObject $ReturnValue
    }
}
Function Get-CMSiteCodeFromAD {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [string]$ADSite = $($GLOBAL:CCM_AD_SITE_NAME),
        
        [Parameter(Mandatory=$false)]
        [string]$IP = $($GLOBAL:CCM_NETWORK_SUBNET_ADDRESS)
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [string]$ReturnValue = [string]::Empty
    }
    Process {

            [string]$FullyQualifiedDomain =  'LDAP://' + $([System.DirectoryServices.DirectoryEntry]::new()).distinguishedName
            Write-Log -Message "FullyQualifiedDomain: $FullyQualifiedDomain" -Source ${CmdletName};
            If ( [string]::IsNullOrEmpty($FullyQualifiedDomain) ){ Throw "Fully Qualified Domain Name Is Null. CmdletMost likely would have failed due to an issue with Ssytem.DirectoryServices." }

            Try {
                If ( [string]::IsNullOrEmpty($IP) ){  
                    [string]$LDAPFilter = "(&(ObjectCategory=mSSMSSite)(mSSMSRoamingBoundaries=$($AdSite.ToUpper())))"   
                }
                ElseIf ( [string]::IsNullOrEmpty($ADSite) ){
                    [string]$LDAPFilter = "(&(ObjectCategory=mSSMSSite)(mSSMSRoamingBoundaries=$($IP.Trim())))"   
                }
                Else{
                    [string]$LDAPFilter = "(&(ObjectCategory=mSSMSSite)(|(mSSMSRoamingBoundaries=$($IP.Trim()))(mSSMSRoamingBoundaries=$($AdSite.ToUpper()))))"
                }
                Write-Log -Message "LDAPFilter: $LDAPFilter" -Source ${CmdletName};
                $Searcher = New-Object 'DirectoryServices.DirectorySearcher';
                $Searcher.Filter = $LDAPFilter;
                $Searcher.SearchRoot = "$FullyQualifiedDomain";
                [string]$Result = $Searcher.FindOne().Path
                Write-Log -Message "Result: $Result" -Source ${CmdletName};
                [string]$ReturnValue = ([regex]'(?<=(CN=SMS-Site-))(\w{3})').Matches($Result)|select -ExpandProperty value -first 1
            }
            Catch {
                Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2         
            }
            Finally {
                Remove-Variable -NAme 'Searcher' -ea SilentlyContinue -force
            }
            
    }
    End {
        Write-Output -InputObject $ReturnValue
    }
}
Function Get-CMSiteCodeFromCM {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [string]$ADSite = $($GLOBAL:CCM_AD_SITE_NAME),

        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [string]$ADDomain = $($GLOBAL:CCM_AD_DOMAIN_NAME),

        [Parameter(Mandatory=$false)]
        [string]$ADForest = $($GLOBAL:CCM_AD_FOREST_NAME),

        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [string]$StartIP = $($GLOBAL:CCM_NETWORK_START_IP),

        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [string]$EndIP = $($GLOBAL:CCM_NETWORK_END_IP),

        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [int]$StartDecimal = $($GLOBAL:CCM_NETWORK_START_IP_DECIMAL),

        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [int]$EndDecimal = $($GLOBAL:CCM_NETWORK_END_IP_DECIMAL)    
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [string]$ReturnValue = [string]::Empty
    }
    Process {
        Try {
            [string]$SystemsQuery = @"
SELECT 
	bss.SiteSystemName as 'DistributionPoint', 
    bg.DefaultSiteCode as 'SiteCode'
  FROM 
	BoundaryGroupMembers bgm
  INNER JOIN 
	vSMS_BoundaryGroup bg
  ON 
	bgm.GroupID = bg.GroupID
  INNER JOIN 
	fn_rbac_BoundarySiteSystems ('disabled') bss
  ON
	bgm.BoundaryID = bss.BoundaryID
  WHERE bgm.BoundaryID IN (SELECT bou.BoundaryID FROM BoundaryEx bou WHERE (((bou.BoundaryType = 1 AND bou.Value = '$ADSite') OR (bou.BoundaryType = 3 AND ((bou.NumericValueLow <= $StartDecimal AND bou.NumericValueHigh >= $EndDecimal) OR (bou.Value = '$StartIP-$EndIP')))) AND bou.Name LIKE '$ADForest/%'))
"@
            
            [psobject[]]$BoundaryGroups = @();
            
            Invoke-SQL -Query $SystemsQuery | Select-Object -Property "DistributionPoint","SiteCode"|%{ $BoundaryGroups += $_}
            Write-Log -Source ${CmdletName} -Message "BoundaryGroups: $($BoundaryGroups | Fl * |Out-String)."
            [string]$SetCMSiteCode = $BoundaryGroups | Group-Object -Property SiteCode | Sort-Object -Property 'Count' -Descending | Select-Object -First 1 -ExpandProperty 'Name'
            Write-Log -Source ${CmdletName} -Message "SetCMSiteCode: $($SetCMSiteCode)."
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2         
        }
        Finally {
            Remove-Variable -NAme 'Searcher' -ea SilentlyContinue -force
        }
            
    }
    End {
        Write-Output -InputObject $ReturnValue
    }
}
Function Get-CMManagementPointFromAD {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$false, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(3,3)]
        [string]$SiteCode = $GLOBAL:CCM_MP_SITECODE
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [string]$ReturnValue = [string]::Empty
    }
    Process {

            [string]$FullyQualifiedDomain =  'LDAP://' + $([System.DirectoryServices.DirectoryEntry]::new()).distinguishedName
            Write-Log -Message "FullyQualifiedDomain: $FullyQualifiedDomain" -Source ${CmdletName};
            If ( [string]::IsNullOrEmpty($FullyQualifiedDomain) ){ Throw "Fully Qualified Domain Name Is Null. CmdletMost likely would have failed due to an issue with Ssytem.DirectoryServices." }
            Try {
                [string]$LDAPFilter = "(&(ObjectCategory=mSSMSManagementPoint)(mSSMSDefaultMP=TRUE)(mSSMSSiteCode=$Sitecode))"
                Write-Log -Message "LDAPFilter: $LDAPFilter" -Source ${CmdletName};
                $Searcher = New-Object 'DirectoryServices.DirectorySearcher';
                $Searcher.Filter = $LDAPFilter;
                $Searcher.SearchRoot = "$FullyQualifiedDomain";
                [string]$Result = $Searcher.FindOne().Path
                Write-Log -Message "Result: $Result" -Source ${CmdletName};
                [string]$ReturnValue = ([regex]'(?<=-)([A-Za-z0-9\.]*)(?=.CN=)').Matches($Result)|select -ExpandProperty value -first 1
            }
            Catch {
                Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2         
            }
            Finally {
                Remove-Variable -NAme 'Searcher' -ea SilentlyContinue -force
            }
    }
    End {
        Write-Output -InputObject $ReturnValue
    }
}
Function Get-CMManagementPointFromCM {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(3,3)]
        [string]$SiteCode = $GLOBAL:CCM_MP_SITECODE
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process {
        Try  { 
            ## 1) Try to get primary boundary via AD Group
            [string]$PrimaryBoundaryQuery = @"
SELECT 
    st.ServerName as 'ManagementPoint'
FROM
    v_Site st
WHERE 
    st.SiteCode = '$($SiteCode.ToUpper())'
"@
            Write-Log -Message "PrimaryBoundaryQuery: $PrimaryBoundaryQuery" -Source ${CmdletName}
            
            [string]$ReturnValue = Invoke-SQL -Query $PrimaryBoundaryQuery|select -ExpandProperty 'ManagementPoint' -First 1
            Write-Log -Message "ReturnValue: $ReturnValue" -Source ${CmdletName}
        } 
        Catch  { 
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2 
        }     
    }
    End {
        Write-Output -InputObject $REturnValue
    }
}
#endregion [AD/CM Site Info]
##*===============================================

##*===============================================
#region [Client Functions]
Function Create-SMSCFGIniFile {
    $DObject = New-Object PSObject
    $DObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $env:ComputerName 
        Try{
            Stop-Service -Name CcmExec -ErrorAction STOP -WarningAction SilentlyContinue
            if(Get-Item "$($env:windir)\SMSCFG.ini.old" -ErrorAction SilentlyContinue){
                Remove-Item -Path "$($env:windir)\SMSCFG.ini.old"
                Rename-Item -Path "$($env:windir)\SMSCFG.ini" -NewName "SMSCFG.ini.old"
            }
            Else{
                Rename-Item -Path "$($env:windir)s\SMSCFG.ini" -NewName "SMSCFG.ini.old"
            }
            Start-Service -Name CcmExec -WarningAction SilentlyContinue
           $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value "OK" 
        }
        Catch{
           $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value $_.Exception.Message
        }
    $DObject
}
Function Set-CMClientSiteCode {
    Param(
        $SiteCode
    )
    $DObject = New-Object PSObject
    $DObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $env:ComputerName 
    Try{
        Invoke-WmiMethod -Namespace "ROOT\CCM" -Class SMS_Client -Name SetAssignedSite -ArgumentList $SiteCode -ErrorAction STOP
        $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value "OK"
    }
    Catch{
        $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value $_.Exception
    }
    $DObject
}
Function Invoke-CMClientAction {
    [CMDLetBinding()]
    PARAM(
         [Parameter(Mandatory=$True,ParameterSetName='RemoteJob')]
            $Computers,
         [Parameter(Mandatory=$False,ParameterSetName='RemoteJob')]
            $TaskScriptBlockParameters,
         [Parameter(Mandatory=$True,ParameterSetName='RemoteJob')]
         [Parameter(Mandatory=$True,ParameterSetName='LocalJob')]
            $TaskName,
         [Parameter(Mandatory=$True,ParameterSetName='RemoteJob')]
         [Parameter(Mandatory=$True,ParameterSetName='LocalJob')]
            $ScriptBlock,
         [Parameter(Mandatory=$True,ParameterSetName='RemoteJob')]
         [Parameter(Mandatory=$True,ParameterSetName='LocalJob')]
            $Reporting,
         [Parameter(Mandatory=$True,ParameterSetName='RemoteJob')]
         [Parameter(Mandatory=$True,ParameterSetName='LocalJob')]
            $OpenReport,
         [Parameter(Mandatory=$True,ParameterSetName='LocalJob')]
            $JobType,
         [Parameter(Mandatory=$True,ParameterSetName='RemoteJob')]
         [Parameter(Mandatory=$True,ParameterSetName='LocalJob')]
            $WorkerCredentials
         )

    Begin{
        [int]$ErrorCount = 0 
        [int]$SuccessCount = 0
        [int]$ContentCount = 0
        $FailedComputers = @()
        $ReportName = "$TaskName" +"_" +(Get-Random)
        $StartTime = Get-Date
        
    }
    Process{
            if($JobType -eq "Local"){
                while($Global:Queue.count -gt 0){
                    if((Get-Job -State Running).Count -lt $Global:MaxConcurrentJobs){
                        Write-Log -Message "Total Running Jobs: $((Get-Job -State Running).Count)" -severity 1 -component "Start-BackGroundJob"
                        Start-BackGroundJob -ScriptBlock $ScriptBlock -WorkerCredentials $WorkerCredentials
                    }

                }
                while((Get-Job).State -eq "Running"){
                       Write-Log -Message "Waiting for local Jobs. Still Jobs in Queue list: $($Global:Queue.Count)" -severity 1 -component "Invoke-CMClientAction"
                       Start-Sleep 1
                }
            }
            Else{

                Try{
                    $MainJob = Invoke-Command -ScriptBlock $ScriptBlock -ComputerName $Computers -AsJob -ErrorAction STOP -ThrottleLimit 10 -ArgumentList $TaskScriptBlockParameters @WorkerCredentials
                    foreach ($job in $MainJob.ChildJobs){
                     $Global:Jobs.Add($Job.Id)
                     Write-Log -Message "Adding $($Job.Location) PSH JOB" -severity 1 -component "Invoke-CMClientAction"
                    }

                }
                Catch{
                    Write-Log -Message $_.Exception.Message -severity 3 -component "Invoke-CMClientAction"
                    Write-Log -Message "Error in line: $($_.InvocationInfo.ScriptLineNumber)" -component "Invoke-CMClientAction" -severity 3
                    
                }
        }
    }
    End{

        While($Global:Jobs.Count -ne 0){
            if($Global:Jobs.Count -ne $null){
                $RemoveJobID = @()
                foreach($JOB in $Global:Jobs){
                    $JobInfo = Get-Job -ID $JOB
                   
                    if($JobInfo.State -eq "Failed"){
                         Write-Log -Message "$TaskName failed on $($JobInfo.Location) with error $($JobInfo.JobStateInfo.Reason.Message.ToString())" -severity 3 -component "Invoke-CMClientAction"
                         Write-Log -Message "Removing JOB ID: $JOB from the array" -severity 2 -component "Invoke-CMClientAction"
                         $FailedComputers += $JobInfo
                         $RemoveJobID += ,$JOB
                         $ErrorCount++         
                    }
                    if($JobInfo.State -eq "Completed"){
                         If($JobType -eq "Local"){
                            Write-Log -Message "$TaskName Completed on $($JobInfo.Name)" -severity 1 -component "Invoke-CMClientAction"
                         }
                         Else{
                            Write-Log -Message "$TaskName Completed on $($JobInfo.Location)" -severity 1 -component "Invoke-CMClientAction"
                         }
                            Write-Log -Message "Removing JOB ID: $JOB from the array" -severity 2 -component "Invoke-CMClientAction"
                         
                             if($Reporting -eq "True"){
                                $JobData = Receive-Job -Id $JOB
                                If([System.String]::IsNullOrEmpty($JobData)){
                                    Write-Log -Message "**** --- No result from query --- ****" -severity 1 -component "Invoke-CMClientAction"
                                }
                                Else{
                                    $ContentCount++
                                    Export-Content -ContentObject $JobData -ContentFileName $ReportName
                                }
                                
                             }

                         $RemoveJobID += ,$JOB
                         $SuccessCount++
                    }
                
                }
                foreach ($Id in $RemoveJobID){
                    $Global:Jobs.Remove($ID)
                }

            }
  
            Start-sleep 1
        }

        Write-Log -Message "-------------------------------------------------------------------------------" -severity 1 -component "Invoke-CMClientAction"
        Write-Log -Message "TOTAL FAILED JOBS: $ErrorCount" -severity 1 -component "Invoke-CMClientAction"
        Write-Log -Message "TOTAL SUCCESS JOBS: $SuccessCount" -severity 1 -component "Invoke-CMClientAction"
        
        If($SuccessCount -ne 0 -and $ContentCount -gt 0){
            $ReportLocation = "$Global:PATH\Reports\$ReportName.csv"
            Write-Log -Message "Please check the following report: $ReportName" -severity 1 -component "Invoke-CMClientAction"
            Write-Log -Message "Report location: ""$ReportLocation""" -severity 1 -component "Open-Report"
        }
        If($ErrorCount -ne 0){
            Write-Log -Message "Please check the failed computers report: $Global:PATH\Reports\FailedComputers_$ReportName.CSV" -severity 1 -component "Invoke-CMClientAction"
            Save-FailedComputers -FailedComputersInfo $FailedComputers -Path "$Global:PATH\Reports\FailedComputers_$ReportName.CSV"
        }

        #Get the end time and calculate total run time
        $EndTime = (Get-Date) - $StartTime
        Write-Log -Message "TOTAL TIME: $($EndTime.TotalMinutes) minutes" -severity 1 -component "Invoke-CMClientAction"

        #Reset to default state Start Button and Worker running state
        $UserInterFace.Btn_START.Dispatcher.Invoke("Normal",[Action]{
            $UserInterFace.WorkerRunning = $False
            $UserInterFace.Btn_START.Content = "Start"
            $UserInterFace.Btn_START.IsEnabled = $True
        })

        #STOP All actions and clean up
        Remove-Job * -Force
        Start-Sleep -Seconds 1
        If($OpenReport -and $SuccessCount -gt 0 -and $ContentCount -gt 0){
            Open-Report -ReportName $ReportName
        }
    }
}
Function Invoke-ClientSchedule {
    Param($X)
    
    $DObject = New-Object PSObject
    $DObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $env:ComputerName       
        Try{
            $Command = Invoke-WmiMethod -Namespace root\CCM -Class SMS_Client -Name TriggerSchedule -ArgumentList "{$X}" -ErrorAction STOP
            $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value "Success"
        }
        Catch{
             $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value $_.Exception.Message
        }
    $DObject
}
Function Get-CMClientManagementPoint {
    $DObject = New-Object PSObject
    $DObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $env:ComputerName   
    Try{
        $MpQuery = Get-WmiObject -Namespace "Root\CCM" -Class SMS_Authority
        $DObject | Add-Member -MemberType NoteProperty -Name "ManagementPoint" -Value $MpQuery.CurrentManagementPoint
    }
    Catch{
        $DObject | Add-Member -MemberType NoteProperty -Name "ManagementPoint" -Value $_.Exception.Message
    }
    $DObject
}
Function Start-CMClientRepair {
    Try{
        Invoke-WmiMethod -Namespace "Root\CCM" -Class SMS_Client -Name RepairClient
    }
    Catch{
        $_.Exception.Message
    }
}
Function Reset-CMClientPolicy {
    Try{
        Invoke-WmiMethod -Namespace "Root\CCM" -Class SMS_Client -Name ResetPolicy -ArgumentList 1
    }
    Catch{
        $_.Exception.Message
    }
}
Function Get-CMClientInventoryActions {
    $DObject = New-Object PSObject
    $DObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $env:ComputerName 
    Try{
        #Hardware Inventory Date
        $HW = Get-WmiObject -NameSpace "ROOT\CCM\INVAGT" -Class InventoryActionStatus -Filter "InventoryActionID='{00000000-0000-0000-0000-000000000001}'" -ErrorAction STOP
        $DObject | Add-Member -MemberType NoteProperty -Name "Hardware Inventory Date" -Value $HW.ConvertToDateTime($HW.LastCycleStartedDate) 
    }
    Catch{
        $DObject | Add-Member -MemberType NoteProperty -Name "Hardware Inventory Date" -Value $_.Exception.Message
    }

    Try{
        #Software Inventory Date
        $SW = Get-WmiObject -NameSpace "ROOT\CCM\INVAGT" -Class InventoryActionStatus -Filter "InventoryActionID='{00000000-0000-0000-0000-000000000002}'" -ErrorAction STOP
        $DObject | Add-Member -MemberType NoteProperty -Name "Software Inventory Date" -Value $SW.ConvertToDateTime($SW.LastCycleStartedDate)
    }
    Catch{
        $DObject | Add-Member -MemberType NoteProperty -Name "Software Inventory Date" -Value $_.Exception.Message
    }
    $DObject
}
Function Get-CMClientCacheInformation {
    $DObject = New-Object PSObject
    $DObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $env:ComputerName 
    Try{
        $CMObject = New-Object -ComObject "UIResource.UIResourceMgr" -ErrorAction STOP
        $CMCacheObject = $CMObject.GetCacheInfo()
        $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value "OK"
        $DObject | Add-Member -MemberType NoteProperty -Name "Location" -Value $CMCacheObject.Location
        $DObject | Add-Member -MemberType NoteProperty -Name "Size" -Value $CMCacheObject.TotalSize
        $DObject | Add-Member -MemberType NoteProperty -Name "FreeSpace" -Value $CMCacheObject.FreeSize
        [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($CMObject)
    }
    Catch{
        $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value $_.Exception.Message
        $DObject | Add-Member -MemberType NoteProperty -Name "Location" -Value "N/A"
        $DObject | Add-Member -MemberType NoteProperty -Name "Size" -Value "N/A"
        $DObject | Add-Member -MemberType NoteProperty -Name "FreeSpace" -Value "N/A"
    }
    $DObject
}

Function Set-CMClientCacheSize{
     Param(
         [int]$CacheSize
        )
    
    #Query Cache size
    Try{
        $CacheQuery = Get-WmiObject -Namespace ROOT\CCM\SoftMgmtAgent -Class CacheConfig -ErrorAction STOP
        $CacheQuery.Size = $CacheSize
        [Void]$CacheQuery.Put()
        Try{
            #Restart CcmExec service
            Restart-Service -Name CcmExec -ErrorAction STOP -Force -WarningAction SilentlyContinue
        }
        Catch{
            $_.Exception.Message
        }
    }
    Catch{
            $_.Exception.Message
    }
}
Function Get-WMIRepositoryState{
    $DObject = New-Object PSObject
    $DObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $env:ComputerName 

    Try{
    #Verify WMI Repository
    $Command = Invoke-Expression "$($env:windir)\System32\Wbem\winmgmt.exe /verifyrepository" -ErrorAction STOP
       $DObject | Add-Member -MemberType NoteProperty -Name "RepositoryState" -Value $Command
    }
    Catch{
       $DObject | Add-Member -MemberType NoteProperty -Name "RepositoryState" -Value $_.Exception.Message  
    }

    $DObject
}
Function Get-CMClientWSUSContentLocation {
    $DObject = New-Object PSObject
    $DObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $env:ComputerName  
        Try{
            $WUA = Get-WmiObject -Namespace "Root\CCM\SoftwareUpdates\WUAHandler" -Class CCM_UpdateSource -ErrorAction STOP
            $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value "OK"
            $DObject | Add-Member -MemberType NoteProperty -Name "ContentLocation" -Value $WUA.ContentLocation
            $DObject | Add-Member -MemberType NoteProperty -Name "ContentVersion" -Value $WUA.ContentVersion
        }
        Catch{
            Try{
                $WUA = Get-ItemProperty "HKLM:SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -ErrorAction STOP
                if($WUA.WUServer.Length -eq 0){
                    $WuServer = "No Server"
                }
                Else{
                    $WuServer = $WUA.WUServer
                }
                $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value "OK"
                $DObject | Add-Member -MemberType NoteProperty -Name "ContentLocation" -Value $WuServer
                $DObject | Add-Member -MemberType NoteProperty -Name "ContentVersion" -Value "N/A"
            }
            Catch{
                    $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value $_.Exception.Message
                    $DObject | Add-Member -MemberType NoteProperty -Name "ContentLocation" -Value "N/A"
                    $DObject | Add-Member -MemberType NoteProperty -Name "ContentVersion" -Value "N/A"
            }
            $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value $_.Exception.Message
            $DObject | Add-Member -MemberType NoteProperty -Name "ContentLocation" -Value "N/A"
            $DObject | Add-Member -MemberType NoteProperty -Name "ContentVersion" -Value "N/A"
        }
    $DObject
}
Function Get-CMClientMissingUpdates {
    $MissingUpdates = @()
    Try{
        $MissingUpdatesQuery = Get-WmiObject -Query "SELECT * FROM CCM_SoftwareUpdate" -Namespace "ROOT\ccm\ClientSDK" -ErrorAction STOP
        If(($MissingUpdatesQuery | Measure-Object | Select-Object -ExpandProperty Count) -ne 0){
            foreach($item in $MissingUpdatesQuery){
                $DObject = New-Object PSObject                    $DObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $env:ComputerName 
                    $DObject | Add-Member -MemberType NoteProperty -Name "Name" -Value $item.Name
                    $DObject | Add-Member -MemberType NoteProperty -Name "ArticleID" -Value $item.ArticleID
                    $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value "OK"
                $MissingUpdates += $DObject
            }
        }
    }
    Catch{
                $DObject = New-Object PSObject                    $DObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $env:ComputerName 
                    $DObject | Add-Member -MemberType NoteProperty -Name "Name" -Value "N/A"
                    $DObject | Add-Member -MemberType NoteProperty -Name "ArticleID" -Value "N/A"
                    $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value $_.Exception.Message
                $MissingUpdates += $DObject        
    }
    $MissingUpdates
}
Function Get-CMClientWUAVersion {
    $DObject = New-Object PSObject
    $DObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $env:ComputerName  
    Try{
        $WUAgent = Get-WmiObject -Namespace "Root\Cimv2\SMS" -Class Win32_WindowsUpdateAgentVersion -ErrorAction STOP
        $DObject | Add-Member -MemberType NoteProperty -Name "WUAVersion" -Value $WUAgent.Version
    }
    Catch{
        
        Try{
            $WUAgent = (Get-Item "$env:windir\System32\wuapi.dll" -ErrorAction STOP).VersionInfo.ProductVersion
            $DObject | Add-Member -MemberType NoteProperty -Name "WUAVersion" -Value $WUAgent
        }
        Catch{
            $DObject | Add-Member -MemberType NoteProperty -Name "WUAVersion" -Value $_.Exception.Message
        }
        $DObject | Add-Member -MemberType NoteProperty -Name "WUAVersion" -Value $_.Exception.Message
    }
    $DObject
}
Function Invoke-WMIStateCheck{
    #Stop Services
    Stop-Service -Name Winmgmt -Force -WarningAction SilentlyContinue
    Set-Location "$($env:windir)\System32\wbem"
    #Register DLL Files
    foreach($DLL in (Get-ChildItem -Filter *.dll)){
       regsvr32.exe -S $DLL.Name
    }
    #Check SysWOW64
    if((Test-Path "$($env:windir)\SysWOW64\wbem")){
       Set-Location "$($env:windir)\SysWOW64\wbem"
       #Register DLL Files
       foreach($DLL in (Get-ChildItem -Filter *.dll)){
          regsvr32.exe -S $DLL.Name
       }
    }
    #Reset WMI Repository
    Invoke-Expression "$($env:windir)\System32\Wbem\winmgmt.exe /resetrepository"
    #Start Services
    Start-Service -Name Winmgmt -WarningAction SilentlyContinue
    Start-Service -Name CcmExec -WarningAction SilentlyContinue
}
Function Install-CMClientMissingUpdates {
    Try{
    $MissingUpdatesQuery = Get-WmiObject -Query "SELECT * FROM CCM_SoftwareUpdate" -Namespace "ROOT\ccm\ClientSDK" -ErrorAction STOP
        If(($MissingUpdatesQuery | Measure-Object | Select-Object -ExpandProperty Count) -ne 0){
            Try{
                foreach($item in $MissingUpdatesQuery){
                    Invoke-WmiMethod -Namespace "Root\CCM\ClientSDK" -Class CCM_SoftwareUpdatesManager -Name InstallUpdates -ArgumentList $item
                }
            }
            Catch{
                $_.Exception.Message
            }
        }
    }
    Catch{
        $_.Exception.Message
    }
}

Function Get-WindowsUpdateStatus {
    Param([String[]]$KBArticles)

    $InstalledUpdates = @()
    $i=0
    $KBArticles = $KBArticles.Split(",") | ForEach-Object {$_}
    foreach($item in $KBArticles){

                $DObject = New-Object PSObject
                $DObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $env:ComputerName
        Try{
            $KBQuery = Get-WmiObject -Namespace "Root\Cimv2" -Class Win32_QuickFixEngineering -Filter "HotFixID like '%$item%'" -ErrorAction STOP
            IF(($KBQuery | Measure-Object | Select-Object -ExpandProperty Count) -ne 0){
                $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value "Installed"
                $DObject | Add-Member -MemberType NoteProperty -Name "HotFixID" -Value $KBQuery.HotFixID
                $DObject | Add-Member -MemberType NoteProperty -Name "InstalledOn" -Value $KBQuery.InstalledOn
                $DObject | Add-Member -MemberType NoteProperty -Name "InstalledBy" -Value $KBQuery.InstalledBy
            }
            Else{
                $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value "Not Installed"
                $DObject | Add-Member -MemberType NoteProperty -Name "HotFixID" -Value $item
                $DObject | Add-Member -MemberType NoteProperty -Name "InstalledOn" -Value "N/A"
                $DObject | Add-Member -MemberType NoteProperty -Name "InstalledBy" -Value "N/A"
            }
        }
        Catch{
                $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value $_.Exception.Message
                $DObject | Add-Member -MemberType NoteProperty -Name "HotFixID" -Value $item
                $DObject | Add-Member -MemberType NoteProperty -Name "InstalledOn" -Value "N/A"
                $DObject | Add-Member -MemberType NoteProperty -Name "InstalledBy" -Value "N/A"
        }
    $InstalledUpdates += $DObject
    }
    $InstalledUpdates
}
Function Get-FreeDiskSpace {
    Param($X)

    $DisksArray = @()
    Try{
        $DisksQuery = Get-WmiObject -Class Win32_Volume -ErrorAction STOP -Filter "DriveType=3" -ComputerName $X
        foreach($item in $DisksQuery){
            $DObject = New-Object PSObject
                $DObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $X
                $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value "OK"
                $DObject | Add-Member -MemberType NoteProperty -Name "DriveLetter" -Value $item.DriveLetter
                $DObject | Add-Member -MemberType NoteProperty -Name "Label" -Value $item.Label
                $DObject | Add-Member -MemberType NoteProperty -Name "FreeSpace" -Value ($item.FreeSpace /1GB)
            $DisksArray += $DObject
        }
    }
    Catch{
         $DObject = New-Object PSObject
            $DObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $X
            $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value $_.Exception.Message
            $DObject | Add-Member -MemberType NoteProperty -Name "DriveLetter" -Value "N/A"
            $DObject | Add-Member -MemberType NoteProperty -Name "Label" -Value "N/A"
            $DObject | Add-Member -MemberType NoteProperty -Name "FreeSpace" -Value "N/A"
        $DisksArray += $DObject
    }
    $DisksArray
}
Function Restart-CMClientComputer {
    Param($ComputerName)
    Restart-Computer -Force -ComputerName $ComputerName -WarningAction SilentlyContinue
}
Function Get-ConfigMgrClientAvailableApps {
    Param($X)

    $AppsAr = @()
    Try{
    $AvailableApps = Get-WmiObject -Namespace "ROOT\CCM\ClientSDK" -Class CCM_Application -ComputerName $X -ErrorAction STOP
        foreach($item in $AvailableApps){
           $DObject = New-Object PSObject
           $DObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $X
           $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value "OK"
           $DObject | Add-Member -MemberType NoteProperty -Name "FullName" -Value $item.FullName
           $DObject | Add-Member -MemberType NoteProperty -Name "Id" -Value $item.ID
           $DObject | Add-Member -MemberType NoteProperty -Name "ApplicabilityState" -Value $item.ApplicabilityState
           $DObject | Add-Member -MemberType NoteProperty -Name "InstallState" -Value $item.InstallState
           $DObject | Add-Member -MemberType NoteProperty -Name "Revision" -Value $item.Revision
           $DObject | Add-Member -MemberType NoteProperty -Name "IsMachineTarget" -Value $item.IsMachineTarget
           $DObject | Add-Member -MemberType NoteProperty -Name "EnforcePreference" -Value $item.EnforcePreference
           $AppsAr += $DObject
        }
    }
    Catch{
           $DObject = New-Object PSObject
           $DObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $X
           $DObject | Add-Member -MemberType NoteProperty -Name "Status" -Value $_.Exception.Message
           $DObject | Add-Member -MemberType NoteProperty -Name "FullName" -Value "N/A"
           $DObject | Add-Member -MemberType NoteProperty -Name "Id" -Value "N/A"
           $DObject | Add-Member -MemberType NoteProperty -Name "ApplicabilityState" -Value "N/A"
           $DObject | Add-Member -MemberType NoteProperty -Name "InstallState" -Value "N/A"
           $DObject | Add-Member -MemberType NoteProperty -Name "Revision" -Value "N/A"
           $DObject | Add-Member -MemberType NoteProperty -Name "IsMachineTarget" -Value "N/A"
           $DObject | Add-Member -MemberType NoteProperty -Name "EnforcePreference" -Value "N/A"
           $AppsAr += $DObject
    }
    $AppsAr
}
Function Get-ComputerUpTime {
    $DObject = New-Object PSObject
    $DObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $env:ComputerName 
    Try{
        $BootTime = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction STOP
        $LastBootUpTime = $BootTime.ConvertToDateTime($BootTime.LastBootUpTime)
        $DObject | Add-Member -MemberType NoteProperty -Name "LastBootUpTime" -Value $LastBootUpTime
        $DObject | Add-Member -MemberType NoteProperty -Name "Days" -Value (((Get-Date) - (Get-Date $LastBootUpTime)).Days)
        $DObject | Add-Member -MemberType NoteProperty -Name "Hours" -Value (((Get-Date) - (Get-Date $LastBootUpTime)).Hours)
    }
    Catch{
        $DObject | Add-Member -MemberType NoteProperty -Name "LastBootUpTime" -Value "N/A"
        $DObject | Add-Member -MemberType NoteProperty -Name "Days" -Value "N/A"
        $DObject | Add-Member -MemberType NoteProperty -Name "Hours" -Value "N/A"
    }
    $DObject
}
Function Get-ComputerAppliedPolicies {
    $GPOPolicies = @()
    Try{
    $GPOQuery = Get-WmiObject -Namespace "ROOT\RSOP\Computer" -Class RSOP_GPLink -Filter "AppliedOrder <> 0" -ErrorAction STOP | ForEach-Object {$_.GPO.ToString().Replace("RSOP_GPO.","")}
        foreach($GP in $GPOQuery){
            $AppliedPolicy = Get-WmiObject -Namespace "ROOT\RSOP\Computer" -Class RSOP_GPO -Filter $GP
                $DObject = New-Object PSObject
                $DObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $env:ComputerName
                $DObject | Add-Member -MemberType NoteProperty -Name "Name" -Value $AppliedPolicy.Name
                $DObject | Add-Member -MemberType NoteProperty -Name "GuidName" -Value $AppliedPolicy.GuidName
                $DObject | Add-Member -MemberType NoteProperty -Name "ID" -Value $AppliedPolicy.ID
                $GPOPolicies += $DObject
        }
    }
    Catch{
        $DObject = New-Object PSObject
                $DObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $env:ComputerName
                $DObject | Add-Member -MemberType NoteProperty -Name "Name" -Value "N/A"
                $DObject | Add-Member -MemberType NoteProperty -Name "GuidName" -Value "N/A"
                $DObject | Add-Member -MemberType NoteProperty -Name "ID" -Value "N/A"
                $GPOPolicies += $DObject
    }
    $GPOPolicies
}
Function Start-CMToolAction {
     PARAM(
          $ScriptBlockName,
          $TaskName,
          $Computers,
          $Reporting,
          $TaskScriptBlockParameters,
          $OpenReport,
          $JobType,
          $WorkerCredentials
          )

    Remove-Job * -Force
    Write-Log -Message "Starting to run $TaskName" -severity 1 -component "Start-CMToolAction"
    $Global:Jobs = [system.collections.arraylist]::Synchronized((New-Object System.Collections.ArrayList))

    Try{
        $WorkerFunction = (Get-ChildItem "Function:$ScriptBlockName" -ErrorAction STOP) | Select-Object -ExpandProperty Definition
        $FunctionTOScriptBlock = [System.Management.Automation.ScriptBlock]::Create($WorkerFunction)   
        
           If($JobType -eq "Local"){
                Write-Log -Message "Job Type: Local Remote Jobs" -severity 1 -component "Start-CMToolAction"
                Write-Log -Message "Please wait - generating new Jobs" -severity 1 -component "Start-CMToolAction"
                $Global:MaxConcurrentJobs = 10
                $Global:Queue = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))
                $Computers | ForEach-Object {$Global:Queue.Enqueue($_)}
                If($Global:Queue.count -lt $MaxConcurrentJobs) {
                    $Global:MaxConcurrentJobs = $Global:Queue.count
                }
                for( $i = 0; $i -lt $Global:MaxConcurrentJobs; $i++ ){
                    Start-BackGroundJob -ScriptBlock $FunctionTOScriptBlock -WorkerCredentials $WorkerCredentials
                }
                Invoke-CMClientAction -TaskName $TaskName -Reporting $Reporting -OpenReport $OpenReport -JobType $JobType -ScriptBlock $FunctionTOScriptBlock -WorkerCredentials $WorkerCredentials
            }
            Else{
                Write-Log -Message "Job Type: Remote" -severity 1 -component "Start-CMToolAction"
                Write-Log -Message "Total computers: $($Computers.Count)" -severity 1 -component "Start-CMToolAction" -noScreen
                Invoke-CMClientAction -Computers $Computers -TaskName $TaskName -ScriptBlock $FunctionTOScriptBlock -Reporting $Reporting -TaskScriptBlockParameters $TaskScriptBlockParameters -OpenReport $OpenReport -WorkerCredentials $WorkerCredentials
            } 
    }
    Catch{
        Get-ErrorInformation -Component "Start-CMToolAction"
        #Reset to default state Start Button and Worker running state
        $UserInterFace.Btn_START.Dispatcher.Invoke("Normal",[Action]{
            $UserInterFace.WorkerRunning = $False
            $UserInterFace.Btn_START.Content = "Start"
            $UserInterFace.Btn_START.IsEnabled = $True
        })
    }
    
}
#endregion [Client Functions]
##*===============================================

##*===============================================
#region [Disk Functions]
Function Clear-CMCache {
    [CmdletBinding()]
    param(
        [int]$AgeDays = 7
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [bool]$ReturnValue = $false;
    }
    Process {
        Try {
            ##################################################
            ## Method #1
            Try {
                $CMObject = New-Object -ComObject "UIResource.UIResourceMgr"        
                $CMCacheObjects = $CMObject.GetCacheInfo()
                $CMCacheObjects.GetCacheElements() | Foreach-Object {
                
                    [string]$ElementId = $_.CacheElementId;
                    Write-Log -Message "ElementId: $ElementId" -Source ${CmdletName}

                    [string]$ElementLocation = $_.Location;
                    Write-Log -Message "ElementLocation: $ElementLocation" -Source ${CmdletName}

                    If ( ![string]::IsNullOrEmpty($ElementId) ) {
                        $CMCacheObjects.DeleteCacheElement($ElementId);
                        Write-Log -Message "Removed Cache Element: $ElementID." -Source ${CmdletName}
                    }
                    Else {
                        Write-Log -Message "Cache Element Is Null." -Source ${CmdletName}
                    }

                    If ( ![string]::IsNullOrEmpty($ElementLocation) ) {
                        If ( Test-Path -Path $ElementLocation ) {
                            Remove-Folder -Path $ElementLocation -ContinueOnError $true -ErrorAction 'SilentlyContinue';
                            Write-Log -Message "Removed Cache Location: $ElementLocation." -Source ${CmdletName};
                        }
                        Else {
                            Write-Log -Message "Location '$ElementLocation' Does Not Exist." -Source ${CmdletName}
                        }
                    }
                    Else {
                        Write-Log -Message "Location Is Null Or Empty." -Source ${CmdletName}
                    }
                    Remove-Variable -Name 'ElementId','ElementLocation' -Force -ErrorAction 'SilentlyContinue'
                }
            }
            Catch {
                Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
            }
            ##################################################
            ## Method #2
            Try {
                [string]$Cachepath = ([wmi]"ROOT\ccm\SoftMgmtAgent:CacheConfig.ConfigKey='Cache'").Location
                If ( [string]::IsNullOrEmpty($Cachepath) ){
                    [string]$CachePath = Join-Path -Path $env:Windir -ChildPath 'ccmcache'
                }
                Write-Log -Message "Cachepath: $Cachepath" -Source ${CmdletName}
                Try {
                    $OldCache = Get-WMIObject -Query "SELECT * FROM CacheInfoEx" -namespace "ROOT\ccm\SoftMgmtAgent"; 
                    $OldCache | Remove-WmiObject -ErrorAction 'SilentlyContinue'
                } Catch {
                    Write-Log -Message "Attempt at Removing any Existing WMI Objects was unsuccessful." -Source ${CmdletName}    
                }
            }
            Catch {
                Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
            }
            ##################################################
            ## Clear Nomad Cache
            Try {
                Clear-CMNomadCache;
            }
            Catch {
                Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
            }
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
}
Function Start-DiskCleanupUtility {
    [cmdletbinding()]
    Param([switch]$NoWait)
    Begin
    {
        [string]${CmdletSection} = 'Begin'
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [string]${ValueNAme} = 'StateFlags0099';  
        [int]${ValueData} = 2;
        [string]$RegPath="HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
    }
    Process
    {
        [string]${CmdletSection} = 'Process'
        try 
        {
            # Create reg keys
            Get-ChildItem -Path $RegPath | %{ 
                Set-RegistryKey -Key $_.Name -Name ${ValueNAme} -Value ${ValueData} -Type 'DWord' -ContinueOnError $true
            }
            

            [hashtable]$Params = @{
                Path="$env:SystemRoot\System32\cleanmgr.exe";
                Parameters=@('/sagerun:99');
                CreateNoWindow=[switch]::Present;
                ContinueOnError=$true;
            }

            #PassThru=[switch]::Present;
            # Run Disk Cleanup 
            If ( $NoWait ) {$Params.Add('NoWait',[switch]::Present)}
            Else {$Params.Add('PassThru',[switch]::Present)} 
            Execute-Process @Params

            # Delete the keys
            Get-ChildItem $RegPath  | %{ 
                Remove-RegistryKey -Key $_.Name -Name ${ValueNAme} -ContinueOnError $true;
            }
        } 
        catch 
        {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        } 
    }
}
Function Get-AvailableDiskSpace {
	[CmdletBinding()]
    [OutputType([psobject])]
	Param (
	)
	
	Begin  {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [psobject]$ReturnValue = New-Object -TypeName PSobject;
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process  {
		Try  {
            [psobject]$ReturnValue = Get-PSDrive $($Env:SystemDrive.TrimEnd(':')) | Select-Object Used,Free
            $ReturnValue|Add-Member -MemberType NoteProperty -Name 'Total' -Value ($ReturnValue.Used + $ReturnValue.Free) -Force;
            $ReturnValue|Add-Member -MemberType NoteProperty -Name 'PercentUsed' -Value $([math]::Round($($ReturnValue.Used/($ReturnValue.Used + $ReturnValue.Free))*100,0)) -Force;
            $ReturnValue|Add-Member -MemberType NoteProperty -Name 'PercentFree' -Value $([math]::Round($($ReturnValue.Free/($ReturnValue.Used + $ReturnValue.Free))*100,0)) -Force;
		}
		Catch  {
			Write-Log -Message "Exception: $($_.Exception.Message)`n$(Resolve-Error)" -Severity 2 -Source ${CmdletName}
		}
	}
	End  {
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
        Write-Output -InputObject $($ReturnValue)
	}
}
#endregion [Client Disk Space]
##*===============================================

##*===============================================
#region [Test]
function Test-ClientDiskSpace{
    [CmdletBinding()]
    param(
        [double]$Threshold = $GLOBAL:CCM_MINIMUM_DISKSPACE_MB
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [bool]$ReturnValue = $false;
    }
    Process {
        Try {
            
            [double]$FreeMegaBytes = [Math]::Round($(Get-AvailableDiskSpace|select -ExpandProperty Free)/1MB)
            Write-Log -Message "FreeMegaBytes: $($FreeMegaBytes)" -Source ${CmdletName}

            [bool]$ReturnValue = $FreeMegaBytes -ge $Threshold
            Write-Log -Message "ReturnValue: $($ReturnValue)" -Source ${CmdletName}
        }
        Catch
        {
            Write-Log -Message "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
    End
    {
        Write-Output -InputObject ($ReturnValue)
    } 
}
function Test-ClientAdminShare {
    [CmdletBinding()]
    [OutputType([bool])]
    Param()
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [bool]$ReturnValue=$false
      
    }
    Process {
        Try  { 
            $AdminShareQuery = Get-SmbShare -Name 'ADMIN$' -ErrorAction Stop
            [bool]$ReturnValue=($AdminShareQuery | Measure-Object | Select-Object -ExpandProperty Count) -eq 1
        } 
        Catch  { 
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2 
        }     
    }
    End {
        Write-Output -InputObject $REturnValue
    }
}
function Test-ClientCache {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [int]$AgeDays = 7
    )
    Begin
    {

        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [bool]$ReturnValue = $false;
    }
    Process
    {
        Try
        {
            
        }
        Catch
        {
            [bool]$ReturnValue = $false;
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
    End
    {
        Write-Output -InputObject $ReturnValue
    }
}
function Test-ClientTaskScheduler {
    [CmdletBinding()]
    [OutputType([bool])]
    Param()
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [bool]$ReturnValue=$false
        [string]$ConfirmFile = Join-Path -Path $env:temp -ChildPath "TestTaskOutput.txt";
        [string]$TaskDefFile = Join-Path -Path $env:temp -ChildPath "TestTask.xml";
        Remove-File -Path $ConfirmFile -ContinueOnError $true -Ea SilentlyContinue;
    }
    Process {
        Try  { 
            [string]$TaskXmlDef = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>2017-08-07T12:52:00.2971476</Date>
    <Author>$envUserdomain\$envUserName</Author>
    <URI>\Test Task Scheduler</URI>
  </RegistrationInfo>
  <Triggers />
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe</Command>
      <Arguments>-ExecutionPolicy ByPass -NoLogo -WindowStyle Hidden -Command "'PS' | out-file -filepath '$ConfirmFile' -force -encoding ascii"</Arguments>
    </Exec>
  </Actions>
</Task>            
"@            
            $TaskXmlDef | Out-File -FilePath $TaskDefFile -Force -Encoding Ascii;
            Execute-SchTasks -Arguments "/Create /TN `"\Test Task Scheduler`" /XML `"$($TaskDefFile)`" /F"|out-null;
            Write-Log -Message "Created Task. ($?)" -Source ${CmdletName}
            Write-Log -Message "Executing Task...." -Source ${CmdletName}
            Execute-SchTasks -Arguments "/Run /I /TN `"\Test Task Scheduler`"";
            Write-Log -Message "Finished Task. ($?)" -Source ${CmdletName}
            Write-Log -Message "Wait 15 Seconds..." -Source ${CmdletName}
            Start-Sleep -Seconds 15
            If ( -not (Test-Path -Path $ConfirmFile) ) {
                Throw "File Does Not Exist. Task Scheduler Failed."
            }
            If ( [string]::IsNullOrEmpty($(Gc $ConfirmFile)) ){
                Throw "File Content Is Null."
            }
            $ReturnValue = $true;
        } 
        Catch  { 
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2 
        }     
    }
    End {
        Remove-File -Path $TaskDefFile -ContinueOnError $true;
        Remove-File -Path $ConfirmFile -ContinueOnError $true;
        Remove-ScheduledTask -Path "\Test Task Scheduler" -Verbose
        Write-Output -InputObject $REturnValue
    }
}
function Test-ClientHostNamespace {
    [CmdletBinding()]
    [OutputType([bool])]
    Param()
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [bool]$ReturnValue=$false
        #Get-WMINameSpace -Name 'ccm' -Root 'root'
    }
    Process {
        Try  { 
            [string]$CCMNamepsaceReturn = Get-WMINameSpace -Name 'ccm' -Root 'root' -Ea SilentlyContinue | Select -Ea SilentlyContinue -ExpandProperty 'Name' -First 1
            Write-Log -Source ${CmdletName} -Message "CCMNamepsaceReturn:$CCMNamepsaceReturn"
            $ReturnValue = ![string]::IsNullOrEmpty($CCMNamepsaceReturn);
        } 
        Catch  { 
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2 
        }     
    }
    End {
        Write-Output -InputObject $REturnValue
    }
}
function Test-ClientService {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Running','Stopped',IgnoreCase=$true)]
        [string]$State,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Automatic','Automatic (Delayed Start)','Disabled','Manual',IgnoreCase=$true)]
        [string]$StartMode,

        [Parameter(Mandatory=$false)]
        [switch]$Enforce = $false
    )
    Begin
    {

        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [bool]$ReturnValue = $false;
        Write-Log -Message "Name: $Name" -Source ${CmdletName}
    }
    Process
    {
        Try {                
            [string]$CurrentStartMode = Get-ServiceStartMode -Name $Name;
            Write-Log -Message "CurrentStartMode: $CurrentStartMode" -Source ${CmdletName}

            [string]$CurrentState = Get-Service -Name $Name -Ea SilentlyContinue| Select -ExpandProperty 'State' -First 1 -Ea SilentlyContinue;
            Write-Log -Message "CurrentState: $CurrentState" -Source ${CmdletName}

            If ( ($CurrentStartMode -notmatch $StartMode) -or ($currentState -notmatch $State )) {
                If ( $Enforce ) {
                    Remediate-ClientService -Name $Name -State $State -StartMode $StartMode
                }
                Else {
                    Write-Output -InputObject $False
                }
            }
            Else {
                Write-Output -InputObject $True
            }    
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
}
function Test-ClientHostService {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$Name = 'ccmexec'
    )
    Begin
    {

        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [bool]$ReturnValue = $false;
    }
    Process
    {
        Try {                
            [string]$ServiceQuery = Invoke-Expression -Command "sc query ccmexec" | Out-String;
            Write-Log -Message "ServiceQuery: $ServiceQuery" -Source ${CmdletName}

            $ReturnValue = ![string]::IsNullOrEmpty($ServiceQuery);
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
    End {
        Write-Output -InputObject $ReturnValue
    }
}
function Test-ClientOperatingSystem {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [double]$MinimumVersion = $($GLOBAL:CCM_MINIMUM_OS_VERSION)
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [bool]$ReturnValue = $false;
    }
    Process {
        Try {                
            [double]$Current_OperatingSystem = Get-OSMajorVersion;
            Write-Log -Message "Current_OperatingSystem: $Current_OperatingSystem" -Source ${CmdletName}

            [bool]$ReturnValue = $Current_OperatingSystem -ge $MinimumVersion 
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
    End {
        Write-Output -InputObject $ReturnValue
    }
}
function Test-CMClient {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Begin
    {

        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [bool]$ReturnValue = $false;[string]$InstalledProductCode = [string]::Empty
    }
    Process
    {
        Try
        {
            Write-Log -Source ${CmdletName} -Message "Test Win32_Product..."
            $wmiJob = Get-WmiObject -Class 'Win32_Product' -filter "Name = 'Configuration Manager Client'" -Property 'Name' -Ea 'SilentlyContinue' -AsJob -DirectRead;

            Write-Log -Source ${CmdletName} -Message "Test Add/Remove Programs..."
            [bool]$ReturnValue = Test-MSI -DisplayName 'Configuration Manager Client' -Version $GLOBAL:CCM_VERSION_COMPLIANT -Operator EXISTS -Verbose
            If ( $ReturnVAlue ) {Throw;}

            Write-Log -Source ${CmdletName} -Message "Test CCMEXEC Service..."
            [bool]$ReturnValue = Test-ClientHostService;
            If ( $ReturnVAlue ) {Throw;}

            Write-Log -Source ${CmdletName} -Message "Testing WMI Namespace..."
            [bool]$ReturnValue = Test-ClientHostNamespace
            If ( $ReturnVAlue ) {Throw;}

            Write-Log -Source ${CmdletName} -Message "Waiting For WMI Job..."
            [bool]$ReturnValue = @(Get-Job -Id $wmiJob.Id | Wait-Job | Receive-Job).Count -gt 0
            If ( $ReturnVAlue ) {Throw;}
        }
        Catch {
            Write-Log -Message "SCCM Client Detected as 'Installed'" -Source ${CmdletName} -Severity 2
        }
    }
    End
    {
        Write-Output -InputObject $ReturnValue
    }
}
#endregion [Test]
##*===============================================

##*===============================================
#region [Remediation]
function Remediate-ClientDiskSpace {
    [CmdletBinding()]
    param()
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process {
        Try {
            
            If ( Test-CMClient ) {
                Clear-CMCache|Out-Null;

            }

            Write-Log -Message "Executing Disk Cleanup.." -Source ${CmdletName}
            Start-DiskCleanupUtility|Out-Null;

            Write-Log -Message "Cleaning Up Temp Files.." -Source ${CmdletName}
            (@("$Env:Windir\Temp" )+ $(Join-Path -Path $(Get-UserProfiles | Select-Object -ExpandProperty 'ProfilePath') -ChildPath 'AppData\Local\Temp')) | %{
                If ( $scriptDirectory -notlike "*$_*" ) {
                    Write-Log -Message "Remove Directory: $($_)..." -Source ${CmdletName}
                    Remove-Folder -Path "$_\*.*" -ContinueOnError $true;
                }
                Else {
                    Write-Log -Message "Skip Directory Removal: $($_)..." -Source ${CmdletName}
                }
            }

        }
        Catch
        {
            Write-Log -Message "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
}
function Remediate-ClientAdminShare {
    [CmdletBinding()]
    param()
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process {
        Try {
            New-SmbShare -FullAccess "BUILTIN\Administrators" -Path $env:Systemroot -Name 'ADMIN$';
        }
        Catch
        {
            Write-Log -Message "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
}
function Remediate-TaskScheduler {
	[CmdletBinding()]
	param
	()
	
	Begin
	{
		[string]${CmdletSection} = "Begin"
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [psobject]$ReturnValue = New-Object -TypeName PSObject	
        
    }
	Process
	{
		[string]${CmdletSection} = "Process"
		Try
		{
            [string]$SystemDirectory = Split-Path -Path $Env:comspec -Parent;
            Write-Log -Message "SystemDirectory: $SystemDirectory" -Source ${CmdletName}

            [string]$ExecutablePath = Get-ChildItem -Path $SystemDirectory -Filter 'FSUtil.exe' -Recurse -Force -ErrorAction 'SilentlyContinue' | Select-Object -First 1 -ExpandProperty 'FullName'
            Write-Log -Message "ExecutablePath: $ExecutablePath" -Source ${CmdletName}

            [string[]]$ExecutableParams = @('resource','setautoreset','true', "$($Env:SystemDrive)\");
            Write-Log -Message "ExecutableParams: $($ExecutableParams -join ',')" -Source ${CmdletName}

            If ( [string]::IsNullOrEmpty($ExecutablePath) ) { Throw "Could Not Find 'FSutil.exe' in '$SystemDirectory'" }

            Invoke-Expression -Command "cmd /c attrib -r -s -h %SystemRoot%\System32\Config\TxR\*.*"|out-Null
            Invoke-Expression -Command "cmd /c attrib -r -s -h %SystemRoot%\System32\SMI\Store\Machine\*"|out-Null

            [Hashtable]$ExecuteProcess = @{
                Path=$ExecutablePath;
                Parameters=$ExecutableParams;
                CreateNoWindow=[switch]::Present;
                WorkingDirectory=$SystemDirectory;
                PassThru=[switch]::Present; 
                ContinueOnError=$true;
            }
            Write-Log -Message "ExecuteProcess: $($ExecuteProcess | Format-List '*' | Out-String)" -Source ${CmdletName}

            [psobject]$ReturnValue = Execute-Process @ExecuteProcess;
            Write-Log -Message "ReturnValue: $($ReturnValue | Format-List '*' | Out-String)" -Source ${CmdletName}
		}
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
}
function Remediate-ClientService {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Running','Stopped',IgnoreCase=$true)]
        [string]$State,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Automatic (Delayed Start)','Disabled','Manual','Automatic',IgnoreCase=$true)]
        [string]$StartMode,

        [Parameter(Mandatory=$false)]
        [switch]$Enforce = $false
    )
    Begin
    {

        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [bool]$ReturnValue = $false;
    }
    Process
    {
        Try { 
            [bool]$ServiceExists = @(Get-Service -Name $Name -Ea SilentlyContinue).Count -gt 0
            Write-Log -Message "ServiceExists: $ServiceExists" -Source ${CmdletName}

            If ( !$ServiceExists ) {  Throw "Service '$Name' Does Not Exist."}

            [string]$CurrentStartMode = Get-ServiceStartMode -Name $Name;
            Write-Log -Message "CurrentStartMode: $CurrentStartMode" -Source ${CmdletName}

            [string]$CurrentState = Get-Service -Name $Name -Ea SilentlyContinue| Select -ExpandProperty 'State' -First 1 -Ea SilentlyContinue;
            Write-Log -Message "CurrentStartMode: $CurrentStartMode" -Source ${CmdletName}

            If ( $CurrentStartMode -notmatch $Startmode ) {
                Set-ServiceStartMode -Name $Name -StartMode $StartMode -ContinueOnError $true;
            }

            If ( $CurrentState -notmatch $State ) {
                If ( $State -eq 'Running' -and $CurrentState -eq 'Stopped') {Start-ServiceAndDependencies -Name $name -ContinueOnError $true;}
                ElseIf($State -eq 'Stopped' -and $CurrentState -eq 'Running') {Stop-ServiceAndDependencies -Name $Name -ContinueOnError $true;}
            }
        }
        Catch {
            $nonCompliantCount++;
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
}
#endregion [Remediation]
##*===============================================

##*===============================================
#region [Validation]
function Validate-ClientDiskSpace {
    [CmdletBinding()]
    param(
        [bool]$RemediateNoncompliance = $GLOBAL:CCM_REMEDIATE_DISKSPACE
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process {
        Try {
            If ( !(Test-ClientDiskSpace) ) {
                If ( !$RemediateNoncompliance ){
                    Throw "Disk Space Remediation is Disabled in Settings."
                }
                Else {
                    Remediate-ClientDiskSpace|Out-Null;
                }
            }
            Else {
                Write-Log -Message "Client Disk Space Compliant." -Source ${CmdletName}
            }
        }
        Catch
        {
            Write-Log -Message "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
}
function Validate-ClientAdminShare {
    [CmdletBinding()]
    param()
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process {
        Try {
            If ( !(Test-ClientAdminShare) ) { Remediate-ClientAdminShare }
            Else { Write-Log -Message "Client Admin Share Compliant." -Source ${CmdletName} }
        }
        Catch
        {
            Write-Log -Message "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName};
        }
    }
}
function Validate-ClientTaskScheduler {
    [CmdletBinding()]
    param()
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process {
        Try {
            If ( !(Test-ClientTaskScheduler) ) { Remediate-TaskScheduler }
            Else { Write-Log -Message "Client Task Scheduler Compliant." -Source ${CmdletName} }
        }
        Catch
        {
            Write-Log -Message "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName};
        }
    }
}
function Validate-ClientServices {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string[]]$checkServices = $(Get-Variable "CCM_SERVICE_[0-9][0-9]" | Select -ExpandProperty Value)
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [bool]$ReturnValue = $false;
    }
    Process {
        $checkServices | %{
            Try { Test-ClientService -Name $_ -State 'Running' -StartMode 'Automatic' -Enforce;}
            Catch {Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;}
        }
    }
}
function Validate-ClientOperatingSystem {
    [CmdletBinding()]
    param()
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process
    {
        Try { 
            If ( !(Test-ClientOperatingSystem) ) {
                $mainExitCode = 68001;
                Throw "Client Operating System Is Not Compliant, Exit Code 68001";
            }
            Else {
                Write-Log -Message "Client OS Compliant." -Source ${CmdletName}
            }
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
            Exit-Script
        }
    }
}
#endregion [Validation]
##*===============================================

##*===============================================
#region [MSI]
function Get-MsiErrors
{
	[CmdletBinding()]
    [OutputType([psobject[]])]
	param (
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        $MsiErrorObjects = $xmlConfig.CCM_SetupErrors.MSI_Errors
    )
	Begin  {
	    [string]${CmdletName} = $PsCmdlet.MyInvocation.MyCommand.Name;	
        [psobject[]]$ReturnValue = @();
    }
    Process {
        Try {
            [psobject[]]$MsiErrors = $MsiErrorObjects |select-object -first 1 -ExpandProperty MSI_Error
            [string[]]$PropertyNAmes =  $MsiErrors | Select-Object -First 1 -Property Attributes,ChildNodes | %{$_.Attributes.Name +  $_.ChildNodes.Name}
            [psobject[]]$ReturnValue = $MsiErrors|Select-Object -Property $PropertyNames | %{Add-Member -InputObject $_ -MemberType NoteProperty -Name 'Message' -Value $_.'#text' -PassThru -Force}|Select-Object -Property $(@($PropertyNAmes|Select -SkipLast 1) + 'Message')
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source 'Convert-Variable' -Severity 2
        }
	}
    End {
        Write-Output -InputObject $ReturnValue
    }
}
function Test-MsiError
{
	[CmdletBinding(DefaultParameterSetName='PassValue')]
    [OutputType([System.Boolean],ParameterSetName='PassQuiet')]
    [OutputType([System.Management.Automation.PSObject[]],ParameterSetName='PassValue')]
	param (
        [Parameter(Mandatory=$true, ParameterSetName='PassQuiet')]
        [Parameter(Mandatory=$true, ParameterSetName='PassValue')]
        [ValidateNotNullOrEmpty()]
        [object[]]$Errors,

        [Parameter(Mandatory=$false, ParameterSetName='PassQuiet')]
        [switch]$Quiet
    )
	Begin  {
	    [string]${CmdletName} = $PsCmdlet.MyInvocation.MyCommand.Name;	
        [System.Management.Automation.PSObject[]]$Results = @();
    }
    Process {
        Try {
            [System.Management.Automation.PSObject[]]$MSIErrors = Get-MsiErrors
            Foreach ( $ErrorNumber in $Errors ) {
                 If ( $ErrorNumber -notmatch '0x[A-Za-z0-9]{8}' ) {
                    [string]$Hexidecimal = '0x{0:X8}' -f $ErrorNumber
                }
                else {
                    [string]$Hexidecimal = $ErrorNumber
                }               
                $MSIErrors | ? {  $($_.HResult).ToUpper() -like $Hexidecimal.ToUpper()} | %{$Results += $_}
            }
            Write-Log -Message "Found $($Results.Count) Matching Errors." -Source ${CmdletName}
            If ( $PsCmdlet.ParameterSetName -eq 'PassValue' ) {
                [System.Management.Automation.PSObject[]]$ReturnValue = $Results;
            }
            Else {
                [System.Boolean]$ReturnValue = $Results.Count -gt 0;
            }
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source 'Convert-Variable' -Severity 2
        }
	}
    End {
        Write-Output -InputObject $ReturnValue
    }
}
 Function Test-RegistryVersion
{
    [CmdletBinding()]
    [OutputType([bool])]
    param(

        [Parameter(Mandatory=$True, ValueFromPipeline=$true,Position=0)]
        [ValidateNotNullOREmpty()]
        [string]$Path,
        
        [Parameter(Mandatory=$false, ValueFromPipeline=$false,Position=1)]
        [string]$Name,

        [Parameter(Mandatory=$false, ValueFromPipeline=$false,Position=2)]
        [ValidateNotNullOREmpty()]
        [switch]$Wow64=$false,

        [Parameter(Mandatory=$False, ValueFromPipeline=$false,Position=3)]
        [string]$Version,

        [Parameter(Mandatory=$True, ValueFromPipeline=$false,Position=4)]
        [ValidateNotNullOREmpty()]
        [ValidateSet('LT','LE','GT','GE','EQ','EXISTS',IgnoreCase=$true)]
        [string]$Operator = 'EXISTS'
    )
 	Begin
	{
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [bool]$ReturnValue = $false;
    }
	Process
	{
		Try {
                If ( ![string]::IsNullOrEmpty($Version) ){
                    [string[]]$VersionParts = $Version.Split('.') | %{ [int]$_ };
                    If ( $VersionParts.Count -lt 4 ) {0..(4-$VersionParts.Count) | %{$VersionParts += "0"}}
                    Write-Log -Message "VersionParts: $($VersionParts -join '|')" -Source ${CmdletName};        
            
                    [Version]$VersionObject = New-Object -TypeName System.Version -ArgumentList $VersionParts;
                    Write-Log -Message "VersionObject: $($VersionObject|fl *|out-string)" -Source ${CmdletName};    
                }
                If ( (Is-64Bit) -and $Wow64 -and ($Path -notlike '*\Wow6432Node\*') ) {$Path = $Path.toLower() -replace '^([A-Za-z_]*\\software\\)',"`$1Wow6432node\"}

                If ( $Operator -notlike 'EXISTS' ) {
                    
                    If ( [string]::IsNullOrEmpty($Name) ) {
                        Throw "Name Is Empty."
                    }
                    If ( [string]::IsNullOrEmpty($Version) ) {
                        Throw "Version Is Empty."
                    }

                    [string]$RegVersionString = Get-RegistryKey -Key $Path -Value $Name -ContinueOnError $true
                    Write-Log -Message "RegVersionString: $($RegVersionString)" -Source ${CmdletName};    
                    If ( [string]::IsNullOrEmpty($RegVersionString) ) {
                        Throw "Key Or Value DNE."
                    }

                    [string[]]$RegVersionParts = $RegVersionString.Split('.');
                    If ( $RegVersionParts.Count -lt 4 ) {0..(4-$RegVersionParts.Count) | %{$RegVersionParts += "0"}}
                    ElseIf ( $RegVersionParts.Count -gt 4 ) {($RegVersionParts.Count-4)..($RegVersionParts.Count-1) | %{$RegVersionParts -= "0"}}
                    Write-Log -Message "RegVersionParts: $($RegVersionParts -join '|')" -Source ${CmdletName};    

                    [Version]$RegVersionObject = New-Object -TypeName System.Version -ArgumentList ($RegVersionParts|select -first 4);
                    Write-Log -Message "RegVersionObject: $($RegVersionObject|fl *|out-string)" -Source ${CmdletName};    
                    
                    [bool]$ReturnValue = [bool]$(Invoke-Expression -Command "`$RegVersionObject.CompareTo(`$VersionObject) -$operator 0");
                }
                Else {
                    If ( ![string]::IsNullOrEmpty($Name) ){
                        [bool]$ReturnValue = Test-RegistryValue -Key $Path -Value $Name 
                    }
                    Else {
                        [bool]$ReturnValue = Test-Path -Path $(Convert-RegistryPath -Key $Path)
                    }
                }
		}
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
    End
    {
        Write-Output -InputObject $ReturnValue
    }

 }
function Test-MsiService
{
	[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Started','Stopped',IgnoreCase=$true)]
        [string]$TestFor
    )
    Begin
    {
        [string]${CmdletSection} = "Begin"
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [bool]$ReturnValue = $true;
        [string]$ServiceName = 'msiserver'
        
    }
    Process
    {
        [string]${CmdletSection} = "Process"
        Try 
        {
            [psobject[]]$ServiceObjects = @();
            
            Switch ( $TestFor ) {
                'Started' {
                    [string]$CompliantState = 'Running';
                    [string]$CompliantStart = 'Automatic'
                }
                'Stopped' {
                    [string]$CompliantState = 'Stopped';
                    [string]$CompliantStart = 'Disabled'
                }
            }
            @(Get-Service -Name Winmgmt) | %{$ServiceObjects += $_  }
            Write-Log -Message "CompliantState: $CompliantState" -Source ${CmdletName}
            Write-Log -Message "CompliantStart: $CompliantStart" -Source ${CmdletName}
            Foreach  ($Service in $ServiceObjects ) {

                [bool]$StateCompliance = $Service.Status -match $CompliantState;           
                Write-Log -Message "StateCompliance: $StateCompliance" -Source ${CmdletName}

                [string]$StartMode = Get-ServiceStartMode -Name $Service.Name -ContinueOnError $true -ErrorAction 'SilentlyContinue'
                Write-Log -Message "StartMode: $StartMode" -Source ${CmdletName}

                [bool]$StartCompliance = $StartMode -match $CompliantStart
                Write-Log -Message "StartCompliance: $StartCompliance" -Source ${CmdletName}

                [bool]$ReturnValue = !($StartCompliance) -or !($StateCompliance)
            }
        }
        Catch 
        {
            Write-Log -Message "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }  
    }
    End
    {
        Write-Output -InputObject $ReturnValue;
    }
}
function Get-MsiLogErrors
{
    [CmdletBinding()]
    [OutputType([psobject[]])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path -Path $_})]
        [string]$FilePath
        
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [psobject[]]$ReturnValue = @();
        [string]$VbsTempPath = Join-Path -Path $env:temp -ChildPath "GetMsiErrors.vbs"
    }
    Process
    {
        Try {
            [string]$Logcontent = Gc $FilePath|Out-String;
            ([regex]"(?<=MainEngineThread is returning )(\d{1,4})").Matches($Logcontent)|Select-Object -ExpandProperty Value -Unique | %{
                $ThisError = $_;
                $myObject = $(New-Object -TypeName Psobject -Property @{ExitCode = ([int]$ThisError);Source = 'MSI';Message =  ''; Action='';})
                Foreach ( $ErrorItem in @($(Import-Csv -Path $global:ComponentErrorscsv | ?{$_.Source -eq 'MSI' -and $_.ID -notlike '*WINDOWS_INSTALLER*'}))) {
                    $Hresult=$(ConvertFrom-HresultErrorToWin32 -hr $ErrorItem.HResult)
                    Write-Log -Message "Hresult: $Hresult" -Source ${cmdletname}
                    If ( $Hresult -eq ([int]$ThisError)){$MyObject.Message = $ErrorItem.Message; break;}
                }
                If ( $ThisError -like 1603 ) {
                    [string]$ActionSource = $([regex]'(?<=Action ended \d{1,2}:\d{1,2}:\d{1,2}: )(.*)(?=\. Return value 3\.)').Matches($Logcontent)|Select-Object -First 1 -ExpandProperty 'Value'
                    $myObject.Action = $ActionSource;
                }
                $ReturnValue += $MyObject
            }

            ([regex]"(?<=[Ee]rror( |: ))(\d{1,4})(?=\.)" ).Matches($Logcontent)|Select-Object -ExpandProperty Value -Unique|%{
                $ThisError = $_;
                Write-Log -Message "ThisError: $ThisError" -Source ${cmdletname}
                $myObject = $(New-Object -TypeName Psobject -Property @{ExitCode = ([int]$ThisError);Source = 'WindowsInstaller';Message =  ''; Action='';})
                Foreach ( $ErrorItem in @($(Import-Csv -Path $global:ComponentErrorscsv | ?{$_.Source -eq 'MSI' -and $_.ID -eq 'ERROR_WINDOWS_INSTALLER'}))) {
                    $Hresult=$(ConvertFrom-HresultErrorToWin32 -hr $ErrorItem.HResult)
                    If ( $Hresult -eq ([int]$ThisError)){
                        $MyObject.Message = $ErrorItem.Message;
                        break;
                    }            
                }
                If ( ![string]::IsNullOrEmpty($ActionSource) ){
                    $MyObject.Action = $ActionSource;
                }
                $ReturnValue += $MyObject
            }
            foreach ( $obj in $ReturnValue ){If ( [string]::IsNullOrEmpty($obj.Message)){$obj.Message = ([System.ComponentModel.Win32Exception]($obj.ExitCode)).Message;}}

        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
    End
    {
        Write-Output -InputObject $ReturnValue
    }
}
Function Reset-SccmClientMsiSource
{
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$DefaultSource = $DefaultInstallSourcePath    
    )
 	Begin
	{
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [bool]$ReturnValue = $false;
        IF ( -not ([bool](@(Get-Module -Name MSI -Ea SilentlyContinue).Count -gt 0))){
            Try {
                Import-Module -Name $MSIPSModule -Force -Ea 'Stop';
            }
            Catch {
                Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
                return
            }
        }
    }
	Process
	{
		Try {

            [string]$InstalledProductCode = Get-InstalledApplication -Name 'Configuration Manager Client' -Exact | Select-Object -First 1 -ExpandProperty 'ProductCode';
            Write-Log -Message "InstalledProductCode: $InstalledProductCode" -Source ${CmdletName};

            [string[]]$ProductSources = Get-MSISource -ProductCode $InstalledProductCode | Sort-Object -Property 'Order' | Select-Object -ExpandProperty 'Path'
            Write-Log -Message "Found $($ProductSources.Count) Source Paths." -Source ${CmdletName};

            If ( [string]::IsNullOrEmpty($InstalledProductCode) ) {Throw "Could Not Find Installed Product Code For 'Configuration Manager Client'"}

            $ProductSource+=$DefaultInstallSourcePath;

            [string]$InstalledPatchCode = Get-MSIPatchInfo -ProductCode $InstalledProductCode | Select-Object -ExpandProperty 'PatchCode' -First 1;
            Write-Log -Message "InstalledPatchCode: $InstalledPatchCode" -Source ${CmdletName};

            If ( ![string]::IsNullOrEmpty($InstalledPatchCode) ) {
                [string[]]$PatchSources = Get-MSISource -ProductCode $InstalledProductCode -PatchCode $InstalledPatchCode| Sort-Object -Property 'Order' | Select-Object -ExpandProperty 'Path'
            }
            Else {
                [string[]]$PatchSources = @();
            }
            Write-Log -Message "Found $($PatchSources.Count) Patch Source Paths." -Source ${CmdletName};

            [string]$TempDirectory = Join-Path -Path $Env:Temp -ChildPath "CCMSetupTemp"
            Write-Log -Message "TempDirectory: $TempDirectory" -Source ${CmdletName};

            If ( $Is64Bit ) { 
                [string]$clientSubfolder = 'x64'
            }
            else {
                [string]$clientSubfolder = 'i386'
            }
            Write-Log -Message "clientSubfolder: $clientSubfolder" -Source ${CmdletName};

            [string[]]$ProductLocalPaths = $ProductSources | ?{$_ -match '[A-Za-z]{1}:\\.*'}
            Write-Log -Message "Found $($ProductLocalPaths.Count) Local Source Paths." -Source ${CmdletName};

            [string[]]$ValidProductLocalPaths = $ProductLocalPaths | ?{Test-Path -Path "$($_.TrimEnd('\'))\client.msi"}
            Write-Log -Message "Found $($ValidProductLocalPaths.Count) Valid Local Source Paths." -Source ${CmdletName};

            [string[]]$ProductHttpPaths = $ProductSources | ?{$_ -match 'http://.*'}
            Write-Log -Message "Found $($ProductLocalPaths.Count) Network Source Paths." -Source ${CmdletName}

            [string[]]$ValidProductHttpPaths = $ProductHttpPaths | ?{Test-URI -URI "$($_.TrimEnd('/'))/ccmsetup.cab"}
            Write-Log -Message "Found $($ValidProductHttpPaths.Count) Valid Network Source Paths." -Source ${CmdletName};
  
            [string[]]$ValidPatchLocalPaths = $PatchSources  | ?{@(Gci -Path $_ -Ea SilentlyContinue -Filter "*$($clientSubfolder)*.msp").Count -gt 0}
            Write-Log -Message "Found $($ValidPatchLocalPaths.Count) Valid Local Patch Source Paths." -Source ${CmdletName};
            
            If ( $ValidProductLocalPaths.Count -eq 0 ) {
                Foreach ( $ValidProductHttpPath in $ValidProductHttpPaths ) {
                    Try {
                        Write-Log -Message "Recusively Downloading Web Directory '$ValidProductHttpPath' To '$TempDirectory'..." -Source ${CmdletName};
                        Download-WebDirectory -Source $ValidProductHttpPath -Destination $TempDirectory -Recurse -Force -Ea 'Stop';
                        Write-Log -Message "Download Finished ($?)." -Source ${CmdletName};
                        If ( Test-Path -Path "$TempDirectory\ccmsetup.cab" ) {
                            Write-Log -Message "Download Success." -Source ${CmdletName}; 
                            break;
                        }
                        Else {Throw "Download Fail (Unknown) (Could Not Find '$TempDirectory\ccmsetup.cab').";}
                    }
                    Catch {Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2}
                }
                If ( !(Test-Path -Path "$TempDirectory\ccmsetup.cab")){  Throw "Unable To Find '$TempDirectory\ccmsetup.cab'"; }
                Else {
                    Write-Log -Message "Clearing MSI Source For Product '$InstalledProductCode'..." -Source ${CmdletName}; 
                    Clear-MSISource -ProductCode $InstalledProductCode;
                    Write-Log -Message "Done. ($?)" -Source ${CmdletName}; 

                    Write-Log -Message "Adding MSI Source '$TempDirectory\$clientSubfolder' To $InstalledProductCode'..." -Source ${CmdletName}; 
                    Add-MSISource -Path "$TempDirectory\$clientSubfolder" -ProductCode $InstalledProductCode;
                    Write-Log -Message "Done. ($?)" -Source ${CmdletName}; 

                    If ( ![string]::IsNullOrEmpty($InstalledPatchCode) ) {
                        Write-Log -Message "Clearing MSI Source For Product '$InstalledProductCode ($InstalledPatchCode)'..." -Source ${CmdletName}; 
                        Clear-MSISource -ProductCode $InstalledProductCode -PatchCode $InstalledPatchCode;
                        Write-Log -Message "Done. ($?)" -Source ${CmdletName}; 

                        Write-Log -Message "Adding MSI Source '$TempDirectory\$clientSubfolder' To $InstalledProductCode ($InstalledPatchCode)'..." -Source ${CmdletName}; 
                        Add-MSISource -Path "$TempDirectory\$clientSubfolder" -ProductCode $InstalledProductCode -PatchCode $InstalledPatchCode;
                        Write-Log -Message "Done. ($?)" -Source ${CmdletName}; 
                    }
                }
            }
            Else {
                Write-Log -Message "Configuration Manager Client MSI Source is Valid" -Source ${CmdletName}; 
            }
		}
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
 }
Function Register-MsiServer
{
	[CmdletBinding()]
    
	param
	(
        [string[]]$ServiceFiles = @()
    )
	
	Begin
	{
		[string]${CmdletSection} = "Begin"
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
	Process
	{
		[string]${CmdletSection} = "Process"
		try
		{
            Get-Item -Ea 'SilentlyContinue' -PAth "$Env:windir\system32\msi.dll","$Env:windir\syswow64\msi.dll" | %{
                Execute-Process -Path "$($_.DirectoryName)\msiexec.exe" -Parameters '/unregserver' -CreateNoWindow -WorkingDirectory $($_.DirectoryName) -PassThru -ContinueOnError $true;
                Invoke-RegisterOrUnregisterDLL -FilePath $_.FullName -DLLAction Unregister -ContinueOnError $true;
                
                Execute-Process -Path "$($_.DirectoryName)\msiexec.exe" -Parameters '/regserver' -CreateNoWindow -WorkingDirectory $($_.DirectoryName) -PassThru -ContinueOnError $true;
                Invoke-RegisterOrUnregisterDLL -FilePath $_.FullName -DLLAction Register -ContinueOnError $true;
            }                         
		}
		catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
		}
	}
}
Function ConvertFrom-MsiProductCodeToPackageCode
{
    [CmdletBinding()]
    param(
        #Accepts only GUID data type, to ensure Valid string format.
        [Parameter(Mandatory=$True, ValueFromPipeline=$true,Position=0)]
        [GUID]$GUID
    )
 	Begin
	{
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
	Process
	{
		Try
		{
            #Stripping off the brackets and the dashes from the GUID, leaving only alphanumerical chars.
            [string]$ProductIDChars = [regex]::replace($GUID, "[^a-zA-Z0-9]", "")
 
            #1. Reversing the first 8 characters, next 4, next 4. Then for the latter half, reverse every two char.
            [int[]]$RearrangedCharIndex = 7,6,5,4,3,2,1,0,11,10,9,8,15,14,13,12,17,16,19,18,21,20,23,22,25,24,27,26,29,28,31,30,32
            [string]$ReturnValue = -join ($RearrangedCharIndex | ForEach-Object{$ProductIDChars[$_]})

		}
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
    End
    {
        Write-Output -InputObject $ReturnValue
    }

 }
Function ConvertFrom-MsiPackageCodeToProductCode
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$true,Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageCode
    )
 	Begin
	{
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
	Process
	{
		Try
		{
            #Stripping off the brackets and the dashes from the GUID, leaving only alphanumerical chars.
            [string]$ProductIDChars = [regex]::replace($PackageCode, "[^a-zA-Z0-9]", "")
            [int[]]$RearrangedCharIndex = 7,6,5,4,3,2,1,0,11,10,9,8,15,14,13,12,17,16,19,18,21,20,23,22,25,24,27,26,29,28,31,30,32
            [string]$RawGuid = -join ($RearrangedCharIndex | ForEach-Object{$ProductIDChars[$_]})
            [string]$ReturnValue = '{' + $(New-Object -TypeName System.Guid -ArgumentList $RawGuid |Select-Object -ExpandProperty 'GUID'| %{$_.ToUpper()}|Select-Object -First 1) + '}'
		}
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
    End
    {
        Write-Output -InputObject $ReturnValue
    }

 }
Function Test-MsiInstalledSource
{
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        #Accepts only GUID data type, to ensure Valid string format.
        [Parameter(Mandatory=$True, ValueFromPipeline=$true,Position=0)]
        [ValidateNotNullOREmpty()]
        [string]$ProductCode
    )
 	Begin
	{
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [bool]$ReturnValue = $false;
    }
	Process
	{
		Try
		{
            [string]$MsiPackageCode = ConvertFrom-MsiProductCodeToPackageCode -GUID $ProductCode;
            Write-Log -Message "MsiPackageCode: $MsiPackageCode" -Source ${CmdletName}

            If ( [string]::IsNullOrEmpty($MsiPackageCode ))
            {
                Throw "Unable To Get Package Code For '$($ProductCode)'"
            }

            [string]$DatabasePath = Join-Path -path 'HKLM:\SOFTWARE\Classes\Installer\Products' -ChildPath $MsiPackageCode;
            Write-Log -Message "DatabasePath: $DatabasePath" -Source ${CmdletName}

            If ( !(Test-Path -Path $DatabasePath) )
            {
                Throw "Unable To Find '$DatabasePath' in Registry."
            }

            [string]$ProductDbSrcPath = Join-Path -Path $DatabasePath -ChildPath 'SourceList'
            Write-Log -Message "ProductDbSrcPath: $ProductDbSrcPath" -Source ${CmdletName}

            [string]$ProductNetPath = Join-Path -Path $ProductDbSrcPath -ChildPath 'Net'
            Write-Log -Message "ProductNetPath: $ProductNetPath" -Source ${CmdletName}

            [psobject]$ProductSourceDetails = Get-ItemProperty -Path $ProductDbSrcPath;
            Write-Log -Message "ProductSourceDetails: $($ProductSourceDetails | fl * | Out-String)" -Source ${CmdletName}

            [psobject]$ProductSourceNetDetails = Get-ItemProperty -Path $ProductNetPath;
            Write-Log -Message "ProductSourceNetDetails: $($ProductSourceNetDetails | fl * | Out-String)" -Source ${CmdletName}

            [string]$PackageName = $ProductSourceDetails | Select -First 1 -ExpandProperty 'PackageName' -ErrorAction SilentlyContinue;
            Write-Log -Message "PackageName: $PackageName" -Source ${CmdletName}

            [string]$LastUsedSource = $ProductSourceDetails | Select -First 1 -ExpandProperty 'LastUsedSource' -ErrorAction SilentlyContinue;
            Write-Log -Message "LastUsedSource: $($LastUsedSource | fl * | Out-String)" -Source ${CmdletName}


            [string[]]$KeyNames = (Get-ItemProperty -Path $ProductNetPath).psobject.properties.name | ?{ $_ -match '\d{1,2}'}
            Write-Log -Message "KeyNames: $($KeyNames | fl * | Out-String)" -Source ${CmdletName}
            
            
            [string[]]$Sources = @();
            Foreach ($KeyName in $KeyNames)
            {
                $Sources += $(Join-Path -Path $ProductSourceNetDetails.$KeyName.ToLower() -ChildPath $($PackageName));
            }

            $Sources = $Sources | Select -Unique
            Write-Log -Message "Sources: $($Sources | fl * | Out-String)" -Source ${CmdletName}

            [int]$ExistCount=0;
            Foreach ( $source in $sources)
            {
                If ((Test-Path -Path $Source) -and $($Source -notlike '\\*')){$ExistCount++}
            }
            [bool]$ReturnVAlue = $ExistCount++;
		}
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
    End
    {
        Write-Output -InputObject $ReturnValue
    }

 }
Function Set-MsiLastUsedSource
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$true,Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$ProductCode,
        [Parameter(Mandatory=$True, ValueFromPipeline=$true,Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )
 	Begin
	{
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
	Process
	{
		Try
		{
            [string]$MsiPackageCode = ConvertFrom-MsiProductCodeToPackageCode -GUID $ProductCode;
            Write-Log -Message "MsiPackageCode: $MsiPackageCode" -Source ${CmdletName}

            If ( [string]::IsNullOrEmpty($MsiPackageCode ))
            {
                Throw "Unable To Get Package Code For '$($ProductCode)'"
            }

            [string]$DatabasePath = Join-Path -path 'HKLM:\SOFTWARE\Classes\Installer\Products' -ChildPath $MsiPackageCode;
            Write-Log -Message "DatabasePath: $DatabasePath" -Source ${CmdletName}

            [bool]$DbPathExists = Test-Path -Path $DatabasePath;
            Write-Log -Message "DbPathExists: $DbPathExists" -Source ${CmdletName}

            #[bool]$NetPathMatch = $Path -notlike '\\*';
            #Write-Log -Message "NetPathMatch: $NetPathMatch" -Source ${CmdletName}

            If ( $DbPathExists )
            {
                 [string]$ProductDbSrcPath = Join-Path -Path $DatabasePath -ChildPath 'SourceList'
                Write-Log -Message "ProductDbSrcPath: $ProductDbSrcPath" -Source ${CmdletName}

                [string]$ProductNetPath = Join-Path -Path $ProductDbSrcPath -ChildPath 'Net'
                Write-Log -Message "ProductNetPath: $ProductNetPath" -Source ${CmdletName}

                [psobject]$ProductSourceDetails = Get-ItemProperty -Path $ProductDbSrcPath;
                Write-Log -Message "ProductSourceDetails: $($ProductSourceDetails | fl * | Out-String)" -Source ${CmdletName}

                [psobject]$ProductSourceNetDetails = Get-ItemProperty -Path $ProductNetPath;
                Write-Log -Message "ProductSourceNetDetails: $($ProductSourceNetDetails | fl * | Out-String)" -Source ${CmdletName}
            
                [string]$Directory = [IO.Path]::GetDirectoryName($Path)
                Write-Log -Message "Directory: $Directory" -Source ${CmdletName}

                Write-Log -Message "Copying Files From '$Path'..." -Source ${CmdletName}
                
                Copy-File -Path "$Directory\*.*" -Destination "$Env:Windir\Temp" -Recurse -ContinueOnError $true;
                If ($?) {Write-Log -Message "File Copy Finished [Success]" -Source ${CmdletName}}
                Else {Write-Log -Message "File Copy Finished [Failure]" -Source ${CmdletName}}

                Write-Log -Message "Set Registry Key '$ProductDbSrcPath'::1='$env:windir\temp'" -Source ${CmdletName}
                Set-RegistryKey -Key $ProductNetPath -Name '1' -Value "$env:windir\temp" -Type ExpandString -ContinueOnError $true;

                Write-Log -Message "Set Registry Key '$ProductDbSrcPath'::LastUsedSource='n;1;$env:windir\temp\'" -Source ${CmdletName}
                Set-RegistryKey -Key $ProductDbSrcPath -Name 'LastUsedSource' -Value "n;1;$env:windir\temp\" -Type ExpandString -ContinueOnError $true;               
            }
            Else
            {
                Write-Log -Message "Unable To Find '$DatabasePath' in Registry." -Source ${CmdletName}
            }


            [string]$DatabasePath = Join-Path -path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\Managed\S-1-5-18\Installer\Products' -ChildPath $MsiPackageCode;
            Write-Log -Message "DatabasePath: $DatabasePath" -Source ${CmdletName}

            [bool]$DbPathExists = Test-Path -Path $DatabasePath;
            Write-Log -Message "DbPathExists: $DbPathExists" -Source ${CmdletName}

            #[bool]$NetPathMatch = $Path -notlike '\\*';
            #Write-Log -Message "NetPathMatch: $NetPathMatch" -Source ${CmdletName}

            If ( $DbPathExists )
            {
                 [string]$ProductDbSrcPath = Join-Path -Path $DatabasePath -ChildPath 'SourceList'
                Write-Log -Message "ProductDbSrcPath: $ProductDbSrcPath" -Source ${CmdletName}

                [string]$ProductNetPath = Join-Path -Path $ProductDbSrcPath -ChildPath 'Net'
                Write-Log -Message "ProductNetPath: $ProductNetPath" -Source ${CmdletName}

                [psobject]$ProductSourceDetails = Get-ItemProperty -Path $ProductDbSrcPath;
                Write-Log -Message "ProductSourceDetails: $($ProductSourceDetails | fl * | Out-String)" -Source ${CmdletName}

                [psobject]$ProductSourceNetDetails = Get-ItemProperty -Path $ProductNetPath;
                Write-Log -Message "ProductSourceNetDetails: $($ProductSourceNetDetails | fl * | Out-String)" -Source ${CmdletName}
            
                [string]$Directory = [IO.Path]::GetDirectoryName($Path)
                Write-Log -Message "Directory: $Directory" -Source ${CmdletName}

                Write-Log -Message "Copying Files From '$Path'..." -Source ${CmdletName}
                
                Copy-File -Path "$Directory\*.*" -Destination "$Env:Windir\Temp" -Recurse -ContinueOnError $true;
                If ($?) {Write-Log -Message "File Copy Finished [Success]" -Source ${CmdletName}}
                Else {Write-Log -Message "File Copy Finished [Failure]" -Source ${CmdletName}}

                Write-Log -Message "Set Registry Key '$ProductDbSrcPath'::1='$env:windir\temp'" -Source ${CmdletName}
                Set-RegistryKey -Key $ProductNetPath -Name '1' -Value "$env:windir\temp" -Type ExpandString -ContinueOnError $true;

                Write-Log -Message "Set Registry Key '$ProductDbSrcPath'::LastUsedSource='n;1;$env:windir\temp\'" -Source ${CmdletName}
                Set-RegistryKey -Key $ProductDbSrcPath -Name 'LastUsedSource' -Value "n;1;$env:windir\temp\" -Type ExpandString -ContinueOnError $true;               
            }
            Else
            {
                Write-Log -Message "Unable To Find '$DatabasePath' in Registry." -Source ${CmdletName}
            }
		}
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
    End
    {
        Write-Output -InputObject $ReturnValue
    }

 }
function Get-MsiUpgradeCode
{
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [guid]$ProductCode
        
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [string]$ReturnValue = [string]::Empty;
    }
    Process
    {
        Try {
            [string]$PackageCode = ConvertFrom-MsiProductCodeToPackageCode -GUID $ProductCode;
            Write-Log -Message "PackageCode: $PackageCode" -Source ${CmdletName}

            If ( [string]::IsNullOrEmpty($PackageCode) ){Throw "PackageCode is Empty."}

            Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UpgradeCodes' | Foreach-Object { 
                Try {If (  $(Get-RegistryKey -Key $_.Name).PSObject.Properties.Name -contains $PackageCode.toUpper() ){ [string]$ReturnValue = ConvertFrom-MsiPackageCodeToProductCode -PackageCode $($_.Name.Split('\')|Select -Last 1); break;}}
                Catch {Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;}
            }

        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
    End
    {
        Write-Output -InputObject $ReturnValue
    }
}
function Get-MsiProductCode
{
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [guid]$UpgradeCode
        
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [string]$ReturnValue = [string]::Empty;
    }
    Process
    {
        Try {
            [string]$PackageCode = ConvertFrom-MsiProductCodeToPackageCode -GUID $UpgradeCode;
            Write-Log -Message "PackageCode: $PackageCode" -Source ${CmdletName}

            If ( [string]::IsNullOrEmpty($PackageCode) ){Throw "PackageCode is Empty."}

            [psobject]$UpgradeCodeObj = Get-RegistryKey -Key "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UpgradeCodes\$PackageCode" -ContinueOnError $true;
            Write-Log -Message "UpgradeCodeObj: $($UpgradeCodeObj|fl *|out-string)" -Source ${CmdletName} 

            If ( !$UpgradeCodeObj) { Throw "Unable To find Reg Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UpgradeCodes\$PackageCode'" }

            [string]$ReturnPackageCode = $UpgradeCodeObj.PSObject.Properties.Name | Where-Object {$_ -notlike 'PS*'} | Select-Object -First 1;
            Write-Log -Message "ReturnPackageCode: $ReturnPackageCode" -Source ${CmdletName}

            [string]$ReturnValue = ConvertFrom-MsiPackageCodeToProductCode -PackageCode $ReturnPackageCode;
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
    End
    {
        Write-Output -InputObject $ReturnValue
    }
}
Function Test-MSI
{
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        #Accepts only GUID data type, to ensure Valid string format.
        [Parameter(Mandatory=$True, ValueFromPipeline=$true,Position=0,ParameterSetName='ByUpgradeCode')]
        [ValidateNotNullOREmpty()]
        [string]$UpgradeCode,

        [Parameter(Mandatory=$True, ValueFromPipeline=$true,Position=0,ParameterSetName='ByProductCode')]
        [ValidateNotNullOREmpty()]
        [string]$ProductCode,

        [Parameter(Mandatory=$True, ValueFromPipeline=$true,Position=0,ParameterSetName='ByDisplayName')]
        [ValidateNotNullOREmpty()]
        [string]$DisplayName,

        [Parameter(Mandatory=$False, ValueFromPipeline=$false,Position=1,ParameterSetName='ByProductCode')]
        [Parameter(Mandatory=$False, ValueFromPipeline=$false,Position=1,ParameterSetName='ByUpgradeCode')]
        [Parameter(Mandatory=$false, ValueFromPipeline=$false,Position=1,ParameterSetName='ByDisplayName')]
        [string]$Version,

        [Parameter(Mandatory=$False, ValueFromPipeline=$false,Position=2,ParameterSetName='ByProductCode')]
        [Parameter(Mandatory=$False, ValueFromPipeline=$false,Position=2,ParameterSetName='ByUpgradeCode')]
        [Parameter(Mandatory=$False, ValueFromPipeline=$true,Position=2,ParameterSetName='ByDisplayName')]
        [ValidateNotNullOREmpty()]
        [ValidateSet('LT','LE','GT','GE','EQ','EXISTS',IgnoreCase=$true)]
        [string]$Operator = 'EXISTS'
    )
 	Begin
	{
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [bool]$ReturnValue = $false;
    }
	Process
	{
		Try {

            If ( ![string]::IsNullOrEmpty($Version) ){
                [string[]]$VersionParts = $Version.Split('.');
                If ( $VersionParts.Count -lt 4 ) {0..(4-$VersionParts.Count) | %{$VersionParts += "0"}}
                Write-Log -Message "VersionParts: $($VersionParts -join '|')" -Source ${CmdletName};        
            
                [Version]$VersionObject = New-Object -TypeName System.Version -ArgumentList $VersionParts;
                Write-Log -Message "VersionObject: $($VersionObject|fl *|out-string)" -Source ${CmdletName};    
            }

            #-#############################-#
            If ( $PSCmdlet.ParameterSetName -eq 'ByUpgradeCode' ) {
                [string]$ProductCode = Get-MsiProductCode -UpgradeCode $UpgradeCode;
                Write-Log -Message "ProductCode: $ProductCode" -Source ${CmdletName};
            }
            ElseIf ( $PSCmdlet.ParameterSetName -eq 'ByDisplayName' ) {
                [string]$ProductCode = Get-InstalledApplication -Name $DisplayName -WildCard | Select-Object -First 1 -ExpandProperty 'ProductCode';
                Write-Log -Message "ProductCode: $ProductCode" -Source ${CmdletName};
            }
            #-#############################-#

            If ( [string]::IsNullOrEmpty($ProductCode) ){
                [bool]$ReturnValue = $false;
            }
            Else {

                [string]$DisplayVersion = Get-InstalledApplication -ProductCode $ProductCode -Exact | Select-Object -ExpandProperty 'DisplayVersion';
                Write-Log -Message "DisplayVersion: $DisplayVersion" -Source ${CmdletName};
                If ( $Operator -notlike 'EXISTS' ) {

                    If ( [string]::IsNullOrEmpty($ProductCode) ){ [bool]$ReturnValue = $false; }
                    Else {
                        [string[]]$DisplayVersionParts = $DisplayVersion.Split('.');

                        If ( $DisplayVersionParts.Count -lt 4 ) {0..(4-$DisplayVersionParts.Count) | %{$DisplayVersionParts += "0"}}
                        Write-Log -Message "DisplayVersionParts: $($DisplayVersionParts -join '|')" -Source ${CmdletName};    

                        [Version]$DisplayVersionObject = New-Object -TypeName System.Version -ArgumentList $DisplayVersionParts;
                        Write-Log -Message "DisplayVersionObject: $($DisplayVersionObject|fl *|out-string)" -Source ${CmdletName};    
                    }
                    [bool]$ReturnValue = [bool]$(Invoke-Expression -Command "`$DisplayVersionObject.CompareTo(`$VersionObject) -$operator 0");
                }
                Else {
                    [bool]$ReturnValue = ![string]::IsNullOrEmpty($DisplayVersion);
                }
            }
		}
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
    End
    {
        Write-Output -InputObject $ReturnValue
    }

 }
 Function Test-FileVersion
{
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        #Accepts only GUID data type, to ensure Valid string format.
        [Parameter(Mandatory=$True, ValueFromPipeline=$true,Position=0,ParameterSetName='ByUpgradeCode')]
        [ValidateNotNullOREmpty()]
        [string]$Path,

        [Parameter(Mandatory=$False, ValueFromPipeline=$false,Position=1,ParameterSetName='ByProductCode')]
        [Parameter(Mandatory=$False, ValueFromPipeline=$false,Position=1,ParameterSetName='ByUpgradeCode')]
        [string]$Version,

        [Parameter(Mandatory=$True, ValueFromPipeline=$false,Position=1,ParameterSetName='ByProductCode')]
        [Parameter(Mandatory=$True, ValueFromPipeline=$false,Position=1,ParameterSetName='ByUpgradeCode')]
        [ValidateNotNullOREmpty()]
        [ValidateSet('LT','LE','GT','GE','EQ','EXISTS',IgnoreCase=$true)]
        [string]$Operator = 'EXISTS'
    )
 	Begin
	{
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [bool]$ReturnValue = $false;
    }
	Process
	{
		Try {
                If ( ![string]::IsNullOrEmpty($Version) ){
                    [string[]]$VersionParts = $Version.Split('.') | %{ [int]$_ };
                    If ( $VersionParts.Count -lt 4 ) {0..(4-$VersionParts.Count) | %{$VersionParts += "0"}}
                    Write-Log -Message "VersionParts: $($VersionParts -join '|')" -Source ${CmdletName};        
            
                    [Version]$VersionObject = New-Object -TypeName System.Version -ArgumentList $VersionParts;
                    Write-Log -Message "VersionObject: $($VersionObject|fl *|out-string)" -Source ${CmdletName};    
                }

                If ( $Operator -notlike 'EXISTS' ) {
                    
                    [string]$FileVersion = Get-ItemProperty -Path $Path -Name 'VersionInfo'|Select-Object -ExpandProperty 'VersionInfo'| Select-Object -ExpandProperty 'ProductVersion' -First 1
                    Write-Log -Message "FileVersion: $($FileVersion)" -Source ${CmdletName};    

                    [string[]]$FileVersionParts = $FileVersion.Split('.');
                    If ( $FileVersionParts.Count -lt 4 ) {0..(4-$FileVersionParts.Count) | %{$FileVersionParts += "0"}}
                    Write-Log -Message "FileVersionParts: $($FileVersionParts -join '|')" -Source ${CmdletName};    

                    [Version]$FileVersionObjects = New-Object -TypeName System.Version -ArgumentList $FileVersionParts;
                    Write-Log -Message "DisplayVersionObject: $($DisplayVersionObject|fl *|out-string)" -Source ${CmdletName};    
                    
                    [bool]$ReturnValue = [bool]$(Invoke-Expression -Command "`$VersionObject.CompareTo(`$FileVersionObjects) -$operator 0");
                }
                Else {
                    [bool]$ReturnValue = Test-Path -Path $Path;
                }
		}
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
    End
    {
        Write-Output -InputObject $ReturnValue
    }

 }
 #endregion [MSI]
##*===============================================

##*===============================================
#region [Task Scheduler]
function Remove-ScheduledTask 
{
	[cmdletbinding()]
	param (
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0
        )]
        [string]
		$ComputerName = $env:computername,
		
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 1
        )]
        [string]
		$Path
	)
	
	begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
		try {
	        $Schedule = New-Object -ComObject 'Schedule.Service'
        } catch {
	        Write-Log -Message "Schedule.Service COM Object not found, this script requires this object" -Source ${CmdletName} -Severity 2
	        return
        }
	}
	
	process	{
        try {
            $Schedule.Connect($ComputerName)
            $TaskFolder = $Schedule.GetFolder((Split-Path -Path $Path))
            $TaskFolder.DeleteTask((Split-Path -Path $Path -Leaf),0)
            
        } catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        }
	}
}
function New-ScheduledTaskItem
{
	[cmdletbinding()]
	param (
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0
        )]
		$Path = 'Nothing',
		
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 1
        )]
        [string]
		$Definition,

		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 1
        )]
		$Flags = 6,

		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 1
        )]
        [string]
		$logonType = 5
 
	)
	
	begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
		try {
	        $Schedule = New-Object -ComObject 'Schedule.Service'
        } catch {
	        Write-Log -Message "Schedule.Service COM Object not found, this script requires this object" -Source ${CmdletName} -Severity 2
	        return
        }
	}
	
	process	{
        try {
            $Schedule.Connect($env:ComputerName)
            $TaskFolder = $Schedule.GetFolder('\')
            $TaskFolder.RegisterTaskDefinition($Path,$Definition,$Flags,$null,$null,$logonType)
            
        } catch {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        }
	}
}
Function Get-ScheduledTasks 
{
    [CmdletBinding()]
    [OutputType([psobject[]])]
    param(
	    [string]$ComputerName = $env:COMPUTERNAME,
        [switch]$RootFolder
    )

    Begin{
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [psobject[]]$ReturnValue=@()
        #region Functions
        function Get-AllTaskSubFolders {
            [cmdletbinding()]
            param (
                # Set to use $Schedule as default parameter so it automatically list all files
                # For current schedule object if it exists.
                $FolderRef = $Schedule.getfolder("\")
            )
            if ($FolderRef.Path -eq '\') {
                $FolderRef
            }
            if (-not $RootFolder) {
                $ArrFolders = @()
                if(($Folders = $folderRef.getfolders(1))) {
                    $Folders | ForEach-Object {
                        $ArrFolders += $_
                        if($_.getfolders(1)) {
                            Get-AllTaskSubFolders -FolderRef $_
                        }
                    }
                }
                $ArrFolders
            }
        }

        function Get-TaskTrigger {
            [cmdletbinding()]
            param (
                $Task
            )
            $Triggers = ([xml]$Task.xml).task.Triggers
            if ($Triggers) {
                $Triggers | Get-Member -MemberType Property | ForEach-Object {
                    $Triggers.($_.Name)
                }
            }
        }
        #endregion Functions
    
    
        try {
	        $Schedule = New-Object -ComObject 'Schedule.Service'
        } catch {
	        Write-Log -Message "Schedule.Service COM Object not found, this script requires this object" -Source ${CmdletName} -Severity 2;
	        return
        }
    }
    Process {
        Try {
            $Schedule.connect($ComputerName) 
            $AllFolders = Get-AllTaskSubFolders

            foreach ($Folder in $AllFolders) {
                if (($Tasks = $Folder.GetTasks(1))) {
                    $Tasks | Foreach-Object {
	                    $ReturnValue += New-Object -TypeName PSCustomObject -Property @{
	                        'Name' = $_.name
                            'Path' = $_.path
                            'State' = switch ($_.State) {
                                0 {'Unknown'}
                                1 {'Disabled'}
                                2 {'Queued'}
                                3 {'Ready'}
                                4 {'Running'}
                                Default {'Unknown'}
                            }
                            'Enabled' = $_.enabled
                            'LastRunTime' = $_.lastruntime
                            'LastTaskResult' = $_.lasttaskresult
                            'NumberOfMissedRuns' = $_.numberofmissedruns
                            'NextRunTime' = $_.nextruntime
                            'Author' =  ([xml]$_.xml).Task.RegistrationInfo.Author
                            'UserId' = ([xml]$_.xml).Task.Principals.Principal.UserID
                            'Description' = ([xml]$_.xml).Task.RegistrationInfo.Description
                            'Trigger' = Get-TaskTrigger -Task $_
                            'ComputerName' = $Schedule.TargetServer
                        }
                    }
                }
            }
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
    End {
        Write-Output -InputObject $ReturnValue
    }
}
function Add-BlockCcmSetupStartupScript
{
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [parameter(Mandatory=$false, Position=0)]
        [ValidateNotNullOrEmpty()]
        [Int32]$Number = $(Get-NextStartupScriptNumber),
        
        [parameter(Mandatory=$false, Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidateCount(1,30)]
        [string[]]$CCMSetupArguments = ${ccmsetupParameters}
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process {
        Try {                
            
            [string]$CCMSetupDefaultDirectory =   Join-Path -Path $Env:Windir -ChildPath 'ccmsetup' #$(Split-Path -Path $CCMSetupDefaultPath -Parent)
            [string]$CCMSetupDefaultPath = Join-Path -Path $CCMSetupDefaultDirectory -ChildPath 'ccmsetup.exe'
            [string]$CCMTempDestPath = Join-Path -Path $env:temp -ChildPath 'ccmsetup.exe'
            If ( !(Test-Path -Path $CCMSetupDefaultPath)){
                Write-Log -Message "Download File 'ftp://whdq2032/bin/ccmsetup.exe -> $CCMTempDestPath' " -Source ${CmdletName}
                If ( Test-Path -Path $CCMTempDestPath ){ Remove-File -Path $CCMTempDestPath -ContinueOnError $true -ErrorAction 'SilentlyContinue';}
                Invoke-FtpDownload -url 'ftp://whdq2032/bin' -localPath $CCMTempDestPath -Filter 'ccmsetup.exe';
                If ( !(Test-Path -Path $CCMSetupDefaultDirectory)) { New-Folder -Path $CCMSetupDefaultDirectory -ContinueOnError $true -ErrorAction 'SilentlyContinue'; }
                [string]$CCMSetupPath = Move-Item -Path $CCMTempDestPath -Destination $CCMSetupDefaultDirectory -Force -PassThru -ErrorAction 'SilentlyContinue'| Select-Object -ExpandProperty 'FullName' -First 1;
            }
            Else {
                [string]$CCMSetupPath = $CCMSetupDefaultPath;
            }
            If ([string]::IsNullOrEmpty($CCMSetupPath) ){
                Throw "CCMSetup.exe Path Is Null Or Empty."
            }
            ElseIf ( !(Test-Path -Path $CCMSetupPath -Ea SilentlyContinue )){
                Throw "CCMSetup.exe Could Not Be Found."
            }
            Else {
                Write-Log -Message "CCMSetupPath: $CCMSetupPath" -Source ${CmdletName}
            }

            [string]$CCMSetupDirectory = Split-Path -Path $CCMSetupPath -Parent
            Write-Log -Message "CCMSetupDirectory: $CCMSetupDirectory" -Source ${CmdletName}

            [string]$StageScriptPath = Join-Path -Path $Env:ProgramData -ChildPath 'CleanCCMSetup.bat'
            Write-Log -Message "StageScriptPath: $StageScriptPath" -Source ${CmdletName}

            [string]$StartupScript = @"
@ECHO OFF
REG DELETE "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\$Number" /f
REG DELETE "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\$Number" /f
REG DELETE "HKU\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "DisallowRun" /f
REG DELETE "HKU\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\DisallowRun" /v 1 /f
CD /D "$CCMSetupDirectory"
CCMSETUP.EXE $($CCMSetupArguments -join ' ')
DEL /S /Q "%~dpnx0"
"@
            Write-Log -Message "StartupScript: $StartupScript" -Source ${CmdletName}

            [string]$TempRegistryFile = Join-Path -Path $Env:Temp -ChildPath 'ClearSccmSetupBlock.reg'
            Write-Log -Message "TempRegistryFile: $TempRegistryFile" -Source ${CmdletName}

            [string]$StartupRegistry = @"
Windows Registry Editor Version 5.00    

[HKEY_USERS\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer]
"DisallowRun"=dword:00000001

[HKEY_USERS\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\DisallowRun ]
"1"="ccmsetup.exe"

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts]    

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup]    

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\$Number]
"GPO-ID"="LocalGPO"    
"SOM-ID"="Local"    
"FileSysPath"="$Env:SystemDrive\\Windows\\System32\\GroupPolicy\\Machine"    
"DisplayName"="CCMSetup Cleanup Script"
"GPOName"="CCMSetup Cleanup Script"  

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\$Number\0]    
"Script"="$($StageScriptPath.Replace('\','\\'))"
"Parameters"=""    
"ExecTime"=hex(b):00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00    

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts]    

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup]    

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\$Number]
"GPO-ID"="LocalGPO"    
"SOM-ID"="Local"    
"FileSysPath"="$Env:SystemDrive\\Windows\\System32\\GroupPolicy\\Machine"    
"DisplayName"="CCMSetup Cleanup Script"
"GPOName"="CCMSetup Cleanup Script"  

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\$Number\0]    
"Script"="$($StageScriptPath.Replace('\','\\'))"
"Parameters"=""    
"ExecTime"=hex(b):00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00    
"@    
            $StartupRegistry | Out-File -FilePath $TempRegistryFile -Encoding 'ascii' -Force;
            $StartupScript | Out-File -FilePath $StageScriptPath -Encoding 'ascii' -Force;
            Execute-Process -Path "$Env:Windir\System32\Reg.exe" -Parameters "import","$TempRegistryFile" -CreateNoWindow -PassThru;
            Remove-File -Path $TempRegistryFile -ContinueOnError $true;
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message), $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
}
function Get-NextStartupScriptNumber
{
    [CmdletBinding()]
    [outputType([Int32])]
    param()
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [Int32]$ReturnValue = -1;
    }
    Process
    {
        Try
        {
            $RegHive = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,[Microsoft.Win32.RegistryView]::Default)
            $RegKey = $REgHive.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup',$false)
            [Int32]$StartupMax = $RegKey.GetSubKeyNames() | Sort-Object -Descending | Select-Object -First 1
            [Int32]$ReturnValue = $StartupMax+1;
        }
        Catch
        {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        }
        Finally
        {
            $RegKey.Close(); 
            $RegHive.Close();
        }
    }
    End
    {
        Write-Output $ReturnValue
    }
}
function Block-SccmSetup
{
    [CmdletBinding()]
    param()
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process
    {
        Try
        {
            Set-RegistryKey -Key 'HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\DisallowRun' -Name '1' -Value 'ccmsetup.exe' -Type String -SID 'S-1-5-18' -ContinueOnError $true;
        }
        Catch
        {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        }
    }
}
function Allow-SccmSetup
{
    [CmdletBinding()]
    param()
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process
    {
        Try
        {
            [psobject]$RegistryKEy = Get-RegistryKey -Key 'HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\DisallowRun' -ReturnEmptyKeyIfExists -SID 'S-1-5-18' ;
            Write-Log -Message "RegistryKEy: $RegistryKEy" -Source ${CmdletName}

            [string]$RemoveProperty = ($RegistryKEy).PSObject.Properties.Name | ?{$_ -like '[1-9]' }|?{$RegistryKEy.$_ -like 'ccmsetup.exe'} | Select-Object -First 1
            Write-Log -Message "RemoveProperty: $RemoveProperty" -Source ${CmdletName}
            
            If ( [string]::IsNullOrEmpty($RemoveProperty) ) { Throw "Could Not Find 'ccmsetup.exe' in Blocked Registry" }

            Remove-RegistryKey -Key 'HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\DisallowRun' -ReturnEmptyKeyIfExists -SID 'S-1-5-18'  -Name $RemoveProperty -ContinueOnError $true;
        }
        Catch
        {
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
        }
    }
}
Function Schedule-ComputerRestart
{
	[CmdletBinding()]
	param
	(
        [Parameter(Position = 0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({$([DateTime]::Now).CompareTo($_) -le 0})]
        [DateTime]$DateTime
    )
	Begin {		
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
	Process
	{
		Try {
            [Int32]$WaitSeconds = $DateTime.Subtract([DateTime]::Now).TotalSeconds
            Write-Log -Message "WaitSeconds: $WaitSeconds" -Source ${CmdletName}
            Invoke-Expression -Command "Shutdown /f /r /t $($WaitSeconds)" | Out-Null
		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
}
Function Execute-SchTasks
{
<#
.SYNOPSIS
	Invoke SchTasks.Exe
.DESCRIPTION
	Invoke SchTasks.Exe
.PARAMETER Arguments
	Arguments for SchTasks.exe.
.EXAMPLE
	Execute-SchTasks -Arguments '/XML C:\Temp\SCTASK.xml'
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$true)]
		[ValidateNotNullorEmpty()]
		[string[]]$Arguments
	)
	
	Begin 
    {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process 
    {
		Try 
        {
            [string]$SystemDirectory = Split-Path -Parent -Path $Env:Comspec
            [string]$SchTasks = Join-Path -Path $SystemDirectory -ChildPath 'schtasks.exe'
            Write-Log -Message "SchTasks: $SchTasks" -Source ${CmdletName}

            $SchTasksProcess = Execute-Process -Path $SchTasks -Parameters $Arguments -CreateNoWindow -WorkingDirectory $SystemDirectory -PassThru -ContinueOnError $true;
            Write-Log -Message "SchTasksProcess: $($SchTasksProcess | Format-List * | Out-String)" -Source ${CmdletName}

		}
		Catch 
        {
			Write-Log -Message "Exception: $($_.Exception.Message)`n$(Resolve-Error)" -Severity 2 -Source ${CmdletName}
		}
	}
	End {
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
Function Add-StartupInvocation
{
<#
.SYNOPSIS
	Adds A Scheduled Task To Invoke This Deployment Script On Machine Startup
.DESCRIPTION
	Invoke SchTasks.Exe
.PARAMETER Arguments
	Arguments for SchTasks.exe.
.EXAMPLE
	Add-StartupInvocation -Arguments '-ExecuteInstall'
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$false)]
		[ValidateNotNullorEmpty()]
		[string[]]$Arguments,
		[Parameter(Mandatory=$false)]
		[ValidateNotNullorEmpty()]
        [string]$TaskName = $installName,
	    [Parameter(Mandatory=$false)]
	    [ValidateSet('Install','Uninstall')]
	    [string]$Type = $DeploymentType,
	    [Parameter(Mandatory=$false)]
	    [ValidateSet('Interactive','Silent','NonInteractive')]
	    [string]$Mode = $DeployMode,
	    [Parameter(Mandatory=$false)]
	    [switch]$RebootPassThru = $AllowRebootPassThru,
	    [Parameter(Mandatory=$false)]
	    [switch]$TerminalServer = $TerminalServerMode,
	    [Parameter(Mandatory=$false)]
	    [switch]$DisableLog = $DisableLogging
	)
	
	Begin 
    {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header

        #-AllowRebootPassThru 
        #-DisableLogging
        #-TerminalServerMode

        [string]$ArgumentString = "-DeployMode $Mode -DeploymentType $Type";
	}
	Process 
    {
		Try 
        {
            If ( $RebootPassThru ) { $ArgumentString += " -AllowRebootPassThru"; }
            If ( $TerminalServer ) { $ArgumentString += " -TerminalServerMode"; }
            If ( $DisableLog ) { $ArgumentString += " -DisableLogging"; }

            [string]$ArgumentString = $ArgumentString,$($Arguments -join ' ') -join ' '
            Write-Log -Message "ArgumentString: $ArgumentString" -Source ${CmdletName}

            [string]$XmlTempPath = Join-Path -Path $Env:Temp -ChildPath "SchTask.xml";
            Write-Log -Message "XmlTempPath: $XmlTempPath" -Source ${CmdletName}

            [datetime]$Now = [datetime]::Now;
            Write-Log -Message "Now: $($Now | Format-List * | Out-String)" -Source ${CmdletName}

            #region [Write Xml File]
            $(@"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>$($Now.Year)-$($Now.Month)-$($Now.Day)T$($Now.Hour):$($Now.Minute):$($Now.Second).5960682</Date>
    <Author>$($envUserDomain)\$($envUserName)</Author>
  </RegistrationInfo>
  <Triggers>
    <BootTrigger>
      <Enabled>true</Enabled>
    </BootTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>false</UseUnifiedSchedulingEngine>
    <WakeToRun>true</WakeToRun>
    <ExecutionTimeLimit>P3D</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>$($scriptDirectory)\Deploy-Application.exe</Command>
      <Arguments>$ArgumentString</Arguments>
      <WorkingDirectory>$($scriptDirectory)</WorkingDirectory>
    </Exec>
  </Actions>
</Task>            
"@)|Out-File -FilePath $XmlTempPath -Encoding ascii -Force
            #endregion [Write Xml File]

            Execute-SchTasks -Arguments '/Create',"/XML`"$($XmlTempPath)`"",'/F',"/TN `"$($TaskName)`"";

		}
		Catch 
        {
			Write-Log -Message "Exception: $($_.Exception.Message)`n$(Resolve-Error)" -Severity 2 -Source ${CmdletName}
		}
	}
	End 
    {
        If ( Test-Path -Path $XmlTempPath ) { Remove-Item -Path $XmlTempPath -Force -ErrorAction 'SilentlyContinue' | Out-Null; }
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
Function Remove-StartupInvocation
{
<#
.SYNOPSIS
	Invoke SchTasks.Exe
.DESCRIPTION
	Invoke SchTasks.Exe
.PARAMETER Arguments
	Arguments for SchTasks.exe.
.EXAMPLE
	Execute-SchTasks -Arguments '/XML C:\Temp\SCTASK.xml'
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$false)]
		[ValidateNotNullorEmpty()]
		[string]$TaskName = $installName
	)
	
	Begin 
    {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process 
    {
		Try 
        {
            Execute-SchTasks -Arguments "/Delete /TN `"$($TaskName)`" /F"
		}
		Catch 
        {
			Write-Log -Message "Exception: $($_.Exception.Message)`n$(Resolve-Error)" -Severity 2 -Source ${CmdletName}
		}
	}
	End {
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
Function Block-AppExecutionSilently 
{
<#
.SYNOPSIS
	Block the execution of an application(s)
.DESCRIPTION
	This function is called when you pass the -BlockExecution parameter to the Stop-RunningApplications function. It does the following:
	1. Makes a copy of this script in a temporary directory on the local machine.
	2. Checks for an existing scheduled task from previous failed installation attempt where apps were blocked and if found, calls the Unblock-AppExecution function to restore the original IFEO registry keys.
	   This is to prevent the function from overriding the backup of the original IFEO options.
	3. Creates a scheduled task to restore the IFEO registry key values in case the script is terminated uncleanly by calling the local temporary copy of this script with the parameter -CleanupBlockedApps.
	4. Modifies the "Image File Execution Options" registry key for the specified process(s) to call this script with the parameter -ShowBlockedAppDialog.
	5. When the script is called with those parameters, it will display a custom message to the user to indicate that execution of the application has been blocked while the installation is in progress.
	   The text of this message can be customized in the XML configuration file.
.PARAMETER ProcessName
	Name of the process or processes separated by commas
.EXAMPLE
	Block-AppExecution -ProcessName ('winword','excel')
.NOTES
	This is an internal script function and should typically not be called directly.
	It is used when the -BlockExecution parameter is specified with the Show-InstallationWelcome function to block applications.
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		## Specify process names separated by commas
		[Parameter(Mandatory=$true)]
		[ValidateNotNullorEmpty()]
		[string[]]$ProcessName
	)
	
	Begin {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
		
		## Remove illegal characters from the scheduled task arguments string
		[char[]]$invalidScheduledTaskChars = '$', '!', '''', '"', '(', ')', ';', '\', '`', '*', '?', '{', '}', '[', ']', '<', '>', '|', '&', '%', '#', '~', '@'
		[string]$SchInstallName = $installName
		ForEach ($invalidChar in $invalidScheduledTaskChars) { [string]$SchInstallName = $SchInstallName -replace [regex]::Escape($invalidChar),'' }
		[string]$schTaskUnblockAppsCommand += "-ExecutionPolicy Bypass -NoProfile -NoLogo -WindowStyle Hidden -File `"$dirAppDeployTemp\$scriptFileName`" -CleanupBlockedApps -ReferrredInstallName `"$SchInstallName`" -ReferredInstallTitle `"$installTitle`" -ReferredLogName `"$logName`" -AsyncToolkitLaunch"
		## Specify the scheduled task configuration in XML format
		[string]$xmlUnblockAppsSchTask = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
	<RegistrationInfo></RegistrationInfo>
	<Triggers>
		<BootTrigger>
			<Enabled>true</Enabled>
		</BootTrigger>
	</Triggers>
	<Principals>
		<Principal id="Author">
			<UserId>S-1-5-18</UserId>
		</Principal>
	</Principals>
	<Settings>
		<MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
		<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
		<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
		<AllowHardTerminate>true</AllowHardTerminate>
		<StartWhenAvailable>false</StartWhenAvailable>
		<RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
		<IdleSettings>
			<StopOnIdleEnd>false</StopOnIdleEnd>
			<RestartOnIdle>false</RestartOnIdle>
		</IdleSettings>
		<AllowStartOnDemand>true</AllowStartOnDemand>
		<Enabled>true</Enabled>
		<Hidden>false</Hidden>
		<RunOnlyIfIdle>false</RunOnlyIfIdle>
		<WakeToRun>false</WakeToRun>
		<ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
		<Priority>7</Priority>
	</Settings>
	<Actions Context="Author">
		<Exec>
			<Command>powershell.exe</Command>
			<Arguments>$schTaskUnblockAppsCommand</Arguments>
		</Exec>
	</Actions>
</Task>
"@
	}
	Process {
		## Bypass if in NonInteractive mode
		If ($deployModeNonInteractive) {
			Write-Log -Message "Bypassing Function [${CmdletName}] [Mode: $deployMode]." -Source ${CmdletName}
			Return
		}
		
		[string]$schTaskBlockedAppsName = $installName + '_BlockedApps'
		
		## Delete this file if it exists as it can cause failures (it is a bug from an older version of the toolkit)
		If (Test-Path -LiteralPath "$configToolkitTempPath\PSAppDeployToolkit" -PathType 'Leaf' -ErrorAction 'SilentlyContinue') {
			$null = Remove-Item -LiteralPath "$configToolkitTempPath\PSAppDeployToolkit" -Force -ErrorAction 'SilentlyContinue'
		}
		## Create Temporary directory (if required) and copy Toolkit so it can be called by scheduled task later if required
		If (-not (Test-Path -LiteralPath $dirAppDeployTemp -PathType 'Container' -ErrorAction 'SilentlyContinue')) {
			$null = New-Item -Path $dirAppDeployTemp -ItemType 'Directory' -ErrorAction 'SilentlyContinue'
		}
		
		Copy-Item -Path "$scriptRoot\*.*" -Destination $dirAppDeployTemp -Exclude 'thumbs.db' -Force -Recurse -ErrorAction 'SilentlyContinue'
		
		## Build the debugger block value script
		[string]$debuggerBlockMessageCmd = "`"powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -WindowStyle Hidden -File `" & chr(34) & `"$dirAppDeployTemp\$scriptFileName`" & chr(34) & `" -ShowBlockedAppDialog -AsyncToolkitLaunch -ReferredInstallTitle `" & chr(34) & `"$installTitle`" & chr(34)"
		[string[]]$debuggerBlockScript = "strCommand = $debuggerBlockMessageCmd"
		$debuggerBlockScript += 'set oWShell = CreateObject("WScript.Shell")'
		#$debuggerBlockScript += 'oWShell.Run strCommand, 0, false'
		$debuggerBlockScript | Out-File -FilePath "$dirAppDeployTemp\AppDeployToolkit_BlockAppExecutionMessage.vbs" -Force -Encoding 'default' -ErrorAction 'SilentlyContinue'
		[string]$debuggerBlockValue = "wscript.exe `"$dirAppDeployTemp\AppDeployToolkit_BlockAppExecutionMessage.vbs`""
		
		## Create a scheduled task to run on startup to call this script and clean up blocked applications in case the installation is interrupted, e.g. user shuts down during installation"
		Write-Log -Message 'Create scheduled task to cleanup blocked applications in case installation is interrupted.' -Source ${CmdletName}
		If (Get-ScheduledTask -ContinueOnError $true | Select-Object -Property 'TaskName' | Where-Object { $_.TaskName -eq "\$schTaskBlockedAppsName" }) {
			Write-Log -Message "Scheduled task [$schTaskBlockedAppsName] already exists." -Source ${CmdletName}
		}
		Else {
			## Export the scheduled task XML to file
			Try {
				#  Specify the filename to export the XML to
				[string]$xmlSchTaskFilePath = "$dirAppDeployTemp\SchTaskUnBlockApps.xml"
				[string]$xmlUnblockAppsSchTask | Out-File -FilePath $xmlSchTaskFilePath -Force -ErrorAction 'Stop'
			}
			Catch {
				Write-Log -Message "Failed to export the scheduled task XML file [$xmlSchTaskFilePath]. `n$(Resolve-Error)" -Severity 2 -Source ${CmdletName}
				Return
			}
			
			## Import the Scheduled Task XML file to create the Scheduled Task
			[psobject]$schTaskResult = Execute-Process -Path $exeSchTasks -Parameters "/create /f /tn $schTaskBlockedAppsName /xml `"$xmlSchTaskFilePath`"" -WindowStyle 'Hidden' -CreateNoWindow -PassThru
			If ($schTaskResult.ExitCode -ne 0) {
				Write-Log -Message "Failed to create the scheduled task [$schTaskBlockedAppsName] by importing the scheduled task XML file [$xmlSchTaskFilePath]." -Severity 2 -Source ${CmdletName}
				Return
			}
		}
		
		[string[]]$blockProcessName = $processName
		## Append .exe to match registry keys
		[string[]]$blockProcessName = $blockProcessName | ForEach-Object { $_ + '.exe' } -ErrorAction 'SilentlyContinue'
		
		## Enumerate each process and set the debugger value to block application execution
		ForEach ($blockProcess in $blockProcessName) {
			Write-Log -Message "Set the Image File Execution Option registry key to block execution of [$blockProcess]." -Source ${CmdletName}
			Set-RegistryKey -Key (Join-Path -Path $regKeyAppExecution -ChildPath $blockProcess) -Name 'Debugger' -Value $debuggerBlockValue -ContinueOnError $true
		}
	}
	End {
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
Function Block-CCMSetup
{
	[CmdletBinding()]
	param
	(
        [ValidateNotNullOrEmptY()]
        [ValidateScript({})]
        [string]$Psexec = $global:PsexecExe
    )
	
	Begin {		
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
	Process
	{
		[string]${CmdletSection} = "Process"
		Try {
            Block-AppExecutionSilently -ProcessName 'ccmsetup';
		}
		Catch {f
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
}
#endregion [Task Scheduler]
##*===============================================

##*===============================================
#region [QueryLanguage]
function Invoke-SQL
{
    [CmdletBinding()]
    [outputtype([psobject[]])]
    param(
            
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('q')]
        [string] $Query,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [Alias('src')]
        [string] $DataSource = $CCM_CAS_SQLDATASOURCE,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [Alias('cmdb')]
        [string] $Database = $CCM_CAS_SQLDATABASE

    )
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [psobject[]]$ReturnValue=@()
    }
    Process {
        Try  { 
            $connectionString = "Data Source=$dataSource; " +
                    "Integrated Security=SSPI; " +
                    "Initial Catalog=$database"

            $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
            $command = new-object system.data.sqlclient.sqlcommand($Query,$connection)
            $connection.Open()

            $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
            $dataset = New-Object System.Data.DataSet
            $adapter.Fill($dataSet) | Out-Null

            $connection.Close()
            [psobject[]]$ReturnValue = $dataSet.Tables
        } 
        Catch  { 
            Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2 
        }     
    }
    End {
        Write-Output -InputObject $ReturnVAlue
    }
}
#endregion [QueryLanguage]
##*===============================================

##*===============================================
#region [Network]
function Get-ActiveNetworkInterfaces {
    [CmdletBinding(DefaultParameterSetName = 'ByValue')]
    [OutputType([psobject[]],ParameterSetName = 'ByValue')]
    param (
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Log -Source ${CmdletName} -Message "Executing '${CmdletName}'...."
        [string]$IPRegex='(?<First>2[0-4]\d|25[0-5]|[01]?\d\d?)\.(?<Second>2[0-4]\d|25[0-5]|[01]?\d\d?)\.(?<Third>2[0-4]\d|25[0-5]|[01]?\d\d?)\.(?<Fourth>2[0-4]\d|25[0-5]|[01]?\d\d?)'
        [psobject[]]$ReturnValue = @();
    }
    Process {
        [string[]]$Adapters = $((Invoke-Expression -Command "netsh interface ipv4 show addresses") -join "`r`n") -split "Configuration for interface "|?{$_ -match 'DHCP enabled:.*Yes' -and $_ -match 'IP Address:' -and $_ -notmatch '169\.\d{3}\..*'}
        Write-Log -Message "Found $($Adapters.Count) Interfaces."  -Source ${CmdletName}
        $Adapters | %{
            Try {
                    [string]$AdapterName = ([regex]'(?<=")(.*)(?=")').Matches($_)|select -first 1 -ExpandProperty value
                    [string]$IPAddress = ([regex]"(?<=IP Address:.*)($IPRegex)(?=\r)").Matches($_)|select -first 1 -ExpandProperty value
                    [string]$IPMask = ([regex]"(?<=mask )($IPRegex)(?=\)\r)").Matches($_)|select -first 1 -ExpandProperty value
                    $ReturnValue += $(
                        New-Object -TypeName PSObject -Property @{
                            Name=$AdapterName;
                            IPAddress=$IPAddress;
                            SubnetMask = $IPMask;
                        }
                    )
            }
            Catch {
                Write-Log -Message "Exception: '$($_.Exception.Message)'`r`nLine Number:[$($_.InvocationInfo.ScriptLineNumber)]" -Source ${CmdletName} -Severity 2;
            }
        }
    }
    End {
        Write-Output -InputObject $ReturnValue
    }
}
function Get-ActiveNetworkAddresses {
    [CmdletBinding(DefaultParameterSetName = 'ByValue')]
    [OutputType([string[]],ParameterSetName = 'ByValue')]
    param ()
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Log -Source ${CmdletName} -Message "Executing '${CmdletName}'...."

        [string[]]$ReturnValue = @();
    }
    Process {
        Try {
            $IPRegex='(?<First>2[0-4]\d|25[0-5]|[01]?\d\d?)\.(?<Second>2[0-4]\d|25[0-5]|[01]?\d\d?)\.(?<Third>2[0-4]\d|25[0-5]|[01]?\d\d?)\.(?<Fourth>2[0-4]\d|25[0-5]|[01]?\d\d?)'
            [System.Net.Dns]::GetHostEntry($env:computername) | `
                Select-Object -ExpandProperty AddressList -First 1 `
            |  Where-Object {
                 $_.AddressFamily -notlike 'InterNetworkV6' `
                 -and `
                 $_.IPAddressToString -match $IPRegex
            } | Select-Object -ExpandProperty 'IPAddressToString' | %{
                $ReturnValue += $_
            }
        }
        Catch {
            Write-Log -Message "Exception: '$($_.Exception.Message)'`r`nLine Number:[$($_.InvocationInfo.ScriptLineNumber)]" -Source ${CmdletName} -Severity 2;
        }
    }
    End {
        Write-Output -InputObject $ReturnValue
    }
}
function Get-IPSubnetMask {
    [CmdletBinding(DefaultParameterSetName = 'ByValue')]
    [OutputType([string],ParameterSetName = 'ByValue')]
    param (
		[Parameter(ParameterSetName = 'ByValue',Mandatory = $true,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('(?<First>2[0-4]\d|25[0-5]|[01]?\d\d?)\.(?<Second>2[0-4]\d|25[0-5]|[01]?\d\d?)\.(?<Third>2[0-4]\d|25[0-5]|[01]?\d\d?)\.(?<Fourth>2[0-4]\d|25[0-5]|[01]?\d\d?)')]
        [System.String]$IPAddress,

		[Parameter(ParameterSetName = 'ByValue',Mandatory = $false,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 0)]
        [ValidateNotNullOrEmpty()]
        [System.String]$DomainName = $((([regex]'(?<=,DC=)(\w*)(?=($|,))').Matches($($(get-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine' -Value 'Distinguished-Name') ))|Select-Object -ExpandProperty Value) -join '.')
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Log -Source ${CmdletName} -Message "Executing '${CmdletName}'...."
        [string]$ReturnValue = [string]::Empty;
        [string]$IPRegex='(?<First>2[0-4]\d|25[0-5]|[01]?\d\d?)\.(?<Second>2[0-4]\d|25[0-5]|[01]?\d\d?)\.(?<Third>2[0-4]\d|25[0-5]|[01]?\d\d?)\.(?<Fourth>2[0-4]\d|25[0-5]|[01]?\d\d?)'
    }
    Process {
        Try {
            [string]$ReturnValue = Invoke-Expression -Command "ipconfig /all" | Select-String "$IPAddress" -Context 0,10 | Select-Object -ExpandProperty 'Context' -First 1  |%{$_.PostContext}|?{ $_ -like '*Subnet Mask*' }|%{$(([regex]$IPRegex).Matches($_)|Select-Object -First 1 -ExpandProperty 'Value')}
        }
        Catch {
            Write-Log -Message "Exception: '$($_.Exception.Message)'`r`nLine Number:[$($_.InvocationInfo.ScriptLineNumber)]" -Source ${CmdletName} -Severity 2;
        }
    }
    End {
        Write-Output -InputObject $ReturnValue
    }
}
function Select-NetworkAddress {
    [CmdletBinding(DefaultParameterSetName = 'ByValue')]
    [OutputType([psobject],ParameterSetName = 'ByValue')]
    param (
		[Parameter(ParameterSetName = 'ByValue',Mandatory = $false,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 0)]
        [ValidateNotNullOrEmpty()]
        [System.String]$DomainName = $(Get-ADDomainName)
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Log -Source ${CmdletName} -Message "Executing '${CmdletName}'...."
        [psobject]$ReturnValue = New-Object -TypeName System.Management.Automation.PSObject;
    }
    Process {
        Try {
           [psobject]$ReturnValue =  Get-ActiveNetworkInterfaces | ?{ (Invoke-Expression "ipconfig"  |   Select-String "Connection-specific DNS Suffix.*$DomainName.*",".*IPv4 Address.*$($_.IPAddress)",".*Subnet Mask.*$($_.SubnetMask)").Matches.Count  -eq 3  }|Sort-Object -Property Name |  Select -First 1
        }
        Catch {
            Write-Log -Message "Exception: '$($_.Exception.Message)'`r`nLine Number:[$($_.InvocationInfo.ScriptLineNumber)]" -Source ${CmdletName} -Severity 2;
        }
    }
    End {
        Write-Output -InputObject $ReturnValue
    }
}
function Get-SubnetDetails {
    [CmdletBinding(DefaultParameterSetName = 'ByValue')]
    [OutputType([string],ParameterSetName = 'ByValue')]
    param (
		[Parameter(ParameterSetName = 'ByValue',Mandatory = $false,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('(?<First>2[0-4]\d|25[0-5]|[01]?\d\d?)\.(?<Second>2[0-4]\d|25[0-5]|[01]?\d\d?)\.(?<Third>2[0-4]\d|25[0-5]|[01]?\d\d?)\.(?<Fourth>2[0-4]\d|25[0-5]|[01]?\d\d?)')]
        [System.String]$IPAddress = $(If([string]::IsNullOrEmpty($GLOBAL:CCM_NETWORK_IP)){$(Select-NetworkAddress).IPAddress}Else{$GLOBAL:CCM_NETWORK_IP}),

		[Parameter(ParameterSetName = 'ByValue',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $true,Position = 1)]
        [ValidateNotNullOrEmpty()]
        [System.String]$SubnetMask = $(If([string]::IsNullOrEmpty($GLOBAL:CCM_NETWORK_SUBNET_MASK)){$(Select-NetworkAddress).SubnetMask}Else{$GLOBAL:CCM_NETWORK_SUBNET_MASK})
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Log -Source ${CmdletName} -Message "Executing '${CmdletName}'...."

        [psobject]$ReturnValue = New-Object -TypeName System.Management.Automation.PSObject;
    }
    Process {
        Try {
            
            [psobject]$ReturnValue = Get-NetworkSummary -IPAddress $IPAddress -SubnetMask $SubnetMask;
            $ReturnValue | Add-Member -MemberType NoteProperty -Name 'MinimumHost' -Value $($ReturnValue.HostRange -split ' - ' |  select -first 1) -Force;
            $ReturnValue | Add-Member -MemberType NoteProperty -Name 'MinimumHostDecimal' -Value $(ConvertTo-DecimalIP -IPAddress $ReturnValue.MinimumHost) -Force;

            $ReturnValue | Add-Member -MemberType NoteProperty -Name 'MaximumHost' -Value $($ReturnValue.HostRange -split ' - ' |  select -last 1) -Force;
            $ReturnValue | Add-Member -MemberType NoteProperty -Name 'MaximumHostDecimal' -Value $(ConvertTo-DecimalIP -IPAddress $ReturnValue.MaximumHost) -Force;
            
        }
        Catch {
            Write-Log -Message "Exception: '$($_.Exception.Message)'`r`nLine Number:[$($_.InvocationInfo.ScriptLineNumber)]" -Source ${CmdletName} -Severity 2;
        }
    }
    End {
        Write-Output -InputObject $ReturnValue
    }
}
Function Download-CMClientSetup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$true,Position=0)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Server = @($NomadCores),

        [Parameter(Mandatory=$True, ValueFromPipeline=$false,Position=1)]
        [ValidateNotNullOrEmpty()]
        [string]$Destination,

        [Parameter(Mandatory=$False, ValueFromPipeline=$false,Position=2)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageID = $CCMSetupPackageID,

        [Parameter(Mandatory=$False, ValueFromPipeline=$false,Position=3)]
        [ValidateNotNullOrEmpty()]
        [string]$FallbackURL = $DefaultInstallSourcePath
    )
 	Begin
	{
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
	Process
	{
		Try
		{
            [string]$PackageVersion = Gwmi -ComputerName VCLD11GPSCCMC01 -Namespace 'root\sms\site_cas' -Query "Select SourceVersion From SMS_Package Where PackageID='$PackageID'" -DirectRead -AsJob | Wait-Job | Receive-Job |select -ExpandProperty SourceVersion -first 1   
            Write-Log -Message "PackageVersion: $PackageVersion" -Source ${CmdletName}

            If ( [string]::IsNullOrEmpty($PackageVersion) ) { Throw "Unable to determine package version of '$PackageID'" }
            Foreach ( $HostName in $Server ) {
                Try {
                    [string]$Uri = 'http://' + $HostName + '/SMS_DP_PKG$/' + $PackageID + '.' + $PackageVersion
                    Write-Log -Message "Uri: $Uri" -Source ${CmdletName}

                    If ( !(Test-URI -URI $Uri) ) {Throw "URL Validation Failed for '$Uri'"}

                    Write-Log -Message "Downloading URL '$Uri' to directory '$Destination'...." -Source ${CmdletName}
                    Download-WebDirectory -Source $uri -Destination $Destination -Recurse -Force
                    Write-Log -Message "Done. ($?)" -Source ${CmdletName}
                }
                Catch {
                    Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
                }
            }
		}
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
 }
#endregion [Network]
##*===============================================

##*===============================================
#region [Settings]

#endregion [Settings]
##*===============================================

##*===============================================
#region [Helpers]
Function Download-WebDirectory  
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false,ValueFromPipeline=$true, Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('(?<=(http|https):\/\/)((\w+|\.)+)(?=(:\d{1,6}|\/?))')]
        [Alias('URL')]
        [string]$Source, 

        [Parameter(Mandatory = $true,ValueFromPipeline=$false, Position=1)]
        [ValidateNotNullOrEmpty()]
        [string]$Destination, 

        [Parameter(Mandatory = $false,ValueFromPipeline=$true, Position=2)]
        [switch]$Recurse = $false,

        [Parameter(Mandatory = $false,ValueFromPipeline=$true, Position=3)]
        [switch]$Force = $false
    )
    Begin {
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSCmdlet.MyInvocation.BoundParameters -Header
    }
    Process {
        Try{
            if ((Test-Path $Destination -ErrorAction SilentlyContinue) -and $Force) {
                Remove-File -Path "$Destination\*.*" -Recurse -ContinueOnError $true;
            }
            elseif((Test-Path $Destination -ErrorAction SilentlyContinue) -and !$Force){
                Throw "Directory '$Destination' Already Exists.  Use the '-Force' Parameter To Ovverride"
            }
            New-Folder -Path $Destination -ContinueOnError $true;

            [System.Net.WebClient]$WebClient = New-Object -TypeName 'System.Net.WebClient'
            
            # Get the file list from the web page
            $webString = $webClient.DownloadString($source)
            Write-Log -Message "webString: $webString" -Source ${CmdletName}

            $lines = [Regex]::Split($webString, "<br>")
            Write-Log -Message "lines: $lines" -Source ${CmdletName}

            # Parse each line, looking for files and folders
            foreach ($line in $lines) {
                if ($line.ToUpper().Contains("HREF")) {
                    # File or Folder
                    if (!$line.ToUpper().Contains("[TO PARENT DIRECTORY]")) {
                        # Not Parent Folder entry
                        $items =[Regex]::Split($line, """")
                        $items = [Regex]::Split($items[2], "(>|<)")
                        $item = $items[2]
                        Write-Log -Message "item: $item" -Source ${CmdletName}

                        [string]$SourceUrl= "$item"
                        Write-Log -Message "SourceUrl: $SourceUrl" -Source ${CmdletName}

                        [string]$DestinationPath="$destination\$($item.Split('/')|select -last 1)" 
                        Write-Log -Message "DestinationPath: $DestinationPath" -Source ${CmdletName}
                        
                        if ($line.ToLower().Contains("&lt;dir&gt")) {
                            # Folder
                            if ($Recurse) {
                                # Subfolder copy required
                                
                                Download-WebDirectory -Source $SourceURL -Destination $DestinationPath -Recurse;
                            } else {
                                # Subfolder copy not required
                            }
                        } else {
                            # File
                            $webClient.DownloadFile($SourceUrl, $DestinationPath)
                        }
                    }
                }
            }
        }
        Catch {
            Write-Log -Message "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
        Finally{
            $WeBClient.Dispose()|OUT-NULL
        }
    }
}
Function Start-BackGroundJob
{
    Param(
         $ScriptBlock,
         $WorkerCredentials
         )

        Try{
            $ComputerName = $Global:Queue.Dequeue()
            $J = Start-Job -ScriptBlock $ScriptBlock -ArgumentList $ComputerName -Name $ComputerName -ErrorAction STOP @WorkerCredentials
            [Void]$Global:Jobs.Add($J.Id)
            Write-Log -Message "Created JOB for $($J.Name)" -severity 1 -component "Start-BackGroundJob"
        }
        Catch{
            #Get-ErrorInformation -Component "Start-BackGroundJob"
        }           
}
function ConvertTo-Xml 
{
    [CmdletBinding(DefaultParameterSetName = 'ByValue')]
    [OutputType([string],ParameterSetName = 'ByValue')]
    param (
		[Parameter(ParameterSetName = 'ByValue',Mandatory = $true,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Xml')]
        [Xml]$InputObject,

		[Parameter(ParameterSetName = 'ByValue',Mandatory = $false,ValueFromPipeline = $false,ValueFromPipelineByPropertyName = $true,ValueFromRemainingArguments = $false,Position = 1)]
        [ValidateNotNullOrEmpty()]
        [ValidateRange(0,10)]
        [Int32]$Indent = 2
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Log -Source ${CmdletName} -Message "Executing '${CmdletName}'...."

        [string]$ReturnValue = [string]::Empty
    }
    Process {
        Try {
            $StringWriter = New-Object System.IO.StringWriter
            $XmlWriter = New-Object System.XMl.XmlTextWriter $StringWriter
            $xmlWriter.Formatting = "indented"
            $xmlWriter.Indentation = $Indent
            $InputObject.WriteContentTo($XmlWriter)
            $XmlWriter.Flush()
            $StringWriter.Flush()            
            
            ## Set Return Value
            [string]$ReturnValue = $StringWriter.ToString();
        }
        Catch {
            Write-Log -Message "Exception: '$($_.Exception.Message)'`r`nLine Number:[$($_.InvocationInfo.ScriptLineNumber)]" -Source ${CmdletName} -Severity 2;
        }
    }
    End {
        Write-Output -InputObject $ReturnValue
    }
}
Function Is-64Bit
{
    [CmdletBinding()]
    [OutputType([bool])]
    param()
 	Begin
	{
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
        [bool]$ReturnValue = $false;
    }
	Process
	{
		Try {
            [bool]$ReturnValue = (Get-OSArchitecture) -match '(64)'
		}
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
    End
    {
        Write-Output -InputObject $ReturnValue
    }

 }
Function Get-OSMajorVersion
{
	[CmdletBinding()]
	param
	(
        [switch]$AltFormat=$false
    )
	Begin {		
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
	Process
	{
		Try {
            [string]$OSVersionStr = Get-WmiObject -Class Win32_OperatingSystem -Property 'Caption' -Ea SilentlyContinue| Select -First 1 -ExpandProperty 'Caption';
            Write-Log -Message "OSVersionStr: $OSVersionStr" -Source ${CmdletName}

            [string]$ProductName = Get-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Value 'ProductName' -ContinueOnError $true
            Write-Log -Message "BuildLabEx: $BuildLabEx" -Source ${CmdletName}

            If ( ![string]::IsNullOrEmpty($OSVersionStr)){  
                [string]$JudgeValue = $OSVersionStr;
            }
            ElseIf ( ![string]::IsNullOrEmpty($ProductName)){     
                [string]$JudgeValue = $ProductName;
            }
           Else {
                Throw "Unable To Detect OS Version."
            }
            If ( $JudgeValue -match '(Windows XP)'){
                If ( (Get-OSArchitecture) -like 'X64' ) {
                    [string]$ReturnValue = '5.2'
                }
                Else {
                    [string]$ReturnValue = '5.1'
                }
            }
            ElseIf ( $JudgeValue -match '(Vista)'){
                [string]$ReturnValue = '6.0';
            }
            ElseIf ( $JudgeValue -match '(Windows 7)'){
                [string]$ReturnValue = '6.1';
            }
            ElseIf ( $JudgeValue -match '(Windows 8 )'){
                [string]$ReturnValue = '6.2';
            }
            ElseIf ( $JudgeValue -match '(Windows 8.1)'){
                [string]$ReturnValue = '6.3';
            }
            ElseIf ( $JudgeValue -match '(Windows 10)'){
                [string]$ReturnValue = '10.0';
            }
		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
    End{
        Write-Output -InputObject $ReturnValue
    }
}
Function Get-OSArchitecture
{
	[CmdletBinding()]
	param
	(
        [switch]$AltFormat=$false
    )
	Begin {		
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
	Process
	{
		Try {
            [string]$OSArchiecture = Get-WmiObject -Class Win32_OperatingSystem -Property 'OSArchitecture' -Ea SilentlyContinue| Select -First 1 -ExpandProperty 'OSArchitecture';
            Write-Log -Message "OSArchiecture: $OSArchiecture" -Source ${CmdletName}

            [string]$BuildLabEx = Get-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Value 'BuildLabEx' -ContinueOnError $true
            Write-Log -Message "BuildLabEx: $BuildLabEx" -Source ${CmdletName}

            If ( ![string]::IsNullOrEmpty($OSArchiecture)){
                If ( $OSArchiecture -match '(64)' ) {
                    [string]$ReturnValue = 'x64'
                    [string]$AltFormatStr = 'x64';
                }
                ElseIf ( $OSArchiecture -match '(32)' ) {
                    [string]$ReturnValue = 'X86'
                    [string]$AltFormatStr = 'i386';
                }            
            }
            ElseIf ( ![string]::IsNullOrEmpty($BuildLabEx)){
                If ( $BuildLabEx -match '(amd64)' ) {
                    [string]$ReturnValue = 'X64'
                    [string]$AltFormatStr = 'x64';
                }
                ElseIf ( $BuildLabEx -match '(x86)' ) {
                    [string]$ReturnValue = 'X86'
                    [string]$AltFormatStr = 'i386';
                }            
            }
           Else {
                Throw "Unable To Detect OS Architecture."
            }
		}
		Catch {
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
    End{
        If ($AltFormat){$ReturnValue=$AltFormatStr}
        Write-Output -InputObject $ReturnValue
    }
}
Function Get-PSCommonParameterNames
{
    [CmdletBinding()]
    [OUtputType([string[]])]
    param()
    process
    {
        [string[]]$ReturnValue = @([System.Management.Automation.PSCmdlet]::CommonParameters +  [System.Management.Automation.PSCmdlet]::OptionalCommonParameters);
    }
    end{
        Write-Output -InputObject $ReturnValue
    }
}
function Invoke-FtpDownload
{
    [CmdletBinding()]
    param([System.Uri]$url, [System.Net.NetworkCredential]$credentials = $(New-Object System.Net.NetworkCredential "anonymous","anonymous"), [string]$localPath,[string]$Filter='*')
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
    Process
    {
        Try
        {
            $listRequest = [Net.WebRequest]::Create($url)
    
            $listRequest.Method = [System.Net.WebRequestMethods+FTP]::ListDirectoryDetails
            $listRequest.Credentials = $credentials

            $lines = New-Object System.Collections.ArrayList

            $listResponse = $listRequest.GetResponse()
            $listStream = $listResponse.GetResponseStream()
            $listReader = New-Object System.IO.StreamReader($listStream)
            while (!$listReader.EndOfStream)
            {
                $line = $listReader.ReadLine()
                $lines.Add($line) | Out-Null
            }
    

            $listReader.Dispose()
            $listStream.Dispose()
            $listResponse.Dispose()

            foreach ($line in $lines)
            {
                Write-Log -Message "Line: $Line" -Source ${CmdletName}
        
                $tokens = $line.Split(" ", 9, [StringSplitOptions]::RemoveEmptyEntries)
                $name = $tokens[8]
                $name = $line.split(' ')|?{![string]::IsNullOrEmpty($_)}|select -last 1
                $permissions = $tokens[0]

                $localFilePath = Join-Path $localPath $name
                Write-Log -Message "localFilePath: $localFilePath" -Source ${CmdletName}

                $fileUrl = ($url.AbsoluteUri,$name -join '/')
                Write-Log -Message "fileUrl: $fileUrl" -Source ${CmdletName}
        
                if (![io.path]::HasExtension($name))
                {
                    if (!(Test-Path $localFilePath -PathType container))
                    {
                        Write-Log ("Creating directory {0}" -f $localFilePath) -Source ${CmdletName}
                        New-Item $localFilePath -Type directory | Out-Null
                    }

                    Invoke-FtpDownload -url $([System.URI]::new(($fileUrl + "/"))) -credentials $credentials -localPath $localFilePath
                }
                ElseIf ( $name -like $Filter )
                {
                    Write-Log ("Downloading {0} to {1}" -f $fileUrl, $localFilePath) -Source ${CmdletName}

                    $downloadRequest = [Net.WebRequest]::Create($fileUrl)
                    $downloadRequest.Method = [System.Net.WebRequestMethods+FTP]::DownloadFile
                    $downloadRequest.Credentials = $credentials

                    $downloadResponse = $downloadRequest.GetResponse()
                    $sourceStream = $downloadResponse.GetResponseStream()
                    $targetStream = [System.IO.File]::Create($localFilePath)
                    $buffer = New-Object byte[] 10240
                    while (($read = $sourceStream.Read($buffer, 0, $buffer.Length)) -gt 0)
                    {
                        $targetStream.Write($buffer, 0, $read);
                    }
                    $targetStream.Dispose()
                    $sourceStream.Dispose()
                    $downloadResponse.Dispose()
                }
            }
        }
        Catch
        {
            Write-Log -Message "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2;
        }
    }
    End
    {
    
    }
}
Function Invoke-Robocopy
{

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true,Position = 0,ValueFromPipelineByPropertyName = $true)]
        [ValidateLength(1, 1024)]
        [Alias('FullName')]
        [string[]]$Path,

        [Parameter(Mandatory = $false,Position = 1)]
        [Alias('DestinationPath')]
        [string]$Destination,


        [Parameter(Mandatory = $false,Position = 2)]
        [Alias('Include')]
        [string[]]$Filter = @(),

        [Parameter(Mandatory = $false)]
        [Alias('E')]
        [switch]$Subfolders = $false,

        [Parameter(Mandatory = $false)]
        [Alias('ZB')]
        [switch]$Restartable = $false,

        [Parameter(Mandatory = $false)]
        [Alias('J')]
        [switch]$NoBuffer = $false,

        [Parameter(Mandatory = $false)]
        [Alias('EFSRAW')]
        [switch]$EncryptedFiles = $false,

        [Parameter(Mandatory = $false)]
        [Alias('COPY_COLON_VALUE')]
        [ValidateSet('D','A','T','S','O','U')]
        [string[]]$FileCopyFlags = @(),

        [Parameter(Mandatory = $false)]
        [Alias('SEC')]
        [switch]$CopySecurityInfo = $false,

        [Parameter(Mandatory = $false)]
        [Alias('COPYALL')]
        [switch]$CopyAllInfo = $false,

        [Parameter(Mandatory = $false)]
        [Alias('NOCOPY')]
        [switch]$CopyNoInfo = $false,

        [Parameter(Mandatory = $false)]
        [Alias('SECFIX')]
        [switch]$FixSecurity = $false,

        [Parameter(Mandatory = $false)]
        [Alias('TIMFIX')]
        [switch]$FixTime = $false,

        [Parameter(Mandatory = $false)]
        [Alias('PURGE')]
        [switch]$PurgeFiles = $false,

        [Parameter(Mandatory = $false)]
        [Alias('MIR')]
        [switch]$Mirror = $false,

        [Parameter(Mandatory = $false)]
        [Alias('MOV')]
        [switch]$MoveFiles = $false,

        [Parameter(Mandatory = $false)]
        [Alias('MOVE')]
        [switch]$MoveAll = $false,

        [Parameter(Mandatory = $false)]
        [Alias('AP_COLON_VALUE')]
        [ValidateSet('D','A','T','S','O','U')]
        [string[]]$AddAttributes = @(),

        [Parameter(Mandatory = $false)]
        [Alias('AM_COLON_VALUE')]
        [ValidateSet('D','A','T','S','O','U')]
        [string[]]$RemoveAttributes = @(),

        [Parameter(Mandatory = $false)]
        [Alias('CREATE')]
        [switch]$DirectoryTree = $false,

        [Parameter(Mandatory = $false)]
        [Alias('FAT')]
        [switch]$FAT32FileNames = $false,

        [Parameter(Mandatory = $false)]
        [Alias('MON_COLON_VALUE')]
        [Int32]$MonitorSourceByChanges = -1,

        [Parameter(Mandatory = $false)]
        [Alias('MOT_COLON_VALUE')]
        [Int32]$MonitorSourceByMinutes = -1,

        [Parameter(Mandatory = $false)]
        [Alias('RH_COLON')]
        [timespan]$RunHours,

        [Parameter(Mandatory = $false)]
        [Alias('PF')]
        [switch]$CheckHoursPerFile = $false,

        [Parameter(Mandatory = $false)]
        [Alias('IPG_COLON_VALUE')]
        [Int32]$InterpacketGap = -1,

        [Parameter(Mandatory = $false)]
        [Alias('SL')]
        [switch]$SymbolicLinks = $false,

        [Parameter(Mandatory = $false)]
        [Alias('MT_COLON_VALUE')]
        [ValidateRange(1,128)]
        [Int32]$Threads = -1,

        [Parameter(Mandatory = $false)]
        [Alias('DCOPY_COLON_VALUE')]
        [ValidateSet('Data','Attributes','Timestamps','Security','Owner','UAudit')]
        [string[]]$FolderCopyFlags = @(),

        [Parameter(Mandatory = $false)]
        [Alias('NODCOPY')]
        [switch]$NoFolderInfo = $false,

        [Parameter(Mandatory = $false)]
        [Alias('NOOFFLOAD')]
        [switch]$NoMicrosoftOffload = $false,

        [Parameter(Mandatory = $false)]
        [Alias('A')]
        [switch]$CopyArchives = $false,

        [Parameter(Mandatory = $false)]
        [Alias('M')]
        [switch]$CopyArchivesReset = $false,

        [Parameter(Mandatory = $false)]
        [Alias('IA_COLON_VALUE')]
        [ValidateSet('R','A','S','H','C','N','E','T','O')]
        [string[]]$IncludeAttributes = @(),

        [Parameter(Mandatory = $false)]
        [Alias('XA_COLON_VALUE')]
        [ValidateSet('R','A','S','H','C','N','E','T','O')]
        [string[]]$ExcludeAttributes = @(),

        [Parameter(Mandatory = $false)]
        [ValidateLength(1, 1024)]
        [Alias('XF_SPACE_VALUES')]
        [string[]]$ExcludeFile = @(),

        [Parameter(Mandatory = $false)]
        [ValidateLength(1, 1024)]
        [Alias('XD_SPACE_VALUES')]
        [string[]]$ExcludeDirectory= @(),

        [Parameter(Mandatory = $false)]
        [Alias('XC')]
        [switch]$ExcludeChanged = $false,

        [Parameter(Mandatory = $false)]
        [Alias('XN')]
        [switch]$ExcludeNewer = $false,

        [Parameter(Mandatory = $false)]
        [Alias('XO')]
        [switch]$ExcludeOlder = $false,

        [Parameter(Mandatory = $false)]
        [Alias('XX')]
        [switch]$ExcludeExtra = $false,

        [Parameter(Mandatory = $false)]
        [Alias('XL')]
        [switch]$ExcludeLonely = $false,

        [Parameter(Mandatory = $false)]
        [Alias('IS')]
        [switch]$IncludeSame = $false,

        [Parameter(Mandatory = $false)]
        [Alias('IT')]
        [switch]$IncludeTweaked = $false,

        [Parameter(Mandatory = $false)]
        [Alias('MAX_COLON_VALUE')]
        [Int32]$MaxSize = -1,

        [Parameter(Mandatory = $false)]
        [Alias('MIN_COLON_VALUE')]
        [Int32]$MinSize = -1,

        [Parameter(Mandatory = $false)]
        [Alias('MAXAGE_COLON_VALUE')]
        [Int32]$MaxAge = -1,

        [Parameter(Mandatory = $false)]
        [Alias('MINAGE_COLON_VALUE')]
        [Int32]$MinAge = -1,

        [Parameter(Mandatory = $false)]
        [Alias('MAXLAD_COLON_VALUE')]
        [Int32]$MaxLastAccessDate = -1,

        [Parameter(Mandatory = $false)]
        [Alias('MINLAD_COLON_VALUE')]
        [Int32]$MinLastAccessDate = -1,

        [Parameter(Mandatory = $false)]
        [Alias('XJ')]
        [switch]$ExcludeJunctions = $false,

        [Parameter(Mandatory = $false)]
        [Alias('FFT')]
        [switch]$AssumeFatFileNames = $false,

        [Parameter(Mandatory = $false)]
        [Alias('DST')]
        [switch]$CompensateDST = $false,

        [Parameter(Mandatory = $false)]
        [Alias('XJD')]
        [switch]$ExcludeDirectoryJunctions = $false,

        [Parameter(Mandatory = $false)]
        [Alias('XJF')]
        [switch]$ExcludeFileJunctions = $false,

        [Parameter(Mandatory = $false)]
        [Alias('R_COLON_VALUE')]
        [Int32]$RetryCount = -1,

        [Parameter(Mandatory = $false)]
        [Alias('W_COLON_VALUE')]
        [Int32]$RetryWait = -1,

        [Parameter(Mandatory = $false)]
        [Alias('REG')]
        [switch]$SaveSettings = $false,
        
        [Parameter(Mandatory = $false)]
        [Alias('TBD')]
        [switch]$WaitForSharenames = $false,

        [Parameter(Mandatory = $false)]
        [Alias('L')]
        [switch]$ListOnly = $false,       

        [Parameter(Mandatory = $false)]
        [Alias('X')]
        [switch]$ReportExtra = $false,

        [Parameter(Mandatory = $false)]
        [Alias('V')]
        [switch]$VerboseOutput = $false,

        [Parameter(Mandatory = $false)]
        [Alias('TS')]
        [switch]$ReportTimestamps = $false,

        [Parameter(Mandatory = $false)]
        [Alias('P')]
        [switch]$ReportFullPath = $false,

        [Parameter(Mandatory = $false)]
        [Alias('BYTES')]
        [switch]$ReportBytes = $false,

        [Parameter(Mandatory = $false)]
        [Alias('NS')]
        [switch]$NoSize = $false,

        [Parameter(Mandatory = $false)]
        [Alias('NC')]
        [switch]$NoClass = $false,

        [Parameter(Mandatory = $false)]
        [Alias('NFL')]
        [switch]$NoFileList = $false,
        
        [Parameter(Mandatory = $false)]
        [Alias('NDL')]
        [switch]$NoDirectoryList = $false,

        [Parameter(Mandatory = $false)]
        [Alias('NP')]
        [switch]$NoProgress = $false,

        [Parameter(Mandatory = $false)]
        [Alias('ETA')]
        [switch]$EstimatedTimeOfArrival = $false,

        [Parameter(Mandatory = $false)]
        [Alias('LOG_COLON_VALUE')]
        [string]$NewLog = $([string]::Empty),

        [Parameter(Mandatory = $false)]
        [Alias('LOG_PLUS_COLON_VALUE')]
        [string]$ExistingLog = $([string]::Empty),

        [Parameter(Mandatory = $false)]
        [Alias('UNILOG_COLON_VALUE')]
        [string]$NewUnicodeLog = $([string]::Empty),

        [Parameter(Mandatory = $false)]
        [Alias('UNILOG_PLUS_COLON_VALUE')]
        [string]$ExistingUnicodeLog = $([string]::Empty),

        [Parameter(Mandatory = $false)]
        [Alias('TEE')]
        [switch]$ConsoleOutput= $false,
        
        [Parameter(Mandatory = $false)]
        [Alias('UNICODE')]
        [switch]$ConsoleOutputUnicode= $false,        

        [Parameter(Mandatory = $false)]
        [Alias('NJH')]
        [switch]$NoJobHeader= $false,

        [Parameter(Mandatory = $false)]
        [Alias('NJS')]
        [switch]$NoJobSummary= $false,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru= $false,

        [Parameter(Mandatory = $false)]
        [switch]$Wait= $false
    )

    ## Begin Reference
    #if ($Configuration -contains 'VolumeRoot') $ExcludedDirectory += '$RECYCLE.BIN', 'System Volume Information'
    #$outputRawFooter = $outputRaw | Select-Object -Last 35; $outputRawResultTable = $outputRaw | Select-Object -Last 14; $outputTextFooter = $outputRawFooter -join "`r`n";
    ## End Reference

    Begin
    {
        ## Set Function Name
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        
        ## Set Unique Log Time Based On UTC
        [string]$logDateTimeUtc = Get-Date -Format yyyyMMddHHmmss;
        
        ## Create Array For Extra Robocopy Paramters
        [string[]]$RobocopyExtraArguments = @();
        
        ## Exclude These Parameters When Evaluating Extra Parameters
        [string[]]$ExcludeParameters = @('Path','Destination','Filter');

        ## Define The Standard Output File For The Robocopy Process
        [string]$RobocopyStdOut = Join-Path -Path $Env:temp -ChildPath 'Robocopy_StandardOut.txt'

        ## Begin [Define Function That Will Return Alias For PSBoundParameter]
        Function Get-ParameterAlias
        {
            [CmdletBinding()]
            [OutputType([string])]
            Param(
                $CommandObject,
                $ParameterName
            )
            [string]$ReturnValue = [string]::Empty;
            
            $getParameters = $getCommand.Parameters
            foreach ( $param in $getParameters.GetEnumerator() )
            {
                If ( $ParameterName -like $param.Key )
                {
                    [string]$ReturnValue = $param.Value.Aliases | Select-Object -First 1
                    break;
                }
            }
            return $ReturnValue
        }
        ## End [Define Function That Will Return Alias For PSBoundParameter]

        [psobject]$RobocopyProcess = New-Object -TypeName PSObject
    }
    Process
    {
        Try
        {
            ## Set System Directory
            [string]$SystemDirectory = Split-Path -Path $Env:Comspec -Parent
            
            ## Find Robocopy.exe Path
            [string]$RobocopyPath = Get-ChildItem -Path $SystemDirectory -Filter 'robocopy.exe' -Force | Select-Object -ExpandProperty 'FullName' -First 1;

            ## Validate Robocopy.exe was found
            If ( [string]::IsNullOrEmpty($RobocopyPath) ) { Throw "Could Not Find 'robocopy.exe' in '$SystemDirectory'" }
            
            ## Add Robocopy Path To Hashtable
            ## Define Empty Parameter Set For Start-Process Function
            [Hashtable]$Start_Process = @{
                'FilePath'=$RobocopyPath;
                'ArgumentList'=@();
                'NoNewWindow'=$([switch]::Present);
                'PassThru'=$([switch]::Present);
                'RedirectStandardOutput'=$RobocopyStdOut;
            }

            ## Get Current Function Information
            $getCommand = (Get-Command -Name $PSCmdlet.MyInvocation.MyCommand.Name)

            ## Get Each Given Parameter that is not contained ibn the exlusion array
            Foreach($PSBoundParameter in ($PSBoundParameters.GetEnumerator() | ?{$ExcludeParameters -notcontains $_.Key}))
            {
                

                ## Get Current Parameter Object Type
                [string]$ParameterType = $PSBoundParameter.Value.GetType().Name
                Write-Host "ParameterType:[$ParameterType" -Source ${CmdletName}

                ## Get Alias For The CUrrent Parameter
                [string]$AliasName = Get-ParameterAlias -CommandObject $getCommand -ParameterName $PSBoundParameter.Key
                Write-Host "AliasName:[$AliasName" -Source ${CmdletName}

                If ( ![string]::IsNullOrEmpty($AliasName))
                {
                    ## Set Value For the Parameter String
                    Switch ( $ParameterType )
                    {
                        'String[]'{ If ( $AliasName -like "*_VALUES" ) { [string]$ReplaceValue = '"' + ($PSBoundParameter.Value -join '" "') + '"'; } ElseIf ( $AliasName -like "*_VALUE" ) { [string]$ReplaceValue = ($PSBoundParameter.Value -join ''); } break; }
                        Default { [string]$ReplaceValue = $PSBoundParameter.Value; break;}
                    }
                    Write-Host "ReplaceValue:[$ReplaceValue" -Source ${CmdletName}

                    ## Replace The Alias Name with characters and values
                    [string]$AddParameter = '/' + $AliasName -Replace '(_COLON)',':' -Replace '(_SPACE)',' ' -Replace '(_PLUS)','+' -Replace '(_MINUS)','-' -Replace '(_VALUES)',$ReplaceValue -Replace '(_VALUE)',$ReplaceValue 
                    Write-Host "AddParameter:[$AddParameter" -Source ${CmdletName}

                    ## Add The Constructed String to the Argument List
                    $RobocopyExtraArguments += $AddParameter;
                }
            }

            ## Execute Process For each path specified with '-Path' Parameter
            Foreach ( $FolderPath in $Path )
            {
                ## Clear out master array for arguments for rb process
                $Start_Process.ArgumentList = @();

                IF ( [system.io.path]::HasExtension($FolderPath))
                {
                    [string]$Sourcedir = Split-Path -Parent $FolderPath -Parent;
                    $Filter += "`"$(Split-Path -Parent $FolderPath -Leaf)`"";
                }

                ## Add Source Path To Argument Array
                $Start_Process.ArgumentList += "`"$($FolderPath)`"";
                
                ## Add Destination To Argument Array
                $Start_Process.ArgumentList += "`"$($Destination)`"";
                
                ## Add Filter Parameter (If Necessary)
                If ( $Filter.Count -gt 0 ){$Start_Process.ArgumentList += ('"'+($Filter -join '" "')+'"')}
                Write-Host "RobocopyExtraArguments:[$($RobocopyExtraArguments -join ' ')" -Source ${CmdletName}

                ## Append Extra Arguments
                $Start_Process.ArgumentList = $Start_Process.ArgumentList + $RobocopyExtraArguments
                Write-Host "`$Start_Process.ArgumentList:[$($Start_Process|Fl *|Out-String)" -Source ${CmdletName}

                
                $ProcessResult = Start-Process @Start_Process
                If ( $Wait )
                {
                    Do
                    {
                        [bool]$ProcessRunning = ![string]::IsNullOrEmpty((Get-Process -Id $ProcessResult.Id -ErrorAction 'SilentlyContinue'| Select-Object -FIrst 1 -ExpandProperty 'Name'))
                        Write-Log -Message "ProcessRunning: $ProcessRunning" -Source ${CmdletName}

                        [string]$LogContent = Get-Content -Path $RobocopyStdOut | Out-String;
                        Write-Log -Message "LogContent: $LogContent" -Source ${CmdletName}
                        
                        [string]$Percent = ([regex]'(\d{1,2}[.]\d{1}[%])').Matches($LogContent) | Select-Object -Last 1 -ExpandProperty 'Value';
                        Write-Host "Process ($($PRocessResult.Id)): $($Percent)" -BackgroundColor Cyan -ForegroundColor Blue

                        Start-Sleep -Seconds 1
                    }
                    While($ProcessRunning)
                }
                [psobject]$RobocopyProcess = New-Object -TypeName PSObject -Property (@{
                    ExitCode = $($ProcessResult.ExitCode);
                    StandardOutput = $(Get-Content -ErrorAction 'SilentlyContinue' -Path $RobocopyStdOut|Out-String);
                })
                Write-Host "RobocopyProcess:[$($RobocopyProcess|Fl *|Out-String)" -Source ${CmdletName}
            }
        }
        Catch
        {
            Write-Warning $_.Exception.Message
        }
    }
    End
    {
        If ( $PassThru )
        {
            Write-Output -InputObject $RobocopyProcess
        }
    }
}
function Get-CmdletParameterAlias
{
    [CmdletBinding()]
    [OutputType([string])]
    Param(
        $CommandObject,
        $ParameterName
    )
    [string]$ReturnValue = [string]::Empty;
    Write-debug -Message "CommandObjectParam: $($CommandObject|fl *|out-string)"
    Write-debug -Message "ParameterNameParam: $($ParameterName)"
    Try
    {
        $getParameters = $CommandObject.Parameters
        foreach ( $param in $getParameters.GetEnumerator() )
        {
            If ( $ParameterName -like $param.Key )
            {
                [string]$ReturnValue = $param.Value.Aliases | Select-Object -First 1
                break;
            }
        }
    }
    Catch
    {
        Write-CMModuleLog -Message "[Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Source 'Get-CmdletParameterAlias' -Severity 2
    }
    Write-Output -InputOBject $ReturnValue    
}
function Expand-CabinetArchive
{
	[CmdletBinding()]
	Param (
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path -Path $_})]
        [ValidatePattern('^(.*)(\.[cC][aA][bB])$')]
        [string]$FilePath,

        [Parameter(Position=1,Mandatory=$false)]
        [string]$Destination = [string]::Empty,

        [Parameter(Position=1,Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$Files = '*',

        [Parameter(Position=2,Mandatory=$false)]
        [switch]$Force
    )
	Begin { 
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    }
	Process {
		Try {
            If ( [string]::IsNullOrEmpty($Destination) ) {
                [string]$Destination = $FilePath.ToLower().Replace('.cab','');
            }
            Write-Log -Message "Destination: $Destination" -Source ${CmdletName}

            If ( Test-Path -Path $Destination ) {
                If ( $Force ) {
                    Remove-Folder -Path $Destination -ContinueOnError $true;
                }
                Else {
                    Throw "Destination Already Exists. Use the '-Force' Parameter to overwrite."
                }
            }
            New-Folder -Path $Destination -ContinueOnError $true;

            [string]$Expand = "$Env:Windir\System32\Expand.exe";
            [string[]]$ExpandParameters = @("`"$FilePath`"","`"$Destination`"","-F:$Files")
            Execute-Process -Path $Expand -Parameters $ExpandParameters -CreateNoWindow -PassThru -ContinueOnError $true 
		}
		Catch
		{
			Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Severity 2
		}
	}
}
function Schedule-ServiceReboot
{
    [CmdletBinding()]
    param([switch]$Force)
    Begin
    {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        [bool]$ReturnValue = $false
    }
    Process
    {
        Try
        {
            [DateTime]$Now = Get-Date;
            Write-Log -Source ${CmdletName} -Message  "Now: $($Now.ToString())"
            [DateTime]$Tom = $Now.AddDays(1);
            Write-Log -Source ${CmdletName} -Message  "Tom: $($Tom.ToString())"
            [DateTime]$ScheduleTimeMax = New-Object -TypeName System.DateTime -ArgumentList $Now.Year, $($Now.Month), $($Tom.Day),0,0,0
            Write-Log -Source ${CmdletName} -Message  "ScheduleTimeMax: $($ScheduleTimeMax.ToString())"
            [int]$WaitSeconds = $ScheduleTimeMax.Subtract($(Get-Date)).TotalSeconds
            Write-Log -Source ${CmdletName} -Message  "WaitSeconds: $WaitSeconds"
            [string]$killExistingShutdown = Invoke-Expression -Command "cmd /c shutdown /a"|Out-string
            Write-Log -Source ${CmdletName} -Message  "killExistingShutdown: $killExistingShutdown ($LASTEXITCODE)"
            If ( $Force ) { [string]$command = 'cmd /c shutdown /f /r /t ' + $WaitSeconds } Else { [string]$command = 'cmd /c shutdown /r /t ' + $WaitSeconds }
            Write-Log -Source ${CmdletName} -Message  "command: $command"
            [string]$scheduleShutdown = Invoke-Expression -Command $command|Out-string
            Write-Log -Source ${CmdletName} -Message  "scheduleShutdown: $scheduleShutdown ($LASTEXITCODE)" 
        }
        Catch
        {
            Write-Host "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" 
        }
    }
}
function Compress-WindowsCabinet
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmptY()]
        [ValidateScript({Test-Path -Path $_})]
		[String]$Path,
		[Parameter(Mandatory = $false, Position = 1)]
		[String]$Destination = [string]::Empty,
        [switch]$PassThru = $false
	)
	
	Begin
	{
		
		## Function Name
		[String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		
		## Write Header
	}
	Process
	{
		Try
		{
			
			Write-Log -Message "Path [$Path]" -Source ${CmdletName}
			If ((-Not $(Test-PAth -Path $Path))) { Throw "Invalid Directory Source Path." }
			If ($Destination -eq '')
			{
				
				[String]$destName = [IO.Path]::GetDirectoryName($Path) + '.cab'
				Write-Log -Message "destName [$destName]" -Source ${CmdletName}
				
				[String]$Destination = Join-Path -Path $Env:Temp -ChildPath $destName
			}
			Write-Log -Message "Destination [$Destination]" -Source ${CmdletName}
			
			If (($(Test-PAth -Path $Destination))) { Throw "Destination Archive [$($Destination)] already exists." }
			
			[String]$DestinationPath = $(Split-Path -Path $Destination -Parent)
			Write-Log -Message "DestinationPath [$DestinationPath]" -Source ${CmdletName}
			
			[String]$DestinationFile = $(Split-Path -Path $Destination -Leaf)
			Write-Log -Message "DestinationFile [$DestinationFile]" -Source ${CmdletName}
			
			Push-Location -Path $DestinationPath -StackName $CmdletName
			
			$ddf = ".OPTION EXPLICIT
.Set CabinetNameTemplate=$DestinationFile
.Set DiskDirectory1=.
.Set CompressionType=MSZIP
.Set Cabinet=on
.Set Compress=on
.Set CabinetFileCountThreshold=0
.Set FolderFileCountThreshold=0
.Set FolderSizeThreshold=0
.Set MaxCabinetSize=0
.Set MaxDiskFileCount=0
.Set MaxDiskSize=0
"
			$dirfullname = (get-item $Path).fullname
			$ddfpath = ($env:TEMP + "\temp.ddf")
			$ddf += (ls -recurse $Path | ? { !$_.psiscontainer } | select -expand fullname | %{ '"' + $_ + '" "' + $_.SubString($dirfullname.length + 1) + '"' }) -join "`r`n"
			$ddf
			$ddf | Out-File -encoding UTF8 $ddfpath
			makecab /F $ddfpath
			rm $ddfpath
			rm setup.inf
			rm setup.rpt
		}
        Catch
        {
            Write-Host "Exception: $($_.Exception.Message)[$($_.InvocationInfo.ScriptLineNumber)" 
        }
    }
    End {
        If ( $PassThru -and ![string]::IsNullOrEmpty($Destination)) {
            If ( Test-Path -Path $Destination ) {
                Write-Output -InputObject $(Get-Item -Path $Destination)
            }
        }
    }
}
Function Test-URI  
{
<#
.Synopsis
Test a URI or URL
.Description
This command will test the validity of a given URL or URI that begins with either http or https. The default behavior is to write a Boolean value to the pipeline. But you can also ask for more detail.
 
Be aware that a URI may return a value of True because the server responded correctly. For example this will appear that the URI is valid.
 
test-uri -uri http://files.snapfiles.com/localdl936/CrystalDiskInfo7_2_0.zip
 
But if you look at the test in detail:
 
ResponseUri   : http://files.snapfiles.com/localdl936/CrystalDiskInfo7_2_0.zip
ContentLength : 23070
ContentType   : text/html
LastModified  : 1/19/2015 11:34:44 AM
Status        : 200
 
You'll see that the content type is Text and most likely a 404 page. By comparison, this is the desired result from the correct URI:
 
PS C:\> test-uri -detail -uri http://files.snapfiles.com/localdl936/CrystalDiskInfo6_3_0.zip
 
ResponseUri   : http://files.snapfiles.com/localdl936/CrystalDiskInfo6_3_0.zip
ContentLength : 2863977
ContentType   : application/x-zip-compressed
LastModified  : 12/31/2014 1:48:34 PM
Status        : 200
 
.Example
PS C:\> test-uri https://www.petri.com
True
.Example
PS C:\> test-uri https://www.petri.com -detail
 
ResponseUri   : https://www.petri.com/
ContentLength : -1
ContentType   : text/html; charset=UTF-8
LastModified  : 1/19/2015 12:14:57 PM
Status        : 200
.Example
PS C:\> get-content D:\temp\uris.txt | test-uri -Detail | where { $_.status -ne 200 -OR $_.contentType -notmatch "application"}
 
ResponseUri   : http://files.snapfiles.com/localdl936/CrystalDiskInfo7_2_0.zip
ContentLength : 23070
ContentType   : text/html
LastModified  : 1/19/2015 11:34:44 AM
Status        : 200
 
ResponseURI   : http://download.bleepingcomputer.com/grinler/rkill
ContentLength : 
ContentType   : 
LastModified  : 
Status        : 404
 
Test a list of URIs and filter for those that are not OK or where the type is not an application.
.Notes
Last Updated: January 19, 2015
Version     : 1.0
 
Learn more about PowerShell:
http://jdhitsolutions.com/blog/essential-powershell-resources/
 
  ****************************************************************
  * DO NOT USE IN A PRODUCTION ENVIRONMENT UNTIL YOU HAVE TESTED *
  * THOROUGHLY IN A LAB ENVIRONMENT. USE AT YOUR OWN RISK.  IF   *
  * YOU DO NOT UNDERSTAND WHAT THIS SCRIPT DOES OR HOW IT WORKS, *
  * DO NOT USE IT OUTSIDE OF A SECURE, TEST SETTING.             *
  ****************************************************************
 
.Link
Invoke-WebRequest
#>
 
[cmdletbinding(DefaultParameterSetName="Default")]
Param(
[Parameter(Position=0)]
[ValidatePattern( "^(http|https)://" )]
[Alias("url")]
[string]$URI,
[Parameter(ParameterSetName="Detail")]
[Switch]$Detail,
[ValidateScript({$_ -ge 0})]
[int]$Timeout = 30
)
 
Begin {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)" 
    Write-Verbose -message "Using parameter set $($PSCmdlet.ParameterSetName)" 
} #close begin block
 
Process {
 
    Write-Verbose -Message "Testing $uri"
    Try {
     #hash table of parameter values for Invoke-Webrequest
     $paramHash = @{
     UseBasicParsing = $True
     DisableKeepAlive = $True
     Uri = $uri
     Method = 'Head'
     ErrorAction = 'stop'
     TimeoutSec = $Timeout
    }
 
    $test = Invoke-WebRequest @paramHash
 
     if ($Detail) {
        $test.BaseResponse | 
        Select ResponseURI,ContentLength,ContentType,LastModified,
        @{Name="Status";Expression={$Test.StatusCode}}
     } #if $detail
     else {
       if ($test.statuscode -ne 200) {
            #it is unlikely this code will ever run but just in case
            Write-Verbose -Message "Failed to request $uri"
            write-Verbose -message ($test | out-string)
            $False
         }
         else {
            $True
         }
     } #else quiet
     
    }
    Catch {
      #there was an exception getting the URI
      write-verbose -message $_.exception
      if ($Detail) {
        #most likely the resource is 404
        $objProp = [ordered]@{
        ResponseURI = $uri
        ContentLength = $null
        ContentType = $null
        LastModified = $null
        Status = 404
        }
        #write a matching custom object to the pipeline
        New-Object -TypeName psobject -Property $objProp
 
        } #if $detail
      else {
        $False
      }
    } #close Catch block
} #close Process block
 
End {
    Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
} #close end block
 
} 
Function Get-CmdletParameterType {
    [CmdletBinding()]
    [OutputType([System.Type])]
    Param(
        $CommandObject,
        $ParameterName
    )
    [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name;
    #Write-debug -Message "CommandObject: $($CommandObject|fl *|out-string)"
    #Write-debug -Message "ParameterName: $($ParameterName)"
    Try
    {
        $getParameters = $CommandObject.Parameters
        #Write-debug -Message "Parameters: $($getParameters|fl *|out-string)"

        foreach ( $param in $getParameters.GetEnumerator() )
        {
            #Write-debug -Message "param: $($param|fl *|out-string)"
            If ( $ParameterName -like $param.Key )
            {
                [System.Type]$ReturnValue = $param.Value.ParameterType
                break;
            }
        }
    }
    Catch
    {
        Write-Log -Message "Exception: $($_.Exception.Message): Line $($_.InvocationInfo.ScriptLineNumber)" -Source ${CmdletName} -Source 'Get-CmdletParameterAlias' -Severity 2
    }
    Write-Output -InputOBject $ReturnValue    
}
#endregion [Helpers]
##*===============================================
##*===============================================
##* END FUNCTION LISTINGS
##*===============================================

##*===============================================
##* SCRIPT BODY
##*===============================================

    New-Alias -Name 'Backup-WmiRepository' -Value "Call-Winmgmt -Backup" -Scope Global -Force -Ea SilentlyContinue;
    New-Alias -Name 'Restore-WmiRepository' -Value "Call-Winmgmt -Restore" -Scope Global -Force -Ea SilentlyContinue;
    New-Alias -Name 'Reset-WmiRepository' -Value "Call-Winmgmt -Reset" -Scope Global -Force -Ea SilentlyContinue;
    New-Alias -Name 'Verify-WmiRepository' -Value "Call-Winmgmt -Verify" -Scope Global -Force -Ea SilentlyContinue;
    New-Alias -Name 'Salvage-WmiRepository' -Value "Call-Winmgmt -Salvage" -Scope Global -Force -Ea SilentlyContinue;

    $rootXML= [xml](Gc "$scriptDirectory\AppDeployToolkit\AppDeployToolkitConfig.xml")
    $rootXML.AppDeployToolkit_Config.CCM_XMLDefinition | Select -ExpandProperty 'Tag'| Sort-Object -Property 'index' | %{
        $Tag = $_;
        [INT]$NODEc=0
        [INT]$TOTCOU=$(@($rootXML.AppDeployToolkit_Config | Select-Xml -XPath "//$($Tag.name)" |Select -ExpandProperty Node).Count)
        $rootXML.AppDeployToolkit_Config | Select-Xml -XPath "//$($Tag.name)" |Select -ExpandProperty Node | %{ 
            $NODEc++;
            $ArgumentObject = $_; 

                #write-verbose -Object "Command Object: $((Get-Command -Name $tag.expression).Definition)))"
            Try {
                #[scriptblock]$ScriptBlock_Execute = $(Get-Variable -Name $tag.expression -Scope GLOBAL | select -ExpandProperty value -first 1)
                #. $Scriptblock_Execute $ArgumentObject
                . $([scriptblock]::Create((Get-Command -Name $tag.expression).Definition)) $ArgumentObject | Out-Null;
            }
            Catch {
                Write-Warning "[XmlImpoort]::$($_.Exception.Message)"
                Start-Sleep
            }
        }
    }
    If ( !(Test-Path -Path "$dirFiles\ccmsetup.exe") ) {
        Write-Log -Severity 2 -Message "Could Not find '$dirFiles\ccmsetup.exe'. Download Source Files" -source $appDeployExtScriptFriendlyName
        Try {
            [string]$SourceURL = Get-Variable -Name 'CCM_SETUPSOURCE_*' | Sort-Object -Property Name | Select-Object -ExpandProperty 'Value' -First 1;
            Write-Log -Message "SourceURL: $SourceURL" -Source $appDeployExtScriptFriendlyName

            [Int32]$PkgVersion = $($SourceURL.Split('.')|Select -Last 1);
            Write-Log -Message "PkgVersion: $PkgVersion" -Source $appDeployExtScriptFriendlyName

            [boolean]$PackageCachePathExists = Test-CMNomadCacheItem -PackageID $CCMSetupPackageID -PackageVersion $PkgVersion
            Write-Log -Message "PackageCachePathExists: $PackageCachePathExists" -Source $appDeployExtScriptFriendlyName

            If ( $PackageCachePathExists ) {
                [string]$TempPath = Get-CMNomadCacheItemPath -PackageID $CCMSetupPackageID;
            }
            Else {
                [string]$TempPath = Execute-SMSNomad -Standalone -NoInstall -PackageID $CCMSetupPackageID -PackagePath $SourceURL -SkipExecution -PackageVersion $PkgVersion -PassThru | Select -ExpandProperty 'FullName' -First 1;
            }
            Write-Log -Message "TempPath: $TempPath" -Source $appDeployExtScriptFriendlyName

            Write-Log -Message "Copy Files From '$TempPath' -> '$dirFiles'" -Source $appDeployExtScriptFriendlyName
            & ROBOCOPY "$TempPath"  "$dirFiles" "*.*" /E /SEC /NFL /NDL

            Try {
                [System.Management.Automation.PSObject]$GLOBAL:dirFiles_Index = New-Object -TypeName PSObject;
                Get-ChildItem -Path $dirFiles -Filter *.* -Recurse -Force | ? { !$_.PSIsContainer } | %{
                    If ( $_.FullName -match '(\\x64\\)' ) {
                        [string]$i386File = $($_.FullName -Replace '\\x64\\','\i386\');
                        Write-Log -Message "i386File: $i386File" -Source ${CmdletName}
                        If ( Test-Path -Path $i386File){[string]$Suffix = "_x64"}Else{[string]$Suffix = ""}
                    }
                    ElseIf ( $_.FullName -match '(\\i386\\)' ) {
                        [string]$x64File = $($_.FullName -Replace '\\i386\\','\x64\');
                        Write-Log -Message "x64File: $x64File" -Source ${CmdletName}
                        If ( Test-Path -Path $x64File){[string]$Suffix = "_x86"}Else{[string]$Suffix = ""}
                    }
                    Else {
                        [string]$Suffix = ""
                    }
                    [string]$VariableName = "CCM_" +'FILES_'+ $([System.IO.Path]::GetFileNameWithoutExtension($_.FullName)).ToUpper() + '_' + $( ([System.IO.Path]::GetExtension($_.FullName).Trimstart('.')).ToUpper()) + $Suffix
                    Write-Log -Message "VariableName: $VariableName" -Source ${CmdletName}
                    Add-Member -InputObject $GLOBAL:dirFiles_Index -MemberType NoteProperty -Name $VariableName.Replace('.','_') -Value $_.FullName -Force;
                }
                [System.Management.Automation.PSObject]$GLOBAL:dirSupportFiles_Index = New-Object -TypeName PSObject;
                Get-ChildItem -Path $dirSupportFiles -Filter *.* -Recurse -Force | ? { !$_.PSIsContainer } | %{
                    If ( $_.FullName -match '(\\x64\\)' ) {
                        [string]$i386File = $($_.FullName -Replace '\\x64\\','\i386\');
                        Write-Log -Message "i386File: $i386File" -Source ${CmdletName}
                        If ( Test-Path -Path $i386File){[string]$Suffix = "_x64"}Else{[string]$Suffix = ""}
                    }
                    ElseIf ( $_.FullName -match '(\\i386\\)' ) {
                        [string]$x64File = $($_.FullName -Replace '\\i386\\','\x64\');
                        Write-Log -Message "x64File: $x64File" -Source ${CmdletName}
                        If ( Test-Path -Path $x64File){[string]$Suffix = "_x86"}Else{[string]$Suffix = ""}
                    }
                    Else {
                        [string]$Suffix = ""
                    }
                    [string]$VariableName = "CCM_" +'SUPPORTFILES_'+ $([System.IO.Path]::GetFileNameWithoutExtension($_.FullName)).ToUpper() + '_' + $( ([System.IO.Path]::GetExtension($_.FullName).Trimstart('.')).ToUpper()) + $Suffix
                    Write-Log -Message "VariableName: $VariableName" -Source ${CmdletName}
                    Add-Member -InputObject $GLOBAL:dirFiles_Index -MemberType NoteProperty -Name $VariableName.Replace('.','_') -Value $_.FullName -Force;
                }
            }
            Catch {
                Write-Log -Message "Unable To Set Global Variables For file" -Source $appDeployToolkitExtName -Severity 2;
            }
        }
        Catch {
            Write-Error -Exception $_
        }
    }
}
Catch {
    Out-File -FilePath "C:\Windows\Temp\AppDeployError.txt" -force -inputobject "Exception Caught In Main Block of  $appDeployToolkitExtName : [$($_.Exception.Message)]" -Encoding ascii
    Write-Host "Exception Caught In Main Block of  $appDeployToolkitExtName : [$($_.Exception.Message)]"
    throw "Exception Caught In Main Block of  $appDeployToolkitExtName : [$($_.Exception.Message)]"
}



If ($scriptParentPath) {
	Write-Log -Message "Script [$($MyInvocation.MyCommand.Definition)] dot-source invoked by [$(((Get-Variable -Name MyInvocation).Value).ScriptName)]" -Source $appDeployToolkitExtName
}
Else {
	Write-Log -Message "Script [$($MyInvocation.MyCommand.Definition)] invoked directly" -Source $appDeployToolkitExtName
}

##*===============================================
##* END SCRIPT BODY
##*===============================================

