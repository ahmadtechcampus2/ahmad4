#########################################################
CREATE VIEW vwER_EntriesPays
AS
	SELECT
		[erGUID],
		[erEntryGUID],
		[erParentGUID] AS [erPayGUID],
		[erParentType],
		[erParentGUID],
		[erParentNumber]
	FROM
		[vwEr]
	WHERE
		[erParentType] = 4

/*
select * from vwEr
*/
#########################################################
#END