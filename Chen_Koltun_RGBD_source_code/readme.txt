Instructions to run the program:

1. The source code requires VLFeat library and please download it from www.vlfeat.org. 
2. Change the path in line 1 in "demo.m" correspondingly and run "demo.m" in Matlab for demonstration.
3. In the folder "data", "im????.png" and "Z????.mat" are a pair of input image and depth image. Please add your examples in the same naming convention.
4. The variable "index" in line 5 in "demo.m" gives the indices of images to process.
5. The output images are stored in the folder "output".

Important notes:
1. The resolutions of example images are expected to be 480x640. If you use other resolutions, please change the horizontal field of view in line 10 in "demo.m".
2. The program requires about 7Gb of memory. Make sure you have enough available memory before running the program.
3. "Z????.mat" contains a depth map "Z" which has the same size as the color image. The value of "Z" gives the distance to the image plane in meters, so the range for "Z" is 0.5-10. Please make sure your depth map falls in this range and depth values are available for all the pixels.
4. If you think the result is not good enough, you can try to tune the following parameters in these ranges in line 81:
direct irradiance	w(3): [0.1, 1]
indirect irradiance w(4): [0.1, 1]
simple regularizer	w(5): [0.01, 0.1]
5. The code in the folder "preprocessing" is a preprocessing step to improve the quality of RGB images and fill in holes in depth images.
See "preprocessing.m" in "preprocessing/RGB" and "fill_depth_colorization.m" in "preprocessing/Depth".

If you have any question about the implementation, please email to cqf@stanford.edu.
