############################################################################
CREATE PROCEDURE prcBillCopyCustomFields @OriginalTypeGuid UNIQUEIDENTIFIER 
, @OriginalGuid UNIQUEIDENTIFIER 
, @NewTypeGuid UNIQUEIDENTIFIER 
, @NewGuid UNIQUEIDENTIFIER 
AS
/*
AUTHER: Abdulkareem Attiya
This Procedure we can used it for all types of bills , Orders
we can copy bill custom fiels to another type (any bill type).
1- get for each record already saved in bill and exists in original type and Newtype of a new bill 
2- at least on field is mutual between the 2 types of bill.  
3- i create (prcCopyCustomFields) for all cards and operations.
*/
Set NOCOUNT ON
DECLARE @CFGuid uniqueidentifier
DECLARE @ISExist uniqueidentifier

DECLARE @MyCursor CURSOR
SET @MyCursor = CURSOR FAST_FORWARD
FOR
SELECT CFGuid  
FROM CFSelFlds000 
WHERE BTGuid = @NewTypeGuid AND Selected = 1

OPEN @MyCursor
FETCH NEXT FROM @MyCursor
INTO @CFGuid
DECLARE @fetch INT
SET @fetch = @@FETCH_STATUS
WHILE @fetch = 0
BEGIN
IF EXISTS( SELECT CFGuid  
		   FROM CFSelFlds000 
		   WHERE BTGuid = @OriginalTypeGuid 
	             AND Selected = 1 
	             AND CFGuid = @CFGuid
		 )
BEGIN
	EXEC dbo.prcCopyCustomFields @OriginalGuid, @NewGuid, 'bu000'
	SET @fetch = 1
END
ELSE
BEGIN 
FETCH NEXT FROM @MyCursor
INTO @CFGuid
SET @fetch = @@FETCH_STATUS
END
END
CLOSE @MyCursor
DEALLOCATE @MyCursor
--------------------------------
--for test
--select * from CFFlds000
--select * from CFGroup000 -- „Ã„Ê⁄… »ÿ«ﬁ… «·Õﬁ· «·„Œ’’…
--select * from CFMapping000 -- «·—»ÿ
/*
select * from bu000
select * from CFSelFlds000 
*/
--select * from CF_Value1 -- 
/*
delete from CF_Value1 where orginal_guid = '929A3ECD-75A1-4C6D-9B73-962AB56FB53D'
*/
--select * from bu000
############################################################################
#END

