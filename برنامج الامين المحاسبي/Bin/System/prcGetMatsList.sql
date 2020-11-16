#########################################################
CREATE PROCEDURE prcGetMatsList
	@MatGUID [UNIQUEIDENTIFIER] = NULL, 
	@GroupGUID [UNIQUEIDENTIFIER] = NULL, 
	@MatType [INT] = -1, -- 0 MatStore or 1 MAtService or -1 ALL Mats Types 
	@CondGUID [UNIQUEIDENTIFIER] = NULL,
	@ExcludeSegmentedMaterials [bit] = 1
AS 
/*  
This procedure: 
	- returns Materials numbers according to a given @MatPtr, @GroupPtr and the CondId found in mc000 
	- depends on fnGetConditionStr 
*/  
	SET NOCOUNT ON 
	 
	DECLARE 
		@Criteria [NVARCHAR](max), 
		@SQL [NVARCHAR](max), 
		@HaveCustFld	BIT -- to check existing Custom Fields , it must = 1 

	SET @MatGUID = ISNULL(@MatGUID, 0x0) 
	SET @GroupGUID = ISNULL(@GroupGUID, 0x0) 
	SET @HaveCustFld = 0 
-- 	we must use vwMtGr cause of groups conditions  
--	Don't replace vwMtGr with vwMt 
	SET @SQL = ' 
		SELECT 
			DISTINCT [vwMtGr].[mtGUID] AS [GUID], 
			[mtSecurity] AS [Security] 
		FROM 
			[vwMtGr] ' 
	IF @GroupGUID <> 0x0
	BEGIN 
		-- this modification added to include mats in Collective groups
		DECLARE @GrpKind INT
		SELECT @GrpKind = Kind FROM GR000
		WHERE GUID = @GroupGUID
		IF @GrpKind = 0 -- Normal Grp
		BEGIN
			SET @SQL = @SQL + '  
				INNER JOIN [fnGetGroupsList]( ''' + CONVERT([NVARCHAR](255),@GroupGUID)+ ''') AS [f]  
				ON [vwMtGr].[mtGroup] = [f].[GUID]'
		END
		ELSE -- Collective Grp
		BEGIN
			SET @SQL = @SQL + '  
				INNER JOIN [fnGetMatsOfCollectiveGrps]( ''' + CONVERT([NVARCHAR](255),@GroupGUID)+ ''') AS [f]  
				ON [vwMtGr].[mtGUID] = [f].[mtGUID]'
				/*INNER JOIN Gri000 AS Gri ON vwMtGr.mtGuid = Gri.MatGUID AND Gri.GroupGuid = ''' + CONVERT([NVARCHAR](255),@GroupGUID) + ''''*/
		END
	END		
	IF ISNULL(@CondGUID,0X00) <> 0X00 
	BEGIN 
		SET @Criteria = [dbo].[fnGetConditionStr2]( NULL,@CondGUID) 
		IF @Criteria <> '' 
		BEGIN 
			IF (RIGHT(@Criteria,4) = '<<>>')-- <<>> to Aknowledge Existing Custom Fields 
			BEGIN 
				SET @HaveCustFld = 1 
				SET @Criteria = REPLACE(@Criteria,'<<>>','')  
			END 
			SET @Criteria = '(' + @Criteria + ')' 
		END 
	END 
	ELSE 
		SET @Criteria = ''  
--------------------------------------------------------------------------
-- Inserting Condition Of Custom Fields 
--------------------------------------------------------------------------
	IF @HaveCustFld > 0
	Begin 
		Declare @CF_Table NVARCHAR(255) 
		SET @CF_Table = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'mt000') 
		SET @SQL = @SQL + ' INNER JOIN ' + @CF_Table + ' ON [vwMtGr].[mtGUID] = ' + @CF_Table + '.Orginal_Guid' 
	End 
		
	DECLARE @MaterialsSegmentsCount [INT]
	SET @MaterialsSegmentsCount = 0
	SELECT @MaterialsSegmentsCount = COUNT(*) FROM [dbo].[vwConditions] WHERE [cndGUID] = @CondGUID AND [cndType] = 17 AND [FieldNum] >= 3000 AND [FieldNum] < 4000 
	IF @MaterialsSegmentsCount > 0
	Begin

		DECLARE @CNT INT,
		@CNT_STR NVARCHAR(MAX)
		SET @CNT = 0
		SET @CNT_STR = N''
		WHILE @CNT < @MaterialsSegmentsCount
		BEGIN
			SET @CNT = @CNT + 1;
			SET @CNT_STR = CONVERT(NVARCHAR, @CNT) 
			SET @SQL = @SQL + ' CROSS APPLY dbo.fnSEG_GetMaterialElements([vwMtGr].[mtGUID]) s' + @CNT_STR + CHAR(10)
		END;
	End
