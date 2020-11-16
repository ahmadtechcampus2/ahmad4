###########################################################################
CREATE PROCEDURE prcGetFirstInFirstOutPrise
@StartDate [DATETIME], 
	@EndDate [DATETIME], 
	@CurrencyGUID [UNIQUEIDENTIFIER] = 0X00 
	/* 
		This Prosedure allow you to calc cost First in First out Price 
	*/ 
AS 
	SET NOCOUNT ON 
	 
	DECLARE @t_Result TABLE(  
			[GUID] [UNIQUEIDENTIFIER],  
			[Qnt] [FLOAT],  
			[Price] [FLOAT]) 
	DECLARE 
			-- mt table variables declarations: 
			@mtGUID [UNIQUEIDENTIFIER], 
			@mtQnt [FLOAT], 
			@mtQnt2 [FLOAT],  
			@mtPrice [FLOAT],  
			@mtValue [FLOAT],  
			-- bi cursor input variables declarations:  
			@buGUID				[UNIQUEIDENTIFIER], 
			@buDate 			[DATETIME],  
			@biNumber 			[INT],  
			@biMatPtr 			[UNIQUEIDENTIFIER], 
			@biQnt 				[FLOAT],  
			@biUnitPrice 			[FLOAT],  
			@biBaseBillType			[INT], 
			@id				[INT]  
	DECLARE @c_bi CURSOR   
	CREATE TABLE #RESULT 
		( 
			[buGUID]			[UNIQUEIDENTIFIER], 
			[buNumber]			[INT], 
			[buDate] 			[DATETIME], 
			[buDirection] 		[INT], 
			[biNumber] 			[INT], 
			[biMatPtr]			[UNIQUEIDENTIFIER], 
			[biQnt]				[FLOAT], 
			[biUnitPrice] 			[FLOAT], 
			[biBaseBillType]		[INT], 
			[buSortFlag] 			[INT] 
		) 
	INSERT INTO #RESULT 
	SELECT 
			[buGUID], 
			[buNumber], 
			[buDate], 
			[buDirection], 
			[biNumber], 
			[biMatPtr], 
			[biQty] + [biBonusQnt], 
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN ([btAffectCostPrice]*[FixedbiUnitPrice]) - ([btDiscAffectCost]*[FixedbiUnitDiscount]) + ([btExtraAffectCost]*[FixedbiUnitExtra]) ELSE 0 END, -- CASE WHEN UserReadPriceSecurity >= BuSecurity THEN FixedBiPrice / (CASE mtUnitFact WHEN 0 THEN 1 ELSE mtUnitFact END) ELSE 0 END,
	        [btBillType], 
			[buSortFlag] 
		FROM 
			(([dbo].[fnExtended_Bi_Fixed](@CurrencyGUID) AS [r] 
			INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[BuType] = [bt].[TypeGUID]) 
			INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGuid]) 
			--INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [co].[biStorePtr] 
		WHERE 
			[buIsPosted] > 0 AND [buDate] BETWEEN @StartDate AND @EndDate  
			AND [bt].[UserSecurity] >= [r].[buSecurity] 
			AND NOT([r].[btType] = 3 OR [r].[btType] = 4 ) 
	CREATE INDEX [RESIND] ON [#RESULT]([biMatPtr],[buNumber],[buDate],[buDirection],[biNumber],[buSortFlag])  
	CREATE TABLE [#IN_RESULT] 
		( 
			[ID]				[INT] IDENTITY(1,1), 
			[buGUID]			[UNIQUEIDENTIFIER], 
			[buNumber]			[INT], 
			[buDate] 			[DATETIME], 
			[biNumber] 			[INT], 
			[biMatPtr]			[UNIQUEIDENTIFIER], 
			[biQnt]				[FLOAT], 
			[biUnitPrice] 		[FLOAT], 
			[biBaseBillType]	[INT], 
			[buSortFlag] 		[INT] 
		)
	INSERT INTO [#IN_RESULT] ([buGUID],[buNumber],[buDate],[biNumber],[biMatPtr],[biQnt],[biUnitPrice],[biBaseBillType],[buSortFlag])  
		SELECT 
			[buGUID],[buNumber],[buDate],[biNumber],[biMatPtr],[biQnt],[biUnitPrice], 
			[biBaseBillType],[buSortFlag] 
		FROM [#RESULT] 
		WHERE [buDirection] > 0 
		ORDER BY  
			[biMatPtr], 
			[buDate], 
			[buSortFlag], 
			[buNumber], 
			[biNumber]  
	CREATE CLUSTERED INDEX INRESIND ON [#IN_RESULT]([ID],[biMatPtr]) 
	SET @id = 0 
	SET @c_bi = CURSOR FAST_FORWARD FOR  
		SELECT   
			[biMatPtr],   
			[biQnt] 
		FROM  
			[#Result]  
		WHERE  
			[buDirection] = -1 
		ORDER BY  
			[biMatPtr],   
			[buDate],   
			[buSortFlag],   
			[buNumber], 
			[biNumber] 
	OPEN @c_bi FETCH NEXT FROM @c_bi INTO 
		@biMatPtr,   
		@biQnt 
	SET @mtGUID = @biMatPtr  
	-- reset variables:  
	SET @mtQnt = 0  
	SET @mtPrice = 0  
	WHILE @@FETCH_STATUS = 0  
	BEGIN  
		-- is this a new material ?  
		IF @mtGUID <> @biMatPtr 
		BEGIN  
			-- insert the material record:  
			/* 
			INSERT INTO @t_Result VALUES(  
				@mtGUID,  
				@mtQnt,    
				@mtPrice) 
				*/  
			-- reset mt variables:  
			SET @mtGUID = @biMatPtr  
			SET @mtQnt = 0  
			SET @mtPrice = 0  
		END 
		SET @mtQnt = @biQnt   
		WHILE (@mtQnt > 0) 
		BEGIN  
			SELECT @ID = [ID],@mtQnt2 = [biQnt],@mtPrice = [biUnitPrice] FROM [#IN_RESULT]
			WHERE [biMatPtr] = @mtGUID AND [ID] = (SELECT MIN([ID]) FROM [#IN_RESULT] 
			WHERE [biQnt] >  0 AND [biMatPtr] = @mtGUID) 
			IF (@@ROWCOUNT = 0) 
			BEGIN 
				SET @mtQnt = 0 
				SET @mtPrice = 0 
				BREAK 
			END  
			IF (@mtQnt > @mtQnt2) 
			BEGIN 
				SET @mtQnt = @mtQnt - @mtQnt2 
				UPDATE [#IN_RESULT] SET [biQnt] = 0 WHERE [ID] = @ID   
			END 
			ELSE 
			BEGIN	 
				UPDATE [#IN_RESULT] SET [biQnt] = @mtQnt2 - @mtQnt WHERE [ID] = @ID   
				SET @mtQnt = 0  
			END 
		END 
		FETCH NEXT FROM @c_bi INTO 
			@biMatPtr,   
			@biQnt 
	END 
	/* 
	INSERT INTO @t_Result VALUES(  
		@mtGUID,  
		@mtQnt,    
		@mtPrice)  
		*/ 
	CLOSE @c_bi DEALLOCATE @c_bi 
		--return result Set 
	CREATE TABLE #Qnt_RESULT(
		[MaterialGUID] [UNIQUEIDENTIFIER],  
		[SumQnt] [FLOAT])

  INSERT INTO #Qnt_RESULT([MaterialGUID],[SumQnt])
  SELECT 
	[biMatPtr],
	SUM([biQnt]) 
  FROM 
		[#IN_RESULT] 
  WHERE 
		[biQnt]>0  
  GROUP BY 
		[biMatPtr]
 
	
	INSERT INTO @t_Result 
	SELECT 
		[biMatPtr], 
		SUM([biQnt]) ,
		SUM([biUnitPrice] * [biQnt]) / ISNULL((SELECT SUM([SumQnt]) FROM [#Qnt_RESULT] AS qnt WHERE r.[biMatPtr] = qnt.[MaterialGUID]), 1)
	FROM 
		[#IN_RESULT] AS r
	WHERE 
		[biQnt] > 0  
	GROUP BY 
			[biMatPtr]
		
	INSERT INTO [#t_Prices] 
 		SELECT 
			ISNULL( [r].[GUID],  [mtTbl].[MatGuid]),  
			ISNULL( [r].[Price], 0) 
		FROM  
			@t_Result AS [r]  
			INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[GUID] = [mtTbl].[MatGuid] 
  
###########################################################################
#END