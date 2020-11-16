###############################################
CREATE FUNCTION fnGetTransfersTypesList ( 
	@SrcGuid UNIQUEIDENTIFIER = 0x0, 
	@UserGUID UNIQUEIDENTIFIER = 0x0) 
	RETURNS @Result TABLE( GUID UNIQUEIDENTIFIER, Security INT) 
AS 
BEGIN 
	IF ISNULL(@UserGUID, 0x0) = 0x0 
		SET @UserGUID = dbo.fnGetCurrentUserGUID() 

		INSERT INTO @Result 
			SELECT 
					IdType, 
					1 
				FROM 
					dbo.RepSrcs AS r  
					INNER JOIN VwTrnBranchOffice() AS b ON 	r.IdType = b.GUID 
				WHERE 
					IdTbl = @SrcGuid 
	RETURN 
END 
###############################################
CREATE FUNCTION fnGetTransfersCenterList 
	( 
		@SrcGuid UNIQUEIDENTIFIER = 0x0, 
		@UserGUID UNIQUEIDENTIFIER = 0x0
	) 
	RETURNS @Result TABLE( GUID UNIQUEIDENTIFIER, Security INT) 
AS 
BEGIN 
	IF ISNULL(@UserGUID, 0x0) = 0x0 
		SET @UserGUID = dbo.fnGetCurrentUserGUID() 

		INSERT INTO @Result 
			SELECT 
					IdType, 
					1 
				FROM 
					dbo.RepSrcs AS r  
					INNER JOIN vwTrnCenter AS c ON 	r.IdType = c.GUID 
				WHERE 
					IdTbl = @SrcGuid 
	RETURN 
END 
#####################################################
CREATE PROC prcTrn_GetNewTransNum
	@TypeGUID uniqueidentifier
AS
	SELECT 
		ISNUll(Max(Number), 0) + 1 AS NewNum 
	FROM trnTransferVoucher000
#####################################################
CREATE Function fnGetTotalGeneralBranchMask()
RETURNS BIGINT
AS 
BEGIN
	DECLARE @cnt INT = 0,
			@mask INT = 0
	SELECT @cnt = count(*) - 1 from br000
	while @cnt >= 0
	BEGIN
		SET @mask = @mask | POWER(2, @cnt)
		SET @cnt -= 1
	END
	RETURN @mask
END
#####################################################
#END