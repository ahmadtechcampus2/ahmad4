######################################################
CREATE PROCEDURE PrcAssetMoveMasterPerYear
	@AssetDetailGuid	UNIQUEIDENTIFIER,
	@StartDate			DATETIME,
	@EndDate			DATETIME,
	@PrevAdd			FLOAT,
	@PrevDed			FLOAT,
	@PrevMain			FLOAT,
	@PrevDep			FLOAT,
	@CurAdd				FLOAT,
	@CurDed				FLOAT,
	@CurMain			FLOAT,
	@CurDep				FLOAT
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @Lang [INT];
	SET @Lang = dbo.fnConnections_GetLanguage();

	DECLARE @adEmployee NVARCHAR(250)
	DECLARE @adPosDate	DATETIME

	SELECT @adEmployee = [ap].[Employee], @adPosDate = [ap].[Date]
	  FROM AssetPossessionsFormItem000 AS [api]
		   INNER JOIN AssetPossessionsForm000 AS [ap] ON [ap].[GUID] = [api].[ParentGuid]
	 WHERE [ap].[OperationType] = 2 AND [api].[AssetGuid] = @AssetDetailGuid
 
	SELECT	[vad].[adGuid],
			DB_NAME(),	 
			@StartDate,	 
			@EndDate,	 
			[vad].[adInDate],
			[vad].[adInVal],
			@PrevAdd + @CurAdd,
			@PrevDed + @CurDed,
			([vad].[adInVal] + (@PrevAdd + @CurAdd) - (@PrevDed + @CurDed)),
			@PrevDep + @CurDep,
			([vad].[adInVal] + (@PrevAdd + @CurAdd) - (@PrevDed + @CurDed) - (@PrevDep+ @CurDep)),
			@PrevMain + @CurMain,
			[vad].[adScrapValue],
			CASE(ISNULL([vad].[adAge],0)) WHEN 0 THEN [as].[LifeExp] ELSE [vad].[adAge] END,
			[vad].[adPurchaseOrder],
			[vad].[adModel],					
			[vad].[adOrigin],					
			[vad].[adCompany],					
			[vad].[adManufDate],					
			[vad].[adSupplier],					
			[vad].[adLKind],					
			[vad].[adLCNum],						
			[vad].[adLCDate],					
			[vad].[adImportPermit],				
			[vad].[adArrvDate],					
			[vad].[adArrvPlace],					
			[vad].[adCustomStatement],			
			[vad].[adCustomCost],				
			[vad].[adCustomDate],				
			[vad].[adContractGuaranty],			
			[vad].[adContractGuarantyDate],		
			[vad].[adContractGuarantyEndDate],	
			[vad].[adJobPolicy],					
			[vad].[adNotes],						
			[vad].[adDailyRental],				
			[ad].[SITE],							
			[ad].[GUARANTEE],					
			[vad].[adGuarantyBeginDate],			
			[vad].[adGuarantyEndDate],			
			[ad].[DEPARTMENT],					
			[vad].[adBarCode],					
			CASE @Lang WHEN 0 THEN [ae].[Name] ELSE (CASE [ae].[LatinName] WHEN N'' THEN [ae].[Name] ELSE [ae].[LatinName] END) END,
			@adPosDate						
	  FROM	vwAd AS [vad] 
			INNER JOIN vtAs AS [as] ON [as].[GUID] = [vad].[adAssGuid]
			INNER JOIN ad000 AS [ad] ON [ad].[GUID] = [vad].[adGuid]
			LEFT JOIN vbAssetEmployee AS [ae] ON [ae].[GUID] = @adEmployee 
	 WHERE	[vad].[adGuid] = @AssetDetailGuid 
END
######################################################
#END