#########################################################
CREATE  PROC prcAssetsGetEmployeeCustody 
	@AssetGuid UNIQUEIDENTIFIER,
	@ignorePossessionFormGuid UNIQUEIDENTIFIER = 0x0	
AS
DECLARE 
	@Operation_Reciept SMALLINT,
	@Operation_Deliver SMALLINT,

	@LastRecieptDate DATETIME,
	@LastRecieptNumber INT,

	@LastDeliverDate DATETIME,
	@LastDeliverNumber INT

SET @Operation_Reciept = 1
SET @Operation_Deliver = 2

SELECT 
	@LastDeliverDate = MAX ([DATE]), 
	@LastDeliverNumber = MAX(form.[Number])
FROM AssetPossessionsForm000 AS form
INNER JOIN AssetPossessionsFormItem000 AS item ON item.[ParentGuid] = form.[Guid] 
WHERE item.[AssetGuid] = @AssetGuid AND form.[OperationType] = @Operation_Deliver		
		AND (@ignorePossessionFormGuid = 0x0 OR @ignorePossessionFormGuid <> form.[GUID])

IF (@LastDeliverDate IS NULL OR @LastDeliverNumber IS NULL)
BEGIN
	RETURN 1
END

SELECT 
	@LastRecieptDate = MAX ([DATE]), 
	@LastRecieptNumber = MAX(form.[Number])
FROM AssetPossessionsForm000 AS form
INNER JOIN AssetPossessionsFormItem000 AS item ON item.[ParentGuid] = form.[Guid] 
WHERE item.[AssetGuid] = @AssetGuid AND form.[OperationType] = @Operation_Reciept		
		AND (@ignorePossessionFormGuid = 0x0 OR @ignorePossessionFormGuid <> form.[GUID])

SET @LastRecieptDate = ISNULL(@LastRecieptDate, '')
SET @LastRecieptNumber = ISNULL(@LastRecieptNumber, 0)

IF (@LastRecieptDate > @LastDeliverDate)
BEGIN
	RETURN 1
END

IF (@LastRecieptDate = @LastDeliverDate AND @LastRecieptNumber > @LastDeliverNumber)
BEGIN
	RETURN 1
END

SELECT 
	[Guid],
	[Employee],
	[Branch],
	[Date]
FROM AssetPossessionsForm000 AS form
INNER JOIN AssetPossessionsFormItem000 AS item ON item.[ParentGuid] = form.[Guid] 
WHERE [Date] = @LastDeliverDate AND form.[Number] = @LastDeliverNumber 
	AND item.[AssetGuid] = @AssetGuid AND form.[OperationType] = @Operation_Deliver	

RETURN 0
#########################################################
CREATE PROC prcAssetsFormGetNextOperation
	@AssetGuid UNIQUEIDENTIFIER,
	@Date	DATETIME,
	@Number INT,
	@Operation SMALLINT -- 2 Deliver, 1 Reciept
AS
	

SELECT 
	form.[GUID]
FROM AssetPossessionsForm000 AS form
INNER JOIN 
	(
		SELECT 	TOP 1
			form.[GUID], 
			MIN ([DATE]) AS MinDate,  
			MIN(form.[Number]) AS MinNumber
		FROM AssetPossessionsForm000 AS form
		INNER JOIN AssetPossessionsFormItem000 AS item ON item.[ParentGuid] = form.[Guid] 
		WHERE item.[AssetGuid] = @AssetGuid AND form.[OperationType] = @Operation	
			AND ([Date] > @Date OR ([Date] = @Date AND [Form].Number > @Number))
		GROUP BY form.[Guid]
	) AS NextOperation
	ON NextOperation.[Guid] = form.[Guid]
#########################################################
CREATE PROC prcAssetsGetNextUtlizeContract
	@AssetGuid UNIQUEIDENTIFIER,
	@Date	DATETIME
AS

SELECT TOP 1
	*
FROM AssetUtilizeContract000 
WHERE [Asset] = @AssetGuid AND [DATE] > @Date
ORDER BY [DATE]
#########################################################	
CREATE PROC prcAssetsutilzeGetLast
	@AssetGuid UNIQUEIDENTIFIER
AS
SELECT 
	*
FROM AssetUtilizeContract000
WHERE [Asset] = @AssetGuid 
	AND [Date] = 
	(
		SELECT 	MAX([DATE])
		FROM AssetUtilizeContract000 
		WHERE [Asset] = @AssetGuid
	)
AND IsCloseDateActive = 0 
#########################################################
CREATE  FUNCTION fnAssetGetMaterials
	(
		@AdGuid UNIQUEIDENTIFIER
	)
RETURNS TABLE
AS
RETURN 
(	
	SELECT 
		ad.[Guid] AS AdGuid,
		ad.[SnGuid] AS SNGuid,
		ad.[SN] AS SN,
		Asset.[Guid] AS AssetGuid,
		mt.[Guid] AS MaterialGuid
	FROM ad000 AS ad
	INNER JOIN As000 AS Asset ON asset.[Guid] = ad.ParentGuid
	INNER JOIN mt000 AS mt ON mt.[Guid] = asset.ParentGuid
	WHERE @AdGuid = 0x0 OR ad.[GUID] = @AdGuid
)
#########################################################
CREATE PROC CheckAssetModifedEmployeAndDate
	@FormGuid UNIQUEIDENTIFIER,
	@AssetGuid UNIQUEIDENTIFIER,
	@Number INT
 AS
 DECLARE @Date DATETIME

SET @Date = (SELECT Date FROM AssetPossessionsForm000 WHERE GUID = @FormGuid)

SELECT f.* FROM AssetPossessionsForm000 AS f
	INNER JOIN AssetPossessionsFormItem000 AS fi ON f.GUID = fi.ParentGuid
	WHERE f.OperationType = 1 AND fi.AssetGuid = @AssetGuid AND (f.Date > @Date OR (f.Date = @Date AND f.Number > @Number))
#########################################################
#END
