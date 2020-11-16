################################################################################
CREATE PROCEDURE prcAuditAllocationEntries
	@AllotmentGuid UNIQUEIDENTIFIER,
	@Date DATETIME
AS
	
	SET NOCOUNT ON
	
	DECLARE 
		@totalCount INT,
		@deletedCount INT
		
	DECLARE @toDelete TABLE(AllocationGuid UNIQUEIDENTIFIER)
	
	SET @totalCount = (SELECT COUNT(DISTINCT BondGuid) FROM AllocationEntries000 ae 
	INNER JOIN Allocations000 ao ON ae.AllocationGuid = ao.[GUID] 
	WHERE ao.AllotmentGuid = @AllotmentGuid
	AND ae.date <= @Date)
	SET @deletedCount = 
		(SELECT 
			COUNT(DISTINCT BondGuid) 
		FROM 
			AllocationEntries000 ae 
			INNER JOIN Allocations000 ao ON ae.AllocationGuid = ao.[GUID] 
		WHERE 
			ao.AllotmentGuid = @AllotmentGuid
			AND  ae.Date <= @Date AND
			NOT EXISTS(SELECT * FROM ce000 WHERE GUID = ae.BondGuid))
	
	DELETE ae
	FROM 
		AllocationEntries000 ae 
		INNER JOIN Allocations000 ao ON ae.AllocationGuid = ao.[GUID] 
	WHERE 
		ao.AllotmentGuid = @AllotmentGuid
		AND  ae.Date <= @Date
		AND
		NOT EXISTS(SELECT * FROM ce000 WHERE GUID = ae.BondGuid)
		
	UPDATE ao
	Set EntryGenrated = 0
	FROM Allocations000 ao
	WHERE
		AllotmentGuid = @AllotmentGuid
		AND 
		NOT EXISTS(SELECT * FROM AllocationEntries000 WHERE ao.Guid = AllocationGuid)
	select @totalCount AS totalCount, @deletedCount AS deletedCount
################################################################################
CREATE procedure AuditAllocEntry
@alltomentguid UNIQUEIDENTIFIER,
@AuditDate DATETIME

AS
SET NOCOUNT ON

SET @AuditDate =  DATEADD(s ,-1 ,DATEADD(mm , DATEDIFF(m ,0 ,@AuditDate) + 1 ,0))

CREATE TABLE #result (allotmentGuid UNIQUEIDENTIFIER, allocationGuid UNIQUEIDENTIFIER, accountguid UNIQUEIDENTIFIER, counteraccguid UNIQUEIDENTIFIER, missdate DATETIME, countOfGenEntry INT, canEdit INT)
DECLARE @checkDate DATETIME
SET @checkDate = [dbo].[fnDate_Amn2Sql]([dbo].[fnOption_get]('AmnCfg_FPDate', default)) 
INSERT INTO #result( allocationGuid, accountguid, counteraccguid, missdate, countOfGenEntry, canEdit)  -- ›Ì Õ«· ÊÃÊœ ﬁÌÊœ „Õ–Ê›… ·Â–Â «·»ÿ«ﬁ…
		SELECT  allocationGuid, ae.accountguid, ae.counteraccountguid, date
		,COUNT(ae.date) OVER (PARTITION BY ae.AllocationGuid )AS countOfGenEntry
		, 1 
        FROM AllocationEntries000 ae 
		WHERE BondGuid in 
						(
						SELECT DISTINCT BondGuid 
						FROM 
						AllocationEntries000 ae 
						INNER JOIN Allocations000 ao ON ae.AllocationGuid = ao.[GUID] 
						WHERE 
						ao.AllotmentGuid = @alltomentguid
						AND ae.Date BETWEEN @checkDate AND @AuditDate
						AND
						NOT EXISTS(SELECT guid FROM ce000 WHERE GUID = ae.BondGuid)
						)
						AND ae.Date BETWEEN @checkDate AND @AuditDate
						
-----------------------------------------
--›Ì Õ«· ÊÃÊœ œ›⁄«  „Õ–Ê›… „‰ «·”‰œ ·Â–Â «·»ÿ«ﬁ…
INSERT INTO #result (allocationGuid, accountguid, counteraccguid, missdate, countOfGenEntry, canEdit)
SELECT  ae.allocationGuid, ae.AccountGuid, ae.CounterAccountGuid, ae.date
, COUNT(ae.date) OVER (PARTITION BY ae.allocationGuid)AS countOfGenEntry, 0
FROM  Allocations000 a inner join Allotment000 al on al.guid= a.AllotmentGuid
inner join  AllocationEntries000  ae on ae.AllocationGuid = a.guid
inner join ce000 ce on ae.BondGuid = ce.guid
WHERE (a.allotmentguid= @alltomentguid
AND ae.Date BETWEEN @checkDate AND @AuditDate
	)
