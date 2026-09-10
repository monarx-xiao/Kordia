/* =====================================================================================
   EXTRACT MASTER/MSDB INSTANCE-LEVEL OBJECTS FOR AZURE SQL MANAGED INSTANCE MIGRATION
   =====================================================================================
   Run each section on the SOURCE on-prem SQL Server 2019 instance.
   Each section PRINTs/generates T-SQL that you then review and run against the
   TARGET Managed Instance. Nothing here executes changes on the source.

   Sections:
     1. Logins (SQL logins with SIDs/password hashes preserved, Windows/Entra logins)
     2. SQL Server Agent jobs, schedules, job steps, operators, alerts
     3. Linked servers and their logins

   Notes:
   - Run as a member of sysadmin on the source.
   - Increase output row size in SSMS: Tools > Options > Query Results > Results to Grid
     > "Maximum Characters Retrieved" to a large value (e.g., 65535), or switch to
     "Results to Text" for these scripts, since the generated statements can be long.
   ===================================================================================== */


/* =====================================================================================
   SECTION 1 — LOGINS (sp_help_revlogin)
   =====================================================================================
   This is Microsoft's official script for scripting out SQL logins with their
   original SID and password hash so that after the user databases are restored/
   migrated, the database users on the target map correctly to the recreated logins
   (avoids "orphaned user" issues). It also scripts Windows logins (password can't be
   captured for Windows auth — not needed, since it's validated by Windows/Entra).

   IMPORTANT for SQL MI:
   - SQL MI supports SQL authentication logins and Microsoft Entra (Azure AD) logins.
   - Classic on-prem "Windows logins" (DOMAIN\user) are NOT supported as-is on SQL MI;
     if the on-prem instance is Entra-joined/hybrid, map these to Entra logins instead.
   - CREATE LOGIN ... WITH SID = ... syntax below works on SQL MI for SQL logins.
   ===================================================================================== */

USE master;
GO

IF OBJECT_ID('sp_hexadecimal') IS NOT NULL
    DROP PROCEDURE sp_hexadecimal;
GO

CREATE PROCEDURE sp_hexadecimal
    @binvalue VARBINARY(256),
    @hexvalue VARCHAR(514) OUTPUT
AS
BEGIN
    DECLARE @charvalue VARCHAR(514);
    DECLARE @i INT;
    DECLARE @length INT;
    DECLARE @hexstring CHAR(16);
    SELECT @charvalue = '0x';
    SELECT @i = 1;
    SELECT @length = DATALENGTH(@binvalue);
    SELECT @hexstring = '0123456789ABCDEF';
    WHILE (@i <= @length)
    BEGIN
        DECLARE @tempint INT;
        DECLARE @firstint INT;
        DECLARE @secondint INT;
        SELECT @tempint = CONVERT(INT, SUBSTRING(@binvalue, @i, 1));
        SELECT @firstint = FLOOR(@tempint / 16);
        SELECT @secondint = @tempint - (@firstint * 16);
        SELECT @charvalue = @charvalue +
            SUBSTRING(@hexstring, @firstint + 1, 1) +
            SUBSTRING(@hexstring, @secondint + 1, 1);
        SELECT @i = @i + 1;
    END;
    SELECT @hexvalue = @charvalue;
END;
GO

IF OBJECT_ID('sp_help_revlogin') IS NOT NULL
    DROP PROCEDURE sp_help_revlogin;
GO

CREATE PROCEDURE sp_help_revlogin
    @login_name SYSNAME = NULL
