#########################################################
create function fnItemSecViolEx (@userGuid [uniqueidentifier] = 0x0, @accountGuid [uniqueidentifier] = 0x0, @matGuid [uniqueidentifier] = 0x0, @storeGuid [uniqueidentifier] = 0x0, @costGuid [uniqueidentifier] = 0x0)
	returns [bit]
as begin
	-- this will be enabled for Extended Item Security System
	return 0
/*
	declare @result bit

	if isnull(@userGuid, 0x0) = 0x0
		set @userGuid = dbo.fnGetCurrentUserGuid()

	-- account browse sec viol:
	if isnull(@accountGuid, 0x0) != 0x0 and not exists(select * from is000 where userGuid = @userGuid and objGuid = @accountGuid)
		set @result = 1

	-- material browse sec viol:
	else if isnull(@matGuid, 0x0) != 0x0 and not exists(select * from is000 where userGuid = @userGuid and objGuid = @matGuid)
		set @result = 1

	-- store browse sec viol:
	else if isnull(@storeGuid , 0x0) != 0x0 and not exists(select * from is000 where userGuid = @userGuid and objGuid = @storeGuid)
		set @result = 1

	-- cost browse sec viol:
	else if isnull(@costGuid , 0x0) != 0x0 and not exists(select * from is000 where userGuid = @userGuid and objGuid = @costGuid)
		set @result = 1

	else
		set @result = 0

	return @result
*/
end

#########################################################
#end