###############################################################################
CREATE PROCEDURE prcUpdateOptionRelatedToReservationSystem
AS
    SET NOCOUNT ON

	IF( (SELECT dbo.fnOption_GetInt('AmnCfg_EnableOrderReservationSystem' , 0)) = 0)
		RETURN

	DECLARE @IsNegativeOutputBasedOnStore INT = dbo.fnOption_GetInt('AmnCfg_NegativeOutputAfterReservationBasedOnStore' , 0)
	DECLARE @OpValue NVARCHAR (2000) = (SELECT CASE WHEN @IsNegativeOutputBasedOnStore = 1 THEN '1' ELSE '0' END)
	EXEC prcOptionAdd 'AmnCfg_MatQtyByStore' , @OpValue
	
	
	DECLARE @IsPreventNegativeOutput INT = dbo.fnOption_GetInt('AmnCfg_PreventNegativeOutputAfterReservation' , 0)
	IF (@IsPreventNegativeOutput = 1) 
	BEGIN
		UPDATE Distributor000 SET OutNegative = 1
	END
###############################################################################
#END