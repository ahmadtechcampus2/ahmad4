CREATE VIEW vwAD_in 
AS
	SELECT * from vwadas	WHERE adStatus = 1
######################################################################
CREATE VIEW vwAD_Out
AS
	SELECT * from vwadas	WHERE adStatus = 0

######################################################################
CREATE view vwExtended_AD
AS
SELECT  
	ad.adSn code, 
	ad.adGuid Guid, 
	ad.adSn +'-'+CASE dbo.fnConnections_GetLanguage() WHEN 1 THEN ass.asName ELSE CASE ass.asLatinName WHEN '' THEN  ass.asName ELSE ass.asLatinName END END adCodeName,   
	my.Guid CurrencyGuid, 
	my.CurrencyVal, 
	my.Code Currency, 
	bi.StoreGUID, 
	ISNULL(AddedVal, 0) AddedVal, 
	ISNULL(DeductVal, 0) DeductVal, 
	st.Code +'-'+CASE dbo.fnConnections_GetLanguage() WHEN 1 THEN st.Name ELSE CASE st.LatinName WHEN '' THEN  st.Name ELSE st.LatinName END END stCodeName,   
	ISNULL(co.Guid, 0x0) coGuid, 
	co.Code +'-'+CASE dbo.fnConnections_GetLanguage() WHEN 1 THEN co.Name ELSE CASE co.LatinName WHEN '' THEN  co.Name ELSE co.LatinName END END coCodeName,  	 
	ad.adInVal Price 
FROM	dbo.fnGetLastSN2()  fn    
		INNER	JOIN vwad	AS ad	ON ad.adSn = fn.sn 
		INNER	JOIN vwas	AS ass	ON ad.adAssGuid = ass.asGuid 
		INNER	JOIN bi000	AS bi	ON bi.Guid = fn.biGuid  
		INNER	JOIN st000	AS st	ON st.Guid = bi.StoreGuid  
		INNER	JOIN my000	AS my	ON my.Guid = bi.CurrencyGuid  
		LEFT	JOIN co000	AS co	ON co.Guid = fn.biCostGuid  
		LEFT 	JOIN (	select axAssDetailGuid, Sum(axvalue) AddedVal	FROM vwAssAdded	group by axAssDetailGuid ) added on added.axAssDetailGuid = ad.adGuid 
		LEFT 	JOIN (	select axAssDetailGuid, Sum(axvalue) DeductVal	FROM vwAssDeduct	group by axAssDetailGuid ) Deduct on Deduct.axAssDetailGuid = ad.adGuid														 
######################################################################
CREATE    VIEW  vwAssetExcludeDetails
AS
SELECT 
	d.Guid,
	d.ParentGuid,
	d.adGuid,
	d.costGuid,
	d.storeGuid,
	d.CurrencyGuid,
	d.CurrencyVal,
	ad.inVal price,
	d.Price outPrice,
	d.Notes,
	ISNULL(AddedVal, 0) + ad.adAddedVal AS AddedVal,
	ISNULL(DeductVal, 0) + ad.adDeductVal AS DeductVal,
	co.Code + '-'+ CASE dbo.fnConnections_GetLanguage() WHEN 0 THEN co.Name ELSE co.LatinName END coCodeName,  
	st.Code + '-'+ CASE dbo.fnConnections_GetLanguage() WHEN 0 THEN st.Name ELSE st.LatinName END stCodeName,  
	ad.Code + '-'+ CASE dbo.fnConnections_GetLanguage() WHEN 0 THEN ad.Name ELSE ad.LatinName END adCodeName,
	my.Code	Currency
from AssetExcludeDetails000 d	
	INNER	JOIN vwadas ad on ad.Guid = d.adGuid
	INNER	JOIN St000 st on st.Guid = d.storeGuid
	LEFT	JOIN Co000 co on co.Guid = d.CostGuid
	INNER	JOIN my000 My on My.Guid = d.CurrencyGuid
	LEFT	JOIN (	select axAssDetailGuid, Sum(axvalue) AddedVal	FROM vwAssAdded	group by axAssDetailGuid ) added on added.axAssDetailGuid = ad.Guid
	LEFT 	JOIN (	select axAssDetailGuid, Sum(axvalue) DeductVal	FROM vwAssDeduct	group by axAssDetailGuid ) Deduct on Deduct.axAssDetailGuid = ad.Guid														
