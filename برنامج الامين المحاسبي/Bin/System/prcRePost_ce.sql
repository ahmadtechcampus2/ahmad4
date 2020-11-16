################################################################################
CREATE PROC prcRePost_ce
AS
/* 
This method: 
	- is responsible for updating all ac balances an NSons depending on posted entries. 
	- is called usually during maintenance stages. 
	- resets balances to 0 after disabling ac triggers. thus, resetting parents.
	- updates debit, credit and NSons from en, wich will recurslively go to all parents. 
*/ 
	SET NOCOUNT ON 

	BEGIN TRAN 

	DECLARE @t TABLE (GUID UNIQUEIDENTIFIER, SumDebit FLOAT, SumCredit FLOAT)

	INSERT INTO @t SELECT enAccount, SUM(enDebit), SUM(enCredit) FROM vwCeEn WHERE ceIsPosted <> 0 GROUP BY enAccount

	EXEC prcDisableTriggers 'ac000'
	UPDATE ac000 SET 
		Debit = 0, 
		Credit = 0,
		NSons = dbo.fnGetAccountNSons(GUID)

	ALTER TABLE ac000 ENABLE TRIGGER ALL 

	UPDATE ac000 SET 
			Debit = ISNULL(SumDebit, 0),
			Credit = ISNULL(SumCredit, 0)
	FROM ac000 AS ac INNER JOIN @t AS t ON ac.GUID = t.GUID

	COMMIT TRAN 

################################################################################
#END
