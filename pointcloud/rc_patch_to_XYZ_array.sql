﻿-----------------------------------------------------------
--
--Rémi-C , Thales IGN
--11/2014
-- 
  ----------------------

/*
	--we need an array agg for array, found in PPPP_utilities
			DROP AGGREGATE public.array_agg_custom(anyarray) ;
			CREATE AGGREGATE public.array_agg_custom(anyarray)
				( SFUNC = array_cat,
				STYPE = anyarray
				);
*/
	--a wrapper function to convert from patch to array[array[]], so to be able to transmit information	
	DROP FUNCTION IF EXISTS rc_patch_to_XYZ_array(ipatch PCPATCH,maxpoints INT, int);
	CREATE OR REPLACE FUNCTION rc_patch_to_XYZ_array(ipatch PCPATCH,maxpoints INT DEFAULT 0, rounding_digits int default 3
		)
	  RETURNS FLOAT[] AS
	$BODY$ 
			DECLARE 
			BEGIN 
				RETURN array_agg_custom(
					ARRAY[
						round(PC_Get(pt.point,'X'),rounding_digits)
						, round(PC_Get(pt.point,'Y'),rounding_digits)
						, round(PC_Get(pt.point,'Z'),rounding_digits)
					] ORDER BY pt.ordinality ASC )
				FROM public.rc_ExplodeN_numbered(  ipatch,maxpoints) as pt ; 
			END ; 
		$BODY$
	LANGUAGE plpgsql IMMUTABLE STRICT;
	--SELECT rc_patch_to_XYZ_array()

	DROP FUNCTION IF EXISTS rc_lib.rc_multipoints_to_XYZ_array(ipoints geometry, int);
	CREATE OR REPLACE FUNCTION rc_lib.rc_multipoints_to_XYZ_array(ipoints geometry,  rounding_digits int default 3 )
	  RETURNS FLOAT[] AS
	$BODY$ 
			DECLARE 
			BEGIN 
				IF ST_Zmflag(ipoints) =2 THEN 
				RETURN rc_lib.array_agg_custom(
					ARRAY[
						 round(ST_X(dmp.geom)::numeric,rounding_digits)
						,  round(ST_Y(dmp.geom)::numeric,rounding_digits)
						,  round(ST_Z(dmp.geom)::numeric,rounding_digits)
					] ORDER BY dmp.path ASC )
				FROM ST_DumpPoints(ipoints ) AS dmp  ; 
			ELSIF ST_Zmflag(ipoints) =0 THEN
				RETURN rc_lib.array_agg_custom(
					ARRAY[
						 round(ST_X(dmp.geom)::numeric,rounding_digits)
						,  round(ST_Y(dmp.geom)::numeric,rounding_digits) 
					] ORDER BY dmp.path ASC )
				FROM ST_DumpPoints(ipoints ) AS dmp  ; 
			ELSE  
				RAISE EXCEPTION 'mutlipoints to array not supported for type %' , ST_Zmflag(ipoints)  ; 
			END IF ; 
			END ; 
		$BODY$
	LANGUAGE plpgsql IMMUTABLE STRICT;
	--SELECT rc_patch_to_XYZ_array()
		SELECT rc_lib.rc_multipoints_to_XYZ_array(ipoints,3) 
		FROM ST_GeomFromText('MULTIPOINT( 0 0 0,1 1 1,2 2 2,3 3 3 ,4 4 4)') as ipoints;
 