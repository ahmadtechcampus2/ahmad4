#############################################
CREATE PROCEDURE prcPOSSD_Station_CheckDriverAccounts
-- Param -------------------------------   
	@StationGUID		UNIQUEIDENTIFIER,
	@DriverGUID			UNIQUEIDENTIFIER
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	DECLARE @ShiftControlAccGUID UNIQUEIDENTIFIER = ( SELECT ShiftControlGUID FROM POSSDStation000 WHERE [GUID] = @StationGUID )
	DECLARE @Result TABLE ( MatchingWihtExtraAccount BIT, MatchingWihtMinusAccount BIT, MatchingWihtReceiveAccount BIT )
	INSERT INTO @Result VALUES (0, 0, 0)
	

	IF EXISTS( SELECT * 
			   FROM dbo.fnGetAccountsList(@ShiftControlAccGUID, 0) AC 
			   INNER JOIN POSSDDriver000 D ON AC.[GUID] = D.ExtraAccountGUID
			   WHERE D.[GUID] = @DriverGUID )

	BEGIN
		UPDATE @Result SET MatchingWihtExtraAccount = 1
	END


	IF EXISTS( SELECT * 
			   FROM dbo.fnGetAccountsList(@ShiftControlAccGUID, 0) AC 
			   INNER JOIN POSSDDriver000 D ON AC.[GUID] = D.MinusAccountGUID
			   WHERE D.[GUID] = @DriverGUID )

	BEGIN
		UPDATE @Result SET MatchingWihtMinusAccount = 1
	END


	IF EXISTS( SELECT * 
			   FROM dbo.fnGetAccountsList(@ShiftControlAccGUID, 0) AC 
			   INNER JOIN POSSDDriver000 D ON AC.[GUID] = D.ReceiveAccountGUID
			   WHERE D.[GUID] = @DriverGUID )

	BEGIN
		UPDATE @Result SET MatchingWihtReceiveAccount = 1
	END

	

	SELECT * FROM @Result
##############################################
#END
