#################################################################
CREATE  PROC prc_SpecialOffersBelongToPFC
		@PFCGuid UNIQUEIDENTIFIER 
AS
BEGIN
	SET NOCOUNT ON
	SELECT DISTINCT SO.Guid 'SGuid' INTO #Temp
	FROM  
	SpecialOffers000  SO		LEFT JOIN 
	SOBillTypes000 SOBillTypes
	ON SO.guid = SOBillTypes.specialofferGUID 
	WHERE SOBillTypes.BillTypeGUID in 
	(	
		SELECT SubPFCBillTypes.TypeGuid FROM 
		SubProfitCenter000 SubPFC inner join 
		SubProfitCenterBill_EN_Type000 SubPFCBillTypes
		ON SubPFC.GUID = SubPFCBillTypes.ParentGUID
		WHERE SubPFC.GUID =  @PFCGuid
	) OR BillTypeGuid is NULL


	DECLARE @PFCGroups TABLE ([GroupGUID] [UNIQUEIDENTIFIER]);
	
	DECLARE @GroupGuid [UNIQUEIDENTIFIER]
	DECLARE @Cursor CURSOR
		SET @Cursor = CURSOR FAST_FORWARD
		FOR
			--GET SELECTED GROUPS FROM SELECTED PFC
			SELECT GroupGuid FROM PFCRelatedGroups000 WHERE [PFCGuid]= @PFCGuid

		OPEN @Cursor FETCH NEXT FROM @Cursor INTO @GroupGuid

		WHILE @@FETCH_STATUS = 0
		BEGIN
			--EXTRACT ALL SUB GROUPS FOR SELECTED PFC
			INSERT INTO @PFCGroups
				SELECT * FROM [dbo].[fnGetGroupsList] (@GroupGuid)
			FETCH NEXT FROM @Cursor
			INTO @GroupGuid
		END

	CLOSE @Cursor
	DEALLOCATE @Cursor
	
	--GET ALL GROUPS USED BY SPECIAL OFFER SYSTEM
	DECLARE @SOGroups TABLE ([SOGUID] [UNIQUEIDENTIFIER], [SOIGroup] [UNIQUEIDENTIFIER],[SOOIGroup] [UNIQUEIDENTIFIER], [SOCDGroup] [UNIQUEIDENTIFIER], [SOType] [INT]);
	INSERT INTO @SOGroups
		SELECT 
			SO.GUID,
			CASE WHEN SOI.ItemType = 0 THEN (SELECT GroupGUID FROM [mt000] WHERE GUID= SOI.ItemGUID) WHEN SOI.ItemType = 1 THEN SOI.ItemGUID ELSE 0x0 END SOIGroup,
			CASE WHEN SOOI.ItemType = 0 THEN (SELECT GroupGUID FROM [mt000] WHERE GUID= SOOI.ItemGUID) WHEN SOOI.ItemType = 1 THEN SOOI.ItemGUID ELSE 0x0 END SOOIGroup,
			CASE WHEN SOCD.ItemType = 0 THEN (SELECT GroupGUID FROM [mt000] WHERE GUID= SOCD.ItemGUID) WHEN SOCD.ItemType = 1 THEN SOCD.ItemGUID ELSE 0x0 END SOCDGroup,
			SO.Type
		FROM  SpecialOffers000 SO
			LEFT JOIN SOItems000 SOI ON SO.GUID = SOI.SpecialOfferGUID
			LEFT JOIN SOOfferedItems000 SOOI ON SO.GUID = SOOI.SpecialOfferGUID
			LEFT JOIN SOConditionalDiscounts000 SOCD ON SO.GUID = SOCD.SpecialOfferGUID
	--MERGE THEM IN ONE COLUMN
	DECLARE @Result TABLE ([SOGUID] [UNIQUEIDENTIFIER], [GroupGUID] [UNIQUEIDENTIFIER]);
	INSERT INTO @Result
	SELECT DISTINCT SOGUID,GROUPGUID
	FROM (
		SELECT SOGUID,SOIGROUP AS GROUPGUID,[SOType] FROM @SOGroups
		UNION ALL
		SELECT SOGUID,SOOIGROUP AS GROUPGUID,[SOType] FROM @SOGroups
		UNION ALL
		SELECT SOGUID,SOCDGROUP AS GROUPGUID,[SOType] FROM @SOGroups
		) SOGROUPS
	WHERE GROUPGUID <> 0x0 OR [SOType]= 4--THOSE WHERE THE TYPE CONIDITION SYSTEM IS USED, YOU NEED TO CONFIGURE CONDITION COPY ALSO.
	
	--CANCEL OFFERS THAT USE UN DEFINED GROUPS IN THE SELECTED PFC
	DELETE FROM @Result
		WHERE SOGUID IN
			(
			SELECT DISTINCT SOGUID
				FROM @Result
			WHERE GroupGUID NOT IN (SELECT DISTINCT GroupGUID FROM @PFCGroups)
			) AND GROUPGUID <> 0x0
	
	--FINAL RESULT
	SELECT DISTINCT SOffer.* FROM 
	@Result Res INNER JOIN SpecialOffers000 SOffer ON SOffer.Guid = Res.SOGUID
	INNER JOIN #Temp Temp ON Temp.SGuid = SOffer.GUID
END
#################################################################
CREATE FUNCTION prc_GetDateOfLastBillUsesOffer( @SOGUID UNIQUEIDENTIFIER) 
      RETURNS DATETIME 
AS  
BEGIN  
     DECLARE @MaxDate1 DATETIME
     DECLARE @MaxDate2 DATETIME
     
	SELECT @MaxDate1 = MAX(bu.buDate)
               FROM vwbubi bu
               INNER JOIN 
               SOItems000 soi ON soi.GUID = bu.biSOGUID    
               INNER JOIN 
               SpecialOffers000 so ON so.GUID = soi.SpecialOfferGUID
               WHERE so.GUID = @SOGUID
                     
    SELECT @MaxDate2 = MAX(bu.buDate)
           FROM vwbubi bu
           INNER JOIN 
           SOOfferedItems000 soi ON soi.GUID = bu.biSOGUID   
           INNER JOIN 
           SpecialOffers000 so ON so.GUID = soi.SpecialOfferGUID
           WHERE so.GUID = @SOGUID
           
           IF (@MaxDate1 > @MaxDate2)   
			RETURN  @MaxDate1
		   
	RETURN  @MaxDate2
