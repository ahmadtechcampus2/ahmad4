#################################################################
CREATE PROC prcPDABilling_InitData
		@PDAGUID uniqueidentifier, 
		@UserName	nvarchar(200) 
AS 
	SET NOCOUNT ON 
	 
	IF Exists (SELECT LoginName From us000 WHERE LoginName = @UserName)
		EXEC prcConnections_Add2 @UserName
	ELSE
	BEGIN
		SELECT TOP 1 @UserName = LoginName From us000 Where bAdmin = 1 
		EXEC prcConnections_Add2 @UserName
	END

	EXEC prcPDABilling_InitTrip			@PDAGUID 
	EXEC prcPDABilling_InitTemplate 	@PDAGUID 
	EXEC prcPDABilling_InitCust 		@PDAGUID 
	EXEC prcPDABilling_InitMat 			@PDAGUID 
	EXEC prcPDABilling_InitMatSn		@PDAGUID 

/*
EXEC prcPDABilling_InitData 'B662F9B9-420D-409E-A7FA-ACB654DD9D05' , '„œÌ—'
*/
#################################################################
#END