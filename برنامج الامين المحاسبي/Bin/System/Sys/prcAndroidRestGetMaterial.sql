################################################################
CREATE PROC prcResGetMaterials
	@GroupGuid UNIQUEIDENTIFIER,
	@UserId UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	----------------------------------------------------
	DECLARE @IsGCCEnabled BIT = (SELECT [dbo].[fnOption_GetBit]('AmnCfg_EnableGCCTaxSystem', DEFAULT))
	DECLARE @IsAutoRefresh BIT = ISNULL((SELECT IsAutoRefresh FROM bg000 bg WHERE bg.Guid = @GroupGuid), 0)
	DECLARE @IsPriceIncludeTax BIT = ISNULL((select TOP 1 IsPriceIncludeTax from bt000 
	        where GUID = (select TOP 1 Value from UserOP000 op  
			Where op.UserID = @UserId AND op.Name='AmnRest_TableBillType')), 0)
   DECLARE @DefPrice INT = ISNULL((select TOP 1 DefPrice from bt000 
           where GUID = (select TOP 1 Value from UserOP000 op  
		   Where op.UserID = @UserId AND op.Name='AmnRest_TableBillType')), 0)
	-- DECLARE @Value int = (select cast(Value AS int) from op000 where Name ='AmnCfg_PricePrec')
	-- DECLARE @ConfigGUID UNIQUEIDENTIFIER = ISNULL((SELECT ConfigID From bg000 bg where bg.Guid = @GroupGuid ),0x0)
	----------------------------------------------------
	SELECT  
		bgi.ItemID AS ItemID,
		bgi.Caption AS Caption,
		ISNULL(bgi.FColor,0) AS FontColor,
		ISNULL(bgi.BColor,11194327) AS BackgroundColor,
		mt.LatinName AS LatinName,
		ISNULL(bm.Name, '') Picture,
		ISNULL(mt.Spec, '') Description,
		CASE (@DefPrice)
			WHEN 4   THEN mt.Whole
			WHEN 8   THEN mt.Half
			WHEN 16  THEN mt.Export
			WHEN 32  THEN mt.Vendor
			WHEN 64  THEN mt.Retail
			WHEN 128 THEN mt.EndUser
			ELSE mt.EndUser
		END AS Price,
		CAST(CASE (@DefPrice) 
		   WHEN 4   THEN mt.Whole 
		   WHEN 8   THEN mt.Half
		   WHEN 16  THEN mt.Export 
		   WHEN 32  THEN mt.Vendor 
		   WHEN 64  THEN mt.Retail 
		   WHEN 128 THEN mt.EndUser 
		   ELSE mt.EndUser 
		END AS NVARCHAR(100)) + ISNULL(' ' + (SELECT TOP 1 Code FROM my000 WHERE Guid = (Select TOP 1 value from op000 where name like 'AmnCfg_DefaultCurrency')), '') AS PriceWithCurrencyCode,
		CASE @IsGCCEnabled WHEN 0 THEN 0 ELSE ISNULL(GCC.Ratio, 0) END AS VatRatio
	INTO 
		#bgItems
	FROM
		bgi000 bgi
		INNER JOIN mt000 mt on mt.GUID = bgi.ItemID
		LEFT JOIN bm000 bm ON bm.GUID = mt.PictureGUID
		LEFT JOIN GCCMaterialTax000 GCC on mt.GUID = gcc.MatGUID AND GCC.TaxType = 1 
	WHERE
		bgi.ParentID = @GroupGuid
	IF @IsAutoRefresh = 1
	BEGIN 
		INSERT INTO #bgItems
		SELECT 
			mt.GUID AS ItemID,
			mt.Name AS Caption,
			0,
			11194327,
			mt.LatinName AS LatinName,
			ISNULL(bm.Name, '') Picture,
			ISNULL(mt.Spec, '') Description,
			CASE (@DefPrice)
				WHEN 4   THEN mt.Whole
				WHEN 8   THEN mt.Half
				WHEN 16  THEN mt.Export
				WHEN 32  THEN mt.Vendor
				WHEN 64  THEN mt.Retail
				WHEN 128 THEN mt.EndUser
				ELSE mt.EndUser
			END AS Price,
				CAST(CASE (@DefPrice) 
				    WHEN 4   THEN mt.Whole
				    WHEN 8   THEN mt.Half
				    WHEN 16  THEN mt.Export 
				    WHEN 32  THEN mt.Vendor 
				    WHEN 64  THEN mt.Retail 
				    WHEN 128 THEN mt.EndUser 
				    ELSE mt.EndUser 
				  END AS NVARCHAR(100)) + ISNULL(' ' + (SELECT TOP 1 Code FROM my000 WHERE Guid = (Select TOP 1 value from op000 where name like 'AmnCfg_DefaultCurrency')), '') AS PriceWithCurrencyCode,
			CASE @IsGCCEnabled WHEN 0 THEN 0 ELSE ISNULL(GCC.Ratio, 0) END AS VatRatio
		FROM
			mt000 mt 
			INNER JOIN gr000 gr ON mt.GroupGUID = gr.GUID 
			INNER JOIN bg000 bg ON bg.GroupGUID = gr.GUID 
			LEFT JOIN bm000 bm ON bm.GUID = mt.PictureGUID
			LEFT JOIN GCCMaterialTax000 GCC on mt.GUID = gcc.MatGUID AND GCC.TaxType = 1 
			LEFT JOIN #bgItems bgi ON bgi.ItemID = mt.GUID 
		WHERE
			bg.Guid = @GroupGuid
			AND 
			bgi.ItemID IS NULL 
	END 
	UPDATE #bgItems
	SET Price = CASE @IsPriceIncludeTax
	WHEN 1 THEN (Price * 100 / (VatRatio + 100))
	ELSE Price
	END 
	SELECT * FROM #bgItems 
	ORDER BY Caption
