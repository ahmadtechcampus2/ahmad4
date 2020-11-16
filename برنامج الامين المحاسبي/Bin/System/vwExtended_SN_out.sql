############################################################################### 
CREATE VIEW vwExtended_SN_out
AS
	SELECT
		[bi].*,
		[sn].[SN] AS [snSN],
		[sn].[Item] AS [snItem], 
		[sn].[Notes] AS [snNotes],
		[sn].[inGuid] AS [snInGuid]

	FROM
		[vwExtended_bi] AS [bi] INNER JOIN [sn000] AS [sn]
		ON [bi].[biGuid] = [sn].[outGuid]

###############################################################################
#END 