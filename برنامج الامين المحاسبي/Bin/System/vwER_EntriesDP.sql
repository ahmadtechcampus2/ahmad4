#########################################################
CREATE VIEW vwER_EntriesDP
AS
	SELECT
		[erGUID],
		[erEntryGUID],
		[erParentGUID] as [erDPGUID],
		[erParentType],
		[erParentNumber]
	FROM
		[vwEr]
	WHERE
		[erParentType] = 8

#########################################################
#END