#########################################################
Create PROCEDURE FormsAndManuFactMaintain
/************************************************************
 ’Ì«‰… «·„—«Õ· ›Ï «· ’‰Ì⁄
 ŒÿÊ«  «·ŒÊ—“„Ì…
 1- ‰›—÷ «‰Â ·œÌ‰« „Ã„Ê⁄ «‰ «·«Ê·Ï ··„Ê«œ Ê«·À«‰Ì… ··‰„«–Ã
 2- ›Ï «·»œ«Ì… ‰÷⁄ ﬂ· «·„Ê«œ «·«Ê·Ì… ›Ï „Ã„Ê⁄… «·„Ê«œ 
 3- ‰«Œ– «·‰„«–Ã «· Ï  œŒ· «·„Ê«œ «· Ï »œ«Œ· „Ã„Ê⁄… «·„Ê«œ ﬂ„«œ… «Ê·Ì… ›ﬁÿ Ê‰÷Ì›Â« «·Ï „Ã„Ê⁄… «·‰„«–Ã
 4- ‰ﬁÊ„ »⁄œÌ· —ﬁ„ «·„—Õ·… ›Ï „Ã„Ê⁄… «·‰„«–Ã »—ﬁ„ Ê«Õœ
 5-‰ﬁÊ„ »«÷«›… «·„Ê«œ «· Ï  ‰ Ã ⁄‰ Â–Â «·‰„«–Ã („Ê«œ „’‰⁄Â )
 5- ‰÷Ì› «·„Ê«œ «·”«»ﬁ… «·Ï „Ã„Ê⁄… «·„Ê«œ 
 6- ‰ﬁÊ„ »Õ–› «·‰„«–Ã „‰ „Ã„Ê⁄… «··‰„«–Ã
 7- ‰ﬁÊ„ »«÷«›… «·‰„«–Ã «· Ï  Õ ÊÏ ⁄·Ï «ÕœÏ «·„Ê«œ ﬂ„«œ… «Ê·Ì… ›Ï „Ã„Ê⁄… «·„Ê«œ ›ﬁÿ  
 8- ‰ﬁÊ„ »“Ì«œ… ·Œ— ﬁ„ ··„—Õ·… »„ﬁœ«— Ê«Õœ 
 9- ‰œŒ· ›Ï Õ«·ﬁ…  ﬂ—Ì—… «·Ï «‰ Ì „ ’Ì«‰… Ã„Ì⁄ «·„—«Õ·  
 ************************************************************/
