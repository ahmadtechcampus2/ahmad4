######################################################
CREATE FUNCTION fnExpensesAccounts()
Returns @ExpensesAccount TABLE
(
	Number INT, 
	GUID [UNIQUEIDENTIFIER],
	ParentGUID [UNIQUEIDENTIFIER],
	Name NVARCHAR(250),
	LatinName NVARCHAR(250),
	Code NVARCHAR(250)
)
AS 
	BEGIN 
 
		DECLARE @ExpensesAcc UNIQUEIDENTIFIER = dbo.fnOption_GetGUID('PFC_ExpensecloseAcc')

		IF(@ExpensesAcc = 0x0)
			RETURN

		INSERT INTO @ExpensesAccount
		SELECT 
			Number,
			GUID,
			ParentGUID,
			Name,
			LatinName,
			Code 
		FROM ac000 
		WHERE FinalGUID = @ExpensesAcc AND ParentGUID <> 0x0

		RETURN
 
	END
######################################################
#END