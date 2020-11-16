######################################################
CREATE PROCEDURE PrcAssetPossessionsMoveReport 
	@FromDate			DATETIME
	,@ToDate			DATETIME
	,@AssetGuid			UNIQUEIDENTIFIER
	,@MaterialGuid			UNIQUEIDENTIFIER
	,@GroupGuid			UNIQUEIDENTIFIER
	,@EmployeeGuid			UNIQUEIDENTIFIER
	,@MaterialConditionGuid		UNIQUEIDENTIFIER
AS
BEGIN
	SET NOCOUNT ON;
	
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])
	INSERT INTO [#MatTbl] EXEC [prcGetMatsList] @MaterialGuid, @GroupGuid, -1,@MaterialConditionGuid
	
	SELECT 
		 Ad.Sn Asset
		,Mt.Name MtName
		,form.Employee EmployeeGuid
		,CASE form.ParentGuid WHEN 0x0 THEN form.OperationType ELSE 3 END AS Movement
		,form.Date
		,Mt.GUID AS MatGuid
		,form.GUID AS FormGuid
		,form.Notes
		,CAST(ISNULL(asd.Number ,form.Number2)AS VARCHAR(50)) AS Number
		,item.AssetGuid
		,ISNULL(br.brName, '') AS brName
	FROM AssetPossessionsForm000 form
	INNER JOIN AssetPossessionsFormitem000 item ON form.Guid = item.ParentGuid
	INNER JOIN Ad000 Ad ON Ad.Guid = item.AssetGuid
	INNER JOIN As000 Ass ON Ass.Guid = Ad.ParentGuid
	INNER JOIN Mt000 Mt  ON Mt.Guid  = Ass.ParentGuid
	INNER JOIN #MatTbl MatTbl  ON Mt.Guid  = MatTbl.MatGUID
	LEFT JOIN AssetStartDatePossessions000 asd ON form.ParentGuid = asd.GUID
	LEFT JOIN vwBr AS br ON form.Branch = br.brGUID
	WHERE	(ISNULL(@AssetGuid, 0x0) = 0x0 OR (Ad.Guid = @AssetGuid))
		AND (form.[Date] BETWEEN @FromDate AND @ToDate)	
		AND (@EmployeeGuid = 0x0 OR @EmployeeGuid = form.Employee)
		AND form.Security <= [dbo].[fnGetUserSec]([dbo].fnGetCurrentUserGuid(),0x20007116,0x0,1,1)
	ORDER BY form.Number , item.Number
END
######################################################
#END