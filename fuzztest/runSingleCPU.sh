#!/bin/bash

#Options
PY_ETHEREUM_PATH="/home/ubuntu/pyethereum"
CPP_ETHEREUM_PATH="/home/ubuntu/cpp-ethereum"
GO_ETHEREUM_PATH="/home/ubuntu/go-ethereum"
LOG_DIR="/home/ubuntu/runTests/results"
LOG_ENABLE=0 #enables output to the file
export PYTHONPATH=$PYTHONPATH:~/software/Ethereum/pyethereum
#options

export EVMJIT="-cache=0"
LOG_FILE="$LOG_DIR/log"
TEST_PYTHON=0
TEST_GO=0
TEST_CPP=0
TEST_SUITE=""
TEST_FILE=""
TEST_SUITE_PREFIX=""
TEST_DEBUG=0
TEST_DEBUG_OPTION=""
for i in "$@"
do
case $i in
    -t)
    shift
    ((i++))
    TEST_SUITE=${!i}
    shift 
    ;;
    -file)
    shift
    ((i++))
    TEST_FILE=${!i}
    shift 
    ;;
    --debug)
    TEST_DEBUG=1
    TEST_DEBUG_OPTION="--debug"
    shift # past argument with no value
    ;;
    --filldebug)
    TEST_FDEBUG_OPTION="--filldebug"
    shift # past argument with no value
    ;;
    --python)
    TEST_PYTHON=1
    cd $PY_ETHEREUM_PATH #(python has local dependencies so only works from within the directory)
    shift # past argument with no value
    ;;
    --cpp)
    TEST_CPP=1
    shift # past argument with no value
    ;;
    --go)
    TEST_GO=1
    shift # past argument with no value
    ;;
    --help)
    echo "Fuzzing Test Script for cpp-ethereum/build/test/fuzzTesting/createRandomTest"
    echo "Before you run make sure to set path variables in the 'options' section in the header of this script"
    echo "Usage:"
    echo "  -t <TestSuite>	- Define the test suite. Default suite is StateTests"
    echo "			(StateTests, TransactionTests, VMTests, BlockChainTests)"
    echo "  -file <PathToFile>	- Run test on a single file"
    echo "  --debug		- Output clients std::out and errors to the console"
    echo "  --filldebug		- Output test generation std::out"
    echo "  --python		- Add python client to the test simulation"
    echo "  --cpp			- Add cpp-jit client to the test simulation"
    echo "  --go			- Add go client to the test simulation"
    echo "			(By default all clients are set to run)"
    echo "  --help		- Display this help"
    exit;
    shift # past argument with no value
    ;;
    *)
            # unknown option
    ;;
esac
done

#if no option, test everything
if [ $TEST_PYTHON -ne 1 ] && [ $TEST_GO -ne 1 ] && [ $TEST_CPP -ne 1 ];
then
	TEST_PYTHON=1
	cd $PY_ETHEREUM_PATH #(python has local dependencies so only works from within the directory)
	TEST_GO=1
	TEST_CPP=1
fi

if [ "$TEST_SUITE" != "StateTests" ] && [ "$TEST_SUITE" != "TransactionTests" ] && [ "$TEST_SUITE" != "VMTests" ] && [ "$TEST_SUITE" != "BlockChainTests" ]; then
	if [ "$TEST_SUITE" != "" ]; then
		echo "Test suite not supported!"
	fi
	echo "Switching to: StateTests"
	TEST_SUITE="StateTests"
fi

