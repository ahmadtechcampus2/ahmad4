######################################################################################
CREATE PROCEDURE GetBillindexOrder
  @Type nvarchar(250),@Reportname nvarchar(250)
AS 
select count(orderindex) CountN from BillNumberOrder000  where orderindex=0 and BillType=@Type and ReportName=@Reportname 
select GUID,orderindex as SortNum from BillNumberOrder000 where BillType=@Type and ReportName=@Reportname 
