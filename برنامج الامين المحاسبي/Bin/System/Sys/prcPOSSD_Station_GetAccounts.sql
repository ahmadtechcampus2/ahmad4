################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetAccounts
@posGuid uniqueidentifier
AS
BEGIN
       SELECT 
                     AC.Name  AS AccountName,
                     AC.LatinName  AS  AccountLatinName,
                     AC.GUID AS AccountGuid
       FROM 
                     ac000 AC INNER JOIN POSSDStation000 PC ON AC.GUID = PC.ContinuesCashGUID OR AC.GUID = PC.DebitAccGUID
       WHERE PC.Guid = @posGuid
       UNION ALL
       SELECT 
                     AC.Name  AS AccountName,
                     AC.LatinName  AS  AccountLatinName,
                     AC.GUID AS AccountGuid
       FROM 
                     ac000 AC INNER JOIN POSSDEmployee000 PE ON AC.GUID = PE.MinusAccountGUID OR AC.GUID = PE.ExtraAccountGUID
                     INNER JOIN POSSDStationEmployee000 PR ON PR.EmployeeGUID = PE.Guid AND PR.StationGUID = @posGuid
	   UNION
       SELECT 
                     AC.Name  AS AccountName,
                     AC.LatinName  AS  AccountLatinName,
                     AC.GUID AS AccountGuid
       FROM 
                     ac000 AC INNER JOIN POSSDStationCurrency000 SC ON AC.GUID = SC.CentralBoxAccGUID OR AC.GUID = SC.FloatCachAccGUID
                     WHERE SC.StationGUID = @posGuid
	   UNION
       SELECT 
                     AC.Name  AS AccountName,
                     AC.LatinName  AS  AccountLatinName,
                     AC.GUID AS AccountGuid
       FROM 
                     ac000 AC INNER JOIN POSSDStationOrder000 SO ON AC.[GUID] = SO.DownPaymentAccountGUID
                     WHERE SO.StationGUID = @posGuid
       
END

#################################################################
#END 