####################################################################
CREATE PROC	prcResGetItemMaterial
	@GroupGuid UNIQUEIDENTIFIER,
	@ItemGuid UNIQUEIDENTIFIER
AS

	SET NOCOUNT ON
	----------------------------------------------------
	DECLARE @IsGCCEnabled BIT = (SELECT [dbo].[fnOption_GetBit]('AmnCfg_EnableGCCTaxSystem', DEFAULT))
	----------------------------------------------------
	Select
	bgi.ItemID,
	bgi.Caption,
	mt.LatinName,
	ISNULL(bm.Name, '') Picture,
	ISNULL(mt.Spec, '') Description,
	mt.EndUser,
	CAST(mt.EndUser AS NVARCHAR(100)) + ISNULL(' ' + (SELECT Code FROM my000 WHERE Guid = (Select value from op000 where name like 'AmnCfg_DefaultCurrency')), '') AS PriceWithCurrencyCode,
	CASE @IsGCCEnabled WHEN 0 THEN 0 ELSE ISNULL(GCC.Ratio, 0) END VatRatio
	From
		bgi000 bgi
		INNER JOIN mt000 mt on mt.GUID = bgi.ItemID
		LEFT JOIN bm000 bm ON bm.GUID = mt.PictureGUID
		LEFT JOIN GCCMaterialTax000 GCC on mt.GUID = gcc.MatGUID AND GCC.TaxType = 1
	WHERE
		bgi.ParentID = @GroupGuid
		AND bgi.ItemID = @ItemGuid
	ORDER BY bgi.Caption
####################################################################
CREATE PROCEDURE prcRestGetOrderItemData
              @ParentID UNIQUEIDENTIFIER 
AS

 SELECT  items.Note, 
         items.Number,
         mt.Name AS Caption, 
         mt.LatinName AS LatinName,
         items.GUID ID, 
         mt.GUID MatID, 
		 items.ItemParentID,
         items.Qty, 
         items.Price, 
         items.Type, 
         ISNULL(bm.Name, '') Picture,  
         items.VatRatio ,
		 items.State,
		 items.KitchenID
 FROM RestOrderItemTemp000 items
		  INNER JOIN mt000 mt ON mt.GUID=items.MatID 
		  LEFT JOIN bm000 bm ON bm.GUID = mt.PictureGUID 
 WHERE items.ParentID=@ParentID 
 ORDER By mt.Name 
####################################################################
Create PROCEDURE prcRestUpdateStateOrder
	@Guid				[uniqueidentifier],
	@State				int,
	@Date               DateTime,
	@KitchenID          [uniqueidentifier]
