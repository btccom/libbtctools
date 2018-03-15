mkdir build-static
cd build-static

cmake -DBTCTOOLS__LIB_TYPE=STATIC -DBTCTOOLS__STATIC_LINKING_VC_LIB=ON -T v141_xp ..

pause
