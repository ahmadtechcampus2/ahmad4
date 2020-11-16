################################################################################
CREATE PROCEDURE prcGetDistGustsList
	@DistGUID 	[UNIQUEIDENTIFIER] = 0x00,
	@AccGUID 	[UNIQUEIDENTIFIER] = 0x00,
	@CustGUID 	[UNIQUEIDENTIFIER] = 0x00,
	@HiGuid		[UNIQUEIDENTIFIER] = 0x00
AS

	SET NOCOUNT ON

	DECLARE @ZeroGuid	UNIQUEIDENTIFIER
	SET @ZeroGuid	= '00000000-0000-0000-0000-000000000000' 

	CREATE TABLE #CustsOfAcc([GUID] UNIQUEIDENTIFIER) 
	INSERT INTO #CustsOfAcc
	SELECT * FROM [dbo].[fnGetCustsOfAcc](@AccGUID)
	
	CREATE TABLE #HierarchyList([GUID] UNIQUEIDENTIFIER) 
	INSERT INTO #HierarchyList
	SELECT GUID FROM fnGetHierarchyList(@HiGuid, 0)
	
	SELECT DISTINCT 
		[cu].[cuGuid] AS Guid, 
		[cu].[cuSecurity] AS [Security]
	FROM 
		[vwCu] AS [Cu] 
		INNER JOIN #CustsOfAcc AS [fCu] ON [Cu].[cuGuid] = [fCu].[Guid]
		LEFT JOIN [DistDistributionLines000] AS [Dl]  ON [Dl].[CustGuid] = [Cu].[cuGuid]
		LEFT JOIN vwDistributor AS [D]   ON [D].[Guid] = [Dl].[DistGuid]
	WHERE
		(cu.cuGuid = @CustGuid OR @CustGuid = @ZeroGuid) AND
		(D.Guid = @DistGuid OR @DistGuid = @ZeroGuid) AND
		(D.HierarchyGuid IN (SELECT Guid FROM #HierarchyList) OR @HiGuid = @ZeroGuid)	

/*
Exec prcConnections_Add2 '„œÌ—'
EXEC prcGetDistGustsList 0x00, 0x00, 0x00, '81A09B21-EE56-48A3-8264-73F38F6A9697'
*/
################################################################################
CREATE PROCEDURE prcDistImpRouteDays
	 @ColumnName nVarchar(100),
	 @ColumnValue nVarchar(100),
	 @RouteDay1 nVarchar(100), 
	 @NextRoute nVarchar(100), 
	 @RouteDay2 nVarchar(100),
	 @RouteDay3 nVarchar(100),
	 @RouteDay4 nVarchar(100),
	 @DistGUID 	uniqueidentifier
AS
BEGIN
	SET NOCOUNT ON
	
	DECLARE		
		@FirstRouteDate DATE,
		@RouteCount INT,
		@EndPeriodDate DATE,
		@TempRouteDate DATE,
		@TempNumber INT,
		@Rout1 INT,
		@Rout2 INT,
		@Rout3 INT,
		@Rout4 INT,
		@NEXT_ROUTE INT,
		@RoutOK Bit,
		@CustomerGUID UNIQUEIDENTIFIER,
		@d Date;
		
	DECLARE @Result Table(
		[Date] DATE,
		Number INT);
		
	SELECT @FirstRouteDate = [dbo].[fnDate_Amn2Sql](Value) FROM op000 WHERE Name = 'DistCfg_Coverage_RouteDate';
	SELECT @EndPeriodDate = [dbo].[fnDate_Amn2Sql](Value) FROM op000 WHERE Name = 'AmnCfg_EPDate';
	SELECT @RouteCount = dbo.fnOption_GetInt('DistCfg_Coverage_RouteCount', '0');
	
	if (not(@ColumnValue is null) and  (@ColumnValue != '') ) 
	Begin
		declare @sql nvarchar(4000);
		set @sql = ' (Select GUID FROM cu000 Where ' + @columnname+ ' = ''' + @ColumnValue + ''')';	
		create table #temptable (Guid UNIQUEIDENTIFIER null)
		insert into #temptable exec sp_executesql @sql		
		SET @CustomerGUID = (select Top 1 * from #temptable); 
	End;

	SET @TempNumber = 1;
	SET @RoutOK = 1;	
	SET @TempRouteDate = @FirstRouteDate;
	
	WHILE (@TempRouteDate <= @EndPeriodDate)
	BEGIN
		IF @TempNumber > @RouteCount
			SET @TempNumber = 1;
				
		IF NOT EXISTS(SELECT * FROM DISTCalendar000 WHERE Date = @TempRouteDate)
		BEGIN
			INSERT INTO @Result VALUES(@TempRouteDate, @TempNumber);
			SET @TempNumber = @TempNumber + 1;
		END
		ELSE
			INSERT INTO @Result VALUES(@TempRouteDate, '0');
			
		SET @TempRouteDate = DATEADD(DAY, 1, @TempRouteDate);
	END
	
	if( ISNUMERIC (@NextRoute) = 1)
		SET @NEXT_ROUTE = (CAST(CAST(@NextRoute AS float) AS INT));
	else
		SET @NEXT_ROUTE = 0;
									
	if (@NEXT_ROUTE > 0 )
	Begin
		if ( ISNUMERIC (@RouteDay1) != 0)
			SET @Rout1 = (CAST(CAST(@RouteDay1 AS float) AS INT));
		else
		if (IsDate (@RouteDay1) = 1)
			Begin				
				BEGIN TRY
					 set @d = cast(CONVERT(Date, @RouteDay1, 105) as Date);
				END TRY
				BEGIN CATCH
					set @d = (CONVERT(Date, cast(@RouteDay1 as Date),105));
				END CATCH;
				SET @Rout1 = (SELECT Number FROM @Result where Date =  @d);
			End
		else
			SET @Rout1 = 0;
			
		if( @Rout1 > @RouteCount)
		begin
			SET  @Rout1 = 0;
			SET @RoutOK = 0;
			SET @Rout2 = 0;
			SET @Rout3 = 0;
			SET @Rout4 = 0;
		end
		
		if (@NEXT_ROUTE < @RouteCount) and (@RoutOK = 1)
		begin
			if ( (@Rout1 + @NEXT_ROUTE ) < @RouteCount)
				SET @Rout2 = ((@Rout1 + @NEXT_ROUTE ));
			else
			begin
				SET @Rout2 = 0;
				SET @Rout3 = 0;
				SET @Rout4 = 0;
				SET @RoutOK = 0;
			end

			if ( (@Rout2 + @NEXT_ROUTE ) < @RouteCount) and (@RoutOK = 1)
				SET @Rout3 = ((@Rout2 + @NEXT_ROUTE ));
			else
			begin
				SET @Rout3 = 0;
				SET @Rout4 = 0;
				SET @RoutOK = 0;
			end

			if ( (@Rout3 + @NEXT_ROUTE ) < @RouteCount) and (@RoutOK = 1)
				SET @Rout4 = ((@Rout3 + @NEXT_ROUTE ));
			else
				SET @Rout4 = 0;			
		end		
	End
	else 
		Begin
			if ((ISNUMERIC (@RouteDay1) != 0) )
				SET @Rout1 =  (CAST(CAST(@RouteDay1 AS float) AS INT));
			else
			if (IsDate (@RouteDay1) = 1)
			Begin
				BEGIN TRY
					 set @d = cast(CONVERT(Date, @RouteDay1, 105) as Date);
				END TRY
				BEGIN CATCH
					set @d = (CONVERT(Date, cast(@RouteDay1 as Date),105));
				END CATCH;
				SET @Rout1 = (SELECT Number FROM @Result where Date =  @d);
			End				
			else
				SET @Rout1 = 0;
			
			if ((ISNUMERIC (@RouteDay2) != 0) )
				SET @Rout2 = (CAST(CAST(@RouteDay2 AS float) AS INT));
			else
			if (IsDate (@RouteDay2) = 1)
			Begin
				BEGIN TRY
					 set @d = cast(CONVERT(Date, @RouteDay2, 105) as Date);
				END TRY
				BEGIN CATCH
					set @d = (CONVERT(Date, cast(@RouteDay2 as Date),105));
				END CATCH;
				SET @Rout2 = (SELECT Number FROM @Result where Date =  @d);
			End							
			else
				SET @Rout2 = 0;
			
			if ((ISNUMERIC (@RouteDay3) != 0) )
				SET @Rout3 = (CAST(CAST(@RouteDay3 AS float) AS INT));
			else
			if (IsDate (@RouteDay3) = 1)
			Begin
				BEGIN TRY
					 set @d = cast(CONVERT(Date, @RouteDay3, 105) as Date);
				END TRY
				BEGIN CATCH
					set @d = (CONVERT(Date, cast(@RouteDay3 as Date),105));
				END CATCH;
				SET @Rout3 = (SELECT Number FROM @Result where Date =  @d);
			End				
			else
				SET @Rout3 = 0;
			
			if ((ISNUMERIC (@RouteDay4) != 0) )
				SET @Rout4 = (CAST(CAST(@RouteDay4 AS float) AS INT));
			else
			if (IsDate (@RouteDay4) = 1)
			Begin
				BEGIN TRY
					 set @d = cast(CONVERT(Date, @RouteDay4, 105) as Date);
				END TRY
				BEGIN CATCH
					set @d = (CONVERT(Date, cast(@RouteDay4 as Date),105));
				END CATCH;
				SET @Rout4 = (SELECT Number FROM @Result where Date =  @d);
			End				
			else
				SET @Rout4 = 0;				
			
			if( @Rout1 > @RouteCount)
				SET  @Rout1 = 0;
			if( @Rout2 > @RouteCount)
				SET  @Rout2 = 0;
			if( @Rout3 > @RouteCount)
				SET  @Rout3 = 0;
			if( @Rout4 > @RouteCount)
				SET  @Rout4 = 0;
				
		End

	DECLARE @IMP_Count  INT;	
	SEt @IMP_Count = 0;
	
	IF(count(@CustomerGUID) > 0)
		IF( @Rout1 > 0) OR ( @Rout2 > 0) OR ( @Rout3 > 0) OR ( @Rout4 > 0)
		Begin	
			if(@DistGUID = 0x00)
			Begin				
				Delete From DistDistributionLines000 WHERE (([DistDistributionLines000].CustGUID = @CustomerGUID ) );
				Insert into DistDistributionLines000 (GUID ,DistGUID, CustGUID, Route1, Route2, Route3, Route4,
														Route1Time, Route2Time, Route3Time, Route4Time)					 
						Select  NEWID(), ds.GUID , @CustomerGUID, @Rout1, @Rout2, @Rout3, @Rout4, '', '', '', ''
						from ci000 ci 
						Inner Join ac000 ac on ci.SonGUID = ac.GUID
						Inner Join Distributor000 ds ON ds.CustomersAccGUID = ci.ParentGuid
						Inner Join cu000 cu on cu.AccountGUID = ac.GUID
						Where cu.Guid = @CustomerGUID
				IF(@@ROWCOUNT > 0)
					SEt @IMP_Count = 1;
			End
			Else
			Begin
				Delete From DistDistributionLines000 WHERE (([DistDistributionLines000].CustGUID = @CustomerGUID ) 
										AND ([DistDistributionLines000].DistGUID = @DistGUID ) );
				Insert into DistDistributionLines000 (GUID ,DistGUID, CustGUID, Route1, Route2, Route3, Route4,
														Route1Time, Route2Time, Route3Time, Route4Time)					 
						Select  NEWID(), ds.GUID , @CustomerGUID, @Rout1, @Rout2, @Rout3, @Rout4, '', '', '', ''
						from ci000 ci 
						Inner Join ac000 ac on ci.SonGUID = ac.GUID
						Inner Join Distributor000 ds ON ds.CustomersAccGUID = ci.ParentGuid
						Inner Join cu000 cu on cu.AccountGUID = ac.GUID
						Where cu.Guid = @CustomerGUID AND ds.GUID = @DistGUID;
							
						IF(@@ROWCOUNT > 0)
							SEt @IMP_Count = 1;
			End
								
			(Select @IMP_Count As Customer_OK);
		End
		ELSE
			DELETE FROM [DistDistributionLines000]				
				WHERE ([DistDistributionLines000].CustGUID = @CustomerGUID );
END
################################################################################
CREATE PROCEDURE repGetDistLines
	@DistGUID [UNIQUEIDENTIFIER] = 0x00,  
	@AccGUID  [UNIQUEIDENTIFIER] = 0x00,  
	@CalcBalance	BIT = 0   
AS   
	SET NOCOUNT ON   
	DECLARE @DistCustAcc	UNIQUEIDENTIFIER  
	SELECT 	@DistCustAcc = ISNULL(CustomersAccGuid,0x00) from vwDistributor WHERE Guid = @DistGuid   
	--PRINT(@DistCustAcc) 
	CREATE TABLE [#Cust]( [GUID] [UNIQUEIDENTIFIER], [Security] INT)        
	IF ISNULL(@DistCustAcc, 0x0) <> 0x0 
	BEGIN 
		INSERT INTO #Cust    
			SELECT DISTINCT  
				Cu.CuGuid, cu.cuSecurity  
			FROM   
				[dbo].[fnGetCustsOfAcc] (@DistCustAcc) AS FCu   
				INNER JOIN vwCu AS Cu ON Cu.CuGuid = FCu.Guid	 
				LEFT JOIN #Cust AS c ON c.Guid = Cu.CuGuid   
		WHERE   
			ISNULL(C.Guid, 0x0) = 0x0  
	END 
	ELSE 
	BEGIN 
		INSERT INTO #Cust  
			SELECT DISTINCT  
				Cu.CuGuid, cu.cuSecurity  
			FROM   
				DistDistributionLines000 AS d 
				INNER JOIN vwCu AS Cu ON Cu.CuGuid = d.CustGuid	 
		WHERE   
			d.DistGuid = @DistGuid 
	END 
	

----------------------------------------------------------------------------
	-- Calc Balance
	CREATE TABLE [#AccBalList] ([AccGuid] [UNIQUEIDENTIFIER], [AccBalance] [float]) 
	CREATE TABLE [#CostBalList] ([AccGuid] [UNIQUEIDENTIFIER], [AccBalance] [float]) 
	IF @CalcBalance = 1 
	BEGIN
		--To calculate the account balance for each of the customers 
		CREATE TABLE [#CustAccList] ([AccGuid] [UNIQUEIDENTIFIER])

		INSERT INTO #CustAccList SELECT cu.cuAccount FROM vwcu as cu
								 WHERE cu.cuguid IN (SELECT Guid FROM [dbo].[fnGetCustsOfAcc] (@DistCustAcc))

		INSERT INTO [#AccBalList]
		SELECT [cu].[AccGuid], SUM([en].[enDebit] - [en].[enCredit])
			FROM
				[vwCeEn] AS [en]
				INNER JOIN [#CustAccList] AS [cu] ON [cu].[AccGuid] = en.[enAccount]
			Where
				[en].[ceIsPosted] <> 0
			GROUP BY
				[cu].[AccGuid]

		--To calculate the account balance for each one of the customer according to the distributor costguid
		DECLARE @DistCostGuid [UNIQUEIDENTIFIER]	
		SELECT @DistCostGuid = ds.CostGuid FROM DistSalesman000 AS ds
								INNER JOIN Distributor000 AS d ON d.PrimSalesmanGuid = ds.Guid
								WHERE d.Guid = @DistGuid

		INSERT INTO [#CostBalList]
		SELECT [cu].[AccGuid], Sum([en].[enDebit] - [en].[enCredit])
			FROM
				[vwCeEn] AS [en]
				INNER JOIN cu000 AS u ON u.AccountGuid = en.[enAccount]
				INNER JOIN [#CustAccList] AS [cu] ON [cu].[AccGuid] = u.AccountGuid
			Where
				[en].[ceIsPosted] <> 0 AND [en].[enCostPoint] = @DistCostGuid
			GROUP BY
				[cu].[AccGuid]
	END				
----------------------------------------------------------------------------

	DECLARE @CustChart INT  
	SELECT @CustChart = Value FROM op000 WHERE NAme = 'DistCfg_CustChart'  
	SET @CustChart = ISNULL(@CustChart, 0)  
	  
	IF @CustChart = 0   
	BEGIN  
		SELECT 	  
			ISNULL([d].[Guid],0X00) AS [Guid],   
			ISNULL([d].[DistGuid],0X00) AS [DistGuid],   
			ISNULL([c].[Guid],0X00) AS [CustGuid],    
			ISNULL([d].[Route1],0) AS [Route1],   
			ISNULL([d].[Route2],0) AS [Route2],   
			ISNULL([d].[Route3],0) AS [Route3],   
			ISNULL([d].[Route4],0) AS [Route4],   
			ISNULL([d].[Route1Time], '1/1/1980') AS [Route1Time],   
			ISNULL([d].[Route2Time], '1/1/1980') AS [Route2Time],   
			ISNULL([d].[Route3Time], '1/1/1980') AS [Route3Time],   
			ISNULL([d].[Route4Time], '1/1/1980') AS [Route4Time],   
			[cu].[cuCustomerName] 		AS [cuCustomerName],   
			[cu].[cuLatinName] 			AS  [cuCustomerLatinName],   
			[cu].[cuPhone1] 			AS [cuPhone1],   
			[cu].[cuPhone2] 			AS [cuPhone2],   
			[cu].[cuFax] 				AS [cuFax],   
			[cu].[cuTelex] 				AS [cuTelex],   
			[cu].[cuMobile] 			AS [cuMobile],   
			[cu].[cuPager] 				AS [cuPager],   
			[cu].[cuNotes] 				AS [cuNotes],   
			[cu].[cuCountry] 			AS [cuCountry],   
			[cu].[cuCity] 				AS [cuCity],   
			[cu].[cuArea] 				AS [cuArea],   
			[cu].[cuStreet] 			AS [cuStreet],    
			[cu].[cuAddress] 			AS [cuAddress],   
			[cu].[cuZipCode] 			AS [cuZipCode],   
			[cu].[cuPoBox] 				AS [cuPoBox],   
			[cu].[cuBarcode] 			AS [cuBarcode],   
			'' 							AS [cuCertificate],   
			'' 							AS [cuCustJob],   
			''							AS [cuCustJobCategory],   
			[cu].[cuUserFld1] 			AS [cuCustFld1],   
			[cu].[cuUserFld2] 			AS [cuCustFld2],   
			[ac].[acCode] 				AS [acCode],   
			[ac].[acGuid] 				AS [AccGuid] ,  
			ISNULL([ab].[AccBalance],0)	AS [AccBalance],
			ISNULL([cb].[AccBalance],0)	AS [CostBalance],
			CASE ISNULL(d.Guid, 0x00) WHEN 0x00 THEN 1 ELSE 0 END AS Flag--  c.Flag  
		FROM   
			[#Cust] AS [c]    
			INNER JOIN [vwCu] AS [cu] ON [cu].[cuGuid] = [c].[Guid] 
			INNER JOIN [vwAc] AS [ac] ON [ac].[acGUID] = [cu].[cuAccount]  
			LEFT JOIN [#AccBalList] AS [ab] ON [ac].[acGuid] = [ab].[AccGuid]
			LEFT JOIN [#CostBalList] AS [cb] ON [ac].[acGuid] = [cb].[AccGuid]
			LEFT JOIN [DistDistributionLines000] AS [d] ON [c].[GUID] = [d].[CustGuid] AND d.DistGuid = @DistGuid  
		ORDER BY    
			CASE ISNULL([d].[Guid], 0X00) WHEN 0X00 THEN 1 ELSE 0 END ,   
			[cuCustomerName]   
	END   
	ELSE  
	BEGIN  
		SELECT 	  
			ISNULL([d].[Guid],0X00) AS [Guid],   
			ISNULL([d].[DistGuid],0X00) AS [DistGuid],   
			ISNULL([c].[Guid],0X00) AS [CustGuid],    
			ISNULL([d].[Route1],0) AS [Route1],   
			ISNULL([d].[Route2],0) AS [Route2],   
			ISNULL([d].[Route3],0) AS [Route3],   
			ISNULL([d].[Route4],0) AS [Route4],   
			ISNULL([d].[Route1Time], '1/1/1980') AS [Route1Time],   
			ISNULL([d].[Route2Time], '1/1/1980') AS [Route2Time],   
			ISNULL([d].[Route3Time], '1/1/1980') AS [Route3Time],   
			ISNULL([d].[Route4Time], '1/1/1980') AS [Route4Time],   
			[cu].[cuCustomerName] 		AS [cuCustomerName],   
			[cu].[cuLatinName] 			AS  [cuCustomerLatinName],   
			[cu].[cuPhone1] 			AS [cuPhone1],   
			[cu].[cuPhone2] 			AS [cuPhone2],   
			[cu].[cuFax] 				AS [cuFax],   
			[cu].[cuTelex] 				AS [cuTelex],   
			[cu].[cuMobile] 			AS [cuMobile],   
			[cu].[cuPager] 				AS [cuPager],   
			[cu].[cuNotes] 				AS [cuNotes],   
			[cu].[cuCountry] 			AS [cuCountry],   
			[cu].[cuCity] 				AS [cuCity],   
			[Gac].[acName] 				AS [cuArea],   
			[Pac].[acName] 				AS [cuStreet],    
			[cu].[cuAddress] 			AS [cuAddress],   
			[cu].[cuZipCode] 			AS [cuZipCode],   
			[cu].[cuPoBox] 				AS [cuPoBox],   
			[cu].[cuBarcode] 			AS [cuBarcode],   
			'' 							AS [cuCertificate],   
			'' 							AS [cuCustJob],   
			''							AS [cuCustJobCategory],   
			[cu].[cuUserFld1] 			AS [cuCustFld1],   
			[cu].[cuUserFld2] 			AS [cuCustFld2],   
			[ac].[acCode] 				AS [acCode],   
			[ac].[acGuid] 				AS [AccGuid] , 
			ISNULL([ab].[AccBalance],0)	AS [AccBalance], 
			ISNULL([cb].[AccBalance],0)	AS [CostBalance],
			CASE ISNULL(d.Guid, 0x00) WHEN 0x00 THEN 1 ELSE 0 END AS Flag--  c.Flag  
		FROM   
			[#Cust] AS [c]    
			INNER JOIN [vwCu] AS [cu] ON [cu].[cuGuid] = [c].[Guid] 
			INNER JOIN [vwAc] AS [ac] ON [ac].[acGUID] = [cu].[cuAccount] 
			LEFT JOIN [#AccBalList] AS [ab] ON [ac].[acGuid] = [ab].[AccGuid] 
			LEFT JOIN [#CostBalList] AS [cb] ON [ac].[acGuid] = [cb].[AccGuid]
			LEFT JOIN [DistDistributionLines000] AS [d] ON [c].[GUID] = [d].[CustGuid] AND d.DistGuid = @DistGuid  
			LEFT JOIN vwac AS Pac ON Pac.acGuid = ac.acParent  
			LEFT JOIN vwac AS Gac ON Gac.acGuid = Pac.acParent  
		ORDER BY    
			CASE ISNULL([d].[Guid], 0X00) WHEN 0X00 THEN 1 ELSE 0 END ,   
			[cuCustomerName]   
	END  
	SELECT CustomersAccGuid FROM Distributor000 WHERE Guid = @DistGuid   

/*
Exec prcConnections_Add2 '„œÌ—'
EXEC repGetDistLines '982F65F9-7526-4CC2-8DB7-563B6F16EF75'
*/
################################################################################
#END
