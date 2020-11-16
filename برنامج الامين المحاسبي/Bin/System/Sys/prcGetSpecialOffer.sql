#####################################################################
CREATE VIEW vwPOSOrderItemsTempWithOutCanceled
AS
	SELECT * FROM POSOrderItemsTemp000 WHERE [State] <> 1 AND SpecialOfferIndex <> 2 AND [Type] <> 1
#####################################################################
CREATE VIEW vwPOSOrderItemsTempWithOutCanceledGroupedOnQty
AS
	SELECT ParentID, SUM(Qty) Qty, MatID FROM vwPOSOrderItemsTempWithOutCanceled
		GROUP BY ParentID, MatID
#####################################################################
CREATE FUNCTION fnGetSqlCheckCusts
	(
		@CustGUID [UNIQUEIDENTIFIER] = 0x0, 
		@AccGUID [UNIQUEIDENTIFIER] = 0x0, 
		@CondGuid [UNIQUEIDENTIFIER] = 0x00
	)
RETURNS NVARCHAR(MAX)

AS 

BEGIN	 
	DECLARE 
		@HasCond [INT], 
		@Criteria [NVARCHAR](max), 
		@SQL [NVARCHAR](max), 
		@HaveCFldCondition	BIT -- to check existing Custom Fields , it must = 1 
	SET @CustGUID = ISNULL(@CustGUID, 0x0) 
	SET @AccGUID = ISNULL(@AccGUID, 0x0) 
	SET @SQL = ' SELECT [cuGuid] AS [Guid], [cuSecurity] AS [Security] '
	SET @SQL = @SQL + ' FROM [vwCu] ' 
			
	IF @AccGUID <> 0x0 
		SET @SQL = @SQL + ' INNER JOIN [dbo].[fnGetCustsOfAcc]( ''' + CONVERT( [NVARCHAR](255), @AccGUID) + ''') AS [f] ON [vwCu].[cuGuid] = [f].[Guid]' 
	
	IF ISNULL(@CondGUID,0X00) <> 0X00 
	BEGIN 
		SET @Criteria = [dbo].[fnGetCustConditionStr](@CondGUID) 
		IF @Criteria <> '' 
		BEGIN 
			IF (RIGHT(@Criteria,4) = '<<>>')-- <<>> to Aknowledge Existing Custom Fields 
			BEGIN 
				SET @HaveCFldCondition = 1 
				SET @Criteria = REPLACE(@Criteria,'<<>>','')  
			END 
			SET @Criteria = '(' + @Criteria + ')' 
		END 
	END 
	ELSE 
		SET @Criteria = '' 
-------------------------------------------------------------------------------------------------------
-- Inserting Condition Of Custom Fields 
-------------------------------------------------------------------------------------------------------- 
	IF @HaveCFldCondition > 0 
		Begin 
			Declare @CF_Table NVARCHAR(255) 
			SET @CF_Table = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'cu000') 	
			SET @SQL = @SQL + ' INNER JOIN ' + @CF_Table + ' ON [vwCu].[cuGuid] = ' + @CF_Table + '.Orginal_Guid ' 
		End 
-------------------------------------------------------------------------------------------------------
	SET @SQL = @SQL + ' 
		WHERE 1 = 1 ' 
	IF @Criteria <> '' 
		SET @SQL = @SQL + ' AND (' + @Criteria + ')' 
	IF @CustGUID <> 0x0 
		SET @SQL = @SQL + ' AND [cuGUID] = ''' + CONVERT( [NVARCHAR](255), @CustGUID) + '''' 


		SET @SQL = 'IF EXISTS(' + @SQL + ') SELECT @res = 1 ELSE Select @res = 0'

	RETURN @SQL
END
#####################################################################
CREATE VIEW vwSpecialOfferDetailUnits
AS
SELECT od.Number, od.[Guid], od.ParentID, od.MatID, CASE od.Unit WHEN 2 THEN od.Qty * mt.Unit2Fact WHEN 3 THEN od.Qty * mt.Unit3Fact ELSE od.Qty END Qty, od.Unit, od.[Group]
	FROM SpecialOfferDetails000 od
		INNER JOIN mt000 mt ON od.MatID = mt.GUID
			WHERE od.[Group] = 0
#####################################################################
CREATE VIEW vwSpecialOfferDetail
AS
SELECT so.*,
		sod.GUID sodID,
		sod.MatID ActualMatID,
		CASE so.Condition WHEN 1 THEN so.Qty ELSE sod.Qty END ActualQty,
		CASE so.Condition WHEN 1 THEN so.Unit ELSE sod.Unit END ActualUnit
	FROM SpecialOffer000 so
	INNER JOIN vwSpecialOfferDetailUnits sod ON so.Guid = sod.ParentID
		WHERE sod.[Group] = 0
UNION ALL
SELECT so.*,
		sod.GUID sodID,
		mt.GUID ActualMatID,
		CASE so.Condition WHEN 1 THEN so.Qty ELSE sod.Qty END ActualQty,
		CASE so.Condition WHEN 1 THEN so.Unit ELSE sod.Unit END ActualUnit 
	FROM SpecialOffer000 so
	INNER JOIN SpecialOfferDetails000 sod ON so.Guid = sod.ParentID
	INNER JOIN gr000 gr ON sod.MatID = gr.GUID AND sod.[Group] = 1
	INNER JOIN mt000 mt ON gr.GUID = mt.GroupGUID
#####################################################################
CREATE VIEW vwOrderItemGroup
AS
SELECT oi.ParentID, SUM(oi.Qty) Qty, mt.GroupGUID FROM vwPOSOrderItemsTempWithOutCanceled oi
	INNER JOIN mt000 mt ON oi.MatID = mt.GUID
	WHERE OfferedItem <> 1
		GROUP BY oi.ParentID, mt.GroupGUID
#####################################################################
CREATE VIEW vwMatOfferDetails
AS
SELECT	so.Guid soID,
		sod.GUID sodID,
		sod.MatID MatID,
		CASE so.Condition WHEN 1 THEN so.Qty ELSE sod.Qty END ActualQty,
		CASE so.Condition WHEN 1 THEN so.Unit ELSE sod.Unit END ActualUnit 
	FROM SpecialOffer000 so
	INNER JOIN SpecialOfferDetails000 sod ON so.Guid = sod.ParentID
	WHERE sod.[Group] = 0
#####################################################################
CREATE VIEW vwGroupOfferDetails
AS
SELECT	so.Guid soID,
		sod.GUID sodID,
		sod.MatID GroupID,
		CASE so.Condition WHEN 1 THEN so.Qty ELSE sod.Qty END ActualQty,
		CASE so.Condition WHEN 1 THEN so.Unit ELSE sod.Unit END ActualUnit 
	FROM SpecialOffer000 so
	INNER JOIN SpecialOfferDetails000 sod ON so.Guid = sod.ParentID
	WHERE sod.[Group] = 1
#####################################################################
CREATE FUNCTION fnPOSGetOrderOfferedItem 
(
	@ApplayCount INT, @OfferID UNIQUEIDENTIFIER, @OrderID UNIQUEIDENTIFIER
)
RETURNS
	@res TABLE (ItemGuid UNIQUEIDENTIFIER, Qty FLOAT)
AS
BEGIN
	DECLARE @GroupId UNIQUEIDENTIFIER, @OfferQty FLOAT
	DECLARE OfferItemCursor
		CURSOR FOR SELECT MatID, Qty FROM SpecialOfferDetails000 WHERE ParentID = @OfferID AND [Group] = 1
	OPEN OfferItemCursor
	
	FETCH NEXT FROM OfferItemCursor 
	INTO @GroupId, @OfferQty

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @OfferQty = @OfferQty * @ApplayCount
		
		DECLARE @OrderItemId UNIQUEIDENTIFIER, @OrderItemQty FLOAT
		DECLARE OrderItemCursor CURSOR FOR SELECT Guid, Qty FROM vwPOSOrderItemsTempWithOutCanceled 
			WHERE ParentID = @OrderID
				AND MatID IN (SELECT Guid FROM mt000 WHERE GroupGUID = @GroupId)
		 ORDER BY Price, Number
		 OPEN OrderItemCursor

		 FETCH NEXT FROM OrderItemCursor 
			INTO @OrderItemId, @OrderItemQty

		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF @OfferQty > @OrderItemQty
			BEGIN
				INSERT INTO @res VALUES (@OrderItemId, @OrderItemQty)
				SET @OfferQty = @OfferQty - @OrderItemQty
			END
			ELSE
			BEGIN
				INSERT INTO @res VALUES (@OrderItemId, @OfferQty)
				BREAK;
			END
			 FETCH NEXT FROM OrderItemCursor 
				INTO @OrderItemId, @OrderItemQty
		END

		CLOSE OrderItemCursor;  
		DEALLOCATE OrderItemCursor;

		FETCH NEXT FROM OfferItemCursor   
		INTO @GroupId, @OfferQty
	END
	CLOSE OfferItemCursor;  
	DEALLOCATE OfferItemCursor;
	RETURN
END
#####################################################################
CREATE FUNCTION fnPOSGetOrderOfferedWhole
(
       @ApplayCount INT, @OfferID UNIQUEIDENTIFIER, @OrderID UNIQUEIDENTIFIER
)
RETURNS
       @res TABLE (ItemGuid UNIQUEIDENTIFIER, Qty FLOAT)
AS
BEGIN
       DECLARE @OfferQty FLOAT, @OrderItemId UNIQUEIDENTIFIER, @OrderItemQty FLOAT
       DECLARE @allMat TABLE(GUID UNIQUEIDENTIFIER)
       DECLARE OrderItemCursor CURSOR FOR SELECT Guid, Qty FROM vwPOSOrderItemsTempWithOutCanceled 
              WHERE ParentID = @OrderID
                     AND (MatID IN (SELECT Guid FROM mt000 WHERE GroupGUID IN (SELECT GUID FROM @allMat))
                     OR MatID IN (SELECT GUID FROM @allMat))
              ORDER BY Price, Number

       SET @OfferQty = (SELECT Qty FROM SpecialOffer000 WHERE Guid = @OfferID) * @ApplayCount

       INSERT INTO @allMat
              SELECT GUID FROM mt000 WHERE GroupGUID IN (SELECT MatID FROM SpecialOfferDetails000 WHERE ParentID = @OfferID) OR GUID IN (SELECT MatID FROM SpecialOfferDetails000 WHERE ParentID = @OfferID)

       OPEN OrderItemCursor
       FETCH NEXT FROM OrderItemCursor 
       INTO @OrderItemId, @OrderItemQty
       WHILE @@FETCH_STATUS = 0
       BEGIN
              IF @OfferQty > @OrderItemQty
              BEGIN
                     INSERT INTO @res VALUES (@OrderItemId, @OrderItemQty)
                     SET @OfferQty = @OfferQty - @OrderItemQty
              END
              ELSE
              BEGIN
                     IF @OfferQty > 0
                     BEGIN
                           INSERT INTO @res VALUES (@OrderItemId, @OfferQty)
                           SET @OfferQty = @OfferQty - @OrderItemQty
                     END
                     BREAK;
              END
                     FETCH NEXT FROM OrderItemCursor 
                     INTO @OrderItemId, @OrderItemQty
       END
       CLOSE OrderItemCursor;  
       DEALLOCATE OrderItemCursor;
              
       RETURN
END
#####################################################################
CREATE FUNCTION fnPOSGetOrderOfferedMatItem 
(
	@ApplayCount INT, @OfferID UNIQUEIDENTIFIER, @OrderID UNIQUEIDENTIFIER
)
RETURNS
	@res TABLE (ItemGuid UNIQUEIDENTIFIER, Qty FLOAT)
AS
BEGIN
	DECLARE @MatID UNIQUEIDENTIFIER, @OfferQty FLOAT
	DECLARE OfferItemCursor
		CURSOR FOR SELECT MatID, Qty FROM SpecialOfferDetails000 WHERE ParentID = @OfferID AND [Group] = 0
	OPEN OfferItemCursor
	
	FETCH NEXT FROM OfferItemCursor 
	INTO @MatID, @OfferQty

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @OfferQty = @OfferQty * @ApplayCount
		
		DECLARE @OrderItemId UNIQUEIDENTIFIER, @OrderItemQty FLOAT
		DECLARE OrderItemCursor CURSOR FOR SELECT Guid, Qty FROM vwPOSOrderItemsTempWithOutCanceled 
			WHERE ParentID = @OrderID
				AND MatID = @MatID
		 ORDER BY Price, Number
		 OPEN OrderItemCursor

		 FETCH NEXT FROM OrderItemCursor 
			INTO @OrderItemId, @OrderItemQty

		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF @OfferQty > @OrderItemQty
			BEGIN
				INSERT INTO @res VALUES (@OrderItemId, @OrderItemQty)
				SET @OfferQty = @OfferQty - @OrderItemQty
			END
			ELSE
			BEGIN
				INSERT INTO @res VALUES (@OrderItemId, @OfferQty)
				BREAK;
			END
			 FETCH NEXT FROM OrderItemCursor 
				INTO @OrderItemId, @OrderItemQty
		END

		CLOSE OrderItemCursor;  
		DEALLOCATE OrderItemCursor;

		FETCH NEXT FROM OfferItemCursor   
		INTO @MatID, @OfferQty
	END
	CLOSE OfferItemCursor;  
	DEALLOCATE OfferItemCursor;
	RETURN
END
#####################################################################
CREATE PROCEDURE prcApplySpecialOfferOnMixedItem
		@orderId UNIQUEIDENTIFIER, 
		@orderItemId UNIQUEIDENTIFIER,
		@orderItemBillId UNIQUEIDENTIFIER,
		@OrderItemQty FLOAT,
		@OrderItemType INT,
		@offerId UNIQUEIDENTIFIER, 
		@AccountID UNIQUEIDENTIFIER,
		@MatAccountID UNIQUEIDENTIFIER,
		@DiscountAccountID UNIQUEIDENTIFIER,
		@DivDiscount INT,
		@Type INT,
		@Condition INT,
		@Qty FLOAT,
		@Discount FLOAT,
		@DiscountType INT,
		@OfferMode	INT,
		@MatID UNIQUEIDENTIFIER,
		@GroupID UNIQUEIDENTIFIER,
		@Unit INT,
		@ApplayOnce BIT,
		@CheckExactQty BIT
AS
IF @Condition = 0
BEGIN
	DECLARE @OfferQty FLOAT
	IF @CheckExactQty = 1
	BEGIN
		DECLARE @counter INT = 0;
		SELECT * INTO #OrderItems FROM vwPOSOrderItemsTempWithOutCanceledGroupedOnQty WHERE ParentID = @orderId
		WHILE EXISTS (SELECT * FROM #OrderItems)
		BEGIN
			IF NOT EXISTS(SELECT so.Guid FROM vwSpecialOfferDetail so
						LEFT JOIN #OrderItems oi ON so.ActualMatID = oi.MatID AND so.ActualQty <= oi.Qty
							WHERE oi.MatID IS NULL AND so.Guid = @offerId
								GROUP BY oi.MatID, so.Guid)
			BEGIN
				UPDATE oi
					SET oi.Qty = oi.Qty - md.ActualQty
				FROM #OrderItems oi
				INNER JOIN vwMatOfferDetails md ON oi.MatID = md.MatID

				SET @counter = @counter + 1;

				DELETE #OrderItems WHERE Qty <= 0
			END
			ELSE
			BEGIN
				DELETE #OrderItems
			END
		END
		DROP TABLE #OrderItems
		SET @OfferQty = @counter;
	END
	ELSE IF @ApplayOnce = 1
	BEGIN
		SET @OfferQty = 1
	END
	ELSE
	BEGIN
		SET @OfferQty = (SELECT SUM(Qty) FROM POSOrderItemsTemp000 WHERE ParentID = @orderId)
	END

	IF @Type = 0 -- Discount Offerr
	BEGIN
		IF @DivDiscount <> 0
		BEGIN
			UPDATE oi 
					SET oi.SpecialOfferID = 0x0,
						oi.Discount = 0
				OUTPUT inserted.Guid, 1 INTO #OfferedItems
				FROM POSOrderItemstemp000 oi
				WHERE oi.SpecialOfferID = @offerId AND oi.ParentID = @orderId

			UPDATE oi 
					SET oi.SpecialOfferID = @offerId,
						oi.Discount = CASE @DiscountType WHEN 0 THEN (@Discount / 100) * (oi.Price * so.Qty)
							ELSE @Discount * @OfferQty END
				OUTPUT inserted.Guid, 1 INTO #OfferedItems
				FROM POSOrderItemsTemp000 oi
				INNER JOIN dbo.fnPOSGetOrderOfferedMatItem(@OfferQty, @offerId, @orderId) so ON oi.Guid = so.ItemGuid
		END
		ELSE
		BEGIN
			UPDATE oi
					SET oi.SpecialOfferID = @offerId
				OUTPUT inserted.Guid, 1 INTO #OfferedItems
				FROM POSOrderItemsTemp000 oi
				INNER JOIN dbo.fnPOSGetOrderOfferedMatItem(@OfferQty, @offerId, @orderId) so ON oi.Guid = so.ItemGuid

			DELETE di 
				FROM POSOrderDiscountTemp000 di
					INNER JOIN POSOrderItemsTemp000 oi ON di.OrderItemID = oi.Guid
				WHERE oi.SpecialOfferID = @offerId AND di.ParentID = @orderId AND SpecialOffer = 1

			INSERT INTO POSOrderDiscountTemp000
				([Number]
			   ,[Guid]
			   ,[Type]
			   ,[ParentID]
			   ,[Value]
			   ,[AccountID]
			   ,[Notes]
			   ,[OrderType]
			   ,[SpecialOffer]
			   ,[OrderItemID])
			VALUES 
			((SELECT ISNULL(MAX(Number), 0) + 1 FROM POSOrderDiscount000)
			, NEWID()
			, @OrderItemType
			, @orderId
			, CASE @DiscountType WHEN 0 THEN (@Discount / 100) * 
				(SELECT SUM(oi.Price * so.Qty) FROM vwPOSOrderItemsTempWithOutCanceled oi
					INNER JOIN dbo.fnPOSGetOrderOfferedMatItem(@OfferQty, @offerId, @orderId) so ON oi.Guid = so.ItemGuid)
					 ELSE @Discount * @OfferQty END
			, @DiscountAccountID
			, ''
			, 0
			, 1
			, (select top 1 guid from POSOrderItemstemp000 where SpecialOfferID = @offerId))
		END
	END
	ELSE
	BEGIN
		DELETE oi2
			OUTPUT deleted.Guid, 2 INTO #OfferedItems
			FROM POSOrderItemsTemp000 oi2
				WHERE oi2.OfferedItem = 1 AND oi2.SpecialOfferID IN(SELECT oi.SpecialOfferID FROM vwSpecialOfferDetail so
						LEFT JOIN POSOrderItemsTemp000 oi ON so.ActualMatID = oi.MatID
							WHERE so.Guid = @offerId)

		DELETE di 
			FROM POSOrderDiscountTemp000 di
				INNER JOIN POSOrderItemsTemp000 oi ON di.OrderItemID = oi.Guid
				INNER JOIN dbo.fnPOSGetOrderOfferedMatItem(@OfferQty, @offerId, @orderId) so ON oi.Guid = so.ItemGuid
		
		UPDATE oi
				SET oi.SpecialOfferID = @offerId
			OUTPUT inserted.Guid, 1 INTO #OfferedItems
			FROM POSOrderItemstemp000 oi
				INNER JOIN dbo.fnPOSGetOrderOfferedMatItem(@OfferQty, @offerId, @orderId) so ON oi.Guid = so.ItemGuid

		
		INSERT INTO POSOrderItemsTemp000
			([Number]
           ,[Guid]
           ,[MatID]
           ,[Type]
           ,[Qty]
           ,[MatPrice]
           ,[VATValue]
           ,[Price]
           ,[PriceType]
           ,[Unity]
           ,[State]
           ,[Discount]
           ,[Added]
           ,[Tax]
           ,[ParentID]
           ,[ItemParentID]
           ,[SalesmanID]
           ,[PrinterID]
           ,[ExpirationDate]
           ,[ProductionDate]
           ,[AccountID]
           ,[BillType]
           ,[Note]
           ,[SpecialOfferID]
           ,[SpecialOfferIndex]
           ,[OfferedItem]
           ,[IsPrinted]
           ,[SerialNumber]
           ,[DiscountType]
           ,[ClassPtr]
           ,[RelatedBillID]
           ,[BillItemID])
		OUTPUT inserted.Guid, 0 INTO #OfferedItems
		SELECT
			   (SELECT ISNULL(MAX(Number), 0) + 1 FROM POSOrderItemsTemp000)
			   ,NEWID()
			   ,MatID
			   ,0
			   ,Qty * @OfferQty
			   ,Price
			   ,0
			   ,Price
			   ,PriceType
			   ,Unit
			   ,0
			   ,0
			   ,0
			   ,0
			   ,@orderId
			   ,0x0
			   ,0x0
			   ,0
			   ,'1980-01-01'
			   ,'1980-01-01'
			   ,0x0
			   ,@orderItemBillId
			   ,''
			   ,@offerId
			   ,2
			   ,1
			   ,0
			   ,''
			   ,1
			   ,''
			   ,0x0
			   ,0x0
			FROM OfferedItems000
				WHERE ParentID = @offerId
	END
END

#####################################################################
CREATE PROCEDURE prcApplySpecialOfferQuntityOnMixedItem
		@orderId UNIQUEIDENTIFIER, 
		@orderItemId UNIQUEIDENTIFIER,
		@orderItemBillId UNIQUEIDENTIFIER,
		@OrderItemQty FLOAT,
		@OrderItemType INT,
		@offerId UNIQUEIDENTIFIER, 
		@AccountID UNIQUEIDENTIFIER,
		@MatAccountID UNIQUEIDENTIFIER,
		@DiscountAccountID UNIQUEIDENTIFIER,
		@DivDiscount INT,
		@Type INT,
		@Condition INT,
		@Qty FLOAT,
		@Discount FLOAT,
		@DiscountType INT,
		@OfferMode	INT,
		@MatID UNIQUEIDENTIFIER,
		@GroupID UNIQUEIDENTIFIER,
		@Unit INT,
		@ApplayOnce BIT,
		@CheckExactQty BIT,
		@ApplayCount FLOAT
AS
IF @Condition = 1
BEGIN
	
	DECLARE @OfferQty FLOAT
	IF @CheckExactQty = 1
	BEGIN
		SET @OfferQty = @ApplayCount;
	END
	ELSE IF @ApplayOnce = 1
	BEGIN
		SET @OfferQty = 1
	END
	ELSE
	BEGIN
		SET @OfferQty = (SELECT SUM(Qty) FROM POSOrderItemsTemp000 WHERE ParentID = @orderId)
	END
	
	IF @Type = 0 -- Discount Offerr
	BEGIN
		IF @DivDiscount <> 0
		BEGIN
			UPDATE oi 
					SET oi.SpecialOfferID = 0x0,
						oi.Discount = 0
				OUTPUT inserted.Guid, 1 INTO #OfferedItems
				FROM POSOrderItemstemp000 oi
				WHERE oi.SpecialOfferID = @offerId AND oi.ParentID = @orderId

			UPDATE oi 
					SET oi.SpecialOfferID = @offerId,
						oi.Discount = CASE @DiscountType WHEN 0 THEN (@Discount / 100) * (oi.Price * oi.Qty) ELSE @Discount END
				OUTPUT inserted.Guid, 1 INTO #OfferedItems
				FROM POSOrderItemstemp000 oi
				INNER JOIN dbo.fnPOSGetOrderOfferedWhole(@OfferQty, @offerId, @orderId) so ON oi.Guid = so.ItemGuid
		END
		ELSE
		BEGIN
		
			DELETE di 
				FROM POSOrderDiscountTemp000 di
					INNER JOIN POSOrderItemstemp000 oi ON di.OrderItemID = oi.Guid
				--	INNER JOIN dbo.fnPOSGetOrderOfferedItem(@OfferQty, @offerId, @orderId) so ON oi.Guid = so.ItemGuid
				WHERE di.ParentID = @orderId AND SpecialOffer = 1 AND oi.SpecialOfferID = @offerId

			UPDATE oi 
					SET oi.SpecialOfferID = 0x0,
						oi.Discount = 0
				OUTPUT inserted.Guid, 1 INTO #OfferedItems
				FROM POSOrderItemstemp000 oi
				WHERE oi.SpecialOfferID = @offerId AND oi.ParentID = @orderId

			UPDATE oi
					SET oi.SpecialOfferID = @offerId
				OUTPUT inserted.Guid, 1 INTO #OfferedItems
				FROM POSOrderItemstemp000 oi
				INNER JOIN dbo.fnPOSGetOrderOfferedWhole(@OfferQty, @offerId, @orderId) so ON oi.Guid = so.ItemGuid


			INSERT INTO POSOrderDiscountTemp000 
				([Number]
			   ,[Guid]
			   ,[Type]
			   ,[ParentID]
			   ,[Value]
			   ,[AccountID]
			   ,[Notes]
			   ,[OrderType]
			   ,[SpecialOffer]
			   ,[OrderItemID])
			VALUES 
			((SELECT ISNULL(MAX(Number), 0) + 1 FROM POSOrderDiscount000)
			, NEWID()
			, @OrderItemType
			, @orderId
			, CASE @DiscountType WHEN 0 THEN (@Discount / 100) * 
				(SELECT SUM(oi.Price * so.Qty) FROM vwPOSOrderItemsTempWithOutCanceled oi
					INNER JOIN dbo.fnPOSGetOrderOfferedWhole(@OfferQty, @offerId, @orderId) so ON oi.Guid = so.ItemGuid)
					 ELSE @OfferQty * @Discount END
			, @DiscountAccountID
			, ''
			, 0
			, 1
			, (SELECT TOP 1 GUID FROM POSOrderItemstemp000 WHERE SpecialOfferID = @offerId ORDER BY Number))
		END
	END
	ELSE
	BEGIN

		DELETE oi
			OUTPUT deleted.Guid, 2 INTO #OfferedItems
			FROM POSOrderItemsTemp000 oi
				WHERE OfferedItem = 1 AND SpecialOfferID = @offerId

		UPDATE oi
				SET oi.SpecialOfferID = @offerId
			OUTPUT inserted.Guid, 1 INTO #OfferedItems
			FROM POSOrderItemstemp000 oi
				INNER JOIN dbo.fnPOSGetOrderOfferedWhole(@OfferQty, @offerId, @orderId) so ON oi.Guid = so.ItemGuid

		INSERT INTO POSOrderItemsTemp000
			([Number]
           ,[Guid]
           ,[MatID]
           ,[Type]
           ,[Qty]
           ,[MatPrice]
           ,[VATValue]
           ,[Price]
           ,[PriceType]
           ,[Unity]
           ,[State]
           ,[Discount]
           ,[Added]
           ,[Tax]
           ,[ParentID]
           ,[ItemParentID]
           ,[SalesmanID]
           ,[PrinterID]
           ,[ExpirationDate]
           ,[ProductionDate]
           ,[AccountID]
           ,[BillType]
           ,[Note]
           ,[SpecialOfferID]
           ,[SpecialOfferIndex]
           ,[OfferedItem]
           ,[IsPrinted]
           ,[SerialNumber]
           ,[DiscountType]
           ,[ClassPtr]
           ,[RelatedBillID]
           ,[BillItemID])
		OUTPUT inserted.Guid, 0 INTO #OfferedItems
		SELECT
			   (SELECT ISNULL(MAX(Number), 0) + 1 FROM POSOrderItemsTemp000)
			   ,NEWID()
			   ,MatID
			   ,0
			   ,Qty * @OfferQty
			   ,Price
			   ,0
			   ,Price
			   ,PriceType
			   ,Unit
			   ,0
			   ,0
			   ,0
			   ,0
			   ,@orderId
			   ,0x0
			   ,0x0
			   ,0
			   ,'1980-01-01'
			   ,'1980-01-01'
			   ,0x0
			   ,@orderItemBillId
			   ,''
			   ,@offerId
			   ,2
			   ,1
			   ,0
			   ,''
			   ,1
			   ,''
			   ,0x0
			   ,0x0
			FROM OfferedItems000
				WHERE ParentID = @offerId
	END
END
#####################################################################
CREATE PROCEDURE prcApplySpecialOfferOnGroupMixedItem
		@orderId UNIQUEIDENTIFIER, 
		@orderItemId UNIQUEIDENTIFIER,
		@orderItemBillId UNIQUEIDENTIFIER,
		@OrderItemQty FLOAT,
		@OrderItemType INT,
		@offerId UNIQUEIDENTIFIER, 
		@AccountID UNIQUEIDENTIFIER,
		@MatAccountID UNIQUEIDENTIFIER,
		@DiscountAccountID UNIQUEIDENTIFIER,
		@DivDiscount INT,
		@Type INT,
		@Condition INT,
		@Qty FLOAT,
		@Discount FLOAT,
		@DiscountType INT,
		@OfferMode	INT,
		@MatID UNIQUEIDENTIFIER,
		@GroupID UNIQUEIDENTIFIER,
		@Unit INT,
		@ApplayOnce BIT,
		@CheckExactQty BIT
AS
IF @Condition = 0
BEGIN
	
	DECLARE @OfferQty FLOAT
	IF @CheckExactQty = 1
	BEGIN
		DECLARE @counter INT = 0;
		SELECT * INTO #OrderItems FROM vwOrderItemGroup WHERE ParentID = @orderId
		WHILE EXISTS (SELECT * FROM #OrderItems)
		BEGIN
			IF NOT EXISTS(SELECT so.sodID FROM vwGroupOfferDetails so
		LEFT JOIN #OrderItems oi ON so.GroupID = oi.GroupGUID AND so.ActualQty <= oi.Qty
			WHERE oi.GroupGUID IS NULL AND so.soID = @offerId AND (ISNULL(oi.ParentID, 0x0) = 0x0 OR oi.ParentID = @orderId)
				GROUP BY so.sodID)
			BEGIN
				UPDATE oi
					SET oi.Qty = oi.Qty - od.ActualQty
				FROM #OrderItems oi
				INNER JOIN vwGroupOfferDetails od ON oi.GroupGUID = od.GroupID

				SET @counter = @counter + 1;

				DELETE #OrderItems WHERE Qty <= 0
			END
			ELSE
			BEGIN
				DELETE #OrderItems
			END
		END
		DROP TABLE #OrderItems
		SET @OfferQty = @counter;
	END
	ELSE IF @ApplayOnce = 1
	BEGIN
		SET @OfferQty = 1
	END
	ELSE
	BEGIN
		SET @OfferQty = (SELECT SUM(Qty) FROM POSOrderItemsTemp000 WHERE ParentID = @orderId)
	END
	
	IF @Type = 0 -- Discount Offerr
	BEGIN
		IF @DivDiscount <> 0
		BEGIN
			UPDATE oi 
					SET oi.SpecialOfferID = 0x0,
						oi.Discount = 0
				OUTPUT inserted.Guid, 1 INTO #OfferedItems
				FROM POSOrderItemstemp000 oi
				WHERE oi.SpecialOfferID = @offerId AND oi.ParentID = @orderId

			UPDATE oi 
					SET oi.SpecialOfferID = @offerId,
						oi.Discount = CASE @DiscountType WHEN 0 THEN (@Discount / 100) * (oi.Price * so.Qty) ELSE @Discount * @OfferQty END
				OUTPUT inserted.Guid, 1 INTO #OfferedItems
				FROM POSOrderItemstemp000 oi
				INNER JOIN dbo.fnPOSGetOrderOfferedItem(@OfferQty, @offerId, @orderId) so ON oi.Guid = so.ItemGuid
		END
		ELSE
		BEGIN
			DELETE di 
				FROM POSOrderDiscountTemp000 di
					INNER JOIN POSOrderItemstemp000 oi ON di.OrderItemID = oi.Guid
						WHERE di.ParentID = @orderId AND SpecialOffer = 1 AND oi.SpecialOfferID = @offerId

			DELETE di 
				FROM POSOrderDiscountTemp000 di
					INNER JOIN POSOrderItemstemp000 oi ON di.OrderItemID = oi.Guid
					INNER JOIN dbo.fnPOSGetOrderOfferedItem(@OfferQty, @offerId, @orderId) so ON oi.Guid = so.ItemGuid
						WHERE di.ParentID = @orderId AND SpecialOffer = 1

			UPDATE oi 
					SET oi.SpecialOfferID = 0x0
				OUTPUT inserted.Guid, 1 INTO #OfferedItems
				FROM POSOrderItemstemp000 oi
				WHERE oi.SpecialOfferID = @offerId AND oi.ParentID = @orderId

			UPDATE oi
					SET oi.SpecialOfferID = @offerId
				OUTPUT inserted.Guid, 1 INTO #OfferedItems
				FROM POSOrderItemstemp000 oi
				INNER JOIN dbo.fnPOSGetOrderOfferedItem(@OfferQty, @offerId, @orderId) so ON oi.Guid = so.ItemGuid
				
			INSERT INTO POSOrderDiscountTemp000 
				([Number]
			   ,[Guid]
			   ,[Type]
			   ,[ParentID]
			   ,[Value]
			   ,[AccountID]
			   ,[Notes]
			   ,[OrderType]
			   ,[SpecialOffer]
			   ,[OrderItemID])
			VALUES 
			((SELECT ISNULL(MAX(Number), 0) + 1 FROM POSOrderDiscount000)
			, NEWID()
			, @OrderItemType
			, @orderId
			, CASE @DiscountType WHEN 0 THEN (@Discount / 100) * 
				(SELECT SUM(oi.Price * so.Qty) FROM vwPOSOrderItemsTempWithOutCanceled oi
					INNER JOIN dbo.fnPOSGetOrderOfferedItem(@OfferQty, @offerId, @orderId) so ON oi.Guid = so.ItemGuid)
					 ELSE @Discount * @OfferQty END
			, @DiscountAccountID
			, ''
			, 0
			, 1
			, (select top 1 guid from POSOrderItemstemp000 where SpecialOfferID = @offerId))
		END
	END
	ELSE
	BEGIN
		DELETE oi
			OUTPUT deleted.Guid, 2 INTO #OfferedItems
			FROM POSOrderItemsTemp000 oi
				WHERE OfferedItem = 1 AND SpecialOfferIndex = 2 AND SpecialOfferID = @offerId

		DELETE oi
			OUTPUT deleted.Guid, 2 INTO #OfferedItems
			FROM POSOrderItemsTemp000 oi
				WHERE OfferedItem = 1 AND SpecialOfferIndex = 2 AND SpecialOfferID IN (
				SELECT oi.SpecialOfferID
					FROM POSOrderItemstemp000 oi
				INNER JOIN dbo.fnPOSGetOrderOfferedItem(@OfferQty, @offerId, @orderId) so ON oi.Guid = so.ItemGuid
				)

		UPDATE oi
				SET oi.SpecialOfferID = @offerId
			OUTPUT inserted.Guid, 1 INTO #OfferedItems
			FROM POSOrderItemstemp000 oi
				INNER JOIN dbo.fnPOSGetOrderOfferedItem(@OfferQty, @offerId, @orderId) so ON oi.Guid = so.ItemGuid

		INSERT INTO POSOrderItemsTemp000
			([Number]
           ,[Guid]
           ,[MatID]
           ,[Type]
           ,[Qty]
           ,[MatPrice]
           ,[VATValue]
           ,[Price]
           ,[PriceType]
           ,[Unity]
           ,[State]
           ,[Discount]
           ,[Added]
           ,[Tax]
           ,[ParentID]
           ,[ItemParentID]
           ,[SalesmanID]
           ,[PrinterID]
           ,[ExpirationDate]
           ,[ProductionDate]
           ,[AccountID]
           ,[BillType]
           ,[Note]
           ,[SpecialOfferID]
           ,[SpecialOfferIndex]
           ,[OfferedItem]
           ,[IsPrinted]
           ,[SerialNumber]
           ,[DiscountType]
           ,[ClassPtr]
           ,[RelatedBillID]
           ,[BillItemID])
		OUTPUT inserted.Guid, 0 INTO #OfferedItems
		SELECT
			   (SELECT ISNULL(MAX(Number), 0) + 1 FROM POSOrderItemsTemp000)
			   ,NEWID()
			   ,MatID
			   ,0
			   ,Qty * @OfferQty
			   ,Price
			   ,0
			   ,Price
			   ,PriceType
			   ,Unit
			   ,0
			   ,0
			   ,0
			   ,0
			   ,@orderId
			   ,0x0
			   ,0x0
			   ,0
			   ,'1980-01-01'
			   ,'1980-01-01'
			   ,0x0
			   ,@orderItemBillId
			   ,''
			   ,@offerId
			   ,2
			   ,1
			   ,0
			   ,''
			   ,1
			   ,''
			   ,0x0
			   ,0x0
			FROM OfferedItems000
				WHERE ParentID = @offerId
	END
END
#####################################################################
CREATE PROCEDURE prcApplySpecialOfferOnMat
		@orderId UNIQUEIDENTIFIER, 
		@orderItemId UNIQUEIDENTIFIER,
		@orderItemBillId UNIQUEIDENTIFIER,
		@OrderItemQty FLOAT,
		@OrderItemType INT,
		@offerId UNIQUEIDENTIFIER, 
		@AccountID UNIQUEIDENTIFIER,
		@MatAccountID UNIQUEIDENTIFIER,
		@DiscountAccountID UNIQUEIDENTIFIER,
		@DivDiscount INT,
		@Type INT,
		@Condition INT,
		@Qty FLOAT,
		@Discount FLOAT,
		@DiscountType INT,
		@OfferMode	INT,
		@MatID UNIQUEIDENTIFIER,
		@GroupID UNIQUEIDENTIFIER,
		@Unit INT,
		@ApplayOnce BIT,
		@CheckExactQty BIT,
		@OrderUnitFact FLOAT,
		@UnitFact FLOAT
AS
IF @Type = 0 -- Discount Offerr
	BEGIN
		IF @DivDiscount <> 0
		BEGIN
			UPDATE POSOrderItemstemp000
					SET SpecialOfferID = @offerId,
						Discount = CASE @DiscountType WHEN 0 THEN (@Discount / 100) * 
						(Price * (CASE WHEN @ApplayOnce = 1 THEN @Qty / @UnitFact WHEN @CheckExactQty = 1 THEN 
							(
								(@OrderItemQty - (CAST(CAST(@OrderItemQty AS DECIMAL(38,19)) % CAST(@Qty AS DECIMAL(38,19)) AS FLOAT))) / @OrderUnitFact
							)
							ELSE @OrderItemQty / @OrderUnitFact END))
							ELSE @Discount * 
								(CASE WHEN @ApplayOnce = 1 THEN 1 WHEN @CheckExactQty = 1 THEN 
							(
								(@OrderItemQty - (CAST(CAST(@OrderItemQty AS DECIMAL(38,19)) % CAST(@Qty AS DECIMAL(38,19)) AS FLOAT))) / @OrderUnitFact
							)/ @Qty
							ELSE @OrderItemQty / @OrderUnitFact END)
							 END
				OUTPUT inserted.Guid, 1 INTO #OfferedItems
				WHERE Guid = @orderItemId 
		END
		ELSE
		BEGIN
			DELETE FROM POSOrderDiscountTemp000 
				WHERE ParentID = @orderId AND OrderItemID = @orderItemId AND SpecialOffer = 1

			UPDATE POSOrderItemstemp000
					SET SpecialOfferID = @offerId
				OUTPUT inserted.Guid, 1 INTO #OfferedItems
				WHERE Guid = @orderItemId

			INSERT INTO POSOrderDiscountTemp000
				([Number]
			   ,[Guid]
			   ,[Type]
			   ,[ParentID]
			   ,[Value]
			   ,[AccountID]
			   ,[Notes]
			   ,[OrderType]
			   ,[SpecialOffer]
			   ,[OrderItemID])
			VALUES 
			((SELECT ISNULL(MAX(Number), 0) + 1 FROM POSOrderDiscount000)
			, NEWID()
			, @OrderItemType
			, @orderId
			, CASE @DiscountType WHEN 0 THEN (@Discount / 100) * 
					(SELECT SUM(oi.Price * 
					(CASE WHEN @ApplayOnce = 1 THEN @Qty / @UnitFact WHEN @CheckExactQty = 1 THEN 
								(
									(@OrderItemQty - (CAST(CAST(@OrderItemQty AS DECIMAL(38,19)) % CAST(@Qty AS DECIMAL(38,19)) AS FLOAT))) / @OrderUnitFact
								)
								ELSE @OrderItemQty / @OrderUnitFact END)
					) FROM vwPOSOrderItemsTempWithOutCanceled oi
					WHERE oi.Guid = @orderItemId ) 
				ELSE @Discount * 
				(SELECT SUM(
				(CASE WHEN @ApplayOnce = 1 THEN 1 WHEN @CheckExactQty = 1 THEN 
							(
								(@OrderItemQty - (CAST(CAST(@OrderItemQty AS DECIMAL(38,19)) % CAST(@Qty AS DECIMAL(38,19)) AS FLOAT))) / @Qty
							)
							ELSE @OrderItemQty / @OrderUnitFact END)
				) FROM vwPOSOrderItemsTempWithOutCanceled oi
				WHERE oi.Guid = @orderItemId )
				
				 END
			, @DiscountAccountID
			, ''
			, 0
			, 1
			, @orderItemId)
		END
	END
	ELSE
	BEGIN
		DELETE FROM POSOrderItemsTemp000
			OUTPUT deleted.Guid, 2 INTO #OfferedItems
			WHERE OfferedItem = 1 AND SpecialOfferID = @offerId

		UPDATE POSOrderItemstemp000
				SET SpecialOfferID = @offerId
			OUTPUT inserted.Guid, 1 INTO #OfferedItems
			WHERE Guid = @orderItemId

		INSERT INTO POSOrderItemsTemp000
			([Number]
           ,[Guid]
           ,[MatID]
           ,[Type]
           ,[Qty]
           ,[MatPrice]
           ,[VATValue]
           ,[Price]
           ,[PriceType]
           ,[Unity]
           ,[State]
           ,[Discount]
           ,[Added]
           ,[Tax]
           ,[ParentID]
           ,[ItemParentID]
           ,[SalesmanID]
           ,[PrinterID]
           ,[ExpirationDate]
           ,[ProductionDate]
           ,[AccountID]
           ,[BillType]
           ,[Note]
           ,[SpecialOfferID]
           ,[SpecialOfferIndex]
           ,[OfferedItem]
           ,[IsPrinted]
           ,[SerialNumber]
           ,[DiscountType]
           ,[ClassPtr]
           ,[RelatedBillID]
           ,[BillItemID])
		OUTPUT inserted.Guid, 0 INTO #OfferedItems
		SELECT
			   (SELECT ISNULL(MAX(Number), 0) + 1 FROM POSOrderItemsTemp000)
			   ,NEWID()
			   ,MatID
			   ,0
			   ,Qty *
			   (CASE WHEN @ApplayOnce = 1 THEN 1 WHEN @CheckExactQty = 1 
					THEN ((@OrderItemQty - (CAST(CAST(@OrderItemQty AS DECIMAL(38,19)) % CAST(@Qty AS DECIMAL(38,19)) AS FLOAT))) / @Qty)
						ELSE @OrderItemQty END)
			   ,Price
			   ,0
			   ,Price
			   ,PriceType
			   ,Unit
			   ,0
			   ,0
			   ,0
			   ,0
			   ,@orderId
			   ,0x0
			   ,0x0
			   ,0
			   ,'1980-01-01'
			   ,'1980-01-01'
			   ,0x0
			   ,@orderItemBillId
			   ,''
			   ,@offerId
			   ,2
			   ,1
			   ,0
			   ,''
			   ,1
			   ,''
			   ,0x0
			   ,0x0
			FROM OfferedItems000
				WHERE ParentID = @offerId
	END
#####################################################################
CREATE PROCEDURE prcCheckAndApplySpecialOffer
	@orderItemId UNIQUEIDENTIFIER,
	@isCanceled BIT
AS

SET NOCOUNT ON

DECLARE 
	@orderId UNIQUEIDENTIFIER,
	@orderItemBillId UNIQUEIDENTIFIER,
	@CurrOffer UNIQUEIDENTIFIER,
	@OrderItemMatId UNIQUEIDENTIFIER,
	@OrderItemGroupId UNIQUEIDENTIFIER,
	@OrderItemQty FLOAT,
	@OrderItemType INT,
	@OrderItemMatUnitFact2 FLOAT,
	@OrderItemMatUnitFact3 FLOAT,
	@OrderCustId UNIQUEIDENTIFIER,
	@OrderUserBillsID UNIQUEIDENTIFIER,
	@CanceledMatOfferId UNIQUEIDENTIFIER,
    @OrderUnit INT

CREATE TABLE #OfferedItems ([ItemId] UNIQUEIDENTIFIER, [OfferItemType] INT)

SELECT 
	@orderId = ParentID,
	@OrderItemMatId = MatID,
	@OrderItemQty = Qty,
	@OrderItemType = [Type],
	@orderItemBillId = BillType,
	@CanceledMatOfferId = ISNULL(SpecialOfferID, 0x0),
    @OrderUnit = Unity
FROM POSOrderItemstemp000 WHERE GUID = @orderItemId

SELECT
	@OrderCustId = CustomerID,
	@OrderUserBillsID = UserBillsID
FROM POSOrdertemp000 WHERE GUID = @orderId

SET @OrderItemGroupId = (SELECT GroupGUID FROM mt000 WHERE GUID = @OrderItemMatId)

SELECT 
	@OrderItemMatUnitFact2 = CASE WHEN ISNULL(Unit2Fact, 0) < 1 THEN 1 ELSE Unit2Fact END, 
	@OrderItemMatUnitFact3 = CASE WHEN ISNULL(Unit3Fact, 0) < 1 THEN 1 ELSE Unit3Fact END 
	FROM mt000 WHERE GUID = @OrderItemMatId
	
IF @isCanceled = 1 AND @CanceledMatOfferId <> 0x0
BEGIN
	DECLARE @CanceledOfferMode INT

	SELECT @CanceledOfferMode = OfferMode FROM SpecialOffer000 WHERE [GUID] = @CanceledMatOfferId

	DELETE FROM POSOrderDiscountTemp000 
		WHERE ParentID = @orderId AND SpecialOffer = 1 AND 
		(
			(@CanceledOfferMode <> 0 AND OrderItemID = @orderItemId)
				OR 
			(@CanceledOfferMode = 0 AND OrderItemID IN (SELECT oi.Guid FROM POSOrderItemsTemp000 oi WHERE oi.SpecialOfferID = @CanceledMatOfferId))
		)

	DELETE FROM POSOrderItemsTemp000
	OUTPUT deleted.Guid, 2 INTO #OfferedItems
		WHERE OfferedItem = 1 AND SpecialOfferID = @CanceledMatOfferId

	UPDATE oi
			SET oi.SpecialOfferID = 0x0,
				oi.Discount = 0
		OUTPUT inserted.Guid, 1 INTO #OfferedItems
		FROM POSOrderItemsTemp000 oi
			WHERE (@CanceledOfferMode = 0 AND oi.SpecialOfferID = @CanceledMatOfferId)
				OR (@CanceledOfferMode <> 0 AND oi.Guid = @orderItemId)
END

DECLARE @offerId UNIQUEIDENTIFIER,
		@custAcId UNIQUEIDENTIFIER,
		@CustCondId UNIQUEIDENTIFIER,
		@AccountID UNIQUEIDENTIFIER,
		@MatAccountID UNIQUEIDENTIFIER,
		@DiscountAccountID UNIQUEIDENTIFIER,
		@DivDiscount INT,
		@Type INT,
		@Condition INT,
		@Qty FLOAT,
		@Discount FLOAT,
		@DiscountType INT,
		@OfferMode	INT,
		@MatID UNIQUEIDENTIFIER,
		@GroupID UNIQUEIDENTIFIER,
		@Unit INT,
		@ApplayOnce BIT,
		@CheckExactQty BIT
DECLARE offerCursor CURSOR FOR
SELECT 
	Guid, CustomersAccountID, CustCondID, AccountID, MatAccountID, DiscountAccountID, DivDiscount, Type, Condition, Qty, Discount, DiscountType, OfferMode, MatID, GroupID, Unit, ApplayOnce, CheckExactQty
FROM SpecialOffer000
	WHERE Active = 1 AND CAST(GETDATE() AS DATE) >= StartDate AND  CAST(GETDATE() AS DATE) <= EndDate
		--AND (ApplayOnce = 0 OR GUID NOT IN (SELECT SpecialOfferID FROM POSOrderItemsTemp000 WHERE ParentID = @orderId))
			ORDER BY OfferIndex DESC
OPEN offerCursor  
	FETCH NEXT FROM offerCursor   
	INTO @offerId,
		@custAcId,
		@CustCondId,
		@AccountID,
		@MatAccountID,
		@DiscountAccountID,
		@DivDiscount,
		@Type,
		@Condition,
		@Qty,
		@Discount,
		@DiscountType,
		@OfferMode,
		@MatID,
		@GroupID,
		@Unit,
		@ApplayOnce,
		@CheckExactQty  
WHILE @@FETCH_STATUS = 0  
BEGIN 

	IF @custAcId <> 0x0 OR @CustCondId <> 0x0
	BEGIN
		DECLARE @CustsExists INT
		IF @OrderCustId <> 0x0
		BEGIN
			DECLARE @sSQL NVARCHAR(MAX)
			SELECT @sSQL = dbo.[fnGetSqlCheckCusts] (@OrderCustId, @custAcId, @CustCondId)
			EXEC SP_EXECUTESQL @sSQL, N'@Res INT OUTPUT', @Res = @CustsExists OUTPUT;
		END
		ELSE
		BEGIN
			SET @CustsExists = 0
		END

		IF @CustsExists = 0
		BEGIN
			FETCH NEXT FROM offerCursor   
				INTO @offerId,
					@custAcId,
					@CustCondId,
					@AccountID,
					@MatAccountID,
					@DiscountAccountID,
					@DivDiscount,
					@Type,
					@Condition,
					@Qty,
					@Discount,
					@DiscountType,
					@OfferMode,
					@MatID,
					@GroupID,
					@Unit,
					@ApplayOnce,
					@CheckExactQty
			CONTINUE;
		END
	END
	
	IF @DiscountAccountID = 0x0 OR @MatAccountID = 0x0 OR @AccountID = 0x0
		SELECT @DiscountAccountID = (CASE @DiscountAccountID WHEN 0x0 THEN DefDiscAccGUID ELSE @DiscountAccountID END),
			   @AccountID = (CASE @AccountID WHEN 0x0 THEN DefBillAccGUID ELSE @AccountID END),
			   @MatAccountID = (CASE @MatAccountID WHEN 0x0 THEN DefDiscAccGUID ELSE @MatAccountID END)
			FROM bt000 WHERE GUID = (SELECT TOP 1 SalesID FROM POSUserBills000 WHERE GUID = @OrderUserBillsID)

	-- Check If Mode Deffult Or Mixed
	IF @OfferMode <> 0 -- Deffult
	BEGIN
	DECLARE @OrderUnitFact FLOAT = ISNULL(CASE @OrderUnit WHEN 2 THEN @OrderItemMatUnitFact2 WHEN 3 THEN @OrderItemMatUnitFact3 ELSE 1 END, 1)
	DECLARE @OfferUnitFact FLOAT = ISNULL(CASE @Unit WHEN 1 THEN @OrderItemMatUnitFact2 WHEN 2 THEN @OrderItemMatUnitFact3 ELSE 1 END, 1)

	IF @OrderUnitFact < 1 
		SET @OrderUnitFact = 1
	IF @OfferUnitFact < 1 
		SET @OfferUnitFact = 1

	SET @OrderItemQty = @OrderItemQty * @OrderUnitFact
	DECLARE @Qty2 INT = @Qty * @OfferUnitFact
	--Check If Mat Offer
		IF @OrderItemMatId = @MatID AND @OrderItemQty >= @Qty2
		BEGIN
			--SET @Qty = CASE @Unit WHEN 1 THEN @Qty * @OrderItemMatUnitFact2 WHEN 2 THEN @Qty * @OrderItemMatUnitFact3 ELSE @Qty END
			EXEC prcApplySpecialOfferOnMat @orderId, @orderItemId, @orderItemBillId, @OrderItemQty, @OrderItemType, @offerId, @AccountID, @MatAccountID, @DiscountAccountID, @DivDiscount, @Type, @Condition, @Qty2, @Discount, @DiscountType, @OfferMode, @MatID, @GroupID, @Unit, @ApplayOnce, @CheckExactQty, @OrderUnitFact, @OfferUnitFact
			BREAK;																																																																								 
		END		
	--Check If Group Offer						
		IF @OrderItemGroupId = @GroupID AND @OrderItemQty >= @Qty
		BEGIN
			EXEC prcApplySpecialOfferOnMat @orderId, @orderItemId, @orderItemBillId, @OrderItemQty, @OrderItemType, @offerId, @AccountID, @MatAccountID, @DiscountAccountID, @DivDiscount, @Type, @Condition, @Qty, @Discount, @DiscountType, @OfferMode, @MatID, @GroupID, @Unit, @ApplayOnce, @CheckExactQty, @OrderUnitFact, 1
			BREAK;
		END
	END
	ELSE -- Mixed
	BEGIN
		IF EXISTS(SELECT * FROM vwSpecialOfferDetail WHERE Guid = @offerId AND ActualMatID = @OrderItemMatId)
		BEGIN
		IF @Condition <> 0
		BEGIN
			DECLARE @ApplayCount FLOAT
			SELECT @ApplayCount = (SUM(oit.Qty) - CAST(CAST(SUM(oit.Qty) AS DECIMAL(38,19)) % CAST(MAX(so.ActualQty) AS DECIMAL(38,19)) AS FLOAT)) / MAX(so.ActualQty)
				FROM vwPOSOrderItemsTempWithOutCanceled oit
					INNER JOIN vwSpecialOfferDetail so ON oit.MatID = so.ActualMatID
						WHERE so.Guid <> 0x0 AND oit.ParentID = @orderId AND so.Guid = @offerId
							HAVING SUM(oit.Qty) >= MAX(so.ActualQty)
			IF @ApplayCount > 0 
			BEGIN
				EXEC prcApplySpecialOfferQuntityOnMixedItem @orderId, @orderItemId, @orderItemBillId, @OrderItemQty, @OrderItemType, @offerId, @AccountID, @MatAccountID, @DiscountAccountID, @DivDiscount, @Type, @Condition, @Qty, @Discount, @DiscountType, @OfferMode, @MatID, @GroupID, @Unit, @ApplayOnce, @CheckExactQty, @ApplayCount
			END
		END
		ELSE
			BEGIN
				DECLARE @allOffer INT = (SELECT COUNT(*) FROM SpecialOfferDetails000 WHERE ParentID = @offerId)
				DECLARE @matOffer INT = (SELECT COUNT(*) FROM SpecialOfferDetails000 WHERE ParentID = @offerId AND [Group] <> 1)
				IF @allOffer <> @matOffer AND @allOffer <> 0 AND @matOffer <> 0
				BEGIN
					IF NOT EXISTS(SELECT oi.MatID, so.Guid FROM SpecialOffer000 so
						INNER JOIN vwSpecialOfferDetailUnits sod ON so.Guid = sod.ParentID
							LEFT JOIN vwPOSOrderItemsTempWithOutCanceled oi ON sod.MatID = oi.MatID AND CASE so.Condition WHEN 1 THEN so.Qty ELSE sod.Qty END <= oi.Qty
								WHERE oi.MatID IS NULL AND sod.[Group] = 0 AND so.Guid = @offerId AND (ISNULL(oi.ParentID, 0x0) = 0x0 OR oi.ParentID = @orderId)
									GROUP BY oi.MatID, so.Guid)
					AND NOT EXISTS(SELECT so.sodID FROM vwGroupOfferDetails so
						LEFT JOIN vwOrderItemGroup oi ON so.GroupID = oi.GroupGUID AND so.ActualQty <= oi.Qty
							WHERE oi.GroupGUID IS NULL AND so.soID = @offerId AND (ISNULL(oi.ParentID, 0x0) = 0x0 OR oi.ParentID = @orderId)
								GROUP BY so.sodID)
						BEGIN
							EXEC prcApplySpecialOfferOnMixedItem @orderId, @orderItemId, @orderItemBillId, @OrderItemQty, @OrderItemType, @offerId, @AccountID, @MatAccountID, @DiscountAccountID, @DivDiscount, @Type, @Condition, @Qty, @Discount, @DiscountType, @OfferMode, @MatID, @GroupID, @Unit, @ApplayOnce, @CheckExactQty
						END
				END
				ELSE
				BEGIN
					IF @matOffer = 0 AND NOT EXISTS(SELECT so.sodID FROM vwGroupOfferDetails so
						LEFT JOIN vwOrderItemGroup oi ON so.GroupID = oi.GroupGUID AND so.ActualQty <= oi.Qty
							WHERE oi.GroupGUID IS NULL AND so.soID = @offerId AND (ISNULL(oi.ParentID, 0x0) = 0x0 OR oi.ParentID = @orderId)
								GROUP BY so.sodID)
					BEGIN
						EXEC prcApplySpecialOfferOnGroupMixedItem @orderId, @orderItemId, @orderItemBillId, @OrderItemQty, @OrderItemType, @offerId, @AccountID, @MatAccountID, @DiscountAccountID, @DivDiscount, @Type, @Condition, @Qty, @Discount, @DiscountType, @OfferMode, @MatID, @GroupID, @Unit, @ApplayOnce, @CheckExactQty
						BREAK;
					END
					ELSE IF NOT EXISTS(SELECT so.Guid FROM vwSpecialOfferDetail so
					LEFT JOIN vwPOSOrderItemsTempWithOutCanceledGroupedOnQty oi ON so.ActualMatID = oi.MatID AND so.ActualQty <= oi.Qty
						WHERE oi.MatID IS NULL AND so.Guid = @offerId
							GROUP BY oi.MatID, so.Guid)
					BEGIN
						EXEC prcApplySpecialOfferOnMixedItem @orderId, @orderItemId, @orderItemBillId, @OrderItemQty, @OrderItemType, @offerId, @AccountID, @MatAccountID, @DiscountAccountID, @DivDiscount, @Type, @Condition, @Qty, @Discount, @DiscountType, @OfferMode, @MatID, @GroupID, @Unit, @ApplayOnce, @CheckExactQty
						BREAK;
					END
				END
			END
		END
	END
    FETCH NEXT FROM offerCursor   
    INTO @offerId, 
		@custAcId,
		@CustCondId,
		@AccountID,
		@MatAccountID,
		@DiscountAccountID,
		@DivDiscount,
		@Type,
		@Condition,
		@Qty,
		@Discount,
		@DiscountType,
		@OfferMode,
		@MatID,
		@GroupID,
		@Unit,
		@ApplayOnce,
		@CheckExactQty  
END
CLOSE offerCursor
DEALLOCATE offerCursor

SELECT * FROM #OfferedItems
################################################################################
#END
