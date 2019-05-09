Function Connect-Px($SERVER) {
    if($SERVER.Length -eq 0)
    {
        Write-Host "No input detected"
        return $False
    } 
    elseif ($SERVER.Length -gt 0 )
    { 
                Write-Host "Connecting to $Server ..."
                $HOSTIP, $PORT= $SERVER.split(":")
                if ([string]::IsNullOrEmpty($PORT)) {$PORT="80"}
                if (Test-NetConnection -ComputerName $HOSTIP -Port $PORT -InformationLevel Quiet)
                            {
                                Write-Host "Successfully connected into Enterprise proxy $SERVER... :)"
                                return $True
                            }
                            else 
                            {
                                Write-Host "Failed to connect into $SERVER :("
                                return $False   
                            }
    }
}


Function Test-Px {    
do
    {
        if($env:http_proxy.Length -gt 0)
        {        
            $env:px_server= $env:http_proxy.trimstart("http://")
            Write-Host "Default PROXY ($env:px_server)"
        }
else    {
            Write-Host "No SYSTEM PROXY SETTING detected"
            $env:px_server= Read-Host -Prompt "Enter Enterprise Proxy <IP:port>, <hostname:port> ?"
            Clear-Host        
        }
                                                              
    } while (-not (Connect-Px($env:px_server)))
    return $True
}

Function Start-Px ($CHECK) {
    if ($CHECK){
    Clear-Host
    Write-Host "Starting Px Server $env:px_server"    
    $IF=$(Get-DnsClient -ConnectionSpecificSuffix $env:USERDNSDOMAIN).InterfaceIndex

    $env:px_listen=$(Get-NetIPAddress -InterfaceIndex $IF -AddressFamily IPv4).IPAddress

    $env:http_proxy='http://'+$env:px_listen+':3128'

    Write-Host 'Enterprise Proxy'$env:px_server

    Write-Host 'Px Proxy'$env:http_proxy

    $env:px_username=$env:USERDOMAIN+'\'+$env:USERNAME

    Write-Host 'Px username'$env:px_username

    Start-Process -Verb open -WorkingDirectory px cmd.exe -ArgumentList "/c", "px.exe", "--server=$env:px_server", "--listen=$env:px_listen", "--user=$env:px_username", "--foreground", "--debug"}
    else {Write-Host "Failed to start Px server $env:px_server :("}
}

Function Stop-Px {
    Start-Process -Verb open -WorkingDirectory px px.exe -ArgumentList "--quit"
}

Function Set-Rootpw {    
    do
        {
            Clear-Host
            Write-Host "======Set Password as rootpw Environment Variable======="
            if($env:rootpw.Length -gt 0)
            {        
            Write-Host "===Default `$env:rootpw ($env:rootpw)==="
            } elseif ([string]::IsNullOrEmpty($env:rootpw)) {
                Write-Host " No password exist as `$env:rootpw"
                Write-Host " Press '1' Set Mannually Password."
                Write-Host " Press '2' Auto Generate Password."
                $selection = Read-Host "Please make a selection"
                        switch ($selection)
                                            {
                                                '1' {
                                                    $env:rootpw= Read-Host -Prompt "Enter root password ?"
                                                }
                                                '2' {
                                                    Write-Host "Auto generate password..."
                                                    $password = "!@#$%^&*0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz".tochararray()
                                                    $env:rootpw = ($password | Get-Random -count 8) -join ''
                                                } 
                                                default {
                                                }  
                                            }
            }   
            
                Write-Output $env:rootpw | Out-File .root_passwd
                if ($?) {
                    Write-Host "Root credentials are saved into .tuleap_passwd"}    
        } while (([string]::IsNullOrEmpty($env:rootpw)))
        Pause
        Clear-Host
    }
function Show-packerMenu
{
    param (
        [string]$Title = 'Packer Menu'
    )
    do
{
    Clear-Host
    Write-Host "================ $Title ================"
    
    Write-Host " Press '0' Kickstart."
    Write-Host " Press '1' CentOS."
    Write-Host " Press '2' Tuleap."
    Write-Host " Press '3' Ldap."
    Write-Host " Press 'r' Return."
    $selection = Read-Host "Please select provisionner config"
    If($selection -eq "r") 
    {
        Show-proxyMenu
        break
   }
    switch ($selection)
    {
        '1' {
           $option = "-var provision=centos"
        }
        '2' {
           $option = "-var 'provision=tuleap'"
        } 
        '3' {
           $option = "-var 'provision=ldap'"
        } 
        '0' {
            $option = $null
        }  
    }   
} until (-not ([string]::IsNullOrEmpty($selection)))
return $option
}

function BuildPacker
{
param (
    [string]$Title = 'Packer Menu'
) 

     $option=Show-packerMenu $Title
 
     $env:PACKER_LOG=1
     $env:PACKER_LOG_PATH="packerlog.txt"
     $host.ui.RawUI.WindowTitle = "packer build $option packerConfig.json"
     Set-Rootpw
     invoke-expression  "packer build $option packerConfig.json"
     Pause
 }


Function BuildProxy {

    Param(
        [switch] $proxy=$false
    )
    if($proxy) {
        Start-Px(Test-Px)
        BuildPacker "Packer Build Tuleap Using Px Proxy"
        Stop-Px
    } elseif (-not $proxy) {
        BuildPacker "Packer Build Tuleap Using Direct Internet"
    }

}

function Show-proxyMenu
{
    param (
        [string]$Title = 'Proxy Menu'
    )

    do
 {
    Clear-Host
    Write-Host "================ $Title ================"
    
    Write-Host " Press 'Any Key' Direct Internet."
    Write-Host " Press 'y' Proxy Internet."
    Write-Host " Press 'x' Exit."

    $selection = Read-Host "                   Please make a selection"
    If($selection -eq "x") 
    {
        $selection=$null
        break
    }     
     switch ($selection)
     {
         'y' {
            $option = "-proxy"
         }
         default {
            $option = "" 
         }  
     }
     $BuildProxyInvoke = "BuildProxy";
     invoke-expression  "$BuildProxyInvoke $option"
 }
 until (-not ([string]::IsNullOrEmpty($selection)))
}

function BuildTuleap
{
param (
    [string]$Title = 'Tuleap VM Image'
) 

$host.ui.RawUI.WindowTitle=$Title
Show-proxyMenu "Network Proxy Settings"

}


BuildTuleap

