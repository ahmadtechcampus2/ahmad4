#########################################################
CREATE FUNCTION fnGetTrnStatementTypesTree( )
	RETURNS TABLE
AS
/*
icon ids:
	91. Trn Statement Typs root.
	92. Trn Statement Voucher
*/
	RETURN (
		SELECT GUID, 0x0 AS ParentGUID, '' AS Code, Name, LatinName, 'TrnStatementTypes000' AS tableName, 
			0 AS branchMask, 15 AS SortNum, 91 AS IconID, '.' AS Path, 0 AS [Level] 
			 FROM brt WHERE tableName = 'TrnStatementTypes000'
		UNION ALL
		SELECT 
			t.GUID, 
			b.GUID,
			t.Abbrev,
			t.Name,
			t.LatinName,
			'TrnStatementTypes000',
			t.branchMask,
			sortNum, --- t.Type * 64000 + t.SortNum, -- sortNum
			92,--
			'.' AS Path, 
			1 AS [Level]
		FROM TrnStatementTypes000 AS t INNER JOIN brt AS b ON b.tableName = 'TrnStatementTypes000')
/*
select * FROM bt000 TrnStatementTypes000
*/
#########################################################
CREATE FUNCTION fnIsBranchReleatedToCenter(@BranchID UNIQUEIDENTIFIER, @CenterID UNIQUEIDENTIFIER)
RETURNS BIT
BEGIN

	IF EXISTS(SELECT * FROM TrnCenter000 WHERE BranchGuid = @BranchID AND GUID = @CenterID)
		RETURN 1;
	RETURN 0;

END
#######################
#END