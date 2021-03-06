﻿--------------
--Remi-C Thales IG 02/2015
-----------
-- some work to try to perfom efficient geometry cutting into pieces
--------------


--importing real data 
/*

--creating index
CREATE INDEX ON lancover_polygons_2010 (ogc_fid);
CREATE INDEX ON lancover_polygons_2010 (lc_class);
CREATE INDEX ON lancover_polygons_2010 (mod_ty);
CREATE INDEX ON lancover_polygons_2010 USING GIST(wkb_geometry);

SELECT *
FROM lancover_polygons_2010  
LIMIT 1 
SELECT lc_class, sum(st_numpoints(wkb_geometry)), count(*) 
FROm lancover_polygons_2010
GROUP BY lc_class 

DROP TABLE IF EXISTS lancover_polygons_2010_dumped ;
CREATE TABLE lancover_polygons_2010_dumped AS 
SELECT ogc_fid, lc_class, dmp.path, dmp.geom
FROM lancover_polygons_2010, ST_Dump(wkb_geometry) as dmp; 

SELECT lc_class, count(*), sum(st_numpoints(geom)), sum(ST_NumInteriorRings(geom))
FROm lancover_polygons_2010_dumped
GROUP BY lc_class

SELECT *,st_numpoints(geom),ST_NumInteriorRings(geom)
FROM lancover_polygons_2010_dumped
ORDER BY ST_NumInteriorRings(geom)
DESC
LIMIT 100


SELECT ST_GeometryType(wkb_geometry)
FROM lancover_polygons_2010
WHERE ogc_fid = 103209 AND lc_class=  34



--emulating a big geom, dumping it to points 
--150 sec for 60000 as a parameter
*/
/*
DROP TABLE IF EXISTS geom_dumped_rings ;
CREATE TABLE geom_dumped_rings AS 
WITH fake_input_geom AS (--creating a polygon with possibly very big number of points, for test
		SELECT  ST_MAkePolygon(ST_CurveToLine(curve1,100000), ARRAY[ST_CurveToLine(curve2,100000),ST_CurveToLine(curve3,1000000)]) as geom
		FROM ST_GeomFromText('CIRCULARSTRING(-10 0,10 0,-10 0)') as curve1
			,ST_GeomFromText('CIRCULARSTRING(-1 0,1 0,-1 0)') as curve2
			,ST_GeomFromText('CIRCULARSTRING(-3 -1.5, -0.5 -1.5,-3 -1.5)') as curve3
		LIMIT 1 --security, this script is not safe ot use with multiple input, neither with multi geom
	) 
	SELECT dmp.path[1] as rid, dmp.geom
	FROM  fake_input_geom, ST_DumpRings(geom) as dmp;
*//*
CREATE TABLE geom_dumped_rings AS  
	SELECT dmp.path[1] as rid, dmp.geom
	FROM  lancover_polygons_2010, ST_DumpRings(ST_GeometryN(wkb_geometry,1)) as dmp 
	WHERE ogc_fid = 103209 AND lc_class=  34

	
	

CREATE INDEX ON geom_dumped_rings (rid) ; 
CREATE INDEX ON geom_dumped_rings USING GIST(geom) ; 

 
DROP TABLE IF EXISTS geom_dumped_to_points;
CREATE TABLE geom_dumped_to_points AS 
	WITH   extracted_points AS (
		SELECT rid  as p1, dmp.path[2] as p2, dmp.geom
		FROM geom_dumped_rings, ST_DumpPoints(geom) as dmp
	)
	, segment AS ( 
		SELECT *, COALESCE(lead(geom,1,NULL) OVER w, first_value(geom) OVER w) as n_point
		FROM extracted_points
		WINDOW w AS (PARTITION BY p1 ORDER BY p2)
	) 
	SELECT p1,p2, ST_SetSRID(ST_MakeLine(geom,n_point),ST_SRID(geom)) as segment
	FROM segment  ; 
	--15sec
	
SELECT count(*)
FROM geom_dumped_to_points ; 
	
CREATE INDEX ON geom_dumped_to_points (p1);
CREATE INDEX ON geom_dumped_to_points (p2); 
CREATE INDEX ON geom_dumped_to_points USING GIST(segment);
--15

--creating a grid covering the area , with some indexes
DROP TABLE IF EXISTS temp_grid ; 
CREATE TABLE temp_grid AS 
	WITH srid AS(
		SELECT ST_SRID(segment) AS srid
		FROM geom_dumped_to_points
		LIMIT 1 
	)
	,extent AS (
		SELECT  ST_Extent(segment) as ext
		FROM srid,geom_dumped_to_points 
	)
	SELECT row_number() over() as nid, ST_SetSRID(f.square,srid) as square
	FROM extent, srid,CDB_RectangleGrid(ST_SetSRID(ext,srid), 1500,1500) as f(square);

CREATE INDEX ON temp_grid (nid) ;
CREATE INDEX ON temp_grid USING GIST(square) ;
--0.375 
 
 --getting the mapping between segment and grid
DROP TABLE IF  EXISTS mapping_segment_square;  
CREATE TABLE  mapping_segment_square AS 
		-- we group segment to form lines
		SELECT p1, nid, tg.square  , ST_LineMerge(ST_Collect(gd.segment ORDER BY p2)) AS line 
		FROM geom_dumped_to_points as gd, temp_grid AS tg
		WHERE ST_Intersects(gd.segment, tg.square)
		GROUP BY p1, nid, tg.square   ;

	CREATE INDEX ON mapping_segment_square (nid) ;
	CREATE INDEX ON mapping_segment_square (p1) ;
--7sec

--group segment per square, create new geom by splitting the square into pieces
DROP TABLE IF  EXISTS cutted_square;  
CREATE TABLE  cutted_square AS 	
	WITH line_grouped AS ( --we group lines for each ring to form lines
		SELECT  nid, square  ,  ST_LineMerge(ST_Collect( line ))  AS line -- removed a st_node on line 
		FROM mapping_segment_square
		GROUP BY   nid,  square   
	)
	, square_cutted AS ( --cutting the square that mapped with the union of segment to form new polygons.
		SELECT   nid, ST_Polygonize( ST_Node(ST_CollectionExtract(ST_Collect( ARRAY[ST_ExteriorRing(square), line]),2)) )as possible_geom
		FROM line_grouped 
		GROUP BY  nid --,line,square
	)
	SELECT row_number() over() as gid,nid, dmp.geom 
	FROM square_cutted, st_dump(possible_geom) AS dmp; 

CREATE INDEX ON cutted_square (gid) ;
CREATE INDEX ON cutted_square (nid) ;
CREATE INDEX ON cutted_square USING GIST  (geom ) ;
CREATE INDEX ON cutted_square USING GIST  (ST_PointOnSurface(geom) ) ;

--4sec

--prepare final result : 
-- compute squarized ring version
  
DROP TABLE IF EXISTS squarized_ring ;
CREATE TABLE squarized_ring  AS 
WITH segments_of_ring_square AS (
		SELECT  p1, dmp.geom AS seg, count(*) over(partition by p1,dmp.geom  ) as n_seg
		FROM mapping_segment_square, rc_DumpSegments(ST_ExteriorRing(square)) as dmp
	)
	--, segments_filtered_grouped AS ( -- this create a 
		SELECT  p1 --, ST_MakePolygon(ST_UnaryUnion( ST_LineMerge(ST_Collect(ST_SNapToGrid(seg,0.01)))))as squarized_ring
			, ST_MakePolygon(ST_ExteriorRing(ST_BuildArea( ST_LineMerge(ST_Collect(ST_SNapToGrid(seg,0.01)))))) as squarized_ring
		FROM segments_of_ring_square
		WHERE n_seg=1
		GROUP BY p1 ; 
CREATE INDEX ON squarized_ring (p1) ; 
CREATE INDEX ON squarized_ring USING GIST( squarized_ring) ; 
--0.172

--now compute square that are necessary within the big polygon
DROP TABLE IF EXISTS full_square_within ;
CREATE TABLE full_square_within  AS  
	WITH full_square_intersecting AS (
		SELECT nid , tg.square
		FROM squarized_ring as s , temp_grid AS tg
		WHERE ST_WITHIN(tg.square, s.squarized_ring)=TRUE
			AND p1=0 --excluding manually the outer ring
		EXCEPT 
			SELECT nid , tg.square
			FROM squarized_ring as s , temp_grid AS tg
			WHERE --ST_Intersects(tg.square, s.squarized_ring)=TRUE AND ST_Touches(tg.square, s.squarized_ring)=FALSE
				ST_WITHIN( tg.square,s.squarized_ring )
				AND p1>0 --excluding manually the outer ring
	)
	SELECT *
	FROM full_square_intersecting AS fs
	WHERE NOT EXISTS (SELECT 1 FROM cutted_square  AS cs WHERE cs.nid = fs.nid);
 

-- we accelerated all that could be done, now we need to deal with cutted_square to determine for each if it is inside of outside the massive polygon
-- we divide the work further : we dont test for the whole polygon, we separate for polygon and for inner rings, because rings are indexed
-- 
-- DROP TABLE IF EXISTS cutted_square_within;  
-- CREATE TABLE cutted_square_within AS 
-- 	--WITH cutted_square_within_exterior_ring AS ( 
-- 		SELECT DISTINCT  cs.gid 
-- 		FROm cutted_square AS cs, geom_dumped_rings as gd
-- 		WHERE ST_Intersects(cs.geom,gd.geom)=TRUE
-- 			AND gd.rid = 0
-- 			AND ST_Area(ST_Intersection(cs.geom,gd.geom) )> 0.001 
-- 		EXCEPT  
-- 		SELECT  DISTINCT cs.gid 
-- 		FROM cutted_square AS cs, geom_dumped_rings as gd
-- 		WHERE ST_Intersects(cs.geom,gd.geom)=TRUE
-- 			AND ST_Area(ST_Intersection(cs.geom,gd.geom) )> 0.001
-- 		AND gd.rid > 0   ; 

 

DROP TABLE IF EXISTS cutted_square_within;  
CREATE TABLE cutted_square_within AS 
	--WITH cutted_square_within_exterior_ring AS ( 
		SELECT DISTINCT  cs.gid , cs.geom, 'within' as status
		FROm cutted_square AS cs,geom_dumped_rings as gd 
		WHERE ST_Intersects(gd.geom, ST_PointOnSurface(cs.geom) )=TRUE
			AND ST_Intersects(gd.geom, cs.geom  ) = TRUE
			AND gd.rid = 0; 
			--AND ST_Area(ST_Intersection(cs.geom,gd.geom) )> 0.001 

CREATE INDEX ON cutted_square_within(gid);
CREATE INDEX ON cutted_square_within USING GIST(geom);
 
DROP TABLE IF EXISTS cutted_square_maybe_within;  
CREATE TABLE cutted_square_maybe_within AS 
		SELECT cs.gid , cs.geom 
		FROm cutted_square AS cs
		EXCEPT 
		SELECT  DISTINCT cs.gid , cs.geom
		FROM cutted_square AS cs, geom_dumped_rings as gd
		WHERE ST_Intersects(ST_PointOnSurface(cs.geom),gd.geom)=TRUE
			--AND ST_Area(ST_Intersection(cs.geom,gd.geom) )> 0.001
		AND gd.rid > 0   ; 

CREATE INDEX ON cutted_square_within (gid);
CREATE INDEX ON cutted_square_within USING GIST(geom);



---------trying another approach : tesselation !
DROP TABLE IF EXISTS tesselation;
CREATE TABLE tesselation AS 
SELECT row_number() over() as tid, rid, triangle
FROM geom_dumped_rings

DROP TABLE IF EXISTS tesselation;
CREATE TABLE tesselation AS 
SELECT ST_Tesselate( geom) AS triangle
FROM  lancover_polygons_2010 
	WHERE ogc_fid = 103209 AND lc_class=  34
 
 
 */
