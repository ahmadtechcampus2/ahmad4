############################################################################################
CREATE PROCEDURE prcCheckDB_mt_Acc
	@Correct INT = 0
AS
	SELECT Max( Cast( Guid as nvarchar(100))) Guid,  Type, ObjGuid, BillTypeGuid 
	INTO #t_Er 
	FROM 
		ma000
	GROUP BY
		Type, ObjGuid, BillTypeGuid
	HAVING
		COUNT( Type) > 1
		
	IF( @@ROWCOUNT = 0)
		RETURN
	
	IF @Correct <> 1
	BEGIN
		INSERT INTO [ErrorLog]( [Type], [g1], [c1], [c2])
		SELECT 0xF05, ObjGuid, mt.Code, mt.Name
		FROM 
			#t_Er ma inner join mt000 mt on ma.ObjGuid = mt.Guid
		WHERE
			ma.Type = 1

		INSERT INTO [ErrorLog]( [Type], [g1], [c1], [c2])
		SELECT 0xF06, ObjGuid, gr.Code, gr.Name
		FROM 
			#t_Er ma inner join gr000 gr on ma.ObjGuid = gr.Guid
		WHERE
			ma.Type = 2
		
		INSERT INTO [ErrorLog]( [Type], [g1], [c1], [c2])
		SELECT 0xF07, ObjGuid, us.LoginName, us.FirstName
		FROM 
			#t_Er ma inner join us000 us on ma.ObjGuid = us.Guid
		WHERE
			ma.Type = 5
	END
	IF @Correct <> 0
	BEGIN
		EXEC prcDisableTriggers 'ma000'
		DELETE ma 
		from 
			ma000 ma inner join #t_Er er 
			on 
				ma.Type = er.Type 
				and ma.ObjGuid = er.ObjGuid 
				and ma.BillTypeGuid = er.BillTypeGuid
				and ma.Guid != cast( er.Guid as uniqueidentifier)

		ALTER TABLE [ma000] ENABLE TRIGGER ALL
	END
	DROP TABLE #t_Er
############################################################################################
#END