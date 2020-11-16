########################################
CREATE FUNCTION fnGetBranchParents(@StartGUID [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE([GUID] [UNIQUEIDENTIFIER])
AS BEGIN

/*
This function:
	- returns a list of ascending parents branches starting from a given branch number.
	- handles the problem of orphants and cross-links.
*/

	DECLARE @ParentGUID [UNIQUEIDENTIFIER]

	SELECT @ParentGUID = [ParentGUID] FROM [br000] WHERE [GUID] = @StartGUID
	WHILE @@ROWCOUNT <> 0
	BEGIN
		IF EXISTS(SELECT * FROM @Result WHERE [GUID] = @ParentGUID)
			BREAK

		INSERT INTO @Result VALUES(@ParentGUID)
		SELECT @ParentGUID = [ParentGUID] FROM [br000] WHERE [GUID] = @ParentGUID
	END

	RETURN
END

/*
select * from br000
select * from fnGetBranchParents( 'B9D2FAE6-5EC6-45DD-AADE-1725B3AFAC29')

*/
########################################
CREATE FUNCTION fnGetBranchesList(
			@BranchGUID [UNIQUEIDENTIFIER]
			) 
		RETURNS @Result TABLE (GUID [UNIQUEIDENTIFIER], [Level] [INT] DEFAULT 0)    
AS BEGIN   
	DECLARE @FatherBuf TABLE( [GUID] [UNIQUEIDENTIFIER], [Level] [INT])    
	DECLARE @Continue [INT], @Level [INT]    
	
	SET @Level = 0      
	IF ISNULL( @BranchGUID, 0x0) = 0x0 
	BEGIN
		INSERT INTO @FatherBuf ( [GUID], [Level])   
			SELECT [GUID], @Level 
			FROM [br000]
			WHERE ISNULL([ParentGUID], 0x0) = 0x0 
	END
	ELSE    
	BEGIN
		INSERT INTO @FatherBuf ( [GUID], [Level])   
			SELECT [brGUID], @Level FROM [vwBr] WHERE [brGUID] = @BranchGUID  
	END

	
	SET @Continue = 1    
	---/////////////////////////////////////////////////////////////    
	WHILE @Continue <> 0      
	BEGIN    
		SET @Level = @Level + 1      
		INSERT INTO @FatherBuf( [GUID], [Level])    
			SELECT [Br].[brGUID], @Level   
				FROM [vwBr] AS [Br] INNER JOIN @FatherBuf AS [fb] ON [Br].[brParentGUID] = [fb].[GUID]   
				WHERE [fb].[Level] = @Level - 1
				
		SET @Continue = @@ROWCOUNT 
	END   
	INSERT INTO @Result SELECT [GUID], [Level] FROM @FatherBuf GROUP BY [GUID], [Level]

	RETURN   
END 
################################
#END 