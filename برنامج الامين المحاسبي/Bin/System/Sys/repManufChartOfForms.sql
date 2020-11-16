###########################################################
CREATE PROCEDURE repChartOfForms  
      @Lang       INT = 0,
      @Type       INT = 0                             -- Language (0=Arabic; 1=English)    
AS    
      SET NOCOUNT ON 
      IF(@TYPE = 0)
      BEGIN
            
            CREATE TABLE #SecViol (Type INT, Cnt INT)    
            CREATE TABLE #Result(  
                        Guid        UNIQUEIDENTIFIER,    
                        ParentGuid UNIQUEIDENTIFIER,    
                        Code        NVARCHAR(250) COLLATE ARABIC_CI_AI,    
                        [Name]            NVARCHAR(250) COLLATE ARABIC_CI_AI,    
                        Number            FLOAT,    
                        MatSecurity INT,    
                        [Level]     INT,  
                        OrderCode   NVARCHAR(250) COLLATE ARABIC_CI_AI 
                  )    
            CREATE TABLE #ReadyMat(MatGUID UNIQUEIDENTIFIER, MiGUID uniqueidentifier)    
                
            INSERT INTO #ReadyMat   
            SELECT   
                  mi.miMatGUID,   
                  mi.miGUID   
            FROM   
                  vwMi AS mi   
                  INNER JOIN vwMt AS mt ON mt.mtGUID = mi.miMatGUID   
                  INNER JOIN vwFm AS fm On fm.mnGUID = mi.miParent  
            WHERE  
                  mi.miType = 0  
            -- Insert Level 0 Ready Material 
            INSERT INTO #Result   
            SELECT   
                  DISTINCT   
                  rm.MatGUID AS GUID,   
                  CAST(0x00 AS UNIQUEIDENTIFIER)      AS ParentGUID,   
                  mt.mtCode   AS Code,   
                  (CASE @Lang WHEN 0 THEN mt.mtName WHEN 1 THEN (CASE mt.mtLatinName WHEN '' THEN mt.mtName ELSE mt.mtLatinName END) END)    AS Name,   
                  mt.mtNumber       AS Number,   
                  mt.mtSecurity     AS MatSecurity,   
                  0           AS [Level],  
                  mt.mtCode   AS OrderCode 
            FROM   
                  #ReadyMat AS rm   
                  INNER JOIN vwMt AS mt ON mt.mtGUID = rm.MatGUID 
            EXEC prcCheckSecurity 

            -- Insert Level 1 Forms 
            INSERT INTO #Result   
            SELECT   
                  fm.fmGUID   AS GUID,   
                  rm.MatGUID  AS ParentGUID,   
                  fm.fmCode   AS Code,   
                  (CASE @Lang WHEN 0 THEN fm.fmName WHEN 1 THEN (CASE fm.fmLatinName WHEN '' THEN fm.fmName ELSE fm.fmLatinName END) END) AS Name,   
                  mn.Number       AS Number,   
                  mn.Security     AS MatSecurity,   
                  1           AS [Level],  
                  mt.mtCode + fm.fmCode   AS OrderCode 
            FROM   
                  #ReadyMat AS rm   
                  INNER JOIN vwMi AS mi ON mi.miGUID = rm.MiGUID   
                  INNER JOIN MN000 AS mn ON mn.GUID = mi.miParent   
                  INNER JOIN vwFm AS fm ON mn.FormGUID = fm.fmGUID   
                  INNER JOIN vwMt AS mt ON mt.mtGUID = rm.MatGUID 
                  INNER JOIN #Result AS r ON r.GUID = rm.MatGUID AND Level = 0 
            EXEC prcCheckSecurity 

            -- Insert Level 2 Material In Form 
            INSERT INTO #Result   
            SELECT   
                  mt.mtGUID   AS GUID,   
                  r.GUID            AS ParentGUID,   
                  mt.mtCode   AS Code,   
                  (CASE @Lang WHEN 0 THEN mt.mtName WHEN 1 THEN (CASE mt.mtLatinName WHEN '' THEN mt.mtName ELSE mt.mtLatinName END) END) AS Name,   
                  mt.mtNumber       AS Number,   
                  mt.mtSecurity     AS MatSecurity,   
                  2           AS [Level],  
                  r.OrderCode + mt.mtCode AS OrderCode 
            FROM   
                  vwMi AS mi 
                  INNER JOIN MN000 AS mn ON mn.GUID = mi.miParent AND mn.Type = 0 AND mi.miType = 1 
                  INNER JOIN vwFm AS fm ON mn.FormGUID = fm.fmGUID 
                  INNER JOIN #Result AS r ON r.GUID = fm.fmGUID AND r.Level = 1 
                  INNER JOIN vwMt AS mt ON mt.mtGUID = mi.miMatGUID 
             
            EXEC prcCheckSecurity 

            -- Insert Level 3 Forms of Row Material 
            INSERT INTO #Result 
            SELECT   
                  fm.fmGUID   AS GUID, 
                  rm.GUID           AS ParentGUID, 
                  fm.fmCode   AS Code,   
                  (CASE @Lang WHEN 0 THEN fm.fmName WHEN 1 THEN (CASE fm.fmLatinName WHEN '' THEN fm.fmName ELSE fm.fmLatinName END) END) AS Name,   
                  mn.Number       AS Number,   
                  mn.Security     AS MatSecurity,   
                  3           AS [Level],  
                  rm.OrderCode + fm.fmCode      AS OrderCode 
            FROM   
                  #Result AS rm 
                  INNER JOIN vwMi AS mi ON mi.miMatGUID = rm.GUID 
                  INNER JOIN MN000 AS mn ON mn.GUID = mi.miParent   
                  INNER JOIN vwFm AS fm ON mn.FormGUID = fm.fmGUID 
                  INNER JOIN vwMt AS mt ON mt.mtGUID = rm.GUID 
            WHERE 
                  mi.miType = 0 AND  
                  rm.Level = 2 
            EXEC prcCheckSecurity 

            SELECT * 
			FROM 
            ( SELECT * , ROW_NUMBER() OVER (PARTITION BY OrderCode ORDER BY OrderCode)   AS RebCode from  #Result ) As res 
            where RebCode = 1
            ORDER BY OrderCode , Level  
      END
      ELSE
      BEGIN
            SELECT Guid ,
                     ParentForm As ParentGuid,
                     Code ,
                     Name ,
                     Number ,
                     1 [MatSecurity] ,
                     0 [Level] ,
                     '0.' + CAST(Number AS NVARCHAR(100)) OrderCode
            INTO #RESULT1
            FROM FM000
            WHERE ParentForm = 0x0
            
            DECLARE @lvl INT
            DECLARE @ordr INT
            SET @lvl = 0
            SET @ordr = 0
            
            WHILE( @lvl < 100 )
            BEGIN
                  SET @lvl = @lvl + 1
                  INSERT INTO #RESULT1
                  SELECT  fm.Guid ,
                           fm.ParentForm As ParentGuid,
                           fm.Code ,
                           fm.Name ,
                           fm.Number ,
                           1 [MatSecurity] ,
                           @lvl [Level] ,
                           res.OrderCode + '.' + CAST(fm.number AS NVARCHAR(100))+ '.' + CAST(  @lvl AS NVARCHAR(100)) OrderCode
                  FROM FM000 fm
                  INNER JOIN #Result1 res ON fm.ParentForm = res.Guid
                  WHERE [Level] = @lvl - 1

                  SET @ordr = @ordr + 1
            END 

			DECLARE @BranchMask BIGINT
			SET @BranchMask = (SELECT SUM([v].branchMask)
			FROM [vtBr] AS [v]
			WHERE [v].[branchMask] & [dbo].[fnConnections_getBranchMask]() <> 0)

			CREATE TABLE #BRANCHES (BranchGuid UNIQUEIDENTIFIER, BranchMask BIGINT )
			IF(@BranchMask != 0)
			BEGIN
				INSERT INTO #BRANCHES 
				SELECT FM.fmGUID, fm.fmBranchMask FROM vwFm fm WHERE (@BranchMask & fm.fmBranchMask) = fm.fmBranchMask
			END
			ELSE
			BEGIN
				INSERT INTO #BRANCHES 
				SELECT fmGUID, fmBranchMask FROM vwFm 
			END

            SELECT *, 
					(SELECT COUNT(*) FROM #Result1 WHERE ParentGuid = res.Guid ) NSons
            FROM 
            ( SELECT *,ROW_NUMBER() OVER (PARTITION BY OrderCode ORDER BY OrderCode)   AS RebCode from  #Result1 ) As res 
			INNER JOIN #BRANCHES BR ON BR.BranchGuid = GUID
            where RebCode = 1 
            ORDER BY OrderCode 
      END
###########################################################
CREATE PROC ManTreeChartMateials
	 @FormGuid UNIQUEIDENTIFIER
AS
SET NOCOUNT ON

SELECT 
	MT.GUID   ,
	MT.NAME   ,
	MT.CODE			      ,
	MT.Number			  ,
	MN.FORMGUID PARENTGUID,
	0 NSons,
	1 [Level], 
	DBO.ISHALFREADYMAT(MI.MATGUID) As IsSemiReadyMat
INTO #RESULT
FROM MI000 MI
INNER JOIN MN000 MN ON MN.GUID = MI.PARENTGUID
INNER JOIN FM000 FM ON FM.GUID = MN.FORMGUID
INNER JOIN MT000 MT ON MT.GUID = MI.MATGUID
WHERE   MN.TYPE = 0 AND MI.TYPE = 1 AND MN.FORMGUID = @FormGuid
ORDER BY IsSemiReadyMat DESC

DECLARE @CNT INT

SET @CNT = (SELECT COUNT(*) FROM #RESULT)

INSERT INTO #RESULT
SELECT 
	GUID,
	NAME,
	CODE,
	NUMBER,
	newid() PARENTGUID,
	@CNT NSons,
	0 [Level],
	-1 IsSemiReadyMat
FROM FM000 FM
WHERE Guid = @FormGuid

SELECT * FROM #RESULT
ORDER BY [Level]
###########################################################
#END