#########################################################################
CREATE PROCEDURE GetOrderStates
	@OrderType AS INT, 
	@AllStates AS INT = 0, 
	@OrderTypeGuid UNIQUEIDENTIFIER = 0x00,
	@CheckTimeScheduleEnabled AS BIT = 0,
	@OrderGuid UNIQUEIDENTIFIER = 0x00
AS 
	SET NOCOUNT ON 

	DECLARE @TimeScheduleEnabled AS BIT = 0
	IF @CheckTimeScheduleEnabled = 1
	BEGIN
		IF EXISTS (SELECT * FROM op000 WHERE Name = 'Orders_EnableTimeScheduleSystem' AND Value = '1')
		BEGIN
			IF EXISTS (SELECT 1 FROM bt000 WHERE GUID = @OrderTypeGuid AND IsTimeScheduleEnabled = 1)
				SET @TimeScheduleEnabled = 1
		END
	END	

	IF (@AllStates = 1 AND @OrderTypeGuid = 0X0) 
		BEGIN
			SELECT DISTINCT oit.Guid ,
							oit.Number ,
							oit.Name ,
							oit.LatinName ,
							oit.Type ,
							oit.PostQty ,
							oit.Operation ,
							oit.BillGuid ,
							oit.FixedDefaultBillType ,
							oit.QtyStageCompleted ,
							oit.BillType , 
						    oitvs.parentGuid ,
							CAST(0x00 AS UNIQUEIDENTIFIER) AS OTGuid,
							1 AS Selected , 
							oitvs.SubSNumber, 
							oitvs.Note, 
							0 AS StateOrder,
							oit.IsQtyReserved
			FROM 
				 oit000 oit LEFT OUTER JOIN oitvs000 oitvs ON oit.Guid = Oitvs.ParentGuid 
			WHERE 
				 Type = @OrderType 
		    ORDER BY 
					PostQty 
		END
	ELSE 
		BEGIN
			CREATE TABLE #OldType
			( [Guid] UNIQUEIDENTIFIER, 
			  Number INT,Name NVARCHAR(250), 
			  LatinName NVARCHAR(250),
			  [Type] INT,
			  PostQty INT,
			  Operation INT, 
			  BillGuid UNIQUEIDENTIFIER, 
			  FixedDefaultBillType BIT, 
			  QtyStageCompleted BIT, 
			  BillType INT,   
			  oitvsGuid UNIQUEIDENTIFIER, 
			  parentGuid UNIQUEIDENTIFIER, 
			  OTGuid UNIQUEIDENTIFIER, 
			  Selected BIT, 
			  SubSNumber INT, 
			  Note NVARCHAR(250), 
			  StateOrder INT, 
			  IsQtyReserved BIT
			)  
			
			CREATE TABLE #NewType 
			( [Guid] UNIQUEIDENTIFIER, 
			  Number INT, 
			  Name NVARCHAR(250), 
			  LatinName NVARCHAR(250),
			  [Type] INT, 
			  PostQty INT, 
			  Operation INT, 
			  BillGuid UNIQUEIDENTIFIER, 
			  FixedDefaultBillType BIT,
			  QtyStageCompleted BIT, 
			  BillType INT, 
			  oitvsGuid UNIQUEIDENTIFIER, 
			  parentGuid UNIQUEIDENTIFIER, 
			  OTGuid UNIQUEIDENTIFIER, 
			  Selected BIT, 
			  SubSNumber INT, 
			  Note NVARCHAR(250), 
			  StateOrder INT, 
			  IsQtyReserved BIT
			)  
			
			CREATE TABLE #Selected
			( [Guid] UNIQUEIDENTIFIER, 
			  Number INT,
			  Name NVARCHAR(250), 
			  LatinName NVARCHAR(250),
			  [Type] INT,
			  PostQty INT,
			  Operation INT, 
			  BillGuid UNIQUEIDENTIFIER, 
			  FixedDefaultBillType BIT, 
			  QtyStageCompleted BIT, 
			  BillType INT,   
			  oitvsGuid UNIQUEIDENTIFIER, 
			  parentGuid UNIQUEIDENTIFIER, 
			  OTGuid UNIQUEIDENTIFIER, 
			  Selected BIT, 
			  SubSNumber INT, 
			  Note NVARCHAR(250), 
			  StateOrder INT, 
			  IsQtyReserved BIT
			) 

			CREATE TABLE  #Unselected
			( [Guid] UNIQUEIDENTIFIER, 
			  Number INT,
			  Name NVARCHAR(250), 
			  LatinName NVARCHAR(250),
			  [Type] INT,
			  PostQty INT,
			  Operation INT, 
			  BillGuid UNIQUEIDENTIFIER,
			  FixedDefaultBillType BIT,
			  QtyStageCompleted BIT, 
			  BillType INT,   
			  oitvsGuid UNIQUEIDENTIFIER, 
			  parentGuid UNIQUEIDENTIFIER, 
			  OTGuid UNIQUEIDENTIFIER, 
			  Selected BIT,
			  SubSNumber INT,
			  Note NVARCHAR(250),
			  StateOrder INT, 
			  IsQtyReserved BIT
			) 
			
			INSERT INTO #OldType
		    SELECT 
				  oit.Guid,
				   oit.Number,
				   oit.Name,
				   oit.LatinName,
				   oit.Type,
				   oit.PostQty,
				   oit.Operation,
				   oit.BillGuid,
				   oit.FixedDefaultBillType,
				   oit.QtyStageCompleted,
				   oit.BillType,   
			       oitvs.Guid AS oitvsGuid,
				   oitvs.parentGuid,
				   oitvs.OTGuid,
				   oitvs.Selected,
				   oitvs.SubSNumber,
				   oitvs.Note,
				   oitvs.StateOrder,
				   oit.IsQtyReserved  
			FROM 
			     oit000 oit INNER JOIN oitvs000 oitvs on oit.Guid = Oitvs.ParentGuid   
			WHERE 
				 oitvs.OTGUID = @OrderTypeGuid 
				  AND 
				 Type = @OrderType 
				  AND 
				 oitvs.Selected = 1
			 
			INSERT INTO #NewType 
			SELECT 
				   oit.Guid,
				   oit.Number,
				   oit.Name,
				   oit.LatinName,
				   oit.Type,
				   oit.PostQty,
				   oit.Operation,
				   oit.BillGuid,
				   oit.FixedDefaultBillType,
				   oit.QtyStageCompleted,
				   oit.BillType,     
				   CAST(0x00 AS UNIQUEIDENTIFIER) AS oitvsGuid,
				   CAST(0x00 AS UNIQUEIDENTIFIER) AS parentGuid,
				   CAST(0x00 AS UNIQUEIDENTIFIER) AS OTGuid,
				   0 AS Selected, 
				   0 AS SubSNumber, 
				   SPACE(1) AS Note,
				   (1000) AS StateOrder,
				   oit.IsQtyReserved   
			FROM 
				 oit000 oit  
			WHERE 
				 Type = @OrderType 
				  AND 
				 oit.Guid NOT IN(SELECT OldType.Guid FROM #OldType OldType ) 
			
			IF (@TimeScheduleEnabled = 1) AND (@OrderGUID <> 0x00)
			BEGIN
				INSERT INTO #Selected
				SELECT DISTINCT old.*
				FROM
					OrderTimeSchedule000 OTS
					INNER JOIN OrderTimeScheduleItems000 OTSI ON OTS.GUID = OTSI.OTSParent
					INNER JOIN #OldType	old ON old.[Guid] = OTSI.StateGUID
				WHERE
					OTS.OrderTypeGUID = @OrderTypeGUID 
					 AND 
					OTS.OrderGUID = @OrderGUID
				
				INSERT INTO #Unselected 
				SELECT 
					  o.Guid,
					  o.Number,
					  o.Name,
					  o.LatinName,
					  o.Type,
					  o.PostQty,
					  o.Operation,
					  o.BillGuid,
					  o.FixedDefaultBillType,
					  o.QtyStageCompleted,
					  o.BillType,  
					  CAST(0x00 AS UNIQUEIDENTIFIER) AS oitvsGuid,
					  CAST(0x00 AS UNIQUEIDENTIFIER) AS parentGuid ,
					  CAST(0x00 AS UNIQUEIDENTIFIER) AS OTGuid,
					  0 AS Selected ,
					  0 AS SubSNumber, 
					  SPACE(1) AS Note,
					  (1000) AS StateOrder,
					  o.IsQtyReserved
				FROM
					 oit000 o 
				WHERE 
				     Type = @OrderType
					  AND 
					 o.[guid] NOT IN (SELECT parentGuid FROM #selected)
				
				DECLARE @SelectedCount AS INT = 0
				SELECT @SelectedCount = COUNT(*) FROM #Selected
				IF @SelectedCount = 0
				BEGIN
					SELECT * FROM #OldType 
					UNION 
					SELECT * FROM #NewType 
					ORDER BY PostQty
				END
				ELSE
					BEGIN
						SELECT * FROM #Selected
						UNION ALL
						SELECT * FROM #Unselected
						ORDER BY PostQty
					END
			END
			ELSE
				BEGIN
					IF (@OrderTypeGuid = 0x0 OR (@OrderTypeGuid <> 0X0 AND @AllStates = 1))
						BEGIN
							SELECT * FROM #OldType 
							UNION 
							SELECT * FROM #NewType 
							ORDER BY PostQty
						END
					ELSE 
						BEGIN
							 SELECT * FROM #OldType 
							 ORDER BY PostQty
						END
				END  
		END
#########################################################################
#END