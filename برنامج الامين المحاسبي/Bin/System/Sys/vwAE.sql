################################################################################
CREATE VIEW vwAE
AS
	SELECT ae.*,CAST (Number AS NVARCHAR(100)) Code,br.brName AS BrunchName FROM AssetEmployee000 AS ae
		LEFT JOIN vwBr AS br ON ae.BranchGuid = br.brGUID
			WHERE ae.BranchGuid = 0x0 OR ISNULL(br.brGUID,0x0) <> 0x0
################################################################################
CREATE VIEW vtAssetPossessionsForm
AS
	SELECT [Number2] AS Number
	  ,[Number] AS Number2
      ,[GUID]
      ,[Security]
      ,[Employee]
      ,[Branch]
      ,[OperationType]
      ,[Date]
      ,[Notes]
      ,[ParentGuid]
	   FROM AssetPossessionsForm000 WHERE ParentGuid = 0x0
################################################################################
CREATE VIEW vtAssetEmployee
AS
	SELECT * FROM AssetEmployee000 
################################################################################
CREATE VIEW vbAssetPossessionsForm
AS
	SELECT * FROM vtAssetPossessionsForm
################################################################################
CREATE VIEW vbAssetEmployee
AS
	SELECT * FROM vtAssetEmployee
################################################################################
CREATE VIEW vtAssetStartDatePossessions
AS
	SELECT DISTINCT sp.* , pf.Branch, pf.Notes
	FROM
		AssetStartDatePossessions000 AS sp
			LEFT JOIN AssetPossessionsForm000 AS pf
				ON sp.GUID = pf.ParentGuid
################################################################################
CREATE VIEW vbAssetStartDatePossessions
AS
	SELECT * FROM vtAssetStartDatePossessions AS asd
		LEFT JOIN vwBr AS br ON asd.Branch = br.brGUID
			WHERE asd.Branch = 0x0 OR br.brGUID <> 0x0
################################################################################
CREATE TRIGGER trgAssetPossessionsForm
  ON [AssetPossessionsForm000] AFTER INSERT 
  NOT FOR REPLICATION
AS  
BEGIN 
	IF @@ROWCOUNT = 0 RETURN	
	SET NOCOUNT ON
	
IF (SELECT ParentGuid FROM INSERTED) = 0x0
	BEGIN
		UPDATE AssetPossessionsForm000
		SET Number2 = (SELECT ISNULL(MAX(Number2),0) + 1 FROM AssetPossessionsForm000 
			WHERE GUID <> (SELECT GUID FROM INSERTED) AND ParentGuid = 0x0)
				WHERE GUID = (SELECT GUID FROM INSERTED)
	END
ELSE
	BEGIN
		UPDATE AssetPossessionsForm000
		SET Number2 = (SELECT ISNULL(MAX(Number2),0) + 1 FROM AssetPossessionsForm000 
			WHERE GUID <> (SELECT GUID FROM INSERTED) AND ParentGuid <> 0x0)
				WHERE GUID = (SELECT GUID FROM INSERTED)
	END
END
################################################################################
#END
