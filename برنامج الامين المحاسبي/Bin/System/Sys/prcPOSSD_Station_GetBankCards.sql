#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetBankCards
	@StationGUID UNIQUEIDENTIFIER
AS
    SET NOCOUNT ON

	SELECT 
		BC.*, 
		RC.StationGUID,
		RC.IsUsed
	FROM 
		BankCard000 BC 
		LEFT JOIN POSSDStationBankCard000 RC
		ON BC.GUID = RC.BankCardGUID AND StationGUID = @StationGUID 
	WHERE IsUsed = 1	   
	ORDER BY Number
#################################################################
#END 