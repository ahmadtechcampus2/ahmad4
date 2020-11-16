##############################################
CREATE FUNCTION fnGetExchangeTypesTree( )
	RETURNS TABLE
AS
/*
icon ids:
	81. Transfer Typs root.
	82. Transfer Voucher
*/
	RETURN (
		SELECT GUID, 0x0 AS ParentGUID, '' AS Code, Name, LatinName, 'TrnExchangeTypes000' AS tableName, 
			0 AS branchMask, 14 AS SortNum, 101 AS IconID, '.' AS Path, 0 AS [Level] 
			 FROM brt WHERE tableName = 'TrnExchangeTypes000'
		UNION ALL
		SELECT 
			t.GUID, 
			b.GUID,
			t.Abbrev,
			t.Name,
			t.LatinName,
			'TrnExchangeTypes000',
			t.branchMask,
			sortNum, --- t.Type * 64000 + t.SortNum, -- sortNum
			102,--
			'.' AS Path, 
			1 AS [Level]
		FROM TrnExchangeTypes000 AS t INNER JOIN brt AS b ON b.tableName = 'TrnExchangeTypes000')
#################################
#END