AS
 BEGIN
	IF(@State=14)
	  BEGIN 
	   IF(@KitchenID = 0x0)
		 BEGIN
		   UPDATE RestOrderItemTemp000 set [State]=@State where [ParentID]=@Guid 
		 END
	   ELSE
		 BEGIN
		   UPDATE RestOrderItemTemp000 set [State] = @State where ParentID=@Guid and KitchenID=@KitchenID 
		   UPDATE RestOrderItemTemp000 set [State] = @State where ParentID=@Guid and [Type] IN(3,4)
		 END
	  END
	 ELSE
	  BEGIN
	    IF(@KitchenID = 0x0)
		  BEGIN
		   UPDATE RestOrderItemTemp000 set [State]=@State where [ParentID]=@Guid AND [State] NOT IN (5,14)
		  END
	    ELSE
		  BEGIN
		   UPDATE RestOrderItemTemp000 set [State] = @State where ParentID=@Guid AND KitchenID=@KitchenID AND [State] NOT IN (5,14) 
		   UPDATE RestOrderItemTemp000 set [State] = @State where ParentID=@Guid AND [Type] IN(3,4) AND [State] NOT IN (5,14)
		  END
	  END
DECLARE @OrderState INT = (SELECT ISNULL( MIN (rsi.State) ,0) FROM RestOrderItemTemp000 rsi  WHERE [ParentID]=@Guid)
  IF(@OrderState = 4)
    BEGIN
	   UPDATE RestOrderTemp000 SET [State]=@OrderState,Preparing = @Date where [Guid] = @Guid
    END
  ELSE IF(@OrderState = 5)
    BEGIN
	   UPDATE RestOrderTemp000 SET [State] = @OrderState,Closing = @Date WHERE [Guid] = @Guid
	END
	 ELSE IF(@OrderState = 14)
    BEGIN
	   UPDATE RestOrderTemp000 SET [State] = @OrderState,Receipting = @Date WHERE [Guid] = @Guid
	END
DECLARE @EnableAndroidNotification BIT
SELECT @EnableAndroidNotification = ISNULL(Value, 0) from FileOP000 where name = 'AmnRest_EnableAndroidNotifications' 
    IF @EnableAndroidNotification = 1 and @OrderState=5
		BEGIN
			INSERT INTO RestFinishedOrder000 
			SELECT NEWID(), vwto.TableID, vwto.Code, vwto.DepartmentID, ot.Closing
				FROM RestOrderTemp000 ot
				INNER JOIN vwRestTablesOrders vwto ON ot.Guid = vwto.ParentID
					WHERE ot.Guid=@Guid
						ORDER BY Code
		END 
END
###################################################################
CREATE PROCEDURE prcRestUpdateStateOrderItem
	@Guid			UNIQUEIDENTIFIER,
	@State			INT,
	@Date           DATETIME,
	@ParentID       UNIQUEIDENTIFIER
AS
BEGIN

	UPDATE RestOrderItemTemp000 SET [State]=@State WHERE [Guid] = @Guid

	DECLARE @OrderState int = (SELECT ISNULL(MIN(rsi.[State]), 0) FROM RestOrderItemTemp000 rsi  WHERE ParentID = @ParentID)
	
	IF(@OrderState=4)
	BEGIN
		UPDATE RestOrderTemp000 SET [State] = @OrderState,Preparing = @Date WHERE [Guid] = @ParentID
	END

	IF(@OrderState=5)
	BEGIN
		UPDATE RestOrderTemp000 SET [State] = @OrderState,Closing = @Date WHERE [Guid] = @ParentID
	END
	DECLARE @EnableAndroidNotification BIT
    SELECT @EnableAndroidNotification = ISNULL(Value, 0) from FileOP000 where name = 'AmnRest_EnableAndroidNotifications' 
    IF @EnableAndroidNotification = 1 and @OrderState=5
		BEGIN
			INSERT INTO RestFinishedOrder000 
			SELECT NEWID(), vwto.TableID, vwto.Code, vwto.DepartmentID, ot.Closing
				FROM RestOrderTemp000 ot
				INNER JOIN vwRestTablesOrders vwto ON ot.Guid = vwto.ParentID
					WHERE ot.Guid=@ParentID
						ORDER BY Code
		END 
END
###################################################################
CREATE PROCEDURE prcRestGetOrdersTempForKDS
	@KitchenID         [UNIQUEIDENTIFIER]
AS
BEGIN
  if (@KitchenID <> 0x0)
     BEGIN
                SELECT Distinct ro.Guid, ro.Opening, ro.Number, ro.Notes, ro.State,ro.Type, rst.Code 
                FROM RestOrderItemTemp000 roi 
                INNER JOIN RestOrderTemp000 ro on roi.ParentID = ro.Guid 
                LEFT JOIN RestOrderTableTemp000 rst on rst.ParentID = ro.Guid 
                WHERE ro.State IN (2, 4, 7) and roi.KitchenID = @KitchenID order by ro.Number  
				END
  ELSE
      BEGIN 
         SELECT Distinct ro.Guid, ro.Opening, ro.Number, ro.Notes, ro.State, ro.Type, rst.Code 
                FROM RestOrderItemTemp000 roi 
                INNER JOIN RestOrderTemp000 ro on roi.ParentID = ro.Guid 
                LEFT JOIN RestOrderTableTemp000 rst on rst.ParentID = ro.Guid 
                WHERE ro.State IN (2, 4, 7) order by ro.Number  
				
      END