TEST_SUITE_PREFIX=${TEST_SUITE,,}
TEST_SUITE_PREFIX=${TEST_SUITE_PREFIX:0:2} 
TOTAL_GO_FAILS=0
TOTAL_CPP_FAILS=0
TOTAL_PYTHON_FAILS=0
TOTAL_FILLING_FAILS=0
while [ 1 ]
do	
	if [[ $TEST_FILE == "" ]]; then
		TEST="$($CPP_ETHEREUM_PATH/build/test/fuzzTesting/createRandomTest -t $TEST_SUITE --fulloutput $TEST_FDEBUG_OPTION)"
	else
		TEST=$(cat $TEST_FILE)
	fi

	#test size limit to ~60 kbyte
	if [[ ${#TEST} -ge 60000 ]]; then
		echo "Test size too long!" 
		continue;
	fi  

	#exit because createRandomTest return might be corrupted by debug messages
	if [ "$TEST_FDEBUG_OPTION" == "--filldebug" ]; then
		echo "$TEST"
		exit;
	fi
	
	FILL_WRONG=1
	if [[ $TEST == *"post"* ]]; then
	 if [ "$TEST_SUITE" == "StateTests" ] || [ "$TEST_SUITE" == "VMTests" ] || [ "$TEST_SUITE" == "BlockChainTests" ]; then
		FILL_WRONG=0
	 fi
	fi

	if [[ $TEST == *"rlp"* ]] && [ "$TEST_SUITE" == "TransactionTests" ]; then
		FILL_WRONG=0
	fi

	if [ "$TEST_SUITE" == "VMTests" ]; then #VMTest always correct filling 
 		FILL_WRONG=0 
	fi  

	if [ $FILL_WRONG == 0 ]; then
		# test pyethereum
		RESULT_PYTHON=0
		if [ $TEST_PYTHON -eq 1 ]; then
		case "$TEST_SUITE" in
		 ("StateTests")
		 	OUTPUT_PYTHON="$(python $PY_ETHEREUM_PATH/ethereum/tests/test_state.py "$TEST" )"
		;;
		 ("TransactionTests")
			OUTPUT_PYTHON="$(python $PY_ETHEREUM_PATH/ethereum/tests/test_transactions.py "$TEST" )"
		;;
		 ("VMTests")
			OUTPUT_PYTHON="$(python $PY_ETHEREUM_PATH/ethereum/tests/test_vm.py "$TEST" )"
		;;
		 ("BlockChainTests")
			OUTPUT_PYTHON="$(python $PY_ETHEREUM_PATH/ethereum/tests/test_blockchain.py "$TEST" )"
		;;
		esac
		 RESULT_PYTHON=$?
		 if [ $TEST_DEBUG -eq 1 ]; then
			echo $OUTPUT_PYTHON
		 fi
		fi

		# test go
		RESULT_GO=0
		if [ $TEST_GO -eq 1 ]; then
			OUTPUT_GO="$( echo $TEST | $GO_ETHEREUM_PATH/bin/ethtest --test $TEST_SUITE --stdin )"
			RESULT_GO=$?
			if [ $TEST_DEBUG -eq 1 ]; then
				echo $OUTPUT_GO
			fi
		fi

		# test cpp-jit
		RESULT_CPPJIT=0
		if [ $TEST_CPP -eq 1 ];
		then
		 OUTPUT_CPPJIT="$($CPP_ETHEREUM_PATH/build/test/fuzzTesting/createRandomTest -t $TEST_SUITE $TEST_DEBUG_OPTION -checktest "$TEST")"
		 RESULT_CPPJIT=$?
		 if [ $TEST_DEBUG -eq 1 ]; then
			echo $OUTPUT_CPPJIT
		 fi
		fi

		if [ $TEST_DEBUG -ne 1 ]; then
			# go fails
			if [ "$RESULT_GO" -ne 0 ] && [ $TEST_GO -eq 1 ]; then
				TOTAL_GO_FAILS=$(($TOTAL_GO_FAILS + 1))
				echo "Go Failed! ($TOTAL_GO_FAILS total)"
				if [ "$LOG_ENABLE" -ne 0 ]; then
					echo Failed: >> $LOG_FILE
					echo Output_GO: >> $LOG_FILE
					echo $OUTPUT_GO >> $LOG_FILE
					echo Test: >> $LOG_FILE
					echo "$TEST" >> $LOG_FILE
				fi
				echo "$TEST" > FailedTest.json
				mv FailedTest.json $LOG_DIR/$TEST_SUITE_PREFIX$(date -d "today" +"%Y%m%d%H%M")GO.json # replace with scp to central server
			fi

			# python fails
			if [ "$RESULT_PYTHON" -ne 0 ] && [ $TEST_PYTHON -eq 1 ]; then
				TOTAL_PYTHON_FAILS=$(($TOTAL_PYTHON_FAILS + 1))
				echo "Python Failed! ($TOTAL_PYTHON_FAILS total)"
				if [ "$LOG_ENABLE" -ne 0 ]; then
					echo Failed: >> $LOG_FILE
					echo Output_PYTHON: >> $LOG_FILE
					echo $OUTPUT_PYTHON >> $LOG_FILE
					echo Test: >> $LOG_FILE
					echo "$TEST" >> $LOG_FILE
				fi
				echo "$TEST" > FailedTest.json 
				mv FailedTest.json $LOG_DIR/$TEST_SUITE_PREFIX$(date -d "today" +"%Y%m%d%H%M")PYTHON.json
			fi

			# cppjit fails
			if [ "$RESULT_CPPJIT" -ne 0 ] && [ $TEST_CPP -eq 1 ]; then
				TOTAL_CPP_FAILS=$(($TOTAL_CPP_FAILS + 1))
				echo "Cpp Failed! ($TOTAL_CPP_FAILS total)"
				if [ "$LOG_ENABLE" -ne 0 ]; then
					echo Failed: >> $LOG_FILE
					echo Output_CPPJIT: >> $LOG_FILE
					echo $OUTPUT_CPPJIT >> $LOG_FILE
					echo Test: >> $LOG_FILE
					echo "$TEST" >> $LOG_FILE
				fi
				echo "$TEST" > FailedTest.json
				mv FailedTest.json $LOG_DIR/$TEST_SUITE_PREFIX$(date -d "today" +"%Y%m%d%H%M")CPPJIT.json
			fi
		fi
	else
		TOTAL_FILLING_FAILS=$(($TOTAL_FILLING_FAILS + 1))
		echo "Error when filling test! ($TOTAL_FILLING_FAILS total)"
		if [ $TEST_DEBUG -ne 1 ]; then
			echo "$TEST" > FailedTest.json 
			mv FailedTest.json $LOG_DIR/$TEST_SUITE_PREFIX$(date -d "today" +"%Y%m%d%H%M")FILL.json
		fi
	fi

	if [[ $TEST_FILE != "" ]]; then
		break;
	fi	
done
