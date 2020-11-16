#########################################################
CREATE VIEW vwER_EntriesCollectedNotes_Types
AS
	SELECT
		[erGUID],
		[erEntryGUID],
		[erNoteGUID],
		[erParentType],
		[ch].[TypeGUID]
	FROM
		[vwER_EntriesCollectedNotes] AS [er] INNER JOIN [ch000] AS [ch] ON [er].[erNoteGUID] = [ch].[GUID]
	WHERE
		[ch].[State] = 1
/*
select * from ce000 as ce inner join en000 as en on ce.guid = en.parentguid where ce.number = 42 
select * from vwER_EntriesCollectedNotes_Types
select * from vwER
select * from ch000
*/
#########################################################
#END