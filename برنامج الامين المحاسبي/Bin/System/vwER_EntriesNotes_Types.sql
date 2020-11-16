#########################################################
CREATE VIEW vwER_EntriesNotes_Types
AS
	SELECT
		[erGUID],
		[erEntryGUID],
		[erNoteGUID],
		[erParentType],
		[ch].[TypeGUID]
	FROM
		[vwER_EntriesNotes] AS [er] INNER JOIN [ch000] AS [ch] ON [er].[erNoteGUID] = [ch].[GUID]
	WHERE
	[ch].[State] = 0
/*
select * from vwER_EntriesNotes_Types
select * from ch000
select * from er000
*/
#########################################################
#END