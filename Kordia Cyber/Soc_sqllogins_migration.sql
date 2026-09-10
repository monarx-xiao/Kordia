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