AS
BEGIN
    DECLARE @name SYSNAME;
    DECLARE @type VARCHAR(1);
    DECLARE @hasaccess INT;
    DECLARE @denylogin INT;
    DECLARE @is_disabled INT;
    DECLARE @PWD_varbinary VARBINARY(256);
    DECLARE @PWD_string VARCHAR(514);
    DECLARE @SID_varbinary VARBINARY(85);
    DECLARE @SID_string VARCHAR(514);
    DECLARE @tmpstr VARCHAR(1024);
    DECLARE @is_policy_checked VARCHAR(3);
    DECLARE @is_expiration_checked VARCHAR(3);
    DECLARE @defaultdb SYSNAME;

    IF (@login_name IS NULL)
        DECLARE login_curs CURSOR FOR
            SELECT p.sid, p.name, p.type, p.is_disabled, p.default_database_name,
                   l.hasaccess, l.denylogin
            FROM sys.server_principals p
            LEFT JOIN sys.syslogins l ON l.sid = p.sid
            WHERE p.type IN ('S', 'G', 'U') AND p.name <> 'sa';
    ELSE
        DECLARE login_curs CURSOR FOR
            SELECT p.sid, p.name, p.type, p.is_disabled, p.default_database_name,
                   l.hasaccess, l.denylogin
            FROM sys.server_principals p
            LEFT JOIN sys.syslogins l ON l.sid = p.sid
            WHERE p.type IN ('S', 'G', 'U') AND p.name = @login_name;

    OPEN login_curs;
    FETCH NEXT FROM login_curs INTO @SID_varbinary, @name, @type, @is_disabled,
        @defaultdb, @hasaccess, @denylogin;

    IF (@@fetch_status = -1)
    BEGIN
        PRINT 'No login(s) found.';
        CLOSE login_curs;
        DEALLOCATE login_curs;
        RETURN -1;
    END;

    SET @tmpstr = '-- Login script generated ' + CONVERT(VARCHAR, GETDATE());
    PRINT @tmpstr;

    WHILE (@@fetch_status <> -1)
    BEGIN
        IF (@@fetch_status <> -2)
        BEGIN
            SET @tmpstr = '-- Login: ' + @name;
            PRINT @tmpstr;

            IF (@type IN ('G', 'U'))
            BEGIN
                SET @tmpstr = 'CREATE LOGIN ' + QUOTENAME(@name) + ' FROM WINDOWS WITH DEFAULT_DATABASE = [' + @defaultdb + ']';
            END
            ELSE
            BEGIN
                EXEC sp_hexadecimal @SID_varbinary, @SID_string OUT;
            END;

            IF (@type = 'S')
            BEGIN
                SELECT @PWD_varbinary = CAST(LOGINPROPERTY(@name, 'PasswordHash') AS VARBINARY(256));
                EXEC sp_hexadecimal @PWD_varbinary, @PWD_string OUT;

                SELECT @is_policy_checked = CASE is_policy_checked WHEN 1 THEN 'ON' WHEN 0 THEN 'OFF' ELSE NULL END
                FROM sys.sql_logins WHERE name = @name;
                SELECT @is_expiration_checked = CASE is_expiration_checked WHEN 1 THEN 'ON' WHEN 0 THEN 'OFF' ELSE NULL END
                FROM sys.sql_logins WHERE name = @name;

                SET @tmpstr = 'CREATE LOGIN ' + QUOTENAME(@name) + ' WITH PASSWORD = ' + @PWD_string + ' HASHED, SID = ' + @SID_string + ', DEFAULT_DATABASE = [' + @defaultdb + ']';

                IF (@is_policy_checked IS NOT NULL)
                    SET @tmpstr = @tmpstr + ', CHECK_POLICY = ' + @is_policy_checked;
                IF (@is_expiration_checked IS NOT NULL)
                    SET @tmpstr = @tmpstr + ', CHECK_EXPIRATION = ' + @is_expiration_checked;
            END;

            IF (@denylogin = 1)
                SET @tmpstr = @tmpstr + '; -- ** NOTE: this login is DENIED access **';
            ELSE IF (@hasaccess = 0)
                SET @tmpstr = @tmpstr + '; -- ** NOTE: this login has NO access **';

            IF (@is_disabled = 1)
                SET @tmpstr = @tmpstr + '; ALTER LOGIN ' + QUOTENAME(@name) + ' DISABLE';

            PRINT @tmpstr;
        END;

        FETCH NEXT FROM login_curs INTO @SID_varbinary, @name, @type, @is_disabled,
            @defaultdb, @hasaccess, @denylogin;
    END;

    CLOSE login_curs;
    DEALLOCATE login_curs;
    RETURN 0;
