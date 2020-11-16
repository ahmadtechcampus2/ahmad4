##################################################################################
CREATE PROCEDURE prcCopyItemPermession
	@SourceUserGuid			[UNIQUEIDENTIFIER],
	@DestinationUserGuid	[UNIQUEIDENTIFIER]
AS
	DECLARE @SQL NVARCHAR(MAX)
	SET @SQL = '
	DECLARE @SrcMask1 BIGINT, @SrcMask2 BIGINT, @SrcMask3 BIGINT, @SrcMask4 BIGINT
	SELECT	
		@SrcMask1 = SUM( CASE WHEN  [u].[Number] between 1 and 63 THEN [dbo].[fnPowerOf2]([u].[Number] - 1)  ELSE 0 END),
		@SrcMask2 = SUM( CASE WHEN  [u].[Number] between 64 and 126 THEN dbo.[fnPowerOf2]( [u].[Number] - 64) ELSE 0 END),
		@SrcMask3 = SUM( CASE WHEN  [u].[Number] between 127 and 189 THEN dbo.[fnPowerOf2]( [u].[Number] - 127) ELSE 0 END),
		@SrcMask4 = SUM( CASE WHEN  [u].[Number] between 190 and 252 THEN dbo.[fnPowerOf2]( [u].[Number] - 190) ELSE 0 END)
	FROM
		[us000] [u]
	WHERE
		[u].GUID = ''' + cast(@SourceUserGuid As VarChar(250)) + '''

	DECLARE @DstMask1 BIGINT, @DstMask2 BIGINT, @DstMask3 BIGINT, @DstMask4 BIGINT
	SELECT	
		@DstMask1 = SUM( CASE WHEN  [u].[Number] between 1 and 63 THEN [dbo].[fnPowerOf2]([u].[Number] - 1)  ELSE 0 END),
		@DstMask2 = SUM( CASE WHEN  [u].[Number] between 64 and 126 THEN dbo.[fnPowerOf2]( [u].[Number] - 64) ELSE 0 END),
		@DstMask3 = SUM( CASE WHEN  [u].[Number] between 127 and 189 THEN dbo.[fnPowerOf2]( [u].[Number] - 127) ELSE 0 END),
		@DstMask4 = SUM( CASE WHEN  [u].[Number] between 190 and 252 THEN dbo.[fnPowerOf2]( [u].[Number] - 190) ELSE 0 END)
	FROM
		[us000] [u]
	WHERE
		[u].GUID = ''' + cast(@DestinationUserGuid As VarChar(250)) + '''

	update [iss] set
		[Mask1] = [iss].[Mask1] | @DstMask1,
		[Mask2] = [iss].[Mask2] | @DstMask2, 
		[Mask3] = [iss].[Mask3] | @DstMask3,
		[Mask4] = [iss].[Mask4] | @DstMask4
	from
		[isx000] [iss]
	where 
		[iss].[Mask1] & @SrcMask1 != 0 OR  [iss].[Mask2] & @SrcMask2 != 0 OR  [iss].[Mask3] & @SrcMask3 != 0 OR  [iss].[Mask4] & @SrcMask4 != 0'

	EXEC [prcExecuteSQL] @SQL
##################################################################################
#END