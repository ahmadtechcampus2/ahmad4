######################################################
CREATE PROC GetManufactureOperations
	@FromDate Date = '1-1-1900',
	@ToDate Date = '1-1-2015',
	@FormGuid UNIQUEIDENTIFIER = 0x0,
	@ManufactureNumber int = 0,
	@GroupGuid UNIQUEIDENTIFIER = 0x0,
	@MatGuid UNIQUEIDENTIFIER = 0x0,
	@CostGuid UNIQUEIDENTIFIER = 0x0
AS

SET NOCOUNT ON

SELECT Distinct mn.*,
			    fm.Name FormName,
			    co.Name InCostCenterName
FROM mn000 mn
	INNER JOIN fm000 fm ON mn.FormGuid = fm.Guid
	INNER JOIN MI000 mi ON mi.ParentGUID = mn.GUID
	INNER JOIN mt000 mt ON mi.MatGUID = mt.GUID
	LEFT JOIN co000 co ON mn.InCostGUID = co.GUID
WHERE (mn.FormGUID = @FormGuid OR ISNULL(@FormGuid, 0x0) = 0x0)
	  AND mn.Type = 1
	  AND mn.Date BETWEEN @FromDate AND @ToDate
	  AND (mn.Number = @ManufactureNumber OR @ManufactureNumber = 0)
	  AND (mi.MatGUID = @MatGUid OR ISNULL(@MatGUid, 0x0) = 0x0)
	  AND (mt.GroupGUID = @GroupGuid OR ISNULL(@GroupGuid, 0x0) = 0x0)
	  AND (mi.CostGUID = @CostGuid OR ISNULL(@CostGuid, 0x0) = 0x0)
ORDER BY mn.Number
######################################################
CREATE PROC GetRawMaterials
	@FromDate Date = '1-1-1900',
	@ToDate Date = '1-1-2015',
	@FormGuid UNIQUEIDENTIFIER = 0x0,
	@ManufactureNumber int = 0,
	@GroupGuid UNIQUEIDENTIFIER = 0x0,
	@MatGuid UNIQUEIDENTIFIER = 0x0,
	@CostGuid UNIQUEIDENTIFIER = 0x0
AS

SELECT Distinct mi.*,
			    mt.Code,
				mt.Name,
				mt.DefUnit,
				mt.Unity Unit1Name,
				mt.Unit2 Unit2Name,
				mt.Unit3 Unit3Name,
				mt.Unit2Fact, 
				mt.Unit3Fact,
				gr.Name GroupName,
				mn.Number ManufactureNumber
FROM mn000 mn
	INNER JOIN fm000 fm ON mn.FormGuid = fm.Guid
	INNER JOIN MI000 mi ON mi.ParentGUID = mn.GUID
	INNER JOIN mt000 mt ON mi.MatGUID = mt.GUID
	INNER JOIN gr000 gr ON mt.GroupGUID = gr.GUID
WHERE mi.Type = 1
      AND (mn.FormGUID = @FormGuid OR ISNULL(@FormGuid, 0x0) = 0x0)
	  AND mn.Type = 1
	  AND mn.Date BETWEEN @FromDate AND @ToDate
	  AND (mn.Number = @ManufactureNumber OR @ManufactureNumber = 0)
	  AND (mi.MatGUID = @MatGUid OR ISNULL(@MatGUid, 0x0) = 0x0)
	  AND (mt.GroupGUID = @GroupGuid OR ISNULL(@GroupGuid, 0x0) = 0x0)
	  AND (mi.CostGUID = @CostGuid OR ISNULL(@CostGuid, 0x0) = 0x0)
ORDER BY mn.Number
######################################################
CREATE PROC GetReadyMaterials
	@FromDate Date = '1-1-1900',
	@ToDate Date = '1-1-2015',
	@FormGuid UNIQUEIDENTIFIER = 0x0,
	@ManufactureNumber int = 0,
	@GroupGuid UNIQUEIDENTIFIER = 0x0,
	@MatGuid UNIQUEIDENTIFIER = 0x0,
	@CostGuid UNIQUEIDENTIFIER = 0x0
