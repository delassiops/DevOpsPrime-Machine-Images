# Import Px Proxy Server Function

# region Include required files
#
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
try {
    . ("$ScriptDirectory\ProxyServer.ps1")
}
catch {
    Write-Host "Error while loading supporting PowerShell Scripts" 
}
#endregion

    Function Copy-rootpwDirectory {
        param (
        [string]$imageMachineDirectory 
    )     
                    $rootpwFile = ".rootpw_${imageMachine}"
                    Write-Output "SSH PASSWORD (root): $env:rootpw"  | Out-File $rootpwFile
                    if ($?) {
                    Write-Host " Adding credentials to $rootpwFile"}
                    Move-Item -path $rootpwFile -Destination $imageMachineDirectory
        }

function New-JsonTemplate
{
    param (
        [string]$machineImage
    )
            $InlineScriptPermission="find /tmp -type f -iname '*.sh' -exec chmod +x {} \;"
            $InlineScriptEnvVars="/tmp/linux/setEnvironmentVariables.sh" 
            $InlineScriptNetworkManager="/tmp/linux/yumNetworkManager.sh"  
            $InlineScriptProxy="/tmp/linux/yumUpdateConfig.sh"
            $InlineScriptYumUpdate="/tmp/linux/yumUpdateAll.sh"
            $InlineScriptHostname="/tmp/linux/setHostname.sh"            
            $InlineScriptTuleap="/tmp/tuleap/yumInstallTuleap.sh"
            $InlineScriptTuleapLdap="/tmp/tuleap/ldapPlugin.sh"
            $InlineScriptOracleInstall="/tmp/oracledatabase/scripts/install.sh"
            $InlineScriptOracleImport="/home/oracle/dump/import.sh"
            $InlineScriptPercona="/tmp/percona/scripts/install.sh"

            $EnvVarsOracle=@( "ORACLE_BASE=/opt/oracle",
                                "ORACLE_HOME=/opt/oracle/product/19c/dbhome",
                                "ORACLE_SID=${env:oracle_db_name}",
                                "ORACLE_CHARACTERSET=${env:oracle_db_characterSet}",
                                "ORACLE_EDITION=SE2",
                                "SYSTEM_TIMEZONE=${env:zoneinfo}")

            $EnvVarsPercona=@( "SYSTEM_TIMEZONE=${env:zoneinfo}")
            
            $TemplateJsonFile = "packer_templates\Template.json"

            $Json = Get-Content $TemplateJsonFile | Out-String  | ConvertFrom-Json

            $Json.builders[0] | Add-Member -Type NoteProperty -Name "output_directory" -Value ""
            
    switch ($machineImage)
    {
        'centos6' {
            $Json.variables.guest_os_type="centos6-64"
            $Json.variables.floppy_files="kickstart/centos6/ks.cfg"
            $Json.variables.iso_url="put_files_here/CentOS-6.10-x86_64-minimal.iso"
            $Json.variables.iso_checksum="7c0dee2a0494dabd84809b72ddb4b761f9ef92b78a506aef709b531c54d30770"

            $Json.builders[0].boot_command='["<tab> text ks=hd:fd0:/ks.cfg <enter><wait>"]'

            $InlineScriptHostname= "$InlineScriptNetworkManager && $InlineScriptHostname"

            $Json.provisioners[1].inline = "$InlineScriptPermission && $InlineScriptEnvVars && $InlineScriptHostname && $InlineScriptProxy && $InlineScriptYumUpdate"
            $Json.provisioners[1] | Add-Member -Type NoteProperty -Name 'expect_disconnect' -Value 'true'
        }
        'centos7' {
            $Json.variables.guest_os_type="centos7-64"
            $Json.variables.floppy_files="kickstart/centos7/ks.cfg"
            $Json.variables.iso_url="put_files_here/CentOS-7-x86_64-Minimal-2003.iso"
            $Json.variables.iso_checksum="659691c28a0e672558b003d223f83938f254b39875ee7559d1a4a14c79173193"
            $Json.provisioners[1].inline = "$InlineScriptPermission && $InlineScriptEnvVars && $InlineScriptHostname && $InlineScriptProxy && $InlineScriptYumUpdate"
            $Json.provisioners[1] | Add-Member -Type NoteProperty -Name 'expect_disconnect' -Value 'true'
        }
        'oraclelinux' {
            $Json.variables.guest_os_type="oraclelinux7-64"
            $Json.variables.floppy_files="kickstart/oraclelinux7/ks.cfg"
            $Json.variables.iso_url="put_files_here/V995537-01.iso"
            $Json.variables.iso_checksum="6E1069FF42F7E59B19AF4E2FCACAE2FCA3F195C7F2904275B0DF386EFDCD616D"
            $Json.provisioners[1].inline = "$InlineScriptPermission && $InlineScriptEnvVars && $InlineScriptHostname && $InlineScriptProxy && $InlineScriptYumUpdate"
            $Json.provisioners[1] | Add-Member -Type NoteProperty -Name 'expect_disconnect' -Value 'true'
        }
        'perconamysql' {
            $TemplateJsonFile = New-JsonTemplate "centos7"
            $Json = Get-Content $TemplateJsonFile | Out-String  | ConvertFrom-Json
            Remove-Item $TemplateJsonFile
            
            $Json.provisioners += @{}
            $Json.provisioners += @{}  
            $TempFile = New-TemporaryFile
            $Json | ConvertTo-Json -depth 32 | Set-Content $TempFile
            $Json = Get-Content $TempFile | Out-String  | ConvertFrom-Json

            $Json.builders[0].cpus="2"
            $Json.builders[0].memory="4096"

            $Json.provisioners[2] | Add-Member -Type NoteProperty -Name 'type' -Value 'file'
            $Json.provisioners[2] | Add-Member -Type NoteProperty -Name 'source' -Value 'upload/percona'
            $Json.provisioners[2] | Add-Member -Type NoteProperty -Name 'destination' -Value '/tmp'

            $Json.provisioners[3] | Add-Member -Type NoteProperty -Name 'type' -Value 'shell'
            $Json.provisioners[3] | Add-Member -Type NoteProperty -Name 'inline' -Value "$InlineScriptPermission && $InlineScriptPercona"
            $Json.provisioners[3] | Add-Member -Type NoteProperty -Name 'environment_vars' -Value $EnvVarsPercona
            $Json.provisioners[3] | Add-Member -Type NoteProperty -Name 'expect_disconnect' -Value 'true'

        }
        'oracledatabase' {
            $TemplateJsonFile = New-JsonTemplate "oraclelinux"
            $Json = Get-Content $TemplateJsonFile | Out-String  | ConvertFrom-Json
            Remove-Item $TemplateJsonFile

            $Json.provisioners += @{}
            $Json.provisioners += @{}
            $Json.provisioners += @{}       
            $TempFile = New-TemporaryFile
            $Json | ConvertTo-Json -depth 32 | Set-Content $TempFile
            $Json = Get-Content $TempFile | Out-String  | ConvertFrom-Json

            $Json.builders[0].cpus="2"
            $Json.builders[0].memory="4096"

            $Json.provisioners[2] | Add-Member -Type NoteProperty -Name 'type' -Value 'file'
            $Json.provisioners[2] | Add-Member -Type NoteProperty -Name 'source' -Value 'upload/oracledatabase'
            $Json.provisioners[2] | Add-Member -Type NoteProperty -Name 'destination' -Value '/tmp'

            $Json.provisioners[3] | Add-Member -Type NoteProperty -Name 'type' -Value 'file'
            $Json.provisioners[3] | Add-Member -Type NoteProperty -Name 'source' -Value 'put_files_here/LINUX.X64_193000_db_home.zip'
            $Json.provisioners[3] | Add-Member -Type NoteProperty -Name 'destination' -Value '/tmp/LINUX.X64_193000_db_home.zip'

            $provisionersshell=$Json.provisioners[1]
            $provisionersfile=$Json.provisioners[3]
            
            $Json.provisioners[1]=$provisionersfile
            $Json.provisioners[3]=$provisionersshell

            $Json.provisioners[4] | Add-Member -Type NoteProperty -Name 'type' -Value 'shell'
            $Json.provisioners[4] | Add-Member -Type NoteProperty -Name 'inline' -Value "$InlineScriptPermission && $InlineScriptOracleInstall && $InlineScriptOracleImport"
            $Json.provisioners[4] | Add-Member -Type NoteProperty -Name 'environment_vars' -Value $EnvVarsOracle
            $Json.provisioners[4] | Add-Member -Type NoteProperty -Name 'expect_disconnect' -Value 'true'

        } 
        'tuleap' {
            $TemplateJsonFile = New-JsonTemplate "centos"
            $Json = Get-Content $TemplateJsonFile | Out-String  | ConvertFrom-Json
            Remove-Item $TemplateJsonFile

            $Json.provisioners += @{}
            $Json.provisioners += @{}  
            $Json.provisioners += @{}       
            $TempFile = New-TemporaryFile
            $Json | ConvertTo-Json -depth 32 | Set-Content $TempFile
            $Json = Get-Content $TempFile | Out-String  | ConvertFrom-Json

            $Json.provisioners[2] | Add-Member -Type NoteProperty -Name 'type' -Value 'file'
            $Json.provisioners[2] | Add-Member -Type NoteProperty -Name 'source' -Value 'upload/tuleap'
            $Json.provisioners[2] | Add-Member -Type NoteProperty -Name 'destination' -Value '/tmp'

            $Json.provisioners[3] | Add-Member -Type NoteProperty -Name 'type' -Value 'shell'
            $Json.provisioners[3] | Add-Member -Type NoteProperty -Name 'pause_before' -Value '30s'
            $Json.provisioners[3] | Add-Member -Type NoteProperty -Name 'inline' -Value "$InlineScriptPermission && $InlineScriptTuleap"
            
            $Json.provisioners[4] | Add-Member -Type NoteProperty -Name 'type' -Value 'file'
            $Json.provisioners[4] | Add-Member -Type NoteProperty -Name 'direction' -Value 'download'
            $Json.provisioners[4] | Add-Member -Type NoteProperty -Name 'source' -Value '/root/.tuleap_passwd'
            $Json.provisioners[4] | Add-Member -Type NoteProperty -Name 'destination' -Value '.tuleap_passwd'
        } 
        'tuleapldap' {
            $TemplateJsonFile = New-JsonTemplate "tuleap"
            $Json = Get-Content $TemplateJsonFile | Out-String  | ConvertFrom-Json
            Remove-Item $TemplateJsonFile
            
            $Json.provisioners[3].inline = "$InlineScriptPermission && $InlineScriptTuleap && $InlineScriptTuleapLdap"
        }
        default {        
        }  
    }

    $VmId= "$machineImage-$env:id_machine_image"
            
    $Json.variables.Hostname="${VmId}"
    $Json.variables.ssh_password="${env:rootpw}"

    if ([string]::IsNullOrEmpty($env:http_proxy))
    {
        $Json.variables.proxy=""
    } else {
        $Json.variables.proxy="${env:http_proxy}" 
    }

    if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN))
    {
        $Json.variables.dnsuffix=""
    } else {
        $Json.variables.dnsuffix="${env:USERDNSDOMAIN}" 
    }

    $Json.builders[0].output_directory="output-$VmId"

    $TempFile = New-TemporaryFile
    $Json | ConvertTo-Json -depth 32 | Set-Content $TempFile

    $env:GeneratedTemplate=$machineImage
    return $TempFile
}


