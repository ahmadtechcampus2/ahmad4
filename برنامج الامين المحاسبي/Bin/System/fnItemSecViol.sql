#########################################################
create function fnItemSecViol (@accountGuid [uniqueidentifier] = 0x0, @matGuid [uniqueidentifier] = 0x0, @storeGuid [uniqueidentifier] = 0x0, @costGuid [uniqueidentifier] = 0x0)
	returns [bit]
as begin
	declare
		@userGuid [uniqueidentifier],
		@result [bit]
	set @userGuid = [dbo].[fnGetCurrentUserGuid]()
	-- account browse sec viol:
	if isNull(@accountGuid, 0x0) != 0x0 and(( [dbo].[fnGetUserAccountSec_Browse](@userGuid) < (select [security] from [ac000] where [guid] = @accountGuid)) or(NOT EXISTS( SELECT * FROM vwAc WHERE acGUID = @accountGuid)))
		set @result = 1
	-- material browse sec viol:
	else if isNull(@matGuid, 0x0) != 0x0 and(( [dbo].[fnGetUserMaterialSec_Browse](@userGuid) < (select [security] from [mt000] where [guid] = @matGuid)) or(NOT EXISTS( SELECT * FROM vwMt WHERE mtGUID = @matGuid)))
		set @result = 1
	-- store browse sec viol:
	else if isNull(@storeGuid , 0x0) != 0x0 and(( [dbo].[fnGetUserStoreSec_browse](@userGuid) < (select [security] from [st000] where [guid] = @storeGuid)) or(NOT EXISTS( SELECT * FROM vwSt WHERE stGUID = @storeGuid)))
		set @result = 1
	-- cost browse sec viol:
	else if isNull(@costGuid , 0x0) != 0x0 and(( [dbo].[fnGetUserCostSec_browse](@userGuid) < (select [security] from [co000] where [guid] = @costGuid)) or(NOT EXISTS( SELECT * FROM vwCo WHERE coGUID = @costGuid)))
		set @result = 1
	else
		set @result = [dbo].[fnItemSecViolEx](@userGuid, @accountGuid, @matGuid, @storeGuid, @costGuid)
	return @result
end

#########################################################
#end
