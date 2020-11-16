##########################################################################################
CREATE PROC prcItemSecurityExtended_InstallTable
	@TableName [NVARCHAR](128),
	@ParentFldName [NVARCHAR](128)
AS

	-- add a trigger to insert and delete data in related Table

	EXEC [prcExecuteSQL] 'insert into [isx000]( [ObjGuid], [Type], [Mask1], [Mask2], [Mask3], [Mask4]) SELECT [i].[guid], 0, 0, 0, 0, 0 FROM  [%0] [i] where [Guid] not in ( select [ObjGuid] from [isx000])', @TableName
	EXEC [prcExecuteSQL] '
	DECLARE @AdmMask1 BIGINT, @AdmMask2 BIGINT, @AdmMask3 BIGINT, @AdmMask4 BIGINT
	SELECT	
		@AdmMask1 = SUM( CASE WHEN  [u].[Number] between 1 and 63 THEN [dbo].[fnPowerOf2]([u].[Number] - 1)  ELSE 0 END),
		@AdmMask2 = SUM( CASE WHEN  [u].[Number] between 64 and 126 THEN dbo.[fnPowerOf2]( [u].[Number] - 64) ELSE 0 END),
		@AdmMask3 = SUM( CASE WHEN  [u].[Number] between 127 and 189 THEN dbo.[fnPowerOf2]( [u].[Number] - 127) ELSE 0 END),
		@AdmMask4 = SUM( CASE WHEN  [u].[Number] between 190 and 252 THEN dbo.[fnPowerOf2]( [u].[Number] - 190) ELSE 0 END)
	FROM
		[us000] [u]
	WHERE
		[u].[bAdmin] = 1 and [Type] = 0

	update [iss] set
		[Mask1] = [iss].[Mask1] | @AdmMask1,
		[Mask2] = [iss].[Mask2] | @AdmMask2, 
		[Mask3] = [iss].[Mask3] | @AdmMask3,
		[Mask4] = [iss].[Mask4] | @AdmMask4
	from
		[isx000] [iss]'

	EXEC [prcExecuteSQL] '
	CREATE TRIGGER [dbo].[trg_%0_ise] -- insert and delete related bl primary data 
		ON [%0] FOR INSERT, DELETE
		NOT FOR REPLICATION
	AS 

	IF @@ROWCOUNT = 0
		RETURN

	SET NOCOUNT ON 
	
	delete [i] 
	FROM 
		[isx000] [i] 
		INNER JOIN [deleted] [d] ON [i].[objGuid] = [d].[guid]
		left JOIN [inserted] [ins] ON [ins].[Guid] = [d].[guid]
	where 
		[ins].[Guid] is null
	
	if( @@rowcount != 0)
		return

	insert into [isx000] ( [ObjGuid], [Type], [Mask1], [Mask2], [Mask3], [Mask4])
		SELECT  [ins].[guid], 3, [i].[Mask1], [i].[Mask2], [i].[Mask3], [i].[Mask4]
		FROM
			[inserted] [ins] 
			inner join [isx000] [i] on [i].[objGuid] = [ins].[%1]

	if( @@rowcount != 0)
		return

	DECLARE @AdmMask1 BIGINT, @AdmMask2 BIGINT, @AdmMask3 BIGINT, @AdmMask4 BIGINT

	SELECT
		@AdmMask1 = SUM( CASE WHEN [u].[Number] between 1  and 63   THEN  [dbo].[fnPowerOf2]([u].[Number] - 1) ELSE 0 END),
		@AdmMask2 = SUM( CASE WHEN [u].[Number] between 64 and 126  THEN dbo.[fnPowerOf2]( [u].[Number] - 64) ELSE 0 END),
		@AdmMask3 = SUM( CASE WHEN [u].[Number] between 127 and 189  THEN dbo.[fnPowerOf2]( [u].[Number] - 127) ELSE 0 END),
		@AdmMask4 = SUM( CASE WHEN [u].[Number] between 190 and 252  THEN dbo.[fnPowerOf2]( [u].[Number] - 190) ELSE 0 END)
	FROM
		[us000] [u]
	WHERE
		[u].[bAdmin] = 1 and [Type] = 0

	insert into [isx000]( [ObjGuid], [Type], [Mask1], [Mask2], [Mask3], [Mask4])
		SELECT  [ins].[guid], 3, @AdmMask1, @AdmMask2, @AdmMask3, @AdmMask4
		FROM
			[inserted] [ins] 
		where 
			isnull( [ins].[%1], 0x0) = 0x0', @TableName, @ParentFldName
##########################################################################################
#END