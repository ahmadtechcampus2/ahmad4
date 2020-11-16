###########################################################
## create by azeez at 1:00 PM 13/3/2002
##########################################################
CREATE FUNCTION fnGetLableMatQty (@Qty int, @BiQty int, @BonusQnt int)
returns int
AS
BEGIN
return CASE @Qty WHEN 0 THEN @BiQty + @BonusQnt ELSE @Qty END
END
##########################################################
CREATE  PROCEDURE repLabelSN
		@BillType [UNIQUEIDENTIFIER],  
		@BillNum [INT], 
		@UnEmptyMat [INT], 
		@EmptyMat [INT], 
		@NegMat [INT], 
		@MatUnity [INT],
		@Qty int = 8,
		@MatCondGuid [UNIQUEIDENTIFIER] = 0x0
AS  
	SET NOCOUNT ON
	DECLARE 
		@UserId [UNIQUEIDENTIFIER] ,
		@Criteria [NVARCHAR](MAX), 
		@SQL [NVARCHAR](MAX), 
		@Qty_Str [NVARCHAR](100), 
		@HaveCustFld BIT, -- to check existing Custom Fields , it must = 1 
		@MaterialsSegmentsCount INT; -- to check existing Custom Fields , it must > 0
			
	SET @HaveCustFld = 0 ;
	SET @MaterialsSegmentsCount = 0;
	IF ISNULL(@MatCondGuid, 0X00) <> 0X00 
	BEGIN 
		SET @Criteria = [dbo].[fnGetConditionStr2]('vwMtGr', @MatCondGuid) 
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

	SET @UserId = [dbo].[fnGetCurrentUserGUID]() 
	CREATE TABLE [#Result](	[biGuid] [UNIQUEIDENTIFIER], 
				[LSN] [NVARCHAR](256) COLLATE ARABIC_CI_AI,  
				[ItemSN] [INT], 
				[LMatPtr] [UNIQUEIDENTIFIER],  
				[biNumber] [INT], 
				[Qty] [FLOAT], 
				[LItemQty] [FLOAT]) 

	SET @Qty_Str = CAST(@Qty AS [NVARCHAR](100)) 
	SET @SQL = '
		INSERT INTO [#Result] 
		SELECT  
			[in_bi].[biGuid] AS [BiGuid], 
			ISNULL([sn].[SN], '''') AS [LSN],  
			ISNULL([snt].[Item], 0) AS [ItemSN], 
			[in_bi].[biMatPtr] AS [LMatPtr],  
			[in_bi].[biNumber], 
			CASE ' + @Qty_Str + ' WHEN -1 THEN [in_bi].[mtQty] ELSE ' + @Qty_Str + ' END AS [Qty], 
			CASE ' + CAST(@MatUnity AS [NVARCHAR](100)) + '
				WHEN 0 THEN dbo.fnGetLableMatQty (' + @Qty_Str + ' , biBillQty,ISNULL( [in_bi].[biBillBonusQnt], 0))  
				WHEN 1 THEN dbo.fnGetLableMatQty (' + @Qty_Str + ' , biQty, [biBonusQnt])
				WHEN 2 THEN CASE [in_bi].[mtUnit2Fact] WHEN 0 THEN dbo.fnGetLableMatQty (' + @Qty_Str + ' , biBillQty, biBillBonusQnt) ELSE  dbo.fnGetLableMatQty (' + @Qty_Str + ' , biQty, biBonusQnt) / [in_bi].[mtUnit2Fact] END 
				WHEN 3 THEN CASE [in_bi].[mtUnit3Fact] WHEN 0 THEN dbo.fnGetLableMatQty (' + @Qty_Str + ' , biBillQty, biBillBonusQnt) ELSE dbo.fnGetLableMatQty (' + @Qty_Str + ' , biQty,  biBonusQnt) / [in_bi].[mtUnit3Fact] END 
				WHEN 4 THEN dbo.fnGetLableMatQty (' + @Qty_Str + ' , biQty,biBonusQnt) / CASE WHEN ISNULL( [in_bi].[mtDefUnitFact], 0) = 0 THEN 1 ELSE ISNULL( [in_bi].[mtDefUnitFact], 1) END 
			END AS [LItemQty] 
		FROM  
			[dbo].[vwExtended_bi] AS [in_bi]
			INNER JOIN [vwMtGr] AS [vwMtGr] ON [vwMtGr].[mtGUID] = [in_bi].[biMatPtr]
			LEFT JOIN [snt000] AS [snt] ON [in_bi].[biGuid] = [snt].[biGUID]
			LEFT JOIN [snc000] AS [sn] ON [snt].[ParentGUID] =  [sn].[GUID] '

	SELECT @MaterialsSegmentsCount = COUNT(*) FROM [dbo].[vwConditions] WHERE [cndGUID] = @MatCondGuid AND [cndType] = 17 AND [FieldNum] >= 3000 AND [FieldNum] < 4000 	
    IF ( @MaterialsSegmentsCount > 0 AND @Criteria <> '') 
	BEGIN
		DECLARE
			@SegTable VARCHAR(max) ;
		SET @SegTable = '
		LEFT JOIN [MaterialElements000] AS [ME] ON [ME].[MaterialId] = [vwMtGr].[mtGUID]
		LEFT JOIN [SegmentElements000] AS [SE] ON [SE].[Id] = [ME].[ElementId]
		LEFT JOIN [MaterialsSegmentsManagement000] [MSM] ON [SE].[SegmentId] = [MSM].[SegmentId]'	
		SET @SQL = @SQL + @SegTable;
	END 
	IF @HaveCustFld > 0
	BEGIN 
		Declare @CF_Table NVARCHAR(255) 
		SET @CF_Table = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'mt000') 
		SET @SQL = @SQL + ' INNER JOIN ' + @CF_Table + ' ON [vwMtGr].[mtGUID] = ' + @CF_Table + '.Orginal_Guid' 
	End 

	SET @SQL = @SQL + '
	WHERE  
		[in_bi].[buType] = ''' + CAST(@BillType AS [NVARCHAR](100)) + '''
		AND  
		[in_bi].[buNumber] = ' + CAST(@BillNum AS [NVARCHAR](100)) + ' 
		AND  
		[dbo].[fnGetUserBillSec_Browse](''' + CAST(@UserId AS [NVARCHAR](100)) + ''', [in_bi].[buType]) >= [in_bi].[buSecurity] 
		AND  
		[dbo].[fnGetUserMaterialSec_Browse](''' + CAST(@UserId AS [NVARCHAR](100)) + ''') >= [in_bi].[mtsecurity] '
		
	IF @Criteria <> ''  
		SET @SQL = @SQL + ' AND ' + @Criteria  
	
	EXEC (@SQL)
	IF( @EmptyMat = 0) 
		DELETE [#Result] WHERE [Qty] = 0 
	IF( @UnEmptyMat = 0) 
		DELETE [#Result] WHERE [Qty] > 0 
	IF( @NegMat = 0) 
		DELETE [#Result] WHERE [Qty] < 0 
		
	SELECT * FROM [#Result] 
	ORDER BY   
		[biNumber], 
		[ItemSN], 
		[LSN]
###########################################################
#end
