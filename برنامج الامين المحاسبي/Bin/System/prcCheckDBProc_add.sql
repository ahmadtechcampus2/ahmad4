######################################################### 
create proc prcCheckDBProc_add
	@code [NVARCHAR](128),
	@name [NVARCHAR](128),
	@description [NVARCHAR](256),
	@latinName [NVARCHAR](128),
	@latinDescription [NVARCHAR](256),
	@procName [NVARCHAR](128) = '',
	@type [INT] = 0
as
/*
This procedure:
	- inserted a string into checkDBProc table.
	- if code already exists, the proc deletes and reinserts
*/

	-- select * from checkDBProc
	IF EXISTS(SELECT * FROM [checkDBProc] WHERE [code] = @code)
		-- delete current to insert new
		DELETE [checkDBProc] WHERE [code] = @code

	-- insert the new string:
	INSERT INTO [checkDBProc] ([code], [name], [description], [latinName], [latinDescription], [procName], [Type]) 
	VALUES (@code, @name, @description, @latinName, @latinDescription, @procName, @type)

#########################################################
#END