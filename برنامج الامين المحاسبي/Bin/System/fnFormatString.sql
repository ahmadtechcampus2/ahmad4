#########################################################
CREATE function fnFormatString(
		@string [nvarchar](max),  
		@param0 [NVARCHAR](2000) = null, 
		@param1 [NVARCHAR](2000) = null, 
		@param2 [NVARCHAR](2000) = null, 
		@param3 [NVARCHAR](2000) = null, 
		@param4 [NVARCHAR](2000) = null, 
		@param5 [NVARCHAR](2000) = null, 
		@param6 [NVARCHAR](2000) = null,
		@param7 [NVARCHAR](2000) = null, 
		@param8 [NVARCHAR](2000) = null,
		@param9 [NVARCHAR](2000) = null)

	returns [NVARCHAR](max) 
as begin 
/* 
this function: 
	- returns @string after swaping @paramX from it, if any 
*/ 
	if @param0 is not null 
		set @string = replace(@string, '%0', @param0) 
	if @param1 is not null 
		set @string = replace(@string, '%1', @param1) 
	if @param2 is not null 
		set @string = replace(@string, '%2', @param2) 
	if @param3 is not null 
		set @string = replace(@string, '%3', @param3) 
	if @param4 is not null 
		set @string = replace(@string, '%4', @param4) 
	if @param5 is not null 
		set @string = replace(@string, '%5', @param5) 
	if @param6 is not null 
		set @string = replace(@string, '%6', @param6) 
	if @param7 is not null 
		set @string = replace(@string, '%7', @param7) 
	if @param8 is not null 
		set @string = replace(@string, '%8', @param8) 
	if @param9 is not null 
		set @string = replace(@string, '%9', @param9) 

	return @string -- ltrim(rtrim(@string)) 

end 

#########################################################
#END