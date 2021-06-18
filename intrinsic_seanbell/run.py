#!/usr/bin/env python2.7
import os, sys
import multiprocessing
import pickle
import time
import argparse

import numpy as np

try:
    from bell2014.krahenbuhl2013.krahenbuhl2013 import DenseCRF
except ImportError:
    print ""
    print "Error: cannot import 'bell2014.krahenbuhl2013'."
    print ""
    print "This is a custom C++ extension and can be compiled with:"
    print ""
    print "    cd %s" % os.path.join(os.path.dirname(os.path.abspath(__file__)), 'krahenbuhl2013')
    print "    make"
    sys.exit(1)

from bell2014.solver import IntrinsicSolver
from bell2014.input import IntrinsicInput
from bell2014.params import IntrinsicParameters
from bell2014 import image_util


class Decompose(object):
    def __init__(self, dataset_name, dataset_root, out_dir):
        self.dataset = dataset_name
        if self.dataset == "BigTime_v1":
            self.dataset_root = dataset_root
            self.list_file = os.path.join(self.dataset_root, "train_test_split/test_list_by_Jundan.p")
            if not self._check_exists([self.dataset_root, self.list_file]):
                raise RuntimeError("BigTime_v1 dataset is not found or not complete in the path: %s " %
                                   self.dataset_root)
            self.data_list = pickle.load(open(self.list_file, "rb"))
        else:
            raise Exception("Not support dataset: %s" % self.dataset)

        self.out_dir = out_dir
        if not os.path.exists(self.out_dir):
            os.makedirs(self.out_dir)

    def _check_exists(self, paths):
        flag = True
        for p in paths:
            flag = flag and os.path.exists(p)
        return flag

    def decompose_image(self, image_filename, mask_filename, r_filename, s_filename, save_raw=False, quiet=False):
        print '\nInput:'
        print '  image_filename:', image_filename
        print '  mask_filename:', mask_filename
        print 'Output:'
        print '  r_filename:', r_filename
        print '  s_filename:', s_filename
        # sRGB
        sRGB = True
        # load input
        input = IntrinsicInput.from_file(
            image_filename,
            image_is_srgb=sRGB,
            mask_filename=mask_filename,
            judgements_filename=None,
        )
        # load parameters
        params = IntrinsicParameters()
        # log
        params.logging = not quiet
        # solve
        solver = IntrinsicSolver(input, params)
        r, s, decomposition = solver.solve()
        # save output
        image_util.save(r_filename, r, mask_nz=input.mask_nz, rescale=True, srgb=sRGB)
        image_util.save(s_filename, s, mask_nz=input.mask_nz, rescale=True, srgb=sRGB)
        if save_raw:
            np.save(r_filename.rpartition('.')[0] + ".npy", r)
            print "save predicted reflectance: " + r_filename.rpartition('.')[0] + ".npy"
            np.save(s_filename.rpartition('.')[0] + ".npy", s)
            print "save predicted shading: " + s_filename.rpartition('.')[0] + ".npy"

    def decompose_BigTime_v1(self, index):
        print "\nProcess %d ......" % index
        path_list = self.data_list[index]
        st = time.time()
        for i in range(len(path_list)):  # decompose all the images of one sequence
            print "\nDecompose %d-%d/%d ......" % (index, i+1, len(path_list))
            # image path
            scene_id, img_name = path_list[i].split('/')
            srgb_img_relative_path = os.path.join(scene_id, "data", img_name)
            srgb_img_path = os.path.join(self.dataset_root, srgb_img_relative_path)
            mask_relative_path = os.path.join(scene_id, "data", img_name[:-4] + "_mask.png")
            mask_path = os.path.join(self.dataset_root, mask_relative_path)
            # decompose
            out_r_image_path = os.path.join(self.out_dir, srgb_img_relative_path[:-4] + "-r.png")
            out_s_image_path = os.path.join(self.out_dir, srgb_img_relative_path[:-4] + "-s.png")
            self.decompose_image(srgb_img_path, mask_path, out_r_image_path, out_s_image_path, True, True)
            # cmd = "python bell2014/decompose.py %s -m %s -r %s -s %s --save-raw -q" % \
            #       (srgb_img_path, mask_path, out_r_image_path, out_s_image_path)
            # # print cmd
            # rt = os.system(cmd)
            # if rt != 0:
            #     self.log.info("Decomposition is not finished : %s" % cmd)
            #     return False
            print "\nDecompose %d-%d/%d %s: %.3f s" % (index, i+1, len(path_list), srgb_img_path, time.time() - st)
            st = time.time()
        return True

    def __len__(self):
        if self.dataset == "BigTime_v1":
            return len(self.data_list)
        else:
            raise Exception("Not support dataset: %s" % self.dataset)

    def run_one(self, index):
        if self.dataset == "BigTime_v1":
            return self.decompose_BigTime_v1(index)
        else:
            raise Exception("Index %d: not support dataset: %s" % (index, self.dataset))

    def run_all(self, start=0):
        flag = True
        for index in range(start, len(self)):
            flag = flag and self.run_one(index)
            if flag:
                print "Finish: %d/%d" % (index+1, len(self))
            else:
                print "Decomposing index %d failed!" % index
                return flag
        return flag


def f(index):
    global D
    return index, D.run_one(index)
    # time.sleep(random.random() * 5)
    # print index
    # return index, True


def run(num_workers, start=0):
    global D
    print "\nMultiple threads: %d" % num_workers
    pool = multiprocessing.Pool(processes=num_workers)

    waiting_list = set(range(start, len(D)))
    finished = set(range(start))
    for index, flag in pool.imap_unordered(f, range(start, len(D))):
        if flag:
            finished.add(index)
            waiting_list.remove(index)
            print "\nFinish: %d/%d" % (len(finished), len(D))
            print "Waiting list:"
            print "\t%s" % sorted(waiting_list)
        else:
            print "\nDecomposing index %d failed!" % index
            pool.terminate()
            return False
    pool.close()
    pool.join()
    return True


D = None
if __name__ == '__main__':
    DATASETS = ["BigTime_v1"]

    # obtain arguments
    parser = argparse.ArgumentParser(description="Decompose all the images in the dataset.")
    parser.add_argument(
        '--dataset', metavar='<file>', type=str,
        help='Dataset name: %s' % DATASETS, required=False, default="BigTime_v1"
    )
    parser.add_argument(
        '--root', metavar='<file>', type=str,
        help='Root directory for all the datasets', required=False, default="../dataset/"
    )
    parser.add_argument(
        '--out-dir', metavar='<file>', type=str,
        help='Output directory for predictions', required=False, default="./predictions"
    )
    parser.add_argument(
        '-mp', '--multiprocessing', metavar='<N>', type=int,
        help='Number of processing', required=True,
    )
    parser.add_argument(
        '-st', '--start-index', metavar='<N>', type=int,
        help='The first index to be processed', required=False, default=0,
    )
    args = parser.parse_args()

    root = args.root
    dataset = args.dataset
    assert dataset in DATASETS
    if dataset == "BigTime_v1":
        dataset_dir = os.path.join(root, "BigTime_v1_resized/")
    else:
        raise Exception("Not support dataset: %s" % dataset)
    out_dir = args.out_dir
    mp = args.multiprocessing
    assert mp > 0
    st = args.start_index
    assert st >= 0

    D = Decompose(dataset, dataset_dir, os.path.join(out_dir, dataset))
    if mp == 1:
        flag = D.run_all(st)
    else:
        flag = run(mp, st)

    if flag:
        print "\nDecompose %s successfully!" % dataset
    else:
        print "\nDecomposing %s failed!" % dataset



