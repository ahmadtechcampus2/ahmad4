###########################################################
### ÊæÒíÚ ÇáãÕÇÑíÝ

CREATE    PROCEDURE repManCostTunBySpend
(
	@FormGuid   UNIQUEIDENTIFIER = 0x0	 ,
	@AcGuid UNIQUEIDENTIFIER = 0x0       ,
	@CostGuid UNIQUEIDENTIFIER = 0x0	 ,
	@FromDate DATETIME = '1-1-1980'      ,
	@ToDate DATETIME   = '1-1-2070'      
)
AS
SET NOCOUNT ON
DECLARE @Ac2Guid UNIQUEIDENTIFIER
SELECT @Ac2Guid = actualaccountguid FROM man_ActualStdAcc000 WHERE standardaccountguid = @AcGuid
IF( ISNULL(@Ac2Guid,0x0) = 0x0 )
BEGIN
	SELECT @Ac2Guid = standardaccountguid FROM man_ActualStdAcc000 WHERE actualaccountguid = @AcGuid
END

SELECT Guid INTO #AccTable
FROM [dbo].[fnGetAccountsList](@AcGuid,1)

INSERT INTO #AccTable
SELECT Guid FROM [dbo].[fnGetAccountsList](@Ac2Guid,1)


SELECT 
		en.[AccountGUID]                 AS AccountGUID,
		en.[CostGUID]                    AS CostGUID, 
		(  
		   SELECT SUM(Debit) - SUM([Credit])
		   FROM en000
		   WHERE AccountGUID = en.[AccountGUID] AND [CostGUID] = en.[CostGUID])  AS Balance,
		ac.Name 			 AS AccountName
INTO #Actual
FROM (
	SELECT en.Guid
		FROM ce000 ce 
			INNER JOIN en000                                en        ON en.ParentGuid            =    ce.Guid  
			INNER JOIN MAN_ACTUALSTDACC000                ac_list0    ON en.[AccountGUID]         =    ac_list0.[ActualAccountGuid]
			INNER JOIN #AccTable ac        ON ac.Guid                  =    ac_list0.[ActualAccountGuid]         -- OR ac.Guid = ac_list0.[StandardAccountGuid]
			INNER JOIN [dbo].[fnGetCostsList](@CostGuid)    co0       ON co0.[GUID]               =    en.[CostGUID]
			INNER JOIN co000                                co        ON co.[GUID]                =    co.[GUID]
	WHERE en.[Date] >= @FromDate       AND en.[Date] <= @ToDate
) a
INNER JOIN en000 en ON en.Guid = a.Guid
INNER JOIN ac000 ac ON ac.Guid = en.AccountGuid
GROUP BY en.[AccountGUID], en.[CostGUID] , ac.[Name]