END;
GO

-- Generate the CREATE LOGIN statements. Copy the PRINT output and run it on the target MI.
EXEC sp_help_revlogin;
GO

-- Cleanup helper procs on the source once you're done (optional)
-- DROP PROCEDURE sp_help_revlogin;
-- DROP PROCEDURE sp_hexadecimal;


/* -------------------------------------------------------------------------------------
   1b. Server roles and role memberships (fixed + user-defined server roles)
   ------------------------------------------------------------------------------------- */

-- User-defined server roles
SELECT 'CREATE SERVER ROLE ' + QUOTENAME(name) + ';' AS script_out
FROM sys.server_principals
WHERE type = 'R' AND is_fixed_role = 0;

-- Role membership (works for both fixed and user-defined roles)
SELECT 'ALTER SERVER ROLE ' + QUOTENAME(r.name) +
       ' ADD MEMBER ' + QUOTENAME(m.name) + ';' AS script_out
FROM sys.server_role_members rm
JOIN sys.server_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.server_principals m ON m.principal_id = rm.member_principal_id
WHERE m.name NOT IN ('sa') AND m.type IN ('S','U','G');

-- Server-level permissions (GRANT/DENY)
SELECT
    CASE state
        WHEN 'G' THEN 'GRANT '
        WHEN 'W' THEN 'GRANT '
        WHEN 'D' THEN 'DENY '
    END + permission_name COLLATE DATABASE_DEFAULT +
    ' TO ' + QUOTENAME(grantee.name) +
    CASE WHEN state = 'W' THEN ' WITH GRANT OPTION' ELSE '' END + ';' AS script_out
FROM sys.server_permissions perm
JOIN sys.server_principals grantee ON grantee.principal_id = perm.grantee_principal_id
WHERE grantee.name NOT IN ('sa','public')
  AND grantee.type IN ('S','U','G');


/* -------------------------------------------------------------------------------------
   1c. Server-level credentials (used for BACKUP TO URL, proxy accounts, etc.)
   Note: secret/password values cannot be extracted — you must know/reset them
   on the target and recreate the credential manually.
   ------------------------------------------------------------------------------------- */

