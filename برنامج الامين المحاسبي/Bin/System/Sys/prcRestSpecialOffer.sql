###########################
CREATE Proc prcRestSpecialOffer
	@OrderID	Uniqueidentifier,
	@ItemType	INT = 0
AS
SET NOCOUNT ON
DECLARE @ItemsCount int,
	@OfferCount int,
	@Type			INT,
	@Condition		INT,
	@OfferID		Uniqueidentifier,
	@OfferQty		FLOAT,
	@OfferItemsCount	FLOAT,
	@OrderDate		DATETIME,
	@OrderAccount		UNIQUEIDENTIFIER,
	@CustomersAccoutID	UNIQUEIDENTIFIER,
	@OrderItemsCount 	FLOAT,
	@OffersCursor		CURSOR,
	@IsGroup		INT,
	@TotalQty		FLOAT,
	@OfferCounts	INT,
	@CustGuid  UNIQUEIDENTIFIER , 
	@CustConditionID        UNIQUEIDENTIFIER     
DECLARE @OrderItemsTemp TABLE 
(
	MatID 	UNIQUEIDENTIFIER,
	Qty		FLOAT,
	Guid	UNIQUEIDENTIFIER
) 
DECLARE @OrderItems TABLE 
(
	MatID 	UNIQUEIDENTIFIER,
	Qty		FLOAT,
	Guid	UNIQUEIDENTIFIER
)
DECLARE @AccountList TABLE 
(
	AccountID 	UNIQUEIDENTIFIER
)
DECLARE @CondAccountList TABLE
( Number UNIQUEIDENTIFIER,     Sec INT ) 

declare @fillAccount bit
set @fillAccount = 0
SELECT	@OrderAccount = [DeferredAccountID] ,
		@OrderDate = [Opening],
		@CustGuid = CustomerID
FROM RestOrderTemp000 WHERE [Guid] = @OrderID
SET @OffersCursor = CURSOR FAST_FORWARD READ_ONLY FOR
SELECT 	
	SpecialOffer.Type,
	SpecialOffer.Condition,
	SpecialOffer.Guid,
	SpecialOffer.Qty, 
	SpecialOffer.CustomersAccountID,
	SpecialOffer.CustCondID
FROM SpecialOffer000  SpecialOffer   
WHERE 	dbo.fnIsBetween(@OrderDate, StartDate, EndDate) = 1
AND 	(SpecialOffer.Active = 1)
ORDER BY SpecialOffer.Number desc
INSERT @OrderItemsTemp 
 SELECT	OrderItems.MatID AS MatID, 
	OrderItems.QtyByDefUnit As Qty,
	OrderItems.GUID
 FROM vwRestOrderItemsTemp OrderItems   
 WHERE (OrderItems.ParentID = @OrderID)
	AND	  (OrderItems.Type = @ItemType)	-- sales item 
	AND	  (IsNull(OrderItems.SpecialOfferID, 0x0) = 0x0)-- not a specialoffer item 	
 GROUP BY OrderItems.MatID, OrderItems.QtyByDefUnit, OrderItems.GUID
