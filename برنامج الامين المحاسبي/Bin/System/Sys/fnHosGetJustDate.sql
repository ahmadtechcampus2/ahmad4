##############################################
create Function HosGetJustDate(@date DateTime)
	returns  DateTime
AS
Begin
	declare @string NVARCHAR(10)
	select @string = Cast(Month(@date) as NVARCHAR(2)) + '-' + 
			 Cast(Day  (@date) as NVARCHAR(2)) + '-' + cast(Year(@date) as char(4))
	return Cast (@string AS DateTime)
	--return Cast(CONVERT(CHAR(8), @date, 112) as DateTime)
end
##############################################
#END