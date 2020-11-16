#########################################################
CREATE TRIGGER trg_bu000_CheckConstraints 
	ON [bu000] FOR INSERT, DELETE, UPDATE 
	NOT FOR REPLICATION

AS  
/*  
This trigger checks:  
	- not to insert posted records.		(AmnE0001) 
	- not to delete posted records.		(AmnE0002) 
	- not to use main stores.				(AmnE0003) 
	- not to use main CostJobs.			(AmnE0004) 
*/  
	IF @@ROWCOUNT = 0 RETURN  
	SET NOCOUNT ON  
	  
	-- study a case when inserting posted records:  
	IF EXISTS(SELECT * FROM [inserted] WHERE [IsPosted] = 1) AND NOT EXISTS(SELECT * FROM [deleted]) 
		insert into [ErrorLog] ([level], [type], [c1]) select 1, 0, 'AmnE0001: Can''t insert posted bills' 
/* 
	-- study a case when using main Stores (NSons <> 0): 
	IF EXISTS(SELECT * FROM [inserted] AS i INNER JOIN st000 AS s ON i.StoreGuid = s.Guid INNER JOIN st000 AS s2 ON s.Guid = s2.ParentGuid) 
		insert into [ErrorLog] (level, type, c1) select 1, 0, 'AmnE0003: Can''t use main stores' 
	-- study a case when using main CostJobs (NSons <> 0): 
	IF EXISTS(SELECT * FROM [inserted] AS i INNER JOIN co000 AS c ON i.StoreGuid = c.Guid INNER JOIN co000 AS c2 ON c.Guid = c2.ParentGuid) 
		insert into [ErrorLog] (level, type, c1) select 1, 0, 'AmnE0004: Can''t use main CostJobs' 
*/ 
	-- study a case when deleting posted records: 
	IF EXISTS(SELECT * FROM [deleted] WHERE [IsPosted] = 1) AND NOT EXISTS(SELECT * FROM [inserted]) 
		insert into [ErrorLog] ([level], [type], [c1]) select 1, 0, 'AmnE0002: Can''t delete posted bills' 

	--IF EXISTS(SELECT * FROM billRel000 b inner join [deleted] d on b.billGuid = d.guid)
	--	insert into [ErrorLog](level, type, c1) select 1, 0, 'AmnE0005: Can''t delete bill(s), master relation found.'
	
	-- check if the bill is generated from assemble bill.. if that's true then we can't delete it.
	IF EXISTS( SELECT * FROM [deleted] WHERE dbo.fnIsGenOfAssemBill( [guid]) != 0) AND NOT EXISTS( SELECT * FROM [inserted]) 
		insert into [ErrorLog] ([level], [type], [c1]) select 1, 0, 'AmnE1111: Can''t delete AssemGenBill.' 
#########################################################
CREATE TRIGGER trg_bu000_CheckConstraints_orders
	ON [bu000] FOR DELETE, UPDATE 
	NOT FOR REPLICATION

AS  
	IF @@ROWCOUNT = 0 RETURN  
	SET NOCOUNT ON  

	IF EXISTS (SELECT * FROM [inserted] [i] INNER JOIN [deleted] [d] ON [i].Guid = d.guid 
		INNER JOIN [OrAddInfo000] [or] ON [or].[ParentGUID] = [i].[GUID])
	BEGIN 
		-- Modify Partially Approved
		IF dbo.fnCurrentUser_CanDo(536965008/*20016F90*/, 0) = 0
		BEGIN 
			IF EXISTS (
				SELECT 
					*
				FROM 
					[inserted] [i] 
					INNER JOIN [deleted] [d] ON [i].Guid = d.guid 
					INNER JOIN [OrAddInfo000] [or] ON [or].[ParentGUID] = [i].[GUID]
				WHERE dbo.fnOrderApprovalState(i.Guid) = 1)
					INSERT INTO [ErrorLog] ([level], [type], [c1]) SELECT 1, 0, 'AmnE0060: don''t have permission to modify partially approved order(s)'
		END 
	END 
	IF EXISTS (SELECT * FROM [inserted] [i] RIGHT JOIN [deleted] [d] ON [i].Guid = d.guid 
		INNER JOIN [OrAddInfo000] [or] ON [or].[ParentGUID] = [d].[GUID] WHERE [i].[GUID] IS NULL)
	BEGIN 
		-- Delete Partially Approved
		IF dbo.fnCurrentUser_CanDo(536965009/*20016F91*/, 0) = 0
		BEGIN 
			IF EXISTS (
				SELECT 
					*
				FROM 
					[inserted] [i] 
					RIGHT JOIN [deleted] [d] ON [i].Guid = d.guid 
					INNER JOIN [OrAddInfo000] [or] ON [or].[ParentGUID] = [d].[GUID]
				WHERE dbo.fnOrderApprovalState(d.Guid) = 1 AND [i].[GUID] IS NULL)
					INSERT INTO [ErrorLog] ([level], [type], [c1]) SELECT 1, 0, 'AmnE0061: don''t have permission to delete partially approved order(s)'
		END 
	END 
