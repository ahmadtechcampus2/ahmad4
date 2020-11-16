#########################################################
CREATE FUNCTION fnGetReceivedChecks()
	RETURNS @Result TABLE(
		AccountGuid UNIQUEIDENTIFIER,
		Value FLOAT)
AS
BEGIN
	;WITH CollCh AS
	(
		SELECT
			chGUID,
			SUM(collectedValue) AS Collected
		FROM
			vwcolch
		GROUP BY
			chGUID
	)
	INSERT INTO @Result
	SELECT
		ch.chAccount,
		SUM(ch.chVal - ISNULL(col.Collected, 0)) AS Val
	FROM 
		vwCh ch
		INNER JOIN ch000 ch1 ON ch.chGUID = ch1.[GUID]
		INNER JOIN vwnt nt ON nt.ntGuid = ch.chType
		LEFT JOIN CollCh col ON col.chGUID =  ch.chGUID
	WHERE
		chDir = 1 -- „ﬁ»Ê÷…
		AND chState IN(0, 2, 4, 7, 10, 11)
		AND nt.ntbAutoEntry = 1
	GROUP BY
		ch.chAccount;

	RETURN;
END
#########################################################
CREATE FUNCTION fnCheque_GetCollectedValue(@ChGUID UNIQUEIDENTIFIER)
	RETURNS FLOAT
AS 
BEGIN
	RETURN 
		ISNULL((SELECT SUM(collectedValue) AS Collected FROM vwcolch WHERE chGUID = @ChGUID), 0)
END
#########################################################
CREATE FUNCTION fnCheque_GetValue(@AccountGuid UNIQUEIDENTIFIER)
	RETURNS FLOAT
AS
BEGIN
	RETURN 
		ISNULL((SELECT
			SUM( 
				(CASE chDir WHEN 1 THEN 1 ELSE -1 END) *
				(ch.chVal - dbo.fnCheque_GetCollectedValue(ch.chGUID))
			) AS Val
		FROM 
			vwCh ch
			-- INNER JOIN ch000 ch1 ON ch.chGUID = ch1.[GUID]
			INNER JOIN vwnt nt ON nt.ntGuid = ch.chType
		WHERE
			(
				(chDir = 1) AND (chState IN (0, 2, 4, 7, 10, 11)) 
				OR 
				(chDir = 2) AND (chState IN (0, 2, 14)) 
			)
			AND nt.ntbAutoEntry = 1
			AND ch.chAccount = @AccountGuid
		GROUP BY
			ch.chAccount), 0)
END
#########################################################
CREATE FUNCTION fnCheque_GetBudgetValue(@AccountGuid UNIQUEIDENTIFIER, @ConsiderChecksInBudget BIT)
	RETURNS @Result TABLE(Value FLOAT)
AS
BEGIN
	IF @ConsiderChecksInBudget = 0
		INSERT INTO @Result SELECT 0
	ELSE  
		INSERT INTO @Result SELECT dbo.fnCheque_GetValue(@AccountGuid)

	RETURN 
END
#########################################################
CREATE FUNCTION fnCheque_AccCust_GetValue_(@AccountGuid UNIQUEIDENTIFIER, @CustGuid UNIQUEIDENTIFIER)
	RETURNS FLOAT
AS
BEGIN
	RETURN 
		ISNULL((SELECT
			SUM( 
				(CASE chDir WHEN 1 THEN 1 ELSE -1 END) *
				(ch.chVal - dbo.fnCheque_GetCollectedValue(ch.chGUID))
			) AS Val
		FROM 
			vwCh ch
			INNER JOIN vwnt nt ON nt.ntGuid = ch.chType
		WHERE
			(
				(chDir = 1) AND (chState IN (0, 2, 4, 7, 10, 11)) 
				OR 
				(chDir = 2) AND (chState IN (0, 2, 14)) 
			)
			AND nt.ntbAutoEntry = 1
			AND ch.chAccount = @AccountGuid
			AND ch.chCustomerGUID = @CustGuid
		GROUP BY
			ch.chAccount, ch.chCustomerGUID), 0)
END
#########################################################
CREATE FUNCTION fnCheque_AccCust_GetBudgetValue(@AccountGuid UNIQUEIDENTIFIER,@CustGuid UNIQUEIDENTIFIER, @ConsiderChecksInBudget BIT)
	RETURNS @Result TABLE(Value FLOAT)
AS
BEGIN
	IF @ConsiderChecksInBudget = 0
		INSERT INTO @Result SELECT 0
	ELSE  
		INSERT INTO @Result SELECT dbo.fnCheque_AccCust_GetValue_(@AccountGuid, @CustGuid)

	RETURN 
END
#########################################################
#END 