END
####################################################################
CREATE PROCEDURE prcRestMergeTables
              @oldTableID UNIQUEIDENTIFIER ,
			  @newTableID UNIQUEIDENTIFIER
AS 
	DECLARE @oldParentID UNIQUEIDENTIFIER = 0x0
	DECLARE	@newParentID UNIQUEIDENTIFIER = 0x0
	DECLARE @OrderState  INT
     
	SET @oldParentID = (SELECT ParentID FROM RestOrderTableTemp000 WHERE TableID = @oldTableID )
	SET	@newParentID = (SELECT ParentID FROM RestOrderTableTemp000 WHERE TableID = @newTableID )

	IF(@oldParentID <> @newParentID)        
	BEGIN
		UPDATE RestOrderItemTemp000 SET ParentID = @newParentID WHERE ParentID = @oldParentID
		UPDATE RestOrderTableTemp000 SET ParentID = @newParentID WHERE ParentID = @oldParentID
		SET @OrderState = (SELECT ISNULL( MIN (rsi.[State]) ,2) FROM RestOrderItemTemp000 rsi  WHERE [ParentID]= @newParentID)
		UPDATE RestOrderTemp000 SET [State]=@OrderState where [Guid] = @newParentID
		DELETE FROM RestOrderTemp000 WHERE Guid = @oldParentID
	END
####################################################################
CREATE PROCEDURE prcRestChangeTables
              @oldTableID UNIQUEIDENTIFIER ,
			  @newTableID UNIQUEIDENTIFIER
AS 
DECLARE 
		@NewCode                  nvarchar(250), 
		@NewCover              INT
	SELECT 
		@NewCode      = rt.Code, 
		@NewCover    = rt.Cover
	FROM    RestTable000 rt    
	  INNER JOIN RestDepartment000 dp ON dp.GUID = rt.DepartmentID 
	     LEFT JOIN RestOrderTableTemp000 rot ON rot.TableID = rt.GUID WHERE rt.Guid=@newTableID
 UPDATE RestOrderTableTemp000 
                         SET TableID = @newTableID,
                         Code = @NewCode, 
                         Cover = @NewCover 
                        WHERE TableID =@oldTableID 

####################################################################
CREATE PROCEDURE prcRestGetTableColor
	@Name		[NVARCHAR](250)
AS
SET NOCOUNT ON	
SELECT [GUID],
 Name,
 Value
  FROM 
      PcOP000 
  WHERE 
	  Name IN ('AmnRest_tc_Empty','AmnRest_tc_Busy','AmnRest_tc_PayToCaptin',
	  'AmnRest_tc_StartPrepare','AmnRest_tc_FinishPrepare','AmnRest_tc_Deploy')
	   AND CompName =@Name
####################################################################
CREATE Procedure prcRestGetTableFinishedOrderData
	@DepartmentID			[nvarchar](250)
AS
SET NOCOUNT ON	
SELECT *
  FROM 
      RestFinishedOrder000 rfo 
	  where rfo.DepartmentGuid=@DepartmentID

	  Delete RestFinishedOrder000
####################################################################
CREATE PROCEDURE prcRestGetOrderItemsTempForKDS
    @ParentID          [UNIQUEIDENTIFIER],
	@KitchenID         [UNIQUEIDENTIFIER]
