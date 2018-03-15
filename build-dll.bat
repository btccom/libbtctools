mkdir build-dll
cd build-dll

cmake -DBTCTOOLS__LIB_TYPE=SHARED -DBTCTOOLS__STATIC_LINKING_VC_LIB=ON -T v141_xp ..

pause
