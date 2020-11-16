###########################################################
### ÇäÍÑÇÝ ÇáãÕÇÑíÝ

CREATE PROCEDURE repManufCostByLevel
(
	@AcGuid UNIQUEIDENTIFIER = 0x0,
	@CostGuid UNIQUEIDENTIFIER = 0x0,
	@WithOutCostCenter INT = 1,
	@FromDate DATETIME = '1-1-1980',
	@ToDate DATETIME   = '1-1-2070'
)
AS
	SET NOCOUNT ON

	DECLARE @Lang INT = [dbo].[fnConnections_GetLanguage]();
	DECLARE @Man_ActualAcc000 TABLE(
		ActualAccountGuid UNIQUEIDENTIFIER,
		AccountName NVARCHAR(250),
		MainAcount UNIQUEIDENTIFIER);
	DECLARE @Man_StanderAcc000 TABLE(
		StandardAccountGuid UNIQUEIDENTIFIER,
		AccountName NVARCHAR(250),
		MainAcount UNIQUEIDENTIFIER);
	DECLARE @AccountName NVARCHAR(250);
	DECLARE @ActualID UNIQUEIDENTIFIER;
	DECLARE @StanderID UNIQUEIDENTIFIER;
	DECLARE @getStanderAndActualID CURSOR;

	SET @getStanderAndActualID = CURSOR	FOR 
	SELECT 
		StandardAccountGuid,
		ActualAccountGuid, 
		AccountName
	FROM 
		MAN_ACTUALSTDACC000;

	OPEN @getStanderAndActualID;
	FETCH NEXT FROM @getStanderAndActualID INTO @StanderID, @ActualID, @AccountName;
	
	WHILE @@FETCH_STATUS = 0
    BEGIN
        INSERT INTO @Man_ActualAcc000
        SELECT 
			[Guid] AS ActualAccountGuid,
            @AccountName AS AccountName, 
            @ActualID AS MainAcount
        FROM 
			dbo.fnGetAccountsList(@ActualID, 0);
        INSERT INTO @Man_StanderAcc000
        SELECT 
			[Guid] StandardAccountGuid,
            @AccountName AccountName,
            @StanderID MainAcount
        FROM 
			dbo.fnGetAccountsList(@StanderID, 0);
        FETCH NEXT FROM @getStanderAndActualID INTO @StanderID, @ActualID, @AccountName;
    END;
	CLOSE @getStanderAndActualID;
	DEALLOCATE @getStanderAndActualID;

