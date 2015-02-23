#!/bin/bash

yrs="PAPER"

cns="B1
     B2
     B3
     B4
     B5
     B6_VCID_1
     B6_VCID_2
     B7
     B8"

toas="red
      green
      blue
      nir
      swir1
      swir2"

MONOMASK="./MASK/zapoved.shp" 
MULTMASK="./MASK/zapoved.shp" 
LANDSAT7MASK="./MASK/landsat.shp" 


function landsat7gap_mask(){
    gzip -d ./$yr/$step/gap_mask/*.TIF.gz

    for cn in $cns
    do
        if [ -f ./$yr/$step/gap_mask/${nam}_GM_${cn}.TIF ]; then

            echo masking - ${nam}_${cn}

            gdal_fillnodata.py -mask ./$yr/$step/gap_mask/${nam}_GM_${cn}.TIF -of GTiff \
                ./$yr/$step/${nam}_${cn}.TIF \
                ./$yr/$step/${nam}_${cn}_mask.TIF

            mkdir -p ./$yr/$step/backup/gap_mask
            mv ./$yr/$step/${nam}_${cn}.TIF ./$yr/$step/backup/${nam}_${cn}.TIF
            mv ./$yr/$step/gap_mask/${nam}_GM_${cn}.TIF ./$yr/$step/backup/gap_mask/${nam}_GM_${cn}.TIF
            
            gdalwarp -cutline $LANDSAT7MASK -crop_to_cutline \
                ./$yr/$step/${nam}_${cn}_mask.TIF \
                ./$yr/$step/${nam}_${cn}.TIF

            rm -f ./$yr/$step/${nam}_${cn}_mask.TIF
        fi
    done
        gzip -a ./$yr/$step/backup/gap_mask/*.TIF
        rmdir ./$yr/$step/gap_mask
}


function normalization(){
    echo normalization scene - ${mtl}
    /usr/bin/python2 calc_norm.py ./$yr/$step/$mtl ./horizons_results.txt
}


function cut_mask(){
    for toa in $toas
    do
        echo cut to mask - ${nam}_${toa}

        gdalwarp -cutline $MONOMASK -crop_to_cutline \
            ./$yr/$step/${toa}.tif \
            ./$yr/$step/${toa}_mono.tif
        gdalwarp -cutline $MULTMASK -crop_to_cutline \
            ./$yr/$step/${toa}.tif \
            ./$yr/$step/${toa}_mult.tif

        rm -f ./$yr/$step/${toa}.tif
        mv ./$yr/$step/${toa}_mono.tif ./$yr/$step/${toa}.tif
    done
}


function multi_raster(){
    echo create multiraster
    gdal_merge.py ./$yr/$step/red_mult.tif \
                    ./$yr/$step/green_mult.tif \
                    ./$yr/$step/blue_mult.tif \
                    ./$yr/$step/nir_mult.tif \
                    ./$yr/$step/swir1_mult.tif \
                    ./$yr/$step/swir2_mult.tif \
                    -o ./$yr/$step/multichannel.tif -separate

    rm ./$yr/$step/red_mult.tif
    rm ./$yr/$step/green_mult.tif
    rm ./$yr/$step/blue_mult.tif
    rm ./$yr/$step/nir_mult.tif
    rm ./$yr/$step/swir1_mult.tif
    rm ./$yr/$step/swir2_mult.tif
}


function index(){
    echo normalization scene - ${mtl}
    /usr/bin/python2 calc_raster.py ./$yr/$step
}


for yr in $yrs
do
    steps=`ls -1 ./${yr}`

    for step in $steps
    do
        mtl=`ls ./$yr/$step | grep _MTL.txt`
        echo $mtl
        nam=`echo ${mtl}| awk -F "_" '{print $1}'`

        echo $yr
        echo $step
        echo $nam

        #gap mask for lansat 7
        landsat7gap_mask

        #Lansat normalization
        normalization

        #cut raster to mask
        cut_mask

        #multichannel raster
        multi_raster

        #sreate indexs
        index

    done
done
