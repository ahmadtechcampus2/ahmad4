#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetCurrencyAccounts
	@StationGUID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON
	 SELECT 
                     AC.Name  AS AccountName,
                     AC.LatinName  AS  AccountLatinName,
                     AC.GUID AS AccountGuid
       FROM 
                     ac000 AC INNER JOIN POSSDStationCurrency000 SC ON AC.GUID = SC.CentralBoxAccGUID OR AC.GUID = SC.FloatCachAccGUID
                     WHERE SC.StationGUID = @StationGUID AND SC.IsUsed = 1

END
#################################################################
#END 