function Show-proxyMenu
{
    param (
        [string]$Title = 'Px Proxy'
    )

    Write-Host "================ $Title ================"
    if ([string]::IsNullOrEmpty($env:http_proxy))
    {
        $ProxyDefault = "No Proxy (Direct)"
    } else {
        $ProxyDefault = "System Proxy:$env:http_proxy"
    }
    Write-Host " [P] Configure Px Proxy [Current $ProxyDefault]"

}

function Show-packerMenu
{
param (
    [string]$Title = 'Generate VM Templates'
)

    Write-Host "================ $Title ================"
    
    Write-Host " [1] CentOS 6"
    Write-Host " [2] CentOS 7"
    Write-Host " [3] Oracle Linux 7"
    Write-Host " [4] Tuleap"
    Write-Host " [5] Tuleap LDAP"
    Write-Host " [6] Oracle Database 19c"
    Write-Host " [7] Percona Server for MySQL"
}

Function Show-rootpwMenu {
    param (
    [string]$Title= "VM SSH Root Password:" 
)     
            Write-Host "====== $Title [$env:rootpw] ======="
            Write-Host " [8] Enter root password ?"
            Write-Host " [9] Generate password ?"
    }

    Function Show-directoryMenu {
        param (
        [string]$Title= "Output Directory:"
    )

                 if ([string]::IsNullOrEmpty($env:id_machine_image)) {
                    $env:id_machine_image = "vmware-iso"
                } 

                Write-Host "========================= $Title [ output-<VMNAME>-$env:id_machine_image ] ======================="

                Write-Host " [10] Enter output id ?"
                Write-Host " [11] Generate: ?" 
        }

        function Show-oracleSidMenu
        {
            param (
                [string]$Title = 'Oracle Database Configuration:'
            )
        
            Write-Host "================ $Title ================"
        
            Write-Host " [12] Configure Global database name (SID=$env:oracle_db_name)"
            Write-Host " [13] Configure Character set of the database ($env:oracle_db_characterSet)"
        
        }

        function Show-zoneinfoMenu
        {
            param (
                [string]$Title = "Time Zone (TZ):"
            )
        
            Write-Host "================ $Title [$env:zoneinfo] ================"
        
            Write-Host " [14] Configure zoneinfo TZ"
        
        }

        function Show-buildMenu
        {
            param (
                [string]$Title = "Templates JSON files: packer_templates\"
            )
        
            Write-Host "================ $Title${env:GeneratedTemplate}.json ================"
        
            Write-Host " [B] Build image(s) from template"
        
        }