and not exists
(SELECT accountguid, contraaccguid
				FROM ce000 ce inner join en000 en on ce.guid = en.parentguid AND ce.guid = ae.BondGuid
WHERE 
	en.AccountGUID = ae.AccountGuid
	AND en.ContraAccGUID = ae.CounterAccountGuid
    and en.debit=0
)


select Distinct allocationGuid, accountguid, counteraccguid, missdate into #DelEntry from #result

----------------------------------------------------------
CREATE TABLE #t2 (allocationguid UNIQUEIDENTIFIER, countOfGenEntry INT, allotmentguid UNIQUEIDENTIFIER, AccountGuid UNIQUEIDENTIFIER, CounterAccountGuid UNIQUEIDENTIFIER,StartDistDate DATETIME,  cnDelPay int )
	  
INSERT INTO #t2
	SELECT  DISTINCT ae.allocationguid
	    ,( SELECT distinct COUNT(ae1.date) OVER (PARTITION BY ae1.AllocationGuid)AS countOfGenEntry  
	FROM  AllocationEntries000 ae1
		inner join Allocations000 a1 on a1.guid = ae1.AllocationGuid 
		inner join Allotment000 al1 on al1.guid = a1.AllotmentGuid  
	WHERE al1.Guid= @alltomentguid
	    AND a1.guid = ae1.allocationguid 
		and a1.guid = a.guid
		 group by ae1.allocationGuid, ae1.date), 
	    al.guid as allotmentguid,
		ae.AccountGuid AccountGuid,
		ae.CounterAccountGuid CounterAccountGuid,
		a.FromMonth StartDistDate
		,count(res.missdate)  OVER (PARTITION by res.allocationGuid) as cntofdel 
		 
	FROM  AllocationEntries000 ae
		inner join Allocations000 a on a.guid = ae.AllocationGuid 
		inner join Allotment000 al on al.guid = a.AllotmentGuid  
		inner join #DelEntry res on a.guid= res.allocationguid  --and missdate <> date 
	WHERE al.Guid= @alltomentguid
	    AND a.guid = ae.allocationguid	
	GROUP BY ae.allocationguid, al.guid, res.allocationGuid, a.guid--,ae.date
	, res.missdate,	ae.accountguid, ae.CounterAccountGuid, a.FromMonth--, res.accountguid, res.counteraccguid
  DECLARE @canEdit INT = 0
  DECLARE @countDelPay INT
  DECLARE @countOfGenPay INT
  DECLARE @allocguid uniqueidentifier
  DECLARE checkDElCursor CURSOR FAST_FORWARD
FOR	SELECT	
			allocationguid,
			countOfGenEntry,
			cnDelPay
		FROM #t2 
OPEN checkDElCursor
	FETCH NEXT 
	FROM checkDElCursor
	INTO  @allocguid, @countOfGenPay, @countDelPay
	WHILE @@FETCH_STATUS = 0
	BEGIN 
		if(@countDelPay = @countOfGenPay)
		BEGIN
		 UPDATE #result SET canEdit = 1 WHERE allocationGuid =  @allocguid 
		END			
		FETCH NEXT FROM checkDElCursor 
	    INTO @allocguid, @countOfGenPay, @countDelPay
	    
     END 
CLOSE checkDElCursor 
DEALLOCATE checkDElCursor
----------------------------------------
-- «—ÌŒ »œ¡ «· Ê“Ì⁄ Ê‰Â«Ì Â  Ê  «—ÌŒ ¬Œ— ”‰œ „Ê·œ Ê⁄œœ «·”‰œ«  «·„Ê·œ… ·ﬂ· ﬁ·„
CREATE TABLE #t1 (allocationguid UNIQUEIDENTIFIER,  allotmentguid UNIQUEIDENTIFIER,accountguid UNIQUEIDENTIFIER,  counteraccguid UNIQUEIDENTIFIER,  StartDistDate DATETIME,EndDistDate DATETIME)
INSERT INTO #t1
	SELECT  DISTINCT a.guid,
	    al.guid as allotmentguid,
		accountguid,
		counteraccountguid,
		a.FromMonth StartDistDate,
		a.ToMonth EndDistDate
	FROM  
		 Allocations000 a 
		inner join Allotment000 al on al.guid = a.AllotmentGuid
		WHERE al.Guid= @alltomentguid
	  --  AND a.guid = ae.allocationguid
		--AND ae.Date BETWEEN @checkDate AND @AuditDate
	GROUP BY al.guid, a.guid, accountguid, counteraccountguid, a.FromMonth, a.ToMonth
	
