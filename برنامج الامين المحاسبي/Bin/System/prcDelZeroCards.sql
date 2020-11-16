###########################################################################
CREATE PROCEDURE prcDelZeroCards
	@DelCustomers		[BIT] = 0, -- 1 del cust , 0 no del acc only
	@DelAccs			[BIT] = 0, -- 1 del cust AND Acc, 0 no del acc only
	@DelMats			[BIT] = 0, --1 del mat qnt = 0 and not dervices
	@DelService			[BIT] = 0, --1 del mat that type MT_SERVICE
	@DelLoyaltyCards	[BIT] = 0,
	@SurceDBName		[NVARCHAR](255),
	@DelBalMats			[BIT] = 0
AS
	-- del customers:
	-- enum TAccType { AT_NORMAL = 1, AT_FINAL = 2, AT_COMPOSITE = 4, AT_COST = 8};
	BEGIN TRAN
	DECLARE @Sql [NVARCHAR](max)
	IF @DelAccs = 1 OR @DelCustomers = 1
	BEGIN
		-- del cust of acc
		IF ( @DelCustomers = 1)
		BEGIN
			CREATE TABLE [#cu]([cuGuid] [UNIQUEIDENTIFIER],[acGuid] [UNIQUEIDENTIFIER])
			SET  @Sql = 'INSERT INTO [#cu] SELECT [cu].[Guid] ,[ac].[Guid]   FROM [cu000] AS [cu] INNER JOIN  ' + @SurceDBName + '..[cu000] AS [cu2] ON [cu].[Guid] = [cu2].[Guid] INNER JOIN [ac000] AS [ac] ON [cu].[AccountGUID] = [ac].[GUID]
			WHERE
				[ac].[Debit] = 0
				AND [ac].[Credit] = 0
				AND [ac].[NSons] = 0
				AND (dbo.[fnAccount_IsUsed]( [ac].[Guid],DEFAULT) = 0x004000000000)
				AND [ac].[Guid] NOT IN ( SELECT DISTINCT [AccountGuid] FROM ' + @SurceDBName + '..[en000])
				AND [cu].[Guid] NOT IN ( SELECT DISTINCT [CustGuid] FROM ' + @SurceDBName + '..[BU000])
				AND [ac].[Guid] NOT IN ( SELECT DISTINCT [AccountGuid] FROM [en000])
				AND [cu].[Guid] NOT IN ( SELECT DISTINCT [CustGuid] FROM [BU000])'
			EXEC (@Sql)	
			DELETE [cu] FROM [cu000] AS [cu] INNER JOIN [#CU] AS [c] ON [cu].[Guid] = [c].[CuGuid]
			DELETE [ac] FROM [ac000] AS [ac] INNER JOIN [#cu] AS [c] ON [ac].[Guid] = [c].[acGuid]
			
			SET  @Sql = 'DELETE [pt000] WHERE [Type] = 2 AND [refGuid] NOT IN (SELECT GUID FROM [cu000])'
			EXEC (@Sql)
			SET  @Sql = 'DELETE [ti000] WHERE [ParentGuid] NOT IN (SELECT [Guid] FROM [pt000])'
			EXEC (@Sql)
		END
		-- del acc not in en which is empty 
		IF @DelAccs = 1
		BEGIN
			SET  @Sql = 'DELETE [ac] FROM [ac000] AS [ac] INNER JOIN  ' + @SurceDBName + '..[ac000] AS [ac2] ON [ac].[Guid] = [ac2].[Guid] WHERE 
					[ac].[Debit] = 0 
					AND [ac].[Credit] = 0 
					AND [ac].[NSons] = 0 
					AND (dbo.[fnAccount_IsUsed]([ac].[Guid],DEFAULT) = 0)
					AND [ac].[Guid] NOT IN ( SELECT DISTINCT [AccountGuid] FROM ' + @SurceDBName + '..[en000])
					AND [ac].[Guid] NOT IN ( SELECT DISTINCT [AccountGuid] FROM [en000])'
			EXEC (@Sql)
		END
	END
	
	-- delete mats:
	IF @DelMats = 1 OR @DelBalMats = 1
	BEGIN
		
		-- empty mats not found in ms000
		SET  @Sql = 'DELETE  [mt] FROM [mt000] AS [mt] INNER JOIN ' + @SurceDBName +'..mt000 AS [m] ON [m].[Guid] = [mt].[Guid] WHERE (([mt].[Type] = 0 OR [mt].[Type] = 2) AND dbo.[fnMaterial_IsUsed]([mt].[GUID]) = 0) AND [mt].[Parent] = 0x0 '
		IF (@DelBalMats = 0)
			SET  @Sql = @Sql + ' AND ' + @SurceDBName + '.dbo.[fnMaterial_IsUsed]([mt].GUID) = 0'
		EXEC (@Sql)

		IF EXISTS(SELECT * FROM [md000] WHERE [ParentGUID] NOT IN (SELECT [Guid] FROM [mt000]))		
		BEGIN
			DELETE [md000] WHERE [ParentGUID] NOT IN (SELECT [Guid] FROM [mt000])
			EXEC (@Sql)
		END
		DELETE [ad000] WHERE [ParentGuid] IN (SELECT [Guid] FROM  [as000] WHERE [ParentGuid] NOT IN (SELECT [GUID] FROM [mt000]))
		DELETE [as000] WHERE [ParentGuid] NOT IN (SELECT [GUID] FROM [mt000])
	END
	IF @DelService = 1
	BEGIN 
		SET  @Sql = 'DELETE [mt] FROM [mt000] AS [mt] INNER JOIN ' + @SurceDBName + '..mt000 AS [m] ON [m].[Guid] = [mt].[Guid]
			WHERE [mt].[Type] = 1 '
		EXEC (@Sql)
	END

	IF @DelLoyaltyCards = 1
	BEGIN
		SET @Sql = 'DELETE [LC] FROM [POSLoyaltyCard000] AS [LC] INNER JOIN ' + @SurceDBName +
					'..POSLoyaltyCard000 AS [p] ON [p].[Guid] = [LC].[Guid] 
					WHERE [LC].[IsInactive] = 1 OR [LC].[EndDate] < GETDATE() '

		SET @Sql += 'DELETE [LCT] FROM [POSLoyaltyCardType000]  AS [LCT] INNER JOIN ' + @SurceDBName + 
					'..POSLoyaltyCardType000 AS [p] ON [p].[Guid] = [LCT].[Guid] 
					WHERE [LCT].[IsInactive] = 1 '

		SET @Sql += 'DELETE [LCC] FROM [POSLoyaltyCardClassification000] AS [LCC] INNER JOIN '  + @SurceDBName +
					'..POSLoyaltyCardClassification000 AS [p] ON [p].[Guid] = [LCC].[Guid] 
					WHERE NOT EXISTS( SELECT 1 FROM POSLoyaltyCard000 WHERE ClassificationGuid = [LCC].[Guid] ) 
					AND NOT EXISTS( SELECT 1 FROM POSLoyaltyCardType000 WHERE ClassificationGuid = [LCC].[Guid] ) 
					'
		EXEC (@Sql)
	END

	COMMIT
			

	/*
	EXEC  prcDelZeroCards
	1,	--@DelCustomers INT, -- 1 del cust , 0 no del acc only
	2,	--@DelAccs INT, -- 1 del cust AND Acc, 0 no del acc only
	3,	--@DelMats INT
	4 	--@DelService INT
	*/
###########################################################################
#END