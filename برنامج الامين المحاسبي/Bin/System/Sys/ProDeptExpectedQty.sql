#########################################################
CREATE PROC prcExpectedQtyDelete 	@Guid	[UNIQUEIDENTIFIER]								
AS 
DELETE FROM expQtyRepHdr000 WHERE Guid  = @Guid 
DELETE FROM expQtyRepDetails000  WHERE ParentGuid = @Guid 
EXEC prcExpQty_DeleteBills @Guid
###########################################################
CREATE PROCEDURE prcExpQty_DeleteBills  @ExpQtyGuid [UNIQUEIDENTIFIER] 											   
AS
DECLARE @InBillGuid  [UNIQUEIDENTIFIER] ,
		@OutBillGuid [UNIQUEIDENTIFIER] 

SELECT @InBillGuid = [InBillGuid] FROM expQtyRepHdr000 
								  WHERE Guid = @ExpQtyGuid 
SELECT @OutBillGuid = [OutBillGuid] FROM expQtyRepHdr000 
								    WHERE Guid = @ExpQtyGuid

UPDATE bu000 SET isPosted = 0 WHERE Guid = @InBillGuid OR Guid = @OutBillGuid
DELETE FROM bu000 WHERE Guid = @InBillGuid OR Guid = @OutBillGuid 
DELETE FROM bi000 WHERE parentGuid = @InBillGuid OR parentGuid = @OutBillGuid
UPDATE expQtyRepHdr000 SET @InBillGuid = 0x0 WHERE Guid = @ExpQtyGuid OR Guid = @ExpQtyGuid
###########################################################
CREATE PROCEDURE prcExpQty_BillGen     @repGUID [UNIQUEIDENTIFIER]    
AS    
	DECLARE          
		@InBillGUID [UNIQUEIDENTIFIER],        
		@InBillTypeGUID [UNIQUEIDENTIFIER],        
		@OutBillGUID [UNIQUEIDENTIFIER],        
		@OutBillTypeGUID [UNIQUEIDENTIFIER],      
		@InBillGenFlag [INT],   
		@OutBillGenFlag [INT],     
		@RawMatCount  [INT],    
		@TotalSum	  [FLOAT],   
		@InBuNumber [FLOAT],    
		@OutBuNumber [FLOAT], 
		@InAgentGuid [UNIQUEIDENTIFIER], 
		@OutAgentGuid [UNIQUEIDENTIFIER], 
		@bPostOut [bit],      
		@bPostIn [bit],    
		@bEntryOut [bit],    
		@bEntryIn [bit] 
---------------------------------- Checking Materials existence ----------------------------------------------- 
SELECT @RawMatCount = ( 
						SELECT COUNT(*) AS COUNT FROM expQtyRepDetails000    
						WHERE inventoryQty > 0 and parentGuid =  @repGUID 
					  )   									 
IF(@RawMatCount = 0) 
			RETURN -100 
-----------------------------------Prepare The Values For Bills------------------------------------------------   
SELECT        
		@InBillGenFlag   =	InGenBill  ,   
		@OutBillGenFlag  =	OutGenBill ,   
		@InBillGUID      =	InBillGuid ,    
		@InBillTypeGuid  =	InBillTypeGuid ,    
		@OutBillGuid     =	OutBillGuid ,   
		@OutBillTypeGUID = 	OutBillTypeGuid  
FROM expQtyRepHdr000 WHERE Guid = @repGUID    
SET @TotalSum = 0 
SELECT @InBuNumber       =  (SELECT Number FROM bu000 WHERE Guid = @InBillGUID),   
	   @OutBuNumber      =  (SELECT Number FROM bu000 WHERE Guid = @OutBillGUID)		    
    
SELECT @InBuNumber       =   ISNULL(@InBuNumber,  ( SELECT Number = ISNULL(MAX(Number), 0 ) +1 FROM bu000 )),        
	   @OutBuNumber      =   ISNULL(@OutBuNumber, ( SELECT Number = ISNULL(MAX(Number), 0 ) +1 FROM bu000 ))        
IF(@InBillGUID = 0x0)   
	SELECT @InBillGUID   =   NEWID()	   
IF(@OutBillGUID = 0x0)   
	SELECT @OutBillGUID  =   NEWID()   
  
