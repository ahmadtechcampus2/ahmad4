##############################################
create Function GetJustDate(@date DateTime)
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
CREATE   Function TrnIsNumberNegative
	( 
		@NumberIn  FLOAT, 
		@NumberOut FLOAT		 
	) 
RETURNS  FLOAT  
AS 
Begin 
DECLARE @RES FLOAT 
	if (@NumberIn < 0 ) 
		set @res =  @NumberOut 
	else 
		set @Res = @NumberIn 
return	@RES 
End 
##############################################
CREATE Function fnTrnIsAccUsedInCenterOrUserConfig
(@CenterGuid UNIQUEIDENTIFIER, @GroupAccGuid UNIQUEIDENTIFIER,@flag INT)
returns int
AS 
begin
	IF EXISTS( SELECT * FROM TrnCenter000 
				WHERE 
					GUID <> @CenterGuid 
					AND (@flag = 1 AND (ManagementCurrencyAccountGuid = @GroupAccGuid OR CurrencyAccountGuidCenter = @GroupAccGuid))
					OR  (@flag = 2 AND CurrencyAccountGuidCenter = @GroupAccGuid)
			) 
		return 1 
	if exists(select * from TrnUserConfig000 where GroupCurrencyAccGUID = @GroupAccGuid) 
		return 2

	return 0
end
##############################################
#END