#########################################################
CREATE VIEW vwMs
AS
	SELECT
		[StoreGUID] AS [msStorePtr],
		[MatGUID] AS [msMatPtr],
		[Qty] AS [msQty],
		[Book] AS [msBook]
	FROM
		[ms000]

#########################################################
CREATE VIEW vwMainTypesGroup
as
	SELECT * FROM TypesGroup000
	WHERE Type = 0
#########################################################
CREATE VIEW vwSubTypesGroup
as
	SELECT * FROM TypesGroup000
	WHERE Type = 1
#########################################################
#END