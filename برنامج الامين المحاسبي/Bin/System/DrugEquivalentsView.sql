CREATE VIEW  DrugEquivalentsView  AS
SELECT  
		 equivalents.matguid AS Matguid 
		,equivalents.equivalentguid AS equivalentguid
		,equivalents.Note AS Note
		,mt.name
		,mt.Latinname AS latinName
		,mt.Code 
		,bi.ExpireDate
		,SUM(bi.qty * (case bt.bisoutPut when 1 then -1 else 1 end) ) qty
	FROM DrugEquivalents000 equivalents  
	INNER JOIN mt000 mt ON equivalents.equivalentguid = mt.guid  
    INNER JOIN bi000 bi ON equivalents.equivalentguid = bi.matguid
    INNER JOIN bu000 bu ON bu.guid = bi.Parentguid
    INNER JOIN bt000 bt ON bt.guid = bu.Typeguid
	WHERE bi.ExpireDate <> '1/1/1980'
  Group by
		 equivalents.matguid  
		,equivalents.equivalentguid
		,equivalents.Note 
		,mt.name
		,mt.Latinname
		,mt.Code 
		,bi.ExpireDate
GO