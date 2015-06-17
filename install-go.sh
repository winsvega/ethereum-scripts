echo Locating GO version...
if which go >/dev/null; then
    VERSION=$(go version)
    if [[ $VERSION == *"1.4.2"* ]]; then
	echo Found Go version 1.4.2
    else
	echo Found Go $VERSION
	echo This version seems to be not supported.
	echo Remove it completely and run this script again.
	exit;
    fi
else
    echo "Go not found. Attempt to install latest supported version..."
    echo Installing GO 1.4.2
    wget http://mirror.lightcone.eu/archlinux/community/os/x86_64/go-2:1.4.2-2-x86_64.pkg.tar.xz
    mv go-2:1.4.2-2-x86_64.pkg.tar.xz go142.tar.xz
    sudo tar xpvf go142.tar.xz -C /
    rm go142.tar.xz
fi

echo "Setup Go-Ethereum to the 'go-ethereum' directory"
if [ -d "go-ethereum" ]; then
   echo Found previous installation directory. 
   echo Attempt to remove...
   sudo rm -r go-ethereum
fi

mkdir go-ethereum
cd go-ethereum
export GOPATH=$(pwd)
export PATH=$PATH:$GOPATH/bin
echo Setting GOPATH=$GOPATH

if which godep >/dev/null; then
   echo Checking godep
else
   echo "Adding godep"
   go get github.com/tools/godep
fi

go get -v github.com/ethereum/go-ethereum/
cd src/github.com/ethereum/go-ethereum
echo building go-ethereum
godep go install -v ./…
echo adding ethtest to $GOPATH/bin
cd cmd/ethtest
godep go install
echo Done.
