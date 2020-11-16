#########################################################
CREATE FUNCTION fnGetGroupsListByLevel (@GroupGUID  [UNIQUEIDENTIFIER], @Level [INT] = 0) 
   RETURNS @Result TABLE ([GUID]  [UNIQUEIDENTIFIER], [Level] [INT])
/*
	This function Returns The Groups Until Level @Level
	If Level=0 returns all Groups 
*/
BEGIN  
	DECLARE @FatherBuf	TABLE([GUID] [UNIQUEIDENTIFIER], [Level] [INT])
	DECLARE @Continue [INT], @Acc_Level [INT]	
    SET @Acc_Level = 1

	IF ( ISNULL( @GroupGUID, 0x0) = 0X0)  
		INSERT INTO @FatherBuf  SELECT [grGUID], @Acc_Level FROM [vwGr] WHERE [grParent] = 0X0 
	ELSE
	BEGIN
		IF ((SELECT [KIND] FROM [gr000] WHERE [gr000].[GUID] = @GroupGUID) = 0)
			INSERT INTO @FatherBuf SELECT [grGUID], @Acc_Level FROM [vwGr] WHERE [grGUID] = @GroupGUID
		ELSE
		BEGIN
			INSERT INTO @Result
			SELECT DISTINCT mt.GroupGUID, @Acc_Level
			FROM
				[fnGetMatsOfCollectiveGrps] (@GroupGUID) AS FN
				INNER JOIN mt000 AS mt ON mt.Guid = [FN].[mtGuid]
			RETURN
		END
	END	
	SET @Continue = 1
	
	WHILE( @Continue <> 0) 
	BEGIN
		IF( ( @Level = 0) OR ( @Acc_Level < @Level))
		BEGIN
			SET @Acc_Level = @Acc_Level + 1
			INSERT INTO @FatherBuf
			SELECT 
				[grGUID], @Acc_Level
			FROM 
				[vwGr] AS [Gr] INNER JOIN @FatherBuf AS [fb] 
				ON [Gr].[grParent] = [fb].[GUID] 
			WHERE 
				[fb].[Level] = @Acc_Level - 1
			SET @Continue = @@ROWCOUNT
		END	
		ELSE
			BREAK 
	END  
	INSERT INTO @Result SELECT [GUID],[LEVEL] FROM @FatherBuf 
	RETURN   
END
#########################################################
#END