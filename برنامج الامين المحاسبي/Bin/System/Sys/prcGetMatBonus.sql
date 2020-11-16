#######################################################################################
CREATE PROCEDURE prcGetMatBonus
	@Qty		[FLOAT], 
	@buDate		[DATETIME], 
	@mtGuid		[UNIQUEIDENTIFIER], 
	@Unit		[INT], 
	@btGuid		[UNIQUEIDENTIFIER],  
	@cuGuid		[UNIQUEIDENTIFIER] = 0x0, 
	@coGuid		[UNIQUEIDENTIFIER] = 0x0 
AS 
	SET NOCOUNT ON 
	 
	IF NOT EXISTS ( SELECT TOP 1 [GUID] FROM [SM000])	 
		RETURN  

	CREATE TABLE [#Result] 
	( 
		[Guid]				UNIQUEIDENTIFIER,
		[Number]			FLOAT,
		[Type]				INT,
		[MatPtr1]			UNIQUEIDENTIFIER,
		[Qty1]				FLOAT,
		[Unity1]			INT,
		[StartDate]			DATETIME,
		[EndDate]			DATETIME,
		[Notes]				NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[Main]				BIT,
		[GroupGUID]			UNIQUEIDENTIFIER,
		[bIncludeGroups]	BIT,
		[PriceType]			INT,
		[Discount]			FLOAT,
		[DiscountType]		INT,
		[CustAccGUID]		UNIQUEIDENTIFIER,
		[OfferAccGUID]		UNIQUEIDENTIFIER,
		[IOfferAccGUID]		UNIQUEIDENTIFIER,
		[bAllBt]			INT,
		[ItemOrd]			INT,
		[MatPtr2]			UNIQUEIDENTIFIER,
		[Qty2]				FLOAT,
		[Unity2]			FLOAT,
		[Price]				FLOAT,
		[Flag]				INT,
		[CurPtr]			UNIQUEIDENTIFIER,
		[CurVal]			FLOAT,
		[Policy]			INT,
		[bBonus]			BIT
	) 

	CREATE TABLE [#Accounts]( [GUID] [UNIQUEIDENTIFIER]) 
	DECLARE @acGUID [UNIQUEIDENTIFIER] 
	SELECT @acGUID = [cuAccount] FROM [vwCu] WHERE [cuGuid] = @cuGuid 
	IF ISNULL( @cuGuid, 0x0) != 0x0  
	BEGIN 
		INSERT INTO [#Accounts] SELECT @acGUID 
		INSERT INTO [#Accounts] SELECT [GUID] FROM [dbo].[fnGetAccountParents]( @acGUID) 

		INSERT INTO [#Accounts] SELECT [ParentGUID] FROM [ci000] WHERE [SonGuid] = @acGUID
	END  

	CREATE TABLE [#CostTbl]( [CostGuid] [UNIQUEIDENTIFIER])  
	IF ISNULL( @coGuid, 0x0) != 0x0  
	BEGIN 
		INSERT INTO [#CostTbl] SELECT @coGuid 
		INSERT INTO [#CostTbl] SELECT [GUID] FROM [dbo].[fnGetCostParents]( @coGuid) 
	END  

	DECLARE @gGroup [UNIQUEIDENTIFIER]  
	SELECT @gGroup = [mtGroup] FROM [vwMt] WHERE [mtGUID] = @mtGuid 
	
	DECLARE @biMatUnitFact INT
	SET @biMatUnitFact = (
		SELECT 
			CASE @Unit 
				WHEN 2 THEN (CASE WHEN [mtUnit2Fact] = 0 THEN 1 ELSE [mtUnit2Fact] END) 
				WHEN 3 THEN (CASE WHEN [mtUnit3Fact] = 0 THEN 1 ELSE [mtUnit3Fact] END) 
				ELSE 1 
			END 
		FROM 
			[vwMt] 
		WHERE 
			[mtGUID] = @mtGuid)
	INSERT INTO [#Result]
	SELECT  
		[smGuid],
		[smNumber],
		[smType],
		[smMatGUID],
		[smQty],
		[smUnity],
		[smStartDate],
		[smEndDate],
		[smDescription],
		[smbAddMain],
		[smGroupGUID],
		[smIncludeGroups],
		[smPriceType],
		[smDiscount],
		[smDiscountType],
		[smCustAccGUID],
		[smOfferAccGUID], 
		[smIOfferAccGUID],
		[smAllBillTypes], 
		[sdItem], 
		(CASE [smType]  
			WHEN 2 THEN [sdMatPtr]  
			ELSE (CASE ISNULL( [sdMatPtr], 0x0) 
					WHEN 0x0 THEN @mtGuid 
					ELSE [sdMatPtr] END) 
		END),
		[sdQty] * ((@Qty * @biMatUnitFact) / ([smQty] * (SELECT CASE(CASE [smUnity] WHEN 2 THEN mtUnit2Fact WHEN 3 THEN mtUnit3Fact WHEN 4 THEN mtDefUnitFact ELSE 1 END) WHEN 0 THEN 1 ELSE (CASE [smUnity] WHEN 2 THEN mtUnit2Fact WHEN 3 THEN mtUnit3Fact WHEN 4 THEN mtDefUnitFact ELSE 1 END) END FROM vwMt WHERE mtGUID = (CASE smMatGUID WHEN 0x0 THEN @mtGuid ELSE smMatGUID END)))),
		[sdUnity],  
		[sdPrice],  
		[sdPriceFlag],  
		[sdCurrencyPtr],  
		[sdCurrencyVal],  
		[sdPolicyType],
 		[sdBonus]
	FROM
		[vwSmSd]
	WHERE
		(
		([smCustCondGUID] = 0x0) AND ([smMatCondGUID] = 0x0))
		AND 
		(
			(ISNULL(@mtGuid, 0x0) = 0x0) 
			OR 
			([smMatGUID] = @mtGuid) 
			OR
			(
				([smGroupGUID] != 0x0)
				AND 
				(
					[smGroupGUID] =  
					(CASE [smIncludeGroups]  
						WHEN 0 THEN (@gGroup) 
						ELSE (SELECT 
								CASE 
									WHEN @gGroup = [smGroupGUID] THEN @gGroup 
									ELSE (SELECT [GUID] FROM [dbo].[fnGetGroupParents](@gGroup) WHERE [GUID] = smGroupGUID)
								END)
					END)
				)
			)
		) 
		AND( [smActive] = 1)
		AND( (@buDate = '1/1/1980') OR (@buDate BETWEEN [dbo].[fnGetDateFromDT]([smStartDate]) AND [dbo].[fnGetDateFromDT]([smEndDate]))) 
		AND( (@Qty = -1) OR  
		(@Qty * (SELECT 
					CASE @Unit 
						WHEN 2 THEN (CASE WHEN [mtUnit2Fact] = 0 THEN 1 ELSE [mtUnit2Fact] END )
						WHEN 3 THEN  (CASE WHEN [mtUnit3Fact] = 0 THEN 1 ELSE [mtUnit3Fact] END )
						ELSE 1 END 
				FROM 
					[vwMt] 
				WHERE 
					[mtGUID] = @mtGuid ) /  
			(SELECT
				CASE [smUnity] 
					WHEN 2 THEN (CASE WHEN [mtUnit2Fact] = 0 THEN 1 ELSE [mtUnit2Fact] END )
					WHEN 3 THEN  (CASE WHEN [mtUnit3Fact] = 0 THEN 1 ELSE [mtUnit3Fact] END )
					WHEN 4 THEN (CASE WHEN [mtDefUnitFact] = 0 THEN 1 ELSE [mtDefUnitFact] END)
					ELSE 1 
				END
			FROM 
				[vwMt] 
			WHERE 
				[mtGUID] = @mtGuid ) >= [smQty])) 
		AND( [smAllBillTypes] = 1 OR @btGuid = 0x0 OR @btGuid IN (select [btGuid] FROM [smBt000] WHERE [ParentGUID] = [smGuid])) 
		AND( [smCustAccGUID] = 0x0 OR [smCustAccGUID] IN( SELECT [GUID] FROM [#Accounts])) 
		AND( [smCostGUID] = 0x0 OR [smCostGUID] IN( SELECT [CostGuid] FROM [#CostTbl])) 

	IF NOT EXISTS( SELECT * FROM [#Result])
	BEGIN 
		DECLARE  
			@C CURSOR, 
			@smGUID UNIQUEIDENTIFIER, 
			@smMatGUID UNIQUEIDENTIFIER, 
			@smGroupGUID UNIQUEIDENTIFIER, 
			@smMatCond UNIQUEIDENTIFIER, 
			@smIncludeGroups BIT, 
			@smAccountGUID UNIQUEIDENTIFIER, 
			@smCustCond UNIQUEIDENTIFIER 
			-- @smCostGUID UNIQUEIDENTIFIER 
	
		DECLARE  
			@found	BIT, 
			@g		UNIQUEIDENTIFIER 
		SET @C = CURSOR FAST_FORWARD FOR  
			SELECT 
				[Guid], 
				[MatGUID], 
				[GroupGUID], 
				[bIncludeGroups], 
				[MatCondGUID], 
				[CustAccGUID], 
				[CustCondGUID] -- , [CostGUID] 
			FROM  
				[sm000] [sm] 
			WHERE  
				([bActive] = 1) 
				AND ((@buDate = '1/1/1980') OR ( @buDate BETWEEN [dbo].[fnGetDateFromDT]( [StartDate]) AND [dbo].[fnGetDateFromDT]( [EndDate]))) 
				AND(( @Qty = -1) OR  
				( @Qty * (SELECT CASE @Unit WHEN 2 THEN ( CASE WHEN [mtUnit2Fact] = 0 THEN 1 ELSE [mtUnit2Fact] END) WHEN 3 THEN ( CASE WHEN [mtUnit3Fact] = 0 THEN 1 ELSE [mtUnit3Fact] END) ELSE 1 END FROM [vwMt] WHERE [mtGUID] = @mtGuid) /  
				( SELECT CASE [Unity] WHEN 2 THEN ( CASE WHEN [mtUnit2Fact] = 0 THEN 1 ELSE [mtUnit2Fact] END) WHEN 3 THEN ( CASE WHEN [mtUnit3Fact] = 0 THEN 1 ELSE [mtUnit3Fact] END) ELSE 1 END FROM [vwMt] WHERE [mtGUID] = @mtGuid) >= [Qty])) 
				AND( [bAllBt] = 1 OR @btGuid = 0x0 OR @btGuid IN( SELECT [btGuid] FROM [smBt000] WHERE [ParentGUID] = [sm].[Guid])) 
				AND( [CostGUID] = 0x0 OR [CostGUID] IN( SELECT [CostGuid] FROM [#CostTbl])) 
				AND( ([CustCondGUID] != 0x0) OR ([MatCondGUID] != 0x0)) 
		------------------------------------------------------------ 
		------------------------------------------------------------ 
		OPEN @C FETCH NEXT FROM @C INTO @smGUID, @smMatGUID, @smGroupGUID, @smIncludeGroups, @smMatCond, @smAccountGUID, @smCustCond 
		WHILE (@@FETCH_STATUS = 0) AND NOT EXISTS( SELECT * FROM [#Result])
		BEGIN  
			DECLARE @bMat BIT, @bAcc BIT  
			SET @bMat = 0 
			IF (@smMatGUID = @mtGuid) AND (@mtGuid != 0x0) 
				SET @bMat = 1 
			ELSE BEGIN  
				SELECT @g = [mtGroup] FROM [vwMt] WHERE [mtGUID] = @mtGuid 
				IF @smMatCond = 0x0 
				BEGIN 
					IF @smGroupGUID = 0x0  
						SET @bMat = 0 
					ELSE BEGIN 
						IF @smIncludeGroups = 0 
						BEGIN  
							IF @smGroupGUID = @g  
								SET @bMat = 1 
						END ELSE BEGIN  
							IF (EXISTS (SELECT [Guid] FROM [dbo].[fnGetGroupParents]( @g) WHERE [GUID] = @smGroupGUID)) OR (@smGroupGUID = @g) 
								SET @bMat = 1							 
						END  
					END  
				END ELSE BEGIN  
					EXEC @found = prcIsMatCondVerified @smMatCond, @mtGuid 
					IF @smGroupGUID = 0x0 
					BEGIN  
						SET @bMat = @found 
					END ELSE BEGIN  
						IF @smIncludeGroups = 0 
						BEGIN  
							IF (@smGroupGUID = @g) AND (@found = 1) 
								SET @bMat = 1 
						END ELSE BEGIN  
							IF ((EXISTS (SELECT [Guid] FROM [dbo].[fnGetGroupParents]( @g) WHERE [GUID] = @smGroupGUID)) OR (@smGroupGUID = @g)) AND (@found = 1) 
								SET @bMat = 1							 
						END  
					END  
				END  
			END  
			IF @bMat = 1 
			BEGIN  
				SET @bAcc = 0 
				IF ISNULL( @smCustCond, 0x0) = 0x0 
				BEGIN  
					IF (@smAccountGUID = 0x0) OR EXISTS( SELECT * FROM [#Accounts] WHERE [GUID] = @smAccountGUID) 
						SET @bAcc = 1 
				END ELSE BEGIN  
					EXEC @found = prcIsCustCondVerified @smCustCond, @cuGuid 
					IF ((@smAccountGUID = 0x0) OR EXISTS( SELECT * FROM [#Accounts] WHERE [GUID] = @smAccountGUID)) AND @found = 1  
						SET @bAcc = 1 
				END  
				IF @bAcc = 1 
				BEGIN  
					INSERT INTO [#Result] 
					SELECT  
						[smGuid], 
						[smNumber], 
						[smType], 
						[smMatGUID],  
						[smQty],  
						[smUnity],  
						[smStartDate],  
						[smEndDate],  
						[smDescription],  
						[smbAddMain], 
						[smGroupGUID], 
						[smIncludeGroups], 
						[smPriceType], 
						[smDiscount], 
						[smDiscountType],
						[smCustAccGUID], 
						[smOfferAccGUID], 
						[smIOfferAccGUID], 
						[smAllBillTypes], 
						[sdItem], 
						(CASE [smType]  
							WHEN 2 THEN [sdMatPtr]  
							ELSE (CASE ISNULL( [sdMatPtr], 0x0) WHEN 0x0 THEN @mtGuid ELSE [sdMatPtr] END) 
						END), 
						[sdQty],  
						[sdUnity],  
						[sdPrice],  
						[sdPriceFlag],  
						[sdCurrencyPtr],  
						[sdCurrencyVal],  
						[sdPolicyType], 
						[sdBonus] 
					FROM 	 
						[vwSmSd] 
					WHERE  
						[smGuid] = @smGUID 
				END  
			END  
			FETCH NEXT FROM @C INTO @smGUID, @smMatGUID, @smGroupGUID, @smIncludeGroups, @smMatCond, @smAccountGUID, @smCustCond -- , @smCostGUID 
		END  
		CLOSE @C DEALLOCATE @C   
	END 
	SELECT * FROM [#Result] ORDER BY [Number] DESC, [ItemOrd] 

#######################################################################################
#END
