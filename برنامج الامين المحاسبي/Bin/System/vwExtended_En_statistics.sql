#########################################################
CREATE VIEW vwExtended_en_statistics
AS
	SELECT
		*,
		(SELECT COUNT(*) FROM [vwEn] WHERE [enParent] = [ce].[ceGUID] AND [vwEn].[enDebit] <> 0) AS [enCountOfDebitors],
		(SELECT COUNT(*) FROM [vwEn] WHERE [enParent] = [ce].[ceGUID] AND [vwEn].[enCredit] <> 0) AS [enCountOfCreditors]
	FROM
		[vwExtended_en] AS [ce]

#########################################################
#END