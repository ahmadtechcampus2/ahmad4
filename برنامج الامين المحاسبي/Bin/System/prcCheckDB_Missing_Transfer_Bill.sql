########################################################################################
CREATE PROC prcCheckDB_Missing_Transfer_Bill
	@Correct INT = 0
	AS
	INSERT INTO [ErrorLog]([Type], [g1])
	SELECT 0x0517,OutBillGuid 
	FROM TS000 AS ts WHERE InBillGuid Not In (Select [bu].[GUID] FROM [bu000] AS [bu] )
	UNION 
	SELECT 0x0517,InBillGuid 
	FROM TS000 AS ts WHERE OutBillGuid Not In (Select [bu].[GUID] FROM [bu000] AS [bu] )

	UPDATE er Set c1 = buFormatedNumber
	FROM vwbubi as vw INNER JOIN ErrorLog as er on er.g1 = vw.buGuid 
	WHERE er.type =  0x0517	

	IF @Correct <> 0
	BEGIN 
		DELETE ts 
		FROM ts000 AS ts INNER JOIN ErrorLog AS er 
		ON er.g1 = ts.InBillGuid 
		WHERE er.type =  0x0517

		DELETE ts 
		FROM ts000 AS ts INNER JOIN ErrorLog AS er 
		ON er.g1 = ts.outBillGuid
		WHERE er.type =  0x0517

		UPDATE bu SET isposted = 0 
		FROM bu000 AS bu INNER JOIN ErrorLog AS er on er.g1 = bu.guid 
		WHERE er.type =  0x0517

		DELETE bu 
		FROM bu000 AS bu INNER JOIN ErrorLog AS er on er.g1 = bu.guid 
		WHERE er.type =  0x0517
	END 
########################################################################################


