#########################################################
CREATE VIEW vwER_EntriesNotes
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
		[erParentType] = 5

#########################################################
#END