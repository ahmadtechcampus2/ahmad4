################################################################################
CREATE FUNCTION fnPOSSD_Station_IsBillTypeUsed (@BillType UNIQUEIDENTIFIER, @IsStationHasShifts INT)
RETURNS @POSSDStations TABLE( [GUID]	UNIQUEIDENTIFIER )
AS 
BEGIN

	IF(@IsStationHasShifts = 0)
	BEGIN
		INSERT INTO @POSSDStations
		SELECT C.[GUID]
		FROM POSSDStation000 C
		WHERE C.SaleBillTypeGUID = @BillType OR C.SaleReturnBillTypeGUID = @BillType
	END

	ELSE
	BEGIN
		INSERT INTO @POSSDStations
		SELECT C.[GUID]
		FROM POSSDStation000 C
			 INNER JOIN POSSDShift000 S ON C.[Guid] = S.StationGUID
		WHERE C.SaleBillTypeGUID = @BillType OR C.SaleReturnBillTypeGUID = @BillType
	END

	RETURN
END
#################################################################
#END
