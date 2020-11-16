#########################################################
CREATE VIEW vwExtended_SN
AS
	SELECT  snc.Sn, 
			snc.Qty, 
		   	snc.Guid snGuid, 
		   	bi.*
	FROM  vwextended_bi bi 	INNER join snt000 snt ON snt.BiGuid = bi.BiGuid
				 			INNER join snc000 snc ON snc.Guid = snt.ParentGuid
#########################################################
CREATE VIEW vwSNInfo
AS
	SELECT
		SN,
		buCust_Name AS Cust_Name,
		buDate AS Date,
		btName,
		buNumber,
		biNotes,
		buNotes,
		biQty,
		mtName AS MatName,
		mtCode AS MatCode,
		btIsInput
	FROM
		vwExtended_SN
#########################################################
CREATE PROC prcBillGenAssets
	@billGUID [UNIQUEIDENTIFIER],   
	@Post [BIT] = 1   
AS     
	declare  @isInput int, @SnADCnt int   
	SET NOCOUNT ON    
	IF @Post = 0      
	BEGIN   
		/*
		SELECT SC.Guid,count([buDirection]) AS Qty
		INTO #SNQTY
		FROM    
		[snc000] SC INNER JOIN [SNT000] ST ON st.[ParentGuid] = sc.[Guid]   
		INNER JOIN [vwbubi] [bi] ON bi.buGuid = st.buGuid   
		Group by SC.Guid   
		DELETE ad000 FROM #SNQTY sn INNER JOIN ad000 ad On ad.SnGuid = Sn.Guid 
									INNER JOIN [SNT000] ST ON st.[ParentGuid] = sn.[Guid]   
									INNER JOIN [vwbubi] [bi] ON bi.buGuid = st.buGuid   
		WHERE Qty <= 1 and bi.buGuid = @billGUID */  
		RETURN   
	END
	--	ãÚÑÝÉ äæÚ ÇáÝÇÊæÑÉ ÅÏÎÇá Ãã ÅÎÑÇÌ   
	set @isInput = (select TOP 1 [t].[bIsInput] from [bu000] [b] inner join [bt000] [t] on [b].[typeGuid] = [t].[guid] where [b].[guid] = @billGuid)    
	if @isInput is null     
		return     
	-- ÊÍÏíË ÍÞæá  ÇáÃÕá ÇáÝÑÚíÉ Ýí ÍÇá ÇáÝÇÊæÑÉ ÅÏÎÇá   
	if @isInput = 1    
	begin  
		DECLARE @TransNotes int = [dbo].[fnOption_get]('HosCfg_TransNotesFromBill', '0')    
		select @SnADCnt = count(*) from vwExtended_SN where mtType = 2 and buGuid = @billGUID    
		if (  ISNULL( @SnAdCnt, 0) = 0)    
			return      
		-- ÊÍÏíË ÇáÃÕæá ÇáãÏÎáÉ ÓáÝÇ   
		UPDATE [ad000] SET    
			[InVal] = [b].[biUnitPrice] + [b].[biUnitExtra] - [b].[biUnitDiscount],    
			[InCurrencyGUID] = [b].[buCurrencyPtr],    
			[InCurrencyVal] = [b].[buCurrencyVal],    
			[InDate] = CASE WHEN [bt].[Type] = 2 AND [bt].[sortNum] = 1 THEN [ad].[inDate] ELSE (CASE WHEN [ad].[UseFlag] <> 0 THEN [ad].[inDate] ELSE [b].[buDate] END) END,
			[BillGuid] = @billGUID  ,
			[BrGuid] = [b].[buBranch],
			[Notes] = (CASE @TransNotes WHEN 1 THEN 
											(CASE [b].biNotes WHEN '' THEN [Notes] ELSE  [b].biNotes END)
										ELSE [Notes] END),
			[PurchaseOrderDate] = [b].[buDate]
		FROM     
			[vwExtended_sn] AS [b]   INNER JOIN ad000 ad ON ad.snGuid  = b.snGuid  
									INNER JOIN bt000 bt on b.buType = bt.Guid 
		WHERE       
			[b].[buGUID] = @billGUID    
			AND [bt].BAffectCostPrice = 1 
			AND [btIsInput] = 1   
			AND [b].[btType] = 1
		IF( @@ROWCOUNT = ISNULL( @SnAdCnt, 0))    
			return    
		
		CREATE TABLE #Temp (   
							Guid  UNIQUEIDENTIFIER,    
							Sn NVARCHAR(150) COLLATE ARABIC_CI_AI,
							[inVal] FLOAT ,    
							[ParentGuid] UNIQUEIDENTIFIER,    
							[inCurrencyGUID]  UNIQUEIDENTIFIER,    
							[inCurrencyVal] FLOAT,    
							snGuid UNIQUEIDENTIFIER,   
							inDate DATETIME,   
							billGUID UNIQUEIDENTIFIER,    
							Number int IDENTITY(1,1) ,
							BuBranchGuid uniqueidentifier,
							BiNote			NVARCHAR(1000)    
					)   
		INSERT INTO #TEMP    
		SELECT    
			  NewId(),    
			  bi.Sn,   
			  [bi].[biUnitPrice] + [bi].[biUnitExtra] - [bi].[biUnitDiscount],    
			  [ass].Guid,    
			  [bi].[buCurrencyPtr],   
			  [bi].[buCurrencyVal],   
			  [bi].snGuid,   
			  [bi].[buDate],			     
			  @BillGuid,
			  bi.buBranch,
			  (CASE @TransNotes WHEN 1 THEN bi.biNotes ELSE '' END)
		FROM     
			[vwExtended_sn] AS [bi]	 LEFT  JOIN [ad000]  AS  [ad]  ON [ad].[SnGUID] = [bi].[snGUID]   
									 INNER JOIN As000    As  ASS   ON ass.ParentGuid = bi.biMatPtr   
		WHERE    
			[bi].[buGUID] = @billGUID       
			AND ([bi].[btType] = 1  OR [btType] = 2)       
			AND [ad].[GUID] IS NULL   
		
		DECLARE @MaxAdNumber INT 
		SET @MaxAdNumber = 0
		SELECT @MaxAdNumber = ISNULL(MAX(Number), 0) FROM ad000
		
		DELETE FROM #Temp WHERE Guid IN
		(
			SELECT Temp.Guid FROM #Temp Temp
			INNER JOIN ad000 ad ON Temp.Sn = ad.Sn AND Temp.inVal = ad.inVal AND Temp.ParentGuid = ad.ParentGuid AND Temp.inCurrencyGUID = ad.inCurrencyGUID AND Temp.snGuid = ad.snGuid AND Temp.billGUID = ad.billGUID
		)
		INSERT INTO [ad000]    
		( Guid,  Sn, [inVal], [ParentGuid], [inCurrencyGUID], [inCurrencyVal], snGuid, inDate, billGUID, Number, status, Security, BrGuid,Notes, PurchaseOrderDate)    
		SELECT	Guid
				,Sn     
				,[inVal]
				,[ParentGuid]
				,[inCurrencyGUID]
				,[inCurrencyVal]
				,snGuid
				,inDate
				,billGUID
				,Number + @MaxAdNumber
				,1
				,1 
				,BuBranchGuid
				,BiNote
				,inDate
		FROM #Temp   
		DROP TABLE #Temp   
	END      
#########################################################
#END