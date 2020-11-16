#########################################################
CREATE FUNCTION fnHasTransactionOutRange(@StartDate DATE = NULL, @EndDate DATE = NULL)
	RETURNS INT
AS 
BEGIN 
	IF @StartDate IS NOT NULL
	BEGIN
		IF EXISTS(SELECT * FROM bu000 bu WHERE ([Date] < @StartDate)
			AND NOT EXISTS(SELECT POGUID FROM ori000 WHERE POGUID = bu.GUID AND bIsRecycled = 1))
			RETURN 1
		IF EXISTS(SELECT * FROM bu000 bu WHERE ([Date] < @StartDate)
			AND NOT EXISTS(SELECT * FROM OrAddInfo000 WHERE ParentGUID = bu.GUID))
			RETURN 1
		IF EXISTS(SELECT * FROM ce000 WHERE [Date] < @StartDate )
			RETURN 1
		IF EXISTS(SELECT * FROM py000 WHERE [Date] < @StartDate )
			RETURN 1
		IF EXISTS(SELECT * FROM ch000 WHERE TransferCheck = 0 AND [Date] < @StartDate)
			RETURN 1
	END
	IF @EndDate IS NOT NULL
	BEGIN
		IF EXISTS(SELECT * FROM bu000 bu WHERE (CAST([Date] AS DATE) > @EndDate)
			AND NOT EXISTS(SELECT POGUID FROM ori000 WHERE POGUID = bu.GUID AND bIsRecycled = 1 ))
			RETURN 2
		IF EXISTS(SELECT * FROM bu000 bu WHERE (CAST([Date] AS DATE) > @EndDate)
			AND NOT EXISTS(SELECT * FROM OrAddInfo000 WHERE ParentGUID = bu.GUID))
			RETURN 2
		IF EXISTS(SELECT * FROM ce000 WHERE CAST([Date] AS DATE) > @EndDate)
			RETURN 2
		IF EXISTS(SELECT * FROM py000 WHERE CAST([Date] AS DATE) > @EndDate )
			RETURN 2
		IF EXISTS(SELECT * FROM ch000 WHERE TransferCheck = 0 AND CAST([Date] AS DATE) > @EndDate)
			RETURN 2
	END

	RETURN 0
END 	
#########################################################
#END