SELECT
    'CREATE CREDENTIAL ' + QUOTENAME(name) +
    ' WITH IDENTITY = ''' + credential_identity + ''', SECRET = ''<REPLACE_WITH_SECRET>'';' AS script_out
FROM sys.credentials;



/* =====================================================================================
   SECTION 2 — SQL SERVER AGENT: JOBS, SCHEDULES, STEPS, OPERATORS, ALERTS
   =====================================================================================
   The most reliable path is still SSMS's built-in scripter:
     Object Explorer > SQL Server Agent > Jobs > right-click a job (or select several)
     > Script Job as > CREATE To > New Query Editor Window
   That uses SMO under the hood and produces fully faithful sp_add_job / sp_add_jobstep /
   sp_add_jobschedule scripts, including encrypted/complex step command text.

   The T-SQL below is a pure-T-SQL alternative useful for bulk/scripted extraction
   (e.g., piping into source control) when SSMS's GUI scripter isn't convenient.
   It reconstructs standard sp_add_job / sp_add_jobstep / sp_add_jobschedule calls
   from msdb system tables. Review the generated output before running on the target.
   ===================================================================================== */

USE msdb;
GO

-- 2a. Operators
SELECT
    'EXEC msdb.dbo.sp_add_operator @name=N''' + REPLACE(name,'''','''''') + ''', ' +
    '@enabled=' + CAST(enabled AS VARCHAR) + ', ' +
    '@email_address=' + ISNULL('N''' + REPLACE(email_address,'''','''''') + '''','NULL') + ', ' +
    '@pager_address=' + ISNULL('N''' + REPLACE(pager_address,'''','''''') + '''','NULL') + ';' AS script_out
FROM msdb.dbo.sysoperators;

-- 2b. Jobs (base job definition)
SELECT
    'EXEC msdb.dbo.sp_add_job @job_name=N''' + REPLACE(j.name,'''','''''') + ''', ' +
    '@enabled=' + CAST(j.enabled AS VARCHAR) + ', ' +
    '@description=' + ISNULL('N''' + REPLACE(j.description,'''','''''') + '''','NULL') + ', ' +
    '@owner_login_name=N''' + SUSER_SNAME(j.owner_sid) + ''', ' +
    '@notify_level_eventlog=' + CAST(j.notify_level_eventlog AS VARCHAR) + ', ' +
    '@notify_level_email=' + CAST(j.notify_level_email AS VARCHAR) + ', ' +
    '@category_name=N''' + ISNULL(c.name,'[Uncategorized (Local)]') + ''';' AS script_out
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.syscategories c ON c.category_id = j.category_id;

-- 2c. Job steps
SELECT
    'EXEC msdb.dbo.sp_add_jobstep @job_name=N''' + REPLACE(j.name,'''','''''') + ''', ' +
    '@step_name=N''' + REPLACE(s.step_name,'''','''''') + ''', ' +
    '@step_id=' + CAST(s.step_id AS VARCHAR) + ', ' +
    '@subsystem=N''' + s.subsystem + ''', ' +
    '@command=N''' + REPLACE(s.command,'''','''''') + ''', ' +
    '@database_name=N''' + ISNULL(s.database_name,'master') + ''', ' +
    '@on_success_action=' + CAST(s.on_success_action AS VARCHAR) + ', ' +
    '@on_fail_action=' + CAST(s.on_fail_action AS VARCHAR) + ', ' +
    '@retry_attempts=' + CAST(s.retry_attempts AS VARCHAR) + ', ' +
    '@retry_interval=' + CAST(s.retry_interval AS VARCHAR) + ';' AS script_out
FROM msdb.dbo.sysjobsteps s
JOIN msdb.dbo.sysjobs j ON j.job_id = s.job_id
ORDER BY j.name, s.step_id;

-- 2d. Schedules
SELECT
    'EXEC msdb.dbo.sp_add_jobschedule @job_name=N''' + REPLACE(j.name,'''','''''') + ''', ' +
    '@name=N''' + REPLACE(sch.name,'''','''''') + ''', ' +
    '@enabled=' + CAST(sch.enabled AS VARCHAR) + ', ' +
    '@freq_type=' + CAST(sch.freq_type AS VARCHAR) + ', ' +
    '@freq_interval=' + CAST(sch.freq_interval AS VARCHAR) + ', ' +
    '@freq_subday_type=' + CAST(sch.freq_subday_type AS VARCHAR) + ', ' +
    '@freq_subday_interval=' + CAST(sch.freq_subday_interval AS VARCHAR) + ', ' +
    '@freq_relative_interval=' + CAST(sch.freq_relative_interval AS VARCHAR) + ', ' +
    '@freq_recurrence_factor=' + CAST(sch.freq_recurrence_factor AS VARCHAR) + ', ' +
    '@active_start_date=' + CAST(sch.active_start_date AS VARCHAR) + ', ' +
    '@active_end_date=' + CAST(sch.active_end_date AS VARCHAR) + ', ' +
    '@active_start_time=' + CAST(sch.active_start_time AS VARCHAR) + ', ' +
    '@active_end_time=' + CAST(sch.active_end_time AS VARCHAR) + ';' AS script_out
FROM msdb.dbo.sysschedules sch
JOIN msdb.dbo.sysjobschedules js ON js.schedule_id = sch.schedule_id
JOIN msdb.dbo.sysjobs j ON j.job_id = js.job_id;

-- 2e. Job -> Server target (almost always local server for on-prem single instance)
SELECT
    'EXEC msdb.dbo.sp_add_jobserver @job_name=N''' + REPLACE(name,'''','''''') + ''', @server_name = N''(local)'';' AS script_out
FROM msdb.dbo.sysjobs;

-- 2f. Alerts
SELECT
    'EXEC msdb.dbo.sp_add_alert @name=N''' + REPLACE(name,'''','''''') + ''', ' +
    '@message_id=' + CAST(message_id AS VARCHAR) + ', ' +
    '@severity=' + CAST(severity AS VARCHAR) + ', ' +
    '@enabled=' + CAST(enabled AS VARCHAR) + ', ' +
    '@delay_between_responses=' + CAST(delay_between_responses AS VARCHAR) + ', ' +
    '@notification_message=' + ISNULL('N''' + REPLACE(notification_message,'''','''''') + '''','NULL') + ';' AS script_out
FROM msdb.dbo.sysalerts;

/* NOTE: Known limitations of the generated Agent scripts above:
   - Job step commands referencing SSIS packages, replication subsystems, or
     CmdExec proxies will need the proxy/credential and (for SSIS) the package
     itself migrated separately — the command text alone won't be enough.
   - Encrypted/obfuscated step properties, job step "database_user_name" for
     step-level impersonation, and target-server groups are not covered.
   - For anything beyond simple T-SQL/CmdExec jobs, prefer SSMS's
     "Script Job as > CREATE To" (SMO-based) instead of the above. */



/* =====================================================================================
   SECTION 3 — LINKED SERVERS
   =====================================================================================
   Passwords/secrets used for linked server logins CANNOT be extracted (SQL Server
   never stores them retrievably) — you must know the credentials to re-enter them
   on the target, or use sp_addlinkedsrvlogin without @rmtpassword and let it
   prompt/require re-entry when you run the generated script on the target.

   NOTE: SQL Managed Instance supports linked servers to other SQL Server / SQL MI
   targets and, depending on driver availability, some non-SQL sources — verify each
   linked server's provider is supported on MI before recreating it.
   ===================================================================================== */

-- 3a. Linked server definitions
SELECT
    'EXEC master.dbo.sp_addlinkedserver @server=N''' + s.name + ''', ' +
    '@srvproduct=N''' + ISNULL(s.product,'') + ''', ' +
    '@provider=N''' + ISNULL(s.provider,'') + ''', ' +
    '@datasrc=' + ISNULL('N''' + s.data_source + '''','NULL') + ', ' +
    '@catalog=' + ISNULL('N''' + s.catalog + '''','NULL') + ';' AS script_out
FROM sys.servers s
WHERE s.is_linked = 1;

-- 3b. Linked server logins (login mappings). @rmtpassword left as a placeholder —
--     fill in manually before executing on the target.
SELECT
    'EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname=N''' + s.name + ''', ' +
    '@useself=N''' + CASE WHEN ll.uses_self_credential = 1 THEN 'True' ELSE 'False' END + ''', ' +
    '@locallogin=' + ISNULL('N''' + lp.name + '''','NULL') + ', ' +
    '@rmtuser=' + ISNULL('N''' + ll.remote_name + '''','NULL') + ', ' +
    '@rmtpassword=''<REPLACE_WITH_PASSWORD>'';' AS script_out
FROM sys.linked_logins ll
JOIN sys.servers s ON s.server_id = ll.server_id
LEFT JOIN sys.server_principals lp ON lp.principal_id = ll.local_principal_id
WHERE s.is_linked = 1;

-- 3c. Linked server options (collation compatible, RPC out, data access, etc.)
SELECT
    'EXEC master.dbo.sp_serveroption @server=N''' + s.name + ''', @optname=N''collation compatible'', @optvalue=N''' + CASE WHEN s.is_collation_compatible = 1 THEN 'true' ELSE 'false' END + ''';' AS script_out
FROM sys.servers s WHERE s.is_linked = 1
UNION ALL
SELECT
    'EXEC master.dbo.sp_serveroption @server=N''' + s.name + ''', @optname=N''rpc out'', @optvalue=N''' + CASE WHEN s.is_rpc_out_enabled = 1 THEN 'true' ELSE 'false' END + ''';'
FROM sys.servers s WHERE s.is_linked = 1
UNION ALL
SELECT
    'EXEC master.dbo.sp_serveroption @server=N''' + s.name + ''', @optname=N''data access'', @optvalue=N''' + CASE WHEN s.is_data_access_enabled = 1 THEN 'true' ELSE 'false' END + ''';'
FROM sys.servers s WHERE s.is_linked = 1;
