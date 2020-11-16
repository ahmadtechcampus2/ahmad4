###########################################################################
CREATE PROCEDURE PrcGetStoreQtyForBill
	@StGuid UNIQUEIDENTIFIER,
	@GroupGuid UNIQUEIDENTIFIER,
	@MatCondGuid UNIQUEIDENTIFIER,
	@ShowBalnced BIT,
	@MaterialCategory VARCHAR(256)
AS
	SET NOCOUNT ON;

	DECLARE 
		@CurrUser UNIQUEIDENTIFIER,
		@SecBal INT,
		@SecBrs INT ;

	SET @CurrUser = dbo.fnGetCurrentUserGUID()
	SET @SecBrs = dbo.fnGetUserMaterialSec_Balance(@CurrUser)
	SET @SecBal = dbo.fnGetUserMaterialSec_Balance(@CurrUser)
	----------------------------
	CREATE TABLE [#StoreTbl]([StoreGUID] [UNIQUEIDENTIFIER] , [Security] [INT]) 
	INSERT INTO [#StoreTbl]	EXEC [prcGetStoresList] @StGuid 
	----------------------------
	CREATE TABLE [#Mat] ( [mtGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])
	INSERT INTO [#Mat] EXEC [prcGetMatsList]  NULL, @GroupGuid, -1, @MatCondGuid 
	----------------------------
	
	SELECT 
		[mt].[MtGuid],
		[MtCode],
		[MtName],
		[mtLatinName],
		ISNULL(SUM([Quantity]),0) AS [Quantity],
		ISNULL(SUM(Qty2),0) AS Qty2,
		ISNULL(SUM(Qty3),0) Qty3,
		mtDefunit,
		mtDefunitfact,
		mtDefUnitName,
		AVG(Case WHEN Quantity = 0 THEN 1 WHEN Quantity IS NULL THEN 2 ELSE 3 end)  AS MtQtyType -- 1 balanced  , 2 empty , 3 move

	INTO 
		#Qty
	FROM
		(
			SELECT biMatPtr,
					SUM(([biQty] + [biBonusQnt]) * [buDirection]) AS [Quantity],
					SUM(([biqty2]+ [biBonusQnt]) * [buDirection]) AS Qty2,
					SUM(([biqty3]+ [biBonusQnt]) * [buDirection]) AS Qty3 
			FROM 
				vwbubi  bu
				INNER JOIN [#StoreTbl] [st] ON bu.BiStorePtr = [st].[StoreGUID] 
			WHERE 
				bu.biClassPtr = @MaterialCategory OR @MaterialCategory = ''
			GROUP BY 
				biMatPtr

			
		) A
		RIGHT JOIN vwMtGr mt ON mtGuid = biMatPtr 
		INNER JOIN [#Mat] AS [m] ON [mt].[MtGuid] = [m].[mtGUID]
	WHERE
		mt.mtSecurity <= @SecBrs 
		AND 
		mt.mtSecurity <= @SecBal
		AND
		@ShowBalnced = 1 OR (@ShowBalnced = 0 AND Quantity IS NOT NULL)
	GROUP BY 
		[mt].[MtGuid],
		[mtCode],
		[mtName],
		[mtLatinName],
		mtDefunit,
		mtDefunitfact,
		mtDefUnitName
	
	SELECT * FROM  #Qty 
	ORDER BY
	[mtCode]
###########################################################################
#END 