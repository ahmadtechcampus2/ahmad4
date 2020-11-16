#########################################################
create function fnColumnsToBitMask(@table [NVARCHAR](128), @excludedColumns [NVARCHAR](2000))
	returns [varbinary](128)
as begin
/* 
This function: 
	- returns a bitmask representing columns of @table after excluding @excludedColumns in Big-Indian format.
	- is usualy used in conjuction with COLUMNS_UPDATED() inside triggers.
*/ 
	declare 
		@t_excludedColumns table([name] [NVARCHAR](128)) 

	declare
		@c cursor, 
		@colName [NVARCHAR](128), 
		@colid [int],
		@byte [tinyint],
		@bit [tinyint],
		@bitmask [varbinary](128),
		@tableID [int]

	-- get the @excludedColumns: 
	insert into @t_excludedColumns select ltrim(rtrim(cast([data] as [NVARCHAR](128)))) from [fnTextToRows](@excludedColumns) 

	set @bitmask = 0x0
	set @byte = 0
	set @bit = 0
	set @tableID = object_id(@table)

	-- prepare the cursor: 
	set @c = cursor fast_forward for select [name], [colid] from [syscolumns] where [id] = @tableID order by [colid]

	open @c fetch from @c into @colName, @colid
	while @@fetch_status = 0 
	begin 
		if ((@colid - 1) % 8 = 0 and @colid != 1) or @bit > 7 -- its a new byte:
		begin
			set @bitmask = @bitmask + cast(@byte as [varbinary](1))
			set @byte = 0
			set @bit = 0
		end

		if not exists(select * from @t_excludedColumns where [name] = @colName)
			set @byte = @byte + power(2, @bit)

		set @bit = @bit + 1

		fetch from @c into @colName, @colid

		if @@fetch_status <> 0 and @byte <> 0
			set @bitmask = @bitmask + cast(@byte as [varbinary](1))

	end 

	close @c deallocate @c 

	-- return the result: 
	return @bitmask
end

#########################################################
#END