#!/usr/bin/sh
# GNU Compilation of WRF dependencies

#We need install some application for installation.

sudo apt install gfortran
sudo apt install m4
sudo apt install csh
sudo apt install git

#mkdir Library
#DIR=$PWD/Library

mkdir wrf_dependencies
DIR=$PWD/wrf_dependencies

# These only need to be set again in new shell environments if using the older make build system
export NETCDF=$DIR/netcdf
export LD_LIBRARY_PATH=$NETCDF/lib:$DIR/grib2/lib

# Set these again in any new shell environment to build and run WRF
export PATH=$NETCDF/bin:$DIR/mpich/bin:${PATH}
export JASPERLIB=$DIR/grib2/lib
export JASPERINC=$DIR/grib2/include

# Use these ONLY when building these dependencies. These SHOULD NOT be set when building WRF or WPS
export CC=gcc
export CXX=g++
export FC=gfortran
export FCFLAGS="-m64 -fallow-argument-mismatch"
export F77=gfortran
export FFLAGS="-m64 -fallow-argument-mismatch"
export LDFLAGS="-L$NETCDF/lib -L$DIR/grib2/lib"
export CPPFLAGS="-I$NETCDF/include -I$DIR/grib2/include -fcommon"

export WRF_DEP_JOBS=16


wget https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/zlib-1.2.11.tar.gz
tar xzvf zlib-1.2.11.tar.gz
cd zlib-1.2.11
./configure --prefix=$DIR/grib2
make -j $WRF_DEP_JOBS
make install
cd ..
rm -rf zlib*

wget https://github.com/HDFGroup/hdf5/archive/hdf5-1_10_5.tar.gz
tar xzvf hdf5-1_10_5.tar.gz
cd hdf5-hdf5-1_10_5
./configure --prefix=$DIR/netcdf --with-zlib=$DIR/grib2 --enable-fortran --enable-shared
make -j $WRF_DEP_JOBS
make install
cd ..
rm -rf hdf5*


wget https://github.com/Unidata/netcdf-c/archive/v4.7.2.tar.gz
tar xzvf v4.7.2.tar.gz
cd netcdf-c-4.7.2
./configure --prefix=$DIR/netcdf --disable-dap --enable-netcdf-4 --enable-hdf5 --enable-shared
make -j $WRF_DEP_JOBS
make install
cd ..
rm -rf v4.7.2.tar.gz netcdf-c*

export PATH=$DIR/netcdf/bin:$PATH
export NETCDF=$DIR/netcdf

export LIBS='-lnetcdf -lz'
wget https://github.com/Unidata/netcdf-fortran/archive/v4.5.2.tar.gz
tar xzvf v4.5.2.tar.gz
cd netcdf-fortran-4.5.2
./configure --prefix=$DIR/netcdf --disable-hdf5 --enable-shared
make -j $WRF_DEP_JOBS
make install
cd ..
rm -rf netcdf-fortran* v4.5.2.tar.gz

wget https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/mpich-3.0.4.tar.gz
tar -xf mpich-3.0.4.tar.gz
cd mpich-3.0.4
./configure --prefix=$DIR/mpich
make -j $WRF_DEP_JOBS 
make install
cd ..
rm -rf mpich*

wget https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/libpng-1.2.50.tar.gz
tar xzvf libpng-1.2.50.tar.gz
cd libpng-1.2.50
./configure --prefix=$DIR/grib2
make -j $WRF_DEP_JOBS
make install
cd ..
rm -rf libpng*

wget https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/jasper-1.900.1.tar.gz
tar xzvf jasper-1.900.1.tar.gz
cd jasper-1.900.1
./configure --prefix=$DIR/grib2
make
make install
cd ..
rm -rf jasper* ._jasper-1.900.1

#WRF installation
git clone --recurse-submodule https://github.com/wrf-model/WRF.git
cd WRF
./configure #(choose options 34 and 1)
./compile em_real -j 4 2>&1 | tee log.compile

#WPS installation
git clone https://github.com/wrf-model/WPS.git
cd WPS
export WRF_DIR=$DIR/WRF
./configure
./compile 2>&1 | tee log.compile



# After this in a new shell you should redo the environment settings found at the top of this script
nano ~/.bashrc

export NETCDF=$DIR/netcdf
export LD_LIBRARY_PATH=$NETCDF/lib:$DIR/grib2/lib
export PATH=$NETCDF/bin:$DIR/mpich/bin:${PATH}
export JASPERLIB=$DIR/grib2/lib
export JASPERINC=$DIR/grib2/include

source ~/.bashrc