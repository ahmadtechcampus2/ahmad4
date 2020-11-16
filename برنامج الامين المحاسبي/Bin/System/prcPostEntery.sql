###########################################################################
CREATE PROCEDURE prcPostEntery
	@GUID UNIQUEIDENTIFIER,
	@QF INT
AS
/*
This procedure:
	- updates the ac000 balances.
	- is called from ce000 triggers.
*/ 
	SET NOCOUNT ON

	DECLARE @t TABLE (Account UNIQUEIDENTIFIER, Debit FLOAT, Credit FLOAT)

	-- using a temporary table will speed things up:
	INSERT INTO @t (Account, Debit, Credit)
		SELECT AccountGUID, @QF * Sum(Debit), @QF * Sum(Credit)
		FROM en000
		WHERE ParentGUID = @GUID
		GROUP BY AccountGUID

	-- notify concerned accounts of new values from the temporary table
	UPDATE ac000 SET
		Debit = ac000.Debit + t.Debit,
		Credit = ac000.Credit + t.Credit
	FROM
		ac000 INNER JOIN @t AS t
		ON ac000.GUID = t.Account

###########################################################################
#END