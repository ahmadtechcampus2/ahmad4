
/************************************************************************/
/*Summery : procedure that take ps000.Guid and returned all it's Children in PSI000*/
Create PROC [dbo].[GetPSList] 
	@PSGUID [UNIQUEIDENTIFIER] ,@psiGuid [UNIQUEIDENTIFIER] = NULL
AS 
	DECLARE @SQL [NVARCHAR](2000) 
	IF @PSIGUID  = NULL 
		SET @SQL = 'SELECT  psi.Guid  ,  psi.FormGuid ,
					psi.priority , psi.storeguid, 
					psi.State, psi.parentGuid  
					FROM psi000 as psi inner join ps000 as ps  
					ON [ps].[GUID] = [psi].[parentGUID]
					where ps.guid =	''' + cast(@PSGUID   as NVARCHAR(40))+ '''' + 
					'order by psi.startdate , psi.state , psi.priority'
	ELSE 
	SET @SQL = 'SELECT  psi.Guid , psi.code ,psi.StartDate ,psi.EndDate ,
				FormGuid , psi.priority ,psi.[StoreGuid] , psi.State, parentGuid
				FROM psi000 as psi inner join ps000 as ps  
				ON [ps].[GUID] = [psi].[parentGUID]
				where ps.guid =	''' + cast(@PSGUID   as NVARCHAR(40))
				 + '''AND psi.guid = ''' + cast(@PSGUID   as NVARCHAR(40))+''''
				 + 'order by psi.startdate , psi.state , psi.priority'
	EXEC (@SQL) 


/****************************************************************/
