######################################################
CREATE PROCEDURE PrcAssetPossessionsInventoryReport 
	@AssetGuid					UNIQUEIDENTIFIER
	,@MaterialGuid				UNIQUEIDENTIFIER
	,@GroupGuid					UNIQUEIDENTIFIER
	,@EmployeeGuid				UNIQUEIDENTIFIER
	,@MaterialConditionGuid		UNIQUEIDENTIFIER
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @Operation_Reciept SMALLINT,
		@Operation_Deliver SMALLINT

	SET @Operation_Reciept = 1
	SET @Operation_Deliver = 2
					
	CREATE TABLE [#MatTbl] ([MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])
	INSERT INTO [#MatTbl]	EXEC [prcGetMatsList]  @MaterialGuid, @GroupGuid, -1,@MaterialConditionGuid
	
	SELECT 
		 Ad.Sn + ' - ' + Mt.[Name] AS Asset
		,Mt.GUID  MatGuid
		,form.Employee
		,form.[Date]
		,item.AssetGuid
		,ISNULL(br.brName, '') AS brName
	
	FROM AssetPossessionsForm000 form
	INNER JOIN AssetPossessionsFormItem000 item ON form.Guid = item.ParentGuid
	INNER JOIN Ad000 Ad ON Ad.Guid = item.AssetGuid
	INNER JOIN As000 Ass ON Ass.Guid = Ad.ParentGuid
	INNER JOIN Mt000 Mt  ON Mt.Guid  = Ass.ParentGuid
	INNER JOIN #MatTbl MatTbl  ON Mt.Guid  = MatTbl.MatGUID
	
	LEFT JOIN ( 
				SELECT 
					MAX(form.[Date]) [Date], 
					form.Employee, 
					item.AssetGuid 
				FROM AssetPossessionsForm000 form
				INNER JOIN AssetPossessionsFormItem000 item ON form.Guid = item.ParentGuid 
				WHERE form.OperationType = @Operation_Reciept
					AND (@EmployeeGuid = 0x0 OR @EmployeeGuid = form.Employee)
				GROUP BY Employee, item.AssetGuid
		)  
		AS reciept_form ON reciept_form.Employee = form.Employee AND reciept_form.AssetGuid = Ad.Guid
	LEFT JOIN vwBr AS br ON form.Branch = br.brGUID
	WHERE	
		(ISNULL(@AssetGuid, 0x0) = 0x0 OR (Ad.Guid = @AssetGuid) )
			AND form.OperationType = @Operation_Deliver 
			AND form.[Date] > ISNULL(reciept_form.[Date], '')
			AND (@EmployeeGuid = 0x0 OR @EmployeeGuid = form.Employee)
		
	ORDER BY form.Number , item.Number
END
######################################################
#END