##############################
create proc HosSetCurrentDate
as
	/*if not EXISTS  (select * from sysobjects where [id] = OBJECT_ID('hosCurrentDate000'))	
		create table hosCurrentDate000 (CurrentDate DateTime)
	else
		delete from hosCurrentDate000
	insert into hosCurrentDate000 values (getdate())*/
##############################
Create Function IsDate1900
	(
		@DateIn	DateTime,
		@DateOut DateTime		
	)
RETURNS  DateTime 
AS
Begin
DECLARE @RES DateTime
	if (@DateIn ='')
		set @res =  @DateOut
	else
		set @Res = @DateIn
return	@RES
End
#############################
Create Function IsDate2100
	(
		@DateIn	DateTime,
		@DateOut DateTime		
	)
RETURNS  DateTime 
AS
Begin
DECLARE @RES DateTime
	if (@DateIn ='2100')
		set @res =  @DateOut
	else
		set @Res = @DateIn
return	@RES
End
######################################################
#End