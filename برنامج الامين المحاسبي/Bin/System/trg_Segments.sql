###########################################################################
CREATE TRIGGER trg_Segments000_UPDATE
ON Segments000 FOR UPDATE
NOT FOR REPLICATION
AS
	
	SELECT se.Name AS ElementName, 
	ISNULL(se.LatinName,'') AS ElementLatinName,
	se.Code AS ElementCode,
	mt.Name AS MaterialName, 
	me.[Order] AS Number, 
	mt.GUID AS MaterialGuid
	INTO #CompositionsElements
	FROM Segments000 i
	JOIN SegmentElements000 se ON i.Id = se.SegmentId
	JOIN MaterialElements000 me ON se.Id = me.ElementId
	JOIN mt000 mt ON me.MaterialId = mt.GUID
	
	SELECT DISTINCT C2.MaterialName, 
	    SUBSTRING(
	        (
	            SELECT '-'+ C1.ElementName  AS [text()]
	            FROM dbo.#CompositionsElements C1
	            WHERE C1.MaterialGuid = C2.MaterialGuid
	            ORDER BY C1.Number
	            For XML PATH ('')
	        ), 2, 1000) AS Name,

		SUBSTRING(
	        (
	            SELECT '-'+ CASE WHEN C1.ElementLatinName = '' THEN C1.ElementName ELSE C1.ElementLatinName END  AS [text()]
	            FROM dbo.#CompositionsElements C1
	            WHERE C1.MaterialGuid = C2.MaterialGuid
	            ORDER BY C1.Number
	            For XML PATH ('')
	        ), 2, 1000) AS LatinName,
		SUBSTRING(
	        (
	            SELECT '-'+ C1.ElementCode  AS [text()]
	            FROM dbo.#CompositionsElements C1
	            WHERE C1.MaterialGuid = C2.MaterialGuid
	            ORDER BY C1.Number
	            For XML PATH ('')
	        ), 2, 1000) AS Code,
			C2.MaterialGuid
	INTO #Result
	FROM dbo.#CompositionsElements C2

	UPDATE mt 
	SET mt.CompositionName = r.Name,
		mt.CompositionLatinName = r.LatinName,
		mt.Code = parent.Code + '-' +  r.Code
	FROM mt000 mt
	JOIN #Result r ON mt.[GUID] = r.MaterialGuid
	JOIN mt000 parent ON mt.Parent = parent.GUID

DROP TABLE #CompositionsElements
DROP TABLE #Result
###########################################################################
#END