AS

SELECT Distinct mi.*,
				bi.Price BillPrice,
				mt.Code,
				mt.Name,
				mt.DefUnit,
				mt.Unity Unit1Name,
				mt.Unit2 Unit2Name,
				mt.Unit3 Unit3Name,
				mt.Unit2Fact, 
				mt.Unit3Fact,
				gr.Name GroupName,
				mn.Number ManufactureNumber 
FROM mn000 mn
	INNER JOIN fm000 fm ON mn.FormGuid = fm.Guid
	INNER JOIN MI000 mi ON mi.ParentGUID = mn.GUID
	INNER JOIN mt000 mt ON mi.MatGUID = mt.GUID
	INNER JOIN gr000 gr ON mt.GroupGUID = gr.GUID
	INNER JOIN mb000 mb ON mb.ManGUID = mn.GUID
	INNER JOIN bi000 bi ON mb.BillGUID = bi.ParentGUID AND mi.MatGUID = bi.MatGUID
WHERE  mi.Type = 0
	  AND (mn.FormGUID = @FormGuid OR ISNULL(@FormGuid, 0x0) = 0x0)
	  AND mn.Type = 1
	  AND mn.Date BETWEEN @FromDate AND @ToDate
	  AND (mn.Number = @ManufactureNumber OR @ManufactureNumber = 0)
	  AND (mi.MatGUID = @MatGUid OR ISNULL(@MatGUid, 0x0) = 0x0)
	  AND (mt.GroupGUID = @GroupGuid OR ISNULL(@GroupGuid, 0x0) = 0x0)
	  AND (mi.CostGUID = @CostGuid OR ISNULL(@CostGuid, 0x0) = 0x0)
	  AND mb.Type = 1
ORDER BY mn.Number
######################################################
CREATE PROC GetUnitExtraCost
	@FromDate Date = '1-1-1900',
	@ToDate Date = '1-1-2015',
	@FormGuid UNIQUEIDENTIFIER = 0x0,
	@ManufactureNumber int = 0,
	@GroupGuid UNIQUEIDENTIFIER = 0x0,
	@MatGuid UNIQUEIDENTIFIER = 0x0,
	@CostGuid UNIQUEIDENTIFIER = 0x0
AS

SELECT Distinct mx.*,
				mn.Number ManufactureNumber  
FROM mx000 mx 
	INNER JOIN mn000 mn ON mx.ParentGUID = mn.GUID
	INNER JOIN fm000 fm ON mn.FormGuid = fm.Guid
	INNER JOIN MI000 mi ON mi.ParentGUID = mn.GUID
	INNER JOIN mt000 mt ON mi.MatGUID = mt.GUID
	LEFT JOIN co000 co ON mi.CostGUID = co.GUID
WHERE mx.Type = 0 
	  AND (mn.FormGUID = @FormGuid OR ISNULL(@FormGuid, 0x0) = 0x0)
	  AND mn.Type = 1
	  AND mn.Date BETWEEN @FromDate AND @ToDate
	  AND (mn.Number = @ManufactureNumber OR @ManufactureNumber = 0)
	  AND (mi.MatGUID = @MatGUid OR ISNULL(@MatGUid, 0x0) = 0x0)
	  AND (mt.GroupGUID = @GroupGuid OR ISNULL(@GroupGuid, 0x0) = 0x0)
	  AND (mi.CostGUID = @CostGuid OR ISNULL(@CostGuid, 0x0) = 0x0)
