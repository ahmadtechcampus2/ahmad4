###########################################################################
create proc prcRaisError
	@type [int] = 0,
	@msgid [nvarchar](255) = '',
	@rollback [bit] = 0,
	@param1 [nvarchar](255) = '',
	@param2 [nvarchar](255) = '',
	@param3 [nvarchar](255) = ''
as

	-- raiserror only if flag 1000 is not set:
	if [dbo].[fnFlag_IsSet] (1000) = 0
		raiserror (@msgid, 16, 1, @param1, @param2, @param3)

	-- rollback transaction only if flag 1001 is not set, and a transaction is pending:
	if isnull(@rollback, 0) != 0 and @@trancount != 0
		rollback tran

###########################################################################
#END