SELECT @OutAgentGuid	 =   Guid FROM cu000 WHERE AccountGuid  = ( SELECT OutAgentAcc FROM expQtyRepHdr000 WHERE Guid = @repGUID ) 
SELECT @InAgentGuid		 =   Guid FROM cu000 WHERE AccountGuid  = ( SELECT InAgentAcc FROM expQtyRepHdr000 WHERE Guid = @repGUID ) 
SET @InAgentGuid		 =   ISNULL(@InAgentGuid, 0x0) 
SET @OutAgentGuid		 =   ISNULL(@OutAgentGuid, 0x0) 
SELECT @bPostOut		 =	 [bAutoPost], @bEntryOut = [bAutoEntry] FROM [Bt000] WHERE [GUID] =  @OutBillTypeGUID      
SELECT @bPostIn			 =   [bAutoPost], @bEntryIn = [bAutoEntry] FROM [Bt000] WHERE [GUID] = @InBillTypeGUID 
-------------------------------------------Delete Old Bills If Found----------------------------------------------------------   
EXEC [prcExpQty_DeleteBills] @repGUID   
-------------------------------------------Generate Bills If Match Condition--------------------------------------------------      
INSERT INTO [bu000](        
					[Number], [Cust_Name], [Date], [CurrencyVal], [Notes], [Total], [PayType], [TotalDisc], [TotalExtra], [ItemsDisc], [BonusDisc], [FirstPay], [Profits],         
					[IsPosted], [Security], [Vendor], [SalesManPtr], [Branch], [VAT], [GUID], [TypeGUID], [CustGUID], [CurrencyGUID], [StoreGUID], [CustAccGUID],         
					[MatAccGUID], [ItemsDiscAccGUID], [BonusDiscAccGUID], [FPayAccGUID], [CostGUID], [UserGUID], [CheckTypeGUID])        
				SELECT        
					@InBuNumber,      
					'',        
					[InRepDate] ,							 
					1,								 
					'',								 
					@TotalSum,  
					0,  
					0,  
					0,  
					0,  
					0,  
					0,  
					0,  
					0,  
					[SecLevel],        
					0,  
					0,  
					NULL,          
					0,  
					@InBillGUID,        
					@InBillTypeGUID,        
					ISNULL(@InAgentGuid, 0x0),							 
					0x0,									    
					[InStoreGuid],						 
					[InAgentAcc],						 
					0x0,							 
					0x0,  
					0x0,  
					0x0,  
					[CostCenter],							        
					0x0,      
					0x0  
				FROM [expQtyRepHdr000]        
				WHERE [GUID] = @repGUID AND @InBillGenFlag = 1    
				UNION ALL   
				SELECT        
					@OutBuNumber,      
					'',        
					[OutRepDate] ,							   
					1,								 
					'',								 
					@TotalSum,  
					0,  
					0,  
					0,  
					0,  
					0,  
					0,  
					0,  
					0,       
					[SecLevel],        
					0,         
					0,        
					NULL,          
					0,         
					@OutBillGUID,        
					@OutBillTypeGUID,        
					ISNULL(@OutAgentGuid, 0x0),							 
					0x0,							 
					[OutStoreGuid],							 
					[OutAgentAcc],							 
					0x0,							    
					0x0,  
					0x0,  
					0x0,  
					[CostCenter],							  
					0x0,  
					0x0         
				FROM [expQtyRepHdr000]        
				WHERE [GUID] = @repGUID AND @OutBillGenFlag = 1    
