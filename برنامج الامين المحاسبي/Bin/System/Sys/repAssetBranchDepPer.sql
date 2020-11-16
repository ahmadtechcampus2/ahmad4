##########################################################################
CREATE PROC repAssetBranchDepPer @BranchGuid UNIQUEIDENTIFIER, @branchMask BIGINT = 0 
AS
	SET NOCOUNT ON
	DECLARE @t TABLE( GUID UNIQUEIDENTIFIER) 
	INSERT INTO @t 
		SELECT DISTINCT 
			mtGroup AS Groupmt 
		FROM  
			vwMt 
		GROUP BY  
			mtGroup 
	SELECT  
		gr.grGuid AS grGuid,  
		ISNULL( gr.grCode +'-'+ gr.grName, '') AS grName,  
		ISNULL( gr.grCode +'-'+ gr.grLatinName, '') AS grLatinName, 
		ISNULL( bap.Age, 0) AS Age 
	FROM  
		vwGr AS gr  
		INNER JOIN @t AS t ON gr.grGuid = t.Guid 
		INNER JOIN vwMt As mt ON mt.mtGroup = gr.grGuid
		LEFT JOIN vcbap AS bap ON gr.grGuid = bap.ObjGuid AND bap.BranchGuid = @BranchGuid 
	WHERE  
		(gr.grBranchMask & @branchMask) <> 0 AND mt.mtType = 2
	GROUP BY
		gr.grGuid,
		gr.grCode,
		ISNULL( gr.grCode +'-'+ gr.grName, ''),
		ISNULL( gr.grCode +'-'+ gr.grLatinName, ''),
		ISNULL( bap.Age, 0) 
	ORDER BY 
		Len(gr.grCode),
		gr.grCode
#############################################################################3
#END