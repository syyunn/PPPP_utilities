﻿---------------------------------------------
--Copyright Remi-C Thales IGN 05/2015
-- 
--this function use python helper function to spatially cluster points
--------------------------------------------

--SET search_path to  public  ;
--a plpython predicting gt_class, cross_validation , result per class
--gids,feature_iar,gt_classes ,labels,class_list,k_folds,random_forest_ntree, plot_directory
DROP FUNCTION IF EXISTS rc_py_cluster_points( igid int[], dat FLOAT[] ,ncluster int, max_iter INT );
CREATE FUNCTION rc_py_cluster_points( igid int[],dat FLOAT[] ,ncluster int, max_iter INT DEFAULT 300)
RETURNS table(gid int, label int)
AS $$"""
This function plot the histogram at the given path
"""
import numpy as np
from scipy import cluster
from sklearn import cluster
data_iar = np.array( dat, dtype=np.float)
gids = np.array( igid, dtype=np.int32)
vector_points = np.reshape( data_iar,( len(data_iar)/2,2 )) ; 

#centroid, label = cluster.vq.kmeans2(vector_points, ncluster, iter=10000, thresh=0, minit='random', missing='warn')
kmean = cluster.KMeans(n_clusters=ncluster, init='k-means++', n_init=10, max_iter=max_iter, tol=0.0001, precompute_distances='auto', verbose=0, random_state=None, copy_x=True, n_jobs=1)
label = kmean.fit_predict(vector_points)
result = [] 
for i in range(0,len(label)):
    result.append(( (gids[i]) , (label[i]) )) ; 
return result;
$$ LANGUAGE plpythonu IMMUTABLE STRICT; 


--a plpython predicting gt_class, cross_validation , result per class
--gids,feature_iar,gt_classes ,labels,class_list,k_folds,random_forest_ntree, plot_directory
DROP FUNCTION IF EXISTS rc_py_cluster_points_dbscan( igid int[], dat FLOAT[] , iweight FLOAT[] , ndim int,  max_dist float, min_sample int );
CREATE OR REPLACE FUNCTION rc_lib.rc_py_cluster_points_dbscan( igid int[],dat FLOAT[] ,  ndim int,max_dist float, min_sample int )
RETURNS table(gid int, label int)
AS $$"""
This function ake input, 
"""
import numpy as np
from scipy import cluster
from sklearn import cluster
data_iar = np.array( dat, dtype=np.float)
gids = np.array( igid, dtype=np.int32)
#weight = np.array(iweight, dtype=np.float)
vector_points = np.reshape( data_iar,( len(data_iar)/ndim, ndim )) ; 

clust = cluster.DBSCAN(eps=max_dist, min_samples=min_sample, metric='euclidean', algorithm='auto', leaf_size=30, p=None, random_state=None) #, sample_weight=weight) 
label = clust.fit_predict(vector_points)
result = [] 
for i in range(0,len(label)):
    result.append(( (gids[i]) , (label[i]) )) ; 
return result;
$$ LANGUAGE plpythonu IMMUTABLE STRICT; 




DROP FUNCTION IF EXISTS rc_py_weighted_median( val FLOAT[] , weight FLOAT[] );
CREATE FUNCTION rc_py_weighted_median( val FLOAT[] , weight FLOAT[], OUT weighted_median FLOAT)
AS $$"""
This function take a list of values and wieght, are return the weighted median
require weightedstats
""" 
import numpy as np
import weightedstats as ws
val_ = np.array( val, dtype=np.float)
weight_ = np.array( weight, dtype=np.float) 
weighted_median = ws.numpy_weighted_median(val_, weights=weight_)
return weighted_median
$$ LANGUAGE plpythonu IMMUTABLE STRICT; 
