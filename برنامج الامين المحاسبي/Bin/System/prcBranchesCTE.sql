###############################################################
CREATE PROC GetMainBranchParents
@MainBranchGUID uniqueidentifier,
@ChildBranchGUID uniqueidentifier
AS
BEGIN

SET NOCOUNT ON;
-- ��� ������� ���� ��� ��� ���� ���� ����� �������

With BranchesCTE ([GUID], [ParentGUID])
AS
(
	SELECT Branch.[GUID], Branch.[ParentGUID]
	FROM br000 AS Branch
	WHERE Branch.[GUID] = @MainBranchGUID

	UNION ALL 

	SELECT Branch.[GUID], Branch.[ParentGUID]
	FROM br000 AS Branch 
	JOIN BranchesCTE
	ON Branch.[GUID] = BranchesCTE.[ParentGUID]
	
)

--��� ��� ����� ��� ��������� ������� ,��� ����� ������� ������� 
SELECT [GUID] FROM BranchesCTE WHERE [GUID] = @ChildBranchGUID

END
##############################################################
#END