-------------------------- insert bi        
INSERT INTO [bi000](        
					[Number], [Qty], [Order], [OrderQnt], [Unity], [Price], [BonusQnt], [Discount], [BonusDisc], [Extra], [CurrencyVal], [Notes], [Profits],         
					[Num1], [Num2], [Qty2], [Qty3], [ExpireDate], [ProductionDate], [Length], [Width], [Height], [VAT], [VATRatio],         
					[ParentGUID], [MatGUID], [CurrencyGUID], [StoreGUID], [CostGUID], ClassPtr)        
				SELECT        
					@InBuNumber,        
					[eqrd].[inventoryQty],        
					0,        
					0,  
					1,									  
					[mt].[AvgPrice],  
					0,      
					0,  
					0,  
					0,  
					1, 
					'',  
					0,  
					0,  
					0,         
					0, 
					0, 
					NULL,								 
					NULL ,								 
					0,									 
					0,									 
					0,									 
					0,        
					0,        
					@InBillGUID,        
					[eqrd].[RawMatGuid],        
					0x0,								 
					[eqrh].[InstoreGuid],								 
					'00000000-0000-0000-0000-000000000000',								 
					NULL								 
				FROM         
					[expQtyRepDetails000] [eqrd]        
					INNER JOIN [expQtyRepHdr000] [eqrh] ON [eqrd].[ParentGUID] = [eqrh].[GUID]        
					INNER JOIN [mt000] [mt] ON [mt].[GUID] =  [eqrd].[RawMatGuid]    
				WHERE   [eqrd].[ParentGUID] = @repGUID AND [eqrd].[inventoryQty] > 0 AND @InBillGenFlag = 1   
				   
				UNION ALL   
				SELECT        
					@OutBuNumber,        
					[eqrd].[inventoryQty],        
					0,  
					0,  
					1,									 
					[mt].[AvgPrice],  
					0,  
					0,  
					0,  
					0,  
					1,									 
					'',  
					0,  
					0, 
					0,  
					0, 
					0, 
					NULL,								   
					NULL ,								 
					0,									 
					0,								 
					0,								 
					0,        
					0,        
					@OutBillGUID,        
					[eqrd].[RawMatGuid],        
					0x0,								  
					[eqrh].[OutstoreGuid],				 
					NULL,								 
					NULL								 
				FROM         
					[expQtyRepDetails000] [eqrd]        
					INNER JOIN [expQtyRepHdr000] [eqrh] ON [eqrd].[ParentGUID] = [eqrh].[GUID]        
					INNER JOIN [mt000] [mt] ON [mt].[GUID] =  [eqrd].[RawMatGuid]    
				WHERE   [eqrd].[ParentGUID] = @repGUID AND [eqrd].[inventoryQty] > 0 AND @OutBillGenFlag = 1   
---------------------------------------- Update The Bills With New Total ----------------------------------------- 
SELECT @totalSum = ISNULL((SELECT SUM([biPrice] * [biBillQty]) FROM [vwBiMt] WHERE [vwBiMt].[biParent] = @OutBillGUID),0)          
UPDATE [bu000] SET       
			[TotalExtra] = 0,       
			[Total] = @TotalSum  
		WHERE   [GUID] = @InBillGUID  AND @InBillGenFlag  = 1        
UPDATE [bu000] SET       
			[TotalExtra] = 0,       
			[Total] = @TotalSum 
		WHERE   [GUID] = @OutBillGUID AND @OutBillGenFlag = 1     
----------------------------------------- Update EXPQTYREPHDR000 With The New Bill GUID---------------------------- 
UPDATE EXPQTYREPHDR000 SET InBillGUID  = @InBillGUID  WHERE Guid  = @repGUID AND @InBillGenFlag  = 1   
UPDATE EXPQTYREPHDR000 SET OutBillGUID = @OutBillGUID WHERE Guid  = @repGUID AND @OutBillGenFlag = 1   
----------------------------------------- Posting the Bills ------------------------------------------------------- 
IF ( @bPostOut = 1 )        
	BEGIN        
		UPDATE [BU000] SET [IsPosted] = 1 WHERE [GUID] = @OutBillGUID  AND @OutBillGenFlag  = 1         
	END        
IF ( @bPostIn = 1)        
	BEGIN        
		UPDATE [BU000] SET [IsPosted] = 1 WHERE [GUID] = @InBillGUID   AND @InBillGenFlag = 1   
	END   
----------------------------------------- Generating Entries For the Generated Bills ------------------------------		  
IF ( @bEntryOut = 1 AND @OutBillGenFlag  = 1 )      
	BEGIN        
		EXEC [prcBill_GenEntry] @OutBillGUID 	  	    
	END        
IF ( @bEntryIn = 1 AND @InBillGenFlag  = 1)      
	BEGIN        
		EXEC [prcBill_GenEntry] @InBillGUID   
	END		 	 
###########################################################
CREATE PROCEDURE prcExpQtyGetRMatCount	@repGuid [UNIQUEIDENTIFIER]
AS
DECLARE	@RawMatCount [INT]
SELECT @RawMatCount = (SELECT COUNT(*) AS count FROM 
								(
								SELECT * FROM expQtyRepDetails000
								WHERE inventoryQty > 0 and parentGuid =  @repGUID
								)RCount
					   )
Select @RawMatCount AS RawMatCount 
###########################################################	
CREATE VIEW vwGetFormAltMats
AS
SELECT   mi1.MatGUID AS baseRawMatGuid, mi2.Type, mi2.Number, mi2.Unity, mi2.Qty, mi2.Notes, mi2.CurrencyVal, mi2.Price, mi2.Class, mi2.GUID, mi2.Qty2, 
                    mi2.Qty3, mi2.ParentGUID, mi2.MatGUID, mi2.StoreGUID, mi2.CurrencyGUID, mi2.ExpireDate, mi2.ProductionDate, mi2.Length, mi2.Width, mi2.Height, 
                    mi2.CostGUID, mi2.Percentage
