############################################################## 
CREATE PROCEDURE PrcImportBudgetCard (
		@UPDATE BIT = 0 )
AS
	SET NOCOUNT ON
	------------------------------------------------
	-- ##BUDGETCARDTBL has created in ( ImpBudgetCard.cpp -> Finish(...) )
	------------------------------------------------
	CREATE TABLE #BUDGETCARDTABLE
	(
		ACCCODE 	NVARCHAR(255) COLLATE ARABIC_CI_AI,
		COSTCODE 	NVARCHAR(255) COLLATE ARABIC_CI_AI,
		PERIODCODE 	NVARCHAR(255) COLLATE ARABIC_CI_AI,
		BRANCHCODE 	NVARCHAR(255) COLLATE ARABIC_CI_AI,
		CREDIT 		FLOAT,
		DEBIT 		FLOAT,
		AccGuid		UNIQUEIDENTIFIER,
		Cstguid		UNIQUEIDENTIFIER,
		PERIODguid	UNIQUEIDENTIFIER,
		BranchGuid	UNIQUEIDENTIFIER,
		abGuid		UNIQUEIDENTIFIER,
		--abdGuid		UNIQUEIDENTIFIER,
		Link		NVARCHAR(255),
		flag 		INT DEFAULT 0
	)
	
	------------------------------------------------
	INSERT INTO #BUDGETCARDTABLE (ACCCODE, COSTCODE, PERIODCODE, BRANCHCODE, CREDIT, DEBIT, ABGUID)
	SELECT ACCCODE, COSTCODE, PERIODCODE, BRANCHCODE, CREDIT, DEBIT, NEWID()
	FROM ##BUDGETCARDTBL
	
	------------------------------------------------
	UPDATE 	#BUDGETCARDTABLE SET
		BranchGuid = 	CASE BRANCHCODE WHEN '' THEN 0x00 ELSE NULL END,
		Cstguid    = 	CASE COSTCODE   WHEN '' THEN 0x00 ELSE NULL END,
		PERIODguid = 	CASE PERIODCODE WHEN '' THEN 0x00 ELSE NULL END
	WHERE PERIODCODE = '' OR BRANCHCODE = '' OR COSTCODE = ''
	
	------------------------------------------------
	CREATE TABLE #ab(
		ID INT IDENTITY(1, 1),
		Guid UNIQUEIDENTIFIER,
		AccGuid UNIQUEIDENTIFIER,
		ACCCODE NVARCHAR(255) COLLATE ARABIC_CI_AI,
		flag TINYINT default 0)
	
	------------------------------------------------ (#ab) insert
	INSERT INTO #ab(AccGuid, ACCCODE)
	SELECT ac.guid, AccCode 
	FROM ac000 ac
	INNER JOIN #BUDGETCARDTABLE b ON AccCode = ac.code
	GROUP BY ac.guid, AccCode
	
	------------------------------------------------ (#ab) update guid, flag for existed parent
	UPDATE #ab SET
		guid = a.guid,
		flag = 1 
	FROM #ab ab
	INNER JOIN ab000 a ON a.accguid = ab.accguid
	
	UPDATE #ab SET guid = NEWID() WHERE flag = 0
	
	------------------------------------------------ 
	UPDATE bd SET
		AccGuid = b.AccGuid,
		abGuid = b.guid
	FROM #BUDGETCARDTABLE bd
	INNER JOIN #ab b ON bd.ACCCODE = b.AccCode
	
	------------------------------------------------ 
	UPDATE bd SET
		cstguid = b.guid
	FROM #BUDGETCARDTABLE bd
	INNER JOIN co000 b ON bd.CostCode = b.code
	
	------------------------------------------------
	UPDATE bd SET
		BranchGuid = b.guid
	FROM #BUDGETCARDTABLE bd
	INNER JOIN br000 b ON bd.BRANCHCODE = b.Code
	
	------------------------------------------------
	UPDATE bd SET
		periodguid = b.guid
	FROM #BUDGETCARDTABLE bd
	INNER JOIN BDP000 b ON bd.PeriodCode = b.Code
	
	------------------------------------------------
	UPDATE #BUDGETCARDTABLE SET 
		link =  CAST(cstGuid 	AS NVARCHAR(36)) + 
			CAST(periodGuid AS NVARCHAR(36)) + 
			CAST(BranchGuid AS NVARCHAR(36)) + 
			CAST(abGuid 	AS NVARCHAR(36))
	
	------------------------------------------------
	DECLARE @NUMBER INT, @M INT
	SELECT @NUMBER = ISNULL(MAX(NUMBER), 0) FROM AB000
	
	INSERT INTO AB000(GUID, AccGuid, Security, Number) 
	SELECT A.Guid, A.AccGuid, 1, ID + @NUMBER 
	FROM #AB A
	WHERE FLAG = 0 
	ORDER BY ACCCODE 
	
	------------------------------------------------
	UPDATE A SET FLAG = 1 
	FROM #BUDGETCARDTABLE A 
	INNER JOIN ABD000 B ON A.LINK = CAST(B.COSTGUID    AS NVARCHAR(36)) + 
					CAST(B.PERIODGUID  AS NVARCHAR(36)) + 
					CAST(B.BRANCH 	   AS NVARCHAR(36)) + 
					CAST(B.PARENTGUID  AS NVARCHAR(36))
	
	------------------------------------------------ UPDATE FLAG FOR REPORT
	UPDATE A SET 
	FLAG = 1
	FROM #BUDGETCARDTABLE A where link in (SELECT CAST(COSTGUID    AS NVARCHAR(36)) + 
					CAST(PERIODGUID  AS NVARCHAR(36)) + 
					CAST(BRANCH 	   AS NVARCHAR(36)) + 
					CAST(PARENTGUID  AS NVARCHAR(36)) from abd000)
	
	------------------------------------------------
	INSERT INTO ABD000 (NUMBER, GUID, SECURITY, COSTGUID, PERIODGUID, BRANCH, PARENTGUID, CREDIT, DEBIT)
	SELECT AB.ID, NEWID(), 1,ISNULL(CSTGUID,0X00), PERIODGUID, BranchGuid, ABGUID, CREDIT, DEBIT 
	FROM #BUDGETCARDTABLE A INNER JOIN #AB AB ON AB.Guid = A.abGuid
	WHERE AB.FLAG = 0
	OR A.link NOT IN (SELECT CAST(COSTGUID    AS NVARCHAR(36)) + 
							CAST(PERIODGUID  AS NVARCHAR(36)) + 
							CAST(BRANCH 	   AS NVARCHAR(36)) + 
							CAST(PARENTGUID  AS NVARCHAR(36)) FROM abd000)
	
	------------------------------------------------
	IF @UPDATE > 0
	begin
		UPDATE ABD SET
			ABD.COSTGUID = A.CSTGUID,
			ABD.PeriodGuid = A.PERIODGUID,
			ABD.Branch = A.BranchGuid,
			ABD.CREDIT = A.CREDIT,
			ABD.DEBIT = A.DEBIT
		FROM ABD000 ABD
		INNER JOIN AB000 AB ON AB.GUID = ABD.PARENTGUID
		INNER JOIN #BUDGETCARDTABLE A ON A.link =  CAST(ABD.COSTGUID    AS NVARCHAR(36)) + 
											  CAST(ABD.PERIODGUID		AS NVARCHAR(36)) + 
											  CAST(ABD.BRANCH           AS NVARCHAR(36)) + 
											  CAST(ABD.PARENTGUID		AS NVARCHAR(36))
		WHERE A.FLAG = 1
		UPDATE AB SET Number = ab.Number
		FROM ABD000 ABD
		INNER JOIN AB000 AB ON AB.GUID = ABD.PARENTGUID
		INNER JOIN #BUDGETCARDTABLE A ON A.link =  CAST(ABD.COSTGUID    AS NVARCHAR(36)) + 
											  CAST(ABD.PERIODGUID		AS NVARCHAR(36)) + 
											  CAST(ABD.BRANCH           AS NVARCHAR(36)) + 
											  CAST(ABD.PARENTGUID		AS NVARCHAR(36))
		WHERE A.FLAG = 1	
	end
	UPDATE  ab  SET Security = ab.Security
	FROM ab000 ab INNER JOIN #BUDGETCARDTABLE bd ON abGuid = ab.Guid
	------------------------------------------------
	SELECT * FROM #BUDGETCARDTABLE
	
	DROP TABLE ##BUDGETCARDTBL
#################################################################
#END     
