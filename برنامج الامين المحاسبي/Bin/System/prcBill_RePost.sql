#########################################################
CREATE PROCEDURE prcBill_repost
	@hushed					BIT = 0,
	@ignoreLastPriceAndCost BIT = 0,
	@LgGuid					UNIQUEIDENTIFIER = 0x0,
	@IsCalcQty				BIT = 1,
	@IsCalcCP				BIT = 1,	
	@IsCalcLastPrice		BIT = 1,
	@IsCalcAvgPrice			BIT = 1	
AS
/*
This method:
	- is resposible for reposting all posted bu000 records.
	- caluclates bi and bu profits depending on the Avarage Price algorithem.
	- updates mt, ms and cp statistics.
	- resets the mc ReCalcProfits flag.
	- can return notification error messages in ErrorLog, when not @hushed, pointing out withrawall of nigative
*/
	SET NOCOUNT ON

	DECLARE 
		@bNeg	BIT,
		@zeroQ	FLOAT,
		@zeroP	FLOAT 

	SET @zeroQ = dbo.fnGetZeroValueQTY()
	SET @zeroP = dbo.fnGetZeroValuePrice()

	IF @hushed = 0
	BEGIN 
		EXEC [prcCheckDB_Initialize]

		IF @IsCalcAvgPrice = 1 OR @IsCalcQty = 1
		BEGIN
			SELECT GUID, Qty, AvgPrice		INTO #mt FROM mt000
			SELECT StoreGUID, MatGUID, Qty	INTO #ms FROM ms000
		END
	END 
	-------------------------
	IF @IsCalcAvgPrice = 1
	BEGIN
		EXEC prcDisableTriggers 'bi000'
		EXEC prcDisableTriggers 'bu000'
	END
	IF @IsCalcQty = 1
	BEGIN 
		EXEC prcDisableTriggers 'ms000'
		EXEC prcDisableTriggers 'snc000'
	END 
	EXEC prcDisableTriggers 'mt000'
	
	-- bi cursor, and cursor's input variables declarations:
	IF ISNULL(@IsCalcAvgPrice, 1) = 1
	BEGIN
		UPDATE mt000 
		SET  
			[AvgPrice] =		0,
			[MaxPrice] =		0,  
			[MaxPrice2] =		0,  
			[MaxPrice3] =		0

		-- mt table variables declarations:
		DECLARE
			@mtGUID			[UNIQUEIDENTIFIER],
			@mtQnt			[FLOAT],
			@mtAvgPrice		[FLOAT],
			@mtMaxPrice		[FLOAT],
			@mtValue		[FLOAT],
			@mtUnit2Fact	[FLOAT],
			@mtUnit3Fact	[FLOAT],
			@UnityFactor	[FLOAT]

		DECLARE
			@c_bi						CURSOR,
			@buGUID						[UNIQUEIDENTIFIER],
			@buDate						[DATETIME],
			@biGUID						[UNIQUEIDENTIFIER],
			@biMatPtr					[UNIQUEIDENTIFIER],
			@biUnity					[INT],
			@biQty						[FLOAT],
			@biQty2						[FLOAT],
			@biQty3						[FLOAT],
			@biBonusQnt					[FLOAT],
			@biPrice					[FLOAT],
			@biUnitPrice				[FLOAT],
			@biUnitDiscount				[FLOAT],
			@biUnitExtra				[FLOAT],
			@buDirection				[INT],
			@btAffectLastPrice			[BIT],
			@btAffectCostPrice			[BIT],
			@btAffectProfit				[BIT],
			@btExtraAffectCostPrice		[BIT],
			@biDiscExtra				[FLOAT], 
			@btDiscountAffectCostPrice	[BIT],
			@btExtraAffectProfit		[BIT],
			@btDiscountAffectProfit		[BIT],
			@btBillType					[INT],
			@mtType						[BIT],
			@biLCDisc					[FLOAT],
			@biLCExtra					[FLOAT],
			@BuIsposted					[BIT]

		CREATE TABLE [#BillsTypesTbl_AVG]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], 
			[UnPostedSecurity] [INTEGER], [PriorityNum] [INTEGER], [SamePriorityOrder] INT, [SortNumber] INT) 
		INSERT INTO [#BillsTypesTbl_AVG] EXEC [prcGetBillsTypesList3] NULL, NULL, 1 /*@SortAffectCostType*/
		
		SET @mtGUID = 0x0
		-- setup bi cursor:
		SET @c_bi = CURSOR FAST_FORWARD FOR
				SELECT
					[buGUID],
					[buDate],
					[biGUID],
					[biMatPtr],
					[biUnity],
					[biQty],
					[biQty2],
					[biQty3],
					[biBonusQnt],
					[biPrice],
					[biUnitPrice],
					[biUnitDiscount],
					[biUnitExtra],
					([BiExtra] * [btExtraAffectCost]) - ([btDiscAffectCost] * [BiDiscount]),
					[buDirection],
					[btAffectLastPrice],
					[btAffectCostPrice],
					[btAffectProfit],
					[btDiscAffectCost],
					[btExtraAffectCost],
					[btDiscAffectProfit],
					[btExtraAffectProfit],
					[btBillType],
					bi.[mtType],
					bi.[biLCDisc],
					bi.[biLCExtra],
					bi.[buIsPosted]
				FROM
					[dbo].[vwExtended_bi] bi
					INNER JOIN [#BillsTypesTbl_AVG] bt ON bt.[TypeGuid] = bi.buType 
				WHERE 
					bi.[buIsPosted] != 0 
					OR 
					bi.btAffectProfit != 0
				ORDER BY
					[biMatPtr], [buDate], [bt].[PriorityNum], [bt].[SortNumber], [bi].[buNumber], [bt].[SamePriorityOrder], [biNumber]

		OPEN @c_bi FETCH FROM @c_bi INTO
			@buGUID, @buDate, @biGUID, @biMatPtr, @biUnity, @biQty, @biQty2, @biQty3, @biBonusQnt, @biPrice, @biUnitPrice, @biUnitDiscount, @biUnitExtra,
			@biDiscExtra, @buDirection, @btAffectLastPrice, @btAffectCostPrice, @btAffectProfit, @btDiscountAffectCostPrice, @btExtraAffectCostPrice, 
			@btDiscountAffectProfit, @btExtraAffectProfit, @btBillType, @mtType, @biLCDisc, @biLCExtra, @BuIsposted

		-- start @c_bi loop
		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- is this a new material ?
			IF @mtGUID <> @biMatPtr
			BEGIN
				-- update mt statistics:
				UPDATE mt000 
				SET
					[AvgPrice] =	ISNULL(@mtAvgPrice, 0),
					[MaxPrice] =	ISNULL(@mtMaxPrice, 0),
					[MaxPrice2] =	ISNULL(@mtMaxPrice * @mtUnit2Fact, 0),
					[MaxPrice3] =	ISNULL(@mtMaxPrice * @mtUnit3Fact, 0)
				WHERE 
					[GUID] = @mtGUID

				-- reset mt variables:
				SELECT
					@mtGUID =		[GUID],
					@mtQnt =		0,
					@mtAvgPrice =	0,
					@mtMaxPrice =	0,
					@bNeg =			0,
					@mtUnit2Fact =	[Unit2Fact],
					@mtUnit3Fact =	[Unit3Fact]
				FROM
					[mt000]
				WHERE
					[GUID] = @biMatPtr
			END

			SET @UnityFactor = CASE @biUnity WHEN 2 THEN @mtUnit2Fact WHEN 3 THEN @mtUnit3Fact ELSE 1 END

			-- check for division by zero:
			IF @UnityFactor = 0 SET @UnityFactor = 1

			IF @btAffectCostPrice = 0
				SET @mtQnt = @mtQnt + @buDirection * (@biQty + @biBonusQnt)
			ELSE
			BEGIN
				IF @mtQnt > 0
				BEGIN
					IF ( @biQty > 0)
						SET @mtValue = @mtAvgPrice * @mtQnt +  (@buDirection * @biQty * (@biUnitPrice + @biUnitExtra * @btExtraAffectCostPrice - @biUnitDiscount * @btDiscountAffectCostPrice))
					ELSE IF ( @biQty = 0)
						SET @mtValue = @mtAvgPrice * @mtQnt + (@buDirection * @biDiscExtra)
				END
				ELSE
					IF @buDirection = 1 
					BEGIN
						IF ( @biQty > 0)
							SET @mtValue = @biQty * (@biUnitPrice + @biUnitExtra * @btExtraAffectCostPrice - @biUnitDiscount * @btDiscountAffectCostPrice)	
						ELSE IF ( @biQty = 0)
							SET @mtValue =  (@buDirection * @biDiscExtra)	
					END
				IF @mtQnt < 0
					set @bNeg = 1
				ELSE
					set @bNeg = 0
				SET @mtQnt = @mtQnt + @buDirection * (@biQty + @biBonusQnt)
				SET @mtValue = @mtValue + @biLCExtra - @biLCDisc
				IF @mtValue > 0  
				BEGIN
					IF ( @mtQnt > 0) AND @bNeg = 0
						SET @mtAvgPrice = @mtValue / @mtQnt
					ELSE IF (@biQty	 > 0) AND (@buDirection = 1) 
					BEGIN
						IF (@biQty + @biBonusQnt) > 0
							SET @mtAvgPrice = (@biLCExtra - @biLCDisc + (@biQty * (@biUnitPrice + @biUnitExtra * @btExtraAffectCostPrice - @biUnitDiscount * @btDiscountAffectCostPrice)))/(@biQty + @biBonusQnt) 
					END
				END
				ELSE
				BEGIN
					IF (@biQty + @biBonusQnt) > 0
						SET @mtAvgPrice = (@biLCExtra - @biLCDisc + (@biQty * (@biUnitPrice + @biUnitExtra * @btExtraAffectCostPrice - @biUnitDiscount * @btDiscountAffectCostPrice)))/(@biQty + @biBonusQnt) 
			
					END
					SET @mtValue = 0
				END

			-- report error:
 			IF @hushed = 0 AND @mtQnt < - @zeroQ AND @buDirection = -1 AND @mtType <> 1 
				INSERT INTO [ErrorLog] ([Type], [g1], [f1], [g2]) VALUES (0x409, @buGUID, @mtQnt, @biMatPtr)

			-- update mt last price flag, if necessary:
			IF @btAffectLastPrice <> 0 AND @BuIsposted != 0 -- c_bi is sorted by date:
			BEGIN
				-- set maxprice:
				IF @mtMaxPrice < @biUnitPrice
					SET @mtMaxPrice = @biUnitPrice
			END

			-- put bi000 profits:
			UPDATE [bi000] 
			SET
				[Profits] =			[dbo].[fnGetProfit](@biQty, @biBonusQnt, @mtAvgPrice, @biUnitPrice, @biUnitExtra, @biUnitDiscount, @btExtraAffectProfit, @btDiscountAffectProfit),
				[UnitCostPrice] =	ISNULL(@mtAvgPrice, 0)
			WHERE [GUID] = @biGUID
			
			FETCH FROM @c_bi INTO
				@buGUID, @buDate, @biGUID, @biMatPtr, @biUnity, @biQty, @biQty2, @biQty3, @biBonusQnt, @biPrice, @biUnitPrice, @biUnitDiscount, @biUnitExtra, @biDiscExtra,
				@buDirection, @btAffectLastPrice, @btAffectCostPrice, @btAffectProfit, @btDiscountAffectCostPrice, @btExtraAffectCostPrice, @btDiscountAffectProfit, 
				@btExtraAffectProfit, @btBillType, @mtType, @biLCDisc, @biLCExtra, @BuIsposted
		END CLOSE @c_bi DEALLOCATE @c_bi    

		-- update the last mt statistics:
		IF ISNULL(@mtGUID, 0x0) != 0x0
		BEGIN 
			UPDATE mt000 
			SET
				[AvgPrice] =	ISNULL(@mtAvgPrice, 0),
				[MaxPrice] =	ISNULL(@mtMaxPrice, 0),
				[MaxPrice2] =	ISNULL(@mtMaxPrice * @mtUnit2Fact, 0),
				[MaxPrice3] =	ISNULL(@mtMaxPrice * @mtUnit3Fact, 0)
			WHERE 
				[GUID] = @mtGUID
		END 

		-- update bu000 profits:
		UPDATE [bu000]
		SET [Profits] =		(SELECT Sum([Profits]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu000].[GUID])
		FROM [bu000]
	END 
	-------------------------
	IF ISNULL(@IsCalcLastPrice, 1) = 1
		EXEC prcLP_Recalc @IgnoreLastPriceAndCost, 0 /*@DisableTriggers*/
	-------------------------
	-- insert ms statistics:
	IF ISNULL(@IsCalcQty, 1) = 1
	BEGIN
		TRUNCATE TABLE [ms000]
	
		INSERT INTO [ms000] ([StoreGUID], [MatGUID], [Qty])
		SELECT st.GUID StoreGUID, mt.GUID MatGUID, SUM((CASE bt.bIsInput WHEN 1 THEN 1 ELSE -1 END) * (bi.Qty + bi.BonusQnt))
		FROM 
			bi000 bi
			INNER JOIN bu000 bu on bu.guid = bi.ParentGUID
			INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
			INNER JOIN mt000 mt on mt.guid = bi.MatGUID
			INNER JOIN st000 st on st.guid = bi.StoreGUID
		WHERE bu.IsPosted <> 0
		GROUP BY st.GUID, mt.GUID

		UPDATE mt000 SET [Qty] = 0 WHERE [Qty] != 0

		UPDATE mt  
		SET [Qty] = ISNULL(biMt.Qty, 0)
		FROM
			[mt000] AS mt
			CROSS APPLY (
				SELECT SUM((CASE bt.bIsInput WHEN 1 THEN 1 ELSE -1 END) * (bi.Qty + bi.BonusQnt)) AS Qty 
				FROM 
					bi000 bi 
					INNER JOIN bu000 bu ON bu.GUID = bi.ParentGUID
					INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
				WHERE bu.IsPosted = 1 AND bi.MatGUID = mt.GUID) AS biMt 

		-- update parent of compostion materials	
		UPDATE mtParent
		SET mtParent.[Qty] = compostionMats.sumQty
		FROM mt000 AS mtParent 
		INNER JOIN
			(
				SELECT 
					SUM(Qty) sumQty,
					Parent
				FROM mt000
				WHERE Parent IS NOT NULL AND Parent <> 0x0
				GROUP BY Parent 
			) compostionMats
			ON compostionMats.Parent = mtParent.GUID
		WHERE mtParent.HasSegments = 1

		-- repost SNs:
		;WITH SnQty AS 
		(
			SELECT 
				SC.Guid, 
				SUM(ISNULL([buDirection], 0)) AS Qty 
			FROM 
				[snc000] SC 
				LEFT JOIN (
					SELECT a.[ParentGuid], [buDirection] 
					FROM 
						[SNT000] a 
						INNER JOIN  [vwbu] [bi]  ON bi.buGuid = a.buGuid
				) st ON st.[ParentGuid] = sc.[Guid]
			GROUP BY SC.Guid
		)

		UPDATE [sn] SET 
		Qty = b.Qty 
		FROM 
			snc000 sn 
			INNER JOIN SnQty b ON sn.Guid = b.Guid
	END 

	-- recalc customer prices:
	IF ISNULL(@IsCalcCP, 1) = 1
		EXEC prcCP_Recalc

	-- remove the mc recalculation necessaty flag:
	IF @IsCalcAvgPrice = 1
		EXEC [prcFlag_reset] 100

	IF @IsCalcAvgPrice = 1
	BEGIN
		EXEC prcEnableTriggers 'bi000'
		EXEC prcEnableTriggers 'bu000'
	END
	IF @IsCalcQty = 1
	BEGIN 
		EXEC prcEnableTriggers 'ms000'
		EXEC prcEnableTriggers 'snc000'
	END 
	EXEC prcEnableTriggers 'mt000'

	IF @hushed = 0
	BEGIN
		INSERT INTO MaintenanceLogItem000 (GUID, ParentGUID, Severity, LogTime, ErrorSourceGUID1, ErrorSourceType1, ErrorSourceGUID2, ErrorSourceType2, Notes)
		SELECT NEWID(), @LgGuid, 3, GETDATE(), [g1], 0X010010000, [g2], 0X010019000, 'Neg out Quantity:' + CAST([f1] AS NVARCHAR(100))
		FROM [ErrorLog]

		IF @IsCalcAvgPrice = 1 OR @IsCalcQty = 1
		BEGIN
			SELECT * 
			INTO #MI 
			FROM
			(
				SELECT 
					NEWID() GUID,
					@LgGuid ParentGUID,
					2 Severity,
					GETDATE() LogTime,
					mt.Guid ErrorSourceGUID1,
					CAST(0x10019000 AS INT) ErrorSourceType1,
					CAST(0x00 AS UNIQUEIDENTIFIER) ErrorSourceGUID2,
					0 ErrorSourceType2,
					mt.Code + '-' + mt.Name 
						+ CASE WHEN ABS(mt.qty - m.Qty) > @zeroQ THEN 'qty ' + CAST(mt.qty AS  NVARCHAR(100)) + ':' + CAST(m.qty AS  NVARCHAR(100)) ELSE '' END 
						+ CASE WHEN ABS(mt.avgPrice - m.avgPrice) > @zeroP THEN 'avgPrice ' + CAST(mt.qty AS  NVARCHAR(100)) + ':' + CAST(m.qty AS  NVARCHAR(100)) ELSE '' END Notes
				FROM 
					mt000 mt 
					INNER JOIN #mt m ON m.Guid = mt.Guid 
				WHERE ABS(mt.qty - m.Qty) > @zeroQ OR ABS(mt.avgPrice - m.avgPrice) > @zeroP
		
				UNION ALL
		
				SELECT 
					NEWID(),
					@LgGuid,
					2,
					GETDATE(),
					mt.Guid,
					0x10019000,
					st.Guid,
					0x1001D000,
					mt.Code + '-' + mt.Name + '  ' + st.Code + '-' + st.Name  
						+ ' qty ' + CAST(mt.qty AS NVARCHAR(100)) + ':' + CAST(m.qty AS NVARCHAR(100))  
				FROM 
					mt000 mt 
					INNER JOIN #ms m ON m.MatGuid = mt.Guid 
					INNER JOIN st000 st ON st.Guid = m.StoreGuid 
					LEFT JOIN ms000 ms ON CAST(m.MatGuid AS NVARCHAR(36)) + CAST(m.StoreGuid AS NVARCHAR(36)) = CAST(ms.MatGuid AS NVARCHAR(36)) + CAST(ms.StoreGuid AS NVARCHAR(36)) 
				WHERE ABS(ms.qty - m.Qty) > @zeroQ  
			) A

			INSERT INTO MaintenanceLogItem000 (GUID, ParentGUID, Severity, LogTime, ErrorSourceGUID1, ErrorSourceType1, ErrorSourceGUID2, ErrorSourceType2, Notes) 
			SELECT GUID, ParentGUID, Severity, LogTime, ErrorSourceGUID1, ErrorSourceType1, ErrorSourceGUID2, ErrorSourceType2, Notes FROM #mi
		END
	END
	
	EXEC prcCloseMaintenanceLog @LgGuid

	-- return ErrorLog:
	IF @hushed = 0 AND [dbo].[fnObjectExists]('ErrorLog') <> 0
		SELECT * FROM [ErrorLog]
#########################################################
CREATE PROCEDURE prcBondCarryover 
	@BondSrc [UNIQUEIDENTIFIER], 
	@BillSrc [UNIQUEIDENTIFIER],
	@NoteSrc [UNIQUEIDENTIFIER], 
	@StartDate [DATETIME],  
	@EndDate [DATETIME]  
	
AS 
	SET NOCOUNT ON  
	DECLARE 
		@UserGUID		[UNIQUEIDENTIFIER]
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]() 

	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT]) 
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @BondSrc, @UserGUID 

	CREATE TABLE [#CheckTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])  
	INSERT INTO [#CheckTbl] EXEC [prcGetEntriesTypesList] @NoteSrc, @UserGUID  

	CREATE TABLE [#Src]( [Type] [UNIQUEIDENTIFIER], [Sec] [INT], [ReadPrice] [INT])    
	INSERT INTO [#Src] EXEC [prcGetBillsTypesList]	@BillSrc

	CREATE TABLE [#Ce]( [CeGuid] [UNIQUEIDENTIFIER],[parentGuid] [UNIQUEIDENTIFIER],[parentTypeGuid] [UNIQUEIDENTIFIER])
	CREATE TABLE [#CeErr]( [CeGuid] [UNIQUEIDENTIFIER],[parentGuid] [UNIQUEIDENTIFIER],[parentTypeGuid] [UNIQUEIDENTIFIER])

	-----------------------bu000-----------------------------------------------------
	INSERT INTO [#Ce]
	SELECT [f].[Guid],[bu].[Guid],[bu].[TypeGuid]  
	FROM	
				ce000 AS [f] 
				INNER JOIN [vwEr] AS [er] ON [f].[Guid] = [er].[erEntryGuid] 
				INNER JOIN [bu000] AS [bu] ON [er].[erParentGuid] = [bu].[Guid] 
				INNER JOIN [#Src] AS [t] ON [bu].[TypeGuid] = [t].[Type]
	WHERE [f].IsPosted = 0 AND [f].Date BETWEEN @StartDate AND @EndDate 
	-------------------------py000------------------------------------------------------------
	INSERT INTO [#Ce]
	SELECT [f].[Guid],[py].[Guid],[py].[TypeGuid]  
	FROM	
				ce000 AS [f] 
				INNER JOIN [vwEr] AS [er] ON [f].[Guid] = [er].[erEntryGuid] 
				INNER JOIN [Py000] AS [py] ON [er].[erParentGuid] = [py].[Guid] 
				INNER JOIN [#EntryTbl] AS [t] ON [py].[TypeGuid] = [t].[Type]
	WHERE [f].[IsPosted] = 0 AND [f].Date BETWEEN @StartDate AND @EndDate
	-------------------------ch000------------------------------------------------------------ 
	INSERT INTO [#Ce] 
	SELECT [f].[Guid],[ch].[Guid],[ch].[TypeGuid]   
	FROM	 
				ce000 AS [f]  
				INNER JOIN [vwEr] AS [er] ON [f].[Guid] = [er].[erEntryGuid]  
				INNER JOIN [ch000] AS [ch] ON [er].[erParentGuid] = [ch].[Guid]  
				INNER JOIN [#CheckTbl] AS [t] ON [ch].[TypeGuid] = [t].[Type] 
	WHERE [f].[IsPosted] = 0 AND [f].Date BETWEEN @StartDate AND @EndDate   
	-----------------------free Ce000---------------------------
	IF EXISTS (SELECT TYPE  FROM [#EntryTbl] WHERE TYPE = 0x0)
	BEGIN
		INSERT INTO [#Ce]
		SELECT [f].[Guid], 0x0, 0x0 
		FROM	
				ce000 AS [f] 
		WHERE [f].[IsPosted] = 0 AND [f].[TypeGUID] = 0x0 AND  [f].Date BETWEEN @StartDate AND @EndDate 
	END
	-----------------------------------------------------
	DECLARE @CeGuid [UNIQUEIDENTIFIER],
			@parentGuid [UNIQUEIDENTIFIER],
			@parentTypeGuid [UNIQUEIDENTIFIER]			


	DECLARE BondsCrryover_cursor CURSOR FOR  
		SELECT  [CeGuid],[parentGuid],[parentTypeGuid]
		FROM  [#Ce]

	OPEN BondsCrryover_cursor  
	FETCH NEXT FROM BondsCrryover_cursor INTO @CeGuid , @parentTypeGuid, @parentTypeGuid

	WHILE @@FETCH_STATUS = 0  
	BEGIN  
			EXEC [dbo].[prcEntry_Post1] @CeGuid,1  
			EXEC[dbo].[prcEntry_post] @CeGuid,1
			UPDATE [ce000] SET [PostDate] = GETDATE() WHERE [guid] = @ceGUID
		   FETCH NEXT FROM BondsCrryover_cursor  INTO @CeGuid , @parentTypeGuid, @parentTypeGuid 
	END  

	CLOSE BondsCrryover_cursor   
	DEALLOCATE BondsCrryover_cursor 


#########################################################
#END