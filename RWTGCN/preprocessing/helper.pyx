import numpy as np
import pandas as pd
import os, json
import random
import scipy.sparse as sp
from libc.math cimport log
import time

def random_walk(spadj, walk_dir_path, freq_dir_path, f_name, int walk_length, int walk_time, bint weight):
    t1 = time.time()
    node_num = spadj.shape[0]
    cdef int iter
    cdef int nd_num = node_num
    cdef int nidx
    cdef int seq_len
    cdef int i
    cdef int j
    cdef int cnt = 1
    cdef int walk_len = walk_length + 1

    spadj = spadj.tolil()
    node_neighbor_arr = spadj.rows
    node_weight_arr = spadj.data
    walk_spadj = sp.lil_matrix((node_num, node_num))
    node_freq_arr = np.zeros(node_num, dtype=int)

    weight_arr_dict = dict()
    # random walk
    for nidx in range(nd_num):
        for iter in range(walk_time):
            eps = 1e-8
            walk = [nidx]
            cnt = 1
            while cnt < walk_len:
                cur = walk[-1]
                neighbor_list = node_neighbor_arr[cur]
                if cur not in weight_arr_dict:
                    weight_arr = np.array(node_weight_arr[cur])
                    weight_arr = weight_arr / weight_arr.sum()
                    weight_arr_dict[cur] = weight_arr
                else:
                    weight_arr = weight_arr_dict[cur]
                if len(neighbor_list) == 0:
                    break
                nxt_id = np.random.choice(neighbor_list, p=weight_arr) if weight else np.random.choice(neighbor_list)
                walk.append(int(nxt_id))
                cnt += 1
            # count walk pair
            seq_len = len(walk)
            for i in range(seq_len):
                for j in range(i + 1, seq_len):
                    if walk[i] == walk[j]:
                        continue
                    from_id, to_id = walk[i], walk[j]
                    if j - i <= 2:
                        walk_spadj[i, j] = 1
                        walk_spadj[j, i] = 1
                    node_freq_arr[from_id] += 1
                    node_freq_arr[to_id] += 1
    t2 = time.time()
    print('random walk time: ', t2 - t1, ' seconds!')

    tot_freq = node_freq_arr.sum()
    Z = 0.00001
    neg_node_list = []
    for nidx in range(nd_num):
        rep_num = int(((node_freq_arr[nidx]/tot_freq)**0.75)/ Z)
        neg_node_list += [nidx] * rep_num
    walk_file_path = os.path.join(freq_dir_path, f_name.split('.')[0] + '.json')
    with open(walk_file_path, 'w') as fp:
        json.dump(neg_node_list, fp)
    del neg_node_list, node_freq_arr
    t3 = time.time()
    print('node freq time: ', t3 - t2, ' seconds!')

    # walk pair set don't store reverse edge
    walk_file_path = os.path.join(walk_dir_path, f_name.split('.')[0] + '.npz')
    sp.save_npz(walk_file_path, walk_spadj.tocoo())
    t4 = time.time()
    print('walk pair time: ', t4 - t3, ' seconds!')