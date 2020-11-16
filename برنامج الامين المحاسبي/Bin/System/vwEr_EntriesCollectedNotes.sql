#########################################################
CREATE VIEW vwER_EntriesCollectedNotes
AS
	SELECT
		[erGUID],
		[erEntryGUID],
		[erParentGUID] AS [erNoteGUID],
		[erParentType],
		[erParentNumber]
	FROM
		[vwEr]
	WHERE
		[erParentType] = 6

#########################################################
#END