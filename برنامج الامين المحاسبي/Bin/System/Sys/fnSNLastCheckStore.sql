######################################################################
CREATE FUNCTION fnSNLastCheckStore
      (
	  @SnGuid UNIQUEIDENTIFIER = 0x0, 
      @ToDate DATETIME = '1/1/1800'  
	  )
    
RETURNS  UNIQUEIDENTIFIER
AS 
BEGIN
		
		DECLARE @BranchMask BIGINT  ;
		SET @BranchMask = -1 
		IF EXISTS(select ISNULL([value],0) from op000 where [name] = 'EnableBranches') 
		BEGIN 
			DECLARE @En_br BIGINT 
			SET @En_br = (select TOP 1 ISNULL([value],0) from op000 where [name] = 'EnableBranches') 
			IF (@En_br = 1) 
				SET @BranchMask = (SELECT [dbo].[fnConnections_getBranchMask] ()) 
		END 

		DECLARE @stGuid UNIQUEIDENTIFIER = (
		SELECT TOP 1
		ISNULL([bi].[StoreGUID],0x0) AS [StoreGuid]
		FROM [snc000] AS snc	 
		INNER JOIN [snt000]AS snt ON [snc].[GUID]    = [snt].ParentGUID 
		INNER JOIN [bu000] AS bu  ON [snt].[buGuid]  = [bu].[GUID] 
		INNER JOIN [bi000] AS bi  ON [snt].[biGUID]  = [bi].[GUID] 
		INNER JOIN [bt000] AS bt  ON [bu].[TypeGUID] = [bt].[GUID] 
		INNER JOIN [mt000] AS mt  ON [snc].[MatGUID] = [mt].[GUID] 
		LEFT  JOIN [vwbr]  AS br  ON [br].[brGUID]   = [bu].[Branch] 
		WHERE  ((@BranchMask = 0 OR  @BranchMask = -1) OR (([br].[brBranchMask] & @BranchMask) = [br].[brBranchMask])) 
		AND bu.IsPosted != 0 
		AND [snc].[GUID] = @SnGuid
		AND [bu].[Date] <= @ToDate
		AND bt.bIsInput = 1
		ORDER BY [bu].[Date] DESC,[bu].[Number] DESC)

		RETURN @stGuid
END 

#########################################################################################
#END
