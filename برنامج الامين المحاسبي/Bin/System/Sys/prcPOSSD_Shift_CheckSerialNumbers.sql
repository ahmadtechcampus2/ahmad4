#################################################################
CREATE PROCEDURE prcPOSSD_Shift_CheckSerialNumbers
-- Param ------------------------------------------------
		 @ShiftGUID UNIQUEIDENTIFIER,
		 @Result    INT = 1 OUTPUT
---------------------------------------------------------
AS
BEGIN

	IF NOT EXISTS ( SELECT SN.* 
				    FROM POSSDTicketItemSerialNumbers000 SN 
				    INNER JOIN POSSDTicketItem000 TI ON TI.[GUID] = SN.TicketItemGUID
				    INNER JOIN POSSDTicket000 T ON T.[GUID] = TI.TicketGUID
				    INNER JOIN POSSDShift000 SH ON SH.[GUID] = T.ShiftGUID
				    WHERE  SH.[GUID] = @ShiftGUID )
	BEGIN
		SET @Result = 1
	END


	DECLARE @StationGUID UNIQUEIDENTIFIER = ( SELECT StationGUID 
											  FROM POSSDShift000 
											  WHERE [GUID] = @ShiftGUID )

	DECLARE @StationStoreGUID UNIQUEIDENTIFIER  = ( SELECT BT.DefStoreGUID 
													FROM POSSDStation000 S INNER JOIN bt000 BT ON S.SaleBillTypeGUID = BT.[GUID] 
													WHERE S.[GUID] =  @StationGUID )


	
	SELECT 
		T.[Type]   AS TicketType, 
		TI.[GUID]  AS TicketItemGUID, 
		TI.MatGUID AS MatGUID, 
		SN.SN	   AS SN,
		SN.[GUID]  AS SNGuid
	INTO 
		#UsedSerialNumbers
	FROM 
		POSSDShift000 SH 
		INNER JOIN POSSDTicket000 T					  ON SH.[GUID] = T.ShiftGUID
		INNER JOIN POSSDTicketItem000 TI			  ON  T.[GUID] = TI.TicketGUID
		INNER JOIN POSSDTicketItemSerialNumbers000 SN ON TI.[GUID] = SN.TicketItemGUID
		INNER JOIN mt000 MT						      ON MT.[GUID] = TI.MatGUID
	WHERE 
		SH.[GUID] = @ShiftGUID
	AND MT.ForceInSN  = 1 
	AND MT.ForceOutSN = 1



	MERGE #UsedSerialNumbers AS T
	USING #UsedSerialNumbers AS S
	ON (T.SN = S.SN)
	WHEN MATCHED AND (S.MatGUID = T.MatGUID) AND (S.TicketType <> T.TicketType)
	THEN DELETE;

	
	DELETE 
		#UsedSerialNumbers
    WHERE 
		SNGuid IN( SELECT UsedSN.SNGuid
				   FROM snc000 SNC
				   INNER JOIN snt000 SNT ON SNC.[GUID] = SNT.ParentGUID
				   INNER JOIN #UsedSerialNumbers UsedSN ON SNC.MatGUID = UsedSN.MatGUID AND SNC.sn = UsedSN.SN
				   WHERE 
				   SNT.stGUID = @StationStoreGUID
				   AND (SNC.Qty > 0) )


	DELETE 
		#UsedSerialNumbers 
	WHERE 
		TicketType = 2


	IF EXISTS(SELECT * FROM #UsedSerialNumbers)
	BEGIN 
		SET @Result = 0
	END
	ELSE
	BEGIN
		SET @Result = 1
	END

END
#################################################################
#END 