##########################################################################
CREATE PROCEDURE prcUser_BuildSecurityTable
	@UserGUID UNIQUEIDENTIFIER = NULL
AS BEGIN 
	-- delete this user items from uix.
	-- build user security table from us000 and ui000.
	-- consider option AmnCfg_PessimisticSecurity in table op000 when building security table.
	SET NOCOUNT ON

	DECLARE @t_Roles TABLE(GUID UNIQUEIDENTIFIER) 
	DECLARE @t_Permissions TABLE(ReportID BIGINT, SubID UNIQUEIDENTIFIER, PermType INT, Permission INT, [System] INT)

	-- prepare uix:
	DELETE uix WHERE UserGUID = @UserGUID 
	INSERT INTO @t_Roles SELECT GUID FROM dbo.fnGetUserRolesList(@UserGUID)

	-- Test if user is admin:
	IF EXISTS(SELECT * FROM @t_Roles AS r INNER JOIN vtUS AS u on r.GUID = u.GUID WHERE bAdmin = 1) 
	BEGIN 
		INSERT INTO uix (UserGUID, ReportID, SubID) SELECT @UserGUID, 0, 0x0 
		-- insert all branches:
		INSERT INTO uix( UserGUID, ReportID, SubID, PermType, Permission)  
			SELECT @UserGUID, CAST( 0x1001F000 AS BIGINT), vtBr.GUID, 0, 1  
			FROM vtBr  
		RETURN 
	END

	INSERT INTO @t_Permissions SELECT uiReportID, uiSubID, uiPermType, uiPermission, uiSystem FROM vwUI AS u INNER JOIN @t_Roles AS r ON u.uiUserGUID = r.GUID
	INSERT INTO @t_Permissions SELECT 1, 0x0, 1, usMaxDiscount, 1 FROM @t_Roles AS r INNER JOIN vwUS u ON r.GUID = u.usGUID
	INSERT INTO @t_Permissions SELECT 1, 0x0, 2, usMinPrice, 1 FROM @t_Roles AS r INNER JOIN vwUS u ON r.GUID = u.usGUID

	-- remove inheritors: 
	DELETE FROM @t_Permissions WHERE Permission = -1 

	-- remove denyed: 
	DELETE mstr 
		FROM @t_Permissions mstr INNER JOIN @t_Permissions slv ON  
			mstr.ReportID = slv.ReportID AND
			mstr.SubID = slv.SubID AND
			mstr.PermType = slv.PermType AND
			mstr.[System] = slv.[System]
		WHERE mstr.Permission = -2

	-- insert: 
	INSERT INTO uix (UserGUID, ReportID, SubID, PermType, Permission, [System])
		SELECT @UserGUID, ReportID, SubID, PermType, (CASE dbo.fnOption_GetBit('AmnCfg_PessimisticSecurity', DEFAULT) WHEN 0 THEN MIN(Permission) ELSE MAX(Permission) END), [system]
		FROM @t_Permissions 
		GROUP BY ReportID, SubID, PermType, [System]
		 
END 

##########################################################################
#END