ORDER BY mn.Number, mx.Type
#########################################################
CREATE PROC GetTotalExtraCost
	@FromDate Date = '1-1-1900',
	@ToDate Date = '1-1-2015',
	@FormGuid UNIQUEIDENTIFIER = 0x0,
	@ManufactureNumber int = 0,
	@GroupGuid UNIQUEIDENTIFIER = 0x0,
	@MatGuid UNIQUEIDENTIFIER = 0x0,
	@CostGuid UNIQUEIDENTIFIER = 0x0
AS

SELECT Distinct mx.*,
			    mn.Number ManufactureNumber  
FROM mx000 mx 
	INNER JOIN mn000 mn ON mx.ParentGUID = mn.GUID
	INNER JOIN fm000 fm ON mn.FormGuid = fm.Guid
	INNER JOIN MI000 mi ON mi.ParentGUID = mn.GUID
	INNER JOIN mt000 mt ON mi.MatGUID = mt.GUID
	LEFT JOIN co000 co ON mi.CostGUID = co.GUID
WHERE mx.Type = 1 
	  AND (mn.FormGUID = @FormGuid OR ISNULL(@FormGuid, 0x0) = 0x0)
	  AND mn.Type = 1
	  AND mn.Date BETWEEN @FromDate AND @ToDate
	  AND (mn.Number = @ManufactureNumber OR @ManufactureNumber = 0)
	  AND (mi.MatGUID = @MatGUid OR ISNULL(@MatGUid, 0x0) = 0x0)
	  AND (mt.GroupGUID = @GroupGuid OR ISNULL(@GroupGuid, 0x0) = 0x0)
	  AND (mi.CostGUID = @CostGuid OR ISNULL(@CostGuid, 0x0) = 0x0)
ORDER BY mn.Number, mx.Type
#########################################################
CREATE FUNCTION GetManufactoryWorkers
(
@ManufactoryGuid UNIQUEIDENTIFIER
)
RETURNS  @Result table 
(
	[GUID] [uniqueidentifier] PRIMARY KEY  NOT NULL,
	[Name] [nvarchar](250) NULL,
	[LatinName] [nvarchar](250) NULL,
	[Code] [nvarchar](100) NULL,
	[Security] [int] NULL
) 
AS 
BEGIN

INSERT INTO @Result 
	SELECT [GUID],[NAME],[LatinName],[Code],[Security]
		FROM JOCWorkers000 
			WHERE @ManufactoryGuid=CASE WHEN  ISNULL (@ManufactoryGuid,0x0)=0x0  THEN 0x0 ELSE ManufactoryGuid END  
RETURN 	 
END

#########################################################

CREATE PROC prcGetManufPrint
	@ManufFomGuid UNIQUEIDENTIFIER,
	@ManufType INT,
	@FromDate DATE,
	@ToDate DATE,
	@FilterByDate BIT,
	@FromNumber INT,
	@ToNumber INT
AS
	SET NOCOUNT ON
	IF(@ManufType = 0)
	BEGIN
		SELECT
			Form.GUID FormGuid
		FROM
			FM000 Form
			INNER JOIN MN000 Manuf ON Manuf.FormGUID = Form.GUID

		WHERE 
			Manuf.Type = 0
			AND ((@FilterByDate = 1 AND Manuf.Date BETWEEN @FromDate AND @ToDate) OR @FilterByDate = 0)
			AND ((@FilterByDate = 0 AND form.Number BETWEEN @FromNumber AND @ToNumber) OR @FilterByDate = 1)
	END
	ELSE
	BEGIN
		SELECT
			Manuf.GUID ManufGuid,
			Manuf.FormGUID FormGuid
		FROM
			 MN000 Manuf 
		WHERE 
			Manuf.Type = 1
			AND ((@FilterByDate = 1 AND Manuf.Date BETWEEN @FromDate AND @ToDate) OR @FilterByDate = 0)
			AND ((@FilterByDate = 0 AND Manuf.Number BETWEEN @FromNumber AND @ToNumber) OR @FilterByDate = 1)
			AND Manuf.FormGUID = @ManufFomGuid
	END
#########################################################
#END