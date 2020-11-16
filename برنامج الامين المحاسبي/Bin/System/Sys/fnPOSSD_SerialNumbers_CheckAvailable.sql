#################################################################
CREATE FUNCTION fnPOSSD_SerialNumbers_CheckAvailable
-- Param ------------------------------------------------
		(	@POSGuid		UNIQUEIDENTIFIER,
			@MaterialGuid   UNIQUEIDENTIFIER,
			@TicketType		INT, -- 0:Sale - 2:ReturnSale
			@SN			    NVARCHAR(500)	  )
-- Return -----------------------------------------------
RETURNS INT
---------------------------------------------------------
AS
BEGIN
	DECLARE @CheckInAlAmeen INT = 0
	DECLARE @CheckInPOSSD   INT = 0
	DECLARE @StationStore UNIQUEIDENTIFIER = CASE @TicketType WHEN 0 THEN ( SELECT BT.DefStoreGUID 
																			FROM POSSDStation000 S INNER JOIN bt000 BT ON S.SaleBillTypeGUID = BT.[GUID] 
																			WHERE S.[GUID] =  @POSGuid )

																	 ELSE ( SELECT BT.DefStoreGUID 
																			FROM POSSDStation000 S INNER JOIN bt000 BT ON S.SaleReturnBillTypeGUID = BT.[GUID] 
																			WHERE S.[GUID] =  @POSGuid ) END

	-------------- Check if available for sale
	IF(@TicketType = 0)
	BEGIN
		IF EXISTS( SELECT 
						SNC.sn
				   FROM 
						snc000 SNC
						INNER JOIN snt000 SNT ON SNC.[GUID] = SNT.ParentGUID 
				   WHERE 
					   SNC.MatGUID = @MaterialGuid
				   AND SNT.stGUID = @StationStore
				   AND (SNC.Qty > 0)
				   AND (SNC.sn = @SN))
		BEGIN
			SET @CheckInAlAmeen = 1
		END
	END


	-------------- Check if exist for return sale
	IF(@TicketType = 2)
	BEGIN
		IF NOT EXISTS( SELECT 
						SNC.sn
				   FROM 
						snc000 SNC
						INNER JOIN snt000 SNT ON SNC.[GUID] = SNT.ParentGUID 
				   WHERE 
					   SNC.MatGUID = @MaterialGuid
				   AND SNT.stGUID = @StationStore
				   AND (SNC.Qty > 0)
				   AND (SNC.sn = @SN))
		BEGIN
			SET @CheckInAlAmeen = 1
		END
	END


	-------------- Check if used in POSSD
	IF NOT EXISTS( SELECT 
					SN.SN
			   FROM 
					POSSDTicketItem000 TI  
					INNER JOIN POSSDTicketItemSerialNumbers000 SN ON TI.[GUID] = SN.TicketItemGUID
					INNER JOIN POSSDTicket000 T ON TI.TicketGUID = T.[GUID]
			   WHERE 
				   TI.MatGUID = @MaterialGuid
			   AND T.[State]  = 0
			   AND T.[Type]   = @TicketType
			   AND SN.SN = @SN )
	BEGIN
		SET @CheckInPOSSD = 1
	END


	-------------- Check if inserted from possd return sale
	IF(@TicketType = 0 AND @CheckInPOSSD = 1 AND @CheckInAlAmeen = 0)
	BEGIN
		IF EXISTS( SELECT 
						SN.SN
				   FROM 
						POSSDTicketItem000 TI  
						INNER JOIN POSSDTicketItemSerialNumbers000 SN ON TI.[GUID] = SN.TicketItemGUID
						INNER JOIN POSSDTicket000 T ON TI.TicketGUID = T.[GUID]
				   WHERE 
					   TI.MatGUID = @MaterialGuid
				   AND T.[State] = 0
				   AND T.[Type] = 2
				   AND SN.SN = @SN )
		BEGIN
			RETURN 1
		END
	END



	RETURN @CheckInAlAmeen & @CheckInPOSSD

END
#################################################################
#END