-----------------------------------------------------------------

DECLARE @count DATETIME
DECLARE @lastEntryDate DATETIME
DECLARE @StartDistDate DATETIME
DECLARE @EndDistDate DATETIME
DECLARE @allocationguid uniqueidentifier
DECLARE @allotmentguid  uniqueidentifier
DECLARE @accountguid uniqueidentifier
DECLARE @counteraccguid uniqueidentifier
DECLARE @startmonth  int
DECLARE @countOfDelPay int
DECLARE @countOfGenEntry int
DECLARE @countOfGeneEntry int
----------------------------- -----------	

DECLARE checkCursor CURSOR FAST_FORWARD
FOR	SELECT	t1.allotmentguid,
            t1.allocationguid,
		    t1.accountguid,
			 t1.counteraccguid,
	         t1.StartDistDate,
		    EndDistDate			
		FROM #t1 t1 
OPEN checkCursor
	FETCH NEXT 
	FROM checkCursor
	INTO @allotmentguid, @allocationguid, @accountguid, @counteraccguid, @StartDistDate, @EndDistDate
	WHILE @@FETCH_STATUS = 0
	BEGIN   
			UPDATE #result SET countOfGenEntry = @countOfGeneEntry where allocationguid = @allocationguid
			
			IF(@StartDistDate < @checkDate)--„‰ «Ã· «·Õ”«»«  «·„œÊ—…
			BEGIN
			  SET @StartDistDate = @checkDate
			END
			SET @count = @StartDistDate
			IF(@EndDistDate < @AuditDate)
			BEGIN
			 SET @AuditDate = @EndDistDate
			END
			WHILE @count <= @AuditDate
			BEGIN  --›Õ’ «–« Â‰«ﬂ ﬁÌÊœ ·Ì”  „Ê·œ… Œ·«· › —… «· Ê“Ì⁄
				if (month(@count) not in (SELECT  month(date) 
				FROM  AllocationEntries000 ae
					inner join Allocations000 a on a.guid = ae.AllocationGuid
					inner join Allotment000 al on al.guid = a.AllotmentGuid
					WHERE al.Guid= @alltomentguid
					and a.GUID= @allocationguid
				    and YEAR(@count) = YEAR(date)
				GROUP BY allocationguid, ae.accountguid, ae.CounterAccountGuid, date
				) ) 
							
					BEGIN
						INSERT INTO #result(allocationGuid, accountguid,counteraccguid, missdate, countOfGenEntry, canEdit) 
							VALUES(@allocationguid, @accountguid, @counteraccguid, @count, @countOfGeneEntry, 0)
							
					END
					SET @count = DATEADD(m, 1, @count)
			END
			
		FETCH NEXT FROM checkCursor 
	    INTO @allotmentguid, @allocationguid, @accountguid, @counteraccguid, @StartDistDate, @EndDistDate
	    
END 
CLOSE checkCursor 
DEALLOCATE checkCursor

	--------------------------------
CREATE TABLE #medRes (countOfDelPay INT , allocationguid UNIQUEIDENTIFIER, accountguid UNIQUEIDENTIFIER, counteraccguid UNIQUEIDENTIFIER, countOfGenEntry INT, missdate DATETIME, canEdit INT)
insert into #medRes (countOfDelPay, allocationguid, accountguid, counteraccguid, countOfGenEntry, missdate, canEdit)
        SELECT   COUNT(*) OVER (PARTITION BY accountguid, counteraccguid)AS countOfDelPay,
		allocationguid, accountguid, counteraccguid, countOfGenEntry, missdate, MAX(canEdit)
		FROM #result 
		--where missdate < @AuditDate
		GROUP BY  allocationguid, accountguid, counteraccguid, missdate, countOfGenEntry, canEdit
		
--------------------------------
		CREATE TABLE #endResult (countOfDeletedPay INT,countOfGeneratedEntry INT, allocationguid UNIQUEIDENTIFIER, accountguid UNIQUEIDENTIFIER, counteraccguid UNIQUEIDENTIFIER, canEdit INT)
	INSERT INTO #endResult
			SELECT  DISTINCT countOfDelPay,
			 Max(countOfGenEntry)OVER (PARTITION BY accountguid, counteraccguid)AS countOfGenEntry ,
			allocationguid, accountguid, counteraccguid, MAX(canEdit)
			 FROM #medRes 
			 group by allocationguid, accountguid, counteraccguid, countOfDelPay, countOfGenEntry--, canEdit

			SELECT * FROM #endResult
################################################################################				  
#END