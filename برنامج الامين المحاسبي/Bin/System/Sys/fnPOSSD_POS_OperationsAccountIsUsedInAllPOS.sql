################################################################################
CREATE FUNCTION fnPOSSDOperationsAccountIsUsedInAllPOS
-- Param ----------------------------------------------------------
	  ( @CurrentPOS					 UNIQUEIDENTIFIER,
	    @CurrentPOSShiftControlAcc   UNIQUEIDENTIFIER,
		@CurrentPOSContinuesCashAcc  UNIQUEIDENTIFIER,

		@CentralAcc     UNIQUEIDENTIFIER,
	    @DebitAcc       UNIQUEIDENTIFIER,
	    @CreditAcc      UNIQUEIDENTIFIER,
	    @ExpenseAcc     UNIQUEIDENTIFIER,
	    @IncomeAcc      UNIQUEIDENTIFIER  )
-- Return ----------------------------------------------------------
RETURNS @Result TABLE(AccName NVARCHAR(50), AccGuid UNIQUEIDENTIFIER)
--------------------------------------------------------------------
AS 
BEGIN

	DECLARE @TempPOSCard TABLE (ShiftControlAcc   UNIQUEIDENTIFIER, ContinuesCashAcc  UNIQUEIDENTIFIER)
	INSERT INTO @TempPOSCard SELECT ShiftControl, ContinuesCash FROM POSCard000 WHERE [Guid] <> @CurrentPOS
	INSERT INTO @TempPOSCard SELECT @CurrentPOSShiftControlAcc, @CurrentPOSContinuesCashAcc

	INSERT INTO @Result
	SELECT TOP 1 fn.* 
	FROM @TempPOSCard POSCard 
	CROSS APPLY dbo.[fnPOSSDOperationsAccountIsUsedInSinglePOS](POSCard.ShiftControlAcc, 
																POSCard.ContinuesCashAcc, 
																@CentralAcc, 
																@DebitAcc, 
																@CreditAcc, 
																@ExpenseAcc, 
																@IncomeAcc) fn


RETURN
END
#################################################################
#END