######################################################################
CREATE PROC PrcAssetsExcludeSave
		@Guid				UNIQUEIDENTIFIER,
		@CeCreateDate		DATETIME,
		@CeCreateUserGUID	UNIQUEIDENTIFIER,
		@BuCreateDate		DATETIME,
		@BuCreateUserGUID	UNIQUEIDENTIFIER,
		@isModify BIT
AS     
SET NOCOUNT ON
		DECLARE @BillTypeGuid UNIQUEIDENTIFIER --   
		DECLARE @DefStoreGuid UNIQUEIDENTIFIER --   
		DECLARE @StoreGuid UNIQUEIDENTIFIER --   
		DECLARE @AccGuid UNIQUEIDENTIFIER --   
		DECLARE @CostGuid  UNIQUEIDENTIFIER --   
		DECLARE @BillGuid  UNIQUEIDENTIFIER --   
		DECLARE @EntryGUID  UNIQUEIDENTIFIER --   
		DECLARE @BranchGUID UNIQUEIDENTIFIER --   
		DECLARE @NOTES  NVARCHAR(250)  --     
		DECLARE @BillNumber BIGINT	 -- رقم الفاتورة     
		DECLARE @Date DATETIME	 -- رقم الفاتورة     
		DECLARE @CurrencyGuid  UNIQUEIDENTIFIER -- العملة      
		DECLARE @CustomerGuid  UNIQUEIDENTIFIER --  الزبون     
		DECLARE @CurrencyVal  FLOAT --     
	  	DECLARE @ParentGUID UNIQUEIDENTIFIER
		DECLARE @ParentNumber BIGINT

		DECLARE @AccuDepCustomerGuid UNIQUEIDENTIFIER
		DECLARE @CusAccCustomerGuid UNIQUEIDENTIFIER
		DECLARE @CapitalProfitCustomerGUID UNIQUEIDENTIFIER
		DECLARE @CapitalLossCustomerGUID UNIQUEIDENTIFIER
		DECLARE @CustGUID UNIQUEIDENTIFIER
	  	  
		SELECT  @BillTypeGuid = CAST ( [Value] AS  UNIQUEIDENTIFIER) FROM op000 WHERE Name = 'HosCfg_ExcludeAssets_BillType'        
		 
		SELECT @BranchGUID = BranchGuid, @BillGuid = BillGuid , @BillTypeGuid = BillTypeGuid, @ParentNumber = Number FROM AssetExclude000 WHERE GUID = @Guid  
		EXEC	prcBill_delete  @BillGuid     
		SELECT					 @BillGuid = BillGuid,  -- الفاتورة     
								 @Date = [Date],     
								 @AccGuid = AccGuid,      
								 @CustomerGuid = CustomerGuid, -- العميل     
								 @CurrencyGuid = CurrencyGuid,    
								 @CurrencyVal = CurrencyVal,    
								 @Notes = Notes    
		FROM AssetExclude000 WHERE guid = @Guid 

		IF EXISTS( SELECT * FROM vwAcCu WHERE GUID = @AccGuid and CustomersCount > 1)
		BEGIN
			INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
			SELECT 1, 0, 'AmnE0052: [' + CAST(@AccGuid AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
			RETURN 
		END
		 
		SELECT  @StoreGuid = StoreGuid  , @CostGuid = CostGuid  
		FROM AssetExcludeDetails000 ex 
		WHERE ex.ParentGuid = @Guid 
		 
		--  GENERATE BILL    
		SELECT @BillNumber =  ISNULL(MAX(Number), 0 ) + 1 FROM bu000 WHERE  TypeGuid = @BillTypeGuid 			PRINT @BillNumber     
		SET @BillGuid = NEWID()     
		INSERT INTO Bu000 (Guid,  number, [Date], CurrencyVal, Notes, PayType, TypeGuid, CustGuid, CurrencyGuid, CustAccGuid , StoreGuid, Security, Branch)     
		VALUES (@BillGuid, @BillNumber, @Date, @CurrencyVal, @Notes, 1, @BillTypeGuid, @CustomerGuid, @CurrencyGuid, @AccGuid, @StoreGuid, 1 , @BranchGUID)     
		SELECT  		     
				NewID() AS Guid,     
				ad.Guid adguid,    
				1 AS Qty,     
				1 AS Unity,      
				ex.Price As Price,      
				ex.CurrencyGuid as CurrencyGuid,      
				ex.CurrencyVal as CurrencyVal,      
		 		ex.Notes AS Notes,      
				ex.StoreGuid as StoreGuid,      
				@BillGuid AS BillGuid,      
				ex.CostGuid as CostGuid,      
				mt.Guid  MatGuid    
		INTO #BillDetails    
		FROM AssetExcludeDetails000 ex 	INNER JOIN ad000 ad on ex.adGuid = ad.Guid     
										INNER JOIN as000 ass on ass.Guid = ad.ParentGuid     
										INNER JOIN mt000 mt on mt.Guid = ass.ParentGuid     
		WHERE ex.ParentGUID = @Guid 
		INSERT  INTO Bi000      
			( Guid , Qty,  Unity,  Price,  CurrencyGuid,  CurrencyVal,  Notes,  StoreGuid,  ParentGuid,  CostGuid,  MatGuid )     
		SELECT 	    
			 Guid , Qty,  Unity,  Price,  CurrencyGuid,  CurrencyVal,  Notes,  StoreGuid,  BillGuid,  CostGuid,  MatGuid     
		FROM #BillDetails    
	INSERT INTO snt000     
	(    
		Guid, Item,	biGuid,	stGuid, ParentGuid, Notes, buGuid   
	)    
	SELECT      
		newId(), 0, b.Guid, b.StoreGuid, Sn.Guid, '',  b.BillGuid      
	FROM #BillDetails b INNER JOIN ad000 ad ON ad.Guid = b.adGuid    
						INNER JOIN SNC000 SN ON ad.SnGuid = Sn.Guid    
	--PRINT 'Before post Bill'  
	EXEC 	prcBill_post @BillGuid, 1     
	UPDATE bu000 
			SET isposted = 1 ,
				CreateDate = CASE WHEN @isModify = 1 THEN  @BuCreateDate ELSE GETDATE() END,
				CreateUserGUID = CASE WHEN @isModify = 1 THEN  @BuCreateUserGuid ELSE [dbo].[fnGetCurrentUserGUID]() END,
				LastUpdateDate = CASE WHEN @isModify = 1 THEN  GETDATE() ELSE LastUpdateDate END,
				LastUpdateUserGUID = CASE WHEN @isModify = 1 THEN  [dbo].[fnGetCurrentUserGUID]() ELSE LastUpdateUserGUID END
			WHERE 
				GUID = @BillGuid		    
	--PRINT 'After post Bill'  
	--EXEC  prcBill_genEntry @BillGuid    
	UPDATE AssetExclude000 SET BillGuid = @BillGuid	WHERE Guid = @Guid       
	-- END GENERATE BILL     
	-- GENERATE BILL PARENT
	DELETE FROM BillRel000 WHERE ParentGUID = @Guid
	INSERT INTO BillRel000     
	(    
		GUID, Type, BillGUID, ParentGUID, ParentNumber   
	)    
	SELECT      
		newId(), 1, @BillGuid, @Guid, @ParentNumber      
	-- END GENERATE BILL PARENT
	   
	-- GENERATE ENTRY    
	EXEC 	prcER_delete @Guid, 102    
	SET @entryGUID = NEWID()    
	DECLARE @entryNum int,
			@CusAccGuid UNIQUEIDENTIFIER,
            @AccuDepAccGuid UNIQUEIDENTIFIER,    
            @CapitalProfitAccGUID UNIQUEIDENTIFIER,  
            @CapitalLossAccGUID     UNIQUEIDENTIFIER     
	SET @entryNum = [dbo].[fnEntry_getNewNum](@BranchGUID)        
	SELECT axAssDetailGuid, Sum(axvalue) AddedVal	 INTO #Added 	FROM vwAssAdded	 	GROUP BY axAssDetailGuid     
	SELECT axAssDetailGuid, Sum(axvalue) DeductVal	INTO #Deduct 	FROM vwAssDeduct 	GROUP BY axAssDetailGuid     
	SELECT adGuid, Sum(Value) CurrentDepVal  		INTO #Dep 		FROM dd000  	GROUP BY adGuid    
	CREATE TABLE #ad (	Guid UNIQUEIDENTIFIER,    
						CostGuid UNIQUEIDENTIFIER,    
						sn NVARCHAR(100) COLLATE Arabic_CI_AI,     
						[Name] NVARCHAR(250) COLLATE Arabic_CI_AI,     
						[LatinN	ame] NVARCHAR(250) COLLATE Arabic_CI_AI ,     
						CurrencyGuid UNIQUEIDENTIFIER,    
						CurrencyVal FLOAT,    
						CusAccGuid UNIQUEIDENTIFIER,    
						AccGuid uniqueidentifier,     
						AccuDepAccGuid UNIQUEIDENTIFIER,     
						outPrice FLOAT,    
						val FLOAT,    
						added FLOAT,   
						Deduct FLOAT,    
						CurrentDep FLOAT,    
						DeprecationVal FLOAT,     
						CapitalProfitAccGUID UNIQUEIDENTIFIER,    
						CapitalLossAccGUID UNIQUEIDENTIFIER   
		)
      INSERT INTO #ad     
      SELECT ad.Guid,  xd.CostGuid,  ad.Sn, ass.Name, ass.LatinName, xd.CurrencyGuid, xd.CurrencyVal,  x.AccGuid , Ass.AccGuid, Ass.AccuDepAccGuid, xd.Price, ad.inVal, ISNULL(Added.addedVal, 0) addedVal, ISNULL( Deduct.DeductVal , 0) DeductVal, ISNULL(CurrentDepVal , 0), ISNULL(ad.DeprecationVal, 0), Ass.CapitalProfitAccGUID, Ass.CapitalLossAccGUID     
      FROM ad000 ad     INNER JOIN AssetExcludeDetails000   AS    xd                ON xd.adGuid = ad.Guid    
                              INNER JOIN AssetExclude000          AS    x                 ON xd.ParentGuid = x.Guid    
                              INNER JOIN as000                          AS    ass               ON ass.Guid = ad.ParentGuid    
                              LEFT  JOIN (      select axAssDetailGuid, Sum(axvalue) AddedVal            from vwAssAdded         group by axAssDetailGuid )    AS    Added             ON Added.axAssDetailGuid   = ad.guid    
                              LEFT  JOIN #Deduct                        AS    Deduct            ON Deduct.axAssDetailGuid = ad.guid    
                              LEFT  JOIN #Dep                           AS    DEP               ON Dep.adGuid = ad.Guid    
      WHERE x.Guid = @Guid
              DECLARE @I FLOAT
              SET @I = ( SELECT SUM(outPrice) +
                                   SUM(val)      +
                                   SUM(added)    + 
                                   SUM(Deduct)   +
                                   SUM(CurrentDep) + 
                                   SUM(DeprecationVal) FROM  #ad)

		SELECT
			 @AccuDepAccGuid = AccuDepAccGuid
			,@CusAccGuid = CusAccGuid
			,@AccGuid =  AccGuid
			,@CapitalProfitAccGUID = CapitalProfitAccGUID
			,@CapitalLossAccGUID = CapitalLossAccGUID
		FROM #ad
		------------------------------------------------------------------------------------------------------------------------
		IF EXISTS( SELECT * FROM vwAcCu WHERE GUID = @AccuDepAccGuid and CustomersCount > 1)
		BEGIN
			INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
			SELECT 1, 0, 'AmnE0052: [' + CAST(@AccuDepAccGuid AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
			RETURN 
		END 
		ELSE IF EXISTS( SELECT * FROM vwAcCu WHERE GUID = @CusAccGuid and CustomersCount > 1)
			BEGIN
				INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
				SELECT 1, 0, 'AmnE0052: [' + CAST(@CusAccGuid AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
				RETURN 
			END 
		ELSE  IF EXISTS( SELECT * FROM vwAcCu WHERE GUID = @AccGuid and CustomersCount > 1)
			BEGIN
				INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
				SELECT 1, 0, 'AmnE0052: [' + CAST(@AccGuid AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
				RETURN 
			END 
		ELSE IF EXISTS( SELECT * FROM vwAcCu WHERE GUID = @CapitalProfitAccGUID and CustomersCount > 1)
		BEGIN
			INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
			SELECT 1, 0, 'AmnE0052: [' + CAST(@CapitalProfitAccGUID AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
			RETURN 
		END 
		ELSE IF EXISTS( SELECT * FROM vwAcCu WHERE GUID = @CapitalLossAccGUID and CustomersCount > 1)
			BEGIN
				INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
				SELECT 1, 0, 'AmnE0052: [' + CAST(@CapitalLossAccGUID AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
				RETURN 
			END 

		IF EXISTS(SELECT * FROM vwAcCu WHERE GUID = @AccuDepAccGuid and CustomersCount = 1)
		BEGIN
			SELECT @AccuDepCustomerGuid = CuGUID FROM vwCu WHERE cuAccount = @AccuDepAccGuid 
		END

		IF EXISTS(SELECT * FROM vwAcCu WHERE GUID = @CusAccGuid and CustomersCount = 1)
		BEGIN
			SELECT @CusAccCustomerGuid = CuGUID FROM vwCu WHERE cuAccount = @CusAccGuid 
		END
		IF EXISTS(SELECT * FROM vwAcCu WHERE GUID = @AccGuid and CustomersCount = 1)
		BEGIN
			SELECT @CustGUID = CuGUID FROM vwCu WHERE cuAccount = @AccGuid 
		END

		IF EXISTS(SELECT * FROM vwAcCu WHERE GUID = @CapitalProfitAccGUID and CustomersCount = 1)
		BEGIN
			SELECT @CapitalProfitCustomerGUID = CuGUID FROM vwCu WHERE cuAccount = @CapitalProfitAccGUID 
		END

		IF EXISTS(SELECT * FROM vwAcCu WHERE GUID = @CapitalLossAccGUID and CustomersCount = 1)
		BEGIN
			SELECT @CapitalLossCustomerGUID = CuGUID FROM vwCu WHERE cuAccount = @CapitalLossAccGUID 
		END
								

IF (@I > 0)
BEGIN
            --Print 'Generation'    
            DECLARE     
            @sn NVARCHAR(100),    
            @Name NVARCHAR(250),     
            @LatinName NVARCHAR(250),     
            @adGuid UNIQUEIDENTIFIER,     
            @val FLOAT,     
            @outPrice FLOAT,     
            @added FLOAT,    
            @Deduct FLOAT,     
            @CurrentDep FLOAT,     
            @DeprecationVal FLOAT    
              
      -- insert into ce    
            INSERT INTO [ce000] ([typeGUID], [Type], [Number], [Date], [Notes], [CurrencyVal], [IsPosted], [Security], [Branch], [GUID], [CurrencyGUID])       
                  SELECT  0x0, 1, @entryNum, @Date, @Notes, @CurrencyVal, 0, 1, @BranchGUID, @entryGUID, @CurrencyGuid       
            -- insert into en000    
            DECLARE adCursor Cursor FOR     
            SELECT *    FROM #ad    
            OPEN adCursor    
    
            FETCH NEXT FROM adCursor    
            INTO     
                  @adGuid, @CostGuid, @sn, @Name, @LatinName,@CurrencyGuid, @CurrencyVal,   @CusAccGuid, @AccGuid, @AccuDepAccGuid, @outPrice, @val, @added, @Deduct, @CurrentDep, @DeprecationVal,  @CapitalProfitAccGUID, @CapitalLossAccGUID    
    
            WHILE @@FETCH_STATUS = 0    
            BEGIN    
                  --???? ???? ??????    
                  IF(@DeprecationVal + @CurrentDep > 0)
                  BEGIN
				     
					  INSERT INTO [en000]    
					  ([number], [accountGUID],     [Date], [Debit], [Credit], [Notes], [CurrencyGUID],[CurrencyVal], [ParentGUID], [CostGUID], [ContraAccGUID], [CustomerGUID])          
					  VALUES     
					  (1, @AccuDepAccGuid, @Date,  @DeprecationVal + @CurrentDep, 0, @Sn + '-'+Case dbo.fnConnections_GetLanguage() WHEN 0 THEN @Name ELSE @LatinName END, @CurrencyGuid, @CurrencyVal, @entryGUID, @CostGuid, @CusAccGuid, @AccuDepCustomerGuid )    
                  END
				  --???? ??????    
                  IF(@outPrice > 0)
                  BEGIN
					  INSERT INTO [en000]    
					  ([number], [accountGUID],     [Date], [Debit], [Credit], [Notes], [CurrencyGUID],[CurrencyVal], [ParentGUID], [CostGUID], [ContraAccGUID], [CustomerGUID])          
					  VALUES     
					  (2, @CusAccGuid, @Date,  @outPrice, 0, @Sn + '-'+Case dbo.fnConnections_GetLanguage() WHEN 0 THEN @Name ELSE @LatinName END, @CurrencyGuid, @CurrencyVal, @entryGUID, @CostGuid, @AccuDepAccGuid, @CusAccCustomerGuid )    
				  END
                  DECLARE @PR FLOAT   
                  SET @PR = @outPrice -( @val + @added - @Deduct)+ @DeprecationVal + @CurrentDep;   
                  IF( @PR > 0 )    
                  BEGIN    
                        IF(@val + @added - @Deduct > 0)
						BEGIN
							INSERT INTO [en000]    
							([number], [accountGUID],     [Date], [Debit], [Credit], [Notes], [CurrencyGUID],[CurrencyVal], [ParentGUID], [CostGUID], [ContraAccGUID], [CustomerGUID])          
							VALUES     
							(3, @AccGuid, @Date,  0, @val + @added - @Deduct, @Sn + '-'+Case dbo.fnConnections_GetLanguage() WHEN 0 THEN @Name ELSE @LatinName END, @CurrencyGuid, @CurrencyVal, @entryGUID, @CostGuid, @CapitalProfitAccGUID, @CustGUID )    
						END
                        IF(@PR > 0)
						BEGIN
							INSERT INTO [en000]    
							([number], [accountGUID], [Date], [Debit], [Credit], [Notes], [CurrencyGUID],[CurrencyVal], [ParentGUID], [CostGUID], [ContraAccGUID], [CustomerGUID])          
							VALUES     
							(4, @CapitalProfitAccGUID, @Date, 0 , @PR, @Sn + '-'+Case dbo.fnConnections_GetLanguage() WHEN 0 THEN @Name ELSE @LatinName END, @CurrencyGuid, @CurrencyVal, @entryGUID, @CostGuid, @AccGuid, ISNULL(@CapitalProfitCustomerGUID, 0x0) )    
						END
                  END ELSE   
                  BEGIN  
						IF(@val + @added - @Deduct > 0)
						BEGIN  

							INSERT INTO [en000]    
							([number], [accountGUID], [Date], [Debit], [Credit], [Notes], [CurrencyGUID],[CurrencyVal], [ParentGUID], [CostGUID], [ContraAccGUID], [CustomerGUID])          
							VALUES     
							(3, @AccGuid, @Date,  0, @val + @added - @Deduct, @Sn + '-'+Case dbo.fnConnections_GetLanguage() WHEN 0 THEN @Name ELSE @LatinName END, @CurrencyGuid, @CurrencyVal, @entryGUID, @CostGuid, @CapitalProfitAccGUID, ISNULL(@CustGUID, 0x0) )    
						END
						IF( ABS(@PR) > 0)
						BEGIN
							INSERT INTO [en000]    
							([number], [accountGUID],     [Date], [Debit], [Credit], [Notes], [CurrencyGUID],[CurrencyVal], [ParentGUID], [CostGUID], [ContraAccGUID], [CustomerGUID])          
							VALUES     
							(4, @CapitalLossAccGUID, @Date, ABS( @PR) , 0, @Sn + '-'+Case dbo.fnConnections_GetLanguage() WHEN 0 THEN @Name ELSE @LatinName END, @CurrencyGuid, @CurrencyVal, @entryGUID, @CostGuid, @AccGuid, ISNULL(@CapitalLossCustomerGUID, 0x0) )    
						END
                  END    
                  FETCH NEXT FROM adCursor    
                  INTO     
                        @adGuid, @CostGuid, @sn, @Name, @LatinName,@CurrencyGuid, @CurrencyVal,   @CusAccGuid, @AccGuid, @AccuDepAccGuid, @outPrice, @val, @added, @Deduct, @CurrentDep, @DeprecationVal, @CapitalProfitAccGUID, @CapitalLossAccGUID    
            END    
            CLOSE adCursor    
            DEALLOCATE adCursor    
            INSERT INTO [er000] ([EntryGUID], [ParentGUID], [ParentType], [ParentNumber])        
                  VALUES(@entryGUID, @GUID, 102, @entryNum)        
            EXEC prcEntry_post @entryGUID, 1    
		UPDATE ce000 
			SET isposted  = 1, 
				PostDate = GETDATE(),
				CreateDate = CASE WHEN @isModify = 1 THEN  @CeCreateDate ELSE GETDATE() END,
				CreateUserGUID = CASE WHEN @isModify = 1 THEN  @CeCreateUserGUID ELSE [dbo].[fnGetCurrentUserGUID]() END,
				LastUpdateDate = CASE WHEN @isModify = 1 THEN  GETDATE() ELSE LastUpdateDate END,
				LastUpdateUserGUID = CASE WHEN @isModify = 1 THEN  [dbo].[fnGetCurrentUserGUID]() ELSE LastUpdateUserGUID END				
			WHERE 
				Guid = @entryGUID
        UPDATE AssetExclude000 SET EntryGuid = @entryGUID WHERE [Guid] = @Guid

END
ELSE
BEGIN
        UPDATE AssetExclude000 SET EntryGuid = @entryGUID WHERE [Guid] = 0x0
END
   UPDATE  Ad000 SET Status = 0 FROM Ad000 ad INNER join #ad ac ON ad.Guid = ac.guid
######################################################################
CREATE PROC prcAssetsRePriceBill @SrcGuid UNIQUEIDENTIFIER
AS 
SELECT 	ad.inval,  
		bi.price, 
		bi.Guid biGuid 
INTO #MatPrice 
FROM  
bi000 bi 	INNER	join snt000 snt ON snt.biGuid = bi.Guid 
			INNER	join snc000 snc ON snt.ParentGuid = Snc.Guid 
			INNER	join ad000 ad ON ad.snGuid = Snc.Guid 
			INNER  	join bu000 bu ON bi.ParentGuid = bu.Guid 
			INNER  	join bt000 bt ON bt.Guid = bu.TypeGuid
			INNER  	join repsrcs src ON bt.Guid = src.IdType 
WHERE src.IdTbl = @SrcGuid and bu.LCGUID = 0x0

EXEC prcDisableTriggers 'bi000'
UPDATE bi000 SET price = inVal FROM #MatPrice mt INNER JOIN bi000 bi ON  mt.biGuid= bi.Guid 
ALTER TABLE bi000 ENABLE TRIGGER all 
DELETE repsrcs WHERE IdTbl = @SrcGuid
######################################################################
CREATE  proc prcDeleteExcludeAsset @Guid Uniqueidentifier
AS
	DECLARE @BillGuid UNIQUEIDENTIFIER, @EntryGuid  UNIQUEIDENTIFIER
	update  Ad000 SET Status = 1 from Ad000 ad inner join assetExcludeDetails000 ac on ad.Guid = ac.adguid  
	WHERE ac.ParentGuid = @Guid

	SELECT @BillGuid = BillGuid, @EntryGuid = EntryGuid  from assetExclude000 WHERE Guid = @Guid
	EXEC	prcBill_delete  @BillGuid 
	exec 	prcER_delete @Guid, 102
	DELETE FROM assetExclude000 WHERE Guid = @Guid
	DELETE  FROM assetExcludeDetails000 WHERE ParentGuid = @Guid
	DELETE FROM BillRel000 WHERE ParentGUID = @Guid
#########################################################
#END
