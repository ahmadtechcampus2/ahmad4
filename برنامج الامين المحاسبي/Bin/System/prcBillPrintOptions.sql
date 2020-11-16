#########################################################
CREATE PROC prcGetBillPrintOptions
	@billTypeGuid UNIQUEIDENTIFIER,
	@userGuid UNIQUEIDENTIFIER,
	@ConfigurationID UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	SELECT 
		[m].[BillLayoutGUID] AS [MasterBillLayoutGUID],
		ISNULL( [d].[BillLayoutGUID], 0X0) AS [DetailsBillLayoutGUID]
	FROM 
		[BPOptions000] [m] 
		LEFT JOIN [BPOptionsDetails000] [d] ON [m].[guid] = [d].[ParentGUID]
	WHERE 
		m.BillTypeGUID = @billTypeGuid
		AND m.UserGUID = @userGuid
		AND m.ConfigurationID = @ConfigurationID

#########################################################
CREATE PROC prcDeleteBillPrintOptions
	@billTypeGuid UNIQUEIDENTIFIER,
	@userGuid UNIQUEIDENTIFIER,
	@ConfigurationID UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	DELETE BPOptions000
	WHERE 
		BillTypeGUID = @billTypeGuid
		AND UserGUID = @userGuid
		AND ConfigurationID = @ConfigurationID
#########################################################
#END