---
	SELECT 
		[GUID] 
	INTO #CostList
	FROM 
		dbo.fnGetCostsList(@CostGuid);

	IF ISNULL(@CostGuid, 0x0) = 0x0
    BEGIN
        INSERT INTO #CostList
        VALUES(0x0)
    END

	DECLARE @Ac2Guid UNIQUEIDENTIFIER;
	
	SELECT @Ac2Guid = actualaccountguid
	FROM man_ActualStdAcc000
	WHERE standardaccountguid = @AcGuid;
	
	IF ISNULL(@Ac2Guid, 0x0) = 0x0
    BEGIN
        SELECT @Ac2Guid = standardaccountguid
        FROM man_ActualStdAcc000
        WHERE actualaccountguid = @AcGuid;
    END;
	
	SELECT Guid 
	INTO #AccTable
	FROM dbo.fnGetAccountsList(@AcGuid, 1);

	INSERT INTO #AccTable
	SELECT Guid
	FROM dbo.fnGetAccountsList(@Ac2Guid, 1);

	SELECT
		en.AccountGUID AS AccountGUID, 
		en.CostGUID AS CostGUID, 
		(
			SELECT SUM(Debit) - SUM(Credit)
			FROM en000
			WHERE 
				AccountGUID = en.AccountGUID
				AND 
				CostGUID = en.CostGUID
				AND 
				[Date] >= @FromDate
				AND 
				[Date] <= @ToDate
		) AS Balance, 
		CASE WHEN @Lang > 0 THEN CASE WHEN ac.LatinName = '' THEN ac.Name ELSE ac.LatinName END ELSE ac.Name END AS AccountName INTO #Actual
	FROM
		(
			SELECT en.Guid
			FROM
				ce000 ce 
				INNER JOIN en000 en ON en.ParentGuid = ce.Guid
				INNER JOIN @Man_ActualAcc000 ac_list0 ON en.AccountGUID = ac_list0.ActualAccountGuid
				INNER JOIN #AccTable ac ON ac.Guid = ac_list0.ActualAccountGuid -- OR ac.Guid = ac_list0.[StandardAccountGuid] 
				LEFT JOIN #CostList co0 ON co0.GUID = en.CostGUID
				LEFT JOIN co000 co ON co.GUID = co.GUID
			WHERE 
				en.[Date] >= @FromDate
				AND 
				en.[Date] <= @ToDate
		) a 
		LEFT JOIN en000 en ON en.Guid = a.Guid
		INNER JOIN ac000 ac ON ac.Guid = en.AccountGuid
	GROUP BY 
		en.AccountGUID,
        en.CostGUID,
        CASE WHEN @Lang > 0 THEN CASE WHEN ac.LatinName = '' THEN ac.Name ELSE ac.LatinName END ELSE ac.Name END;
	
	INSERT INTO #Actual
	SELECT DISTINCT 
		stnd.AccountGUID, 
        co1.GUID AS CostGUID, 
        (
            SELECT 
				SUM(Balance)
            FROM
                #Actual stndr1 
				INNER JOIN co000 co00 ON co00.GUID = stndr1.CostGUID
            WHERE 
				co00.ParentGUID = co1.GUID
                AND 
				stndr1.AccountGuid = stnd.AccountGuid
        ) AS Balance, 
        stnd.AccountName
	FROM
		#Actual stnd 
		INNER JOIN co000 co0 ON co0.GUID = stnd.CostGUID
		INNER JOIN co000 co1 ON co1.GUID = co0.ParentGUID;

	SELECT en.AccountGUID AS AccountGUID, 
		en.CostGUID AS CostGUID, 
		(
			SELECT SUM(Debit) - SUM(Credit)
			FROM en000
			WHERE 
				AccountGUID = en.AccountGUID
				AND 
				CostGUID = en.CostGUID
				AND 
				[Date] >= @FromDate
				AND 
				[Date] <= @ToDate
		) AS Balance, 
		CASE WHEN @Lang > 0 THEN CASE WHEN ac.LatinName = '' THEN ac.Name ELSE ac.LatinName END ELSE ac.Name END AS AccountName INTO #Standard
	FROM
		(
			SELECT 
				en.Guid
			FROM
				ce000 ce 
				INNER JOIN en000 en ON en.ParentGuid = ce.Guid
				INNER JOIN @Man_StanderAcc000 ac_list0 ON en.AccountGUID = ac_list0.StandardAccountGuid
				INNER JOIN #AccTable ac ON ac.Guid = ac_list0.StandardAccountGuid -- OR ac.Guid = ac_list0.[StandardAccountGuid] 
				LEFT JOIN #CostList co0 ON co0.GUID = en.CostGUID
				LEFT JOIN co000 co ON co.GUID = co.GUID
			WHERE 
				en.[Date] >= @FromDate
				AND 
				en.[Date] <= @ToDate
		) a 
			LEFT JOIN en000 en ON en.Guid = a.Guid
			INNER JOIN ac000 ac ON ac.Guid = en.AccountGuid
	GROUP BY 
		en.AccountGUID, 
		en.CostGUID, 
		CASE WHEN @Lang > 0 THEN CASE WHEN ac.LatinName = '' THEN ac.Name ELSE ac.LatinName END ELSE ac.Name END;

	INSERT INTO #Standard
	SELECT DISTINCT 
		stnd.AccountGUID, 
		co1.GUID AS CostGUID, 
		(
			SELECT SUM(Balance)
			FROM
				#Standard stndr1 
				INNER JOIN co000 co00 ON co00.GUID = stndr1.CostGUID
			WHERE 
				co00.ParentGUID = co1.GUID
				AND 
				stndr1.AccountGuid = stnd.AccountGuid
		) AS Balance, 
		stnd.AccountName
	FROM
		#Standard stnd 
		INNER JOIN co000 co0 ON co0.GUID = stnd.CostGUID
		INNER JOIN co000 co1 ON co1.GUID = co0.ParentGUID;

	UPDATE #Standard
	SET AccountGUID = msa.MainAcount
	FROM 
		#Standard std 
		INNER JOIN @Man_StanderAcc000 msa ON std.AccountGUID = msa.StandardAccountGuid;

	UPDATE #Actual
	SET AccountGUID = msa.MainAcount
	FROM 
		#Actual act 
		INNER JOIN @Man_ActualAcc000 msa ON act.AccountGUID = msa.ActualAccountGuid;

	SELECT act.AccountGUID, 
		   act.CostGUID, 
		   SUM(act.Balance)Balance 
	INTO #FinalActual
	FROM #Actual act
	GROUP BY 
		act.AccountGUID, 
		act.CostGUID;

	SELECT 
		std.AccountGUID, 
		std.CostGUID, 
		SUM(std.Balance)Balance 
	INTO #FinalStandard
	FROM #Standard std
	GROUP BY 
		std.AccountGUID, 
		std.CostGUID;

	SELECT DISTINCT 
		co.Code, 
        CAST(co.Code AS NVARCHAR(100)) + '-' + co.Name CostName, 
        CAST(man_ac.AccountName AS NVARCHAR(100))AS AccountName, 
        ISNULL(ac.Balance, 0)AS ACTUAL, 
        0 AS [STANDARD], 
        CAST(0 AS float)AS DEF 
	INTO #RESULT
	FROM
		#FinalActual ac 
		FULL JOIN #FinalStandard stndr ON ac.CostGuid = stndr.CostGuid
		LEFT JOIN co000 co ON co.Guid = ac.CostGuid OR co.Guid = stndr.CostGuid
		INNER JOIN @Man_ActualAcc000 man_ac ON ac.AccountGuid = man_ac.ActualAccountGuid
	UNION
	SELECT 
		co.Code code, 
		CAST(co.Code AS NVARCHAR(100)) + '-' + ISNULL(co.Name, '')CostName, 
		ISNULL(CAST(man_ac.AccountName AS NVARCHAR(100)), '')AS AccountName, 
		0 AS ACTUAL, 
		ISNULL(stndr.Balance, 0)AS STANDARD, 
		0 AS DEF
	FROM
		#FinalActual ac 
		FULL JOIN #FinalStandard stndr ON ac.CostGuid = stndr.CostGuid
		LEFT JOIN co000 co ON co.Guid = ac.CostGuid OR co.Guid = stndr.CostGuid
		INNER JOIN @Man_StanderAcc000 man_ac ON stndr.AccountGuid = man_ac.StandardAccountGuid;

	INSERT INTO #RESULT
	SELECT DISTINCT 
		res.Code, 
		res.CostName , 
		CAST(res.AccountName AS NVARCHAR(100))AS AccountName, 
		0 AS ACTUAL, 
		0 AS STANDARD, 
		SUM(res.ACTUAL) + SUM(res.STANDARD)AS DEF
	FROM 
		#RESULT res
	GROUP BY 
		res.Code, 
		res.CostName, 
		res.AccountName;

	SELECT 
		AccountName, 
		SUM(ACTUAL)ACTUAL, 
		ABS(SUM(STANDARD))STANDARD, 
		SUM(DEF)DEF 
	INTO #FINALRES
	FROM #RESULT
	GROUP BY AccountName;

	IF @WithOutCostCenter = 0
    BEGIN
		SELECT ISNULL(temp.CostName,'IDS_WithoutCost') CostName, 
               temp.AccountName,
               temp.ACTUAL,
               temp.STANDARD,
               temp. DEF,
               CASE WHEN @Lang > 0 THEN CASE WHEN ac.LatinName = '' THEN ac.Name ELSE ac.LatinName END ELSE ac.Name END StandardName, 
               CASE WHEN @Lang > 0 THEN CASE WHEN ac2.LatinName = '' THEN ac2.Name ELSE ac2.LatinName END ELSE ac2.Name END ActualName
		FROM
            (
            SELECT		 
			        Code, 
            		CostName,
                    AccountName, 
                    SUM(ACTUAL
                        ) ACTUAL, 
                    ABS(SUM(STANDARD
                        ))STANDARD, 
                    SUM(DEF
                        )DEF
                FROM #RESULT
                GROUP BY Code,
                        CostName, 
                        AccountName
            ) AS temp 
			INNER JOIN man_ActualStdAcc000 man ON man.AccountName LIKE temp.AccountName
			INNER JOIN ac000 ac ON man.StandardAccountGuid = ac.Guid
			INNER JOIN ac000 ac2 ON man.ActualAccountGuid = ac2.Guid

		ORDER BY temp.code, temp.CostName ;
	END;
	ELSE
    BEGIN
        SELECT 
			'' costname,
            temp.*, 
            CASE WHEN @Lang > 0 THEN CASE WHEN ac.LatinName = '' THEN ac.Name ELSE ac.LatinName END ELSE ac.Name END StandardName, 
            CASE WHEN @Lang > 0 THEN CASE WHEN ac2.LatinName = '' THEN ac2.Name ELSE ac2.LatinName END ELSE ac2.Name END ActualName
        FROM
            (
				SELECT
					AccountName, 
					SUM(ACTUAL)ACTUAL, 
					ABS(SUM(STANDARD))STANDARD, 
					SUM(DEF)DEF
				FROM #RESULT
				GROUP BY AccountName
            ) AS temp 
			INNER JOIN man_ActualStdAcc000 man ON man.AccountName LIKE temp.AccountName
			INNER JOIN ac000 ac ON man.StandardAccountGuid = ac.Guid
			INNER JOIN ac000 ac2 ON man.ActualAccountGuid = ac2.Guid
	END;
 ------------------------------
	IF @WithOutCostCenter = 0
	BEGIN
		SELECT 
			ISNULL(temp.CostName, 'IDS_WithoutCost') AS CostName, 
			SUM(ACTUAL) AS ACTUAL, 
			ABS(SUM([STANDARD])) AS [STANDARD],
			SUM(DEF) AS DEF 
		FROM 
			(
				SELECT 
					temp.CostName, 
					temp.AccountName,
					temp.ACTUAL,
					temp.[STANDARD],
					temp.DEF,
					CASE WHEN @Lang > 0 THEN CASE WHEN ac.LatinName = '' THEN ac.Name ELSE ac.LatinName END ELSE ac.Name END AS StandardName, 
					CASE WHEN @Lang > 0 THEN CASE WHEN ac2.LatinName = '' THEN ac2.Name ELSE ac2.LatinName END ELSE ac2.Name END AS ActualName
				FROM
				(
					SELECT
						Code,
						CostName,
						AccountName,
						SUM(ACTUAL) AS ACTUAL,
						SUM([STANDARD]) AS [STANDARD],
						SUM(DEF) AS DEF
					FROM #RESULT
					GROUP BY 
						Code,
						CostName, 
						AccountName
				) AS temp 
				INNER JOIN man_ActualStdAcc000 man ON man.AccountName LIKE temp.AccountName
				INNER JOIN ac000 ac ON man.StandardAccountGuid = ac.[Guid]
				INNER JOIN ac000 ac2 ON man.ActualAccountGuid = ac2.[Guid]  
			) AS temp
		GROUP BY 
			temp.CostName
		ORDER BY 
			temp.CostName;
	END
	ELSE
		SELECT 
			'' AS CostName,
			SUM(ACTUAL) AS ACTUAL, 
			ABS(SUM([STANDARD])) AS [STANDARD],
			SUM(DEF) AS DEF 
		FROM 
			(
				SELECT
					Code,
					CostName,
					AccountName,
					SUM(VALUE) AS ACTUAL,
					0 AS STANDARD,
					0 AS DEF
				FROM 
				(	 
					SELECT DISTINCT 
						res.Code AS Code, 
						ISNULL(res.CostName,'') AS CostName, 
						'IDS_THETOTAL' AS AccountName, 
						SUM(res.ACTUAL) AS VALUE 
					FROM 
						#RESULT res 
					GROUP BY 
						res.Code, 
						res.CostName, 
						res.AccountName 
				) AS q1 
				GROUP BY 
					Code, 
					CostName, 
					AccountName 
				UNION 
                SELECT
					Code,
					CostName,
					AccountName,
					0 AS ACTUAL,
					SUM(VALUE) AS [STANDARD],
					0 AS DEF
                FROM 
                (
	                SELECT  
			            res.Code AS Code, 
			            ISNULL(res.CostName,'') AS CostName, 
			            'IDS_THETOTAL' AS AccountName, 
			            SUM(res.STANDARD) AS VALUE 
	                FROM 
						#RESULT res 
	                GROUP BY 
						res.Code, 
						res.CostName, 
						res.AccountName 
                ) AS q1 
                GROUP BY 
					Code, 
					CostName, 
					AccountName 
                UNION 
				SELECT
					Code, 
					CostName, 
					AccountName, 
					0 AS ACTUAL, 
					0 AS [STANDARD],
					SUM(VALUE) AS DEF			 
				FROM 
				(	 
					SELECT  
						res.Code, 
						ISNULL(res.CostName,'') AS CostName, 
						'IDS_THETOTAL' AS AccountName, 
						SUM(res.DEF) AS VALUE 
					FROM 
						#RESULT res 
					GROUP BY 
						res.Code, 
						res.CostName 
				) AS q1 
				GROUP BY 
					Code, 
					CostName, 
					AccountName  
			) AS temp
------------------------------
	IF @WithOutCostCenter = 0
		SELECT * FROM #FINALRES f

###########################################################
#END