#####################################################
CREATE PROCEDURE prcAccountBal
	@StartDate 	DATETIME,
	@EndDate 		DATETIME,
	@AccSec		INT,
	@EntrySec		INT,
	@CurrencyPtr	INT,
	@CurrencyVal	FLOAT,
	@CostPtr		INT,
	@Final			INT
AS

	CREATE TABLE #t_Result
	(
		Account INT,
		AccName NVARCHAR(256) COLLATE ARABIC_CI_AI,
		Code NVARCHAR(256) COLLATE ARABIC_CI_AI,
		Parent INT,
		Final INT,
		acDebitOrCredit INT,
		acCurPtr INT,
		acCurVal FLOAT,
		Level INT,
		Debit FLOAT,
		Credit FLOAT,
		CurCardDebit FLOAT,
		CurCardCredit F
	)
	DECLARE @Level INT
	DECLARE @CurPtr INT

	SET @CurPtr = @CurrencyPtr
	SET @Level = 0
	-- put detailed accounts:

	--DECLARE @SqlString NVARCHAR(8000)

	CREATE TABLE #CostTbl( CostPtr INTEGER, Security INT)
	INSERT INTO #CostTbl EXEC prcGetCostsList @CostPtr

	INSERT INTO #t_Result
		SELECT
			enAccount,
			acCode+ '-' +acName AS enName,
			acCode,
			acParent,
			acFinal,
			acDebitOrCredit,
			acCurrencyPtr,
			acCurrencyVal,
			@Level,
			CASE enCurrencyPtr WHEN @CurPtr THEN SUM(EnDebit / EnCurrencyVal) ELSE SUM(EnDebit / @CurrencyVal) END AS Debit,
			CASE enCurrencyPtr WHEN @CurPtr THEN SUM(EnCredit / EnCurrencyVal) ELSE SUM(EnCredit / @CurrencyVal ) END AS Credit,
			CASE acCurrencyPtr WHEN @CurPtr THEN 0 ELSE CASE enCurrencyPtr WHEN acCurrencyPtr THEN SUM(EnDebit / EnCurrencyVal) ELSE 0 END END AS CurCardDebit,
			CASE acCurrencyPtr WHEN @CurPtr THEN 0 ELSE CASE enCurrencyPtr WHEN acCurrencyPtr THEN SUM(EnCredit / EnCurrencyVal) ELSE 0 END END AS CurCardCredit
		FROM
			vwExtended_En
		WHERE
			ceIsPosted <> 0
			AND EnDate BETWEEN @StartDate AND @EndDate
			AND ceSecurity <= @EntrySec
			AND acSecurity <= @AccSec
			AND acFinal = @Final
			AND ( (@CostPtr = 0) OR (enCostPoint IN (SELECT CostPtr FROM #CostTbl)))
		GROUP BY
			enAccount,
			acName,
			acCode,
			acParent,
			acFinal,
			acDebitOrCredit,
			acCurrencyPtr,
			acCurrencyVal,
			enCurrencyPtr

		-- check Continuing:
		IF @@ROWCOUNT = 0 RETURN

		-- start looping:
		WHILE 1 = 1
		BEGIN
			-- Inc level
			SET @Level = @Level + 1
		       	-- insert heigher generation:
			INSERT INTO #t_Result
				SELECT
					acNumber,
					(acCode+' - '+acName) AS enName,
					acCode,
					acParent,
					acFinal,
					acDebitOrCredit,
					acCurrencyPtr,
					acCurrencyVal,
					@Level,
					0,
					0,
					0,
					0
				FROM
					vwAc
				WHERE
					acNumber IN (SELECT Parent FROM #t_Result AS t WHERE t.Level = @Level - 1)
					AND acSecurity <= @AccSec

			IF @@ROWCOUNT = 0 BREAK
			-- update the Sums of the fresh generation:       
			UPDATE #t_Result SET
				Debit = (SELECT Sum(son.Debit) FROM #t_Result AS Son WHERE Son.Parent = Father.Account),
				Credit = (SELECT Sum(son.Credit) FROM #t_Result AS Son WHERE Son.Parent = Father.Account),
				CurCardDebit = (SELECT Sum(son.CurCardDebit) FROM #t_Result AS Son WHERE Son.Parent = Father.Account),
				CurCardCredit = (SELECT Sum(son.CurCardCredit) FROM #t_Result AS Son WHERE Son.Parent = Father.Account)
			FROM
				#t_Result AS Father
			WHERE
				Level = @Level
			DELETE FROM #t_Result WHERE
				Level < @Level AND Account IN (SELECT Account FROM #t_Result AS t WHERE t.Level = @Level)
		END

		SELECT * FROM #t_Result
		ORDER BY Code

		DROP TABLE #t_Result
		Drop TABLE #CostTbl

	/*   
	exec prcAccountBal    
	'1/1/2002',--	@StartDate DATETIME,    
	'12/22/2002',--	@EndDate DATETIME,       
	5,--	@AccSec	INT,       
	5,--	@EntrySec	INT,       
	1,--	@CurrencyPtr	INT,       
	1,--	@CurrencyVal	FLOAT,      
	0,--	@CostPoint	INT,     
	1--	@Final	INT      
	*/   

################################
#END