--------------------------------------------------------------------------	 
	IF @MatGUID <> 0x0 
		IF @Criteria <> '' SET @Criteria = @Criteria + ' 
			AND ([mtGUID] = ''' + CONVERT( [NVARCHAR](255), @MatGUID) + ''' OR [mtParent] = ''' + CONVERT( [NVARCHAR](255), @MatGUID) + ''')' 
		ELSE SET @Criteria = @Criteria + ' 
			([mtGUID] = ''' + CONVERT( [NVARCHAR](255), @MatGUID)+ ''' OR [mtParent] = ''' + CONVERT( [NVARCHAR](255), @MatGUID) + ''')' 
		
	SET @SQL = @SQL + ' WHERE 1 = 1' 
	IF @Criteria <> ''  
		SET @SQL = @SQL + ' AND ' + @Criteria  
	IF @MatType <> -1 AND @MatType < 3 
		SET @SQL = @SQL + ' AND [mtType] = ' + CAST( @MatType AS NVARCHAR) 
	ELSE IF @MatType = 256 
		SET @SQL = @SQL + ' AND ([mtType] = 0 OR [mtType] = 1) ' 
	ELSE IF @MatType = 257 
		SET @SQL = @SQL + ' AND ([mtType] = 0 OR [mtType] = 2) ' 
	ELSE IF @MatType = 258 
		SET @SQL = @SQL + ' AND ([mtType] = 1 OR [mtType] = 2) ' 
	IF @ExcludeSegmentedMaterials = 1
		SET @SQL = @SQL + ' AND [vwMtGr].[mtHasSegments] != 1 '
	EXEC(@SQL) 
#########################################################
CREATE PROCEDURE prcJobOrder_CheckMatGroup
		@Mat	 					UNIQUEIDENTIFIER,
		@Group						UNIQUEIDENTIFIER
AS   
SET NOCOUNT ON    
   
SELECT * 
FROM Mi000 Mi
INNER JOIN JobOrder000 Jo ON Jo.Guid = Mi.ParentGuid
WHERE Mi.Type = 0
	AND Mi.MatGuid = @Mat
	AND Jo.ProductionLine NOT IN 
	(
		SELECT 
			DISTINCT ProductionLine
		FROM ProductionLineGroup000  
		WHERE @Group IN (SELECT Guid FROM fnGetGroupsList(@Group))
	)
#########################################################
CREATE FUNCTION fnIsMatUsedInOrdersOrFormsOrBills(@MatGuid UNIQUEIDENTIFIER)
RETURNS  INT 
AS 
BEGIN 
	IF EXISTS(SELECT * FROM bi000 WHERE MatGUID = @MatGuid)
		BEGIN
			IF EXISTS(SELECT * FROM bi000 WHERE MatGUID = @MatGuid AND Unity = 2 OR Unity = 3 )
				RETURN 1
		END
	
	IF EXISTS(SELECT * FROM mi000 MI INNER JOIN MN000 MN ON MN.Guid = MI.ParentGuid WHERE MatGUID = @MatGuid AND MN.Type = 0)
		BEGIN
			IF EXISTS(SELECT * FROM mi000 MI INNER JOIN MN000 MN ON MN.Guid = MI.ParentGuid WHERE MatGUID = @MatGuid AND MN.Type = 0 AND (Unity = 2 OR Unity = 3))
				RETURN 2 
		END


	-- POS on smart device
	DECLARE @POSSDStationGroup TABLE(GroupGuid UNIQUEIDENTIFIER, StationGuid UNIQUEIDENTIFIER)
	INSERT INTO 
		@POSSDStationGroup 
	SELECT 
		Gfn.GroupGuid, SG.StationGUID
	FROM 
		POSSDStationGroup000 SG
		CROSS APPLY (SELECT [GUID] AS GroupGuid FROM [dbo].[fnGetGroupsList](SG.GroupGUID)) AS Gfn

	IF EXISTS( SELECT 
					* 
			   FROM mt000 MT 
			        INNER JOIN @POSSDStationGroup SG ON MT.GroupGUID = SG.GroupGuid
			        INNER JOIN POSSDShift000 SH ON SH.StationGUID = SG.StationGuid
			   WHERE 
					MT.[GUID] = @MatGuid
				    AND SH.CloseDate IS NULL ) 
		BEGIN
			RETURN 3
		END
	
	
