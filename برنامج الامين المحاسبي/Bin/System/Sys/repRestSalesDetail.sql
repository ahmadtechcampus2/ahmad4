###########################
CREATE  PROCEDURE repRestSalesDetail 
@StartDate [DateTime],
@EndDate   [DateTime],
@UserDetail [BIT], 
@PayDetail [BIT], 
@GrDetail [BIT],
@GrLevel [INT],
@MtDetail [BIT] , 
@SalesDetailByOrderType [BIT],
@BillsDetailByOrderType [BIT]

AS

	SET NOCOUNT ON
	DECLARE @selectedOrders TABLE 
	( 
		[GUID] [uniqueidentifier], 
		[FinishCashierID] [uniqueidentifier],
		[PaymentPackageID]	[uniqueidentifier], 
		[Direction]		[INT]
	)
	INSERT INTO @selectedOrders
	SELECT 
		[GUID] , [FinishCashierID] , [PaymentsPackageID] , IIF ( Type != 4 , 1 , -1 )
	FROM 
		RestOrder000 [Order]	
	WHERE  
	 ([Order].[Closing] BETWEEN @startDate AND @endDate) 
	
	
	DECLARE @language [INT]	
	SET @language = [dbo].[fnConnections_getLanguage]() 
	
	DECLARE @TableOrderTotal [FLOAT]
	DECLARE @OuterOrderTotal [FLOAT]
	DECLARE @DeliveryOrderTotal [FLOAT]
	DECLARE @ReturnedOrderTotal [FLOAT]
	DECLARE @PaidAndReceived [UNIQUEIDENTIFIER] = NEWID()
	DECLARE @NetSales [UNIQUEIDENTIFIER] = NEWID()
	DECLARE @SubTotal [FLOAT] , @ReturnSubTotal [FLOAT], @Total [FLOAT] , @Count [INT] , @Added [FLOAT] , 
		@Discount [FLOAT] , @DeliveryFees [FLOAT]
	DECLARE @UserSubTotal [FLOAT] , @UserReturnSubTotal [FLOAT] , @UserTotal [FLOAT] , @UserCount [INT] , 
		@UserAdded [FLOAT] , @UserDiscount [FLOAT] , @UserDeliveryFees [FLOAT]
	
	SELECT  @SubTotal =		  SUM( IIF( Type != 4 , SubTotal , 0 ) ), 
			@ReturnSubTotal = SUM( IIF( Type = 4 , SubTotal , 0 ) ),
			@Count =		  COUNT( o.GUID ),
			@Added =		  SUM( Added * Direction),
			@Discount =		  SUM( Discount * Direction), 
			@DeliveryFees =	  SUM ( DeliveringFees * Direction),
			@ReturnedOrderTotal = SUM( ( SubTotal + Added - Discount + Tax  ) * IIF( Type = 4 , -1 , 0 ) ) , 
		    @DeliveryOrderTotal = SUM( ( SubTotal + Added - Discount + Tax + DeliveringFees ) * IIF( Type = 3 , 1 , 0 ) ) ,  
		    @OuterOrderTotal  = SUM( ( SubTotal + Added - Discount + Tax  ) * IIF( Type = 2 , 1 , 0 ) ) ,  
		    @TableOrderTotal = SUM( ( SubTotal + Added - Discount + Tax  ) * IIF( Type = 1 , 1 , 0 ) ) ,
		    @Total = @TableOrderTotal + @OuterOrderTotal + @DeliveryOrderTotal + @ReturnedOrderTotal
	FROM RestOrder000 o 
	INNER JOIN @selectedOrders s ON o.Guid = s.GUID

	CREATE TABLE #t 
	(
		[ID] [UNIQUEIDENTIFIER],
		[Total] [FLOAT],
		[Notes] [NVARCHAR](100),
		[Type] [INT],
		[PARENTID] [UNIQUEIDENTIFIER],
		[SortNum] [INT] IDENTITY(0,1)
	)

	INSERT INTO #t 
	SELECT  @PaidAndReceived , ISNULL( SUM( IIF ( Type = 0 , -1 , 1 ) * Value ) , 0) + @Total, '', 1, 0x0  
	FROM RestEntry000
	WHERE Date BETWEEN @StartDate AND @EndDate
	
	INSERT INTO #t 		
	VALUES (@NetSales , @Total , ' ' , 2 , @PaidAndReceived) , 
				  (NEWID() , @Count , ' ' ,	 3 , @NetSales  ) , 
				  (NEWID() , @SubTotal , ' ' , 4 , @NetSales ) , 
				  (NEWID() , @ReturnSubTotal , ' ' , 5 , @NetSales ) , 
				  (NEWID() , @Added , ' ' , 6  , @NetSales ) ,
				  (NEWID() , @Discount, ' ' , 7  , @NetSales ),
				  (NEWID() , @DeliveryFees, ' ' , 8  , @NetSales ) 
	
	
	INSERT INTO #t  
	SELECT NEWID() , SUM(CalculatedValue * Direction) ,   rt.Name  + ' ' + 
			CAST(rt.Value AS NVARCHAR(12)) + ' % '   , 30 , @NetSales 
	FROM RestDiscTax000 rdt
	INNER JOIN RestTaxes000 rt ON rt.Guid = ParentTaxID
	INNER JOIN @selectedOrders o ON o.Guid = rdt.ParentID
	GROUP BY  rt.Name , rt.Value 
	
	INSERT INTO #t 
	SELECT NEWID() , SUM( Value ) AS Value , ' ' , Type + 9 , @PaidAndReceived  
	FROM RestEntry000
	WHERE Date BETWEEN @StartDate AND @EndDate
	GROUP BY Type

	IF @@ROWCOUNT = 0 
	INSERT INTO #t  VALUES   
					(NEWID() , 0 , ' ' , 9 , @PaidAndReceived) ,
					(NEWID() , 0 , ' ' , 10 , @PaidAndReceived)
	
	IF @UserDetail = 1 
	BEGIN 
		DECLARE @SalesByUser [UNIQUEIDENTIFIER] = NEWID()	
		INSERT INTO #t SELECT @SalesByUser , @Total , ' ' , 11 , 0x0  
		
		SELECT * INTO #user FROM  us000 us
		WHERE EXISTS(SELECT 1 FROM @selectedOrders WHERE FinishCashierId = us.GUID)
		
		WHILE EXISTS( SELECT 1 FROM #user)
		BEGIN 
			DECLARE @user [UNIQUEIDENTIFIER] = ( SELECT TOP 1 GUID FROM #user)
		
			SELECT @UserTotal =			  SUM( (SubTotal + Added - Discount + Tax + DeliveringFees) * Direction ) , 
					@UserSubTotal =		  SUM( IIF( Type != 4 , SubTotal , 0 ) ), 
					@UserReturnSubTotal = SUM( IIF( Type = 4 , SubTotal , 0 ) ), 
					@UserCount =		  COUNT( o.GUID ),
					@UserAdded =		  SUM( Added * Direction), 
					@UserDiscount =		  SUM( Discount * Direction) , 
					@UserDeliveryFees =	  SUM( DeliveringFees * Direction)
			FROM RestOrder000 o
			INNER JOIN @selectedOrders s ON o.Guid = s.GUID
			WHERE o.FinishCashierID = @user 
		
			INSERT INTO #t
			SELECT @user , @UserTotal , us.LoginName , 12 , @SalesByUser 
			FROM #user us
			WHERE GUID = @user
		
			INSERT INTO #t  VALUES 
							  (NEWID() , @UserCount , ' ' ,	 3 , @user ) , 
							  (NEWID() , @UserSubTotal , ' ' , 4 , @user) , 
							  (NEWID() , @UserReturnSubTotal , ' ' , 5 , @user) , 
							  (NEWID() , @UserAdded , ' ' , 6  , @user ) ,
							  (NEWID() , @UserDiscount, ' ' , 7  , @user ),
							  (NEWID() , @UserDeliveryFees, ' ' , 8  , @user )
		
			INSERT INTO #t 
			SELECT NEWID() , SUM(CalculatedValue * Direction) , rt.Name  + ' ' + 
					CAST(rt.Value AS NVARCHAR(12)) + ' % '   , 30 , @user
			FROM RestDiscTax000 rdt
			INNER JOIN RestTaxes000 rt ON rt.Guid = ParentTaxID
			INNER JOIN  @selectedOrders o 
			ON o.Guid = rdt.ParentID AND o.FinishCashierID = @user
			GROUP BY  rt.Name , rt.Value 
		
			DELETE FROM #user WHERE GUID = @user
		END
	
	END

	IF @PayDetail = 1 
	BEGIN 
		DECLARE @SalesByPayType [UNIQUEIDENTIFIER] = NEWID() 	
		INSERT INTO #t SELECT @SalesByPayType , @Total , ' ' , 13 , 0x0 
	
		INSERT INTO #t 
		SELECT NEWID() , [Total] , ' ' , [Type], @SalesByPayType  FROM (
			SELECT  SUM( (Cur.Paid - cur.Returned) * Equal * Direction) AS [Total] , 14 AS [Type]
			FROM POSPaymentsPackage000 p
			INNER JOIN POSPaymentsPackageCurrency000 cur ON cur.ParentID = p.Guid
			INNER JOIN @selectedOrders o ON o.PaymentPackageID = p.GUID 
			UNION ALL 
			SELECT  SUM ( p.DeferredAmount * Direction) ,  15 
			FROM POSPaymentsPackage000 p
			INNER JOIN @selectedOrders o ON o.PaymentPackageID = p.GUID 
			WHERE DeferredAmount > 0
			UNION ALL 
			SELECT  SUM((ch.Paid / CurrencyValue) * Direction ) AS [Total] , 16 
			FROM POSPaymentsPackage000 p
			INNER JOIN POSPaymentsPackageCheck000 ch ON ch.ParentID = p.Guid
			INNER JOIN @selectedOrders o ON o.PaymentPackageID = p.GUID 
		) t
		WHERE [Total] IS NOT NULL
		ORDER BY t.[Type]
		
	END


	IF @GrDetail = 1
	BEGIN
		DECLARE @SalesByGr [UNIQUEIDENTIFIER] = NEWID()
		INSERT INTO #t  
		VALUES ( @SalesByGr , @SubTotal - @ReturnSubTotal, ' ' , 17 , 0x0 )
		
		DECLARE @Level INT = 0
		
		SELECT  SUM(Price * oi.Qty * Direction) AS [Total]   , gr.GUID , gr.ParentGUID , 0  AS [Level]
		INTO #Gr
		FROM RestOrderItem000 oi
		INNER JOIN mt000 mt ON mt.GUID = oi.MatID		
		INNER JOIN gr000 gr ON 	gr.GUID = mt.GroupGUID		
		INNER JOIN  @selectedOrders o ON oi.ParentID = o.GUID 
		GROUP BY 	gr.GUID , gr.ParentGUID
		
		CREATE TABLE [#GrLevel] ([GGuid] [UNIQUEIDENTIFIER], [Level] INT, [grName] NVARCHAR(256),
			 [grLatinName] NVARCHAR(256), [grParent] [UNIQUEIDENTIFIER])
	
		INSERT INTO [#GrLevel] SELECT g.[GUID] AS [GGuid],g.[Level],[grName],[grLatinName],[grParent] 
		FROM  [fnGetGroupsOfGroupSorted](0x0,1)  g 
		INNER JOIN [vwGr] ON [GUID] = [grGuid]
		
		UPDATE [#Gr] SET [Level] = [gr].[Level] FROM [#Gr] AS [er] INNER JOIN [#GrLevel] AS [gr] ON [GGUID] = er.GUID 
		SELECT @Level = MAX([Level]) FROM  [#GrLevel] 
	
		WHILE (@Level > =0)  
		BEGIN
			INSERT INTO #Gr 
			SELECT SUM([Total]) , grLevel.GGuid , grLevel.grParent , grLevel.Level
			FROM #Gr gr 
			INNER JOIN #GrLevel grLevel ON grLevel.GGuid = gr.ParentGUID
			WHERE gr.[Level] = @Level 
			GROUP BY grLevel.GGuid , grLevel.grParent , grLevel.Level
	
			SET @Level = @Level - 1  
		END
			
		INSERT INTO #t  
		SELECT g.GUID , SUM(g.[Total])  , Name , 30 , IIF ( g.ParentGUID = 0x0 , @SalesByGr , g.ParentGUID) 
		FROM   #Gr g 
		INNER JOIN gr000 gr ON gr.GUID = g.GUID
		WHERE [Level] < @GrLevel OR @GrLevel = 0  
		GROUP BY g.GUID , Name  , IIF ( g.ParentGUID = 0x0 , @SalesByGr , g.ParentGUID)
	
	END

	IF @MtDetail = 1
	BEGIN
		DECLARE @SalesByMat [UNIQUEIDENTIFIER] = NEWID()
		INSERT INTO #t  
		VALUES ( @SalesByMat , @SubTotal - @ReturnSubTotal , ' ' , 18 , 0x0 )
	
		INSERT INTO #t  
		SELECT NEWID()  , [Total] , mt.Name , 30 , @SalesByMat  FROM (
				SELECT SUM(( Price * Qty * Direction )) AS [Total] , MatID 
				FROM RestOrderItem000 oi
				INNER JOIN  @selectedOrders o ON oi.ParentID = o.GUID 
				GROUP BY MatID 
		) t 
		INNER JOIN mt000 mt ON mt.GUID = t.MatID
	END

	IF @SalesDetailByOrderType = 1 
	BEGIN 
		DECLARE @SalesByOrderType [UNIQUEIDENTIFIER] = NEWID()
		INSERT INTO #t  
		VALUES ( @SalesByOrderType , @Total , ' ' , 19 , 0x0  )
	
		DECLARE @TableOrder [UNIQUEIDENTIFIER] = NEWID()
		DECLARE @OuterOrder [UNIQUEIDENTIFIER] = NEWID()
		DECLARE @DeliveryOrder [UNIQUEIDENTIFIER] = NEWID()
		DECLARE @ReturnedOrder [UNIQUEIDENTIFIER] = NEWID()

		INSERT INTO #t VALUES ( @TableOrder, @TableOrderTotal, ' ', 20 , @SalesByOrderType ) 

		IF @BillsDetailByOrderType = 1
		BEGIN
			INSERT INTO #t  
			SELECT NEWID() ,  SubTotal + Added - Discount + Tax   , 
			 '( '  + CAST(ot.Code AS NVARCHAR(35))  + ' ) - ' + CAST(o.Ordernumber AS NVARCHAR(8)), 
			24  , @TableOrder 
			FROM RestOrder000 o 
			INNER JOIN fnGetRestOrderTables(0x0) ot ON o.Guid = ot.ParentGuid
			WHERE EXISTS ( SELECT 1 FROM @selectedOrders s WHERE o.Guid = s.GUID )
			ORDER BY o.Ordernumber
		END

		INSERT INTO #t VALUES ( @OuterOrder, @OuterOrderTotal, ' ', 21 , @SalesByOrderType ) 
		
		IF @BillsDetailByOrderType = 1
		BEGIN
			INSERT INTO #t  
			SELECT NEWID() ,  SubTotal + Added - Discount + Tax   ,
			' - '  + CAST(o.Ordernumber AS NVARCHAR(8))  , 25  , @OuterOrder 
			FROM RestOrder000 o
			WHERE EXISTS ( SELECT 1 FROM @selectedOrders s WHERE o.Guid = s.GUID )
			AND o.Type = 2
			ORDER BY o.Ordernumber
		END

		INSERT INTO #t VALUES ( @DeliveryOrder, @DeliveryOrderTotal, ' ', 22 , @SalesByOrderType ) 
		
		IF @BillsDetailByOrderType = 1
		BEGIN
			INSERT INTO #t
			SELECT NEWID() ,  SubTotal + Added - Discount + Tax + DeliveringFees   ,
			cu.CustomerName + ' - ' + CAST(o.Ordernumber AS NVARCHAR(8)) , 30  , @DeliveryOrder 
			FROM RestOrder000 o
			INNER JOIN cu000 cu ON cu.GUID = o.CustomerID
			WHERE EXISTS ( SELECT 1 FROM @selectedOrders s WHERE o.Guid = s.GUID )
			AND o.Type = 3
			ORDER BY o.Ordernumber
		END

		INSERT INTO #t VALUES ( @ReturnedOrder, @ReturnedOrderTotal, ' ', 23 , @SalesByOrderType ) 

		IF @BillsDetailByOrderType = 1
		BEGIN
			INSERT INTO #t  
			SELECT NEWID() ,  -(SubTotal + Added - Discount + Tax)   ,
			' - '  + CAST(o.Ordernumber AS NVARCHAR(8))  , 26  , @ReturnedOrder 
			FROM RestOrder000 o
			WHERE EXISTS ( SELECT 1 FROM @selectedOrders s WHERE o.Guid = s.GUID )
			AND o.Type = 4
			ORDER BY o.Ordernumber
		END
	END
	
	SELECT * FROM #t ORDER BY  SortNum
	
	SELECT MIN(Opening) AS [firstOrder] , MAX(Opening)  AS [lastOrder] , GETDATE() AS [CurrentDate]
	FROM RestOrder000 o
	WHERE EXISTS ( SELECT 1 FROM @selectedOrders s WHERE o.Guid = s.GUID )

###########################
#END