INSERT INTO #Actual
SELECT DISTINCT	stnd.AccountGUID,
		co1.[GUID] as CostGUID,
		(SELECT SUM(Balance) FROM #Actual stndr1 INNER JOIN co000 co00 ON co00.[GUID] = stndr1.CostGUID WHERE  co00.[ParentGUID] = co1.[GUID] and stndr1.AccountGuid = stnd.AccountGuid ) AS Balance,
		stnd.AccountName
FROM #Actual stnd
INNER JOIN co000 co0 ON co0.[GUID] = stnd.CostGUID
INNER JOIN co000 co1 ON co1.[GUID] = co0.[ParentGUID]

SELECT 
		en.[AccountGUID]                 AS AccountGUID,
		en.[CostGUID]                    AS CostGUID, 
		(SELECT SUM(Debit) - SUM([Credit])
		 FROM en000 WHERE AccountGUID = en.[AccountGUID] AND [CostGUID] = en.[CostGUID])  AS Balance,
		ac.Name 			 AS AccountName
INTO #Standard
FROM (
		SELECT en.Guid
		FROM ce000 ce 
			INNER JOIN en000                                en        ON en.ParentGuid            =    ce.Guid  
			INNER JOIN MAN_ACTUALSTDACC000                ac_list0    ON en.[AccountGUID]         =    ac_list0.[StandardAccountGuid]
			INNER JOIN #AccTable ac        ON ac.Guid                  =    ac_list0.[StandardAccountGuid]         -- OR ac.Guid = ac_list0.[StandardAccountGuid]
			INNER JOIN [dbo].[fnGetCostsList](@CostGuid)    co0       ON co0.[GUID]               =    en.[CostGUID]
			INNER JOIN co000                                co        ON co.[GUID]                =    co.[GUID]
		WHERE en.[Date] >= @FromDate                        AND en.[Date] <= @ToDate
) a
INNER JOIN en000 en ON en.Guid = a.Guid
INNER JOIN ac000 ac ON ac.Guid = en.AccountGuid
GROUP BY en.[AccountGUID], en.[CostGUID] , ac.[Name]

INSERT INTO #Standard
SELECT DISTINCT	stnd.AccountGUID,
		co1.[GUID] as CostGUID,
		(SELECT SUM(Balance) FROM #Standard stndr1 INNER JOIN co000 co00 ON co00.[GUID] = stndr1.CostGUID WHERE  co00.[ParentGUID] = co1.[GUID] and stndr1.AccountGuid = stnd.AccountGuid ) AS Balance,
		stnd.AccountName
FROM #Standard stnd
INNER JOIN co000 co0 ON co0.[GUID] = stnd.CostGUID
INNER JOIN co000 co1 ON co1.[GUID] = co0.[ParentGUID]

SELECT DISTINCT
		co.Guid As CostGuid,
		CAST (man_ac.AccountName as NVARCHAR(100)) as AccountName,
		CAST('IDS_ACTUAL' AS NVARCHAR(100)) AS [TYPE],
		ISNULL(ac.Balance   , 0) AS VALUE
INTO #RESULT
FROM #Actual ac
INNER JOIN #Standard stndr             ON  ac.CostGuid = stndr.CostGuid
INNER JOIN co000    co                ON co.Guid = ac.CostGuid    OR  co.Guid = stndr.CostGuid
INNER JOIN MAN_ACTUALSTDACC000 man_ac ON ac.AccountGuid = man_ac.[ActualAccountGuid]
UNION
SELECT 
		co.Guid As CostGuid,
		ISNULL(CAST (man_ac.AccountName as NVARCHAR(100)),'') as AccountName,
		'IDS_STANDARD' AS [TYPE],	
		ISNULL(stndr.Balance, 0) AS VALUE
FROM #Actual ac
INNER JOIN #Standard stndr ON  ac.CostGuid = stndr.CostGuid
INNER JOIN co000     co   ON co.Guid = ac.CostGuid              OR  co.Guid = stndr.CostGuid
INNER JOIN MAN_ACTUALSTDACC000 man_ac ON stndr.AccountGuid = man_ac.[StandardAccountGuid]

SELECT 
		mn.CostGuid    CostGuid	   ,
		ISNULL(CAST((SELECT Number FROM co000 WHERE GUID = co.[ParentGUID]) as NVARCHAR(10)),'') + '-' +  ISNULL(CAST(co.[Number] as NVARCHAR(10)),'')+ '            ' + co.Name        CostName	   ,
		co.ParentGuid			   ,
		mn.FormGuid	   FormGuid	   ,
		p.[Qty]        PlanQty     ,
		mn.[Qty]       ManQty      ,
	   (mn.[QTY] - p.[QTY]) as def ,
	   CASE p.[Qty] WHEN 0 THEN 0 ELSE ((mn.[Qty]     / p.[Qty])) * 100		END AS UsePerc,
	   CASE p.[Qty] WHEN 0 THEN 0 ELSE (1 - (mn.[Qty] / p.[Qty]))* 100     END AS LostPerc
INTO #LIST
FROM 
(
	SELECT FORMGUID , SUM(QTY) QTY 
	FROM [PSI000] 
	WHERE [StartDate] >= @FromDate
	  AND [EndDate]   <= @ToDate
	GROUP BY [FormGuid]
)p 
INNER JOIN 
(
	SELECT ISNULL(FORMGUID,0x0) as FormGuid , co.Guid CostGuid , SUM(QTY) QTY 
	FROM [MN000] MN
	INNER JOIN fnGetCostsList(@CostGuid) co ON co.[Guid] = mn.[OutCostGUID]
	WHERE  [OutDate] >= @FromDate
	   AND [OutDate] <= @ToDate
	GROUP BY [FormGuid] ,co.Guid
) mn ON   mn.FormGuid = p.FormGuid
INNER JOIN co000 co ON co.[GUID] = mn.[CostGuid]

IF(@FormGuid <> 0x0)
	DELETE FROM #LIST WHERE FormGuid <> @FormGuid

INSERT INTO #LIST
SELECT DISTINCT
	   co.Guid CostGuid ,
	   CAST(co.[Number] as NVARCHAR(10)) + '            ' + co.Name CostName ,
	   0x0  ParentGuid  ,
	   0x0  FormGuid    ,
	   (SELECT SUM(PlanQty) FROM #LIST WHERE ParentGuid = Guid )  as PlanQty          ,
	   (SELECT SUM(ManQty)  FROM #LIST WHERE ParentGuid = Guid )  as ManQty           ,
	   (SELECT SUM(ManQty) - SUM(PlanQty) FROM #List WHERE ParentGuid = Guid ) as def,
	   0 UsePerc,
	   0 LostPerc
FROM #LIST lst
INNER JOIN co000 co ON co.Guid = lst.ParentGuid


UPDATE #LIST SET 
	UsePerc  =  (CASE PlanQty WHEN 0 THEN 0 ELSE ((ManQty     / PlanQty)) * 100	END), 
	LostPerc =  (CASE PlanQty WHEN 0 THEN 0 ELSE (1 - (ManQty / PlanQty)) * 100 END)
FROM #LIST
WHERE PARENTGUID = 0x0


INSERT INTO #RESULT
SELECT  DISTINCT
		res.CostGuid As CostGuid,
		CAST (res.AccountName as NVARCHAR(100)) as AccountName,
		'IDS_VARIATION' AS [TYPE],	
		SUM(res.VALUE) AS VALUE
FROM #RESULT res
GROUP BY res.CostGuid , res.AccountName

SELECT 
		lst.CostName CostName,
		res.AccountName AS AccountName,
		CAST(0 AS FLOAT) AS Balance ,
		CAST(0 AS FLOAT) AS LostPerc,
		CAST(0 AS FLOAT) AS LowProductionVar,
		res.value AS Variation
INTO #FinalResult
FROM #LIST lst 
INNER JOIN #Result res ON lst.CostGuid = res.CostGuid 
WHERE res.Type = 'IDS_VARIATION'
UNION
SELECT lst.CostName CostName,
		res.AccountName AS AccountName,
		CAST(0 AS FLOAT) AS Balance ,
		LostPerc AS LostPerc,
		CAST(0 AS FLOAT) AS LowProductionVar,
		CAST(0 AS FLOAT) AS Variation
FROM #LIST lst
INNER JOIN #Result res ON lst.CostGuid = res.CostGuid 
WHERE res.Type = 'IDS_VARIATION'
UNION
SELECT lst.CostName CostName,
		res.AccountName AS AccountName,
		CAST(0 AS FLOAT) AS Balance ,
		CAST(0 AS FLOAT) AS LostPerc,
		(LostPerc / 100) * res.Value AS LowProductionVar,
		CAST(0 AS FLOAT) AS Variation
FROM #LIST lst 
INNER JOIN #Result res ON lst.CostGuid = res.CostGuid 
WHERE res.Type = 'IDS_VARIATION'
UNION
SELECT lst.CostName CostName,
		res.AccountName AS AccountName,
		((100 - LostPerc) / 100) * res.Value AS Balance ,
		CAST(0 AS FLOAT) AS LostPerc,
		CAST(0 AS FLOAT) AS LowProductionVar,
		CAST(0 AS FLOAT) AS Variation
FROM #LIST lst 
INNER JOIN #Result res ON lst.CostGuid = res.CostGuid 
WHERE res.Type = 'IDS_VARIATION'


SELECT CostName, AccountName, SUM(Balance) Balance, SUM(LostPerc) LostPerc, SUM(LowProductionVar) LowProductionVar, SUM(Variation) Variation FROM #FinalResult
GROUP BY CostName, AccountName
###########################################################
#END
