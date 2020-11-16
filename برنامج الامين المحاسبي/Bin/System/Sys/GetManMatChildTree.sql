#########################################################################
CREATE PROC GetManMatChildTree
@MATGUID    [UNIQUEIDENTIFIER], 
@PARENTPATH [NVARCHAR](max) = ''
AS 
SET NOCOUNT ON 

	--///////////////////////////////////////////////////////////////////////////////   
      DECLARE @MANFORM  [UNIQUEIDENTIFIER]
      DECLARE @SELECTED UNIQUEIDENTIFIER
      DECLARE @MAT UNIQUEIDENTIFIER
      DECLARE @CNT INT
      DECLARE @PPATH [NVARCHAR](1000)
      
      SELECT TOP 1 @MANFORM = [PARENTGUID] 
      FROM MI000 MI
      INNER JOIN MN000 MN ON MN.GUID = MI.PARENTGUID
      INNER JOIN FM000 FM ON FM.GUID = MN.FORMGUID
      WHERE   MN.TYPE = 0 AND MI.TYPE = 0 AND MATGUID = @MATGUID
      
               
      IF (@PARENTPATH = '')
      BEGIN
				  IF NOT EXISTS ( SELECT * FROM tempdb..sysobjects WHERE name = '##TREEBUFFER')
                  CREATE TABLE ##TREEBUFFER
                  (
                        [GUID]                     [UNIQUEIDENTIFIER],
                        [PARENTGUID]         [UNIQUEIDENTIFIER],
                        [MATGUID]            [UNIQUEIDENTIFIER],
                        [ISHALFREADYMAT]   [BIT]                  ,
                        [PATH]                   [NVARCHAR](1000)  ,
                        [QTY]                [INT]                ,
			[Unit]			[INT],	
                        [TYPE]                     [INT]                ,
                        [IsSemiReadyMat]   [INT]                  
                  )
                  SET @PARENTPATH = '0'
      END
      
			INSERT INTO ##TREEBUFFER
            SELECT  MI.[GUID] , MI.PARENTGUID , MI.MATGUID , DBO.ISHALFREADYMAT(MI.MATGUID) , @PARENTPATH + '.' + CAST(MI.NUMBER AS NVARCHAR(100)) , MI.QTY , MI.Unity, MI.[TYPE] , 0
            FROM   MI000 MI
			INNER JOIN MN000 MN ON MN.GUID = MI.PARENTGUID
			INNER JOIN FM000 FM ON FM.GUID = MN.FORMGUID
            WHERE   MN.Type = 0 AND MI.TYPE = 1 AND PARENTGUID = @MANFORM 

      SELECT TOP 1
            @SELECTED = [GUID],
            @MAT = [MATGUID],
            @PPATH     = [PATH]
      FROM ##TREEBUFFER
      WHERE ISHALFREADYMAT = 1
      ORDER BY [PATH]          
      IF(@SELECTED <> 0X0)
      BEGIN
            UPDATE ##TREEBUFFER SET [ISHALFREADYMAT] = 0 , [IsSemiReadyMat] = 1 WHERE GUID = @SELECTED
            EXEC [DBO].[GETMANMATCHILDTREE]  @MAT, @PPATH
      END
      IF(@PARENTPATH = '0')
      BEGIN
            SET @CNT = (SELECT COUNT(*) FROM ##TREEBUFFER WHERE ISHALFREADYMAT = 1)
            IF(@CNT = 0)
            BEGIN
                  SELECT [TREE].[GUID] ,[TREE].[PARENTGUID] ,[FM].[Name] AS FORMNAME,[MATGUID] , [MT].[NAME] AS MATNAME,[TREE].[QTY],[TREE].[PATH], [TREE].[Unit], [TREE].[IsSemiReadyMat]
                  FROM ##TREEBUFFER TREE
                  LEFT JOIN MN000 MN ON [MN].[GUID] = [TREE].[PARENTGUID]                 
                  LEFT JOIN FM000 FM ON [FM].[GUID] = [MN].[FORMGUID]
                  LEFT JOIN MT000 MT ON [MT].[GUID] = [TREE].[MATGUID]
                  ORDER BY [TREE].[PATH]               
	          DROP TABLE ##TREEBUFFER
            END
      END
#########################################################################
CREATE PROCEDURE PrcGetBillOfMaterials
@Gr AS [UNIQUEIDENTIFIER]= 0x00
AS
SET NOCOUNT ON 
SELECT fm.Name, mn.Guid 
INTO #Forms
FROM mn000 mn INNER JOIN fm000 fm ON fm.Guid = mn.FormGuid WHERE Type  =  0 -- ‰„«–Ã
----------------------------------------------------------------------------------------------------------------------
SELECT   mi.MatGuid ,mt.Code MatCode, mt.Name MatName, mt.Unity MatUnit , mi.ParentGuid,
	 (CASE mi.Unity WHEN 1 then mi.Qty when 2 then mi.Qty * Unit2Fact when  3 then mi.Qty * Unit3Fact else mi.Qty END )RawMatQty , mi.Type
INTO #RawMat
FROM mi000 mi INNER JOIN mt000 mt ON mt.Guid = mi.MatGuid  
WHERE mt.GroupGUID = Case @Gr when 0x00 then mt.GroupGUID ELSE @Gr END AND  mi.Type= 1 --„«œ… √Ê·Ì…
-----------------------------------------------------------------------------------------------------------------------
SELECT RawMat.MatGuid, RawMat.MatCode +'  -  '+ RawMat.MatName+ '  -  ' +RawMat.MatUnit MatName, RawMat.MatUnit, RawMat.RawMatQty, f.Name 
FROM #RawMat RawMat INNER JOIN #Forms f ON f.Guid = RawMat.ParentGuid ORDER BY f.Name
#########################################################################
#END
