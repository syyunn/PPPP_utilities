﻿---------------------------------------------
--Copyright Remi-C Thales IGN 05/2015
-- 
--this function construct a Bezier curve linking 2 segments
--------------------------------------------

DROP FUNCTION IF EXISTS rc_bezier_from_seg(seg_points geometry,parallel_threshold float, nb_segs int);
CREATE OR REPLACE FUNCTION rc_bezier_from_seg(seg_points geometry,parallel_threshold float, nb_segs int, OUT bezier geometry, OUT PC geometry)
  AS
$BODY$
#this function takes 2 segments, and build a Bezier curve to join the segments
import sys
sys.path.insert(0, '/media/sf_E_RemiCura/PROJETS/PPPP_utilities/postgis') 
import rc_py_generate_bezier_curve as rc
#reload(rc)
bezier, pc = rc.bezier_curve(seg_points, parallel_threshold, nb_segs, in_server=True)
return (bezier,pc)
$BODY$
LANGUAGE plpythonu STABLE STRICT;

SELECT st_astext(bezier), st_astext(pc) 
FROM ST_GeomFromText('MULTIPOINT(0 2,1 2,2 1 ,2 0)') as geom 
	,rc_bezier_from_seg(geom,pi()/8, 10);

	
SELECT geom
FROM ST_GeomFromText('MULTIPOINT(0 2,1 2,2 1 ,2 0)') as geom ; 

SELECT ST_AsText('01020000001F000000000000000000F03F000000000000004061EA72FB830CF13F50D961EA72FBFF3F6687A9CBED0FF23F446587A9CBEDFF3F0BD7A3703D0AF33FD8A3703D0AD7FF3F51D961EA72FBF33F0D951DA62EB7FF3F398EE3388EE3F43FE4388EE3388EFF3FC4F5285C8FC2F53F5E8FC2F5285CFF3FED0F32547698F63F7798BADCFE20FF3FBCDCFE204365F73F34547698BADCFE3F285C8FC2F528F83F8FC2F5285C8FFE3F3A8EE3388EE3F83F90E3388EE338FE3FEA72FB830C95F93F2DB73FC850D9FD3F3E0AD7A3703DFA3F713D0AD7A370FD3F31547698BADCFA3F547698BADCFEFC3FC950D961EA72FB3FDA61EA72FB83FC3F000000000000FC3F000000000000FC3FDA61EA72FB83FC3FC850D961EA72FB3F547698BADCFEFC3F32547698BADCFA3F713D0AD7A370FD3F3E0AD7A3703DFA3F2FB73FC850D9FD3FEA72FB830C95F93F8EE3388EE338FE3F398EE3388EE3F83F90C2F5285C8FFE3F295C8FC2F528F83F32547698BADCFE3FBBDCFE204365F73F7798BADCFE20FF3FEE0F32547698F63F5C8FC2F5285CFF3FC3F5285C8FC2F53FE4388EE3388EFF3F3A8EE3388EE3F43F0C951DA62EB7FF3F52D961EA72FBF33FD7A3703D0AD7FF3F0BD7A3703D0AF33F436587A9CBEDFF3F6687A9CBED0FF23F50D961EA72FBFF3F62EA72FB830CF13F0000000000000040010000000000F03F');  