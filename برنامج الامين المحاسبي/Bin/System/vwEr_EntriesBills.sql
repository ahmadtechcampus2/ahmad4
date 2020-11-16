#########################################################
CREATE VIEW vwER_EntriesBills
AS
	SELECT
		[erGUID],
		[erEntryGUID],
		[erParentGUID] as [erBillGUID],
		[erParentType],
		[erParentNumber]
	FROM
		[vwEr]
	WHERE
		[erParentType] = 2

#########################################################
#END