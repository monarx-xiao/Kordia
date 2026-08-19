#####################  SQL Server Full Stack Install DSC Configuration #####################
# This DSC configuration installs SQL Server 2022, SSMS, New Relic Infrastructure agent,
# New Relic SQL integration, ODBC and OLE DB drivers, and .NET 4.7.2 on a Windows machine.
# It also configures a New Relic SQL login and users for all non-system databases.


Configuration Install-SqlServerFullStack
{
    param(
        [Parameter(Mandatory=$true)]
        [string[]] $NodeName,

        [Parameter(Mandatory=$true)]
        [PSCredential] $NewRelicSqlCredential,   # SQL login credential for New Relic (username will be used?)

        [Parameter(Mandatory=$true)]
        [string] $SaPassword,                     # SA (or install) password for SQL unattended install - ask bo if this meets the complexity ref doc

        [Parameter(Mandatory=$false)]
        [string] $DownloadPath = 'C:\DSC\Downloads',

        [Parameter(Mandatory=$false)]
        [string] $SqlInstallerUrl = 'https://go.microsoft.com/fwlink/?linkid=2215202&clcid=0x409&culture=en-us&country=us',

        [Parameter(Mandatory=$false)]
        [string] $DotNetUrl = 'https://go.microsoft.com/fwlink/?LinkId=863262',

        [Parameter(Mandatory=$false)]
        [string] $SsmsUrl = 'https://aka.ms/ssms/21/release/vs_SSMS.exe',

        [Parameter(Mandatory=$false)]
        [string] $NewRelicInfraUrl = 'https://download.newrelic.com/infrastructure_agent/windows/newrelic-infra.msi',

        [Parameter(Mandatory=$false)]
        [string] $NewRelicMsiSqlUrl = 'https://download.newrelic.com/infrastructure_agent/windows/integrations/nri-mssql/nri-mssql-amd64.msi',

        [Parameter(Mandatory=$false)]
        [string] $OdbcUrl = 'https://go.microsoft.com/fwlink/?linkid=2266337',   # ODBC 17
        [Parameter(Mandatory=$false)]
        [string] $OleDbUrl = 'https://go.microsoft.com/fwlink/?linkid=2318002'  # OLE DB
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node $NodeName {
        # ensure the download folder exists
        File DownloadFolder {
            Ensure = "Present"
            Type   = "Directory"
            DestinationPath = $DownloadPath
        }

        #
        # Helper Script resource to download a URL if file not present
        #
        Script Download-DotNet {
            DependsOn = "[File]DownloadFolder"
            GetScript = {
                @{ Result = (Test-Path $Using:DotNetPath) }
            }
            TestScript = {
                Test-Path $Using:DotNetPath
            }
            SetScript = {
                Write-Verbose "Downloading .NET from $($Using:DotNetUrl) to $($Using:DotNetPath)"
                Invoke-WebRequest -Uri $Using:DotNetUrl -OutFile $Using:DotNetPath -UseBasicParsing -ErrorAction Stop
            }
        }

        Script Download-SqlInstaller {
            DependsOn = "[File]DownloadFolder"
            GetScript = {
                @{ Result = (Test-Path $Using:SqlInstallerPath) }
            }
            TestScript = {
                Test-Path $Using:SqlInstallerPath
            }
            SetScript = {
                Invoke-WebRequest -Uri $Using:SqlInstallerUrl -OutFile $Using:SqlInstallerPath -UseBasicParsing -ErrorAction Stop
            }
        }

        Script Download-SSMS {
            DependsOn = "[File]DownloadFolder"
            GetScript = { @{ Result = (Test-Path $Using:SsmsPath) } }
            TestScript = { Test-Path $Using:SsmsPath }
            SetScript = {
                Invoke-WebRequest -Uri $Using:SsmsUrl -OutFile $Using:SsmsPath -UseBasicParsing -ErrorAction Stop
            }
        }

        Script Download-NewRelicInfra {
            DependsOn = "[File]DownloadFolder"
            GetScript = { @{ Result = (Test-Path $Using:NewRelicInfraPath) } }
            TestScript = { Test-Path $Using:NewRelicInfraPath }
            SetScript = {
                Invoke-WebRequest -Uri $Using:NewRelicInfraUrl -OutFile $Using:NewRelicInfraPath -UseBasicParsing -ErrorAction Stop
            }
        }

        Script Download-NewRelicSqlIntegration {
            DependsOn = "[File]DownloadFolder"
            GetScript = { @{ Result = (Test-Path $Using:NewRelicSqlIntegrationPath) } }
            TestScript = { Test-Path $Using:NewRelicSqlIntegrationPath }
            SetScript = {
                Invoke-WebRequest -Uri $Using:NewRelicMsiSqlUrl -OutFile $Using:NewRelicSqlIntegrationPath -UseBasicParsing -ErrorAction Stop
            }
        }

        Script Download-Odbc {
            DependsOn = "[File]DownloadFolder"
            GetScript = { @{ Result = (Test-Path $Using:OdbcPath) } }
            TestScript = { Test-Path $Using:OdbcPath }
            SetScript = {
                Invoke-WebRequest -Uri $Using:OdbcUrl -OutFile $Using:OdbcPath -UseBasicParsing -ErrorAction Stop
            }
        }

        Script Download-OleDb {
            DependsOn = "[File]DownloadFolder"
            GetScript = { @{ Result = (Test-Path $Using:OleDbPath) } }
            TestScript = { Test-Path $Using:OleDbPath }
            SetScript = {
                Invoke-WebRequest -Uri $Using:OleDbUrl -OutFile $Using:OleDbPath -UseBasicParsing -ErrorAction Stop
            }
        }

        #
        # Install .NET 4.7.2 (EXE). Test by checking registry release key for v4 Full
        #
        Script Install-DotNet472 {
            DependsOn = "[Script]Download-DotNet"
            GetScript = { @{ Installed = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -ErrorAction SilentlyContinue).Release } }
            TestScript = {
                $rel = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -ErrorAction SilentlyContinue).Release
                # .NET 4.7.2 Release key = 461808
                return ($rel -ge 461808)
            }
            SetScript = {
                $exe = $Using:DotNetPath
                & $exe /q /norestart
                # Wait briefly and retry registry check
                Start-Sleep -Seconds 10
            }
        }

        # Install SQL Server 2022 (unattended). typical silent install.
        # Adjust features/instance name/paths for your environment.
        #
        Script Install-SqlServer2022 {
            DependsOn = "[Script]Download-SqlInstaller"
            GetScript = {
                # detect by checking SQL Server 16.0 registry
                $key = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\150\InstalledInstances'
                $exists = (Test-Path $key)
                @{ Installed = $exists }
            }
            TestScript = {
                # Check if default instance MSSQLSERVER is present in registry instances for 16.x (SQL 2022)
                $instancesKey = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL'
                if (Test-Path $instancesKey) {
                    $vals = Get-ItemProperty -Path $instancesKey -ErrorAction SilentlyContinue
                    return ($vals.PSObject.Properties.Count -gt 0)
                } else { return $false }
            }
            SetScript = {
                $installer = $Using:SqlInstallerPath
                # Example silent install args - customize FEATURES, INSTANCENAME, and security (SA password)
                $cfgArgs = '/q /ACTION=Install /IACCEPTSQLSERVERLICENSETERMS /FEATURES=SQLENGINE,SSMS,RS /INSTANCENAME=MSSQLSERVER /SECURITYMODE=SQL /SAPWD="' + $Using:SaPassword + '" /TCPENABLED=1'
                # run installer
                Start-Process -FilePath $installer -ArgumentList $cfgArgs -Wait -NoNewWindow
                Start-Sleep -Seconds 15
            }
        }

        #
        # Install SSMS (installer is an EXE)
        #
        Script Install-SSMS {
            DependsOn = "[Script]Download-SSMS"
            GetScript = {
                $reg = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
                $found = Get-ChildItem $reg -Recurse -ErrorAction SilentlyContinue |
                    Get-ItemProperty -ErrorAction SilentlyContinue |
                    Where-Object { $_.DisplayName -like '*SQL Server Management Studio*' } |
                    Select-Object -First 1
                @{ Installed = ($null -ne $found) }
            }
            TestScript = {
                $reg = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
                $found = Get-ChildItem $reg -Recurse -ErrorAction SilentlyContinue |
                    Get-ItemProperty -ErrorAction SilentlyContinue |
                    Where-Object { $_.DisplayName -like '*SQL Server Management Studio*' } |
                    Select-Object -First 1
                return ($null -ne $found)
            }
            SetScript = {
                $exe = $Using:SsmsPath
                Start-Process -FilePath $exe -ArgumentList '/install','/quiet','/norestart' -Wait -NoNewWindow
            }
        }

        #
        # Install New Relic Infrastructure agent (MSI) using Package (ID-based) - fallback to Script if needed
        #
        Package Install-NewRelicInfra {
            Name = "NewRelic Infrastructure"
            Path = $DownloadPath + '\newrelic-infra.msi'
            ProductId = ""    # optional; leave blank to allow installer to detect
            Arguments = '/qn /norestart'
            Ensure = "Present"
            DependsOn = "[Script]Download-NewRelicInfra"
        }

        #
        # Install New Relic SQL integration (MSI)
        #
        Package Install-NewRelicSqlIntegration {
            Name = "NewRelic MSSQL Integration"
            Path = $DownloadPath + '\nri-mssql-amd64.msi'
            Arguments = '/qn /norestart'
            Ensure = "Present"
            DependsOn = "[Script]Download-NewRelicSqlIntegration"
        }

        #
        # Install ODBC driver (MSI)
        #
        Package Install-ODBC {
            Name = "ODBC Driver 17 for SQL Server"
            Path = $DownloadPath + '\msodbcsql.msi'
            Arguments = '/qn /norestart'
            Ensure = "Present"
            DependsOn = "[Script]Download-Odbc"
        }

        #
        # Install OLE DB driver (MSI)
        #
        Package Install-OleDb {
            Name = "MS OLE DB Driver"
            Path = $DownloadPath + '\msoledb.msi'
            Arguments = '/qn /norestart'
            Ensure = "Present"
            DependsOn = "[Script]Download-OleDb"
        }

        #
        # Create New Relic SQL login and users for all non-system DBs using sqlcmd
        #
        Script Configure-NewRelicSqlLogin {
            DependsOn = @(
                "[Script]Install-SqlServer2022",
                "[Package]Install-NewRelicInfra"
            )
            GetScript = { @{ Result = "Query performed" } }
            TestScript = {
                $user = $Using:NewRelicSqlCredential.UserName
                $check = "SELECT COUNT(*) FROM sys.server_principals WHERE name = '$user'"
                $res = & sqlcmd -S localhost -Q $check -h -1 2>$null
                return ([int]($res.Trim()) -gt 0)
            }
            SetScript = {
                $user = $Using:NewRelicSqlCredential.UserName
                $pw = $Using:NewRelicSqlCredential.GetNetworkCredential().Password

                # create login if missing
                $createLogin = @"
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$user')
BEGIN
    CREATE LOGIN [$user] WITH PASSWORD = N'$pw', CHECK_POLICY = OFF;
    GRANT CONNECT SQL TO [$user];
    GRANT VIEW SERVER STATE TO [$user];
    GRANT VIEW ANY DEFINITION TO [$user];
END
"@

                $createLogin | Out-File -FilePath "$env:TEMP\create_newrelic_login.sql" -Encoding ascii
                & sqlcmd -S localhost -i "$env:TEMP\create_newrelic_login.sql"

                # create user in each non-system database
                $dbList = & sqlcmd -S localhost -Q "SET NOCOUNT ON; SELECT name FROM sys.databases WHERE name NOT IN ('master','msdb','tempdb','model','rdsadmin','distribution')" -h -1
                $dbList = $dbList -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                foreach ($db in $dbList) {
                    $createUserCmd = "IF NOT EXISTS (SELECT 1 FROM [$db].sys.database_principals WHERE name = N'$user') BEGIN USE [$db]; CREATE USER [$user] FOR LOGIN [$user]; END"
                    & sqlcmd -S localhost -Q $createUserCmd
                }

                Remove-Item "$env:TEMP\create_newrelic_login.sql" -ErrorAction SilentlyContinue
            }
        }

        #
        # Write the New Relic mssql-config.yml (template). We will place this in integration.d
        #
        File NewRelicMssqlConfig {
            DependsOn = "[Package]Install-NewRelicSqlIntegration"
            Ensure = 'Present'
            Type = 'File'
            DestinationPath = 'C:\Program Files\newrelic\integration.d\mssql-config.yml'
            Contents = @"
variables:
  password:
    obfuscated:
      key: pass
      secret: QlFCQz0OARYkCRIdPQQWBwM1GxY1GBYAUQ==
integrations:
  - name: nri-mssql
    env:
      HOSTNAME: $($env:COMPUTERNAME)
      USERNAME: $($Using:NewRelicSqlCredential.UserName)
      PASSWORD: "${password}"
      INSTANCE:
    inventory_source: config/mssql
    interval: 15
"@
        }

        #
        # Restart New Relic service to pick up config
        #
        Script Restart-NewRelicService {
            DependsOn = "[File]NewRelicMssqlConfig"
            GetScript = { @{ Result = (Get-Service -Name newrelic-infra -ErrorAction SilentlyContinue).Status } }
            TestScript = {
                # If service exists and is running - nothing to do
                $svc = Get-Service -Name newrelic-infra -ErrorAction SilentlyContinue
                return ($svc -and $svc.Status -eq 'Running')
            }
            SetScript = {
                if (Get-Service -Name newrelic-infra -ErrorAction SilentlyContinue) {
                    Restart-Service -Name newrelic-infra -Force -ErrorAction SilentlyContinue
                } else {
                    Write-Warning 'newrelic-infra service not present (agent may not have installed).'
                }
            }
        }
    } # Node block

    # define helper var paths at the configuration scope (used by Script resources via $Using:)
    ConfigurationData {
        
    }
}