OPEN @OffersCursor														
FETCH FROM @OffersCursor INTO 	@Type, @Condition, @OfferID, @OfferQty, @CustomersAccoutID, @CustConditionID
WHILE @@FETCH_STATUS = 0
BEGIN
    if (IsNull(@OrderAccount, 0x0) != 0x0) AND @fillAccount=0
	begin
		set @fillAccount = 1
		insert @AccountList SELECT Guid FROM dbo.fnGetAccountsList(@CustomersAccoutID, Default)
	end
	
    IF ((IsNull(@OrderAccount, 0x0) != 0x0) AND (@OrderAccount NOT IN (select AccountID from @AccountList )))
    BEGIN		
		FETCH FROM @OffersCursor INTO 	@Type, @Condition, @OfferID, @OfferQty, @CustomersAccoutID, @CustConditionID
		CONTINUE
    END

	        
     -- if there is not CustomersAccoutID then check if this customer validates the condition             
    IF ISNULL(@CustConditionID , 0x0) <> 0x0  
    BEGIN  
          IF ISNULL(@CustGuid , 0x0) = 0x0  
          BEGIN         
                FETCH FROM @OffersCursor INTO @Type, @Condition, @OfferID, @OfferQty, @CustomersAccoutID, @CustConditionID
                CONTINUE  
          END  
            
          DELETE @CondAccountList  
          INSERT @CondAccountList  EXEC [prcGetCustsList]  @CustGuid, Null, @CustConditionID                                                                            
          IF @CustGuid NOT IN (SELECT Number FROM @CondAccountList)  
          BEGIN         
                FETCH FROM @OffersCursor INTO @Type, @Condition, @OfferID, @OfferQty, @CustomersAccoutID, @CustConditionID
                CONTINUE  
          END  
    END           
                    
    
    IF (@Condition = 0) -- DEFINED
    BEGIN
		SELECT @ItemsCount =  COUNT(*), @OfferCounts = ISNULL(Min(OffersCount), 1) FROM
		(
			 (
				SELECT SOD.matid, (SUM(item.qty)/CASE WHEN SOD.QtyByDefUnit=0 THEN 1 ELSE SOD.QtyByDefUnit END) OffersCount FROM @OrderItemsTemp item 
					INNER JOIN vwSpecialOfferDetails SOD ON item.MatID = SOD.MatID 
				 WHERE SOD.ParentID=@OfferID
				 GROUP BY SOD.matid, SOD.QtyByDefUnit
				 HAVING SUM(item.qty)>=SOD.QtyByDefUnit
			 ) 
			  UNION 
			 (
				SELECT SOD.matid, (SUM(item.qty)/CASE WHEN SOD.QtyByDefUnit=0 THEN 1 ELSE SOD.QtyByDefUnit END) OffersCount FROM @OrderItemsTemp item 
					INNER JOIN mt000 mt ON item.matid=mt.guid 
					INNER JOIN vwSpecialOfferDetails SOD ON mt.groupguid = SOD.MatID 
				WHERE SOD.ParentID=@OfferID
				GROUP BY SOD.matid, SOD.QtyByDefUnit
				HAVING SUM(item.qty)>=SOD.QtyByDefUnit
			)
		) y
		SELECT @OfferCount = COUNT(*), @OfferQty=SUM(QtyByDefUnit) FROM vwSpecialOfferDetails 
		  WHERE ParentID=@OfferID
		  
		IF @OfferCount = @ItemsCount
		BEGIN
			INSERT @OrderItems SELECT MatID, Qty, Guid FROM @OrderItemsTemp WHERE MatID IN 
			(
				SELECT matid FROM ((
					SELECT SOD.matid FROM @OrderItemsTemp item 
						INNER JOIN vwSpecialOfferDetails SOD ON item.MatID = SOD.MatID 
					 WHERE SOD.ParentID=@OfferID
					 GROUP BY SOD.matid, SOD.QtyByDefUnit
					 HAVING SUM(item.qty)>=SOD.QtyByDefUnit
				 ) 
				  UNION 
				 (
					SELECT item.matid FROM @OrderItemsTemp item 
						INNER JOIN mt000 mt ON item.matid=mt.guid WHERE mt.GroupGUID IN (SELECT SOD.matid FROM @OrderItemsTemp item 
						INNER JOIN mt000 mt ON item.matid=mt.guid 
						INNER JOIN vwSpecialOfferDetails SOD ON mt.groupguid = SOD.MatID 
					WHERE SOD.ParentID=@OfferID
					GROUP BY SOD.matid, SOD.QtyByDefUnit
					HAVING SUM(item.qty)>=SOD.QtyByDefUnit)
				)) Y
			)
			BREAK;
		END
    END
    ELSE IF (@Condition = 1)
    BEGIN	
		SELECT @ItemsCount =  ISNULL(SUM(item.Qty), 0) FROM @OrderItemsTemp item 
			INNER JOIN vwSpecialOfferDetails SOD ON item.MatID = SOD.MatID 
		WHERE SOD.ParentID=@OfferID
		
		SELECT @ItemsCount = ISNULL(@ItemsCount, 0) + ISNULL(SUM(item.Qty), 0) FROM @OrderItemsTemp item 
			INNER JOIN mt000 mt ON item.matid=mt.guid 
			INNER JOIN vwSpecialOfferDetails SOD ON mt.groupguid = SOD.MatID
		WHERE SOD.ParentID=@OfferID
		IF (@ItemsCount >= @OfferQty AND @OfferQty != 0)
		BEGIN	
			SET @OfferCounts = @ItemsCount / @OfferQty
			
			INSERT @OrderItems SELECT 
				MatID,
				Qty,
				Guid
			FROM @OrderItemsTemp
			WHERE (MatID IN (SELECT MatID FROM SpecialOfferDetails000
				WHERE ParentID = @OfferID ) ) OR (MatID IN (SELECT mt.GUID FROM SpecialOfferDetails000 sod
				INNER JOIN mt000 mt on mt.GroupGUID=sod.matid WHERE sod.ParentID = @OfferID ) )
					
			BREAK
		END
	END
	FETCH FROM @OffersCursor INTO @Type, @Condition, @OfferID, @OfferQty, @CustomersAccoutID, @CustConditionID
END
CLOSE @OffersCursor
DEALLOCATE @OffersCursor
	--------------------------------------------------------------------------
	-- RESULTS 
  	--1- Order Items
	SELECT 
		Guid As OrderItemID 
	FROM @OrderItems
	--2- Offer
	SELECT   
		Type,
		Discount AS DiscountPercent,  
		Guid AS OfferID,
		AccountID,
		MatAccountID,
		DiscountAccountID,
		DivDiscount,
		DiscountType,
		@OfferCounts OfferCounts
	FROM SpecialOffer000
	WHERE Guid = @OfferID
  	--3- Offered Items
	if (@Type = 1)
	SELECT 
		CASE ISNULL(OfferedItems.MatID, 0x0) WHEN 0x0 THEN mt.GUID ELSE OfferedItems.MatID END MatID,
		ISNULL(OfferedItems.MatCode, mt.Code) MatCode,
		ISNULL(OfferedItems.MatName, mt.Name) MatName,
		OfferedItems.Qty,
		OfferedItems.Unit,
		CASE ISNULL(OfferedItems.UnitName, '') 
			WHEN '' THEN 
				CASE OfferedItems.[Unit] WHEN 1 THEN [Mt].[Unity] 
					WHEN 2 THEN [Mt].[Unit2] 
					WHEN 3 THEN [Mt].[Unit3] 
				END 
			ELSE 
				OfferedItems.UnitName 
			END  UnitName,
		OfferedItems.Price,
		OfferedItems.PriceType,
		OfferedItems.PriceTypeName,
		OfferedItems.Discount AS DiscountPercent
	FROM vwOfferedItems OfferedItems
		LEFT JOIN mt000 mt ON 
			(OfferedItems.MatID=0x0 AND mt.GUID IN (SELECT TOP 1 MatID FROM @OrderItems))
	WHERE ParentID = @OfferID
	ORDER BY OfferedItems.Number

###########################
#END