AS
BEGIN
CREATE TABLE #RestOrderItemsTemp(
    [Number] [float] NULL DEFAULT ((0)),
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL DEFAULT (newid()),
	[ParentID] [uniqueidentifier] NULL DEFAULT (0x00),
	[MatName] [nvarchar](250) NULL DEFAULT ((0)),
	[MatLatinName] [nvarchar](250) NULL DEFAULT ((0)),
	[Qty] [float] NULL DEFAULT ((0)),
	[State] [int] NULL DEFAULT ((0)),
	[MatID] [uniqueidentifier] NULL DEFAULT (0x00),
	[Note] [nvarchar](250) NULL DEFAULT (''),
	[Type] [int] NULL DEFAULT ((0)),
	[KitchenID] [uniqueidentifier] NULL DEFAULT (0x00),
	[ItemParentID] [uniqueidentifier] NULL DEFAULT (0x00))
  if (@KitchenID <> 0x0)
       BEGIN
	            INSERT INTO #RestOrderItemsTemp 
                SELECT Number, [Guid], ParentID, MatName, MatLatinName, ISNULL(QtyByDefUnit, Qty) Qty, [State], MatID,Note,[Type],KitchenID,ItemParentID 
				FROM vwRestOrderItemsTemp
				WHERE ParentID = @ParentID AND [Type] NOT IN (1,3,4) AND KitchenID = @KitchenID
				ORDER by [State]
	   END
  ELSE
      BEGIN 
	            INSERT INTO #RestOrderItemsTemp 
                SELECT Number, [Guid], ParentID, MatName, MatLatinName, ISNULL(QtyByDefUnit, Qty) Qty, [State], MatID,Note,[Type],KitchenID,ItemParentID 
				FROM vwRestOrderItemsTemp 
				WHERE ParentID = @ParentID and [Type] NOT IN (1,3,4) 
				ORDER by [State]	
      END

	  INSERT INTO #RestOrderItemsTemp 
         SELECT vm.Number, vm.[Guid], vm.ParentID, vm.MatName, vm.MatLatinName,  ISNULL(vm.QtyByDefUnit, vm.Qty) Qty, vm.[State], vm.MatID,vm.Note,vm.[Type],vm.KitchenID,vm.ItemParentID 
				FROM vwRestOrderItemsTemp vm INNER JOIN #RestOrderItemsTemp tbl ON vm.ItemParentID=tbl.Guid  WHERE vm.ParentID = @ParentID and vm.[Type] IN (3, 4)  ORDER by [State]	
   Select * from #RestOrderItemsTemp ORDER BY [State] 
END
#####################################################################
CREATE PROCEDURE prcResGetMaterialsSearch
    @pos nvarchar(250),
	@search nvarchar(250)
AS
	SET NOCOUNT ON
	----------------------------------------------------
	DECLARE @IsGCCEnabled BIT = (SELECT [dbo].[fnOption_GetBit]('AmnCfg_EnableGCCTaxSystem', DEFAULT))
	----------------------------------------------------
	Select  
	bgi.ItemID,
	bgi.Caption,
	mt.LatinName,
	mt.Code,
	mt.Number,
	ISNULL(bm.Name, '') Picture,
	ISNULL(mt.Spec, '') Description,
	CASE (Select DefPrice FROM bt000 Where Guid IN (SELECT TOP 1 Value FROM UserOP000 WHERE Name = 'AmnRest_TableBillType'))
		WHEN 4   THEN mt.Whole
		WHEN 8   THEN mt.Half
		WHEN 16  THEN mt.Export
		WHEN 32  THEN mt.Vendor
		WHEN 64  THEN mt.Retail
		WHEN 128 THEN mt.EndUser
	ELSE mt.EndUser
	END AS Price,
	CAST(CASE (Select DefPrice FROM bt000 Where Guid IN (SELECT TOP 1 Value FROM UserOP000 WHERE Name = 'AmnRest_TableBillType')) WHEN 4   THEN mt.Whole WHEN 8   THEN mt.Half WHEN 16  THEN mt.Export WHEN 32  THEN mt.Vendor WHEN 64  THEN mt.Retail WHEN 128 THEN mt.EndUser ELSE mt.EndUser END AS NVARCHAR(100)) + ISNULL(' ' + (SELECT TOP 1 Code FROM my000 WHERE Guid = (Select TOP 1 value from op000 where name like 'AmnCfg_DefaultCurrency')), '') AS PriceWithCurrencyCode,
	CASE @IsGCCEnabled WHEN 0 THEN 0 ELSE ISNULL(GCC.Ratio, 0) END VatRatio
	FROM
		bgi000 bgi
		INNER JOIN mt000 mt ON mt.GUID = bgi.ItemID
		INNER JOIN bg000 bg ON bgi.ParentID =bg.Guid
		INNER JOIN RestConfig000 cnfg ON bg.ConfigID =cnfg.Guid
		LEFT JOIN bm000 bm ON bm.GUID = mt.PictureGUID
		LEFT JOIN GCCMaterialTax000 GCC on mt.GUID = gcc.MatGUID AND GCC.TaxType = 1 
	WHERE
	cnfg.HostName=@pos 
	AND
	  (bgi.Caption like '%'+@search+'%' OR mt.LatinName like '%'+@search+'%'
		OR mt.Code like '%'+@search+'%')
####################################################################
#END