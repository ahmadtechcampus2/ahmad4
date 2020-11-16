#########################################################
CREATE VIEW vwExtended_BiGr
AS
	SELECT
		[bi].*,
		[gr].[grNumber],
		[gr].[grParent],
		[gr].[grCode],
		[gr].[grName],
		[gr].[grNotes],
		[gr].[grSecurity]
	FROM
		[vwExtended_bi] AS [bi] INNER JOIN [vwGr] AS [gr] ON [bi].[mtGroup] = [gr].[grGUID]

#########################################################
#END