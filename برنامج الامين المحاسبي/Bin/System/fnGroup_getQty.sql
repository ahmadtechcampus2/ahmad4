######################################################### 
create function fnGroup_getQty(
		@groupGuid [uniqueidentifier])
	returns [float]
as begin
/*
this function:
	- returns the total quantity of a given @groupGuid by accumulating posted bills qtys of descending material.
	- deals with core tables directly, ignoring branches and itemSecurity features.
*/

	declare @result [float]

	set @result = (	
			select sum([qty] * (2 *[bIsInput] - [bIsOutput]))
			from [bi000] [bi] 
				inner join [bu000] [bu] on [bi].[parentGuid] = [bu].[guid] 
				inner join [bt000] [bt] on [bu].[typeGuid] = [bt].[guid]
				inner join [fnGetMaterialsList](@groupGuid) [f] on [bi].[matGuid] = [f].[guid]
			where [bi].[matGuid] = @groupGuid)

	return isnull(@result, 0)
end

#########################################################
#end