AS
SET NOCOUNT ON
	CREATE TABLE #MAt
	(
		GUID        UNIQUEIDENTIFIER,
		ParentGUID  UNIQUEIDENTIFIER,
		okFlag      BIT
	)
	CREATE TABLE #FormsAndManuf
	(
		MnGuid  UNIQUEIDENTIFIER,
		FmGuid  UNIQUEIDENTIFIER
	)
	DECLARE @Continue [INT]
	DECLARE @PhaseNumber [INT] = 1
	
	INSERT INTO #MAt
	SELECT m.MatGUID,
	       m.ParentGUID,
	       0
	FROM   MI000 m
	WHERE  dbo.ISHALFREADYMAT(m.MatGUID) = 0
	       AND m.[Type] = 1
	
	SELECT @Continue = COUNT(*)
	FROM   #MAt
	WHERE  okFlag = 0
	
	
	
	WHILE (@Continue <> 0)
	BEGIN
	    --	/////////////////////////////
	    
	    INSERT INTO #FormsAndManuf
	    SELECT DISTINCT vmf.mnGUID,
	           vmf.fmGUID
	    FROM   MI000 m
	           INNER JOIN #MAt mat
	                ON  mat.GUID = m.MatGUID
	           INNER JOIN vwMnFm vmf
	                ON  m.ParentGUID = vmf.mnGUID
	    WHERE  m.[Type] = 1
	           AND mat.okFlag = 0
	    
	    DELETE 
	    FROM   #FormsAndManuf
	    WHERE  MnGuid  IN (SELECT m.ParentGUID
	                       FROM   mi000 m
	                       WHERE  m.MatGUID NOT IN (SELECT DISTINCT mt.GUID
	                                                FROM   #MAt mt)
	                              AND m.[Type] = 1)
	    
	    
	    --	/////////////////////////////
	     UPDATE MN000
	    SET    PhaseNumber = @PhaseNumber
	    WHERE  GUID IN (SELECT MnGuid
	                    FROM   #FormsAndManuf Mnfm)
	           OR  FormGUID IN (SELECT FmGuid
	                            FROM   #FormsAndManuf Mnfm)
	    
	    --	/////////////////////////////
	    UPDATE #MAt
	    SET    okFlag = 1
	    WHERE  okFlag = 0
	    --	/////////////////////////////
	    INSERT INTO #MAt
	    SELECT m.MatGUID,
	           m.ParentGUID,
	           0
	    FROM   MI000 m
	           INNER JOIN #FormsAndManuf MnFm
	                ON  m.ParentGUID = MnFm.MnGuid
	    WHERE  m.[Type] = 0
	           AND m.MatGUID NOT IN (SELECT GUID
	                                 FROM   #MAt)
	    
	    
	    --	/////////////////////////////
	    DELETE 
	    FROM   #FormsAndManuf
	    --	/////////////////////////////
	    SELECT @Continue = COUNT(*)
	    FROM   #MAt
	    WHERE  okFlag = 0
	    
	    SET @PhaseNumber = @PhaseNumber + 1
	END
	
--	EXEC FormsAndManuFactMaintain
#########################################################
CREATE PROCEDURE TestFormsRelation 
	@guid UNIQUEIDENTIFIER
AS
/************************************************************
«Ã«—«∆Ì… «· «ﬂœ «‰Â ·Ì” Â‰«ﬂ „Ê«œ ›Ï ‰„Ê–Ã ﬂ„«œ… «Ê·Ì… „‰ ‰„Ê–Ã «Œ—  Ê«Õœ „Ê«œ «·‰Ê–Ã «·«Œ— „ÊÃÊœ ﬂ„«œ… «Ê·Ì… ›Ï Â–« «·‰„Ê–Ã  
·Ê ﬁÌ„… «· Count 1 „⁄‰Ï –«··ﬂ Â‰«ﬂ Œÿ√ „‰ «·„” Œœ„ 
************************************************************/
SET NOCOUNT ON
CREATE TABLE #FirstResult  
	(  
		Guid         UNIQUEIDENTIFIER,  
		ParentGuid   UNIQUEIDENTIFIER,  
		Code         NVARCHAR(250) COLLATE ARABIC_CI_AI,  
		[Name]       NVARCHAR(250) COLLATE ARABIC_CI_AI,  
		Number       FLOAT,  
		MatSecurity  INT,  
		[Level]      INT,  
		OrderCode    NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		RepCode    NVARCHAR(250) COLLATE ARABIC_CI_AI  
	)  
	CREATE TABLE #Result2  
	(   Guid         UNIQUEIDENTIFIER,  
		ParentGuid   UNIQUEIDENTIFIER,  
		Code         NVARCHAR(250) COLLATE ARABIC_CI_AI,  
		[Name]       NVARCHAR(250) COLLATE ARABIC_CI_AI,  
		Number       FLOAT,  
		MatSecurity  INT,  
		[Level]      INT,  
		OrderCode    NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		RepCode    NVARCHAR(250) COLLATE ARABIC_CI_AI  
	)  
	CREATE TABLE #Result3  
	(  
		 Guid         UNIQUEIDENTIFIER,  
		ParentGuid   UNIQUEIDENTIFIER,  
		Code         NVARCHAR(250) COLLATE ARABIC_CI_AI,  
		[Name]       NVARCHAR(250) COLLATE ARABIC_CI_AI,  
		Number       FLOAT,  
		MatSecurity  INT,  
		[Level]      INT,  
		OrderCode    NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		RepCode    NVARCHAR(250) COLLATE ARABIC_CI_AI  
	)  
	  
	INSERT INTO #FirstResult  
	EXEC repChartOfForms 0,  
	     0  
	  
	DELETE   
	FROM   #FirstResult  
	WHERE  Guid NOT IN (SELECT guid  
	                    FROM   fm000)  
	  
	DECLARE @code NVARCHAR(250)   
	  
	SET @code = (  
	        SELECT Top 1 r.OrderCode  
	        FROM   #FirstResult r  
	        WHERE  r.Guid = @guid  
	               AND r.[Level] = 1  
	    )  
	INSERT INTO #Result2  
	SELECT *  
	FROM   #FirstResult r  
	WHERE  r.OrderCode LIKE @code + '%'  
	       AND R.Guid <> @guid  
	  
	INSERT INTO #Result3  
	SELECT r.*  
	FROM   #FirstResult r  
	       INNER JOIN #Result2 r2  
	            ON  r.Guid = r2.Guid  
	WHERE  r2.OrderCode <> r.OrderCode  
	SELECT COUNT(*) count  
	WHERE  @guid IN (SELECT r1.guid  
	                 FROM   #FirstResult r1  
					 INNER JOIN #Result3 r2  
	                 ON  r1.OrderCode   
	                 LIKE r2.OrderCode    
                                    + '%')  

#########################################################
CREATE PROCEDURE prcCheckCostGuidForSemiMatInRawGrid
(
  @MatGuid UNIQUEIDENTIFIER -- «·„«œ… ‰’› «·„’‰⁄… 
)

AS
	SET NOCOUNT ON 
BEGIN 
  
 DECLARE @FormGuid UNIQUEIDENTIFIER 
 
 CREATE TABLE #TMP 
 (
	FormGuid UNIQUEIDENTIFIER ,
	Idrank INT 
 )

INSERT INTO #TMP   
SELECT FormGuid ,RANK() OVER (PARTITION BY mi.MatGuid ORDER BY fm.Number DESC) 

		FROM FM000 FM INNER JOIN MN000 MN ON MN.FormGUID = fm.GUID
					  INNER JOIN MI000 MI ON MI.ParentGUID = MN.GUID
WHERE MI.Type = 0 -- „«œ… Ã«Â“… 
		  AND 
		  MN.Type = 0 -- -- ‰„Ê–Ã 
		  AND 
		  MI.MatGUID = @MatGuid

SELECT *
INTO #tt 
FROM #TMP WHERE Idrank = 1 

SELECT @FormGuid = FormGuid 
FROM #tt


 SELECT   MN.StepCost as StepCostGuid --,  MN.OutCostGUID as OutCostGuid
	INTO #MatTable 
	FROM FM000 FM INNER JOIN MN000 MN ON MN.FormGUID = fm.GUID
				  INNER JOIN MI000 MI ON MI.ParentGUID = MN.GUID
	WHERE MI.Type = 0 -- „«œ… Ã«Â“… 
		  AND 
		  MN.Type = 0 -- -- ‰„Ê–Ã 
		  AND 
		  MI.MatGUID = @MatGuid
		  AND 
		  fm.Guid = @FormGuid 
		  
	SELECT distinct mx.CostGuid AS CostGuid 
	INTO #TotalTable 
	 FROM MX000 Mx INNER JOIN MN000 MN ON Mn.Guid = Mx.ParentGuid 
	WHERE MN.Type = 0 
		  AND 
		  MN.FormGUID = @FormGuid 
		   
		   
   SELECT MTbl.StepCostGuid, IsNull(TotalTb.CostGuid, 0X0) as CostGuid
   FROM #MatTable MTbl left JOIN  #TotalTable TotalTb ON MTbl.StepCostGuid = TotalTb.CostGuid

    	
END
#########################################################
CREATE FUNCTION fnIsUsedOfReadyMat(@FormG UNIQUEIDENTIFIER,  @MatGuid UNIQUEIDENTIFIER, @ManType INT)
RETURNS INT 
AS 
BEGIN
	DECLARE @FormGuid UNIQUEIDENTIFIER , @IsUsedReadyMat INT 

	if (@FormG = 0x0 )
	BEGIN 
	SELECT 	@IsUsedReadyMat =COUNT(fm.GUID)

			FROM FM000 FM INNER JOIN MN000 MN ON MN.FormGUID = fm.GUID
						  INNER JOIN MI000 MI ON MI.ParentGUID = MN.GUID
	WHERE MI.Type = 0 -- „«œ… Ã«Â“… 
			  AND 
			  MN.Type = @ManType-- ‰„Ê–Ã 
			  AND 
			  MI.MatGUID = @MatGuid
			 
   END 
   ELSE
   BEGIN
   SELECT 	@IsUsedReadyMat =COUNT(fm.GUID)

			FROM FM000 FM INNER JOIN MN000 MN ON MN.FormGUID = fm.GUID
						  INNER JOIN MI000 MI ON MI.ParentGUID = MN.GUID
	WHERE MI.Type = 0 -- „«œ… Ã«Â“… 
			  AND 
			  MN.Type = @ManType-- ‰„Ê–Ã 
			  AND 
			  MI.MatGUID = @MatGuid
			  AND fm.GUID <> @FormG
	END 
    
   

	RETURN   ISNull(@IsUsedReadyMat, 0) 
    
END
#########################################################
CREATE FUNCTION fnIsUsedOfStepCostCenter(@FormG UNIQUEIDENTIFIER,  @PhaseNumber INT, @CostGuid UNIQUEIDENTIFIER)
RETURNS INT 
AS 
BEGIN
	DECLARE @FormGuid UNIQUEIDENTIFIER , @IsUsedStepCostCenter INT 

	if (@FormG = 0x0 )
	BEGIN 
	SELECT 	@IsUsedStepCostCenter = COUNT(FM.GUID)

			FROM FM000 FM INNER JOIN MN000 MN ON MN.FormGUID = fm.GUID
				
	WHERE 	 MN.StepCost = @CostGuid -- „—ﬂ“ ﬂ·›… «·„—Õ·… 
			  AND @CostGuid <> 0x0
			  AND
			 MN.PhaseNumber <> @PhaseNumber
			 AND MN.Type = 0 	 
   END 
   ELSE
   BEGIN
   SELECT 	@IsUsedStepCostCenter =COUNT(FM.GUID)

			FROM FM000 FM INNER JOIN MN000 MN ON MN.FormGUID = fm.GUID
	WHERE 
			  MN.StepCost = @CostGuid -- „—ﬂ“ ﬂ·›… «·„—Õ·… 
			  AND @CostGuid <> 0x0
			  AND  
			 MN.PhaseNumber <> @PhaseNumber
			  AND FM.GUID <> @FormG
			  AND MN.Type = 0 
	END 

	RETURN   ISNull(@IsUsedStepCostCenter, 0) 
    
END
#########################################################
CREATE FUNCTION fnIsUsedOfInAccAsOutAcc(@FormG UNIQUEIDENTIFIER,  @InAccGuid UNIQUEIDENTIFIER)
RETURNS INT 
AS 
BEGIN
	DECLARE @FormGuid UNIQUEIDENTIFIER , @IsUsedOfInAccAsOutAcc INT 

	if (@FormG = 0x0 )
	BEGIN 
	SELECT 	@IsUsedOfInAccAsOutAcc = COUNT(FM.GUID)
			FROM FM000 FM INNER JOIN MN000 MN ON MN.FormGUID = fm.GUID	
	        WHERE 	MN.OutTempAccGuid = @InAccGuid -- Õ”«» Ê”Ìÿ «·«Œ—«Ã	 
   END 
   ELSE
   BEGIN
      SELECT 	@IsUsedOfInAccAsOutAcc =COUNT(FM.GUID)
			FROM FM000 FM INNER JOIN MN000 MN ON MN.FormGUID = fm.GUID 
			WHERE 	MN.OutTempAccGuid = @InAccGuid -- Õ”«» Ê”Ìÿ «·«Œ—«Ã
			 AND FM.GUID <> @FormG
	END 

	RETURN   ISNull(@IsUsedOfInAccAsOutAcc, 0) 
    
END
#########################################################
CREATE FUNCTION fnIsUsedOfOutAccAsInAcc(@FormG UNIQUEIDENTIFIER,  @OutAccGuid UNIQUEIDENTIFIER)
RETURNS INT 
AS 
BEGIN
	DECLARE @FormGuid UNIQUEIDENTIFIER , @IsUsedOfOutAccAsInAcc INT 

	if (@FormG = 0x0 )
	BEGIN 
	SELECT 	@IsUsedOfOutAccAsInAcc = COUNT(FM.GUID)
			FROM FM000 FM INNER JOIN MN000 MN ON MN.FormGUID = fm.GUID	
	        WHERE 	MN.InTempAccGuid = @OutAccGuid -- Õ”«» Ê”Ìÿ «·«Œ—«Ã	 
   END 
   ELSE
   BEGIN
      SELECT 	@IsUsedOfOutAccAsInAcc =COUNT(FM.GUID)
			FROM FM000 FM INNER JOIN MN000 MN ON MN.FormGUID = fm.GUID 
			WHERE 	MN.InTempAccGuid = @OutAccGuid -- Õ”«» Ê”Ìÿ «·«Œ—«Ã
			 AND FM.GUID <> @FormG
	END 

	RETURN   ISNull(@IsUsedOfOutAccAsInAcc, 0) 
    
END
#########################################################
CREATE FUNCTION fnCheckBillTypeHasBillsMovment(@BillType UNIQUEIDENTIFIER)
RETURNS INT  
AS 
BEGIN
	DECLARE @Result INT;

    IF EXISTS (SELECT 1 FROM bu000 WHERE TypeGUID = @BillType)
		SET @Result = 0;
    ELSE
		SET @Result = 1;
    RETURN @Result;
END 
#########################################################
#END    