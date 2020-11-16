#########################################################
CREATE FUNCTION fnGetBillMatAccSons
(
@BillGuid UNIQUEIDENTIFIER,
@AccGuid UNIQUEIDENTIFIER,
@DBColumnFld NVARCHAR(256)  
)
RETURNS  @Result TABLE (
		[ParentGuid] UNIQUEIDENTIFIER,
		[SonGUID] UNIQUEIDENTIFIER,
		[Ratio] FLOAT
		)		
BEGIN 
	-- First Check Account if   
	IF NOT EXISTS(SELECT TOP 1 [guid] FROM ac000 WHERE GUID = @AccGuid AND [Type] = 8)
	OR 
	NOT EXISTS (SELECT TOP 1 [ParentGUID] FROM AccCostNewRatio000 AS acnr WHERE acnr.ParentGUID = @BillGuid AND acnr.PrimaryGUID = @AccGuid AND acnr.ControlDbColumn = @DBColumnFld)
	BEGIN 
		INSERT INTO @Result VALUES(@AccGuid,@AccGuid,100)
		RETURN 
	END 
	-- Finally Get Result 
	INSERT INTO @Result	
	SELECT  acnr.[PrimaryGUID], 
		    acnr.[SonGUID], 
			acnr.[Ratio]
	FROM AccCostNewRatio000 AS acnr 
	WHERE acnr.ParentGUID = @BillGuid AND
		  acnr.PrimaryGUID = @AccGuid AND
		  acnr.ControlDbColumn = @DBColumnFld
			
	RETURN 			
END 
/***TEST****
SELECT * FROM fnGetBillMatAccSons('F7EB630E-88CE-4CAF-873F-F59DA8327B1E')
*/
#########################################################
CREATE FUNCTION fnGetBillDiscounts
(
@BillGuid UNIQUEIDENTIFIER 
)
RETURNS  @Result TABLE (
		[diGuid]	UNIQUEIDENTIFIER,
		[diAccount] UNIQUEIDENTIFIER,
		[diDiscount] FLOAT,
		[diExtra] FLOAT,
		[diCostGUID] UNIQUEIDENTIFIER,
		[diContraAccGUID] UNIQUEIDENTIFIER, 
		[diCurrencyVAL] FLOAT, 
		[diCurrencyPtr] UNIQUEIDENTIFIER,
		[diNotes] NVARCHAR(1000) COLLATE ARABIC_CI_AI,
		[diNumber] INT,
		[diClassPtr] NVARCHAR(256) COLLATE ARABIC_CI_AI 
		)		
BEGIN 
-- First insert accounts hat are not distributive 
	INSERT INTO @Result
	SELECT  [diGuid],
			[diAccount], 
		    [diDiscount], 
		    [diExtra],
			[diCostGUID], 
			[diContraAccGUID], 
			[diCurrencyVAL],
			[diCurrencyPtr],
			[diNotes],
			([diNumber] + 1) * 1000,
			[diClassPtr]  
	FROM [vwDi] di 
		INNER JOIN ac000 ac ON di.[diAccount] = ac.[GUID] AND ac.[Type] <> 8
	WHERE 	[diParent] = @BillGUID AND	 
			([diDiscount] + [diExtra]) > 0 	
	ORDER BY di.[diNumber] 	
	--TEST
--	RETURN  --SELECT * FROM @Result		
--Second insert Distributive Accounts that HAVE NO new ratios in AccCostNewRatio000
	INSERT INTO @Result
	SELECT  [diGuid],
			[diAccount], 
		    [diDiscount], 
		    [diExtra],
			[diCostGUID], 
			[diContraAccGUID], 
			[diCurrencyVAL],
			[diCurrencyPtr],
			[diNotes],
			([diNumber] + 1) * 1000,
			[diClassPtr]  
	FROM [vwDi] di 
		INNER JOIN ac000 ac ON di.[diAccount] = ac.[GUID] 
		--INNER JOIN ci000 AS ci ON ci.ParentGUID = di.[diAccount]
	WHERE 	[diParent] = @BillGUID 	 
			AND ([diDiscount] + [diExtra]) > 0
			AND ac.[Type] = 8
			AND [diAccount] NOT IN 
			(
				SELECT AccSon.PrimaryGUID 
				FROM AccCostNewRatio000 AccSon
				WHERE 
					AccSon.ParentGUID = [diParent] AND
					AccSon.PrimaryGUID =[diAccount] AND  					
					ISNUMERIC(AccSon.ControlDbColumn) = 1 AND 
					AccSon.ControlDbColumn = di.[diNumber]
			)
	ORDER BY di.[diNumber] 
			--RETURN 
--Finally insert Distributive Accounts that HAVE new ratios in AccCostNewRatio000	
IF EXISTS (SELECT 1 FROM AccCostNewRatio000 AS acnr WHERE acnr.ParentGUID = @BillGUID AND 
		ISNUMERIC(acnr.ControlDbColumn) = 1)
	BEGIN 
		INSERT INTO @Result
		SELECT   
			[diGuid] AS [diGuid],
			acnr.SonGUID [diAccount], 
			acnr.Ratio * [diDiscount] / 100 AS [diDiscount], 
			acnr.Ratio * [diExtra] / 100 AS [diExtra],
			[diCostGUID], 
			[diContraAccGUID], 
			[diCurrencyVAL],
			[diCurrencyPtr],
			[diNotes],
			(acnr.[ControlDbColumn] + 1) * 1000 AS [diNumber],
			[diClassPtr] 
		FROM [vwDi] AS di  
			INNER JOIN AccCostNewRatio000 AS acnr ON acnr.PrimaryGUID = di.diAccount AND acnr.ParentGUID = di.diParent
			AND acnr.ControlDbColumn = [diNumber] 
		WHERE 
			[diParent] = @BillGUID AND 
			([diDiscount] + [diExtra]) > 0 AND
			ISNUMERIC(acnr.ControlDbColumn) = 1
		ORDER BY di.[diNumber] 	
		
	END 
 
	RETURN 			
END 
/***TEST****
SELECT * FROM fnGetBillDiscounts('F7EB630E-88CE-4CAF-873F-F59DA8327B1E') ORDER BY diNumber
*/
-- SELECT * FROM vwDi WHERE diParent = 'F7EB630E-88CE-4CAF-873F-F59DA8327B1E'

#END