RETURN 0
END 
#########################################################
CREATE FUNCTION fnIsMatUsedInBillsWithSerialNum (@MatGuid UNIQUEIDENTIFIER)
RETURNS  INT 
AS 
BEGIN 
	IF EXISTS(SELECT * FROM bi000 WHERE MatGUID = @MatGuid)
	BEGIN
	IF EXISTS(SELECT * FROM bi000 bi 
					INNER JOIN mt000 mt on mt.Guid = bi.MatGuid 
					INNER JOIN snt000 snt  ON snt.biGUID = bi.Guid 
					WHERE bi.MatGUID = @MatGuid  AND mt.SNflag = 1)
			RETURN 1
	END


	-- POS on smart device
	DECLARE @POSSDStationGroup TABLE(GroupGuid UNIQUEIDENTIFIER, StationGuid UNIQUEIDENTIFIER)
	INSERT INTO 
		@POSSDStationGroup 
	SELECT 
		Gfn.GroupGuid, SG.StationGUID
	FROM 
		POSSDStationGroup000 SG
		CROSS APPLY (SELECT [GUID] AS GroupGuid FROM [dbo].[fnGetGroupsList](SG.GroupGUID)) AS Gfn

	IF EXISTS( SELECT 
					* 
			   FROM mt000 MT 
			        INNER JOIN @POSSDStationGroup SG ON MT.GroupGUID = SG.GroupGuid
			        INNER JOIN POSSDShift000 SH ON SH.StationGUID = SG.StationGuid
			   WHERE 
					MT.[GUID] = @MatGuid
				    AND SH.CloseDate IS NULL ) 
			RETURN 2

  RETURN 0
END 
#########################################################
CREATE PROCEDURE prcInsertMainBarcodeIntoExtended
@MatGuid UNIQUEIDENTIFIER 
AS
BEGIN
  	SET NOCOUNT ON	

		 INSERT INTO MatExBarcode000 (Guid, MatGuid, MatUnit, Barcode, IsDefault)
				SELECT Newid(), Guid, 1 , Barcode, 1 
				FROM  mt000 mt  WHERE Guid = @MatGuid AND Barcode <>''
			
				INSERT INTO MatExBarcode000 (Guid, MatGuid, MatUnit, Barcode, IsDefault)
				SELECT Newid(), Guid, 2 ,  Barcode2, 1  
				FROM mt000 mt  WHERE Guid = @MatGuid AND Barcode2 <>''
			
			
				INSERT INTO MatExBarcode000 (Guid, MatGuid, MatUnit, Barcode, IsDefault)
				SELECT Newid(),  Guid, 3 , Barcode3, 1 
				FROM  mt000 mt WHERE Guid = @MatGuid AND Barcode3 <>''
END
#########################################################
CREATE FUNCTION fnIsMatUsedInJOC (@MatGuid UNIQUEIDENTIFIER)
RETURNS  INT 
AS 
BEGIN 
	IF (@MatGuid  = 0x0)
		return 0

	IF EXISTS(SELECT * FROM JOCBOMFinishedGoods000 WHERE MatPtr = @MatGuid)
		RETURN 1
	
	ELSE IF EXISTS(SELECT * FROM JOCBOMRawMaterials000 WHERE MatPtr = @MatGuid)
		RETURN 1
	
	ELSE IF EXISTS(SELECT * FROM JOCOperatingBOMFinishedGoods000 WHERE MaterialGuid = @MatGuid)
		RETURN 1
	
	ELSE IF EXISTS(SELECT * FROM JOCOperatingBOMRawMaterials000 WHERE RawMaterialGuid = @MatGuid)
		RETURN 1
	ELSE IF EXISTS(SELECT * FROM JOCOperatingBOMFinishedGoods000 WHERE SpoilageMaterial = @MatGuid)
		RETURN 1	

	ELSE IF EXISTS(SELECT * FROM JOCBOMSpoilage000 WHERE SpoilageMaterial = @MatGuid)
		RETURN 1
			
  RETURN 0
END 
#########################################################
CREATE PROCEDURE prcGetMatListByBillType
	@BillTypeGuid UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	CREATE TABLE [#MatTbl] ([MatGUID][UNIQUEIDENTIFIER], [mtSecurity][INT])

	DECLARE @GroupGuid UNIQUEIDENTIFIER = (SELECT DefaultGroupGUID FROM bt000 WHERE Guid = @BillTypeGuid)

	INSERT INTO [#MatTbl]
	EXEC [prcGetMatsList] 0X0, @GroupGUID, -1, NULL, 0
	
	SELECT MatGUID FROM [#MatTbl]

	DROP TABLE #MatTbl

#########################################################
#END