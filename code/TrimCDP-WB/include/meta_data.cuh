#ifndef _H_META_DATA_
#define _H_META_DATA_

#include "header.h"
#include "util.h"
// #include "mapper_enactor.cuh"

class meta_data
{
public:
	/*traversal*/
	feature_t *vert_status;
	feature_t *vert_status_prev;
	feature_t *record; // 记录了SSSP任务后的状态
	feature_t *lb_record;
	feature_t *in_queue;
	feature_t *temp_st;
	bit_t *bitmap;
	int width;
	// For debug
	feature_t *sa_chk;
	index_t *sml_count_chk;
	index_t *mid_count_chk;
	index_t *lrg_count_chk;
	int *lb0;
	volatile int *best;
	index_t *future_work;

	/*reducer*/
	index_t *cat_thd_count_sml;
	index_t *cat_thd_count_mid;
	index_t *cat_thd_count_lrg;
	index_t *cat_thd_off_sml;
	index_t *cat_thd_off_mid;
	index_t *cat_thd_off_lrg;

	index_t *cat_thd_count_h;
	index_t *cat_thd_off_h;
	index_t *scan_temp_sml; // store block sum
	index_t *scan_temp_mid; // store block sum
	index_t *scan_temp_lrg; // store block sum
	
	/*merge worklist counting*/
	index_t *cat_thd_count_merge;
	index_t *cat_thd_off_merge;
	index_t *scan_temp_merge; // store block sum

	/*worklist*/
	vertex_t *worklist_sml;
	vertex_t *worklist_mid;
	vertex_t *worklist_lrg;
	vertex_t *new_worklist_sml;
	vertex_t *new_worklist_mid;
	vertex_t *new_worklist_lrg;
	// vertex_t *worklist_sz_sml_d;
	// vertex_t *worklist_sz_mid_d;
	// vertex_t *worklist_sz_lrg_d;

	/*merge worklist*/
	vertex_t *worklist_merge;
	volatile vertex_t *worklist_sz_merge;

	/*thread bin
	 * - for generate frontier queue while map
	 *   instead of scan and generate frontier queue
	 * */
	vertex_t *worklist_bin;
	unsigned int *max_queue_size;
	volatile vertex_t *worklist_sz_sml;
	volatile vertex_t *worklist_sz_mid;
	volatile vertex_t *worklist_sz_lrg;
	volatile vertex_t *new_worklist_sz_sml;
	volatile vertex_t *new_worklist_sz_mid;
	volatile vertex_t *new_worklist_sz_lrg;
	/*stream*/
	cudaStream_t *stream;

	/*大度数节点分割映射*/
	vertex_t *son;    // 节点映射到子节点（大度数节点映射到子节点，其他节点映射到自己）
	vertex_t *mother; // 子节点映射到父节点（大度数节点的子节点映射到大度数节点，其他节点映射到自己）
	