END
#################################################################
CREATE PROC PrcAddLinkedPFCServer
			@serverName NVARCHAR(50),
			@userName	NVARCHAR(50),
			@password	NVARCHAR(50),
			@isWindowsAuthintication BIT
AS
	SET NOCOUNT ON
	
	DECLARE @Result	INT
	
	IF ISNULL(@serverName, N'') = N'' 
	BEGIN
		SELECT 0 AS 'Success' 
		RETURN
	END
	
	IF  NOT EXISTS (SELECT * FROM  sys.sysservers WHERE srvName = @serverName)
	BEGIN
		EXEC @Result = sp_addlinkedserver @serverName 
		IF @Result = 1
		BEGIN
			SELECT 0 AS 'Success' 
			RETURN
		END	
	END					
	
	DECLARE @useself varchar(8)
	IF @isWindowsAuthintication = 0
		SET @useself = 'FALSE'
	ELSE
		SET @useself = 'TRUE'
	
	EXEC @Result = sp_addlinkedsrvlogin  @serverName, @useself, NULL, @userName, @password
		 
	IF @Result = 1
	BEGIN
		SELECT 0 AS 'Success' 
		RETURN
	END	
	ELSE
	BEGIN
		SELECT 1 AS 'Success' 
		RETURN
	END	
#################################################################
CREATE PROCEDURE prcShipmentReport
	@StartDate 			[DATETIME],  
	@EndDate 			[DATETIME],  
	@MatGUID 			[UNIQUEIDENTIFIER], 
	@GroupGUID 			[UNIQUEIDENTIFIER],   
	@ProfitCenterGUID	[UNIQUEIDENTIFIER],   
	@UseUnit 			[INT], 		--	1: unit1  2: unit2  3: unit3  4: default unit  
	@ShipmentOrReturn	[INT], -- 1 Shipment to PFC ONLY, 2 Shipment From PFC ONLY, 3 both Shipments to and from PFC ONLY,
	@DeliveredOrOnRoad	[INT], -- 1 On road Shipments ONLY, 2 Delivered Shipments ONLY, 3 both delivered Shipments and On road ones,
	@ProviderGuid		[UNIQUEIDENTIFIER] = 0x0,
	@CondGuid			[UNIQUEIDENTIFIER] = 0x00,
	@Mode				[INT]	= 1 -- 1: Center Price, 2:Purchasing Price
