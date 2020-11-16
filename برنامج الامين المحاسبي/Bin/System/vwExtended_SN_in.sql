############################################################################### 
CREATE VIEW vwExtended_SN_in
AS
	SELECT
		[bi].*,
		[sn].[SN] AS [snSN],
		[sn].[Item] AS [snItem], 
		[sn].[Notes] AS [snNotes],
		[sn].[outGuid] AS [snOutGuid]

	FROM
		[vwExtended_bi] AS [bi] INNER JOIN [sn000] AS [sn]
		ON [bi].[biGuid] = [sn].[inGuid]

###############################################################################
#END 