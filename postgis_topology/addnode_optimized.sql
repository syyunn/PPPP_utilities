﻿-- Function: topology.addnode(character varying, geometry, boolean, boolean)

-- DROP FUNCTION topology.addnode(character varying, geometry, boolean, boolean);

CREATE OR REPLACE FUNCTION topology.addnode(atopology character varying, apoint geometry, allowedgesplitting boolean, setcontainingface boolean DEFAULT false)
  RETURNS integer AS
$BODY$
DECLARE
	nodeid int;
	rec RECORD;
  containing_face int;
BEGIN
	--
	-- Atopology and apoint are required
	-- 
	IF atopology IS NULL OR apoint IS NULL THEN
		RAISE EXCEPTION 'Invalid null argument';
	END IF;

	--
	-- Apoint must be a point
	--
	--IF substring(geometrytype(apoint), 1, 5) != 'POINT' --NOTE : no need for substring, swithcing to standard function
	IF ST_geometrytype(apoint)  != 'ST_POINT'
	THEN
		RAISE EXCEPTION 'Node geometry must be a point';
	END IF;
 
 
  IF setContainingFace THEN
    containing_face := topology.GetFaceByPoint(atopology, apoint, 0);
  ELSE
    containing_face := NULL;
  END IF;

	--
	-- Get new node id from sequence --NOTE : we get it directly with a "return" in the insert.
	--
	--FOR rec IN EXECUTE 'SELECT nextval(' ||
	--	quote_literal(
	--		quote_ident(atopology) || '.node_node_id_seq'
	--	) || ')'
	--LOOP
	--	nodeid = rec.nextval;
	--END LOOP;

	--
	-- Insert the new row
	--
	EXECUTE 'INSERT INTO ' || quote_ident(atopology)
		|| '.node(node_id, containing_face, geom) 
		VALUES(' || nodeid || ',' || coalesce(containing_face::text, 'NULL')
    || ',$1) RETURNING node_id' USING apoint INTO nodeid;

	RETURN nodeid;
	
END
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION topology.addnode(character varying, geometry, boolean, boolean)
  OWNER TO postgres;
COMMENT ON FUNCTION topology.addnode(character varying, geometry, boolean, boolean) IS 'args: toponame, apoint, allowEdgeSplitting=false, computeContainingFace=false - Adds a point node to the node table in the specified topology schema and returns the nodeid of new node. If point already exists as node, the existing nodeid is returned.';
