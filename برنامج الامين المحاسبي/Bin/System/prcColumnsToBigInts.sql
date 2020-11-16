######################################################### 
CREATE proc prcColumnsToBigInts 
	@tableName [NVARCHAR](128), 
	@excludedColumns [NVARCHAR](128) = '', 
	@mask1 [bigint] output, 
	@mask2 [bigint] output, 
	@mask3 [bigint] output,
	@mask4 [bigint] output, 
	@mask5 [bigint] output, 
	@mask6 [bigint] output, 
	@mask7 [bigint] output,
	@mask8 [bigint] output, 
	@mask9 [bigint] output,  
	@mask10 [bigint] output
as 

	declare  
		@t_excludedColumns table([name] [NVARCHAR](128) collate arabic_ci_ai)  
	insert into @t_excludedColumns 
	select ltrim(rtrim(cast([data] as [NVARCHAR](128)))) from [fnTextToRows](@excludedColumns)

	set @mask1 = 0
	set @mask2 = 0
	set @mask3 = 0
	set @mask4 = 0
	set @mask5 = 0
	set @mask6 = 0
	set @mask7 = 0
	set @mask8 = 0
	set @mask9 = 0
	set @mask10 = 0



	declare
		@c cursor,  
		@colName [NVARCHAR](128),  
		@colid [int], 
		@byte [tinyint], 
		@bit [tinyint], 
		@bitmask [varbinary](128), 
		@tableID [int] 

	declare @sql NVARCHAR(1250)

	set @bitmask = 0x0
	set @byte = 0 
	set @bit = 0 
	set @tableID = object_id(@tableName) 
	-- prepare the cursor:  
	set @c = cursor fast_forward for 
		select [name], [colid] from [syscolumns] 
		where ([id] = @tableID) and (([name] collate arabic_ci_ai) in (select [name] from @t_excludedColumns))
		order by [colid] 
	open @c fetch from @c into @colName, @colid 
	while @@fetch_status = 0  
	begin  
		if @colid <= 8
			set @mask1 = @mask1 + power(2, @colid - 1) 
		else if @colid <= 16
			set @mask2 = @mask2 + power(2, (@colid - 1) - 8) 
		else if @colid <= 24
			set @mask3 = @mask3 + power(2, (@colid - 1) - 16) 
		else if @colid <= 32
			set @mask4 = @mask4 + power(2, (@colid - 1) - 24) 
		else if @colid <= 40
			set @mask5 = @mask5 + power(2, (@colid - 1) - 32) 
		else if @colid <= 48
			set @mask6 = @mask6 + power(2, (@colid - 1) - 40) 
		else if @colid <= 56
			set @mask7 = @mask7 + power(2, (@colid - 1) - 48) 
		else if @colid <= 64
			set @mask8 = @mask8 + power(2, (@colid - 1) - 56) 
		else if @colid <= 72
			set @mask9 = @mask9 + power(2, (@colid - 1) - 64) 
		else if @colid <= 80
			set @mask10 = @mask10 + power(2, (@colid - 1) - 72) 

		fetch from @c into @colName, @colid 
	end  
	close @c deallocate @c  

#########################################################
#END