FROM   dbo.MI000 AS mi1 INNER JOIN
       dbo.MI000 AS mi2 ON mi2.ParentGUID = mi1.MatGUID
WHERE mi1.type <> 2
#########################################################
CREATE VIEW vwRelated_Operation_Form
AS
SELECT  mn.Guid As Guid , CAST(mn.Number AS NVARCHAR(100)) AS OpNumber, 
		fm.Name AS FormName, 
		fm.Designer AS FormDesigner
FROM         dbo.MN000 AS mn INNER JOIN dbo.FM000 AS fm ON mn.FormGUID = fm.GUID
WHERE	mn.type = 1
#########################################################
CREATE  PROCEDURE prcGetExpectedQtys		
(	 
	@GrpGuid UNIQUEIDENTIFIER = 0x0,   
	@CostGuid UNIQUEIDENTIFIER = 0x0 ,   
	@SrcTypesguid UNIQUEIDENTIFIER =  0x0,   
	@FromDate DATETIME = '1-1-1980',   
	@ToDate DATETIME   = '1-1-2070', 
	@SemiMatsOnlyFlag INT  = 0  
) 
AS 
SET NOCOUNT ON 
DECLARE @SemiMatsGroupGuid UNIQUEIDENTIFIER 
------------------------------------------------------------------------ 
SET @SemiMatsGroupGuid = (SELECT [VALUE] FROM op000 WHERE [NAME] ='man_semiconductGroup')  
------------------------------------------------------------------------- 

CREATE TABLE #CostGuids 
(  
	Guid UNIQUEIDENTIFIER, 
	
) 
INSERT INTO #CostGuids SELECT Guid FROM dbo.fnGetCostsList(@CostGuid)
IF(@CostGuid = 0x0)INSERT INTO #CostGuids VALUES (0x0)


-- This table holds the materials with thier standard quantities 
CREATE TABLE #StandardQty 
(  
	MatGuid UNIQUEIDENTIFIER, 
	MatCode NVARCHAR(100) COLLATE ARABIC_CI_AI, 
	MatName NVARCHAR(100) COLLATE ARABIC_CI_AI, 
	MatLatinName NVARCHAR(100), 
	StandardQty FLOAT 
) 
-- This table holds the materials with thier actual quantities 
CREATE TABLE #ActualQty 
( 
	MatGuid UNIQUEIDENTIFIER, 
	ActualQty FLOAT 
)	 
-- This table holds the end result which yield from joining previous tables 
CREATE TABLE #Result 
( 
	MatGuid UNIQUEIDENTIFIER, 
	MatCode NVARCHAR(100) COLLATE ARABIC_CI_AI, 
	MatName NVARCHAR(100) COLLATE ARABIC_CI_AI, 
	MatLatinName NVARCHAR(100), 
	StandardQty FLOAT, 
	ActualQty FLOAT 
) 
--------------------------------------------------------------------------------------					 
-- Filling #StandardQty table 
INSERT INTO #StandardQty  
SELECT   
		 q1.matGuid AS MatGuid   
		,q1.matcode AS MatCode   
		,q1.matname AS MatName   
		,q1.matlatinname AS MatLatinName   
		,Sum(CASE q1.billtype WHEN 2 THEN q1.Qty ELSE 0 END) AS StdOutput  		  
FROM    
(   
     SELECT DISTINCT mt.Guid AS MatGuid   
                   , mt.Code  AS MatCODE   
                   , mt.NAME AS MatName   
				   , mt.LatinName AS MatLatinName   
				   , bi.qty AS Qty   
				   , billTypes.[type] AS billtype   
				   , mn.Guid	AS Guid  
                
            FROM  
			bt000 billTypes    
            INNER JOIN bu000 bu                                         ON bu.[TypeGUID]   = billTypes.[GUID]   
            INNER JOIN bi000 bi                                         ON bi.[ParentGUID] = bu.[GUID]   
            INNER JOIN #CostGuids co ON ((co.Guid = bu.CostGuid AND bi.CostGuid = '00000000-0000-0000-0000-000000000000') OR  bi.CostGuid = co.Guid  )
            INNER JOIN (SELECT bu.costguid AS Guid FROM co000 co,bu000 bu    
						WHERE co.guid = bu.costGuid OR bu.costguid = 0x0   
						GROUP BY bu.costguid ) co1 ON co1.[GUID] = co.[Guid]   
            INNER JOIN mt000 mt                                         ON mt.[GUID]  = bi.[MatGUID]   
            INNER JOIN dbo.fnGetGroupsList (@GrpGuid)  gr ON gr.[GUID]  = mt.[GroupGUID]   
            INNER JOIN [RepSrcs] rs ON rs.[idType] = bu.[TypeGUID]   
			LEFT JOIN mb000 mb  ON mb.[BILLGUID] = bu.[GUID]    
			LEFT JOIN mn000 mn  ON mn.[GUID] = mb.[MANGUID]   
			INNER JOIN mi000 mi  ON mi.[MATGUID] = bi.[MATGUID]   
           WHERE    
				bu.[Date] >= @FromDate   
				AND bu.[Date] <= @ToDate    
				AND [rs].IdTbl = @SrcTypesguid   
				AND mi.[type] = 1   
) q1   
GROUP BY matguid, matcode, matName, matlatinName    
ORDER BY matCode  
------------------------------------------------------------------------------------------------- 
-- Filling #ActualQty table  

