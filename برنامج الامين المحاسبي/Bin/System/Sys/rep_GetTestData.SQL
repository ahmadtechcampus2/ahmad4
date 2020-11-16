############################################################
create proc rep_GetTestData
 @startdate datetime,
 @enddate datetime
---, @matGuid uniqueidentifier
As
select 	mt.guid , mt.name , 
	case mt.defunit 
	  when 1 then
		case mt.unity 
		when '' then '«·ÊÕœ… «·√Ê·Ï'
		else mt.unity 
		end
	 when 2 then 	mt.unit2
		else	unit3
	end	
	AS mat_unit
,	
 	case mt.defunit
  	  when 1 then 
		case  bi.unity
		   when 2  then  bi.qty / mt.unit2fact
 		   when 3  then  bi.qty / mt.unit3fact
		else 	 bi.qty
	  end
	 when 2 then
		case  bi.unity
		   when 1  then  bi.qty * mt.unit2fact
 		   when 3  then  (bi.qty * mt.unit3fact) / unit2fact
		else 	bi.qty
	  end
  	 when 3  then
                  case  bi.unity
		   when 1  then  bi.qty / mt.unit3fact
 		   when 2  then  (bi.qty / mt.unit2fact)* unit3fact
		else 	bi.qty
	       end
	end
	as qty_def
,
	case bi.unity 
	  when 1 then

	case mt.unity 
		when '' then '«·ÊÕœ… «·√Ê·Ï'
		else mt.unity 
		end
	  when 2 then 	mt.unit2
		  else	unit3
	 end	
	AS BILL_UNIT
, 
 	case mt.defunit
  	  when 1 then 
		case  bi.unity
		   when 2  then  bi.price * mt.unit2fact
 		   when 3  then  bi.price * mt.unit3fact
		else 	bi.price
	  end
	 when 2 then
		case  bi.unity
		   when 1  then  bi.price / mt.unit2fact
 		   when 3  then  (bi.price / mt.unit3fact) * unit2fact
		else 	bi.price
	  end
  	 when 3  then
                  case  bi.unity
		   when 1  then  bi.price / mt.unit3fact
 		   when 2  then  (bi.price * mt.unit2fact)/ unit3fact
		else 	bi.price
	       end
	end
	as price_def

from bi000 as bi 
	inner join bu000  AS BU on bi.parentguid = bu.guid
	inner join mt000  AS mt on bi.matguid = mt.guid
where 
	bu.date  between @startdate and @enddate
	
########################################
create proc rep_GetTestData2
-- @startdate datetime 
-- @enddate datetime  

As
select 	
	mt.guid ,
	bt.abbrev + ' ' + CAST( bu.number AS NVARCHAR(128)) as op_abbrev,
	bt.name as op_name,
	mt.name , 
	case mt.defunit 
	  when 1 then
		case mt.unity 
		when '' then '«·ÊÕœ… «·√Ê·Ï'
		else mt.unity 
		end
	 when 2 then 	mt.unit2
		else	unit3
	end	
	AS mat_unit
,	
 	case mt.defunit
  	  when 1 then 
		case  bi.unity
		   when 2  then  bi.qty / mt.unit2fact
 		   when 3  then  bi.qty / mt.unit3fact
		else 	 bi.qty
	  end
	 when 2 then
		case  bi.unity
		   when 1  then  bi.qty * mt.unit2fact
 		   when 3  then  (bi.qty * mt.unit3fact) / unit2fact
		else 	bi.qty
	  end
  	 when 3  then
                  case  bi.unity
		   when 1  then  bi.qty / mt.unit3fact
 		   when 2  then  (bi.qty / mt.unit2fact)* unit3fact
		else 	bi.qty
	       end
	end
	as qty_def
,
	case bi.unity 
	  when 1 then

	case mt.unity 
		when '' then '«·ÊÕœ… «·√Ê·Ï'
		else mt.unity 
		end
	  when 2 then 	mt.unit2
		  else	unit3
	 end	
	AS BILL_UNIT
, 
 	case mt.defunit
  	  when 1 then 
		case  bi.unity
		   when 2  then  bi.price * mt.unit2fact
 		   when 3  then  bi.price * mt.unit3fact
		else 	bi.price
	  end
	 when 2 then
		case  bi.unity
		   when 1  then  bi.price / mt.unit2fact
 		   when 3  then  (bi.price / mt.unit3fact) * unit2fact
		else 	bi.price
	  end
  	 when 3  then
                  case  bi.unity
		   when 1  then  bi.price / mt.unit3fact
 		   when 2  then  (bi.price * mt.unit2fact)/ unit3fact
		else 	bi.price
	       end
	end
	as price_def

from bi000 as bi 
	inner join bu000  AS BU on bi.parentguid = bu.guid
	inner join mt000  AS mt on bi.matguid = mt.guid
	inner join bt000  As bt on bt.guid = bu.typeguid 
	order by op_abbrev


#END

--CREATE PROC rep_GetTestData
--	@startDate datetime	@enddate datetime
--AS
--	SELECT mt.Name, bi.Qty, bi.Price 
--	FROM 
--		BI000 AS bi 
--		INNER JOIN BU000 AS bu ON bu.GUID = bi.ParentGUID
--		INNER JOIN MT000 AS mt ON mt.GUID = bi.MatGUID
--	WHERE
--		bu.DAte between @startDate and @enddate
--#END