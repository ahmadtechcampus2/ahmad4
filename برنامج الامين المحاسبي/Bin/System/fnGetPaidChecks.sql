#########################################################
CREATE FUNCTION fnGetPaidChecks()
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
		chDir = 2 -- „œ›Ê⁄…
		AND chState IN(0, 2, 14)
		AND nt.ntbAutoEntry = 1
	GROUP BY
		ch.chAccount;

	RETURN;
END
#########################################################
#END 