INSERT INTO #ActualQty 
SELECT MatGuid, ActOutPut FROM 
(	 
SELECT    
			 Qry1.matGuid AS MatGuid  , 
			 SUM(CASE Qry1.billtype WHEN 1 THEN Qry1.Qty WHEN 2 THEN Qry1.Qty WHEN 5 THEN Qry1.Qty ELSE -Qry1.Qty END) AS ActOutput    
	FROM    
	(   
		  SELECT DISTINCT  mt.Guid AS MatGuid   
					   , mt.Code  AS MatCODE   
					   , mt.NAME AS MatName   
					   , mt.LatinName AS MatLatinName   
					   , bi.qty AS Qty   
					   , billTypes.[billtype] AS billtype   
					   , bu.Guid  
				FROM bt000 billTypes   
				INNER JOIN bu000 bu                                         ON bu.[TypeGUID]   = billTypes.[GUID]   
				INNER JOIN bi000 bi                                         ON bi.[ParentGUID] = bu.[GUID]   
				INNER JOIN #CostGuids co ON ((co.Guid = bu.CostGuid AND bi.CostGuid = '00000000-0000-0000-0000-000000000000') OR  bi.CostGuid = co.Guid  )
				--INNER JOIN (SELECT bu.costguid AS Guid FROM co000 co,bu000 bu    
					--		WHERE co.guid = bu.costGuid or bu.costguid = 0x0   
						--	GROUP BY bu.costguid ) co1 ON co1.[GUID] = co.[Guid]   
				INNER JOIN mt000 mt                                         ON mt.[GUID]  = bi.[MatGUID]   
				INNER JOIN dbo.fnGetGroupsList (@GrpGuid)  gr ON gr.[GUID]  = mt.[GroupGUID]   
				INNER JOIN [RepSrcs] rs ON rs.[idType] = bu.[TypeGUID]   
			   WHERE    
					bu.[Date] >= @FromDate   
					AND bu.[Date] <= @ToDate    
					AND [rs].IdTbl = @SrcTypesguid   
					AND billTypes.[type] = 1
				   
	) Qry1   
GROUP BY Matguid, Matcode, MatName, MatlatinName
)Qry2 
---------------------------------------------------------------------------- 
-- Filling #Result table 
INSERT INTO #Result  
	SELECT SQ.MatGuid,  
		   SQ.MatCode,  
	       SQ.MatName,  
	       SQ.MatLatinName,  
	       SQ.StandardQty, 
	       AQ.ActualQty 
FROM #StandardQty AS SQ LEFT JOIN #ActualQty AS AQ ON SQ.MatGuid = AQ.MatGuid 
----------------------------------------------------------------------------- 
-- Exclude the materials that are not Semi manufactured , if match condition 
IF( @SemiMatsOnlyFlag = 1) 
DELETE FROM #Result WHERE matGuid NOT IN 
( 
	   SELECT mt.Guid FROM mt000 AS mt  
			  INNER JOIN dbo.fnGetGroupsList (@SemiMatsGroupGuid) AS gr  
	          ON gr.[GUID]  = mt.[GroupGUID]  
) 
----------------------------------------------------------------------------- 
-- returning result to caller 
SELECT * FROM #result 
-- Drop axulary tables  
DROP TABLE #Result 
DROP TABLE #StandardQty 
DROP TABLE #ActualQty 
#########################################################	                      
CREATE VIEW vwBuMb
AS
SELECT	bu.Guid, 
		bu.Number,
		ManGuid,
		mb.Type AS Type 
FROM mb000 mb INNER JOIN bu000 bu ON mb.BillGuid = bu.Guid
#########################################################	                      
#END