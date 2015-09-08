#!/bin/bash
#Script
# First check than remove ghost test files in result directory 
# which produced during not thread safe simulations

RESULTS_DIR="./results" 
for i in "$@"
do
case $i in
    -dir)
    shift
    ((i++))
    RESULTS_DIR=${!i}
    shift 
    ;;
esac
done

for filepath in $PWD/$RESULTS_DIR/*.json; do
    filename="$(basename $filepath)"

    #stxxxxCPPJIT.json
    if [[ $filename == *"st20"* ]] && [[ $filename == *"CPPJIT"* ]]; then
	OUT=$(./test.sh -t StateTests -file $filepath --cpp)
	if [ "$OUT" != "" ]; then
	    echo "Error Confirmed: $filename"
	    echo "Output: $OUT"
	else
	    rm $filepath
	fi
    fi

    #stxxxxFILL.json
    if [[ $filename == *"st20"* ]] && [[ $filename == *"FILL"* ]]; then
	OUT=$(./test.sh -t StateTests -filltest $filepath --cpp)	
	if [ "$OUT" != "" ]; then
	    echo "Error Confirmed: "$filename
	     echo "Output: $OUT"
	else
	    rm $filepath
	fi
    fi

done

