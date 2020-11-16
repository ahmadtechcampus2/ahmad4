############################################################################
CREATE PROCEDURE prcOrderCopyDocuments @OriginalGuid UNIQUEIDENTIFIER
	, @OriginalTypeGuid UNIQUEIDENTIFIER
	, @NewGuid UNIQUEIDENTIFIER
	, @NewTypeGuid UNIQUEIDENTIFIER

AS
/*
AUTHER: Abdulkareem Attiya
This Procedure we can used it for all types of Orders for :
- Copy Order Document page.
AS 
1- get for each record already saved in original order and exists in original type and Newtype of a new order 
*/
SET NOCOUNT ON

INSERT INTO docach000
SELECT DISTINCT NEWID()
	, @NewTypeGuid
	, @NewGuid
	, docach.DocGuid
	, docach.Achieved
	, docach.Path
FROM docach000 docach
INNER JOIN ordoc000 ordoc ON docach.DocGuid = ordoc.Guid
INNER JOIN ordocvs000 Original_ordocvs ON ordoc.Guid = Original_ordocvs.DocGuid
	AND Original_ordocvs.TypeGuid = docach.TypeGuid
INNER JOIN ordocvs000 New_ordocvs ON New_ordocvs.DocGuid = Original_ordocvs.DocGuid
	AND New_ordocvs.TypeGuid = @NewTypeGuid
	AND New_ordocvs.Selected = 1
WHERE docach.OrderGuid = @OriginalGuid
ORDER BY DocGuid
-------------------------------------
--For Test 
/*
select * from bu000
delete from docach000 where orderguid = '85FF16FF-CADB-4E3A-BF96-EACD395F9402'
SELECT * FROM docach000
SELECT * FROM ordoc000
SELECT * FROM ordocvs000
*/
############################################################################
#END

