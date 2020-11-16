################################################################################
## This Procedure is used by AccTree to show Final Account Name for each account
CREATE PROCEDURE repAccTree
	@Lang		[INT] = 0,					-- Language	(0=Arabic; 1=English) 
	@ACCGuid	[UNIQUEIDENTIFIER] = NULL, 
	@Type		[INT] = 0,
	@ShowOnlyUsedAccounts [BIT] = 0,
	@CostName 	NVARCHAR(500)   = '',
	@CompName	NVARCHAR(500)   = '',
	@MenuName	NVARCHAR(500)   = '' 
AS 
	SET NOCOUNT ON

	 DECLARE @GuidofCost	  [UNIQUEIDENTIFIER] = '0733FAFE-FF92-4D07-84B6-AE040F480A10'
	 DECLARE @GuidofComposite [UNIQUEIDENTIFIER] = '3CEF77A3-E427-4E18-9E32-2BF8C610CDFA'

	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT]) 
	CREATE TABLE [#Result]( 
			[Guid]			[UNIQUEIDENTIFIER], 
			[ParentGuid] 	[UNIQUEIDENTIFIER], 
			[CustGuid]		[UNIQUEIDENTIFIER], 
			[FinalGuid] 	[UNIQUEIDENTIFIER], 
			[Code]			[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
			[Name]			[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
			[CustName]		[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
			[FinalName]		[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
			[UseFlag]		[INT], 
			[NSons]			[INT], 
			[Type]			[INT], 
			[AccSecurity]	[INT], 
			[Path]			[VARCHAR](8000), 
			[Level]			[INT],
			[IsSync]		[BIT],
			[CustomerCount]	[INT],
			[AccMenuName] NVARCHAR(250) COLLATE ARABIC_CI_AI,
			[AccMenuLAtinName] NVARCHAR(250) COLLATE ARABIC_CI_AI
		   	) 

	IF(@MenuName <> '')
		BEGIN 
		INSERT INTO [#Result] 
			SELECT  
				[ac].[acGuid],  
				CASE WHEN ac.acType = 4 THEN @GuidofComposite ELSE @GuidofCost END, 
				0x0,--CASE WHEN cu.cuGuid IS Null then 0x0 ELSE cu.cuGuid END AS CustomerGuid, 
				CASE WHEN ac.acType = 4 THEN @GuidofComposite ELSE @GuidofCost END, 
				AC.acCode as [Code],  
				CASE WHEN @Lang = 0 THEN CASE WHEN [ac].acName = '' THEN [ac].acLatinName  ELSE [ac].acName END ELSE CASE WHEN [ac].acLatinName = '' THEN [ac].acName ELSE [ac].acLatinName END END AS [acName], 
				'',
				'',
				[ac].[acUseFlag], 
				[ac].[acNSons], 
				[ac].[acType], 
				[ac].[acSecurity], 
				'', 
				1,
				[ac].IsSync,
				0,
				AccMenuName,
				AccMenuLatinName
			FROM 
				[vwac] AS [ac] 
				WHERE 
					((ac.AccMenuName = @MenuName OR ac.AccMenuLatinName = @MenuName OR ((@MenuName = @CompName OR @MenuName = @CostName) AND AccMenuLatinName = '' AND AccMenuName = '' ))) AND ac.acType = @Type

		IF(@MenuName = @CompName OR @MenuName = @CostName)
		BEGIN
			INSERT INTO #Result
				SELECT  
				NEWID(),  
				CASE WHEN ac.acType = 4 THEN @GuidofComposite ELSE @GuidofCost END, 
				0x0,--CASE WHEN cu.cuGuid IS Null then 0x0 ELSE cu.cuGuid END AS CustomerGuid, 
				CASE WHEN ac.acType = 4 THEN @GuidofComposite ELSE @GuidofCost END, 
				'',  
				CASE WHEN @Lang = 0 THEN CASE WHEN [ac].AccMenuName = '' THEN [ac].AccMenuLatinName  ELSE [ac].AccMenuName END ELSE CASE WHEN [ac].AccMenuLatinName = '' THEN [ac].AccMenuName ELSE [ac].AccMenuLatinName  END END AS [acName], 
				'',
				'',
				[ac].[acUseFlag], 
				1, 
				[ac].[acType], 
				[ac].[acSecurity], 
				'', 
				1,
				[ac].IsSync,
				0,
				AccMenuName,
				AccMenuLatinName
			FROM 
				[vwac] as [ac]
			WHERE 
				ac.acType = @Type AND (AccMenuLatinName <> '' OR AccMenuName <> '' )
		END

		SELECT * FROM #Result order by path
		IF (@ACCGuid IS NULL OR @ACCGuid = 0x00) 
		BEGIN 
			SELECT * FROM [#SecViol] 
		END 
		RETURN
	END

	IF (@Type = -1)
	BEGIN
		INSERT INTO [#Result] 
			SELECT  
				[ac].[acGuid],  
				ISNULL( [ac].[acParent], 0x0) AS [Parent], 
				0x0, --CASE WHEN cu.cuGuid IS Null then 0x0 ELSE cu.cuGuid END AS CustomerGuid, 
				[ac].[acFinal], 
				[ac].[acCode],  
				CASE WHEN (@Lang = 1)AND([ac].[acLatinName] <> '') THEN  [ac].[acLatinName] ELSE [ac].[acName] END AS [acName], 
				'',--CASE WHEN (@Lang = 1)AND(cu.cuLatinName <> '') THEN  cu.cuLatinName ELSE cu.cuCustomerName END AS cuName, 
				'',--CASE WHEN (@Lang = 1)AND(ac2.acLatinName <> '') THEN  ac2.acLatinName ELSE ac2.acName END AS FinalName, 
				[ac].[acUseFlag], 
				[ac].[acNSons], 
				[ac].[acType], 
				[ac].[acSecurity], 
				'', 
				0,
				[ac].IsSync,
				0,
				AccMenuName,
				AccMenuLatinName
			FROM 
				[vwac] as [ac]
			WHERE  
				[ac].[acGuid] = @AccGuid
	END
	ELSE
	BEGIN
		IF (@Type = 4) OR (@Type = 8) 
		BEGIN 
			INSERT INTO [#Result] 
				SELECT  
					[ac].[acGuid],  
					ISNULL( [ac].[acParent], 0x0) AS [Parent], 
					0x0, --CASE WHEN cu.cuGuid IS Null then 0x0 ELSE cu.cuGuid END AS CustomerGuid, 
					[ac].[acFinal], 
					[ac].[acCode],  
					CASE WHEN (@Lang = 1)AND([ac].[acLatinName] <> '') THEN  [ac].[acLatinName] ELSE [ac].[acName] END AS [acName], 
					'',--CASE WHEN (@Lang = 1)AND(cu.cuLatinName <> '') THEN  cu.cuLatinName ELSE cu.cuCustomerName END AS cuName, 
					'',--CASE WHEN (@Lang = 1)AND(ac2.acLatinName <> '') THEN  ac2.acLatinName ELSE ac2.acName END AS FinalName, 
					[ac].[acUseFlag], 
					[ac].[acNSons], 
					[ac].[acType], 
					[ac].[acSecurity], 
					'', 
					0,
					[ac].IsSync,
					0,
					AccMenuName,
					AccMenuLatinName
				FROM 
					[vwac] as [ac] INNER JOIN [ci000] as [ci]	 
					ON [ci].[SonGUID] = [ac].[acGuid] 
				WHERE  
					(@ACCGuid IS NULL) OR ([ci].[ParentGuid] = @AccGuid) 
					 
		END  
		ELSE
		BEGIN 
			INSERT INTO [#Result] 
				SELECT  
					[ac].[acGuid],  
					CASE WHEN ISNULL(AccMenuName,'') = '' THEN CASE WHEN [ac].[acType] = 8 THEN @GuidofCost WHEN [ac].[acType] = 4 THEN  @GuidofComposite ELSE ISNULL( [ac].[acParent], 0x0) END ELSE ISNULL( [ac].[acParent], 0x0) END AS [Parent], 
					0x0,--CASE WHEN cu.cuGuid IS Null then 0x0 ELSE cu.cuGuid END AS CustomerGuid, 
					CASE WHEN ISNULL(AccMenuName,'') = '' THEN CASE WHEN [ac].[acType] = 8 THEN @GuidofCost WHEN [ac].[acType] = 4 THEN  @GuidofComposite ELSE [ac].[acFinal] END ELSE [ac].[acFinal] END , 
					[ac].[acCode],  
					CASE WHEN (@Lang = 1) AND ([ac].[acLatinName] <> '') THEN  [ac].[acLatinName] ELSE [ac].[acName] END AS [acName], 
					'',
					CASE WHEN  ISNULL(AccMenuName,'') = '' THEN CASE WHEN [ac].[acType] = 8 THEN @CostName WHEN [ac].[acType] = 4 THEN  @CompName ELSE '' END ELSE '' END,
					[ac].[acUseFlag], 
					[ac].[acNSons], 
					[ac].[acType], 
					[ac].[acSecurity], 
					[fn].[Path], 
					[fn].[Level],
					[ac].IsSync,
					0,
					ISNULL(AccMenuName,''),
					ISNULL(AccMenuLatinName,'')
				FROM 
					[vwac] as [ac] 
					INNER JOIN [dbo].[fnGetAccountsListWitthComppositAndCostAccounts]( @ACCGuid, 1) AS [fn] ON [ac].[acGuid] = [fn].[Guid] 
			
			IF( @ShowOnlyUsedAccounts = 1 )	
			BEGIN
				DECLARE @Level INT
				SELECT @Level = MAX(level) FROM [#Result]
				
				WHILE ( @Level > -1 )
				BEGIN
					DELETE FROM #Result WHERE Level = @Level AND Guid NOT IN (SELECT AccountGuid FROM En000) AND Guid NOT IN (SELECT ParentGuid FROM #Result)
					SET @Level = @Level -1
				END
			END			 
		END 
	END
	EXEC [prcCheckSecurity] 

	SELECT
	 DISTINCT 
		 0x0 AS [acGuid],
		MIN(res.path) AS path, 	
		[acType],
		CASE WHEN @Lang = 0 THEN CASE WHEN [vwac].AccMenuName = '' THEN [vwac].AccMenuLatinName  ELSE [vwac].AccMenuName END ELSE CASE WHEN [vwac].AccMenuLatinName = '' THEN [vwac].AccMenuName ELSE [vwac].AccMenuLatinName  END END AS [accMenuName] 
	INTO #TEMPMenu
	FROM 	[vwac] 
		INNER JOIN #Result AS res ON res.Guid = vwAc.acGUID
	WHERE  
		([acType] = 4 OR [acType] = 8)  
		AND (ISNULL(vwac.AccMenuName,'') <> '' OR ISNULL(vwac.AccMenuLatinName, '') <> '')
		GROUP BY 
		vwac.AccMenuLatinName,
		vwac.AccMenuName,
		vwac.acType

	DECLARE @PathCost NVARCHAR(MAX) = (SELECT MIN(path) FROM #Result WHERE TYPE = 8)
	DECLARE @PathComp NVARCHAR(MAX) = (SELECT MIN(path) FROM #Result WHERE TYPE = 4)

	IF (@PathCost IS NOT NULL OR @PathComp IS NOT NUll)
	BEGIN

		UPDATE #TEMPMenu 
		SET acguid =NEWID()

		INSERT INTO #Result 
		SELECT 
		DISTINCT
		temp.acGuid AS [acGuid],  
		CASE WHEN vwac.acType = 8 THEN @GuidofCost ELSE @GuidofComposite END AS [Parent], 
		0x0,
		CASE WHEN vwac.acType = 8 THEN @GuidofCost ELSE @GuidofComposite END AS [FinalGuid], 
		'',  
		 temp.[accMenuName] AS [acName], 
		'',--cuName, 
		CASE WHEN vwac.acType = 8 THEN @CostName ELSE @CompName END [FinalName],--FinalName, 
		[acUseFlag], 
		[acNSons], 
		temp.[acType], 
		[acSecurity], 
		temp.path , 
		 1 ,
		[IsSync],
		0,
		'',
		''
		FROM  
			[vwac] 
			INNER JOIN #TEMPMenu AS temp ON temp.[accMenuName] IN ( vwac.AccMenuName , vwac.AccMenuLatinName) 
		WHERE  
			([vwac].[acType] = 4 OR [vwac].[acType] = 8) AND [vwac].acType = temp.acType

		--MENU LEVEL AND ACC
		UPDATE #Result 
		SET 
		Level = CASE WHEN AccMenuName <> '' OR AccMenuLAtinName <> '' THEN 2 ELSE 1 END,
		NSons = CASE WHEN Code = '' THEN 1 ELSE NSons END
		WHERE Type = 8 OR Type = 4 

		--UPDATE PATH
		UPDATE #Result 
		SET 
		path = CASE WHEN code <> '' AND (AccMenuName = '' AND AccMenuLAtinName = '')THEN CASE WHEN Type = 8 THEN @PathCost + path ELSE @PathComp + path END WHEN code = '' AND level = 1 THEN  CASE WHEN Type = 8 THEN @PathCost + path ELSE @PathComp + path END ELSE PATH END
		WHERE Type = 8 OR Type = 4 
		
		IF(@PathCost IS NOT NULL)
			INSERT INTO #Result values(@GuidofCost, 0x0, 0x0, 0x0, '', @CostName , '', '' , 0, 1, 8, 1, @PathCost , 0 , 0, 0, '' , '')
		
		IF(@PathComp IS NOT NULL)
			INSERT INTO #Result values(@GuidofComposite, 0x0, 0x0, 0x0, '', @CompName , '', '' , 0, 1, 4, 1, @PathComp , 0 , 0, 0, '', '')


		UPDATE Res 
		SET ParentGuid = Temp.acguid ,
			FinalGuid  = CASE WHEN Res.Type= 8 THEN @GuidofCost ELSE @GuidofComposite END,
			FinalName  = Temp.accMenuName 
		FROM #Result AS Res
			INNER JOIN #TEMPMenu AS Temp on  Temp.accMenuName IN (Res.AccMenuLAtinName , Res.AccMenuName)
		WHERE (Res.Type = 4 OR Res.Type = 8) AND Res.Type = temp.acType
		
		UPDATE Res 
		SET 
		path = Temp.Path + Res.Path
		FROM #Result AS Res
			INNER JOIN #Result AS Temp on  Temp.Guid  = Res.ParentGuid
		WHERE (Res.Type = 4 OR Res.Type = 8 ) AND (Res.AccMenuLAtinName <> '' OR Res.AccMenuName <> '') AND Res.Type = Temp.Type

	END
	----------------------------------------------	 
	UPDATE [Res] SET  
		[FinalName] = CASE WHEN (@Lang = 1)AND([ac].[acLatinName] <> '') THEN  [ac].[acLatinName] ELSE [ac].[acName] END 
	FROM  
		[#Result] AS [Res] INNER JOIN [vwac] as [ac]  
		ON [Res].[FinalGuid] = [ac].[acGuid] 
	----------------------------------------------	 
	UPDATE [Res] SET  
		[CustGuid] = ISNULL( [cu].[cuGuid], 0x0), 
		[CustName] = CASE WHEN (@Lang = 1)AND([cu].[cuLatinName] <> '') THEN  [cu].[cuLatinName] ELSE [cu].[cuCustomerName] END 
	FROM  
		[#Result] AS [Res] INNER JOIN [vwcu] as [cu]  
		ON [Res].[Guid] = [cu].[cuAccount] 
	----------------------------------------------	
	UPDATE #Result SET  
		[CustomerCount] = Custcount
	From 
		(SELECT CU.AccountGUID, COUNT(*) CustCount 
		FROM cu000 cu 
		GROUP BY cu.AccountGUID) T
	WHERE T.AccountGUID = [Guid]
	----------------------------------------------	
	SELECT * FROM [#Result] ORDER BY [Path]--ParentGuid, Guid 
	 
	IF (@ACCGuid IS NULL OR @ACCGuid = 0x00) 
	BEGIN 
		SELECT * FROM [#SecViol] 
	END 
	 
	-- DROP PROCEDURE REPACCTREE 
	-- DROP TABLE #Result 
	-- DROP TABLE #Accs 
	-- SELECT Top 100 * FROM ac000 
	-- SELECT Top 1 * FROM cu000 
	-- Exec repAccTree 1, '87B533E9-78B8-42C2-BA07-5248BB297940' 
	-- Exec prcGetAccountsList NULL 
	-- Exec SELECT * FROM dbo.fnGetAccountsList(NULL) 
###################################################################################
##--≈⁄«œ…  —„Ì“ «·Õ”«»« 
## 
CREATE PROCEDURE PrcReorderAccountsCodes 	
	@GUID [UNIQUEIDENTIFIER]
AS 
	DECLARE  
		@AccCur				CURSOR, 
		@OrdCur				CURSOR,
		@ReorderCur			CURSOR,
		@ParentGuid			UNIQUEIDENTIFIER, 
		@AccGuid			UNIQUEIDENTIFIER, 
		@ParentCode			NVARCHAR(250), 
		@Counter			INT, 
		@AccsCount			INT,
		@CODE				NVARCHAR(25)
	SET @AccCur = CURSOR FAST_FORWARD FOR 
		SELECT 
			[GUID] 
		FROM 
			[fnGetAccountsList](@GUID, 1) 
		ORDER BY [LEVEL] 
		
	OPEN @AccCur FETCH NEXT FROM @AccCur INTO  @ParentGuid 
	WHILE @@FETCH_STATUS = 0 
	BEGIN  
		SET @Counter = 0 
		SELECT @ParentCode = [Code] FROM [ac000] WHERE [GUID] = @ParentGuid 
		SELECT @AccsCount = COUNT(*) FROM [ac000] WHERE [ParentGUID] = @ParentGuid 
	 
		SET @OrdCur = CURSOR FAST_FORWARD FOR 
			SELECT 
				[GUID] 
			FROM 
				[ac000] 
			WHERE 
				[ParentGUID] = @ParentGuid 
			ORDER BY 
				[CODE] 
				
		OPEN @OrdCur FETCH NEXT FROM @OrdCur INTO  @AccGuid 
		WHILE @@FETCH_STATUS = 0 AND @Counter < @AccsCount
		BEGIN  
			SET @Counter = @Counter + 1 
			DECLARE @STR NVARCHAR(10) 
			IF @AccsCount < 10 
			BEGIN  
				IF @Counter < 10 
					SET @STR = '' + CAST( ISNULL(@Counter, 0) AS NVARCHAR(10)) 
			END
			ELSE
				IF @AccsCount < 100 
				BEGIN  
					IF @Counter < 10 
						SET @STR = '0' + CAST( ISNULL(@Counter, 0) AS NVARCHAR(10)) 
					ELSE 
						IF @Counter < 100 
							SET @STR = '' + CAST( ISNULL(@Counter, 0) AS NVARCHAR(10)) 
				END 
				ELSE 
					IF @AccsCount < 1000 
					BEGIN  
						IF @Counter < 10 
							SET @STR = '00' + CAST( ISNULL(@Counter, 0) AS NVARCHAR(10))  
						ELSE
							IF @Counter < 100 
								SET @STR = '0' + CAST( ISNULL(@Counter, 0) AS NVARCHAR(10))  
							ELSE 
								IF @Counter < 1000 
									SET @STR = '' + CAST( ISNULL(@Counter, 0) AS NVARCHAR(10))  
					END
					ELSE 
						BEGIN 
							IF @Counter < 10 
								SET @STR = '000' + CAST( ISNULL(@Counter, 0) AS NVARCHAR(10))  
							ELSE 
								IF @Counter < 100 
									SET @STR = '00' + CAST( ISNULL(@Counter, 0) AS NVARCHAR(10))  
								ELSE 
									IF @Counter < 1000 
										SET @STR = '0' + CAST( ISNULL(@Counter, 0) AS NVARCHAR(10))  
									ELSE  
										SET @STR = '' + CAST( ISNULL(@Counter, 0) AS NVARCHAR(10))  
						END
						  
			UPDATE [ac000] SET [Code] = @ParentCode + @STR WHERE [GUID] = @AccGuid 
			FETCH NEXT FROM @OrdCur INTO  @AccGuid 
		END  
		CLOSE @OrdCur DEALLOCATE @OrdCur 
		 
		FETCH NEXT FROM @AccCur INTO  @ParentGuid 
	END  
	CLOSE @AccCur DEALLOCATE @AccCur 
	
	SET @ReorderCur = CURSOR FAST_FORWARD FOR 
		SELECT 
			[fn].[GUID], 
			[ac].[Code] 
		FROM 
			[fnGetAccountsList](@GUID, 1) [fn] 
			INNER JOIN [ac000] [ac] ON [ac].[guid] = [fn].[guid] 
		WHERE 
			[fn].[Guid] <> @GUID
			
	OPEN @ReorderCur FETCH NEXT FROM @ReorderCur INTO  @AccGuid, @CODE
	WHILE @@FETCH_STATUS = 0 
	BEGIN  
			IF EXISTS (SELECT [Code] FROM [ac000] WHERE [GUID] != @AccGuid AND [CODE] = @CODE)
				UPDATE [ac000] SET [Code] = [Code] + '*' WHERE [GUID] = @AccGuid
			FETCH NEXT FROM @ReorderCur INTO  @AccGuid, @CODE
	END
	CLOSE @ReorderCur DEALLOCATE @ReorderCur 
/* 
prcConnections_add2 '„œÌ—' 
PrcReorderAccountsCodes 'DAD5712C-CA8B-4270-A37F-13F92276357C'
*/ 
###################################################################################
CREATE  PROCEDURE prcAccCustomersTree
	@Lang		[INT] = 0,					-- Language	(0=Arabic; 1=English) 
	@ACCGuid	[UNIQUEIDENTIFIER] = NULL, 
	@Type		[INT] = 0,
	@ShowOnlyUsedAccounts [BIT] = 0	 
AS 
	SET NOCOUNT ON
	
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT]) 
	CREATE TABLE [#Result]( 
			[Guid]			[UNIQUEIDENTIFIER], 
			[ParentGuid] 	[UNIQUEIDENTIFIER], 
			[CustGuid]		[UNIQUEIDENTIFIER], 
			[FinalGuid] 	[UNIQUEIDENTIFIER], 
			[Code]			[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
			[Name]			[NVARCHAR](1000) COLLATE ARABIC_CI_AI, 
			[CustName]		[NVARCHAR](1000) COLLATE ARABIC_CI_AI, 
			[FinalName]		[NVARCHAR](1000) COLLATE ARABIC_CI_AI, 
			[UseFlag]		[INT], 
			[NSons]			[INT], 
			[Type]			[INT], 
			[AccSecurity]	[INT], 
			[Path]			[VARCHAR](8000), 
			[Level]			[INT],
			[IsSync]		[BIT],
			[CustomerCount] [INT]
		   	) 
	 
	DECLARE @counter INT ;
	DECLARE @TempTable TABLE(
	name nvarchar(1000) ,
	Guid uniqueidentifier ,
	Parent uniqueidentifier,
	level int  
	);

	;WITH tmp AS
	(
	SELECT DISTINCT
		acName as name ,
		acGUID as Guid ,
		acParent as parent,
		fn.Level,
		Count(*)OVER(PARTITION BY acName) as number
	FROM
		vwCuAc ac
	INNER JOIN fnGetAccountsList(0x0,1) fn on fn.GUID = ac.acGUID
	)
	INSERT INTO @TempTable
	select Name, GUID,Parent,[level]
	FROM tmp
	WHERE number >= 1

	SELECT @counter= max(level) FROM @TempTable

	WHILE @counter != -1
	BEGIN
	INSERT INTO @TempTable( Guid, level,Parent )
	SELECT
		fn.GUID, level, ac.ParentGUID parent
	FROM
		fnGetAccountsList(0x0,1) fn
	INNER JOIN ac000 ac on ac.GUID = fn.GUID
	WHERE
		level = @counter-1 And fn.GUID in (SELECT parent FROM @TempTable)
	SET @counter= @counter -1
	END
		INSERT INTO [#Result] 
			SELECT  
				[ac].[acGuid],  
				ISNULL( [ac].[acParent], 0x0) AS [Parent], 
				0x0,--CASE WHEN cu.cuGuid IS Null then 0x0 ELSE cu.cuGuid END AS CustomerGuid, 
				[ac].[acFinal], 
				[ac].[acCode],  
				CASE WHEN (@Lang = 1)AND([ac].[acLatinName] <> '') THEN  [ac].[acLatinName] ELSE [ac].[acName] END AS [acName], 
				'',--CASE WHEN (@Lang = 1)AND(cu.cuLatinName <> '') THEN  cu.cuLatinName ELSE cu.cuCustomerName END AS cuName, 
				'',--CASE WHEN (@Lang = 1)AND(ac2.acLatinName <> '') THEN  ac2.acLatinName ELSE ac2.acName END AS FinalName, 
				[ac].[acUseFlag], 
				[ac].[acNSons], 
				[ac].[acType], 
				[ac].[acSecurity], 
				[fn].[Path], 
				[fn].[Level],
				[ac].IsSync,
				0
			FROM 
				[vwac] as [ac] INNER JOIN [dbo].[fnGetAccountsList]( @ACCGuid, 1) AS [fn] 
				ON [ac].[acGuid] = [fn].[Guid] 
				INNER JOIN @TempTable t on t.Guid = ac.[acGuid]
					
		IF( @ShowOnlyUsedAccounts = 1 )	
		BEGIN
			DECLARE @Level INT
			SELECT @Level = MAX(level) FROM [#Result]
				
			WHILE ( @Level > -1 )
			BEGIN
				DELETE FROM #Result WHERE Level = @Level AND Guid NOT IN (SELECT AccountGuid FROM En000) AND Guid NOT IN (SELECT ParentGuid FROM #Result)
				SET @Level = @Level -1
			END
		END			 
		 
	EXEC [prcCheckSecurity] 
	----------------------------------------------	 
	UPDATE [Res] SET  
		[FinalName] = CASE WHEN (@Lang = 1)AND([ac].[acLatinName] <> '') THEN  [ac].[acLatinName] ELSE [ac].[acName] END 
	FROM  
		[#Result] AS [Res] INNER JOIN [vwac] as [ac]  
		ON [Res].[FinalGuid] = [ac].[acGuid] 
	----------------------------------------------	 
	UPDATE [Res] SET  
		[CustGuid] = ISNULL( [cu].[cuGuid], 0x0), 
		[CustName] = CASE WHEN (@Lang = 1)AND([cu].[cuLatinName] <> '') THEN  [cu].[cuLatinName] ELSE [cu].[cuCustomerName] END 
	FROM  
		[#Result] AS [Res] INNER JOIN [vwcu] as [cu]  
		ON [Res].[Guid] = [cu].[cuAccount] 
	----------------------------------------------
	UPDATE #Result SET  
		[CustomerCount] = Custcount
	From 
		(SELECT CU.AccountGUID, COUNT(*) CustCount 
		FROM cu000 cu 
		GROUP BY cu.AccountGUID) T
	WHERE T.AccountGUID = [Guid]
	----------------------------------------------	
	SELECT * FROM [#Result] ORDER BY [Path]--ParentGuid, Guid 
	 
	IF (@ACCGuid IS NULL OR @ACCGuid = 0x00) 
	BEGIN 
		SELECT * FROM [#SecViol] 
	END 
###################################################################################
CREATE PROCEDURE prcDAccCustomersTree
	@Lang		[INT] = 0,
	@ACCGuid	[UNIQUEIDENTIFIER] = NULL
	
AS 
	SET NOCOUNT ON
	
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT]) 
	CREATE TABLE [#Result]
			( 
			[Guid]			[UNIQUEIDENTIFIER], 
			[ParentGuid] 	[UNIQUEIDENTIFIER], 
			[Name]			[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
			[Level]			[INT],
			[NSons]			[INT], 
			[CustSecurity]  [INT]
		   	) 
	 
	INSERT INTO #Result( name, Guid, [ParentGuid], level, NSons, CustSecurity )
	SELECT CASE WHEN (@Lang = 1)AND(cuLatinName <> '') THEN  cuLatinName ELSE cuCustomerName END, cuGUID,cuGUID, 0, 0, cuSecurity
	FROM vwCu WHERE cuAccount = @ACCGuid
	
	EXEC [prcCheckSecurity] 
	 
	SELECT * FROM [#Result] ORDER BY Name
	 
	IF (@ACCGuid IS NULL OR @ACCGuid = 0x00) 
	BEGIN 
		SELECT * FROM [#SecViol] 
	END 
###################################################################################
#END
