######################################################### 
create function fnMaterial_getQty(
		@matGuid [UNIQUEIDENTIFIER])
	returns [float]
as begin
/*
this function:
	- returns the total quantity of a given @matGuid by accumulating posted bills
	- deals with core tables directly, ignoring branches and itemSecurity features.
*/

	declare @result [float]

	set @result = (	
			select sum([qty] * (2 * [bIsInput]-[bIsOutput]))
			from [bi000] [bi] inner join [bu000] [bu] on [bi].[parentGuid] = [bu].[guid] inner join [bt000] [bt] on [bu].[typeGuid] = [bt].[guid]
			where [bi].[matGuid] = @matGuid and [bu].[isPosted] = 1)

	return isnull(@result, 0.0)
end

#########################################################
#end