#################################################################
CREATE FUNCTION fnPOSSD_Shift_CanUncloseShift
(
	 @ShiftGuid		          UNIQUEIDENTIFIER
)
RETURNS INT
AS
BEGIN
	DECLARE @Result								 INT = 0
	DECLARE @SaleBillTypeGeneratedFromCloseShift UNIQUEIDENTIFIER
	DECLARE @POSCardSaleBillType				 UNIQUEIDENTIFIER
	SELECT @SaleBillTypeGeneratedFromCloseShift = BU.TypeGUID
	FROM BillRel000 BR  
	INNER JOIN bu000 BU ON BU.[GUID] = BR.BillGUID
	WHERE BR.ParentGUID = @ShiftGuid
	SELECT @POSCardSaleBillType = C.SaleBillTypeGUID 
	FROM POSSDShift000 S 
	INNER JOIN POSSDStation000 C ON S.[StationGUID] = C.[GUID]
	WHERE S.[GUID] = @ShiftGuid
	
	IF(@SaleBillTypeGeneratedFromCloseShift <> @POSCardSaleBillType)
	BEGIN
		SET @Result = 1
	END

	DECLARE @stationGuid UNIQUEIDENTIFIER = (SELECT StationGUID FROM POSSDShift000 WHERE GUID = @ShiftGuid)
	DECLARE @closeDate DATETIME = (SELECT CloseDate From POSSDShift000 WHERE GUID = @ShiftGuid)
	DECLARE @MaxCloseDate DATETIME = (SELECT MAX(CloseDate) From POSSDShift000 WHERE StationGUID = @stationGuid)
	
	IF (@closeDate <> @MaxCloseDate)
	BEGIN
		SET @Result = 2
	END

	RETURN @Result
END
#################################################################
#END 