#########################################################
create proc prcServer_listDir
	@path [NVARCHAR](255) = null,
	@showFiles [bit] = 0
as
/*
This procedure:
	- lists drive names only if @path is null.
	- lists directories only if @showFiles was 0.
	- returns dir of given @path.
	- acts on servers' hardware only, DRIVES AND PATHES ARE RELATIVE TO THE SQL-SERVER
*/

	create table [#directories]([name] [NVARCHAR](260) COLLATE ARABIC_CI_AI)
	create table [#files]([name] [NVARCHAR](260) COLLATE ARABIC_CI_AI)

	declare @t table([name] [NVARCHAR](260) COLLATE ARABIC_CI_AI, [isDirectory] [bit], [ord] [int] identity (1, 1))

	if @path is null
	begin
		create table [#dum] ([dum] [NVARCHAR](260) COLLATE ARABIC_CI_AI )
		
		declare
			@drive [nchar](1),
			@sql [NVARCHAR](300)
		
		set @drive = 'A'
		
		while 1=1
		begin
			set @sql = 'dir ' + @drive + ':\ /b'
			insert into [#dum] exec [master]..[xp_cmdshell] @sql
			if @@rowcount > 2
				insert into [#directories] select @drive + ':'
		
			set @drive = char(ascii(@drive) + 1)
		
			if @drive >= 'Z'
				break
		end

		drop table [#dum]

	end else begin
		set @sql = 'dir ' + @path + ' /b /ad /on'
		insert into [#directories] exec [master]..[xp_cmdshell] @sql

		if @showFiles != 0
		begin
			set @sql = 'dir ' + @path + ' /b /a-d /on'
			insert into [#files] exec [master]..[xp_cmdshell] @sql
		end
	end

	insert into @t select [name], 1 as [isDirectory] from [#directories]
	insert into @t select [name], 0 from [#files]

	delete @t where [name] is null

	select [name], [isDirectory] from @t order by [ord]
	
	drop table [#directories]
	drop table [#files]
 
#########################################################
#end