AS 
BEGIN
	SET NOCOUNT ON  
	DECLARE @Lang [INT];
	SET @Lang = dbo.fnConnections_GetLanguage();
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	 
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	CREATE TABLE [#Result]  
	( 
		[ShipmentGUID]						[UNIQUEIDENTIFIER] ,
		[ShipmentNumber]					[INT],
		[ShipmentType]						[INT], -- 1 To , 2 From
		[ShipmentDate] 						[DATETIME],
		[PFCName]							[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[PFCLatinName]						[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[MtGuid]							[UNIQUEIDENTIFIER],
		[MtName]							[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[MtCode]							[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[MtLatinName]						[NVARCHAR](255) COLLATE ARABIC_CI_AI,    
		[biQty] 							[FLOAT],  
		[biPrice] 							[FLOAT],
		[ShipmentStatus]					[INT], -- 1 On-Road , 2 Delivered
		[mtSecurity]						[INT],
		[biNumber]							[INT],
		[ProviderName]						[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[biUnit]							[NVARCHAR](255),
		[BuGUID]						[UNIQUEIDENTIFIER],
		[BiGUID]						[UNIQUEIDENTIFIER]
	)
	--Filling temporary tables  
	INSERT INTO [#MatTbl]	EXEC [prcGetMatsList] 	@MatGUID, @GroupGUID, 0, @CondGuid  
	DECLARE @ShipmentStatusOnRoad [INT], @ShipmentStatusDelivered [INT], @ShipmentToPFC [INT], @ShipmentFromPFC [INT], @ShipmentFromPFCWithReturn [INT], @ShipmentToPFCWithPurch [INT]
	SET @ShipmentToPFC = 1  SET @ShipmentFromPFC = 2 SET @ShipmentToPFCWithPurch = 4 SET @ShipmentFromPFCWithReturn = 8
	SET @ShipmentStatusOnRoad = 1  SET @ShipmentStatusDelivered = 2
	SELECT * INTO #ShipmentBillTempTable 
	FROM	PFCShipmentBill000
	WHERE 
	(Type = CASE WHEN (@ShipmentOrReturn & @ShipmentToPFC)				<> 0 THEN 1 ELSE 0 END) OR
	(Type = CASE WHEN (@ShipmentOrReturn & @ShipmentFromPFC)			<> 0 THEN 2 ELSE 0 END) OR
	(Type = CASE WHEN (@ShipmentOrReturn & @ShipmentToPFCWithPurch)		<> 0 THEN 3 ELSE 0 END) OR
	(Type = CASE WHEN (@ShipmentOrReturn & @ShipmentFromPFCWithReturn)	<> 0 THEN 4 ELSE 0 END)
	IF (@Mode = 1) 
	BEGIN
	INSERT INTO [#Result]
	SELECT DISTINCT Shipment.Guid, Shipment.Number, Shipment.Type, Shipment.Date, SubPFC.Name, SubPFC.LatinName, MatTable.[Guid], MatTable.Name, MatTable.Code,  MatTable.LatinName,
		(CASE 
			(CASE @UseUnit WHEN 4 THEN defunit ELSE @UseUnit END) 	
						WHEN 1 THEN (bubi.biQty)    
		  				WHEN 2 THEN (  
		  								CASE WHEN [Unit2Fact] <> 0 THEN
		  								(bubi.biQty)/ [Unit2Fact] 
		  								ELSE
		  								(
		  									CASE WHEN bubi.biQty2  <> 0 THEN 
		  										bubi.biQty2 
		  									ELSE
		  										bubi.biQty
		  									END
		  								)
		  								END
		  							)      
						WHEN 3 THEN (  
	  									CASE WHEN [Unit3Fact] <> 0 THEN
	  									(bubi.biQty)/ [Unit3Fact] 
	  									ELSE
	  									(
	  										CASE WHEN bubi.biQty3  <> 0 THEN 
	  											bubi.biQty3 
	  										ELSE
	  											bubi.biQty
	  										END
	  									)
	  									END
		  							)
		 END
		)
		, 
		(CASE 
			(CASE @UseUnit WHEN 4 THEN defunit ELSE @UseUnit END)
						WHEN 1 THEN ( bubi.biPrice )    
		  				WHEN 2 THEN (  
		  								CASE WHEN [Unit2Fact] <> 0 THEN
		  									 bubi.biPrice * [Unit2Fact] 
		  								ELSE
		  									 bubi.biPrice 
		  								END
		  							)      
						WHEN 3 THEN (  
										CASE WHEN [Unit3Fact] <> 0 THEN
		  									 bubi.biPrice * [Unit3Fact] 
		  								ELSE
		  									 bubi.biPrice 
		  								END
	  									
		  							)
		 END
		) / (CASE bubi.biUnity WHEN 1 THEN 1 WHEN 2 THEN (CASE WHEN [Unit2Fact] <> 0 THEN [Unit2Fact] ELSE 1 END) ELSE (CASE WHEN [Unit3Fact] <> 0 THEN [Unit3Fact] ELSE 1 END) END)
		,
		CASE WHEN (Shipment.DeliveryTransGuid <> 0x0) THEN @ShipmentStatusDelivered ELSE @ShipmentStatusOnRoad END
		,
		Mat.[mtSecurity]
		,
		bubi.biNumber biNumber,
		(CASE @Lang WHEN 0 THEN vtAc.Name ELSE (CASE vtAc.LatinName WHEN N'' THEN vtAc.Name ELSE vtAc.LatinName END) END) ProviderName
		,
		(CASE (CASE @UseUnit WHEN 4 THEN defunit ELSE @UseUnit END)
		 WHEN 1 THEN ( MatTable.Unity )    
		 WHEN 2 THEN ( CASE MatTable.Unit2 WHEN '' THEN  MatTable.Unity ELSE MatTable.Unit2 END)      
		 WHEN 3 THEN ( CASE MatTable.Unit3 WHEN '' THEN  MatTable.Unity ELSE MatTable.Unit3 END)    
		 END),
		 AssociatedBill.buGUID,
		 bubi.biGUID
		FROM 
			#ShipmentBillTempTable Shipment INNER JOIN
			ts000 Trans ON (Trans.GUID = ( CASE WHEN (@DeliveredOrOnRoad & @ShipmentStatusDelivered != 0)  
												THEN Shipment.DeliveryTransGuid END)	
										   OR 
							Trans.GUID = (CASE  WHEN (@DeliveredOrOnRoad & @ShipmentStatusOnRoad != 0)
												THEN Shipment.TransGuid END)
							)
			INNER JOIN vwbubi bubi ON bubi.buguid = Trans.InBillGUID
			LEFT JOIN vwBu AssociatedBill ON  (AssociatedBill.buGUID = Shipment.AssociatedBillGuid OR AssociatedBill.buGUID = 0x0)
			LEFT JOIN vtAc ON (vtAc.GUID = AssociatedBill.buCustAcc Or AssociatedBill.buGUID = 0x0)
			INNER JOIN [#MatTbl] Mat ON  bubi.biMatPtr = Mat.[MatGUID]
			INNER JOIN vtsubprofitcenter SubPFC ON SubPFC.GUID = Shipment.ProfitCenterGUID
			INNER JOIN mt000 MatTable ON MatTable.GUID = Mat.[MatGUID]
		WHERE 
		(ProfitCenterGUID = @ProfitCenterGUID OR @ProfitCenterGUID = 0x0)
		AND (AssociatedBill.buCustAcc =  @ProviderGuid OR @ProviderGuid = 0x0 )
		AND (	
				(	
					CASE WHEN (@DeliveredOrOnRoad & @ShipmentStatusOnRoad <> 0 )
					THEN  
						Shipment.Date
					END   BETWEEN @StartDate AND @EndDate 
				)
			OR (	
					CASE WHEN (@DeliveredOrOnRoad & @ShipmentStatusDelivered <> 0 )
					THEN  
						Shipment.DeliveryDate
					END   BETWEEN @StartDate AND @EndDate 
				)
			)
		AND (	
				(
					(	
						CASE WHEN (@DeliveredOrOnRoad & @ShipmentStatusOnRoad <> 0 )
						THEN  
							Shipment.TransGuid
						END   != 0x0
					) 
					AND
					(
						CASE WHEN (@DeliveredOrOnRoad & @ShipmentStatusOnRoad <> 0 )
						THEN  
							Shipment.DeliveryTransGuid
						END   = 0x0
					)
				)
				OR 
				(	
					CASE WHEN (@DeliveredOrOnRoad & @ShipmentStatusDelivered <> 0 )
					THEN  
						Shipment.DeliveryTransGuid
					END  != 0x0 
				)
			)
	END
	ELSE
	BEGIN
	INSERT INTO [#Result]
	SELECT DISTINCT Shipment.Guid, Shipment.Number, Shipment.Type, Shipment.Date, SubPFC.Name, SubPFC.LatinName, MatTable.[Guid], MatTable.Name, MatTable.Code,  MatTable.LatinName,
		(CASE 
			(CASE @UseUnit WHEN 4 THEN defunit ELSE @UseUnit END) 	
						WHEN 1 THEN (AssociatedBill.biQty)    
		  				WHEN 2 THEN (  
		  								CASE WHEN [Unit2Fact] <> 0 THEN
		  								(AssociatedBill.biQty)/ [Unit2Fact] 
		  								ELSE
		  								(
		  									CASE WHEN AssociatedBill.biQty2  <> 0 THEN 
		  										AssociatedBill.biQty2 
		  									ELSE
		  										AssociatedBill.biQty
		  									END
		  								)
		  								END
		  							)      
						WHEN 3 THEN (  
	  									CASE WHEN [Unit3Fact] <> 0 THEN
	  									(AssociatedBill.biQty)/ [Unit3Fact] 
	  									ELSE
	  									(
	  										CASE WHEN AssociatedBill.biQty3  <> 0 THEN 
	  											AssociatedBill.biQty3 
	  										ELSE
	  											AssociatedBill.biQty
	  										END
	  									)
	  									END
		  							)
		 END
		)
		, 
		(CASE 
			(CASE @UseUnit WHEN 4 THEN defunit ELSE @UseUnit END)
						WHEN 1 THEN ( AssociatedBill.biPrice )    
		  				WHEN 2 THEN (  
		  								CASE WHEN [Unit2Fact] <> 0 THEN
		  									 AssociatedBill.biPrice * [Unit2Fact] 
		  								ELSE
		  									 AssociatedBill.biPrice 
		  								END
		  							)      
						WHEN 3 THEN (  
										CASE WHEN [Unit3Fact] <> 0 THEN
		  									 AssociatedBill.biPrice * [Unit3Fact] 
		  								ELSE
		  									 AssociatedBill.biPrice 
		  								END
	  									
		  							)
		 END
		) / (CASE AssociatedBill.biUnity WHEN 1 THEN 1 WHEN 2 THEN (CASE WHEN [Unit2Fact] <> 0 THEN [Unit2Fact] ELSE 1 END) ELSE (CASE WHEN [Unit3Fact] <> 0 THEN [Unit3Fact] ELSE 1 END) END)
		,
		@ShipmentStatusDelivered
		,
		Mat.[mtSecurity]
		,
		AssociatedBill.biNumber biNumber,
		(CASE @Lang WHEN 0 THEN vtAc.Name ELSE (CASE vtAc.LatinName WHEN N'' THEN vtAc.Name ELSE vtAc.LatinName END) END) ProviderName
		,
		(CASE (CASE @UseUnit WHEN 4 THEN defunit ELSE @UseUnit END)
		 WHEN 1 THEN ( MatTable.Unity )    
		 WHEN 2 THEN ( CASE MatTable.Unit2 WHEN '' THEN  MatTable.Unity ELSE MatTable.Unit2 END)      
		 WHEN 3 THEN ( CASE MatTable.Unit3 WHEN '' THEN  MatTable.Unity ELSE MatTable.Unit3 END)    
		 END),
		 AssociatedBill.buGUID
		FROM 
			#ShipmentBillTempTable Shipment 
			INNER JOIN vwbubi AssociatedBill ON Shipment.AssociatedBillGuid  = AssociatedBill.buGUID
			LEFT JOIN vtAc ON (vtAc.GUID = AssociatedBill.buCustAcc)
			INNER JOIN [#MatTbl] Mat ON  AssociatedBill.biMatPtr = Mat.[MatGUID]
			INNER JOIN vtsubprofitcenter SubPFC ON SubPFC.GUID = Shipment.ProfitCenterGUID
			INNER JOIN mt000 MatTable ON MatTable.GUID = Mat.[MatGUID]
		WHERE 
		(ProfitCenterGUID = @ProfitCenterGUID OR @ProfitCenterGUID = 0x0)
		AND (AssociatedBill.buCustAcc =  @ProviderGuid OR @ProviderGuid = 0x0 )
		AND (Shipment.DeliveryDate   BETWEEN @StartDate AND @EndDate)
	END
	EXEC prcCheckSecurity
	--Master Result
	SELECT DISTINCT R.ShipmentGUID, 
					R.ShipmentNumber, 
					R.ShipmentType, 
					R.ShipmentDate, 
					R.PFCName, 
					R.PFCLatinName, 
					R.ShipmentStatus, 
					R.ProviderName,
					R.BuGUID
	FROM			[#Result] R
	ORDER BY		R.ShipmentDate
	--details Result
	SELECT DISTINCT	R.ShipmentGUID, 
			R.MtGuid, 
			R.MtName, 
			R.MtCode, 
			R.MtLatinName, 
			R.biNumber, 
			R.biPrice, 
			R.biQty,
			R.biUnit
	FROM	[#Result] R	
	--NextResult(0)
	SELECT	ShipmentType , 
			SUM(biQty) TotalQty, 
			SUM(biQty * biPrice ) Total 
	FROM		[#Result]
	GROUP BY	ShipmentType 
	--Viloation result
	SELECT * FROM [#SecViol]
END
#################################################################
CREATE PROCEDURE GetRelatedPFCMaterials
	@PFCGuid [UNIQUEIDENTIFIER]
AS
BEGIN
	SELECT DISTINCT Mat.* 
	FROM 
	mt000 Mat INNER JOIN 
	[dbo].[GetPFCMaterialsList](@PFCGuid) as res
	ON Mat.GUID = res.MaterialGUID
END
#################################################################
CREATE FUNCTION GetPFCMaterialsList (@PFCGuid [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE (
	[MaterialGUID]		[UNIQUEIDENTIFIER] ,
	[GroupGuid]			[UNIQUEIDENTIFIER])
AS
BEGIN
	DECLARE @GroupGuid [UNIQUEIDENTIFIER]
	DECLARE @Cursor CURSOR

	SET @Cursor = CURSOR FAST_FORWARD
	FOR
	SELECT GroupGuid
	FROM PFCRelatedGroups000 
	WHERE PFCGuid = @PFCGuid

	OPEN @Cursor FETCH NEXT FROM @Cursor INTO @GroupGuid

	WHILE @@FETCH_STATUS = 0
	BEGIN
		INSERT INTO @Result
		select [mtGUID], [mtGroup] from [dbo].[fnGetMatsOfGroups](@GroupGuid)
		FETCH NEXT FROM @Cursor
		INTO @GroupGuid
	END

	CLOSE @Cursor
	DEALLOCATE @Cursor

	RETURN
END
#################################################################
CREATE FUNCTION FnGetRelatedPFCMaterials(@PFCGuid [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
RETURN
	(SELECT DISTINCT Mat.* 
	FROM 
	mt000 Mat INNER JOIN 
	GetPFCMaterialsList(@PFCGuid) as res	ON Mat.GUID = res.MaterialGUID)
#################################################################
CREATE PROC prcGetAllGroupsRelatedTo 
				@GroupGUID uniqueidentifier
AS
BEGIN
	SET NOCOUNT ON  
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	
	CREATE TABLE  [#Result]( [GroupGuid] [UNIQUEIDENTIFIER], [GroupSecurity] [INT]) 
	--Bring Children
	INSERT INTO [#Result]
	EXEC prcGetGroupsList @GroupGUID

	EXEC prcCheckSecurity

	INSERT INTO [#Result1]
	SELECT DISTINCT 
		[Number],
		[Code],
		[Name],
		[Notes],
		[Security],
		[GUID],
		[Type],
		[VAT],
		[LatinName],
		[ParentGUID],
		[branchMask],
		[Kind]
	FROM [#Result]
	INNER JOIN gr000 groups
	ON [#Result].[GroupGuid] = groups.GUID
END
#################################################################
CREATE PROC prcPFCRelatedGroups
		@PFCGuid UNIQUEIDENTIFIER 
AS
BEGIN
	SET NOCOUNT ON
	CREATE TABLE [#Result1]
	(
		[Number] [int] ,
		[Code] [nvarchar](100) ,
		[Name] [nvarchar](250) ,
		[Notes] [nvarchar](250) ,
		[Security] [int] ,
		[GUID] [uniqueidentifier],
		[Type] [int] ,
		[VAT] [float] ,
		[LatinName] [nvarchar](250),
		[ParentGUID] [uniqueidentifier] ,
		[branchMask] [bigint],
		[Kind] [tinyint]
	)

	SELECT GroupGuid  INTO #RelatedGroups
	FROM PFCRelatedGroups000 
	WHERE PFCGuid = @PFCGuid


	DECLARE @GroupGuid [UNIQUEIDENTIFIER]
	DECLARE @Cursor CURSOR

	SET @Cursor = CURSOR FAST_FORWARD
	FOR
	SELECT GroupGuid
	FROM   #RelatedGroups 

	OPEN @Cursor FETCH NEXT FROM @Cursor INTO @GroupGuid

	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC prcGetAllGroupsRelatedTo	@GroupGuid 
		FETCH NEXT FROM @Cursor
		INTO @GroupGuid
	END

	CLOSE @Cursor
	DEALLOCATE @Cursor

	UPDATE [#Result1] SET ParentGUID = 0x0 
	WHERE ParentGUID not in (SELECT GUID  FROM [#Result1])

	SELECT DISTINCT * FROM [#Result1]
END
#################################################################
CREATE FUNCTION HashAccountsGuid(@ParentAccountGuid UNIQUEIDENTIFIER) RETURNS VARCHAR(MAX)
BEGIN
    DECLARE @StringToBeHashed varchar(max), @HashedString varchar(max)
    
    SET @HashedString = CONVERT(varchar(max), (SELECT  CONVERT( varchar(36), Account.Guid) From dbo.fnGetAccountsListByFinal(@ParentAccountGuid)  Account ORDER BY Account.Guid For XML PATH ('')))
    
    SET @StringToBeHashed = CAST( REPLACE( CAST((SELECT SUBSTRING( @HashedString ,1, LEN(@HashedString)))  AS VARCHAR(max)), '-', '') AS VARCHAR(max))
    
    SET @HashedString =  master.dbo.fn_varbintohexstr(HASHBYTES('MD5', @StringToBeHashed));
    SELECT @HashedString = SUBSTRING(@HashedString , 3, 32)
    
    RETURN @HashedString ;
END;
#################################################################
CREATE FUNCTION HashMaterialsInCenter() RETURNS @Result TABLE ( HashedString1 VARCHAR(MAX))
BEGIN
    DECLARE @StringToBeHashed VARCHAR(MAX), @HashedString VARCHAR(MAX)
	DECLARE @Count INT , @MaxGroupOfMat INT 
	
	SET @MaxGroupOfMat = 250
	SET @Count = CAST(
						CEILING(
								(SELECT (COUNT(*) / CAST(@MaxGroupOfMat AS FLOAT)) FROM mt000)
								)
					   AS INT) ;

	WHILE @Count > 0
	BEGIN 
    
		SET @HashedString =  CONVERT(VARCHAR(MAX), (
													 SELECT TOP (@MaxGroupOfMat) CONVERT(VARCHAR(36), Tbl.guid) 
													 FROM (SELECT guid, ROW_NUMBER() OVER (ORDER BY guid) AS row FROM mt000) AS Tbl
													 WHERE Tbl.row >= (1+((@Count-1)*@MaxGroupOfMat)) For XML PATH ('')
													)
		                             )
	
	    SET @StringToBeHashed = CAST(
									 REPLACE(
											 CAST((SELECT SUBSTRING( @HashedString ,1, LEN(@HashedString)))  AS VARCHAR(MAX)),
											  '-', '') 
									 AS VARCHAR(MAX))

        SET @HashedString =  master.dbo.fn_varbintohexstr(HASHBYTES('MD5', @StringToBeHashed));
        SELECT @HashedString = SUBSTRING(@HashedString , 3, 32)
	    INSERT INTO @Result SELECT @HashedString 
	    SET @Count = @Count -1 ;
    END 

    RETURN 
END;
#################################################################
CREATE PROC HashMaterialsInMng(@PFCGuid UNIQUEIDENTIFIER)
AS
BEGIN
SET NOCOUNT ON
	CREATE TABLE [#FinalResult] (HashedString1  [VARCHAR](MAX) )

	SELECT DISTINCT Mat.GUID, Mat.Security INTO #TmpResult
	FROM 
	mt000 Mat INNER JOIN 
	[dbo].[GetPFCMaterialsList](@PFCGuid) as res
	ON Mat.GUID = res.MaterialGUID
	
    DECLARE @StringToBeHashed VARCHAR(MAX), @HashedString VARCHAR(MAX)
	DECLARE @Count INT , @MaxGroupOfMat INT 
		
	SET @MaxGroupOfMat = 250
	set @Count = Cast(
						CEILING(
								(SELECT (COUNT(*) / CAST(@MaxGroupOfMat AS FLOAT)) FROM #TmpResult)
								)
					 AS INT) ;

	WHILE @Count > 0
	begin 
  
		SET @HashedString =  CONVERT(VARCHAR(MAX), (
													 SELECT TOP (@MaxGroupOfMat) CONVERT(VARCHAR(36), Tbl.guid) 
													 FROM (SELECT guid, ROW_NUMBER() OVER (ORDER BY guid) AS row FROM #TmpResult) AS Tbl
													 WHERE Tbl.row >= (1+((@Count-1)*@MaxGroupOfMat)) For XML PATH ('')
													)
		                             )

    
		SET @StringToBeHashed = CAST( 
									 REPLACE( 
											 CAST((SELECT SUBSTRING( @HashedString ,1, LEN(@HashedString)))  AS VARCHAR(max)),
											  '-', '') 
								AS VARCHAR(max))

		SET @HashedString =  master.dbo.fn_varbintohexstr(HASHBYTES('MD5', @StringToBeHashed));
		
		SELECT @HashedString = SUBSTRING(@HashedString , 3, 32)
		INSERT INTO #FinalResult Select @HashedString 
		SET @Count = @Count -1 ;
    END 
	
    SELECT * FROM #FinalResult ;
END;

#################################################################
CREATE PROC GetAccountsListWithDetails(@Guid UNIQUEIDENTIFIER)
AS
SELECT	DISTINCT
		[ac].[GUID],
		[ac].[Code],
		[ac].[Name],
		[ac].[LatinName],
		[parent].[Name] [ParentName],
		[parent].[LatinName] [ParentLatinName]
	FROM [dbo].[fnGetAccountsListByFinal](@Guid) as [lst]
	INNER JOIN [ac000] as [ac] ON [lst].[GUID] = ac.[GUID]
		LEFT JOIN [ac000] as [parent] on [parent].[GUID] = [ac].[ParentGUID]
	order by
		[ac].[Code]

#################################################################
CREATE PROCEDURE GetPFCMaterialsWithDetails
	@PFCGuid [UNIQUEIDENTIFIER]
AS
BEGIN
	SELECT DISTINCT 
	Mat.Guid,
	Mat.Code,
	Mat.Name,
	Mat.LatinName,
	GR.Code AS [GroupCode],
	GR.Name AS[GroupName],
	GR.LatinName AS[GroupLatinName] 
	FROM 
	mt000 Mat INNER JOIN
	[dbo].[GetPFCMaterialsList](@PFCGuid) res
	ON Mat.GUID = res.MaterialGUID
	INNER JOIN [GR000] GR ON Mat.GroupGuid = GR.Guid
	ORDER BY Mat.Code
END
#################################################################
CREATE PROC prcGetProfitCenterShipments
	@ProfitCenterId UNIQUEIDENTIFIER,
	@ShipmentStoreId UNIQUEIDENTIFIER, 
	@CenterStoreId UNIQUEIDENTIFIER,
	@GORStoreId UNIQUEIDENTIFIER,
	@ShipmentType TINYINT,
	@FilterRangeType TINYINT /* 0 ShipmentDate, 1 DeliveryDate, 2 ShipmentNumber*/,
	@FromDate DATETIME,
	@ToDate DATETIME,
	@FromNumber INT,
	@ToNumber INT
AS
	SET NOCOUNT ON

	;WITH Total AS
	(
		SELECT
			T.[GUID],
			SUM(B.Price * B.CurrencyVal * B.Qty) AS Total
		FROM
			ts000 AS T
			JOIN bi000 AS B ON T.OutBillGUID = B.ParentGUID
		GROUP BY
			T.[GUID]
	)
	SELECT 
		S.[Guid],
		S.Number,
		P.Code + '-' + P.Name AS ProfitCenter,
		S.Date AS ShipmentDate,
		S.DeliveryDate,
		SS.Code + '-' + SS.Name AS ShipmentStore,
		COALESCE(DS.Code + '-' + DS.Name, '') AS CenterStore,
		COALESCE(GOR.Code + '-' + GOR.Name, '') AS GORStore,
		T.Total
	FROM
		PFCShipmentBill000 AS S
		JOIN SubProfitCenter000 AS P ON S.ProfitCenterGUID = P.[Guid]
		JOIN st000 AS SS ON S.ShipmentStoreGUID = SS.GUID
		LEFT JOIN st000 AS DS ON S.CenterStoreGUID = DS.GUID
		LEFT JOIN st000 AS GOR ON S.GORStoreGuid = GOR.GUID
		LEFT JOIN Total AS T ON T.GUID = S.DeliveryTransGuid
	WHERE
		((@ProfitCenterId <> 0x AND S.ProfitCenterGUID = @ProfitCenterId) OR @ProfitCenterId = 0x)
		AND ((@ShipmentStoreId <> 0x AND S.ShipmentStoreGUID = @ShipmentStoreId) OR @ShipmentStoreId = 0x)
		AND ((@CenterStoreId <> 0x AND S.CenterStoreGUID = @CenterStoreId) OR @CenterStoreId = 0x)
		AND ((@GORStoreId <> 0x AND S.GORStoreGuid = @GORStoreId) OR @GORStoreId = 0x)
		AND ((@ShipmentType <> 0 AND S.[Type] = @ShipmentType) OR @ShipmentType = 0)
		AND 
		(
			(@FilterRangeType = 0 AND S.[Date] BETWEEN @FromDate AND @ToDate)
			OR
			(@FilterRangeType = 1 AND S.DeliveryDate BETWEEN @FromDate AND @ToDate)
			OR
			(@FilterRangeType = 2 AND S.Number BETWEEN @FromNumber AND @ToNumber)
		)
#################################################################
CREATE PROCEDURE CheckPFCMaterialsConsistency
		@PFCGuid UNIQUEIDENTIFIER
AS
BEGIN
	SET NOCOUNT ON;
		
	DECLARE @priceType INT
	DECLARE  @pricePrec INT = CAST(dbo.fnOption_GetValue('AmnCfg_PricePrec', 0) AS INT)

	SELECT @priceType = Price FROM SubProfitCenter000 WHERE Guid = @PFCGuid
	
	CREATE TABLE #Result
	(
		Guid UNIQUEIDENTIFIER,
		Name NVARCHAR(255),
		LatinName NVARCHAR(255),
		Code NVARCHAR(255),
		Price FLOAT,
		Price2 FLOAT,
		Price3 FLOAT,
		UnitFact FLOAT,
		Unit2Fact FLOAT,
		Unit3Fact FLOAT
	)

	IF @priceType = 4 --  PT_WHOLE = 0x4
	BEGIN
		INSERT INTO #Result
		SELECT DISTINCT Mat.GUID, Mat.Name, Mat.LatinName, Mat.Code, Mat.Whole, Mat.Whole2, Mat.Whole3, 1, Unit2Fact, Unit3Fact
		FROM 
		mt000 Mat INNER JOIN 
		[dbo].[GetPFCMaterialsList](@PFCGuid) as res ON Mat.GUID = res.MaterialGUID
		WHERE ROUND(Mat.Whole * Mat.Unit2Fact, @pricePrec) <> ROUND(Mat.Whole2, @pricePrec)
			OR ROUND(Mat.Whole * Mat.Unit3Fact, @pricePrec)  <> ROUND(Mat.Whole3, @pricePrec)
	END 
	ELSE IF @priceType = 8 --PT_HALF = 0x8
	BEGIN
		INSERT INTO #Result
		SELECT DISTINCT Mat.GUID, Mat.Name, Mat.LatinName, Mat.Code, Mat.Half, Mat.Half2, Mat.Half3, 1, Unit2Fact, Unit3Fact
		FROM 
		mt000 Mat INNER JOIN 
		[dbo].[GetPFCMaterialsList](@PFCGuid) as res ON Mat.GUID = res.MaterialGUID
		WHERE ROUND(Mat.Half * Mat.Unit2Fact, @pricePrec) <> ROUND(Mat.Half2, @pricePrec)
			OR ROUND(Mat.Half * Mat.Unit3Fact, @pricePrec)  <> ROUND(Mat.Half3, @pricePrec)
	END
	ELSE IF @priceType = 16 --PT_EXPORT = 0x10
	BEGIN
		INSERT INTO #Result
		SELECT DISTINCT Mat.GUID, Mat.Name, Mat.LatinName, Mat.Code, Mat.Export, Mat.Export2, Mat.Export3, 1, Unit2Fact, Unit3Fact
		FROM 
		mt000 Mat INNER JOIN 
		[dbo].[GetPFCMaterialsList](@PFCGuid) as res ON Mat.GUID = res.MaterialGUID
		WHERE ROUND(Mat.Export * Mat.Unit2Fact, @pricePrec) <> ROUND(Mat.Export2, @pricePrec)
			OR ROUND(Mat.Export * Mat.Unit3Fact, @pricePrec)  <> ROUND(Mat.Export3, @pricePrec)
	END
	ELSE IF @priceType = 32 --PT_VENDOR = 0x20
	BEGIN
		INSERT INTO #Result
		SELECT DISTINCT Mat.GUID, Mat.Name, Mat.LatinName, Mat.Code, Mat.Vendor, Mat.Vendor2, Mat.Vendor3, 1, Unit2Fact, Unit3Fact
		FROM 
		mt000 Mat INNER JOIN 
		[dbo].[GetPFCMaterialsList](@PFCGuid) as res ON Mat.GUID = res.MaterialGUID
		WHERE ROUND(Mat.Vendor * Mat.Unit2Fact, @pricePrec) <> ROUND(Mat.Vendor2, @pricePrec)
			OR ROUND(Mat.Vendor * Mat.Unit3Fact, @pricePrec)  <> ROUND(Mat.Vendor3, @pricePrec)
	END
	ELSE IF @priceType = 64 --PT_RETAIL = 0x40
	BEGIN
		INSERT INTO #Result
		SELECT DISTINCT Mat.GUID, Mat.Name, Mat.LatinName, Mat.Code, Mat.Retail, Mat.Retail2, Mat.Retail3, 1, Unit2Fact, Unit3Fact
		FROM 
		mt000 Mat INNER JOIN 
		[dbo].[GetPFCMaterialsList](@PFCGuid) as res ON Mat.GUID = res.MaterialGUID
		WHERE ROUND(Mat.Retail * Mat.Unit2Fact, @pricePrec) <> ROUND(Mat.Retail2, @pricePrec)
			OR ROUND(Mat.Retail * Mat.Unit3Fact, @pricePrec)  <> ROUND(Mat.Retail3, @pricePrec)
	END
	ELSE IF @priceType = 128  --PT_ENDUSER = 0x80
	BEGIN
		INSERT INTO #Result
		SELECT DISTINCT Mat.GUID, Mat.Name, Mat.LatinName, Mat.Code, Mat.EndUser, Mat.EndUser2, Mat.EndUser3, 1, Unit2Fact, Unit3Fact
		FROM 
		mt000 Mat INNER JOIN 
		[dbo].[GetPFCMaterialsList](@PFCGuid) as res ON Mat.GUID = res.MaterialGUID
		WHERE ROUND(Mat.EndUser * Mat.Unit2Fact, @pricePrec) <> ROUND(Mat.EndUser2, @pricePrec)
			OR ROUND(Mat.EndUser * Mat.Unit3Fact, @pricePrec)  <> ROUND(Mat.EndUser3, @pricePrec)
	END

	SELECT * FROM #Result

END
#################################################################
CREATE PROCEDURE prcProfitCheckMats
	@DESTDBNAME		 NVARCHAR (max) = ''
AS 
	SET NOCOUNT ON

	DECLARE @Query1 NVARCHAR (max)
	DECLARE @Query2 NVARCHAR (max)
	DECLARE @Query3 NVARCHAR (max)

	SET @Query1 ='IF EXISTS (SELECT * FROM mt000 S1 LEFT JOIN '+@DESTDBNAME+'.dbo.mt000 S2 ON S1.GUID = S2.GUID WHERE  S1.HasSegments=1 and S2.HasSegments!=1 )
	BEGIN
		DECLARE @var1 [NVARCHAR](255);
		SET @var1 ='+'''AmnE1004:'''+' (SELECT TOP 1 [NAME] FROM (SELECT S2.Name FROM mt000 S1 LEFT JOIN '+@DESTDBNAME+'.dbo.mt000 S2 ON S1.GUID = S2.GUID WHERE  S1.HasSegments=1 and S2.HasSegments!=1) as res)
		RAISERROR (@var1, 18, 255);
		RETURN
	END'
	SET @Query2 ='IF EXISTS (SELECT * FROM mt000 S1 LEFT JOIN '+@DESTDBNAME+'.dbo.mt000 S2 ON S1.GUID = S2.GUID WHERE  S1.HasSegments=1 and  S2.HasSegments!=1) BEGIN
		DECLARE @var2 [NVARCHAR](255);
		SET @var2 ='+'''AmnE1005:'''+' (SELECT TOP 1 [NAME] FROM (SELECT S2.Name FROM mt000 S1 LEFT JOIN '+@DESTDBNAME+'.dbo.mt000 S2 ON S1.GUID = S2.GUID WHERE  S1.HasSegments=1 and S2.HasSegments!=1) as res)
		RAISERROR (@var2, 18, 255);
		RETURN
	END'
	SET @Query3 ='IF EXISTS (SELECT * FROM MaterialSegments000 MS1 LEFT JOIN '+@DESTDBNAME+'.dbo.MaterialSegments000 MS2 ON MS1.MaterialId = MS2.MaterialId WHERE  MS1.SegmentId!=MS2.SegmentId) BEGIN
		DECLARE @var3 [NVARCHAR](255);
		SET @var3 =''AmnE1006:'' (SELECT TOP 1 [NAME] FROM (SELECT S2.Name FROM mt000 S1 LEFT JOIN '+@DESTDBNAME+'.dbo.mt000 S2 ON S1.GUID = S2.GUID WHERE  S1.HasSegments=1 and S2.HasSegments!=1) as res)
		RAISERROR (@var3, 18, 255);
		RETURN
	END'
	
	
	EXECUTE sp_executesql @Query1
	EXECUTE sp_executesql @Query2
	EXECUTE sp_executesql @Query3

#################################################################
CREATE FUNCTION fnGetMatPricesCheckSum
(
	@PFCGuid UNIQUEIDENTIFIER,
	@priceType INT
)
RETURNS INT
AS
BEGIN

	IF @priceType = 4
		RETURN (SELECT CHECKSUM_AGG(CHECKSUM(GUID, Whole, Whole2, Whole3)) 
		FROM mt000 MT
		LEFT JOIN GetPFCMaterialsList(@PFCGuid) PFCMat ON PFCMat.MaterialGUID = MT.GUID
		WHERE @PFCGuid = 0X0 OR PFCMat.MaterialGUID IS NOT NULL)

	IF @priceType = 8
		RETURN (SELECT CHECKSUM_AGG(CHECKSUM(GUID, Half, Half2, Half3))
		FROM mt000 MT
		LEFT JOIN GetPFCMaterialsList(@PFCGuid) PFCMat ON PFCMat.MaterialGUID = MT.GUID
		WHERE @PFCGuid = 0X0 OR PFCMat.MaterialGUID IS NOT NULL)

	IF @priceType = 16
		RETURN (SELECT CHECKSUM_AGG(CHECKSUM(GUID, Export, Export2, Export3))
		FROM mt000 MT
		LEFT JOIN GetPFCMaterialsList(@PFCGuid) PFCMat ON PFCMat.MaterialGUID = MT.GUID
		WHERE @PFCGuid = 0X0 OR PFCMat.MaterialGUID IS NOT NULL)

	IF @priceType = 32
		RETURN (SELECT CHECKSUM_AGG(CHECKSUM(GUID, Vendor, Vendor2, Vendor3))
		FROM mt000 MT
		LEFT JOIN GetPFCMaterialsList(@PFCGuid) PFCMat ON PFCMat.MaterialGUID = MT.GUID
		WHERE @PFCGuid = 0X0 OR PFCMat.MaterialGUID IS NOT NULL)

	IF @priceType = 64
		RETURN (SELECT CHECKSUM_AGG(CHECKSUM(GUID, Retail, Retail2, Retail3))
		FROM mt000 MT
		LEFT JOIN GetPFCMaterialsList(@PFCGuid) PFCMat ON PFCMat.MaterialGUID = MT.GUID
		WHERE @PFCGuid = 0X0 OR PFCMat.MaterialGUID IS NOT NULL)

	IF @priceType = 128
		RETURN (SELECT CHECKSUM_AGG(CHECKSUM(GUID, EndUser, EndUser2, EndUser3))
		FROM mt000 MT
		LEFT JOIN GetPFCMaterialsList(@PFCGuid) PFCMat ON PFCMat.MaterialGUID = MT.GUID
		WHERE @PFCGuid = 0X0 OR PFCMat.MaterialGUID IS NOT NULL)

	RETURN 0
END
##########################################################################################
#END