# ---- helper: set path variables used by 'Using' in Script resources ----
# To compile, set these variables in the session and then call the configuration:
$DownloadPath = 'C:\DSC\Downloads'
$DotNetPath = Join-Path $DownloadPath 'ndp472-x86-x64-allos-enu.exe'         # Download the file in doc from Box
$SqlInstallerPath = Join-Path $DownloadPath 'SQLServer2022Setup.exe'         # Download the file in doc from Box
$SsmsPath = Join-Path $DownloadPath 'vs_SSMS.exe'
$NewRelicInfraPath = Join-Path $DownloadPath 'newrelic-infra.msi'
$NewRelicSqlIntegrationPath = Join-Path $DownloadPath 'nri-mssql-amd64.msi'
$OdbcPath = Join-Path $DownloadPath 'msodbcsql.msi'
$OleDbPath = Join-Path $DownloadPath 'msoledb.msi'

# compile for local computer (replace credential & SA password)
# $cred = Get-Credential -Message 'New Relic SQL login credential (enter username/password)'# added on script v.2
# Install-SqlServerFullStack -NodeName 'localhost' -NewRelicSqlCredential $cred -SaPassword 'YourSA!Passw0rd' -DownloadPath $DownloadPath
# Start-DscConfiguration -Path .\Install-SqlServerFullStack -Wait -Verbose -Force # Launch DSC (test this before uat)
