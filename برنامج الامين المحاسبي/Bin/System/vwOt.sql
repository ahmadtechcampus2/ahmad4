###################################
CREATE VIEW vwOt
AS
	SELECT
		[GUID] AS [otGUID],
		[TypeName] AS [otTypeName],
		[BTSaleGUID] AS [otBTSaleGUID],
		[BTRSaleGUID] AS [otBTRSaleGUID],
		[BtInReadyGUID] AS [OtBtInReadyGUID],
		[BtOutRawGUID] AS [OtBtOutRawGUID],
		[InReadyAccGUID] AS [otInReadyAccGUID],
		[OutRawAccGUID] AS [otOutRawAccGUID],
		[SystemType] AS [otSystemType],
		[DrawerAccGuid] AS [otDrawerAccGuid],
		[CurDrawerAccGuid] AS [otCurDrawerAccGuid],
		[SpBtSaleGUID] AS [otSpBtSaleGUID],
		[SpBTRSaleGUID] AS [otSpBTRSaleGUID],
		[SpBTInReadyGUID] AS [otSpBTInReadyGUID],
		[SpBTOutRawGUID] AS [otSpBTOutRawGUID],
		[SpInReadyAccGUID] AS [otSpInReadyAccGUID],
		[SpOutRawAccGUID] AS [otSpOutRawAccGUID]
	FROM  
		[ot000]
###################################

CREATE VIEW vwIngredMats
AS 
	SELECT  
                [mt000].[code]      AS [nimatcode],
				[ni000].[matguid]   AS [Guid] ,
				[ng000].[matguid]   AS [ngMatguid] , 
				[mt000].[name]      AS [nimatname], 
				[mt000].[LatinName] AS [LatinName]
         
	FROM 
		[ng000] JOIN  [ni000]  
	  
ON [ng000].[guid]=[ni000].[parentguid] 

                JOIN [mt000]
ON [ni000].[matguid]=[mt000].[guid]

###################################

CREATE  function fnGetIngredMats(@MatPtr   [Uniqueidentifier])
returns TABLE
AS
	RETURN (SELECT * FROM    [vwIngredMats]  WHERE @Matptr = NgMatGuid) 
###################################

CREATE VIEW VwTablesInUse 
 AS 
  SELECT [tableGuid] 
  
  FROM [or000]
  
WHERE [orderstate] NOT IN(1,2,16) 

###################################
#END