#########################################################
CREATE TRIGGER trg_bu000_CheckConstraints_sn 
	ON bu000 FOR UPDATE 
	NOT FOR REPLICATION

AS  
/*  
This trigger checks rules of serial numbers:  
	- A material found having serial number(s), while it shouldn't. 					(AmnE0031)  
	- Trying to enter Serial Number(s), while found already existing in stock.		(AmnE0032)  
	- Bill item(s) found having Quantities not equal to Serial Numbers provided.	(AmnE0033)  
	- Bill item(s) found having Quantities less than Serial Numbers provided.		(AmnE0034)  
	- Trying to take out Serial Number(s), while not found in stock.				(AmnE0035)  
	- Serial Number(s) found duplicated in the same bill.							(AmnE0036)  
*/  
	IF @@ROWCOUNT = 0  
		RETURN   
	IF NOT EXISTS(SELECT 1 FROM snc000)
		RETURN  
	IF NOT UPDATE([IsPosted])  
		RETURN   
 
	DECLARE @DirFlag INT,@RowCnt INT,@OutQty INT,@buPosted BIT
	SET NOCOUNT ON 
	SET @OutQty = 0  
	DECLARE @Dir INT,@BuGuid UNIQUEIDENTIFIER,@IsPosted BIT,@TypeGuid UNIQUEIDENTIFIER 
	DECLARE @SN TABLE(
	--CREATE TABLE #Sn (  
		[SN] [NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[snGUID] [UNIQUEIDENTIFIER], 
		[biGUID] [UNIQUEIDENTIFIER], 
		[MatGUID] [UNIQUEIDENTIFIER], 
		[stGUID] [UNIQUEIDENTIFIER], 
		[biQty]	[FLOAT], 
		[SnFlag] [BIT], 
		[ForceInSn] [BIT], 
		[ForceOutSn] [BIT], 
		[bIsInput] [INT], 
		[buGUID] [UNIQUEIDENTIFIER], 
		[mtType] [INT],
		[IsPosted]	BIT
	) 
	CREATE TABLE #SNQTY 
	( 
		[SN]			[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		QTY				[FLOAT], 
		[ForceINSn]		[BIT], 
		[ForceOutSn]	[BIT], 
		[MatGuid] [UNIQUEIDENTIFIER] ,
		[stGuid]	[UNIQUEIDENTIFIER]
		
	) 
	CREATE TABLE  #PBU ([buGuid] [UNIQUEIDENTIFIER], [buType] [UNIQUEIDENTIFIER], [bIsInput] INT, [IsPosted] INT, [TypeGuid] [UNIQUEIDENTIFIER], btType INT)
	INSERT INTO #PBU SELECT [i].[GUID] AS [buGuid], [i].[TypeGuid] AS [buType] ,CASE [bIsInput] WHEN 1 THEN 1 ELSE -1 END AS [bIsInput],[i].[IsPosted],[i].[TypeGuid],bt.Type btType  
	FROM [inserted] AS [i] INNER JOIN [deleted] AS [d] ON [i].[GUID] = [d].[GUID]   
	INNER JOIN [bt000] [bt] ON  [i].[TypeGuid] = [bt].[Guid] 
	WHERE [i].[IsPosted] <> [d].[IsPosted] 
	SET @RowCnt = @@ROWCOUNT
	
	IF @RowCnt = 1 
	BEGIN
		SELECT @BuGuid = [buGuid],@Dir = [bIsInput],@IsPosted = [IsPosted] ,@TypeGuid = [TypeGuid]   FROM #PBU 
		--IF EXISTS(SELECT * FROM bt000 WHERE GUID = @TypeGuid AND (Type = 3 OR TYPE = 4))
		--	SET @TRNType = 1
	END
	ELSE 
		SET @BuGuid = 0X00 
	IF EXISTS(SELECT * FROM  #PBU WHERE [IsPosted] > 0)
		SET @buPosted = 1
	ELSE
		SET @buPosted = 0
	CREATE CLUSTERED INDEX pbuind ON #PBU([buGuid])  
	SET @DirFlag = 0
	IF EXISTS (SELECT * FROM #PBU WHERE [bIsInput] = 1)
		SET @DirFlag = @DirFlag | 0X0001
	IF EXISTS (SELECT * FROM #PBU WHERE [bIsInput] = -1)
		SET @DirFlag = @DirFlag | 0X0002
	IF @RowCnt = 2 AND EXISTS (SELECT * FROM #PBU a INNER JOIN [TS000] ON [buGuid] = [OutBillGuid] WHERE isPosted = 0) AND EXISTS (SELECT * FROM #PBU a INNER JOIN [TS000] ON [buGuid] = [InBillGuid] WHERE isPosted = 0)
		SET @OutQty = 1	
	IF exists(select * from #PBU where [isposted] = 0) 
	BEGIN 
		IF @BuGuid = 0X00 
		BEGIN
			UPDATE [c] set [qty] = [c].[Qty] - [bIsInput]  from (SELECT ParentGUID,[bIsInput] from #PBU P INNER JOIN [snT000]  [Sn]  ON P.[buGuid] = [Sn].[buGuid] where [isposted] = 0) s INNER JOIN [snc000] [c] ON s.ParentGUID = c.Guid 
		END
		ELSE 
			UPDATE [c] set [qty] = [c].[Qty] - @Dir  from [SNT000] s INNER JOIN [snc000] [c] ON s.ParentGUID = c.Guid WHERE S.[buGuid] = @BuGuid 
	END 
	 
	CREATE TABLE #MTSN
	(
		[biGuid]		UNIQUEIDENTIFIER,
		QTY				[FLOAT],
		[SnFlag]		[Bit], 
		[ForceINSn]		[BIT], 
		[ForceOutSn]	[BIT], 
		[MatGuid]		[UNIQUEIDENTIFIER],
		[StoreGuid]		[UNIQUEIDENTIFIER],
		[isPosted]		 INT,
		[bIsInput]		INT,
		[Type]			INT
	)
	IF @BuGuid = 0X00 
		INSERT INTO #MTSN
		SELECT [bi].[Guid] ,bi.Qty + bi.BonusQnt,
			mt.[SnFlag],	
			mt.[ForceINSn],	
			mt.[ForceOutSn],
			bi.[MatGuid],
			bi.[StoreGuid],
			[bu].[isPosted],
			[bu].[bIsInput],[Type]
		FROM
			[bi000] [bi] 
			INNER JOIN #PBU  [bu] ON [bi].[ParentGuid] = [bu].[buGuid] 
			INNER JOIN [mt000] [mt] ON [mt].[Guid] = [bi].[MatGuid]
		--WHERE [SnFlag] > 0 
	ELSE
		INSERT INTO #MTSN
		SELECT [bi].[Guid] ,bi.Qty ,
		[SnFlag],	
		[ForceINSn],
		[ForceOutSn],
		[MatGuid],
		[StoreGuid],
		@IsPosted,@Dir,[Type]
	FROM
			(SELECT Guid,[Qty] + BonusQnt [Qty],[StoreGuid],[MatGuid]  FROM [bi000] where parentguid = @BuGuid) [bi] 
			INNER JOIN [mt000] [mt] ON [mt].[Guid] = [MatGuid] 
			--WHERE  [SnFlag] > 0 
	
	INSERT INTO [ErrorLog] ([level], [type], [c1], [g1]) select 1, 0, 'AmnE0031: Material(s) found having serial number(s), while it shouldn''t', a.[biGuid] FROM #MTSN a INNER JOIN snt000 s ON s.biGuid = a.[biGuid] WHERE [SNFlag] = 0  
	
	DELETE #MTSN WHERE [SnFlag] = 0 
	IF (select count(*) FROM #MTSN) = 0
		RETURN

	IF @BuGuid = 0X00 
	BEGIN 
		INSERT INTO @SN  
			SELECT [SN],[snc].[Guid],[bi].[biGuid],[snc].[MatGuid],[bi].[StoreGuid],[bi].[Qty],[SnFlag],[ForceInSn],[ForceOutSn],[bIsInput],[SNT].[buGuid],[Type],
			[IsPosted]
			FROM [SNC000] [snc]	 
			INNER JOIN [SNT000] [snt] ON [snt].[ParentGuid] = [snc].[Guid] 
			INNER JOIN #MTSN [bi] ON [snt].[biGuid] = [bi].[biGuid]

	END  
	ELSE 
	BEGIN 
		INSERT INTO @SN  
		SELECT [SN],[snc].[Guid],[bi].[biGuid],[snc].[MatGuid],[bi].[StoreGuid],[bi].[Qty],[SnFlag],[ForceInSn],[ForceOutSn],@Dir,@BuGuid,[Type] 
			,@IsPosted
			FROM (SELECT * FROM [SNT000] WHERE [buGuid] = @BuGuid) [snt]  
			INNER JOIN [SNC000] [snc]	 ON [snt].[ParentGuid] = [snc].[Guid] 
			INNER JOIN #MTSN [bi] ON [snt].[biGuid] = [bi].[biGuid]

	END 
	
	--CREATE  clustered INDEX SNIND ON #Sn([SNGUID],[SN],[MatGuid],[buGuid]) 
	
	INSERT INTO #SNQTY 
	SELECT [SN],SUM([dir]),[ForceINSn],[ForceOutSn],[MatGuid],[stGuid]
	FROM
		[snt000] [SN] INNER JOIN (
							SELECT SNGuid,[ForceInSn],[ForceOutSn],SN,MatGuid
								FROM @SN
							GROUP BY SNGuid,[ForceInSn],[ForceOutSn],SN,MatGuid
						) [S]	ON [S].SNGuid = [SN].[ParentGuid]
		INNER JOIN (
				SELECT CASE [BT].[bIsInput] WHEN 1 THEN 1 ELSE -1 END AS [dir] ,bu.guid 
					FROM bu000 bu
						INNER JOIN BT000 BT ON bu.typeGuid  = bt.Guid
					WHERE [Isposted] = 1
		) [B] ON [B].Guid = [SN].buGuid
	WHERE ([ForceINSn] = 1 OR [ForceOutSn] = 1)-- AND [SN].[stGuid] =  [s].[stGuid]    
	GROUP BY [SN],[ForceINSn],[ForceOutSn],[MatGuid],[stGuid]
	--HAVING @BuGuid = 0x00 OR ((SUM([dir]) > 1) AND (@Dir = 1)) OR (@Dir = -1) 


	INSERT INTO [ErrorLog] ([level], [type], [c1], [c2]) 
		SELECT 1, 0, 'AmnE0032: Trying to enter Serial Number(s), while found already existing in stock[' + [SN] +']',  [SN]  
			FROM #SNQTY 
			WHERE [ForceOutSn] = 1  AND ((@DirFlag & 0x0001) >0 OR @buPosted = 1)
		GROUP BY [SN],[MatGuid]
		HAVING sum([QTY])> 1 
	UNION ALL 
		SELECT 1, 0, 'AmnE0035: [' + [Sn] + '] Trying to take out Serial Number(s), while not found in stock ' + CAST([QTY] AS VARCHAR), [Sn]  
		FROM #SNQTY T
		WHERE ForceOutSN = 1 AND ForceInSN = 1 AND ((@DirFlag & 0x0002) > 0 OR @buPosted = 1) AND (-[QTY])> @OutQty--CASE @TRNType WHEN 0 THEN 0 ELSE 1 END
		--AND EXISTS(SELECT * FROM SNC000 S WHERE S.MatGUID = T.MatGuid AND T.SN = S.SN)


	IF @BuGuid = 0X00 
		UPDATE [c] set [qty] = [c].[Qty] + [bIsInput] from [snc000] [c] INNER JOIN @SN s ON s.snGUID = c.Guid  WHERE IsPosted > @OutQty
	ELSE IF @IsPosted > 0
		UPDATE [c] set [qty] = [c].[Qty] + @Dir  from [SNT000] s INNER JOIN [snc000] [c] ON s.ParentGUID = c.Guid WHERE S.[buGuid] = @BuGuid  
	
	--SET ANSI_DEFAULTS OFF  -- Not available in Azure
	INSERT INTO [ErrorLog] ([level], [type], [c1], [g1]) 
			SELECT 1, 0, 'AmnE0033: Bill item(s) Quantities doen''t match serial numbers provided', A.biGuid 
			FROM #MTSN A LEFT JOIN SNT000 S ON S.biGUID = A.biGUID WHERE (( [bIsInput] = 1 AND [ForceInSn] = 1) OR ([bIsInput] = -1  AND [ForceOutSn] = 1) ) AND IsPosted > 0
			GROUP BY [Qty],A.[biGuid] HAVING ISNULL(COUNT(DISTINCT ISNULL(CAST(S.GUID AS NVARCHAR(36)), 0)),0) <> [Qty]  
			UNION ALL 
			SELECT 1, 0, 'AmnE0036: Serial Number(s) found duplicated in the same bill', [MatGuid]  FROM @SN WHERE IsPosted > 0 GROUP BY  [MatGuid],[sn],[buGuid] HAVING COUNT(*) > 1  
	--SET ANSI_DEFAULTS ON  
ENDF: 
#########################################################
CREATE TRIGGER trg_bu000_useFlag
	ON [dbo].[bu000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION

AS
/*
This trigger:
  - updates UseFlag of concerned accounts.
*/

	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON
	
	IF EXISTS(SELECT * FROM [deleted])
	BEGIN
		IF UPDATE([CustAccGUID])
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[CustAccGUID]
		IF UPDATE([MatAccGUID])
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[MatAccGUID]
	END
	
	IF EXISTS(SELECT * FROM [inserted])
	BEGIN
		IF UPDATE([CustAccGUID])
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[CustAccGUID]
		IF UPDATE([MatAccGUID])
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[MatAccGUID]
	END
	
#########################################################
CREATE TRIGGER trg_bu000_post
	ON [bu000] FOR UPDATE
	NOT FOR REPLICATION

AS
/*
This trigger:
	- handles the changes in IsPosted field
*/
	IF @@ROWCOUNT = 0 RETURN

	IF NOT UPDATE ([IsPosted]) RETURN
	
	SET NOCOUNT ON
	
	DECLARE
		@c			CURSOR,
		@GUID		[UNIQUEIDENTIFIER],
		@NewPost	[INT],
		@IsOutput	[BIT],
		@IsCheckForQtyByBranches [BIT]

	SET @IsCheckForQtyByBranches = 0
	IF	(dbo.fnOption_GetInt('AmnCfg_MatQtyByStore', '0') = 1) AND 
		(dbo.fnOption_GetInt('EnableBranches', '0') = 1)
	BEGIN 
		SET @IsCheckForQtyByBranches = 1
	END 

	SET @c = CURSOR FAST_FORWARD FOR
		SELECT [i].[GUID], [i].[IsPosted], bt.bIsOutput
		FROM 
			[inserted] AS [i] 
			INNER JOIN [deleted] AS [d] ON [i].[GUID] = [d].[GUID]
			INNER JOIN [bt000] bt ON bt.GUID = i.TypeGUID 
		WHERE [d].[IsPosted] <> [i].[IsPosted]

	OPEN @c FETCH FROM @c INTO @GUID, @NewPost, @IsOutput
	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC [prcBill_Post] @GUID, @NewPost
		EXEC [prcBillGenAssets] @GUID, @NewPost
		
		IF ((@IsCheckForQtyByBranches = 1) AND (@NewPost = 1) AND (@IsOutput = 1))
		BEGIN 
			DECLARE @isCalcPurchaseOrderRemindedQty BIT
			SELECT @isCalcPurchaseOrderRemindedQty = dbo.fnOption_GetInt('AmnCfg_CalcPurchaseOrderRemindedQty', '0')

			INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
			SELECT   
				2,   
				0,   
				'AmnW0062: ' + CAST([mt].[GUID] AS NVARCHAR(128)) + ' Product balance is less than zero, ' + dbo.fnMaterial_GetCodeName([mt].[GUID]), 
				[mt].[GUID]   
			FROM   
				[bu000] AS [bu] 
				INNER JOIN [bi000] AS [bi] ON [bu].[GUID] = [bi].[ParentGUID]
				INNER JOIN [mt000] AS [mt] ON [mt].[GUID] = [bi].[MatGUID]
				CROSS APPLY dbo.fnMat_GetQtyByBranch(mt.GUID, CASE bi.StoreGUID WHEN 0x0 THEN bu.StoreGUID ELSE bi.StoreGUID END, bu.Branch) fn
			WHERE 
				[bu].[GUID] = @GUID
				AND 
				[mt].[Type] <> 1 -- €Ì— Œœ„Ì…  
				AND 
				((fn.Bal + (CASE @isCalcPurchaseOrderRemindedQty 
								  WHEN 1 THEN [dbo].[fnGetPurchaseOrderRemaindedQty]([bi].[MatGUID], bi.StoreGUID, bu.Branch) 
								  ELSE 0 
						    END)) < -dbo.fnGetZeroValueQTY())
		END 

		FETCH FROM @c INTO @GUID, @NewPost, @IsOutput
	END -- @c loop

	CLOSE @c DEALLOCATE @c

#########################################################
CREATE TRIGGER trg_bu000_delete
	ON [bu000] FOR DELETE
	NOT FOR REPLICATION
AS
/* 
This trigger: 
	- deletes related records: bi, di, er, ce 
*/ 
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON 
	 
	-- deleting related data: 
	DELETE [ContractBillItems000] FROM 
		[ContractBillItems000] AS c 
		INNER JOIN [bi000] AS bi ON bi.Guid = c.BillItemGuid 
		INNER JOIN [deleted] AS bu ON bu.Guid = bi.ParentGuid
	DELETE [bi000] FROM [bi000] INNER JOIN [deleted] ON [bi000].[ParentGUID] = [deleted].[GUID]
	DELETE [di000] FROM [di000] INNER JOIN [deleted] ON [di000].[ParentGUID] = [deleted].[GUID] 
	DELETE [SNT000] FROM [SNT000] INNER JOIN [deleted] ON [SNT000].[BuGUID] = [deleted].[GUID] 
	DELETE  [billRelations000] FROM [billRelations000] INNER JOIN [deleted] ON [deleted].[GUID] =  [BillGuid] 
	DELETE  [billRelations000] FROM [billRelations000] INNER JOIN [deleted] ON [deleted].[GUID] =  [RelatedBillGuid]
	DELETE [LCRelatedExpense000] FROM [LCRelatedExpense000] INNER JOIN [deleted] ON [deleted].[GUID] = [ItemParentGUID]
	IF EXISTS(SELECT * FROM [rch000] r INNER JOIN [deleted] bu ON bu.GUID = r.ObjGUID)
		DELETE [rch000] FROM [rch000] r INNER JOIN [deleted] bu ON bu.GUID = r.ObjGUID 
	-- delete related Discount Card:
	--DELETE [DiscRel000] FROM [DiscRel000] [x] inner join [deleted] [d] on [x].[BillGuid] = [d].[guid]
	
	DECLARE 
		@c CURSOR, 
		@g [UNIQUEIDENTIFIER] 
	SET @c = CURSOR FAST_FORWARD FOR SELECT [GUID] FROM [deleted] 
	OPEN @c FETCH FROM @c INTO @g 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		EXEC [prcBill_DeleteEntry] @g 
		DELETE [ts000] WHERE [OutBillGUID] = @g OR [InBillGuid] = @g
		FETCH FROM @c INTO @g 
	END 
	 
	CLOSE @c DEALLOCATE @c 
#########################################################
CREATE TRIGGER trg_bu000_StopCustomer
	ON [bu000] FOR UPDATE
	NOT FOR REPLICATION

AS
/* 
This trigger: 
	- stops the customer which has late pays
*/ 
	IF @@ROWCOUNT = 0 
		RETURN 
		
	IF NOT UPDATE ([IsPosted]) 
		RETURN
	
	SET NOCOUNT ON 
	
	DECLARE @Value NVARCHAR(100)
	SET @Value = (SELECT [Value] FROM op000 WHERE [Name] = 'AmncfStopCustomer')
	DECLARE @Tbl_Cust TABLE(CustGUID UNIQUEIDENTIFIER)
	IF (@Value = '1') 
	BEGIN
		INSERT INTO @Tbl_Cust 
		SELECT 
			CustGuid 
		FROM 
			Inserted ins 
			INNER JOIN bt000 bt  ON bt.GUID = ins.TypeGUID 
		WHERE  
			CustGuid <> 0x0 
			AND bt.bIsOutput > 0 
			AND ins.isPosted > 0
			
		IF EXISTS(
				SELECT 
					bu.[Guid]
				FROM
					bu000 bu
					INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
					INNER JOIN pt000 pt ON pt.RefGUID = bu.[Guid]
					LEFT JOIN er000 er ON er.ParentGUID = bu.[GUID]
					INNER JOIN ce000 ce ON ce.[Guid] = entryGuid
					INNER JOIN en000 en ON en.parentguid = ce.GUID
					LEFT JOIN (SELECT SUM(Val) AS DebtVal, DebtGUID FROM bp000 GROUP BY DebtGUID) Dbp ON Dbp.DebtGUID = bu.GUID
					LEFT JOIN (SELECT SUM(Val) AS PayVal, PayGUID FROM bp000 GROUP BY PayGUID) Pbp ON Pbp.PayGUID = bu.GUID
					INNER JOIN ac000 ac ON ac.GUID = en.AccountGUID
					INNER JOIN cu000 cu ON ac.GUID = cu.AccountGUID
					INNER JOIN @Tbl_Cust t_cust ON t_cust.CustGUID = cu.GUID
				WHERE 
					bt.bIsOutput > 0 
					AND bu.PayType = 1 
					AND bu.IsPosted > 0
					AND bu.Total + bu.TotalExtra - bu.TotalDisc  + (CASE bt.VatSystem WHEN 2 THEN 0 ELSE bu.Vat END) - (ISNULL(Dbp.DebtVal, 0) + ISNULL(Pbp.PayVal, 0)) > 0.9
					AND dbo.fnGetDateFromTime(pt.DueDate) < dbo.fnGetDateFromTime(GETDATE())
				UNION ALL 
				SELECT -- ·„⁄«·Ã… «·«” Õﬁ«ﬁ«  ›Ì „·› „œÊ— Ê ›⁄Ì· ŒÌ«— «” Õﬁ«ﬁ «·›Ê« Ì— «À‰«¡ «· œÊÌ—
					ce.[Guid]
				FROM 
					ce000 AS ce
					INNER JOIN pt000 pt ON pt.RefGUID = ce.[Guid]
					LEFT JOIN er000 er ON er.ParentGUID = ce.[Guid]
					INNER JOIN ce000 ce1 ON ce1.[Guid] = entryGuid
					INNER JOIN en000 en ON en.parentguid = ce1.GUID
					LEFT JOIN (SELECT SUM(Val) AS Val, DebtGUID FROM bp000 GROUP BY DebtGUID) bp ON bp.DebtGUID = en.GUID
					INNER JOIN ac000 ac ON ac.GUID = en.AccountGUID
					INNER JOIN cu000 cu ON ac.GUID = cu.AccountGUID
					INNER JOIN @Tbl_Cust t_cust ON t_cust.CustGUID = cu.GUID
				WHERE
					en.Debit - ISNULL(bp.Val,0) > 0.9
					AND dbo.fnGetDateFromTime(pt.DueDate) < dbo.fnGetDateFromTime(GETDATE())
			)
				INSERT INTO [ErrorLog] ([level], [type], [c1]) SELECT 2, 0, 'AmnE0039: Customer was stopped because he has pay''s' 
	END
#########################################################
CREATE TRIGGER trg_bu000_CheckConstraintsExpireDate
	ON [dbo].[bu000] FOR UPDATE  
	NOT FOR REPLICATION

AS   
/*   
This trigger checks rules of ExpireDate:   
	processes the expire when posting 
	it prohibits when entering if forceinexpire and expire = '1/1/1980' the error raised 
	when out if forceoutexpire and expire doesnt exists the error raised 
*/ 
	IF @@ROWCOUNT = 0   
		RETURN    
	SET NOCOUNT ON
	  
	IF NOT UPDATE([IsPosted])   
		RETURN

	IF NOT EXISTS(SELECT * FROM mt000 WHERE ExpireFlag > 0 AND (ForceInExpire > 0 OR ForceOutExpire >0))
		RETURN 

	DECLARE @Inserted TABLE(
		[Guid] UNIQUEIDENTIFIER,
		[Dir] INT)

	INSERT @Inserted 
	SELECT 
		i.Guid,
		CASE bt.bisInput 
			WHEN 1 THEN 1 
			ELSE -1 
		END 
	FROM 
		inserted i 
		INNER JOIN bt000 bt ON bt.Guid = i.TypeGuid 
	WHERE 
		i.IsPosted > 0

	IF @@ROWCOUNT = 0   
		RETURN 

	DECLARE @bi TABLE(
		mtName NVARCHAR(255),
		MatGUID UNIQUEIDENTIFIER, 
		[ExpireDate] DATETIME,
		Qty FLOAT,
		Store UNIQUEIDENTIFIER,
		Direction INT)

	INSERT INTO @bi
	SELECT 
		mt.Name, 
		MatGUID,
		[ExpireDate], 
		bi.Qty, 
		bi.StoreGUID,
		Dir
	FROM 
		bi000 bi  
		INNER JOIN @Inserted i ON i.Guid = bi.ParentGUID 
		INNER JOIN mt000 mt ON mt.GUID = bi.MatGUID
		INNER JOIN bu000 bu ON bu.GUID = bi.ParentGUID
		INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
	WHERE 
		mt.ExpireFlag > 0 
		AND
		NOT (bt.SortNum = 0 AND bt.type = 3)
		AND
		((Dir = -1 AND ForceOutExpire > 0)
		OR 
		(Dir = 1 AND ForceInExpire > 0 AND [ExpireDate] = '1/1/1980'))

	IF @@ROWCOUNT = 0
		RETURN

	IF EXISTS(SELECT * FROM @bi WHERE Qty > 0 AND [ExpireDate] = '1/1/1980')
	BEGIN
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])  
			SELECT 1, 0, 'AmnE0133: Bill item(['+ mtName +']) doesnt''t contain expire date ', MatGUID FROM @bi WHERE Qty > 0 AND [ExpireDate] = '1/1/1980'
	END

	IF EXISTS(SELECT * FROM @bi WHERE Direction < 0)
	BEGIN
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])  
		SELECT 1, 0, 'AmnE0134: Bill item(['+ mtName +']) The expiredate doesn''t exists ', B.MatGUID
		FROM bi000 bi INNER JOIN bu000 bu ON bu.GUID = bi.ParentGUID 
		INNER JOIN bt000 bt  ON bt.GUID = bu.TypeGUID
		INNER JOIN (SELECT DISTINCT MatGuid FROM @bi) bb ON bb.MatGUID = bi.MatGUID 
		RIGHT JOIN @bi b ON CAST(b.MatGUID AS NVARCHAR(36)) + CAST(b.Store AS NVARCHAR(36)) + CAST(b.ExpireDate AS NVARCHAR(10)) 
						= CAST(bi.MatGUID AS NVARCHAR(36)) + CAST(bi.StoreGUID  AS NVARCHAR(36)) + CAST(bi.ExpireDate AS NVARCHAR(10))
		WHERE BU.IsPosted > 0 AND b.Direction < 0 
		GROUP BY mtName,b.MatGUID,b.Store,b.[ExpireDate] 
		HAVING ISNULL(SUM((bi.qty + bi.bonusqnt) * CASE bt.bIsInput WHEN 1 THEN 1 ELSE -1 END),-1) < 0 
	END
################################################################################
CREATE TRIGGER trgPaymentsPackageCheck_Delete ON POSPaymentsPackageCheck000 for DELETE
	NOT FOR REPLICATION

AS
DELETE FROM ch000 
FROM ch000 ch 
INNER JOIN DELETED d ON ch.Guid = d.ChildID
#########################################################
CREATE TRIGGER trg_bu000_CheckConstraintsClass
	ON [dbo].[bu000] FOR UPDATE  
	NOT FOR REPLICATION

AS   
	IF @@ROWCOUNT = 0 
		RETURN;
	
	SET NOCOUNT ON;
	
	IF NOT EXISTS(SELECT * FROM Inserted I JOIN bi000 BI ON bi.ParentGuid = I.Guid JOIN mt000 MT ON MT.Guid = BI.MatGuid WHERE MT.ForceInClass > 0 OR MT.ForceOutClass > 0)
		RETURN;

	SELECT 
		BI.MatGuid,
		MT.Name AS mtName,
		MT.ForceInClass,
		MT.ForceOutClass,
		BI.ClassPtr,
		BI.Qty,
		BI.StoreGuid,
		CASE bt.bisInput 
			WHEN 1 THEN 1 
			ELSE -1 
		END AS Dir
	INTO #Result_Trg
	FROM
		bi000 BI
		JOIN inserted I ON I.Guid = BI.ParentGUID
		JOIN bt000 BT ON BT.Guid = I.TypeGUID
		JOIN mt000 MT ON MT.Guid = BI.MatGuid
	WHERE
		((MT.ForceInClass > 0 AND BT.bIsInput > 0) OR (MT.ForceOutClass > 0 AND BT.bIsOutput > 0)) 
		AND BI.Qty > 0
		AND (BT.bAutoPost = 1 OR I.IsPosted = 1)
		AND NOT (bt.SortNum = 0 AND bt.type = 3)

	INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])  
	SELECT 
		1, 
		0, 
		'AmnE0135: Bill item(['+ mtName +']) doesnt''t contain a class ', 
		MatGuid
	FROM
		#Result_Trg
	WHERE
		ClassPtr = N'';

	INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])  
	SELECT 1, 0, 'AmnE0136: Bill item(['+ mtName +']) The material class doesn''t exists ', B.MatGUID
	FROM
		bi000 bi INNER JOIN bu000 bu ON bu.GUID = bi.ParentGUID 
		INNER JOIN bt000 bt  ON bt.GUID = bu.TypeGUID
		INNER JOIN (SELECT DISTINCT MatGuid FROM #Result_Trg) bb ON bb.MatGUID = bi.MatGUID 
		RIGHT JOIN #Result_Trg b ON b.MatGUID = bi.MatGUID AND b.StoreGuid = bi.StoreGUID AND b.ClassPtr = BI.ClassPtr
	WHERE 
		BU.IsPosted > 0 AND b.Dir < 0 
	GROUP BY  
		mtName,
		b.MatGUID,
		b.StoreGuid,
		b.ClassPtr
	HAVING 
		ISNULL(SUM((bi.qty + bi.bonusqnt) * CASE bt.bIsInput WHEN 1 THEN 1 ELSE -1 END),-1) < 0 
################################################################################
CREATE TRIGGER trg_bu000_insert 
	ON [dbo].[bu000] FOR INSERT
	NOT FOR REPLICATION

AS  
	IF @@ROWCOUNT = 0 RETURN  
	SET NOCOUNT ON  

	IF EXISTS (SELECT * FROM inserted WHERE ISNULL(CreateUserGUID, 0x0) = 0x0)
	BEGIN 
		UPDATE bu 
		SET 
			CreateUserGUID = [dbo].[fnGetCurrentUserGUID](),
			CreateDate = GETDATE()
		FROM 
			bu000 bu 
			INNER JOIN inserted i ON bu.GUID = i.GUID 
		WHERE 
			ISNULL(i.CreateUserGUID, 0x0) = 0x0
	END 
################################################################################
#END