	/*大度数节点分割映射扩展*/
	index_t *son_range_start;  // 每个节点的子节点范围起始位置
	vertex_t *son_list;        // 所有子节点的列表

public:
	~meta_data() {}
	meta_data(
		vertex_t vert_count,
		index_t edge_count, int wid)
	{
		const size_t VERT_SZ = sizeof(vertex_t) * vert_count;
		const size_t FEAT_SZ = sizeof(feature_t) * vert_count;
		const size_t BIT_SZ = sizeof(bit_t) * (((vert_count) >> 3) + 1);
		const size_t CATE_SZ = sizeof(index_t) * BLKS_NUM * THDS_NUM;

		// int blk_size = 256;
		// int grd_size = 256;

		width = wid;
		// Because thread bin is only used by the smaller kernel
		// cudaOccupancyMaxPotentialBlockSize(&grd_size, &blk_size,
		//	mapper_merge_push_kernel, 0, 0);
		const size_t GBIN_SZ = sizeof(vertex_t) * BLKS_NUM * THDS_NUM * BIN_SZ;
		assert(THDS_NUM <= 1024);
		H_ERR(cudaMalloc((void **)&vert_status, FEAT_SZ * width));
		H_ERR(cudaMalloc((void **)&vert_status_prev, FEAT_SZ * width));
		H_ERR(cudaMalloc((void **)&temp_st, FEAT_SZ));
		H_ERR(cudaMalloc((void **)&lb_record, FEAT_SZ * width)); // for compute
		H_ERR(cudaMalloc((void **)&record, FEAT_SZ * width));	 // one label
		H_ERR(cudaMalloc((void **)&lb0, FEAT_SZ * width));		 // w1 w2
		H_ERR(cudaMalloc((void **)&in_queue, FEAT_SZ * width));
		H_ERR(cudaMalloc((void **)&bitmap, BIT_SZ));
		H_ERR(cudaMemset(bitmap, 0, BIT_SZ));
		cudaMallocManaged((void **)&max_queue_size, sizeof(unsigned int));
		// Thread-bin for frontier generation
		H_ERR(cudaMalloc((void **)&worklist_bin, GBIN_SZ));

		// H_ERR(cudaMalloc((void **)&worklist_sz, sizeof(vertex_t)));
		// Workload balancing: count, prefix and collect.
		H_ERR(cudaMalloc((void **)&worklist_sml, VERT_SZ * width));
		H_ERR(cudaMalloc((void **)&worklist_mid,0.5* VERT_SZ * width));
		H_ERR(cudaMalloc((void **)&worklist_lrg, 0.5*VERT_SZ * width));
		// H_ERR(cudaMalloc((void **)&new_worklist_sml, VERT_SZ * width));
		// H_ERR(cudaMalloc((void **)&new_worklist_mid, VERT_SZ * width));
		// H_ERR(cudaMalloc((void **)&new_worklist_lrg, VERT_SZ * width));
		
		// Allocate merge worklist
		H_ERR(cudaMalloc((void **)&worklist_merge, VERT_SZ * width));
		H_ERR(cudaMalloc((void **)&worklist_sz_merge, sizeof(vertex_t)));
		H_ERR(cudaMalloc((void **)&cat_thd_count_sml, CATE_SZ));
		H_ERR(cudaMalloc((void **)&cat_thd_count_mid, CATE_SZ));
		H_ERR(cudaMalloc((void **)&cat_thd_count_lrg, CATE_SZ));
		H_ERR(cudaMalloc((void **)&cat_thd_off_sml, CATE_SZ));
		H_ERR(cudaMalloc((void **)&cat_thd_off_mid, CATE_SZ));
		H_ERR(cudaMalloc((void **)&cat_thd_off_lrg, CATE_SZ));

		// maybe should be size of BLKS_NUM only!
		H_ERR(cudaMalloc((void **)&scan_temp_sml, CATE_SZ));
		H_ERR(cudaMalloc((void **)&scan_temp_mid, CATE_SZ));
		H_ERR(cudaMalloc((void **)&scan_temp_lrg, CATE_SZ));
		
		// Allocate merge worklist counting variables
		H_ERR(cudaMalloc((void **)&cat_thd_count_merge, CATE_SZ));
		H_ERR(cudaMalloc((void **)&cat_thd_off_merge, CATE_SZ));
		H_ERR(cudaMalloc((void **)&scan_temp_merge, CATE_SZ));

		// verification purpose
		H_ERR(cudaMallocHost((void **)&cat_thd_count_h, CATE_SZ));
		H_ERR(cudaMallocHost((void **)&cat_thd_off_h, CATE_SZ));

		// maybe should be size of BLKS_NUM only!
		H_ERR(cudaMalloc((void **)&worklist_sz_sml, sizeof(vertex_t)));
		H_ERR(cudaMalloc((void **)&worklist_sz_mid, sizeof(vertex_t)));
		H_ERR(cudaMalloc((void **)&worklist_sz_lrg, sizeof(vertex_t)));
		H_ERR(cudaMalloc((void **)&new_worklist_sz_sml, sizeof(vertex_t)));
		H_ERR(cudaMalloc((void **)&new_worklist_sz_mid, sizeof(vertex_t)));
		H_ERR(cudaMalloc((void **)&new_worklist_sz_lrg, sizeof(vertex_t)));
		H_ERR(cudaMalloc((void **)&best, sizeof(vertex_t)));

		// for frontier queue size report
		// Allocated on CPU, mapped to GPU
		// H_ERR(cudaHostAlloc((void **)&worklist_sz_sml,
		//			sizeof(index_t),cudaHostAllocMapped));
		// H_ERR(cudaHostGetDevicePointer((void **)&worklist_sz_sml_d,
		//			worklist_sz_sml,0));
		// H_ERR(cudaHostAlloc((void **)&worklist_sz_mid,
		//			sizeof(index_t),cudaHostAllocMapped));
		// H_ERR(cudaHostGetDevicePointer((void **)&worklist_sz_mid_d,
		//			worklist_sz_mid,0));
		// H_ERR(cudaHostAlloc((void **)&worklist_sz_lrg,
		//			sizeof(index_t),cudaHostAllocMapped));
		// H_ERR(cudaHostGetDevicePointer((void **)&worklist_sz_lrg_d,
		//			worklist_sz_lrg,0));

		stream = (cudaStream_t *)malloc(sizeof(cudaStream_t) * 3);
		for (index_t i = 0; i < 3; ++i)
			H_ERR(cudaStreamCreate(&(stream[i])));

		H_ERR(cudaMallocHost((void **)&sa_chk, FEAT_SZ));
		H_ERR(cudaMallocHost((void **)&sml_count_chk, CATE_SZ));
		H_ERR(cudaMallocHost((void **)&mid_count_chk, CATE_SZ));
		H_ERR(cudaMallocHost((void **)&lrg_count_chk, CATE_SZ));

		H_ERR(cudaMalloc((void **)&future_work, sizeof(index_t)));

		// 为大度数节点分割分配映射数组
		H_ERR(cudaMalloc((void **)&son, sizeof(vertex_t) * vert_count));
		H_ERR(cudaMalloc((void **)&mother, sizeof(vertex_t) * vert_count));
		
		// 为大度数节点分割扩展映射分配GPU内存
		H_ERR(cudaMalloc((void **)&son_range_start, sizeof(index_t) * vert_count));
		H_ERR(cudaMalloc((void **)&son_list, sizeof(vertex_t) * vert_count));
	}
	void release()
	{
		cudaFree(vert_status);
		cudaFree(vert_status_prev);
		cudaFree(worklist_lrg);
		cudaFree(worklist_mid);
		cudaFree(worklist_sml);
		cudaFree(new_worklist_lrg);
		cudaFree(new_worklist_mid);
		cudaFree(new_worklist_sml);
		cudaFree(worklist_bin);
		cudaFree(worklist_merge);
		cudaFree(temp_st);
		cudaFree(record);
		cudaFree(lb_record);
		cudaFree(in_queue);
		cudaFree(son);
		cudaFree(mother);
		cudaFree(son_range_start);
		cudaFree(son_list);
	}
};

#endif
