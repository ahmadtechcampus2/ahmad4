#########################################################
CREATE VIEW vwER_EntriesPays_PYType
AS
	SELECT
		[erGUID],
		[erEntryGUID],
		[erParentGUID] AS [erPayGUID],
		[erParentType],
		[py].[TypeGUID]
	FROM
		[vwER_EntriesPays] AS [er] INNER JOIN [PY000] AS [py] ON [er].[erPayGUID] = [py].[GUID]

/*
select * from er000 vwER_EntriesPays_PYTYPE
*/
#########################################################
#END