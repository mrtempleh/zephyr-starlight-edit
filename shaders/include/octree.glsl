#ifndef INCLUDE_OCTREE
    #define INCLUDE_OCTREE

    bool isLeaf (ivec3 pos, uint level) 
    {
        return imageLoad(voxelBufferLod, (pos + ivec3(voxelVolumeSize.x, 0, 0)) >> level).r == 0u;
    }

#endif