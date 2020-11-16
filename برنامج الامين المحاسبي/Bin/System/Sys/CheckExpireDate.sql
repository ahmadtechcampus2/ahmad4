##################################################################################
CREATE PROCEDURE prcCheckExpireDate 
	@MatGUID 			[UNIQUEIDENTIFIER], 
	@GroupGUID 			[UNIQUEIDENTIFIER],
	@Store				[UNIQUEIDENTIFIER],
	@CondGuid			[UNIQUEIDENTIFIER],
	@LgGuid UNIQUEIDENTIFIER=0x0
AS 
	SET NOCOUNT ON  
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	CREATE TABLE [#StoreTbl]([StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT])
	
	INSERT INTO [#MatTbl]		EXEC [prcGetMatsList] 		@MatGUID, @GroupGUID, 0,@CondGuid 
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList] 	@Store
	
	DECLARE @Parms NVARCHAR(2000)
	

	SET @Parms = @Parms

				+ 'Store:' + ISNULL((SELECT Code + '-' + [Name] FROM ST000 WHERE  [Guid] = @Store),'')
				+ 'Material:' + ISNULL((SELECT Code + '-' + [Name] FROM mt000 WHERE  [Guid] = @MatGUID),'')
				+ 'Group:' + ISNULL((SELECT Code + '-' + [Name] FROM gr000 WHERE  [Guid] = @GroupGUID),'')
				
	--EXEC prcCreateMaintenanceLog 20,@LgGuid OUTPUT,@Parms 
	
	SELECT [MatGUID],[mtSecurity],Unit2Fact,Unit3Fact INTO [#MatTbl2]  FROM [#MatTbl] m INNER JOIN mt000 MT ON mt.GUID = m.MatGUID
	WHERE mt.ExpireFlag > 0
	CREATE TABLE #InResult 
	(
		MatGUID UNIQUEIDENTIFIER,
		StoreGuid UNIQUEIDENTIFIER,
		[buDate] DateTime,
		[ExpireDate] DateTime,
		Qty			FLOAT,
		Dir			INT
	)
	
	CREATE TABLE #OutResule
	(
		Id				INT IDENTITY(1,1),
		Id2				FLOAT,
		GUID			UNIQUEIDENTIFIER,
		Number			INT,
		buGuid			UNIQUEIDENTIFIER,
		MatGUID			UNIQUEIDENTIFIER,
		StoreGuid		UNIQUEIDENTIFIER,
		qty				FLOAT,
		Bonus			FLOAT,
		buDate			DATETIME,
		[expireDate]	DATETIME,
		unity			TINYINT,
		Price			FLOAT,
		discrate		FLOAT,
		bonusdiscrate		FLOAT,
		extrarate		FLOAT,
		FLAG BIT		DEFAULT 0
	)
	INSERT INTO #InResult (MatGUID,	StoreGuid,[ExpireDate],qty )
	SELECT biMatPtr,biStorePtr,biExpireDate,SUM((biQty + biBonusQnt) * buDirection) from vwBuBi 
	INNER JOIN [#MatTbl2] mt ON mt.[MatGUID] = biMatPtr
	INNER JOIN [#StoreTbl] st ON st.StoreGuid = biStorePtr
	WHERE buDirection = 1 OR (buDirection = -1 AND biExpireDate > '1/1/1980')
	GROUP BY biMatPtr,biStorePtr,biExpireDate,[buDate],buDirection

	
	INSERT INTO #OutResule(Guid,Number,buGuid,MatGUID,StoreGuid,qty,Bonus,[expireDate],unity,Price,discrate,bonusdiscrate,extrarate)
	SELECT biGUID,biNumber,buGUID,biMatPtr,biStorePtr,biQty,bibonusQnt,biExpireDate ,biunity,biPrice,CASE biPrice WHEN 0 THEN 0 ELSE  CASE biQty WHEN 0 THEN 0 ELSE biDiscount/(biPrice * biQty) END END, CASE WHEN biQty = 0 OR biPrice = 0 THEN 0 ELSE  biBonusDisc /(biPrice * biQty) END ,
	 CASE  WHEN  biQty = 0 OR biPrice = 0 THEN 0 ELSE  biBonusDisc /(biPrice * biQty) END	
	FROM vwBuBi bi
	INNER JOIN [#MatTbl2] mt ON mt.[MatGUID] = biMatPtr
	INNER JOIN [#StoreTbl] st ON st.StoreGuid = biStorePtr
	WHERE  buDirection = -1 AND biExpireDate = '1/1/1980' ORDER BY biMatPtr,buDate,buSortFlag,buNumber
	
	UPDATE #OutResule SET Id2 = id
	ALTER TABLE #OutResule DROP COLUMN ID


	
	DECLARE @c CURSOR,@MatPtr UNIQUEIDENTIFIER,@StoreGuid UNIQUEIDENTIFIER,@biQty FLOAT,@ExpireDate DATETIME,@Qty FLOAT,@ID FLOAT
	,@Qty2 FLOAT,@CurrMatPtr UNIQUEIDENTIFIER,@CurrStoreGuid UNIQUEIDENTIFIER,@Bonus FLOAT
	
	SET @c = CURSOR FAST_FORWARD FOR 
	SELECT MatGUID,	StoreGuid,[ExpireDate],SUM(qty) FROM #InResult 
	GROUP BY MatGUID,StoreGuid,[ExpireDate] 
	HAVING SUM(qty) > 0 ORDER BY MatGUID,	StoreGuid
	SET @CurrMatPtr = 0X00
	SET @CurrStoreGuid = 0X00
	OPEN @c FETCH NEXT FROM @c INTO @MatPtr,	@StoreGuid,@ExpireDate,@biQty
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF ((@CurrStoreGuid =@StoreGuid) AND (@CurrMatPtr = @MatPtr))
			GOTO LL
		SET @Qty = @biQty
		WHILE @Qty > 0
		BEGIN
			SET @ID = NULL
			SELECT @Qty2 = qty ,@ID = Id2,@Bonus = Bonus FROM #OutResule 
			WHERE Id2 = (SELECT MIN(ID2) FROM #OutResule  WHERE [ExpireDate] = '1/1/1980' AND MatGUID = @MatPtr AND StoreGuid = @StoreGuid)
	
			IF (@ID IS NULL)
			BEGIN
				SET @CurrStoreGuid = @StoreGuid
				SET @CurrMatPtr = @MatPtr
				GOTO LL
			END
			IF ((@Qty2 + @Bonus) <= @Qty)
			BEGIN
				UPDATE #OutResule SET [ExpireDate] = @ExpireDate WHERE Id2 = @ID
				SET @Qty = @Qty - (@Qty2 + @Bonus)
			END
			ELSE
			BEGIN
				UPDATE #OutResule SET qty = CASE WHEN (@Qty2 > @Qty - @Bonus) THEN @Qty - @Bonus ELSE @Qty END ,bonus =  CASE WHEN ( @Bonus < @Qty) THEN @Bonus  ELSE @Bonus - @Qty END ,[expireDate]  = @ExpireDate,FLAG = 1 WHERE Id2 = @ID
				IF (@Qty2  > @Qty - @Bonus)
					SET @Qty2 = @Qty2 -( @Qty - @Bonus)
				ELSE
					SET @Qty2 = @Qty2 - @Qty
				if ( @Bonus > @Qty)
					SET @Bonus = @Bonus - @Qty
				ELSE 
					SET @Bonus = 0	

				INSERT INTO #OutResule(Id2,GUID,Number,buGuid,MatGUID,StoreGuid,qty,[expireDate],Bonus,unity,FLAG,discrate,bonusdiscrate,extrarate,Price)			
				SELECT @ID + 0.000001,NEWID(),Number,buGuid,MatGUID,StoreGuid,@Qty2 ,'1/1/1980',@Bonus,unity,1,discrate,bonusdiscrate,extrarate,Price FROM #OutResule WHERE ID2 = @ID
				SET @Qty = 0
				
			END
		END
	
		LL: FETCH NEXT FROM @c INTO @MatPtr ,@StoreGuid,@ExpireDate ,@biQty  
	END
	CLOSE @c 
	DEALLOCATE @c
	EXEC prcDisableTriggers 'bi000'
	UPDATE bi SET 
	Qty = CASE [out].FLAG WHEN 0 THEN bi.Qty ELSE [out].qty END,
	BonusQnt = CASE [out].FLAG WHEN 0 THEN bi.BonusQnt ELSE [out].bonus END,
	Discount = CASE [out].FLAG WHEN 0 THEN bi.Discount ELSE [out].discrate *[out].Price *[out].qty   END,
	BonusDisc = CASE [out].FLAG WHEN 0 THEN bi.BonusDisc ELSE [out].bonusdiscrate *[out].Price *[out].qty   END,
	bi.Extra  = CASE [out].FLAG WHEN 0 THEN bi.Extra ELSE [out].extrarate *[out].Price *[out].qty   END,
	[ExpireDate] =  [out].[ExpireDate] FROM  bi000 bi INNER JOIN #OutResule [out] ON [out].GUID = bi.GUID 
	
	INSERT INTO bi000 (GUID,Number,Qty,ParentGUID,BonusQnt,Price,Discount,BonusDisc,Extra,[ExpireDate],MATGUID,STOREGUID,unity)
	SELECT [out].[GUID],[out].[Number], [out].qty,[out].buGuid,[out].bonus,[out].Price,[out].discrate *[out].Price *[out].qty,
	[out].bonusdiscrate *[out].Price *[out].qty, [out].extrarate *[out].Price *[out].qty  ,[out].[ExpireDate],[out].MatGUID,[out].STOREGUID,[out].unity
	FROM #OutResule [out] LEFT JOIN bi000 bi ON [out].GUID = bi.GUID WHERE bi.GUID IS NULL
	
	UPDATE bi SET CurrencyGUID = bu.CurrencyGUID 
	,CurrencyVal = bu.CurrencyVal 
	FROM bi000 bi INNER JOIN bu000 bu ON bu.GUID = bi.ParentGUID WHERE ISNULL(bi.CurrencyGUID,0X00) = 0x00  
	
	ALTER TABLE bi000 ENABLE  TRIGGER ALL
	INSERT INTO MaintenanceLogItem000 ( GUID, ParentGUID, Severity, LogTime, ErrorSourceGUID1, ErrorSourceType1, Notes)
	SELECT NEWID(), @LgGuid, 0x0001,GETDATE(),[out].[buGuid],268500992,bt.Name +':' +CAST(bu.Number AS NVARCHAR(10)) + 'mtName' + mt.Name + 'ExpireDate:' +CAST([out].[ExpireDate] AS NVARCHAR(10))   
	FROM #OutResule [out] INNER JOIN bu000 bu ON bu.GUID = buGuid 
	INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID 
	INNER JOIN mt000 mt ON mt.GUID = MatGUID
##################################################################################
#END