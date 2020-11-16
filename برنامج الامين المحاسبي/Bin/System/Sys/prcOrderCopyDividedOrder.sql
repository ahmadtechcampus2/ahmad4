############################################################################
CREATE PROCEDURE prcOrderCopyDividedOrder @OriginalGuid UNIQUEIDENTIFIER
, @OriginalTypeGuid UNIQUEIDENTIFIER
, @NewGuid UNIQUEIDENTIFIER
, @NewTypeGuid UNIQUEIDENTIFIER 
AS
/*
AUTHER: Abdulkareem Attiya
This Procedure we can used it for all types of Orders for :
- Copy Order information page.
- Copy Order Document page.
- Copy Order Custom Fields page.
Last Edit in logic:
- Edit in Information Page. 
- No Copy of Document page.
- No Copy of Order Custom Fields page.
*/
SET NOCOUNT ON
--Information
exec dbo.prcOrderCopyOrderInfo @OriginalGuid ,@NewGuid , @NewTypeGuid 
--Documents
--exec dbo.prcOrderCopyDocuments @OriginalGuid, @OriginalTypeGuid , @NewGuid , @NewTypeGuid 
--CustomFields
--exec dbo.prcBillCopyCustomFields @OriginalTypeGuid , @OriginalGuid , @NewTypeGuid , @NewGuid 
-- Approvals
exec prcOrdersSaveNewOrderApprovals @NewGuid, @NewTypeGuid 

--for test 
/*
delete from ORADDINFO000 where parentguid = '85FF16FF-CADB-4E3A-BF96-EACD395F9402'
delete from docach000 where orderguid = '85FF16FF-CADB-4E3A-BF96-EACD395F9402'
delete from CF_Value1 where orginal_guid = '85FF16FF-CADB-4E3A-BF96-EACD395F9402'

select * from bu000 where typeguid in(  'F697D711-2D93-4D2E-A78D-CCBA62312E44' , '5412CC66-2DAE-41D0-82ED-67B81E4D7B40')
select * from bt000 where type = 5

DECLARE @OriginalGuid UNIQUEIDENTIFIER = '887E98C8-D762-43E7-9A73-8AC66B7EA406'
DECLARE @OriginalTypeGuid UNIQUEIDENTIFIER = '5412CC66-2DAE-41D0-82ED-67B81E4D7B40'
DECLARE @NewGuid UNIQUEIDENTIFIER = '85FF16FF-CADB-4E3A-BF96-EACD395F9402'
DECLARE @NewTypeGuid UNIQUEIDENTIFIER = 'F697D711-2D93-4D2E-A78D-CCBA62312E44' -- '929A3ECD-75A1-4C6D-9B73-962AB56FB53D'

exec prcOrderCopyDividedOrder @OriginalGuid 
, @OriginalTypeGuid 
, @NewGuid 
, @NewTypeGuid  
*/
############################################################################
#END

