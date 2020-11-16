####################################################################################
CREATE function fnGetUserOrderMask( @UserNum INT, @Mask1 bigint, @Mask2 bigint, @Mask3 bigint, @Mask4 bigint)
	returns bigint
AS 
BEGIN
	RETURN 	( SELECT CASE  
		WHEN @UserNum between 1 and 63 THEN @Mask1
		WHEN @UserNum between 64 and 127 THEN @Mask2
		WHEN @UserNum between 128 and 191 THEN @Mask3
		WHEN @UserNum between 192 and 255 THEN @Mask4
		ELSE 0
		END)
END
####################################################################################
CREATE function fnGetUserMask( @UserNum INT)
	RETURNS BIGINT
AS 
BEGIN
	RETURN 	( SELECT CASE  
		WHEN @UserNum BETWEEN 1 and 63 THEN dbo.fnGetBranchMask( @UserNum)
		WHEN @UserNum between 64 and 127 THEN dbo.fnGetBranchMask( @UserNum - 63)
		WHEN @UserNum between 128 and 191 THEN dbo.fnGetBranchMask( @UserNum - 127)
		WHEN @UserNum between 192 and 255 THEN dbo.fnGetBranchMask( @UserNum - 191)
		ELSE 0
		END)
END
####################################################################################
CREATE function fnGetUserOrder_Mask ( @UserNum INT, @Mask1 bigint, @Mask2 bigint, @Mask3 bigint, @Mask4 bigint) 
	RETURNS BIGINT 
AS  
BEGIN 
	
	IF (@UserNum <= 63)
		RETURN @Mask1 & [dbo].[fnPowerOf2](@UserNum - 1)
	ELSE IF (@UserNum <= 126)
		RETURN @Mask2 & [dbo].[fnPowerOf2]( @UserNum - 64)
	ELSE IF (@UserNum <= 189)
		RETURN @Mask3 & [dbo].[fnPowerOf2]( @UserNum - 127)
	ELSE IF (@UserNum <= 252)
		RETURN @Mask4 &  [dbo].[fnPowerOf2]( @UserNum - 190)
	RETURN 0
	
END 
####################################################################################
#END