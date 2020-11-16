###############################################
CREATE FUNCTION fnGetTrnStatementTypesList ( 
	@SrcGuid UNIQUEIDENTIFIER = 0x0, 
	@UserGUID UNIQUEIDENTIFIER = 0x0) 
	RETURNS @Result TABLE( GUID UNIQUEIDENTIFIER, Security INT) 
AS 
BEGIN 
	IF ISNULL(@UserGUID, 0x0) = 0x0 
		SET @UserGUID = dbo.fnGetCurrentUserGUID() 
/*	IF ISNULL(@SrcGuid, 0x0)= 0x0 
		INSERT INTO @Result 
			SELECT 
					ttGUID, 
					BrowseSec, 
					ReadPriceSec 
				FROM 
					dbo.fnGetUserBillsSec( @UserGUID ) AS fn 
					INNER JOIN vwTrnTransferTypes AS b ON fn.GUID = b.ttGUID 
	ELSE */
		INSERT INTO @Result 
			SELECT 
					IdType, 
					1 --dbo.fnGetUserBillSec_Browse(@UserGUID, IdType), 
				FROM 
					dbo.RepSrcs AS r  
					INNER JOIN vwTrnStatementTypes AS b ON r.IdType = b.ttGUID 
				WHERE 
					IdTbl = @SrcGuid 
	RETURN 
END 
#####################################################
#END
