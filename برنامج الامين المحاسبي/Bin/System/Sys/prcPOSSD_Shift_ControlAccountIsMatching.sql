#################################################################
CREATE PROCEDURE prcPOSSD_Shift_ControlAccountIsMatching
	@ShiftGuid UNIQUEIDENTIFIER,
	@AccountType INT, -- 1: Shift Countrol Account, 2: Float Cash Account
	@Result BIT   OUT
AS 
BEGIN

	SET NOCOUNT ON

	SET @Result = 1

	DECLARE @temp TABLE
	(
		Balance FLOAT,
		Debit FLOAT,
		Credit FLOAT,
		CurrValue FLOAT
	)
	 
	DECLARE @currencyGuid UNIQUEIDENTIFIER, @accountBalance FLOAT
	DECLARE  @pricePrec INT = CAST(dbo.fnOption_GetValue('AmnCfg_PricePrec', 0) AS INT)

	SELECT @currencyGuid =  [Value] FROM [dbo].[OP000] WHERE [Name] = 'AmnCfg_DefaultCurrency'

	INSERT INTO @temp
    EXEC prcPOSSD_Shift_GetAccountBalanceDuringShift @ShiftGuid, @AccountType, @currencyGuid

	SELECT @accountBalance = ISNULL(ROUND(ABS(Debit - Credit), @pricePrec) ,0) FROM @temp
	
    IF(@accountBalance <> 0)
	   SET @Result = 0
END
#################################################################
CREATE PROCEDURE prcPOSSD_Shift_GetAccountBalanceDuringShift
	@ShiftGuid		UNIQUEIDENTIFIER,
	@AccountType	INT, -- 1: Shift Countrol Account, 2: Float Cash Account
	@CurGuid		UNIQUEIDENTIFIER = NULL
AS
SET NOCOUNT ON

	DECLARE @AccountGuid	   UNIQUEIDENTIFIER
	DECLARE @RelatedShiftEntry TABLE (ParentGuid UNIQUEIDENTIFIER)

	SELECT @AccountGuid = CASE @AccountType WHEN 1 THEN S.ShiftControlGUID ELSE S.ContinuesCashGUID END
	FROM POSSDShift000 SH 
	INNER JOIN POSSDStation000 S ON SH.StationGUID = S.[GUID]
	WHERE SH.[GUID] = @ShiftGuid

	INSERT INTO @RelatedShiftEntry
	SELECT BillGUID 
	FROM BillRel000 
	WHERE ParentGUID = @ShiftGuid

	INSERT INTO @RelatedShiftEntry
	SELECT @ShiftGuid

	IF ISNULL(@CurGuid, 0x0) = 0x0
		SET @CurGuid = (SELECT [CurrencyGuid] FROM [ac000] WHERE [guid] = @AccountGuid)



	SELECT 
		SUM( ISNULL( EN.fixedEnDebit, 0) - ISNULL( EN.fixedEnCredit, 0) ) AS Balance,
		SUM( ISNULL( EN.fixedEnDebit, 0)) AS Debit,
		SUM( ISNULL( EN.fixedEnCredit, 0)) AS Credit,
		[dbo].fnGetCurVal (@CurGuid, GETDATE()) AS CurrencyVal
	FROM 
		[dbo].[fnCeEn_Fixed](@CurGuid) EN
		INNER JOIN [dbo].[fnGetAccountsList](@AccountGuid, DEFAULT) AC ON EN.enAccount = AC.[GUID]
		INNER JOIN er000 ER ON ER.EntryGUID = EN.ceGUID
		INNER JOIN @RelatedShiftEntry RSE ON RSE.ParentGuid = ER.ParentGUID
	WHERE 
		[en].[ceIsPosted] = 1
#################################################################
#END 