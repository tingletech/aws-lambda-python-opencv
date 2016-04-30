#!/bin/bash

if [[ -n "$DEBUG" ]]; then 
  set -x
fi

set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions
set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
set -o errexit   ## set -e : exit the script if any statement returns a non-true return value

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # http://stackoverflow.com/questions/59895
cd $DIR

if [[ ! -e ve27 ]]
  then
    virtualenv --python python2.7 ve27
fi

set +u
. ve27/bin/activate
set -u

rm -rf build lambda-package

# Setting up build env
# sudo yum update -y
# sudo yum install -y git cmake gcc-c++ gcc python-devel chrpath
mkdir lambda-package lambda-package/cv2 build build/numpy

# Build numpy
pip install --install-option="--prefix=$PWD/build/numpy" numpy
cp -rf build/numpy/lib64/python2.7/site-packages/numpy lambda-package

export PYTHONPATH=$DIR/lambda-package/

# Build OpenCV 3.1
(
	NUMPY=$PWD/lambda-package/numpy/core/include
	cd build
	git clone https://github.com/Itseez/opencv.git
	cd opencv
	git checkout 3.1.0
	cmake						\
		-D CMAKE_BUILD_TYPE=RELEASE		\
		-D WITH_TBB=ON				\
		-D WITH_IPP=ON				\
		-D WITH_V4L=ON				\
		-D ENABLE_AVX=ON			\
		-D ENABLE_SSSE3=ON			\
		-D ENABLE_SSE41=ON			\
		-D ENABLE_SSE42=ON			\
		-D ENABLE_POPCNT=ON			\
		-D ENABLE_FAST_MATH=ON			\
		-D BUILD_EXAMPLES=OFF			\
		-D PYTHON2_NUMPY_INCLUDE_DIRS="$NUMPY"	\
                -D BUILD_opencv_java=OFF               \
		.
	make
)
cp build/opencv/lib/cv2.so lambda-package/cv2/__init__.so
cp -L build/opencv/lib/*.so.3.1 lambda-package/cv2
strip --strip-all lambda-package/cv2/*
chrpath -r '$ORIGIN' lambda-package/cv2/__init__.so
touch lambda-package/cv2/__init__.py

# Copy template function and zip package
cp template.py lambda-package/lambda_function.py
cd lambda-package
zip -r ../lambda-package.zip *
