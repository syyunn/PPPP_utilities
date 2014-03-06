﻿---------------------------------------------
--Copyright Remi-C Thales IGN 03/12/2013
--
--
--adding , to catch errorsan exception catcher around totopogeom
--
--
--
--------------------------------------------


-- Function: public.rc_totopogeomwithouterrors(geometry, character varying, integer, double precision)

-- DROP FUNCTION public.rc_totopogeomwithouterrors(geometry, character varying, integer, double precision);

CREATE OR REPLACE FUNCTION public.rc_totopogeomwithouterrors(ageom geometry, atopology character varying, alayer integer, atolerance double precision DEFAULT 0)
  RETURNS topogeometry AS
$BODY$
DECLARE
  layer_info RECORD;
  topology_info RECORD;
  rec RECORD;
  tg topology.TopoGeometry;
  elems topology.TopoElementArray = '{{0,0}}';
  sql TEXT;
  typ TEXT;
  tolerance FLOAT8;
BEGIN

raise notice 'ageom : %',ST_AsText(ageom);
  -- Get topology information
  BEGIN
    SELECT *
    FROM topology.topology
      INTO STRICT topology_info WHERE name = atopology;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE EXCEPTION 'No topology with name "%" in topology.topology',
        atopology;
  END;

  -- Get tolerance, if 0 was given
  tolerance := COALESCE( NULLIF(atolerance, 0), topology._st_mintolerance(atopology, ageom) );

  -- Get layer information
  BEGIN
    SELECT *, CASE
      WHEN feature_type = 1 THEN 'puntal'
      WHEN feature_type = 2 THEN 'lineal'
      WHEN feature_type = 3 THEN 'areal'
      WHEN feature_type = 4 THEN 'mixed'
      ELSE 'unexpected_'||feature_type
      END as typename
    FROM topology.layer l
      INTO STRICT layer_info
      WHERE l.layer_id = alayer
      AND l.topology_id = topology_info.id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE EXCEPTION 'No layer with id "%" in topology "%"',
        alayer, atopology;
  END;

  -- Can't convert to a hierarchical topogeometry
  IF layer_info.level > 0 THEN
      RAISE EXCEPTION 'Layer "%" of topology "%" is hierarchical, cannot convert to it.',
        alayer, atopology;
  END IF;


  -- 
  -- Check type compatibility and create empty TopoGeometry
  -- 1:puntal, 2:lineal, 3:areal, 4:collection
  --
  typ = geometrytype(ageom);
  IF typ = 'GEOMETRYCOLLECTION' THEN
    --  A collection can only go collection layer
    IF layer_info.feature_type != 4 THEN
      RAISE EXCEPTION
        'Layer "%" of topology "%" is %, cannot hold a collection feature.',
        layer_info.layer_id, topology_info.name, layer_info.typename;
    END IF;
    tg := topology.CreateTopoGeom(atopology, 4, alayer);
  ELSIF typ = 'POINT' OR typ = 'MULTIPOINT' THEN -- puntal
    --  A point can go in puntal or collection layer
    IF layer_info.feature_type != 4 and layer_info.feature_type != 1 THEN
      RAISE EXCEPTION
        'Layer "%" of topology "%" is %, cannot hold a puntal feature.',
        layer_info.layer_id, topology_info.name, layer_info.typename;
    END IF;
    tg := topology.CreateTopoGeom(atopology, 1, alayer);
  ELSIF typ = 'LINESTRING' or typ = 'MULTILINESTRING' THEN -- lineal
    --  A line can go in lineal or collection layer
    IF layer_info.feature_type != 4 and layer_info.feature_type != 2 THEN
      RAISE EXCEPTION
        'Layer "%" of topology "%" is %, cannot hold a lineal feature.',
        layer_info.layer_id, topology_info.name, layer_info.typename;
    END IF;
    tg := topology.CreateTopoGeom(atopology, 2, alayer);
  ELSIF typ = 'POLYGON' OR typ = 'MULTIPOLYGON' THEN -- areal
    --  An area can go in areal or collection layer
    IF layer_info.feature_type != 4 and layer_info.feature_type != 3 THEN
      RAISE EXCEPTION
        'Layer "%" of topology "%" is %, cannot hold an areal feature.',
        layer_info.layer_id, topology_info.name, layer_info.typename;
    END IF;
    tg := topology.CreateTopoGeom(atopology, 3, alayer);
  ELSE
      -- Should never happen
      RAISE EXCEPTION
        'Unsupported feature type %', typ;
  END IF;

  -- Now that we have a topogeometry, we loop over distinct components 
  -- and add them to the definition of it. We add them as soon
  -- as possible so that each element can further edit the
  -- definition by splitting

--modified to catch errors:
BEGIN

  FOR rec IN SELECT DISTINCT id(tg), alayer as lyr,-- geom,
    CASE WHEN ST_Dimension(geom) = 0 THEN 1
         WHEN ST_Dimension(geom) = 1 THEN 2
         WHEN ST_Dimension(geom) = 2 THEN 3
    END as type,
    CASE WHEN ST_Dimension(geom) = 0 THEN
           topology.topogeo_addPoint(atopology, geom, tolerance)
         WHEN ST_Dimension(geom) = 1 THEN
           topology.topogeo_addLineString(atopology, geom, tolerance)
         WHEN ST_Dimension(geom) = 2 THEN
           topology.topogeo_addPolygon(atopology, geom, tolerance)
    END as primitive
    FROM (SELECT (ST_Dump(ageom)).geom) as f
    WHERE NOT ST_IsEmpty(geom)
  LOOP
  --raise notice 'coucou, tg : %, geom %',rec.id, ST_AsText(rec.geom);
    -- TODO: consider use a single INSERT statement for the whole thing
    sql := 'INSERT INTO ' || quote_ident(atopology)
        || '.relation(topogeo_id, layer_id, element_type, element_id) VALUES ('
        || rec.id || ',' || rec.lyr || ',' || rec.type
        || ',' || rec.primitive || ')';
    EXECUTE sql;
  END LOOP;

  RETURN tg;
  
EXCEPTION
    WHEN SQLSTATE 'P0001' THEN
        RAISE NOTICE 'this geometry can''t be converted to topogeom : %
		doing nothing',ageom;
	RETURN NULL;	
END;
END
$BODY$
  LANGUAGE plpgsql VOLATILE STRICT
  COST 100;
ALTER FUNCTION public.rc_totopogeomwithouterrors(geometry, character varying, integer, double precision)
  OWNER TO postgres;