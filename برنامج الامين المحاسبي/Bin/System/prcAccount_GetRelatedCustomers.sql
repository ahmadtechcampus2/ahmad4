#########################################################
CREATE PROC prcAccount_GetRelatedCustomers
	@AccGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON 

	IF NOT EXISTS (SELECT * FROM vwCu WHERE cuAccount = @AccGuid)
		RETURN

	DECLARE @Result TABLE(
		Number INT, 
		Guid UNIQUEIDENTIFIER, 
		Name NVARCHAR(500), 
		Debit FLOAT, 
		Credit FLOAT,
		LastCheckDateBal FLOAT, 
		LastCheckDate DATETIME, 
		MaxDebit FLOAT, 
		Warn FLOAT, 
		ConsiderChecksInBudget INT);

	DECLARE	@lang INT;
	DECLARE	@AcCurrencyVal FLOAT;
	 
	SET @lang = [dbo].[fnConnections_GetLanguage]()
	SELECT @AcCurrencyVal= acCurrencyVal FROM vwAc WHERE acGUID = @AccGuid
	if(@AcCurrencyVal = 0)
		SET @AcCurrencyVal = 1
	INSERT INTO @Result
	SELECT 
		1,
		cuGUID,
		CASE @lang WHEN 0 THEN cuCustomerName ELSE CASE cuLatinName WHEN '' THEN cuCustomerName ELSE cuLatinName END END,
		0, 
		0,
		ISNULL(fn.LastCheckDateBal, 0) / ac.CurrencyVal LastCheckDateBal,
		ISNULL(fn.CheckedToDate, '19800101'),
		cuMaxDebit / @AcCurrencyVal ,
		cuWarn,
		cuConsiderChecksInBudget
	FROM vwCu cu 
	INNER JOIN ac000 ac ON ac.GUID = cu.cuAccount
	OUTER APPLY dbo.fnAccLastCheckBalance ( cuAccount, cuGUID )  fn
	WHERE
		cuAccount = @AccGuid 

	UPDATE @Result 
	SET 
		Debit = F.D / @AcCurrencyVal,
		Credit = F.C / @AcCurrencyVal
	FROM 
		@Result R
		INNER JOIN (
			SELECT rs.GUID, SUM(en.Debit) AS D, SUM(en.Credit) AS C 
			FROM 
				@Result rs
				INNER JOIN en000 en ON rs.GUID = en.CustomerGUID AND en.AccountGUID = @AccGuid
				INNER JOIN ce000 ce on ce.GUID = en.ParentGUID
			WHERE 
				en.AccountGUID = @AccGuid AND ce.IsPosted = 1
			GROUP BY 
				rs.GUID) F ON R.GUID = F.GUID 
	
	IF EXISTS (SELECT * FROM en000 WHERE AccountGUID = @AccGuid AND CustomerGUID = 0x0)
	BEGIN 
		INSERT INTO @Result
		SELECT 0, 0x0, '', 
		   SUM(en.Debit) / @AcCurrencyVal,
		   SUM(en.Credit) / @AcCurrencyVal,
		   ISNULL(fn.LastCheckDateBal,0) / en.CurrencyVal LastCheckDateBal,
		   ISNULL(fn.CheckedToDate,'1/1/1980'),
		   0,
		   0,
		   0
		FROM 
			en000 en
			INNER JOIN ce000 ce on ce.GUID = en.ParentGUID,
			vwCu cu OUTER APPLY dbo.fnAccLastCheckBalance( cuAccount,Default)  fn
		WHERE 
			en.AccountGUID = @AccGuid
			AND ISNULL(en.CustomerGUID, 0x0) = 0x0
			AND ce.IsPosted = 1
		GROUP BY LastCheckDateBal, CheckedToDate, en.CurrencyVal
	END
	SELECT * FROM @Result ORDER BY Number, Name
#########################################################
CREATE FUNCTION fnAccLastCheckBalance (
	@Acc1 UNIQUEIDENTIFIER = 0x0,
	@Cust1 UNIQUEIDENTIFIER = 0x0
	)
RETURNS TABLE
AS RETURN
(
	SELECT TOP 1 CheckedToDate,
	   ISNULL(Chk.Debit,0) - ISNULL(Chk.Credit,0) LastCheckDateBal  
	FROM CheckAcc000 Chk
	WHERE
		ISNULL(AccGUID, 0x0) = CASE WHEN ISNULL(@Acc1, 0x0) <> 0x0 THEN ISNULL(@Acc1, 0x0) ELSE ISNULL(AccGUID, 0x0)END 
		AND ISNULL(CustGUID, 0x0) = CASE WHEN ISNULL(@Cust1, 0x0)  <> 0x0 THEN ISNULL(@Cust1, 0x0) ELSE ISNULL(CustGUID, 0x0)END 
	ORDER BY
		CheckedToDate DESC
)
#########################################################
#END