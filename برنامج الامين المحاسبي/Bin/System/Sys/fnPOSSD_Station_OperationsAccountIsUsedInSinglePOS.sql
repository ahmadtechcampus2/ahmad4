################################################################################
CREATE FUNCTION fnPOSSD_Station_OperationsAccountIsUsedInSinglePOS
-- Param ----------------------------------------------------------
	  ( @ShiftControlAccToBeVerified   UNIQUEIDENTIFIER,
		@ContinuesCashAccToBeVerified  UNIQUEIDENTIFIER,

		@CentralAccOfTheCurrentPOS     UNIQUEIDENTIFIER,
	    @DebitAccOfTheCurrentPOS       UNIQUEIDENTIFIER,
	    @CreditAccOfTheCurrentPOS      UNIQUEIDENTIFIER,
	    @ExpenseAccOfTheCurrentPOS     UNIQUEIDENTIFIER,
	    @IncomeAccOfTheCurrentPOS      UNIQUEIDENTIFIER  )
-- Return ----------------------------------------------------------
RETURNS @Result TABLE(AccName NVARCHAR(50), AccGuid UNIQUEIDENTIFIER)
--------------------------------------------------------------------
AS 
BEGIN

	DECLARE @AccountTemp TABLE(OperationsAcc UNIQUEIDENTIFIER, AccGuid UNIQUEIDENTIFIER)

	IF(@CentralAccOfTheCurrentPOS <> 0x0) INSERT INTO @AccountTemp SELECT @CentralAccOfTheCurrentPOS, fn.[GUID] FROM [dbo].[fnGetAccountsList](@CentralAccOfTheCurrentPOS, 1) fn
	IF(@DebitAccOfTheCurrentPOS   <> 0x0) INSERT INTO @AccountTemp SELECT @DebitAccOfTheCurrentPOS,   fn.[GUID] FROM [dbo].[fnGetAccountsList](@DebitAccOfTheCurrentPOS,   1) fn
	IF(@CreditAccOfTheCurrentPOS  <> 0x0) INSERT INTO @AccountTemp SELECT @CreditAccOfTheCurrentPOS,  fn.[GUID] FROM [dbo].[fnGetAccountsList](@CreditAccOfTheCurrentPOS,  1) fn
	IF(@ExpenseAccOfTheCurrentPOS <> 0x0) INSERT INTO @AccountTemp SELECT @ExpenseAccOfTheCurrentPOS, fn.[GUID] FROM [dbo].[fnGetAccountsList](@ExpenseAccOfTheCurrentPOS, 1) fn
	IF(@IncomeAccOfTheCurrentPOS  <> 0x0) INSERT INTO @AccountTemp SELECT @IncomeAccOfTheCurrentPOS,  fn.[GUID] FROM [dbo].[fnGetAccountsList](@IncomeAccOfTheCurrentPOS,  1) fn

	IF EXISTS(SELECT * FROM @AccountTemp WHERE AccGuid = @ShiftControlAccToBeVerified)
	BEGIN
		INSERT INTO @Result SELECT '"' + ac.Code +' - '+ ac.Name + '"', at.OperationsAcc from ac000 ac INNER JOIN @AccountTemp at ON ac.[GUID] = at.OperationsAcc WHERE at.AccGuid = @ShiftControlAccToBeVerified
	END

	IF EXISTS(SELECT * FROM @AccountTemp WHERE AccGuid = @ContinuesCashAccToBeVerified)
	BEGIN
		INSERT INTO @Result SELECT '"' + ac.Code +' - '+ ac.Name + '"', at.OperationsAcc from ac000 ac INNER JOIN @AccountTemp at ON ac.[GUID] = at.OperationsAcc WHERE at.AccGuid = @ContinuesCashAccToBeVerified
	END

RETURN
END
#################################################################
#END