Function BuildPacker {
    $env:PACKER_LOG=1
    $env:PACKER_LOG_PATH="packer_templates/packerlog_${env:GeneratedTemplate}.txt"
    invoke-expression  "cmd /c start packer build packer_templates\${env:GeneratedTemplate}.json"
}

function BuildMachineImage
{
do
{
Clear-Host

Write-Host "`n"
Show-proxyMenu

Show-packerMenu

Show-rootpwMenu

Show-directoryMenu

Show-oraclesidMenu

Show-zoneinfoMenu

Show-buildMenu

Write-Host "`n"
$selection = (Read-Host '  Choose a menu option, or press 0 to Exit').ToUpper()

switch ($selection)
{
    '0' {
       break
    }
    'P' {
        if (Add-PXCredential) {Start-Px(Test-Px)}
    }
    '1' {
        $JsonTemplate=New-JsonTemplate "centos6"
        Move-Item $JsonTemplate packer_templates\"${env:GeneratedTemplate}.json" -Force
    }
    '2' {
        $JsonTemplate=New-JsonTemplate "centos7"
        Move-Item $JsonTemplate packer_templates\"${env:GeneratedTemplate}.json" -Force
    }
    '3' {
        $JsonTemplate=New-JsonTemplate "oraclelinux"
        Move-Item $JsonTemplate packer_templates\"${env:GeneratedTemplate}.json" -Force
    } 
    '4' {
        $JsonTemplate=New-JsonTemplate "tuleap"
        Move-Item $JsonTemplate packer_templates\"${env:GeneratedTemplate}.json" -Force
    }
    '5' {
        $JsonTemplate=New-JsonTemplate "tuleapldap"
        Move-Item $JsonTemplate packer_templates\"${env:GeneratedTemplate}.json" -Force
    }
    '6' {
        $JsonTemplate=New-JsonTemplate "oracledatabase"
        Move-Item $JsonTemplate packer_templates\"${env:GeneratedTemplate}.json" -Force 
    }
    '7' {
        $JsonTemplate=New-JsonTemplate "perconamysql"
        Move-Item $JsonTemplate packer_templates\"${env:GeneratedTemplate}.json" -Force
    }
    '8' {
        $env:rootpw= Read-Host -Prompt "Enter root password ?"
    }
    '9' {
        $env:rootpw = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 8 | ForEach-Object {[char]$_})
    }
    '10' {
        $env:id_machine_image = Read-Host -Prompt "Enter Output ID: "
    } 
    '11' {
        $env:id_machine_image = -join ((65..90) | Get-Random -Count 6 | ForEach-Object {[char]$_})
    }
    '12' {
        $env:oracle_db_name = (Read-Host -Prompt "Enter ORACLE SID Name: ").ToUpper()
    }
    '13' {
        $env:oracle_db_characterSet= Read-Host -Prompt "Enter characterSet ?"
    }
    '14' {
        $env:zoneinfo = Read-Host -Prompt "Enter Time Zone ?"
    }
    'B' {
        if ([string]::IsNullOrEmpty($env:GeneratedTemplate))
        {
            Clear-Host
            Write-Host " Required Template JSON file"
            Show-packerMenu
            Pause
        } else {
            BuildPacker
        }
    }    
}
}
until ( $selection -eq '0')
}

$env:rootpw="server"
$env:oracle_db_name="NONCDB"
$env:oracle_db_characterSet="AL32UTF8"
$env:zoneinfo="UTC"
$env:GeneratedTemplate = ""
BuildMachineImage
Pause
Clear-Host