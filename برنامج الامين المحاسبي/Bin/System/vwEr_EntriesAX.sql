#########################################################
CREATE VIEW vwER_EntriesAX
AS
	SELECT
		[erGUID],
		[erEntryGUID],
		[erParentGUID] as [erAXGUID],
		[erParentType],	
		[erParentNumber]
	FROM
		[vwEr]
	WHERE
		[erParentType] = 7

#########################################################
#END